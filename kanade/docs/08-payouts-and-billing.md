# 08 — 訂閱與分潤

## 1. 金流架構

```
店家 ──── Stripe Billing ────▶ 平台 Stripe 帳戶
                                    │
                                    ├─ 平台留存 55%
                                    │
                                    └─ Stripe Connect Transfer
                                         │
                                         ▼
                                   創作者 Express 帳戶
```

**核心原則：平台不保管使用者資金。**

不建立平台內餘額錢包 —— 那在多數司法管轄區會觸及資金移轉業（money transmitter）的牌照要求。改以 Stripe Connect Express 帳戶：創作者的錢由 Stripe 保管與撥付，平台僅發出 Transfer 指令。

**Stripe Connect Express 同時解決：**

- 創作者本人確認（KYC）
- 銀行帳戶綁定與撥款
- 稅務表格（日本國內：支払調書用資料；海外創作者：W-8BEN）
- 撥款失敗的重試與通知

---

## 2. 訂閱

| 方案 | 月額（稅込） | Stripe Price ID |
|---|---|---|
| Free | ¥0 | —（不建立訂閱） |
| Standard | ¥1,980 | `price_standard_monthly_jpy` |
| Standard 年繳 | ¥19,008（8 折） | `price_standard_yearly_jpy` |
| Custom | ¥4,980 | `price_custom_monthly_jpy` |
| Custom 年繳 | ¥47,808（8 折） | `price_custom_yearly_jpy` |
| Enterprise | 個別報價 | 手動建立 |

### 2.1 消費稅

日本国内取引，稅込表示（**総額表示義務**）。Stripe Tax 開啟 JP 自動計算。

平台須取得**適格請求書発行事業者登録番号**並在請求書上標示 —— 否則店家無法進項稅額扣抵，會直接影響購買意願。這是日本 B2B 的必要條件，不是選配。

### 2.2 Webhook 處理

| 事件 | 動作 |
|---|---|
| `customer.subscription.created` | 建立 `subscriptions`；發行管理外証明書 |
| `customer.subscription.updated` | 同步狀態、`venue_quota` |
| `invoice.payment_failed` | 進入 14 日寬限；第 1／7／13 日寄送提醒 |
| `invoice.payment_succeeded` | 解除寬限；計入 `payout_periods.net_revenue_jpy` |
| `customer.subscription.deleted` | 期末失效証明書；裝置降級至 Free |

Webhook 端點須驗簽並冪等（以 `event.id` 去重）。

### 2.3 欠費處理

```
D+0   付款失敗 → 寬限開始，播放不中斷
D+1   郵件提醒
D+7   郵件 + App 內提示
D+13  最終通知
D+14  降級至 Free 情境；証明書 revoked_at 設定
D+45  訂閱取消
```

**寬限期間播放不中斷**是刻意的設計。店內突然沒音樂會直接影響店家營業，造成的關係損害遠大於 14 日的服務成本。

---

## 3. 分潤池

### 3.1 計算

```
net_revenue = 訂閱收入總額
            − Stripe 手續費
            − 退款、chargeback
            − 消費稅

pool = net_revenue × 0.45
```

比例 `pool_rate` 存於 `payout_periods`，**每期獨立記錄**。日後調整比例不會影響已結算期間的數字。

### 3.2 分配

依**加權播放時長**分配，而非播放次數：

```
weighted_ms(track) = Σ min(played_ms, 90_000)
```

**單次播放的計入上限為 90 秒。** 理由：

- 防止上傳超長曲目刷分潤（60 分鐘的 ambient 曲會不成比例地佔用權重）
- 讓不同長度的曲目在同一基準上競爭

```
creator_share = Σ weighted_ms(該創作者所有曲目)
amount_jpy    = floor(pool × creator_share / total_weighted_ms)
```

只計入**商用播放事件**。聽眾端的免費串流不參與分潤 —— 那是曝光管道，不是收入來源，也是防刷的必要邊界。

### 3.3 結算週期

| 時點 | 動作 |
|---|---|
| 每月 1 日 | 建立上月 `payout_periods`（`draft`） |
| 每月 5 日 | 異常偵測完成，`finalized` |
| 每月 10 日 | 執行 Stripe Transfer |
| 每月 15 日 | 撥款完成，`paid` |

**最低撥款門檻 ¥1,000**，未達門檻累積至次期。Stripe Transfer 有固定成本，小額撥款不划算。

---

## 4. 防刷

分潤機制一旦可被套利，曲庫品質會在數個月內崩壞。AI 音樂的邊際生產成本趨近於零，代表**刷量的成本也趨近於零** —— 防護必須從第一天就存在。

| 手法 | 對策 |
|---|---|
| 自建假店舖刷自己的歌 | 訂閱付費為前提（刷 1 首要付 ¥1,980）；且單店貢獻權重設上限 |
| 上傳大量近似曲目佔量 | 平台內 CLAP 近似度去重（cosine > 0.95 視為同一曲） |
| 超長曲目 | 單次計入上限 90 秒 |
| 人頭帳號分散上傳 | 撥款需 KYC；同一銀行帳戶／裝置指紋關聯偵測 |
| 播放器竄改事件 | `client_event_id` 冪等；伺服器端驗證時序合理性（事件時間不得重疊、不得早於裝置綁定） |

**單店權重上限：** 任一店舖對單一創作者的月度貢獻，不得超過該創作者總權重的 30%。超出部分不計入。這使「自建店舖刷自己」在經濟上不可行。

異常偵測於每月 5 日結算前執行，命中項目人工複核後才 `finalized`。

---

## 5. 創作者稅務

| 情況 | 處理 |
|---|---|
| 日本國內個人 | Stripe 收集必要資料；平台年度提供支払調書用明細 |
| 日本國內法人 | 同上；請求書可由創作者自行開立 |
| 海外創作者 | Stripe 收集 W-8BEN；依租稅協定預扣 |

**平台不提供稅務建議**，僅提供完整的收益明細供創作者自行申報。此立場須在條款中明示。

---

## 6. 退款

| 情況 | 政策 |
|---|---|
| 訂閱首月 | 14 日內全額退款（無條件） |
| 年繳中途解約 | 依未使用月數按比例退款，扣除已享折扣差額 |
| 服務重大中斷 | 依中斷時數按比例補償（延長訂閱期，非現金） |
| 已結算的分潤 | **不因後續退款而追回**；由平台吸收 |

最後一項是刻意的：向創作者追討已撥付款項會嚴重破壞信任，而金額相對可控。此成本計入 `payout_periods` 的下期 `net_revenue` 調整。
