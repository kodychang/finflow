# Shoko Forms

日本商業帳票作成 Web App の新規プロトタイプです。日本の商取引でよく使う帳票を、独立した帳票オブジェクトとして作成、管理、変換、印刷できます。

## 機能

- 帳票タイプ切替: 見積書、注文書、発注書、納品書、請求書、領収書、受領書
- 見積書、注文書 / 発注書、納品書、請求書、領収書の相互変換
- 各帳票を独立した `formObject` として保存し、請求書・納品書も導線順に依存せず直接検索 / 参照
- URL クエリ `?form=<帳票ID>` / `?doc=<帳票番号>` による保存済み帳票の直接表示
- 取引先、自社情報、インボイス登録番号の入力
- 取引先管理
- 商品・サービス項目管理
- 明細行の追加、削除、数量、単価の入力
- 帳票全体の税率設定: 基本情報内の百分率入力、初期値 8%
- 適格請求書の主要記載事項チェック
- 税率別の対象金額、消費税額、非課税額の表示
- A4 帳票プレビュー
- ブラウザ内データベース (`localStorage`) 保存と最近の帳票リスト
- Email 登録による自動アカウント ID 発行
- Google アカウントログインと Google Drive バックアップ保存 / 最新バックアップ読込
- ローカルサーバー経由の PDF 生成、PDF プレビュー、印刷画面
- 帳票 JSON / ZIP バックアップ出力、JSON / ZIP バックアップ読込

## PDF 生成の標準実装

このプロジェクトでは、このリポジトリ内の PDF 実装を正とします。ほかの作業スレッドや派生版へ同期する場合は、以下の実装を基準にしてください。

- フロントエンド: `app.js` の `buildPdfPayload()`、`exportPdf()`、`printWithBrowserFallback()`、`submitPdfForm()`
- サーバー: `server.js` の `/api/pdf-file`、`/api/pdf`、`/api/pdf-print`、`pdfShell()`、`renderPdfBuffer()`
- PDF レンダリング: WeasyPrint を使い、`styles.css` と `fonts/` の帳票・印章用スタイルをサーバー側で読み込む
- 正しい動作: プロジェクト全体のプレビュー URL は `http://localhost:4180` のみを使い、PDF 生成リンクも同じ URL 配下に統一する
- 禁止事項: 1つの作業中に `4181`、`4183` など別ポートのプレビューリンクを追加で立てない

## インボイス制度対応範囲

プレビューでは以下の項目をチェックします。

- 自社名称
- 登録番号
- 取引年月日
- 取引内容
- 税率別金額
- 税率別消費税額
- 交付先名称

消費税額は、帳票ごとに税率別合計へ1回端数処理する前提で計算しています。

## 起動

```bash
cd /Volumes/AI/codex/japanese-business-forms-app
node server.js
```

Open `http://localhost:4180`.

## Google アカウント / Drive バックアップ

設定画面の `Google Client ID` に Google Cloud Console で作成した OAuth 2.0 Web Client ID を入力します。承認済み JavaScript 生成元には、利用するローカル URL 例 `http://localhost:4180` を追加してください。

Drive バックアップは Google Identity Services で `drive.file` スコープを取得し、`shoko-forms-backup-*.zip` を Google Drive に保存します。復元は Drive 上の同名バックアップから更新日時が新しい ZIP / JSON を読み込みます。

バックアップ読込は旧形式との互換性を優先し、`documents` / `docs` / `forms`、`customers` / `clients`、`items` / `products` など複数のキー名を許容します。ZIP 内は JSON ファイルを探して取り込み、既存データとは ID・帳票番号・会社名・名称をキーにマージします。

## 设计说明

这是一个零依赖静态 Web App，适合先确认产品体验。当前账号与 Google Drive 同步是浏览器端实现，生产化建议迁移到 Next.js + TypeScript，并追加服务器端 OAuth 回调、数据库账号表、团队权限、客户主数据、帐票编号规则、电子帐簿保存法相关审计记录、服务器端 PDF 生成和数据库持久化。
