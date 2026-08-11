# 02 — 系統架構

## 1. 元件圖

```
┌─ 創作者 ──────────┐   ┌─ 聽眾 ────────┐   ┌─ 店家 ────────────────┐
│ Web 上傳          │   │ Web / PWA     │   │ 商用播放器             │
│ 權利聲明表單      │   │ 免費串流      │   │ (Android / Web kiosk) │
│ 收益後台          │   │               │   │ 離線快取 + 再生ログ    │
└────────┬─────────┘   └───────┬───────┘   └───────────┬───────────┘
         │                     │                       │
         └──────────────┬──────┴───────────────────────┘
                        │  HTTPS
              ┌─────────▼──────────┐
              │   API (Next.js)     │
              │   Route Handlers    │
              └─────────┬──────────┘
                        │
   ┌────────────┬───────┼────────────┬──────────────┬─────────────┐
   │            │       │            │              │             │
┌──▼───────┐ ┌─▼─────┐ ┌▼─────────┐ ┌▼───────────┐ ┌▼──────────┐ ┌▼────────┐
│ Postgres │ │  R2   │ │ Job Queue│ │ Meilisearch│ │  Stripe   │ │ ClickHouse│
│ 主資料   │ │ 音檔  │ │ 轉檔/審核│ │ 全文+情境  │ │ 訂閱/分潤 │ │ 再生ログ  │
└──────────┘ └───┬───┘ └────┬─────┘ └────────────┘ └───────────┘ └─────────┘
                 │          │
          ┌──────▼──┐  ┌────▼──────────────────────────────┐
          │Cloudflare│  │ Workers: ffmpeg 轉檔 / LUFS 量測  │
          │   CDN    │  │ 指紋比對 / J-WID・NexTone 查核    │
          └──────────┘  │ 相似度檢測 / 聲音克隆檢測          │
                        └───────────────────────────────────┘
```

---

## 2. 技術選型

| 層 | 選擇 | 理由 |
|---|---|---|
| 前端 / API | **Next.js (App Router) + TypeScript** | 單一 codebase 涵蓋 Web／PWA／API；Vercel 部署簡單 |
| 主資料庫 | **PostgreSQL 16**（Neon 或 Supabase） | 關聯完整性對權利鏈至關重要；需要交易保證 |
| 物件儲存 | **Cloudflare R2** | **出口流量零費用**，這是成本結構的關鍵決策 |
| CDN | Cloudflare | 與 R2 原生整合 |
| 轉檔 | **ffmpeg**，跑在容器化 worker（Fly.io Machines 或 AWS Batch spot） | CPU 密集，需可彈性伸縮；spot 可省 60〜70% |
| 佇列 | **PostgreSQL + `SELECT ... FOR UPDATE SKIP LOCKED`** | 初期不引入 Redis／SQS；規模到了再換 |
| 搜尋 | **Meilisearch** | 日文分詞開箱可用，自架成本低 |
| 再生ログ | **ClickHouse**（Phase 2 起） | 寫入量大、需長期保存與快速聚合；初期先用 Postgres 分區表 |
| 金流 | **Stripe（Billing + Connect Express）** | 訂閱、分潤、稅務表格一次解決 |
| 音訊指紋 | **Chromaprint / AcoustID** | 開源、成熟 |
| 相似度嵌入 | **CLAP embedding** + pgvector | 情境搜尋與近似曲目檢測共用同一套向量 |
| 播放（Web） | **hls.js**（Safari 用原生 HLS） | 自適應碼率 |
| 商用播放器 | **Android（Kotlin）+ ExoPlayer**；備援為 kiosk 模式 PWA | 需要背景播放、離線快取、裝置鎖定 |

### 明確不採用

- **P2P / WebTorrent** — 見 [01-product 第 5 節](01-product.md#5-明確不做的事)
- **微服務** — 單一 Next.js app + worker 池即可支撐到數千店舖規模
- **Kubernetes** — 營運複雜度不成比例

---

## 3. 音檔處理管線

上傳後的每一步都會寫入 `clearance_checks`，**任一步失敗即停止並標記為 `flagged`，不進入商用曲庫**。

```
1. 上傳          → 接收原始檔（WAV/FLAC/MP3），計算 audio_sha256
2. 格式驗證      → ffprobe 確認確為可解碼音訊；拒絕非音訊內容
3. 去識別化      → 剝除 ID3 / 地理位置等 metadata（除非創作者明示保留）
4. 重新編碼      → 一律 re-encode，絕不直接提供原始上傳位元組
                   輸出：HLS/AAC 多碼率（64k / 128k / 256k）+ 商用用 256k AAC
5. 響度量測      → EBU R128：integrated LUFS、true peak、LRA
6. 指紋計算      → Chromaprint fingerprint
7. 嵌入計算      → CLAP embedding（情境標籤 + 近似檢測）
8. 自動審核      → 見 04-rights-chain 第 3 節
9. 人工複審      → 抽樣 + 全部 flagged 項目
10. 進入曲庫     → clearance_status = 'cleared'，可加入 commercial_catalog
```

**設計原則：`audio_sha256` 是內容的正規識別碼。** 授權、証明書、再生ログ、分潤全部綁定版本雜湊而非曲目 ID。曲目可以改名、改封面、換版本，已發出的憑證與記錄不受影響。

---

## 4. 環境與部署

| 環境 | 用途 | 資料 |
|---|---|---|
| `local` | 開發 | Docker Compose（Postgres + Meilisearch + MinIO 代替 R2） |
| `staging` | 整合測試、店家試用 | 獨立 R2 bucket，種子資料 |
| `production` | 正式 | 每日備份 + PITR |

- 資料庫遷移：**Drizzle Kit**，遷移檔進版控，禁止手動改 production schema
- Secrets：Vercel 環境變數 + Doppler；**任何憑證不得進 repo**
- CI：GitHub Actions — lint、typecheck、單元測試、遷移 dry-run

---

## 5. 成本模型（概估）

以 **500 家付費店舖、每店每日播放 10 小時** 估算：

| 項目 | 計算 | 月成本 |
|---|---|---|
| 商用串流出口流量 | 500 店 × 10h × 30d × 115 MB/h ≈ 17 TB | **¥0**（R2 零出口費） |
| 儲存 | 50,000 曲 × (原檔 30MB + 轉檔 12MB) ≈ 2.1 TB | 約 US$32 |
| 轉檔 CPU | 新增 5,000 曲/月 × 約 20 秒 | 約 US$40（spot） |
| Postgres | Neon Scale | 約 US$70 |
| Meilisearch | 小型 VPS | 約 US$20 |
| ClickHouse | 再生ログ，約 4.5 億筆/年 | 約 US$50 |
| Stripe 手續費 | 500 × ¥1,980 × 3.6% | 約 ¥35,600 |
| **合計（不含人事）** | | **約 US$212 + ¥35,600** |

對照收入：500 × ¥1,980 = **¥990,000／月**。

**結論：基礎設施不是成本瓶頸。** 真正的成本是（1）人工審核、（2）客服、（3）創作者分潤池（45%）、（4）日本法務。頻寬完全不需要擔心 — 這是選擇 R2 而非自建 CDN 或 P2P 的直接後果。

### 儲存是唯一持續增長的成本

流量隨用量波動，儲存只增不減。對策：

- 每帳號上傳配額（依信譽等級調整）
- 12 個月零商用播放的曲目，原始檔轉入冷儲存
- 已被撤銷（revoked）的曲目保留原檔以備稽核，但移出 CDN

---

## 6. 安全

| 面向 | 措施 |
|---|---|
| 認證 | Passkey 優先，不自行保管密碼；店家裝置用長效裝置金鑰 |
| 授權 | Postgres RLS + 應用層檢查雙重把關 |
| 上傳 | 一律 re-encode；檔案大小與時長上限；速率限制 |
| 外部連結 | `rel="nofollow ugc"` + Google Safe Browsing 掃描 |
| 裝置金鑰 | 僅儲存雜湊；可遠端撤銷 |
| 再生ログ | **append-only**，禁止 UPDATE／DELETE；以資料庫權限強制 |
| 稽核軌跡 | 所有權利狀態變更寫入 `audit_events`，不可變 |
| 備份 | 每日全備 + PITR；每季演練還原 |

**再生ログ 的不可變性是法律防禦的基礎。** 若記錄可被竄改，其證據價值歸零。實作上以獨立資料庫角色寫入，該角色僅有 INSERT 權限。
