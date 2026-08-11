# 03 — 資料模型

PostgreSQL 16。以下為核心 schema，省略了部分審計欄位（`created_at` / `updated_at` 一律存在）。

## 設計原則

1. **權利綁定版本雜湊，不綁曲目 ID。** 所有憑證、記錄、分潤引用 `track_versions.audio_sha256`。
2. **條款做快照。** 每份聲明與証明書都記錄當時的 `terms_version`，不隨日後改版而變動。
3. **再生ログ append-only。** 由資料庫權限強制，不靠應用層自律。
4. **狀態轉換留痕。** 權利狀態的每次變更都寫入 `audit_events`。
5. **已售出／已憑證化的內容永不硬刪。** 一律以 `revoked_at` / `removed_at` 軟刪除。

---

## 1. 使用者與創作者

```sql
CREATE TYPE user_role AS ENUM ('listener', 'creator', 'venue_admin', 'staff');

CREATE TABLE users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email           citext UNIQUE NOT NULL,
  handle          citext UNIQUE NOT NULL,        -- profile URL: /@handle
  display_name    text NOT NULL,
  roles           user_role[] NOT NULL DEFAULT '{listener}',
  country         char(2),                        -- ISO 3166-1
  locale          text NOT NULL DEFAULT 'ja-JP',
  suspended_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- 保留字：禁止註冊知名藝人名稱、含 official/verified 的 handle
CREATE TABLE reserved_handles (
  handle  citext PRIMARY KEY,
  reason  text NOT NULL
);

CREATE TABLE creator_profiles (
  user_id           uuid PRIMARY KEY REFERENCES users(id),
  bio               text,
  avatar_key        text,                          -- R2 object key
  -- [{platform, url, verified_at}] — rel="me" 雙向驗證
  external_links    jsonb NOT NULL DEFAULT '[]',
  -- 信譽等級決定上傳配額與抽樣複審比例
  trust_tier        smallint NOT NULL DEFAULT 0 CHECK (trust_tier BETWEEN 0 AND 3),
  stripe_account_id text,                          -- Stripe Connect Express
  payout_enabled    boolean NOT NULL DEFAULT false
);
```

---

## 2. 權利聲明（權利鏈起點）

**這是整條權利鏈的第一環。** 每次上傳都必須綁定一份有效聲明；聲明本身不可變，修改即產生新版本。

```sql
CREATE TABLE rights_declarations (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                   uuid NOT NULL REFERENCES users(id),
  terms_version             text NOT NULL,          -- 條款快照版本，例 '2026-09-01'

  -- 集管團體
  cmo_member                boolean NOT NULL,       -- 是否為任一集管團體會員
  declared_cmos             text[] NOT NULL DEFAULT '{}',  -- JASRAC / NexTone / ASCAP ...
  no_future_registration    boolean NOT NULL,       -- 同意不事後登記（契約義務）

  -- 內容聲明
  original_work             boolean NOT NULL,       -- 非既有作品的翻唱或改編
  no_voice_clone            boolean NOT NULL,       -- 未模仿可辨識之在世人物聲音
  no_third_party_sample     boolean NOT NULL,       -- 未使用未授權取樣

  -- AI 來源揭露（C2PA 的資料來源）
  ai_generated              boolean NOT NULL,
  ai_tool                   text,                   -- 例 'Suno v5'
  ai_prompt                 text,
  human_contribution        text,                   -- 人類創作參與的描述

  -- 授權範圍：必須包含可再授權的公開演奏／再生權
  grants_public_performance boolean NOT NULL,
  sublicensable             boolean NOT NULL,

  signed_at                 timestamptz NOT NULL DEFAULT now(),
  signed_ip                 inet NOT NULL,
  signed_user_agent         text NOT NULL,

  CONSTRAINT decl_must_grant_rights
    CHECK (grants_public_performance AND sublicensable),
  CONSTRAINT decl_must_be_original
    CHECK (original_work AND no_voice_clone AND no_third_party_sample),
  CONSTRAINT decl_no_future_reg
    CHECK (no_future_registration)
);

CREATE INDEX ON rights_declarations (user_id, signed_at DESC);
```

> **`cmo_member = true` 不自動拒絕，但強制進入人工審核。** JASRAC 會員的作品原則上全部委託管理（含本人可能遺忘的舊作），風險極高。實務上除非能提出該作品未委託的明確證明，否則不予通過。

---

## 3. 曲目與版本

```sql
CREATE TYPE clearance_status AS ENUM (
  'pending',    -- 處理中
  'cleared',    -- 已通過，可進商用曲庫
  'flagged',    -- 自動檢查有疑慮，待人工判斷
  'rejected',   -- 不通過
  'revoked'     -- 曾通過但事後撤銷（最高風險事件）
);

CREATE TABLE tracks (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id     uuid NOT NULL REFERENCES users(id),
  title          text NOT NULL,
  description    text,
  cover_key      text,
  -- 情境標籤：'morning','lunch','evening','rainy','busy','quiet','cafe','salon',...
  scene_tags     text[] NOT NULL DEFAULT '{}',
  genre_tags     text[] NOT NULL DEFAULT '{}',
  bpm            smallint,
  musical_key    text,
  has_vocals     boolean NOT NULL DEFAULT false,
  language       char(2),
  published_at   timestamptz,
  deleted_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE track_versions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id          uuid NOT NULL REFERENCES tracks(id),
  declaration_id    uuid NOT NULL REFERENCES rights_declarations(id),

  audio_sha256      bytea NOT NULL UNIQUE,       -- 正規識別碼，全域唯一（天然去重）
  source_key        text NOT NULL,               -- R2: 原始上傳檔
  hls_prefix        text,                        -- R2: HLS 輸出前綴
  commercial_key    text,                        -- R2: 商用 256k AAC

  duration_ms       integer NOT NULL,
  sample_rate       integer NOT NULL,
  channels          smallint NOT NULL,

  -- EBU R128
  lufs_integrated   real,
  true_peak_dbtp    real,
  loudness_range    real,

  chromaprint       text,                        -- 音訊指紋
  clap_embedding    vector(512),                 -- pgvector：情境搜尋 + 近似檢測

  clearance         clearance_status NOT NULL DEFAULT 'pending',
  cleared_at        timestamptz,
  revoked_at        timestamptz,
  revoke_reason     text,

  is_current        boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ON track_versions (track_id) WHERE is_current;
CREATE INDEX ON track_versions (clearance) WHERE clearance = 'cleared';
CREATE INDEX ON track_versions USING hnsw (clap_embedding vector_cosine_ops);
```

> `audio_sha256` 的 UNIQUE 約束同時達成三件事：內容去重、完整性驗證、以及阻止同一檔案被不同帳號重複上傳（常見的洗曲手法）。

---

## 4. 審核記錄

每一項自動或人工檢查都留下獨立記錄。**這是遭質疑時的舉證基礎**，不能只存最終結論。

```sql
CREATE TYPE check_type AS ENUM (
  'format_validation',
  'jasrac_jwid',            -- JASRAC 作品資料庫 J-WID 比對
  'nextone_search',         -- NexTone 檢索
  'fingerprint_commercial', -- 對商業曲庫的指紋比對
  'similarity_embedding',   -- CLAP 近似度檢測（含平台內部去重）
  'voice_clone_detect',
  'manual_review'
);

CREATE TYPE check_result AS ENUM ('pass', 'fail', 'inconclusive');

CREATE TABLE clearance_checks (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  track_version_id  uuid NOT NULL REFERENCES track_versions(id),
  check_type        check_type NOT NULL,
  result            check_result NOT NULL,
  provider          text,                        -- 'acoustid' / 'internal' / reviewer id
  score             real,                        -- 相似度等量化結果
  evidence          jsonb NOT NULL DEFAULT '{}', -- 查詢字串、命中項目、截圖 key
  reviewed_by       uuid REFERENCES users(id),   -- 人工複審者
  checked_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON clearance_checks (track_version_id, check_type);
```

---

## 5. 商用曲庫與曲庫快照

商用曲庫是 `cleared` 曲目的**受管子集**。快照讓每份証明書能綁定「發行當下的曲庫狀態」。

```sql
CREATE TABLE commercial_catalog_entries (
  track_version_id  uuid PRIMARY KEY REFERENCES track_versions(id),
  added_at          timestamptz NOT NULL DEFAULT now(),
  removed_at        timestamptz,
  removal_reason    text
);

-- 每日產生一次；証明書與再生ログ 引用之
CREATE TABLE catalog_snapshots (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  taken_at      timestamptz NOT NULL DEFAULT now(),
  entry_count   integer NOT NULL,
  -- 所有 audio_sha256 排序後建構的 Merkle root。
  -- 用途：可對單一曲目出具 Merkle proof，證明「播放當時該曲確在已審核曲庫中」，
  --       且無須揭露完整曲庫。
  merkle_root   bytea NOT NULL
);
```

---

## 6. 店家、訂閱、裝置

```sql
CREATE TABLE organizations (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_name        text NOT NULL,
  billing_country   char(2) NOT NULL DEFAULT 'JP',
  tax_id            text,                        -- 適格請求書発行事業者登録番号 等
  stripe_customer_id text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE venues (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          uuid NOT NULL REFERENCES organizations(id),
  name            text NOT NULL,
  address         text,
  floor_area_sqm  numeric(8,2),                  -- 供對照 JASRAC 面積級距用
  industry        text,                          -- 'restaurant','salon','retail','clinic'
  timezone        text NOT NULL DEFAULT 'Asia/Tokyo',
  opening_hours   jsonb NOT NULL DEFAULT '{}',   -- 情境排程的依據
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TYPE plan_code AS ENUM ('free', 'standard', 'custom', 'enterprise');

CREATE TABLE subscriptions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id                uuid NOT NULL REFERENCES organizations(id),
  plan                  plan_code NOT NULL,
  status                text NOT NULL,           -- 對映 Stripe subscription status
  venue_quota           integer NOT NULL DEFAULT 1,
  current_period_start  timestamptz NOT NULL,
  current_period_end    timestamptz NOT NULL,
  stripe_subscription_id text UNIQUE,
  canceled_at           timestamptz
);

CREATE TABLE venue_devices (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id          uuid NOT NULL REFERENCES venues(id),
  label             text NOT NULL,
  device_key_hash   bytea NOT NULL,              -- 僅存雜湊
  app_version       text,
  last_seen_at      timestamptz,
  revoked_at        timestamptz
);
```

---

## 7. 管理外証明書

```sql
CREATE TABLE certificates (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cert_no            text UNIQUE NOT NULL,       -- 'KND-2026-000123'
  org_id             uuid NOT NULL REFERENCES organizations(id),
  venue_id           uuid NOT NULL REFERENCES venues(id),
  subscription_id    uuid NOT NULL REFERENCES subscriptions(id),

  valid_from         date NOT NULL,
  valid_to           date NOT NULL,
  catalog_snapshot_id uuid NOT NULL REFERENCES catalog_snapshots(id),
  terms_version      text NOT NULL,

  verify_token       text NOT NULL,              -- 公開驗證頁的高熵 token
  pdf_key            text NOT NULL,              -- R2
  pdf_sha256         bytea NOT NULL,

  issued_at          timestamptz NOT NULL DEFAULT now(),
  revoked_at         timestamptz,
  revoke_reason      text
);

CREATE INDEX ON certificates (venue_id, valid_to DESC);
```

---

## 8. 再生ログ（append-only）

初期以 Postgres 月分區表實作，寫入量增長後遷往 ClickHouse。**保存期限 5 年**（涵蓋日本一般時效並保留餘裕）。

```sql
CREATE TABLE playback_events (
  id                bigserial,
  venue_id          uuid NOT NULL,
  device_id         uuid NOT NULL,
  track_version_id  uuid NOT NULL,
  audio_sha256      bytea NOT NULL,   -- 反正規化：即使曲目日後被刪，記錄仍可自證
  scene_id          uuid,
  started_at        timestamptz NOT NULL,
  played_ms         integer NOT NULL, -- 實際播放時長，非曲目長度
  completed         boolean NOT NULL,
  client_event_id   uuid NOT NULL,    -- 冪等鍵，離線重送用
  ingested_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, started_at)
) PARTITION BY RANGE (started_at);

CREATE UNIQUE INDEX ON playback_events (device_id, client_event_id, started_at);
CREATE INDEX ON playback_events (venue_id, started_at DESC);
CREATE INDEX ON playback_events (track_version_id, started_at);

-- 不可變性以權限強制，而非應用層自律
REVOKE UPDATE, DELETE ON playback_events FROM app_write;
GRANT INSERT, SELECT ON playback_events TO app_write;
```

> `audio_sha256` 在此刻意反正規化。再生ログ 的價值在於**日後被質疑時能獨立自證**；若必須 JOIN 一張可能已被修改的表才能解讀，證據力就打了折扣。

---

## 9. 分潤

```sql
CREATE TYPE payout_status AS ENUM ('draft', 'finalized', 'paid', 'failed');

CREATE TABLE payout_periods (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_start   date NOT NULL,
  period_end     date NOT NULL,
  net_revenue_jpy bigint NOT NULL,               -- 訂閱淨收入（已扣 Stripe 手續費與退款）
  pool_rate      numeric(4,3) NOT NULL DEFAULT 0.450,
  pool_jpy       bigint NOT NULL,
  total_weighted_ms bigint NOT NULL,
  status         payout_status NOT NULL DEFAULT 'draft',
  finalized_at   timestamptz,
  UNIQUE (period_start, period_end)
);

CREATE TABLE payout_lines (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id      uuid NOT NULL REFERENCES payout_periods(id),
  creator_id     uuid NOT NULL REFERENCES users(id),
  play_count     integer NOT NULL,
  weighted_ms    bigint NOT NULL,
  amount_jpy     bigint NOT NULL,
  stripe_transfer_id text,
  paid_at        timestamptz,
  UNIQUE (period_id, creator_id)
);
```

---

## 10. 稽核軌跡

```sql
CREATE TABLE audit_events (
  id           bigserial PRIMARY KEY,
  actor_id     uuid REFERENCES users(id),        -- NULL = 系統
  entity_type  text NOT NULL,                    -- 'track_version','certificate',...
  entity_id    uuid NOT NULL,
  action       text NOT NULL,                    -- 'clearance.revoked','cert.issued',...
  before       jsonb,
  after        jsonb,
  reason       text,
  occurred_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON audit_events (entity_type, entity_id, occurred_at DESC);
REVOKE UPDATE, DELETE ON audit_events FROM app_write;
```

**所有 `clearance` 狀態變更、証明書發行與撤銷、曲庫增刪，皆必須寫入此表。** 這是遭到查詢時證明「平台確實有在管理」的依據 — 而「有無盡到管理義務」往往決定責任歸屬。
