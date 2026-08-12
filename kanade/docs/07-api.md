# 07 — API 規格

REST over HTTPS。`Content-Type: application/json`，除檔案上傳外。
Base：`https://api.kanade.example/v1`

---

## 1. 認證

| 客戶端 | 方式 |
|---|---|
| Web（創作者／聽眾／店主） | Session cookie（`HttpOnly`, `Secure`, `SameSite=Lax`） |
| 商用播放器裝置 | `Authorization: Device <device_key>` |
| 店家整合 API（Custom 方案） | `Authorization: Bearer <api_key>` |
| 內部 worker | mTLS，不經公開閘道 |

裝置金鑰於綁定時發放一次，僅儲存雜湊（`venue_devices.device_key_hash`）。遺失即重新綁定，無法找回。

---

## 2. 錯誤格式

```json
{
  "error": {
    "code": "clearance_required",
    "message": "この楽曲はまだ審査中です。",
    "detail": { "track_version_id": "018f2c00-..." },
    "request_id": "req_01J8..."
  }
}
```

| HTTP | code 範例 |
|---|---|
| 400 | `invalid_request`, `declaration_incomplete` |
| 401 | `unauthenticated`, `device_key_revoked` |
| 403 | `forbidden`, `subscription_required` |
| 404 | `not_found` |
| 409 | `duplicate_audio`, `handle_taken` |
| 422 | `clearance_required`, `unsupported_audio_format` |
| 429 | `rate_limited`（附 `Retry-After`） |
| 5xx | `internal_error` |

所有回應含 `X-Request-Id`，與 `audit_events` 及日誌可交叉查詢。

---

## 3. 創作者：上傳

### 3.1 建立權利聲明

```http
POST /declarations
```

```json
{
  "terms_version": "2026-09-01",
  "cmo_member": false,
  "declared_cmos": [],
  "no_future_registration": true,
  "original_work": true,
  "no_voice_clone": true,
  "no_third_party_sample": true,
  "ai_generated": true,
  "ai_tool": "Suno v5",
  "ai_prompt": "warm lo-fi jazz, rainy afternoon, no vocals",
  "human_contribution": "プロンプト設計、選別、マスタリング",
  "grants_public_performance": true,
  "sublicensable": true
}
```

→ `201 { "declaration_id": "..." }`

任一必要布林值為 `false` → `400 declaration_incomplete`。

### 3.2 取得上傳 URL

```http
POST /uploads
{ "declaration_id": "...", "filename": "morning.wav", "size_bytes": 48210332 }
```

→ `201`

```json
{
  "upload_id": "...",
  "url": "https://r2.../presigned",
  "method": "PUT",
  "expires_at": "2026-09-01T12:15:00Z"
}
```

直傳 R2，不經 API 伺服器。

### 3.3 完成上傳

```http
POST /uploads/{upload_id}/complete
{ "track": { "title": "朝の光", "scene_tags": ["morning","cafe"], "has_vocals": false } }
```

→ `202`

```json
{ "track_id": "...", "track_version_id": "...", "clearance": "pending" }
```

進入非同步管線（見 [02 第 3 節](02-architecture.md#3-音檔處理管線)）。

### 3.4 查詢審核狀態

```http
GET /tracks/{track_id}/versions/{version_id}/clearance
```

→ `200`

```json
{
  "clearance": "flagged",
  "checks": [
    { "type": "fingerprint_commercial", "result": "pass",  "checked_at": "..." },
    { "type": "similarity_embedding",   "result": "fail",  "score": 0.94,
      "message": "既存楽曲との類似度が高いため人手による確認中です。" }
  ],
  "estimated_review_by": "2026-09-03T00:00:00Z"
}
```

> `evidence` 的完整內容**不對創作者揭露** —— 揭露命中細節等於教人如何規避檢測。僅回傳檢查類型、結果與說明文字。

---

## 4. 聽眾：免費串流

```http
GET /discover?scene=morning&limit=50        # 情境瀏覽
GET /search?q=雨の日 カフェ&limit=20         # 語意 + 全文混合搜尋
GET /tracks/{id}/stream                     # → 302 至 HLS 播放清單
```

免費、無需登入（速率限制較嚴）。串流僅提供 128k HLS；商用 256k 需裝置認證。

---

## 5. 商用播放器

### 5.1 綁定裝置

```http
POST /devices/bind
{ "pairing_code": "483-921", "label": "レジ横" }
```

→ `201 { "device_id": "...", "device_key": "dk_live_...", "venue_id": "..." }`

`device_key` **僅此一次回傳**。

### 5.2 取得播放佇列

```http
GET /player/queue?hours=4
Authorization: Device dk_live_...
```

→ `200`

```json
{
  "scene": { "id": "...", "name": "平日 午後 雨" },
  "expires_at": "2026-09-01T18:00:00Z",
  "items": [
    {
      "track_version_id": "018f2c00-...",
      "audio_sha256": "a3f2b1...",
      "title": "朝の光",
      "artist": "Yuki Aoi",
      "duration_ms": 187430,
      "gain_db": -2.4,
      "url": "https://cdn.../commercial/a3f2b1....m4a",
      "url_expires_at": "2026-09-01T20:00:00Z"
    }
  ]
}
```

`gain_db` 由伺服器依 `lufs_integrated` 對 -16 LUFS 目標計算，播放器直接套用。

### 5.3 曲庫差分同步

```http
GET /player/catalog/delta?since=2026-09-01T06:00:00Z
```

→ `200`

```json
{
  "added":   [ { "track_version_id": "...", "audio_sha256": "..." } ],
  "removed": [ { "track_version_id": "...", "reason": "revoked", "hard_stop": true } ],
  "as_of": "2026-09-01T12:00:00Z"
}
```

`hard_stop: true` → 播放器必須**立即**中斷該曲，不等曲末。

### 5.4 上傳再生ログ

```http
POST /player/playback-events
{ "events": [ { "client_event_id": "...", "track_version_id": "...",
                "audio_sha256": "...", "started_at": "...",
                "played_ms": 187430, "completed": true } ] }
```

→ `202 { "accepted": 100, "duplicates": 3 }`

以 `(device_id, client_event_id)` 冪等去重。**重複送出永遠回 202**，不回錯誤 —— 離線重送必須是安全的。單批上限 500 筆。

---

## 6. 店家管理

```http
GET  /venues/{id}/certificate                  # 目前有效証明書
GET  /venues/{id}/certificate/pdf              # → 302 至 R2 簽名 URL
POST /venues/{id}/playback-logs/export         # 非同步產生匯出
     { "from": "2026-09-01", "to": "2026-09-30", "format": "pdf" }
     → 202 { "export_id": "...", "status": "processing" }
GET  /exports/{export_id}                      # 輪詢，完成後含下載 URL
GET  /venues/{id}/scenes
PUT  /venues/{id}/scenes/{scene_id}
```

---

## 7. 公開驗證（無需認證）

```http
GET /public/certificates/{cert_no}?t={verify_token}
```

→ `200`

```json
{
  "cert_no": "KND-2026-000123",
  "status": "valid",
  "org_name": "株式会社◯◯",
  "venue_name": "◯◯カフェ 渋谷店",
  "valid_from": "2026-09-01",
  "valid_to": "2027-08-31",
  "catalog_as_of": "2026-09-01",
  "catalog_track_count": 12847,
  "issuer": "◯◯株式会社"
}
```

`status`：`valid` / `expired` / `revoked`。

token 錯誤一律回 `404 not_found`（**不區分「不存在」與「token 錯誤」**，避免列舉攻擊）。此端點速率限制 60 req/min/IP。

---

## 8. 創作者收益

```http
GET /creator/earnings?period=2026-09
```

→ `200`

```json
{
  "period": "2026-09",
  "status": "finalized",
  "play_count": 4821,
  "weighted_ms": 892340000,
  "amount_jpy": 12430,
  "pool_rate": 0.30,
  "next_tier": {
    "rate": 0.35,
    "paying_venues_required": 500,
    "paying_venues_current": 312
  },
  "top_tracks": [
    { "track_id": "...", "title": "朝の光", "play_count": 892, "venue_count": 34 }
  ]
}
```

> `venue_count` 顯示店舖**數量**，不揭露店名 —— 店家的營運資訊不對創作者公開。

> `pool_rate` 與 `next_tier` 為**必填**。段階的分配率は公表を前提とした設計であり、現在の分配率と次の段階を隠すと制度そのものが不信の対象になる（[08 第 3.2 節](08-payouts-and-billing.md#32-段階的分配率)）。最高段階（45%）到達後は `next_tier` を `null` とする。

---

## 9. 速率限制

| 端點群 | 限制 |
|---|---|
| 公開串流／搜尋（未登入） | 120 req/min/IP |
| 公開驗證 | 60 req/min/IP |
| 已登入一般 | 600 req/min/user |
| 上傳建立 | 20/hour/user（依 `trust_tier` 上調） |
| 播放器同步 | 60 req/min/device |
| 再生ログ 上傳 | 20 req/min/device |

超限回 `429` 並附 `Retry-After`。
