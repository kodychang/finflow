const yen = new Intl.NumberFormat("ja-JP", {
  style: "currency",
  currency: "JPY",
  maximumFractionDigits: 0,
});

const today = "2026-04-29";
let appLang = "ja";

const uiText = {
  ja: {
    "Documents": "書類センター",
    "Filing readiness": "申告準備",
    "Income analysis": "収入分析",
    "Tax estimate": "税額予測",
    "Policy updates": "政策更新",
    "Membership": "会員・権限",
    "Accounts": "口座整理",
    "Forms": "帳票作成",
    "Customers": "取引先管理",
    "Feedback": "お問い合わせ",
    "Training data": "学習データ",
    "Annual revenue": "年度売上",
    "Annual expenses": "年度支出",
    "Projected profit": "今年の利益見込み",
    "Missing / review": "漏れ・確認待ち",
    "AI usage saved": "AI使用量削減",
    "All": "すべて",
    "Needs review": "未確認",
    "Company": "法人",
    "Personal": "個人",
    "Tax": "税務",
    "Status": "状態",
    "Folder": "整理先",
    "Saved name": "保存名",
    "Date": "日付",
    "Issue date": "発行日",
    "Due date": "期限",
    "Counterparty": "取引先",
    "Type": "種別",
    "Company/personal": "法人/個人",
    "Category": "分類",
    "Amount": "金額",
    "Confidence": "信頼度",
    all: "すべて",
    unreviewed: "未確認",
    company: "法人",
    personal: "個人",
    tax: "税務",
    staged: "未整理",
    archived: "整理済み",
    pendingReview: "AI確認待ち",
    receipt: "領収書",
    invoice: "請求書",
    contract: "契約書",
    bank_statement: "銀行・カード明細",
    tax_document: "税務書類",
    income: "収入",
    expense: "支出",
    upload: "アップロード",
    confirmArchive: "確認して整理",
    archivedUpdate: "整理済み / 更新",
    noErrors: "エラーなし",
  },
  "zh-Hant": {
    all: "全部",
    unreviewed: "未確認",
    company: "法人",
    personal: "個人",
    tax: "稅務",
    staged: "待歸檔",
    archived: "已歸檔",
    pendingReview: "AI待確認",
    receipt: "收據",
    invoice: "發票/請求書",
    contract: "合約",
    bank_statement: "銀行/信用卡明細",
    tax_document: "稅務文件",
    income: "收入",
    expense: "支出",
    upload: "上傳",
    confirmArchive: "確認並歸檔",
    archivedUpdate: "已歸檔 / 更新",
    noErrors: "沒有錯誤",
  },
  "zh-Hans": {
    all: "全部",
    unreviewed: "未确认",
    company: "法人",
    personal: "个人",
    tax: "税务",
    staged: "待归档",
    archived: "已归档",
    pendingReview: "AI待确认",
    receipt: "收据",
    invoice: "发票/请求书",
    contract: "合同",
    bank_statement: "银行/信用卡明细",
    tax_document: "税务文件",
    income: "收入",
    expense: "支出",
    upload: "上传",
    confirmArchive: "确认并归档",
    archivedUpdate: "已归档 / 更新",
    noErrors: "没有错误",
  },
  en: {
    "文件中心": "Documents",
    "申报准备": "Filing readiness",
    "申報準備": "Filing readiness",
    "收入分析": "Income analysis",
    "税额预估": "Tax estimate",
    "稅額預估": "Tax estimate",
    "政策更新": "Policy updates",
    "会员与权限": "Membership",
    "會員與權限": "Membership",
    "账户整理": "Accounts",
    "帳戶整理": "Accounts",
    "表单生成": "Forms",
    "表單生成": "Forms",
    "客户管理": "Customers",
    "客戶管理": "Customers",
    "客户反馈": "Feedback",
    "客戶反饋": "Feedback",
    "学习数据": "Training data",
    "學習資料": "Training data",
    "上传": "Upload",
    "上傳": "Upload",
    "年度收入": "Annual revenue",
    "年度支出": "Annual expenses",
    "今年预估盈亏": "Projected profit",
    "今年預估損益": "Projected profit",
    "缺漏与待确认": "Missing / review",
    "缺漏與待確認": "Missing / review",
    "AI使用量节省": "AI usage saved",
    "AI使用量節省": "AI usage saved",
    "全部": "All",
    "未确认": "Needs review",
    "未確認": "Needs review",
    "法人": "Company",
    "个人": "Personal",
    "個人": "Personal",
    "税务": "Tax",
    "稅務": "Tax",
    "搜索：店名、分类、金额": "Search: vendor, category, amount",
    "搜尋：店名、分類、金額": "Search: vendor, category, amount",
    "状态": "Status",
    "狀態": "Status",
    "保存名称": "Saved name",
    "保存名稱": "Saved name",
    "日期": "Date",
    "发行日": "Issue date",
    "發行日": "Issue date",
    "交易对象": "Counterparty",
    "交易對象": "Counterparty",
    "类型": "Type",
    "類型": "Type",
    "法人/个人": "Company/personal",
    "法人/個人": "Company/personal",
    "分类": "Category",
    "分類": "Category",
    "金额": "Amount",
    "金額": "Amount",
    "可信度": "Confidence",
    "已确认": "Confirmed",
    "已確認": "Confirmed",
    "确认并归档": "Confirm and archive",
    "確認並歸檔": "Confirm and archive",
    all: "All",
    unreviewed: "Needs review",
    company: "Company",
    personal: "Personal",
    tax: "Tax",
    staged: "Pending archive",
    archived: "Archived",
    pendingReview: "AI review",
    receipt: "Receipt",
    invoice: "Invoice",
    contract: "Contract",
    bank_statement: "Bank/card statement",
    tax_document: "Tax document",
    income: "Income",
    expense: "Expense",
    upload: "Upload",
    confirmArchive: "Confirm and archive",
    archivedUpdate: "Archived / update",
    noErrors: "No errors",
  },
};

function t(key) {
  return uiText[appLang]?.[key] || uiText.ja[key] || key;
}

const phraseMap = {
  ja: {
    "表单生成": "帳票作成",
    "客户管理": "取引先管理",
    "客户反馈": "お問い合わせ",
    "当前视角: 用户工作台": "現在の表示: ユーザー作業台",
    "平台经营者后台": "運営者管理画面",
    "归档目录": "整理先",
    "归档待ち": "未整理",
    "用户手动输入、CSV导入、PDF/照片明细上传。AI 自动识别交易并与发票/收据匹配。": "手入力、CSV取込、PDF/写真の明細アップロードに対応します。AIが取引と請求書・領収書を照合します。",
    "后期: API连接": "将来: API連携",
    "银行/信用卡 API、会计软件 API、聚合商连接作为高级功能，需要 OAuth、合规和维护。": "銀行・カードAPI、会計ソフトAPI、集約サービス連携は上位機能として扱い、OAuth、法令対応、保守が必要です。",
    "手动追加": "手入力で追加",
    "摘要 / 店铺 / 入金来源": "摘要 / 店舗 / 入金元",
    "金额": "金額",
    "收入": "収入",
    "支出": "支出",
    "确认并归档": "確認して整理",
    "已归档 / 更新确认": "整理済み / 更新",
    "AI归档理由与检查结果": "AIの整理理由と確認結果",
    "确认后才归档": "確認後に整理",
    "法人 / 发票・請求書": "法人 / 請求書",
    "法人 / 领收书": "法人 / 領収書",
    "法人 / 契约书": "法人 / 契約書",
    "法人 / 税务": "法人 / 税務",
    "法人 / 银行账户": "法人 / 銀行口座",
    "个人 / 领收书": "個人 / 領収書",
    "个人 / 税务": "個人 / 税務",
    "个人 / 银行账户": "個人 / 銀行口座",
    "已归档": "整理済み",
    "待确认": "未確認",
    "客户/厂商名": "取引先名",
    "区分": "区分",
    "联系人": "担当者",
    "电话": "電話",
    "付款条件": "支払条件",
    "备注 / 报税确认事项": "メモ / 申告確認事項",
    "搜索不到，建立新客户": "見つからない場合は新規作成",
  },
  "zh-Hant": {
    "書類センター": "文件中心",
    "申告準備": "申報準備",
    "収入分析": "收入分析",
    "税額予測": "稅額預估",
    "政策更新": "政策更新",
    "会員・権限": "會員與權限",
    "口座整理": "帳戶整理",
    "学習データ": "學習資料",
    "アップロード": "上傳",
    "年度売上": "年度收入",
    "年度支出": "年度支出",
    "今年の利益見込み": "今年預估損益",
    "漏れ・確認待ち": "缺漏與待確認",
    "AI使用量削減": "AI使用量節省",
    "すべて": "全部",
    "未確認": "未確認",
    "会社": "法人",
    "個人": "個人",
    "税務": "稅務",
    "検索: 店舗名、分類、金額": "搜尋：店名、分類、金額",
    "状態": "狀態",
    "保存名": "保存名稱",
    "日付": "日期",
    "発行日": "發行日",
    "期限": "期限",
    "取引先": "交易對象",
    "種別": "類型",
    "会社/個人": "法人/個人",
    "分類": "分類",
    "金額": "金額",
    "信頼度": "可信度",
    "確認済": "已確認",
    "確認して整理": "確認並歸檔",
  },
  "zh-Hans": {
    "書類センター": "文件中心",
    "申告準備": "申报准备",
    "収入分析": "收入分析",
    "税額予測": "税额预估",
    "政策更新": "政策更新",
    "会員・権限": "会员与权限",
    "口座整理": "账户整理",
    "学習データ": "学习数据",
    "アップロード": "上传",
    "年度売上": "年度收入",
    "年度支出": "年度支出",
    "今年の利益見込み": "今年预估盈亏",
    "漏れ・確認待ち": "缺漏与待确认",
    "AI使用量削減": "AI使用量节省",
    "すべて": "全部",
    "未確認": "未确认",
    "会社": "法人",
    "個人": "个人",
    "税務": "税务",
    "検索: 店舗名、分類、金額": "搜索：店名、分类、金额",
    "状態": "状态",
    "保存名": "保存名称",
    "日付": "日期",
    "発行日": "发行日",
    "期限": "期限",
    "取引先": "交易对象",
    "種別": "类型",
    "会社/個人": "法人/个人",
    "分類": "分类",
    "金額": "金额",
    "信頼度": "可信度",
    "確認済": "已确认",
    "確認して整理": "确认并归档",
  },
  en: {
    "書類センター": "Documents",
    "申告準備": "Filing readiness",
    "収入分析": "Income analysis",
    "税額予測": "Tax estimate",
    "政策更新": "Policy updates",
    "会員・権限": "Membership",
    "口座整理": "Accounts",
    "表单生成": "Forms",
    "客户管理": "Customers",
    "客户反馈": "Feedback",
    "学習データ": "Training data",
    "アップロード": "Upload",
    "年度売上": "Annual revenue",
    "年度支出": "Annual expenses",
    "今年の利益見込み": "Projected profit",
    "漏れ・確認待ち": "Missing / review",
    "AI使用量削減": "AI usage saved",
    "すべて": "All",
    "未確認": "Needs review",
    "会社": "Company",
    "個人": "Personal",
    "税務": "Tax",
    "検索: 店舗名、分類、金額": "Search: vendor, category, amount",
    "状態": "Status",
    "归档目录": "Folder",
    "保存名": "Saved name",
    "日付": "Date",
    "発行日": "Issue date",
    "期限": "Due date",
    "取引先": "Counterparty",
    "種別": "Type",
    "会社/個人": "Company/personal",
    "分類": "Category",
    "金額": "Amount",
    "信頼度": "Confidence",
    "確認済": "Confirmed",
    "確認して整理": "Confirm and archive",
    "当前视角: 用户工作台": "Current view: user workspace",
    "平台经营者后台": "Operator admin",
  },
};

const taxSources = [
  "国税庁: 所得税 5%-45% 速算表",
  "国税庁: 法人税 中小法人 800万円以下15%、超過23.2%",
  "国税庁: 消費税 標準10%、軽減8%、インボイス保存要件",
  "東京都主税局: 個人事業税 事業主控除290万円、税率は業種別",
];

const incomeTaxBrackets = [
  { min: 0, max: 1949000, rate: 0.05, deduction: 0 },
  { min: 1950000, max: 3299000, rate: 0.1, deduction: 97500 },
  { min: 3300000, max: 6949000, rate: 0.2, deduction: 427500 },
  { min: 6950000, max: 8999000, rate: 0.23, deduction: 636000 },
  { min: 9000000, max: 17999000, rate: 0.33, deduction: 1536000 },
  { min: 18000000, max: 39999000, rate: 0.4, deduction: 2796000 },
  { min: 40000000, max: Infinity, rate: 0.45, deduction: 4796000 },
];

const aiPipelineRules = [
  "先用本地预处理/基础OCR抽取文字与版面，避免整份文件直接送AI",
  "只把关键字段、低置信度片段、表格摘要送到视觉/语言模型",
  "日本发票检查登録番号、税率、税额、发行日、对方名称、付款期限",
  "AI只给建议目录，用户确认后才写入个人/法人/税务/合同目录",
];

const accounts = [
  { name: "会社銀行口座", type: "bank", owner: "company", balance: 1840000, mixed: false, progress: 86, connection: "manual_csv" },
  { name: "会社クレジットカード", type: "credit_card", owner: "company", balance: -246800, mixed: false, progress: 72, connection: "manual_csv" },
  { name: "個人銀行口座", type: "bank", owner: "personal", balance: 930000, mixed: true, progress: 54, connection: "manual" },
  { name: "PayPay", type: "payment", owner: "mixed", balance: 128000, mixed: true, progress: 38, connection: "statement_upload" },
];

const companyProfile = {
  companyName: "株式会社サンプル",
  corporateNumber: "1234567890123",
  invoiceNumber: "T1234567890123",
  postalCode: "100-0001",
  address: "東京都千代田区千代田1-1",
  representative: "田中 太郎",
  phone: "03-1234-5678",
  email: "office@example.jp",
};

const personalProfile = {
  fullName: "田中 太郎",
  tradeName: "FinFlow Studio",
  postalCode: "154-0001",
  address: "東京都世田谷区池尻1-2-3",
  phone: "090-1234-5678",
  email: "taro@example.jp",
  residentTaxMemo: "都民税は6月通知、普通徴収の確認が必要",
  identityStatus: "本人確認済み",
};

let phoneVerification = {
  phone: "090-1234-5678",
  sent: false,
  verified: false,
  lastSentAt: "",
};

const driveFolders = [
  "FinFlow Backup/2026/法人/請求書",
  "FinFlow Backup/2026/法人/領収書",
  "FinFlow Backup/2026/法人/契約書",
  "FinFlow Backup/2026/法人/税務書類",
  "FinFlow Backup/2026/法人/口座明細",
  "FinFlow Backup/2026/個人/領収書",
  "FinFlow Backup/2026/個人/税務書類",
  "FinFlow Backup/2026/個人/口座明細",
  "FinFlow Backup/2026/確認待ち",
];

const ocrRoadmap = [
  {
    title: "前期: Gemini / GPT Vision",
    body: "アップロード直後は外部 API で文字と項目を抽出し、ユーザー修正を学習用に蓄積します。",
  },
  {
    title: "中期: 修正データを学習化",
    body: "確定後の項目差分、OCR原文、書類種別、日付、税率を教師データとして保存します。",
  },
  {
    title: "後期: PaddleOCR 切替",
    body: "蓄積した日本語帳票データを使い、PaddleOCR を主系統にして API コストを下げます。",
  },
];

let bankTransactions = [
  { id: "txn-001", account: "会社銀行口座", date: "2026-04-20", description: "株式会社サンプル 入金", amount: 280000, type: "income", source: "manual_csv", matched: "client_invoice_0420.png" },
  { id: "txn-002", account: "会社クレジットカード", date: "2026-04-01", description: "Meta Ads", amount: -30000, type: "expense", source: "statement_upload", matched: "meta_ads_receipt_april.pdf" },
  { id: "txn-003", account: "個人銀行口座", date: "2026-04-11", description: "NTT Docomo", amount: -8900, type: "expense", source: "manual", matched: "business ratio review" },
];

const bankConnectionStrategy = {
  defaultMode: "manual_csv",
  apiMode: "future_optional",
  reason: "银行/信用卡 API 需要金融机构授权、OAuth、聚合商契约、持续维护和合规审查，MVP 不作为必要条件。",
};

const annualGoal = {
  targetProfit: 3000000,
  minimumCashReserve: 900000,
};

const governmentFeeds = [
  {
    source: "国税庁",
    title: "国税庁ホームページ新着情報・メールマガジン",
    summary: "税に関する新着情報を週次または月次で受け取る公式配信。申告期限、様式、制度変更の確認元にする。",
    url: "https://www.nta.go.jp/merumaga/",
    impact: "申告期限・様式変更・インボイス関連",
  },
  {
    source: "国税庁",
    title: "国税庁 新着情報",
    summary: "国税庁サイトに掲載された税制・手続・通達などの公式更新を監視する。",
    url: "https://www.nta.go.jp/information/news/news.htm",
    impact: "法人税・所得税・消費税・電子申告",
  },
  {
    source: "中小企業庁",
    title: "中小企業向け税制・支援策",
    summary: "中小企業者向け税制、支援策、賃上げ・最低賃金対応支援などを確認する。",
    url: "https://www.chusho.meti.go.jp/zaimu/zeisei/index.html",
    impact: "優遇税制・補助金・中小企業支援",
  },
  {
    source: "e-Gov",
    title: "法令API / 法令検索",
    summary: "法令更新をAPIで取得し、税務・社会保険・会社手続に関連する変更を通知する設計。",
    url: "https://laws.e-gov.go.jp/docs/law-data-basic/8529371-law-api-v1/",
    impact: "法令改正・施行日・条文確認",
  },
];

const taxChecklistRules = [
  { id: "receipts", label: "経費の領収書・請求書を集める", severity: "high" },
  { id: "invoice_number", label: "インボイス登録番号と税率を確認する", severity: "high" },
  { id: "bank_match", label: "銀行/カード明細と証憑を照合する", severity: "high" },
  { id: "due_dates", label: "納付期限・支払期限・契約更新日を確認する", severity: "medium" },
  { id: "personal_company_split", label: "個人/法人の混在支出を分ける", severity: "high" },
  { id: "government_updates", label: "国税庁・中小企業庁の最新情報を確認する", severity: "medium" },
];

const subscriptionPlans = [
  {
    id: "free",
    name: "Free",
    price: 0,
    includedEmployees: 0,
    features: ["本人アカウントのみ", "月20ファイルまで", "OCR mock / 手動確認"],
  },
  {
    id: "team3",
    name: "Team 3",
    price: 1500,
    includedEmployees: 3,
    features: ["员工账号3名", "权限管理", "公告与反馈", "基础报税预估"],
  },
  {
    id: "team6",
    name: "Team 6",
    price: 2500,
    includedEmployees: 6,
    features: ["员工账号6名", "后台关系管理", "广告/公告系统", "优先反馈处理"],
  },
];

const rolePermissions = {
  owner: "用户侧全权限 / 账单 / 员工 / 删除",
  admin: "用户侧成员 / 文件 / 规则管理",
  accountant: "文件确认 / 报税预估 / 导出",
  staff: "上传 / 编辑自己文件",
  viewer: "只读 / 下载授权文件",
};

let subscriptionState = {
  planId: "team3",
  renewalDate: "2026-05-28",
  paymentStatus: "active",
};

let employees = [
  { id: "emp-owner", name: "Owner", email: "owner@finflow.local", role: "owner", status: "active" },
  { id: "emp-001", name: "Tanaka", email: "tanaka@client.jp", role: "accountant", status: "active" },
  { id: "emp-002", name: "Chen", email: "chen@client.jp", role: "staff", status: "invited" },
];

let adminMembers = [
  { id: "m-001", company: "株式会社サンプル", planId: "team3", status: "active", employeesUsed: 2, renewalDate: "2026-05-28" },
  { id: "m-002", company: "個人事業主 Demo", planId: "free", status: "trial", employeesUsed: 0, renewalDate: "2026-05-10" },
  { id: "m-003", company: "合同会社Flow", planId: "team6", status: "active", employeesUsed: 5, renewalDate: "2026-06-03" },
];

let serviceItems = [
  { id: "svc-001", planId: "team3", title: "月次ファイル整理サポート", body: "上传文件分类、员工权限检查、基础报税预估提醒。" },
  { id: "svc-002", planId: "team6", title: "优先行政服务", body: "多账户整理、公告投放、反馈优先处理、服务内容月度更新。" },
];

let announcements = [
  { id: "ann-001", title: "今月の確認", body: "登録番号、税率、納付期限、支払証明がない文件会自动进入确认队列。", active: true },
];

let ads = [
  { id: "ad-001", title: "税理士レビュー预约", target: "报税预估页面", active: true },
];

let feedbackTickets = [
  { id: "fb-001", type: "ocr", priority: "high", status: "open", message: "NTT收据税额识别需要人工确认。", createdAt: "2026-04-28 11:20" },
];

let customers = [
  {
    id: "cus-001",
    name: "株式会社サンプル",
    ownerType: "company",
    invoiceNumber: "T1234567890123",
    corporateNumber: "1234567890123",
    postalCode: "100-0001",
    address: "東京都千代田区千代田1-1",
    contactName: "経理担当",
    department: "経理部",
    email: "accounting@example.jp",
    phone: "03-0000-0000",
    paymentTerms: "月末締め翌月末払い",
    source: "invoice",
    revenue: 280000,
    memo: "請求書発行先。インボイス登録番号確認済み。",
  },
  {
    id: "cus-002",
    name: "Meta Ads",
    ownerType: "company",
    invoiceNumber: "",
    corporateNumber: "",
    postalCode: "",
    address: "",
    contactName: "",
    department: "",
    email: "",
    phone: "",
    paymentTerms: "カード決済",
    source: "receipt",
    revenue: 0,
    memo: "広告費支払先。領収書とカード明細の照合が必要。",
  },
  {
    id: "cus-003",
    name: "NTT Docomo",
    ownerType: "personal",
    invoiceNumber: "",
    corporateNumber: "",
    postalCode: "",
    address: "",
    contactName: "",
    department: "",
    email: "",
    phone: "",
    paymentTerms: "口座/カード引落",
    source: "receipt",
    revenue: 0,
    memo: "個人利用と事業利用割合を確認。",
  },
];

let generatedForms = [
  {
    id: "form-001",
    template: "invoice",
    customer: "株式会社サンプル",
    ownerType: "company",
    amount: 280000,
    status: "draft",
    createdAt: "2026-04-28 12:00",
    title: "2026年4月分 Web制作費",
    issueDate: "2026-04-28",
    dueDate: "2026-05-31",
    itemLabel: "Web制作・運用費",
    quantity: 1,
    unitPrice: 280000,
    taxRate: 10,
    paymentMethod: "銀行振込",
    memo: "お振込確認後、領収データを自動保管します。",
    documentNumber: "INV-2026-0401",
  },
];

let formDraft = {
  direction: "income",
  template: "invoice",
  owner_type: "company",
  customer_query: "株式会社サンプル",
  document_title: "2026年4月分 Web制作費",
  issue_date: "2026-04-29",
  due_date: "2026-05-31",
  valid_until: "2026-05-31",
  expense_date: "2026-05-31",
  amount: 280000,
  item_label: "Web制作・運用費",
  quantity: 1,
  unit_price: 280000,
  tax_rate: 10,
  payment_method: "銀行振込",
  bank_account_note: "三井住友銀行 渋谷支店 普通 1234567",
  requester_department: "",
  approval_owner: "",
  attachment_status: "receipt_attached",
  preset_note: "standard",
  memo: "お振込確認後、領収データを自動保管します。",
};

let documents = [
  {
    id: "doc-001",
    name: "meta_ads_receipt_april.pdf",
    original_name: "meta_ads_receipt_april.pdf",
    renamed_name: "20260401_MetaAds_receipt_30000.pdf",
    fileType: "PDF",
    status: "review",
    archive_status: "pending_review",
    target_directory: "pending_review",
    ai_strategy: "token_saver",
    standard_profile: "jp_invoice",
    document_type: "receipt",
    owner_type: "company",
    transaction_type: "expense",
    date: "2026-04-01",
    created_at: "2026-04-01T10:15",
    issued_at: "2026-04-01",
    due_at: "2026-05-31",
    amount: 30000,
    tax_amount: 2727,
    tax_rate: "10%",
    vendor: "Meta Ads",
    invoice_number: "",
    category: "広告宣伝費",
    payment_method: "credit_card",
    account: "会社クレジットカード",
    tax_deductible: true,
    confidence: 0.91,
    need_review: false,
    summary: "4月分広告費。カード明細との照合候補あり。",
    review_notes: "日本インボイス检查: 金额、税率、税额已识别；登録番号缺失，建议用户确认。AI建议目录: 法人 / 领收书。",
    ocr_text: "Meta Ads Receipt 2026-04-01 JPY 30,000 Tax 2,727",
    hash: "sha256:demo-meta",
    language: "ja/en",
  },
  {
    id: "doc-002",
    name: "client_invoice_0420.png",
    original_name: "client_invoice_0420.png",
    renamed_name: "20260420_株式会社サンプル_invoice_280000.png",
    fileType: "IMG",
    status: "done",
    archive_status: "archived",
    target_directory: "company/invoices",
    ai_strategy: "token_saver",
    standard_profile: "jp_invoice",
    document_type: "invoice",
    owner_type: "company",
    transaction_type: "income",
    date: "2026-04-20",
    created_at: "2026-04-20T13:40",
    issued_at: "2026-04-20",
    due_at: "2026-05-31",
    amount: 280000,
    tax_amount: 25455,
    tax_rate: "10%",
    vendor: "株式会社サンプル",
    invoice_number: "T1234567890123",
    category: "売上",
    payment_method: "bank_transfer",
    account: "会社銀行口座",
    tax_deductible: false,
    confidence: 0.96,
    need_review: false,
    summary: "Web制作案件の請求書。未入金として管理。",
    review_notes: "日本請求書检查: 発行日、登録番号、税率、金额、期限均有。用户确认后已归档。",
    ocr_text: "請求書 株式会社サンプル 合計 280,000円 登録番号 T1234567890123",
    hash: "sha256:demo-invoice",
    language: "ja",
  },
  {
    id: "doc-003",
    name: "personal_phone_bill.pdf",
    original_name: "personal_phone_bill.pdf",
    renamed_name: "20260411_NTTDocomo_receipt_8900.pdf",
    fileType: "PDF",
    status: "review",
    archive_status: "pending_review",
    target_directory: "pending_review",
    ai_strategy: "balanced",
    standard_profile: "jp_invoice",
    document_type: "receipt",
    owner_type: "personal",
    transaction_type: "expense",
    date: "2026-04-11",
    created_at: "2026-04-11T09:05",
    issued_at: "2026-04-11",
    due_at: "2026-04-30",
    amount: 8900,
    tax_amount: 809,
    tax_rate: "10%",
    vendor: "NTT Docomo",
    invoice_number: "",
    category: "通信費",
    payment_method: "credit_card",
    account: "個人クレジットカード",
    tax_deductible: true,
    confidence: 0.74,
    need_review: true,
    summary: "個人カード支払い。事業利用割合の確認が必要。",
    review_notes: "个人/事业混用风险。建议确认业务使用比例后再归档到个人或法人目录。",
    ocr_text: "ご利用料金 8,900円 2026年4月 NTT Docomo",
    hash: "sha256:demo-phone",
    language: "ja",
  },
];

let selectedId = documents[0].id;
let currentFilter = "all";
let currentView = "home";
let currentDirectoryFilter = "";
let currentSmartFilter = "";
let trainingSamples = [];

const tableBody = document.querySelector("#document-table");
const form = document.querySelector("#detail-form");
const searchInput = document.querySelector("#search-input");
const dropZone = document.querySelector("#drop-zone");
const fileInput = document.querySelector("#file-input");
const homeFileInput = document.querySelector("#home-file-input");
const languageSelect = document.querySelector("#language-select");
const taxInputIds = ["personal-deductions", "business-tax-rate", "corporate-local-rate", "consumption-tax-mode"];
const announcementForm = document.querySelector("#announcement-form");
const adForm = document.querySelector("#ad-form");
const feedbackForm = document.querySelector("#feedback-form");
const businessFormGenerator = document.querySelector("#business-form-generator");
const customerSearch = document.querySelector("#customer-search");
const manualTransactionForm = document.querySelector("#manual-transaction-form");
const companyProfileForm = document.querySelector("#company-profile-form");
const personalProfileForm = document.querySelector("#personal-profile-form");
const phoneVerificationForm = document.querySelector("#phone-verification-form");
const previewFormButton = document.querySelector("#preview-form-button");
let ocrRuntime = {
  busy: false,
  message: "OCR未実行",
};

function mockOcrProvider(file) {
  const lower = file.name.toLowerCase();
  const isIncome = lower.includes("invoice") || lower.includes("売上") || lower.includes("income");
  const isBank = lower.includes("bank") || lower.includes("銀行");
  const isContract = lower.includes("contract") || lower.includes("契約");
  const amount = isIncome ? 180000 : lower.includes("tax") ? 52000 : 0;
  const taxAmount = amount ? Math.round(amount / 11) : 0;
  const issuedAt = inferIssueDate(lower) || today;
  const dueAt = isIncome ? addDays(issuedAt, 30) : "";
  const vendor = isIncome ? "新規クライアント" : isBank ? "銀行明細" : file.name.replace(/\.[^.]+$/, "").slice(0, 24) || "未確認書類";
  const documentType = isBank ? "bank_statement" : isContract ? "contract" : isIncome ? "invoice" : "receipt";
  const extension = file.name.includes(".") ? file.name.split(".").pop() : "file";
  const ownerType = lower.includes("personal") || lower.includes("個人") ? "personal" : "company";
  const standardProfile = isBank ? "jp_bank" : isContract ? "jp_contract" : "jp_invoice";

  return {
    id: `doc-${Date.now()}-${Math.round(Math.random() * 9999)}`,
    name: file.name,
    original_name: file.name,
    renamed_name: buildRenamedName({ issued_at: issuedAt, vendor, document_type: documentType, amount, extension }),
    fileType: file.name.split(".").pop()?.toUpperCase() || "FILE",
    status: "review",
    archive_status: "pending_review",
    target_directory: "pending_review",
    ai_strategy: "token_saver",
    standard_profile: standardProfile,
    document_type: documentType,
    owner_type: ownerType,
    transaction_type: isIncome ? "income" : "expense",
    date: issuedAt,
    created_at: toDatetimeLocal(file.lastModified ? new Date(file.lastModified) : new Date()),
    issued_at: issuedAt,
    due_at: dueAt,
    amount,
    tax_amount: taxAmount,
    tax_rate: amount ? "10%" : "",
    vendor,
    invoice_number: "",
    category: isBank ? "銀行明細" : isContract ? "契約書" : isIncome ? "売上" : "要確認",
    payment_method: isBank ? "bank_transfer" : "credit_card",
    account: isIncome || isBank ? "会社銀行口座" : "会社クレジットカード",
    tax_deductible: !isIncome,
    confidence: Number((0.41 + Math.random() * 0.18).toFixed(2)),
    need_review: true,
    summary: "仮解析です。前期は Gemini/GPT API を想定し、ユーザー確認後の修正を学習用に保存します。",
    review_notes: buildReviewNotes({ document_type: documentType, owner_type: ownerType, vendor, amount, issued_at: issuedAt, due_at: dueAt, invoice_number: "" }),
    ocr_text: `preview OCR: ${file.name} / generated at ${new Date().toISOString()}`,
    hash: `sha256:${file.name.length}-${file.size}-${file.lastModified}`,
    language: languageSelect.value === "ja" ? "ja/zh/en" : languageSelect.value,
    ocr_engine: "gemini_or_gpt_phase1",
  };
}

function suggestDirectory(doc) {
  const owner = doc.owner_type === "personal" ? "personal" : "company";
  if (doc.document_type === "invoice") return `${owner}/invoices`;
  if (doc.document_type === "contract") return `${owner}/contracts`;
  if (doc.document_type === "bank_statement") return `${owner}/bank`;
  if (doc.document_type === "tax_document" || doc.category === "税金") return `${owner}/tax`;
  return `${owner}/receipts`;
}

function buildReviewNotes(doc) {
  const checks = [
    doc.issued_at ? "発行日候補あり" : "発行日未確定",
    doc.amount ? "金額候補あり" : "金額未確定",
    doc.tax_amount ? "税額候補あり" : "税額未確定",
    doc.invoice_number ? "登録番号候補あり" : "登録番号未確定",
    doc.due_at ? "期限候補あり" : "期限未確定または対象外",
  ];
  return `前期OCR方針: Gemini/GPT API で抽出し、確定データを将来の PaddleOCR 学習へ回します。確認項目: ${checks.join(" / ")}。仮の整理先: ${suggestDirectory(doc)}。`;
}

function buildRenamedName(doc) {
  const date = (doc.issued_at || doc.date || today).replaceAll("-", "");
  const vendor = sanitizeFilePart(doc.vendor || "unknown");
  const type = sanitizeFilePart(doc.document_type || "document");
  const amount = Math.round(Number(doc.amount || 0));
  const ext = sanitizeFilePart(doc.extension || doc.fileType || "file").toLowerCase();
  return `${date}_${vendor}_${type}_${amount}.${ext}`;
}

function sanitizeFilePart(value) {
  return String(value).trim().replace(/[\\/:*?"<>|\s]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 48) || "unknown";
}

function inferIssueDate(name) {
  const match = name.match(/(20\d{2})[-_]?([01]\d)[-_]?([0-3]\d)/);
  if (!match) return "";
  return `${match[1]}-${match[2]}-${match[3]}`;
}

function addDays(dateString, days) {
  const date = new Date(`${dateString}T00:00:00`);
  date.setDate(date.getDate() + days);
  return date.toISOString().slice(0, 10);
}

function toDatetimeLocal(date) {
  const pad = (number) => String(number).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function activePlan() {
  return subscriptionPlans.find((plan) => plan.id === subscriptionState.planId) || subscriptionPlans[0];
}

function employeeUsage() {
  return employees.filter((employee) => employee.role !== "owner").length;
}

function findOrCreateCustomer(query, ownerType = "company", source = "manual", createIfMissing = true) {
  const name = String(query || "").trim() || "未命名客户";
  const existing = customers.find((customer) => customer.name.toLowerCase() === name.toLowerCase());
  if (existing) return { customer: existing, created: false };
  if (!createIfMissing) {
    return {
      customer: {
        id: "preview-customer",
        name,
        ownerType,
        invoiceNumber: "",
        corporateNumber: "",
        postalCode: "",
        address: "",
        contactName: "",
        department: "",
        email: "",
        phone: "",
        paymentTerms: "",
        source,
        revenue: 0,
        memo: "",
      },
      created: false,
    };
  }
  const customer = {
    id: `cus-${Date.now()}`,
    name,
    ownerType,
    invoiceNumber: "",
    corporateNumber: "",
    postalCode: "",
    address: "",
    contactName: "",
    department: "",
    email: "",
    phone: "",
    paymentTerms: "",
    source,
    revenue: 0,
    memo: "",
  };
  customers.unshift(customer);
  return { customer, created: true };
}

function guessCategory(name) {
  if (name.includes("ads") || name.includes("広告")) return "広告宣伝費";
  if (name.includes("train") || name.includes("taxi") || name.includes("交通")) return "交通費";
  if (name.includes("phone") || name.includes("通信")) return "通信費";
  if (name.includes("rent") || name.includes("家賃")) return "家賃";
  if (name.includes("tax") || name.includes("税")) return "税金";
  return "雑費";
}

function filteredDocuments() {
  const query = searchInput.value.trim().toLowerCase();
  return documents.filter((doc) => {
    const filterMatch =
      currentFilter === "all" ||
      (currentFilter === "unreviewed" && doc.status === "review") ||
      (currentFilter === "company" && doc.owner_type === "company") ||
      (currentFilter === "personal" && doc.owner_type === "personal") ||
      (currentFilter === "tax" && (doc.category === "税金" || doc.document_type === "tax_document")) ||
      (currentFilter === "staged" && doc.archive_status !== "archived");
    const smartMatch =
      !currentSmartFilter ||
      (currentSmartFilter === "income" && doc.transaction_type === "income") ||
      (currentSmartFilter === "expense" && doc.transaction_type === "expense") ||
      (currentSmartFilter === "review" && doc.archive_status !== "archived");
    const directoryMatch = !currentDirectoryFilter || doc.target_directory === currentDirectoryFilter || suggestDirectory(doc) === currentDirectoryFilter;
    const text = `${doc.name} ${doc.vendor} ${doc.category} ${doc.amount} ${doc.target_directory} ${directoryLabel(doc.target_directory)}`.toLowerCase();
    return filterMatch && smartMatch && directoryMatch && text.includes(query);
  });
}

function renderTable() {
  tableBody.innerHTML = filteredDocuments()
    .map(
      (doc) => `
        <tr data-id="${doc.id}" class="${doc.id === selectedId ? "selected" : ""}">
          <td><span class="status-badge ${doc.status === "done" ? "done" : "review"}">${doc.status === "done" ? t("archived") : t("unreviewed")}</span></td>
          <td>${directoryLabel(doc.target_directory)}</td>
          <td>${doc.renamed_name}</td>
          <td>${doc.date}</td>
          <td>${doc.issued_at || "-"}</td>
          <td>${doc.due_at || "-"}</td>
          <td>${doc.vendor}</td>
          <td><span class="type-chip">${t(doc.document_type)}</span></td>
          <td>${doc.owner_type === "company" ? t("company") : t("personal")}</td>
          <td>${doc.category}</td>
          <td class="number">${yen.format(doc.amount)}</td>
          <td>${Math.round(doc.confidence * 100)}%</td>
        </tr>
      `,
    )
    .join("");

  tableBody.querySelectorAll("tr").forEach((row) => {
    row.addEventListener("click", () => {
      selectedId = row.dataset.id;
      render();
    });
  });
}

function renderDirectories() {
  const directories = [
    { key: "company/invoices", label: "法人 / 发票・請求書" },
    { key: "company/receipts", label: "法人 / 领收书" },
    { key: "company/contracts", label: "法人 / 契约书" },
    { key: "company/tax", label: "法人 / 税务" },
    { key: "company/bank", label: "法人 / 银行账户" },
    { key: "personal/receipts", label: "个人 / 领收书" },
    { key: "personal/tax", label: "个人 / 税务" },
    { key: "personal/bank", label: "个人 / 银行账户" },
  ];
  document.querySelector("#directory-grid").innerHTML = directories
    .map((directory) => {
      const count = documents.filter((doc) => doc.target_directory === directory.key && doc.archive_status === "archived").length;
      const pending = documents.filter((doc) => suggestDirectory(doc) === directory.key && doc.archive_status !== "archived").length;
      return `
        <button class="directory-card" data-directory-filter="${directory.key}">
          <strong>${directory.label}</strong>
          <span>已归档 ${count} / 待确认 ${pending}</span>
        </button>
      `;
    })
    .join("");
}

function directoryLabel(directory) {
  const labels = {
    pending_review: t("pendingReview"),
    "company/receipts": `${t("company")} / ${t("receipt")}`,
    "company/invoices": `${t("company")} / ${t("invoice")}`,
    "company/contracts": `${t("company")} / ${t("contract")}`,
    "company/tax": `${t("company")} / ${t("tax_document")}`,
    "company/bank": `${t("company")} / ${t("bank_statement")}`,
    "personal/receipts": `${t("personal")} / ${t("receipt")}`,
    "personal/tax": `${t("personal")} / ${t("tax_document")}`,
    "personal/bank": `${t("personal")} / ${t("bank_statement")}`,
  };
  return labels[directory] || directory || t("pendingReview");
}

function selectedDocument() {
  return documents.find((doc) => doc.id === selectedId) || documents[0];
}

function renderDetail() {
  const doc = selectedDocument();
  if (!doc) return;

  document.querySelector("#detail-title").textContent = doc.vendor;
  const badge = document.querySelector("#detail-status");
  badge.textContent = doc.status === "done" ? "確認済" : "未確認";
  badge.className = `status-badge ${doc.status === "done" ? "done" : "review"}`;
  document.querySelector("#preview-name").textContent = doc.renamed_name || doc.name;
  document.querySelector("#preview-meta").textContent = `original: ${doc.original_name || doc.name} / ${doc.fileType} / ${doc.language} / ${doc.hash}`;
  document.querySelector(".preview-icon").textContent = doc.fileType.slice(0, 4);
  document.querySelector("#confirm-button").textContent = doc.archive_status === "archived" ? t("archivedUpdate") : t("confirmArchive");

  [...form.elements].forEach((field) => {
    if (field.name && doc[field.name] !== undefined) {
      field.value = doc[field.name];
    }
  });
  renderWorkflowSteps(doc);
}

function renderWorkflowSteps(doc) {
  const steps = [
    { label: "上传文件/照片", done: true },
    { label: "本地预处理与版面OCR", done: true },
    { label: "AI按日本商务/税务标准抽取字段", done: true },
    { label: "用户确认个人/法人、类别、金额、期限", done: doc.archive_status === "archived" },
    { label: `写入目录: ${directoryLabel(doc.target_directory)}`, done: doc.archive_status === "archived" },
  ];
  document.querySelector("#workflow-steps").innerHTML = steps
    .map((step) => `<div class="workflow-step ${step.done ? "done" : ""}"><span>${step.done ? "✓" : "•"}</span>${step.label}</div>`)
    .join("");
}

function updateMetrics() {
  const { income, expense, profit } = financeSummary();
  const review = documents.filter((doc) => doc.status === "review" || doc.need_review).length;

  document.querySelector("#monthly-income").textContent = yen.format(income);
  document.querySelector("#monthly-expense").textContent = yen.format(expense);
  document.querySelector("#monthly-profit").textContent = yen.format(profit);
  document.querySelector("#profit-guidance").textContent = profit >= 0 ? "現時点では黒字。納税資金を確保" : "赤字見込み。未請求・未回収を確認";
  document.querySelector("#review-count").textContent = `${review}件`;
  const archived = documents.filter((doc) => doc.archive_status === "archived").length;
  const saving = Math.round(55 + (archived / Math.max(documents.length, 1)) * 25);
  document.querySelector("#token-saving").textContent = `${saving}%`;
}

function renderIncome() {
  const confirmedIncome = documents.filter((doc) => doc.transaction_type === "income");
  const total = confirmedIncome.reduce((sum, doc) => sum + Number(doc.amount), 0);
  const byClient = groupSum(confirmedIncome, "vendor");
  const byChannel = {
    銀行入金: total * 0.65,
    Stripe: total * 0.2,
    PayPay: total * 0.1,
    現金: total * 0.05,
  };

  document.querySelector("#income-grid").innerHTML = [
    analysisCard("月度収入", yen.format(total), "請求書・入金・手入力を統合", 88),
    analysisCard("未収候補", yen.format(Math.max(0, total - 120000)), "入金照合待ち", 42),
    ...Object.entries(byClient).map(([name, value]) => analysisCard(name, yen.format(value), "顧客別売上", 64)),
    ...Object.entries(byChannel).map(([name, value]) => analysisCard(name, yen.format(value), "チャネル別推定", 50)),
  ].join("");
}

function analysisCard(label, value, note, progress) {
  return `
    <article class="analysis-card">
      <span>${label}</span>
      <strong>${value}</strong>
      <small>${note}</small>
      <div class="progress-bar"><i style="width:${Math.min(progress, 100)}%"></i></div>
    </article>
  `;
}

function groupSum(items, key) {
  return items.reduce((acc, item) => {
    acc[item[key]] = (acc[item[key]] || 0) + Number(item.amount);
    return acc;
  }, {});
}

function financeSummary() {
  const confirmed = documents.filter((doc) => doc.status === "done");
  const income = confirmed.filter((doc) => doc.transaction_type === "income").reduce((sum, doc) => sum + Number(doc.amount), 0);
  const expense = confirmed.filter((doc) => doc.transaction_type === "expense").reduce((sum, doc) => sum + Number(doc.amount), 0);
  return { income, expense, profit: income - expense };
}

function missingIssues() {
  const issues = [];
  documents.forEach((doc) => {
    if (doc.archive_status !== "archived") issues.push({ doc, label: "未归档确认" });
    if (!doc.invoice_number && ["invoice", "receipt"].includes(doc.document_type)) issues.push({ doc, label: "登録番号未确认" });
    if (!doc.due_at && ["invoice", "contract", "tax_document"].includes(doc.document_type)) issues.push({ doc, label: "期限缺失" });
    if (doc.owner_type === "personal" && doc.tax_deductible) issues.push({ doc, label: "个人/事业比例需确认" });
    if (doc.confidence < 0.8) issues.push({ doc, label: "AI信赖度低" });
  });
  return issues;
}

function renderActionBoard() {
  const summary = financeSummary();
  const issues = missingIssues();
  const gap = annualGoal.targetProfit - summary.profit;
  const profitState = summary.profit >= 0 ? "目前是黒字" : "目前是赤字";
  document.querySelector("#simple-action-board").innerHTML = `
    <article class="action-card primary-action">
      <span>今年の着地見込み</span>
      <strong>${profitState} / ${yen.format(summary.profit)}</strong>
      <small>目標利益 ${yen.format(annualGoal.targetProfit)}、不足 ${yen.format(Math.max(0, gap))}</small>
    </article>
    <article class="action-card">
      <span>今日の優先確認</span>
      <strong>${issues.length ? issues[0].label : "急ぎの確認はありません"}</strong>
      <small>${issues.length ? issues[0].doc.vendor + " / " + issues[0].doc.renamed_name : "今月分の領収書と口座明細を続けて追加"}</small>
    </article>
    <article class="action-card">
      <span>申告ミス防止</span>
      <strong>${issues.length} 件の見直し候補</strong>
      <small>都民税、期限、証憑不足、個人/法人混在、税率不明を優先表示</small>
    </article>
  `;
}

function renderReadiness() {
  const issues = missingIssues();
  const resolvedRatio = Math.max(0, Math.round(100 - (issues.length / Math.max(documents.length * 3, 1)) * 100));
  document.querySelector("#readiness-score").innerHTML = `
    <article class="readiness-card">
      <span>申告準備度</span>
      <strong>${resolvedRatio}%</strong>
      <small>目标是让报税前不用回头找单据、付款证明、期限和文字说明。</small>
      <div class="progress-bar"><i style="width:${resolvedRatio}%"></i></div>
    </article>
    <article class="readiness-card">
      <span>年度目标</span>
      <strong>${yen.format(annualGoal.targetProfit)}</strong>
      <small>当前利润 ${yen.format(financeSummary().profit)}，系统会提示还差多少。</small>
    </article>
  `;

  document.querySelector("#tax-checklist").innerHTML = taxChecklistRules
    .map((rule) => {
      const related = issues.filter((issue) => {
        if (rule.id === "receipts") return issue.label.includes("未归档");
        if (rule.id === "invoice_number") return issue.label.includes("登録番号");
        if (rule.id === "due_dates") return issue.label.includes("期限");
        if (rule.id === "personal_company_split") return issue.label.includes("个人");
        if (rule.id === "bank_match") return issue.doc.document_type === "bank_statement";
        return false;
      });
      return `
        <article class="checklist-item ${related.length ? "needs-work" : "done"}">
          <div>
            <strong>${rule.label}</strong>
            <span>${related.length ? related.length + " 件需要确认" : "当前没有明显漏项"}</span>
          </div>
          <span>${rule.severity}</span>
        </article>
      `;
    })
    .join("");
}

function renderPolicyUpdates() {
  const html = governmentFeeds
    .map(
      (feed) => `
        <article class="policy-card">
          <span>${feed.source}</span>
          <strong>${feed.title}</strong>
          <p>${feed.summary}</p>
          <small>影响: ${feed.impact}</small>
          <a href="${feed.url}" target="_blank" rel="noreferrer">公式ページを確認</a>
        </article>
      `,
    )
    .join("");

  document.querySelectorAll("#home-policy-list, #policy-list").forEach((list) => {
    list.innerHTML = html;
  });
}

function renderOcrRoadmap() {
  const node = document.querySelector("#ocr-mode-board");
  if (!node) return;
  node.innerHTML =
    `<article class="ocr-mode-card">
      <strong>現在の状態</strong>
      <span>${escapeHtml(ocrRuntime.message)}</span>
    </article>` +
    ocrRoadmap
    .map(
      (item) => `
        <article class="ocr-mode-card">
          <strong>${item.title}</strong>
          <span>${item.body}</span>
        </article>
      `,
    )
    .join("");
}

function renderAccounts() {
  bindProfileForm(companyProfileForm, companyProfile);
  bindProfileForm(personalProfileForm, personalProfile);
  renderPhoneVerification();
  document.querySelector("#account-list").innerHTML = accounts
    .map(
      (account) => `
        <article class="account-card">
          <div>
            <span>${accountOwnerLabel(account.owner)} / ${accountTypeLabel(account.type)} / ${connectionLabel(account.connection)}</span>
            <strong>${account.name}</strong>
            <div class="progress-bar"><i style="width:${account.progress}%"></i></div>
          </div>
          <div class="number">
            <strong>${yen.format(account.balance)}</strong>
            <span>${account.mixed ? "混用確認あり" : "整理済み"}</span>
          </div>
        </article>
      `,
    )
    .join("");
  renderTransactions();
  renderDriveStructure();
}

function bindProfileForm(formNode, source) {
  if (!formNode) return;
  [...formNode.elements].forEach((field) => {
    if (field.name && source[field.name] !== undefined) field.value = source[field.name];
  });
}

function connectionLabel(connection) {
  const labels = {
    manual: "手入力",
    manual_csv: "CSV取込",
    statement_upload: "明細アップロード",
    api_future: "API連携予定",
  };
  return labels[connection] || connection;
}

function accountOwnerLabel(owner) {
  return {
    company: "法人",
    personal: "個人",
    mixed: "混在",
  }[owner] || owner;
}

function accountTypeLabel(type) {
  return {
    bank: "銀行口座",
    credit_card: "カード",
    payment: "決済口座",
  }[type] || type;
}

function renderTransactions() {
  document.querySelector("#transaction-list").innerHTML = `
    <div class="section-heading compact">
      <h3>入出金一覧</h3>
      <p>手入力、CSV、明細アップロードをまとめ、証憑との照合漏れを防ぎます。</p>
    </div>
    ${bankTransactions
      .map(
        (txn) => `
          <article class="transaction-row">
            <div>
              <strong>${escapeHtml(txn.description)}</strong>
              <span>${txn.date} / ${txn.account} / ${connectionLabel(txn.source)}</span>
            </div>
            <div class="number">
              <strong>${yen.format(txn.amount)}</strong>
              <span>照合: ${escapeHtml(txn.matched || "未照合")}</span>
            </div>
          </article>
        `,
      )
      .join("")}
  `;
}

function renderPhoneVerification() {
  const status = document.querySelector("#verification-status");
  if (!status) return;
  const sentLabel = phoneVerification.sent ? `送信済み ${phoneVerification.lastSentAt}` : "未送信";
  const verifyLabel = phoneVerification.verified ? "電話確認済み" : "電話確認前";
  status.innerHTML = `
    <span class="status-badge ${phoneVerification.verified ? "done" : "review"}">${verifyLabel}</span>
    <small>${phoneVerification.phone || "番号未入力"} / ${sentLabel}</small>
  `;
}

function renderDriveStructure() {
  const node = document.querySelector("#drive-structure");
  if (!node) return;
  node.innerHTML = `
    <div class="drive-folder-list">
      ${driveFolders.map((folder) => `<article class="drive-folder-row"><strong>${folder}</strong><span>年度・区分・書類種別で整理</span></article>`).join("")}
    </div>
  `;
}

function renderNotices() {
  const activeAnnouncements = announcements.filter((item) => item.active);
  const activeAds = ads.filter((item) => item.active);
  document.querySelector("#notice-strip").innerHTML = [...activeAnnouncements, ...activeAds]
    .slice(0, 3)
    .map((item) => {
      const label = item.target ? "AD" : "公告";
      const body = item.body || item.target;
      return `
        <article class="notice-item">
          <div><strong>${label}: ${escapeHtml(item.title)}</strong><span>${escapeHtml(body)}</span></div>
          <span>${activePlan().name} / ${yen.format(activePlan().price)}月</span>
        </article>
      `;
    })
    .join("");
}

function renderMembership() {
  const currentPlan = activePlan();
  document.querySelector("#plan-grid").innerHTML = subscriptionPlans
    .map(
      (plan) => `
        <article class="plan-card ${plan.id === currentPlan.id ? "active-plan" : ""}">
          <span>${plan.id === currentPlan.id ? "当前会员" : "可选择"}</span>
          <h4>${plan.name}</h4>
          <div class="plan-price">${yen.format(plan.price)}<span>/月</span></div>
          <ul class="plan-features">
            ${plan.features.map((feature) => `<li>${escapeHtml(feature)}</li>`).join("")}
          </ul>
          <button class="${plan.id === currentPlan.id ? "secondary-button" : "confirm-button"}" data-plan-id="${plan.id}">
            ${plan.id === currentPlan.id ? "使用中" : "切换方案"}
          </button>
        </article>
      `,
    )
    .join("");

  const used = employeeUsage();
  document.querySelector("#employee-quota").textContent = `员工账号 ${used}/${currentPlan.includedEmployees}，续费日 ${subscriptionState.renewalDate}`;
  document.querySelector("#employee-table").innerHTML = employees
    .map(
      (employee) => `
        <tr>
          <td>${escapeHtml(employee.name)}</td>
          <td>${escapeHtml(employee.email)}</td>
          <td>
            <select class="role-select" data-employee-id="${employee.id}" ${employee.role === "owner" ? "disabled" : ""}>
              ${Object.keys(rolePermissions)
                .map((role) => `<option value="${role}" ${employee.role === role ? "selected" : ""}>${role}</option>`)
                .join("")}
            </select>
          </td>
          <td>
            <select class="status-select" data-employee-status-id="${employee.id}" ${employee.role === "owner" ? "disabled" : ""}>
              ${["active", "invited", "suspended"]
                .map((status) => `<option value="${status}" ${employee.status === status ? "selected" : ""}>${status}</option>`)
                .join("")}
            </select>
          </td>
          <td>${rolePermissions[employee.role]}</td>
        </tr>
      `,
    )
    .join("");
}

function renderAdmin() {
  const memberList = document.querySelector("#admin-member-list");
  const serviceEditor = document.querySelector("#service-editor");
  const announcementList = document.querySelector("#announcement-list");
  const adList = document.querySelector("#ad-list");
  if (!memberList || !serviceEditor || !announcementList || !adList) return;

  memberList.innerHTML = adminMembers
    .map((member) => {
      const plan = subscriptionPlans.find((item) => item.id === member.planId) || subscriptionPlans[0];
      return `
        <div class="admin-row">
          <strong>${escapeHtml(member.company)}</strong>
          <span class="admin-row-meta">${plan.name} / ${yen.format(plan.price)}月 / ${member.status} / 员工 ${member.employeesUsed}/${plan.includedEmployees} / 续费 ${member.renewalDate}</span>
        </div>
      `;
    })
    .join("");

  serviceEditor.innerHTML = serviceItems
    .map(
      (service) => `
        <div class="service-row">
          <strong>${escapeHtml(service.title)}</strong>
          <span class="service-row-meta">${service.planId}</span>
          <textarea data-service-id="${service.id}">${escapeHtml(service.body)}</textarea>
        </div>
      `,
    )
    .join("");

  announcementList.innerHTML = announcements
    .map(
      (item) => `
        <div class="ad-row">
          <strong>${escapeHtml(item.title)}</strong>
          <span class="ad-row-meta">${escapeHtml(item.body)} / ${item.active ? "active" : "hidden"}</span>
          <button class="secondary-button" data-toggle-announcement="${item.id}">${item.active ? "隐藏" : "显示"}</button>
        </div>
      `,
    )
    .join("");

  adList.innerHTML = ads
    .map(
      (item) => `
        <div class="ad-row">
          <strong>${escapeHtml(item.title)}</strong>
          <span class="ad-row-meta">${escapeHtml(item.target)} / ${item.active ? "active" : "hidden"}</span>
          <button class="secondary-button" data-toggle-ad="${item.id}">${item.active ? "停止" : "投放"}</button>
        </div>
      `,
    )
    .join("");
}

function renderGeneratedForms() {
  renderFormPreview();
  document.querySelector("#generated-forms").innerHTML = generatedForms
    .map(
      (formItem) => `
        <article class="feedback-ticket">
          <strong>${formTemplateLabel(formItem.template)} - ${escapeHtml(formItem.customer)}</strong>
          <div class="ticket-meta">
            <span>${formItem.ownerType === "company" ? "法人" : "個人"}</span>
            <span>${yen.format(formItem.amount)}</span>
            <span>${formItem.documentNumber || "下書き"}</span>
            <span>${formItem.createdAt}</span>
          </div>
        </article>
      `,
    )
    .join("");
}

function formTemplateLabel(template) {
  const labels = {
    invoice: "請求書",
    quotation: "見積書",
    receipt: "領収書",
    delivery_note: "納品書",
    payment_request: "支払依頼書",
    tax_summary: "申告チェック表",
  };
  return labels[template] || template;
}

function currentFormDraft() {
  const data = new FormData(businessFormGenerator);
  return {
    direction: String(data.get("direction") || formDraft.direction || "income"),
    template: String(data.get("template") || formDraft.template),
    owner_type: String(data.get("owner_type") || formDraft.owner_type),
    customer_query: String(data.get("customer_query") || formDraft.customer_query),
    document_title: String(data.get("document_title") || formDraft.document_title),
    issue_date: String(data.get("issue_date") || formDraft.issue_date),
    due_date: String(data.get("due_date") || formDraft.due_date),
    valid_until: String(data.get("valid_until") || formDraft.valid_until),
    expense_date: String(data.get("expense_date") || formDraft.expense_date),
    amount: Number(data.get("amount") || formDraft.amount || 0),
    item_label: String(data.get("item_label") || formDraft.item_label),
    quantity: Number(data.get("quantity") || formDraft.quantity || 1),
    unit_price: Number(data.get("unit_price") || formDraft.unit_price || 0),
    tax_rate: Number(data.get("tax_rate") || formDraft.tax_rate || 10),
    payment_method: String(data.get("payment_method") || formDraft.payment_method),
    bank_account_note: String(data.get("bank_account_note") || formDraft.bank_account_note),
    requester_department: String(data.get("requester_department") || formDraft.requester_department),
    approval_owner: String(data.get("approval_owner") || formDraft.approval_owner),
    attachment_status: String(data.get("attachment_status") || formDraft.attachment_status),
    preset_note: String(data.get("preset_note") || formDraft.preset_note),
    memo: String(data.get("memo") || formDraft.memo),
  };
}

function presetNoteText(key) {
  return {
    standard: "お支払期限までにお振込をお願いいたします。",
    tax_followup: "保存用として発行し、申告資料に添付できる形式で保管します。",
    urgent: "恐れ入りますが、お早めのお手続きをお願いいたします。",
    expense_clear: "支払内容と証憑を確認のうえ、精算または振込処理をお願いいたします。",
  }[key] || "お支払期限までにお振込をお願いいたします。";
}

function templatesForDirection(direction) {
  if (direction === "expense") {
    return [
      { value: "payment_request", label: "支払依頼書" },
      { value: "tax_summary", label: "経費精算書" },
      { value: "receipt", label: "領収書整理票" },
    ];
  }
  return [
    { value: "quotation", label: "見積書" },
    { value: "invoice", label: "請求書" },
    { value: "delivery_note", label: "納品書" },
    { value: "receipt", label: "領収書" },
  ];
}

function syncFormMode() {
  if (!businessFormGenerator) return;
  const direction = String(new FormData(businessFormGenerator).get("direction") || formDraft.direction || "income");
  const templateSelect = businessFormGenerator.elements.namedItem("template");
  const options = templatesForDirection(direction);
  templateSelect.innerHTML = options.map((item) => `<option value="${item.value}">${item.label}</option>`).join("");
  const valid = options.some((item) => item.value === formDraft.template);
  templateSelect.value = valid ? formDraft.template : options[0].value;
  formDraft.template = templateSelect.value;
  businessFormGenerator.querySelectorAll(".income-only").forEach((node) => node.classList.toggle("hidden", direction !== "income"));
  businessFormGenerator.querySelectorAll(".expense-only").forEach((node) => node.classList.toggle("hidden", direction !== "expense"));
}

function renderFormPreview(forceOpenMobile = false) {
  const previewNode = document.querySelector("#form-preview");
  if (!previewNode || !businessFormGenerator) return;
  formDraft = currentFormDraft();
  syncFormMode();
  formDraft = currentFormDraft();
  previewNode.classList.toggle("mobile-preview-open", forceOpenMobile);
  const result = findOrCreateCustomer(formDraft.customer_query, formDraft.owner_type, "preview", false);
  const customer = result.customer;
  const sender = formDraft.owner_type === "company" ? companyProfile : personalProfile;
  const subtotal = formDraft.unit_price * Math.max(1, formDraft.quantity);
  const total = formDraft.amount || subtotal;
  const taxAmount = formDraft.tax_rate ? Math.round(total * (formDraft.tax_rate / (100 + formDraft.tax_rate))) : 0;
  const isExpense = formDraft.direction === "expense";
  const titleLabel = isExpense ? "支払先" : "宛先";
  const senderLabel = isExpense ? "申請元" : "発行元";
  const dueLabel = isExpense ? "支払予定日" : formDraft.template === "quotation" ? "見積有効期限" : "支払期限";
  const dueValue = isExpense ? formDraft.expense_date || formDraft.due_date : formDraft.template === "quotation" ? formDraft.valid_until || formDraft.due_date : formDraft.due_date;
  previewNode.innerHTML = `
    <article class="jp-form-sheet">
      <div class="jp-form-head">
        <div>
          <span>${formTemplateLabel(formDraft.template)}</span>
          <strong>${escapeHtml(formDraft.document_title || "件名未入力")}</strong>
        </div>
        <div class="jp-form-number">
          <span>No.</span>
          <strong>${formNumber(formDraft.template)}</strong>
        </div>
      </div>
      <div class="jp-form-meta">
        <div><span>発行日</span><strong>${formDraft.issue_date || "-"}</strong></div>
        <div><span>${dueLabel}</span><strong>${dueValue || "-"}</strong></div>
        <div><span>税率</span><strong>${formDraft.tax_rate}%</strong></div>
      </div>
      <div class="jp-form-parties">
        <section>
          <span>${titleLabel}</span>
          <strong>${escapeHtml(customer.name || "取引先未入力")}</strong>
          <p>${escapeHtml(customer.address || "住所未登録")}</p>
          <p>${escapeHtml(customer.contactName || "担当未登録")} / ${escapeHtml(customer.phone || "電話未登録")}</p>
        </section>
        <section>
          <span>${senderLabel}</span>
          <strong>${escapeHtml(sender.companyName || sender.fullName || "発行元未入力")}</strong>
          <p>${escapeHtml(sender.address || "")}</p>
          <p>${escapeHtml(sender.phone || "")} / ${escapeHtml(sender.email || "")}</p>
        </section>
      </div>
      <table class="jp-form-table">
        <thead>
          <tr><th>内容</th><th>数量</th><th>単価</th><th>金額</th></tr>
        </thead>
        <tbody>
          <tr>
            <td>${escapeHtml(formDraft.item_label || "内容未入力")}</td>
            <td>${Math.max(1, formDraft.quantity)}</td>
            <td>${yen.format(formDraft.unit_price || total)}</td>
            <td>${yen.format(total)}</td>
          </tr>
        </tbody>
      </table>
      <div class="jp-form-total">
        <div><span>小計</span><strong>${yen.format(total)}</strong></div>
        <div><span>消費税</span><strong>${yen.format(taxAmount)}</strong></div>
        <div><span>合計</span><strong>${yen.format(total)}</strong></div>
      </div>
      <div class="jp-form-note">
        <span>支払方法</span>
        <p>${escapeHtml(formDraft.payment_method || "未入力")}</p>
        ${isExpense ? `<span>申請情報</span><p>${escapeHtml(formDraft.requester_department || "部門未入力")} / ${escapeHtml(formDraft.approval_owner || "承認者未入力")} / ${escapeHtml(formDraft.attachment_status || "添付未入力")}</p>` : `<span>振込先</span><p>${escapeHtml(formDraft.bank_account_note || "未入力")}</p>`}
        <span>備考</span>
        <p>${escapeHtml(formDraft.memo || presetNoteText(formDraft.preset_note))}</p>
      </div>
    </article>
  `;
}

function formNumber(template) {
  const prefix = { invoice: "INV", quotation: "QT", receipt: "RC", delivery_note: "DN", payment_request: "PR", tax_summary: "TX" }[template] || "FM";
  return `${prefix}-2026-04`;
}

function renderCustomers() {
  const query = customerSearch.value.trim().toLowerCase();
  const visible = customers.filter((customer) =>
    `${customer.name} ${customer.email} ${customer.phone} ${customer.invoiceNumber} ${customer.corporateNumber} ${customer.address} ${customer.contactName}`
      .toLowerCase()
      .includes(query),
  );
  const createHint =
    query && visible.length === 0
      ? `<article class="feedback-ticket"><strong>「${escapeHtml(customerSearch.value)}」はまだ登録されていません</strong><span>このまま新規登録すると、あとで請求書や申告資料にも使えます。</span></article>`
      : "";
  document.querySelector("#customer-list").innerHTML =
    createHint +
    visible
      .map(
        (customer) => `
          <article class="customer-card" data-customer-id="${customer.id}">
            <div class="customer-card-header">
              <div>
                <strong>${escapeHtml(customer.name)}</strong>
                <span>${customer.ownerType === "company" ? "法人取引先" : "個人取引先"} / 登録元: ${customer.source} / 売上 ${yen.format(customer.revenue)}</span>
              </div>
              <button class="secondary-button" data-save-customer="${customer.id}">保存</button>
            </div>
            <div class="customer-edit-grid">
              ${customerInput(customer, "name", "客户/厂商名")}
              <label>
                区分
                <select data-customer-field="ownerType">
                  <option value="company" ${customer.ownerType === "company" ? "selected" : ""}>法人</option>
                  <option value="personal" ${customer.ownerType === "personal" ? "selected" : ""}>個人</option>
                </select>
              </label>
              ${customerInput(customer, "invoiceNumber", "登録番号")}
              ${customerInput(customer, "corporateNumber", "法人番号")}
              ${customerInput(customer, "postalCode", "郵便番号")}
              ${customerInput(customer, "address", "住所")}
              ${customerInput(customer, "contactName", "担当者")}
              ${customerInput(customer, "department", "部署")}
              ${customerInput(customer, "email", "Email")}
              ${customerInput(customer, "phone", "電話")}
              ${customerInput(customer, "paymentTerms", "支払条件")}
              <label class="wide">
                メモ / 申告確認事項
                <textarea data-customer-field="memo" rows="2">${escapeHtml(customer.memo || "")}</textarea>
              </label>
            </div>
          </article>
        `,
      )
      .join("");
}

function customerInput(customer, field, label) {
  return `
    <label>
      ${label}
      <input data-customer-field="${field}" value="${escapeHtml(customer[field] || "")}" />
    </label>
  `;
}

function renderFeedback() {
  document.querySelector("#feedback-list").innerHTML = feedbackTickets
    .map(
      (ticket) => `
        <article class="feedback-ticket">
          <strong>${escapeHtml(ticket.message)}</strong>
          <div class="ticket-meta">
            <span>${ticket.type}</span>
            <span>${ticket.priority}</span>
            <span>${ticket.createdAt}</span>
          </div>
          <select class="status-select" data-feedback-id="${ticket.id}">
            ${["open", "in_review", "resolved", "closed"]
              .map((status) => `<option value="${status}" ${ticket.status === status ? "selected" : ""}>${status}</option>`)
              .join("")}
          </select>
        </article>
      `,
    )
    .join("");
}

function taxableProfit(ownerType) {
  const confirmed = documents.filter((doc) => doc.status === "done" && doc.owner_type === ownerType);
  const income = confirmed.filter((doc) => doc.transaction_type === "income").reduce((sum, doc) => sum + Number(doc.amount), 0);
  const expense = confirmed.filter((doc) => doc.transaction_type === "expense").reduce((sum, doc) => sum + Number(doc.amount), 0);
  return { income, expense, profit: Math.max(0, income - expense) };
}

function calcIncomeTax(taxableIncome) {
  const rounded = Math.floor(Math.max(0, taxableIncome) / 1000) * 1000;
  const bracket = incomeTaxBrackets.find((item) => rounded >= item.min && rounded <= item.max) || incomeTaxBrackets[0];
  return Math.max(0, Math.round(rounded * bracket.rate - bracket.deduction));
}

function calcCorporateTax(taxableIncome) {
  const firstBand = Math.min(Math.max(0, taxableIncome), 8000000) * 0.15;
  const secondBand = Math.max(0, taxableIncome - 8000000) * 0.232;
  return Math.round(firstBand + secondBand);
}

function renderTax() {
  const personal = taxableProfit("personal");
  const corporate = taxableProfit("company");
  const personalDeductions = Number(document.querySelector("#personal-deductions").value || 0);
  const businessTaxRate = Number(document.querySelector("#business-tax-rate").value || 0) / 100;
  const corporateLocalRate = Number(document.querySelector("#corporate-local-rate").value || 0) / 100;
  const consumptionMode = document.querySelector("#consumption-tax-mode").value;

  const personalTaxable = Math.max(0, personal.profit - personalDeductions);
  const nationalIncomeTax = calcIncomeTax(personalTaxable);
  const reconstructionTax = Math.round(nationalIncomeTax * 0.021);
  const residentTaxEstimate = Math.round(personalTaxable * 0.1);
  const personalBusinessTax = Math.round(Math.max(0, personal.profit - 2900000) * businessTaxRate);

  const corporateTaxable = corporate.profit;
  const nationalCorporateTax = calcCorporateTax(corporateTaxable);
  const localCorporateEstimate = Math.round(corporateTaxable * corporateLocalRate);
  const localCorporateTax = Math.round(nationalCorporateTax * 0.103);

  const taxableSales = documents
    .filter((doc) => doc.status === "done" && doc.transaction_type === "income")
    .reduce((sum, doc) => sum + Number(doc.amount), 0);
  const inputTax = documents
    .filter((doc) => doc.status === "done" && doc.transaction_type === "expense" && doc.tax_deductible)
    .reduce((sum, doc) => sum + Number(doc.tax_amount || 0), 0);
  const outputTax = Math.round(taxableSales / 11);
  const consumptionTax = consumptionMode === "taxable" ? Math.max(0, outputTax - inputTax) : 0;

  document.querySelector("#tax-results").innerHTML = `
    ${taxCard("個人事業主", [
      ["売上", yen.format(personal.income)],
      ["経費", yen.format(personal.expense)],
      ["事業利益", yen.format(personal.profit)],
      ["課税所得見込", yen.format(personalTaxable)],
      ["所得税", yen.format(nationalIncomeTax)],
      ["復興特別所得税", yen.format(reconstructionTax)],
      ["住民税概算", yen.format(residentTaxEstimate)],
      ["個人事業税概算", yen.format(personalBusinessTax)],
      ["合計概算", yen.format(nationalIncomeTax + reconstructionTax + residentTaxEstimate + personalBusinessTax)],
    ])}
    ${taxCard("法人", [
      ["売上", yen.format(corporate.income)],
      ["損金", yen.format(corporate.expense)],
      ["所得見込", yen.format(corporateTaxable)],
      ["法人税", yen.format(nationalCorporateTax)],
      ["地方法人税 10.3%", yen.format(localCorporateTax)],
      ["法人住民税・事業税概算", yen.format(localCorporateEstimate)],
      ["合計概算", yen.format(nationalCorporateTax + localCorporateTax + localCorporateEstimate)],
    ])}
    ${taxCard("消費税 / インボイス", [
      ["課税売上推定", yen.format(taxableSales)],
      ["売上消費税推定", yen.format(outputTax)],
      ["仕入税額控除候補", yen.format(inputTax)],
      ["納付見込", yen.format(consumptionTax)],
    ])}
    <p class="tax-note">これは申告前の概算です。控除、青色申告、給与、社会保険、繰越欠損金、簡易課税、2割特例、地方税率、業種、法人規模で結果が変わります。${taxSources.join(" / ")} を基礎に、申告時は国税庁・自治体・税理士確認が必要です。</p>
  `;
}

function taxCard(title, rows) {
  return `
    <article class="tax-card">
      <h4>${title}</h4>
      ${rows.map(([label, value]) => `<div class="tax-line"><span>${label}</span><strong>${value}</strong></div>`).join("")}
    </article>
  `;
}

function renderTraining() {
  const rows = trainingSamples.length
    ? trainingSamples
    : [
        {
          id: "sample-placeholder",
          file: "確認済みにするとここへ保存",
          engine: "mock-gpt-vision",
          fields: "document_type, amount, category, owner_type",
          time: "-",
        },
      ];

  document.querySelector("#training-log").innerHTML = rows
    .map(
      (sample) => `
        <article class="log-item">
          <strong>${sample.file}</strong>
          <span>engine: ${sample.engine}</span>
          <span>changed_fields: ${sample.fields}</span>
          <span>time: ${sample.time}</span>
        </article>
      `,
    )
    .join("");
}

function normalizeLanguage() {
  const replacements = phraseMap[appLang] || {};
  document.documentElement.lang = appLang;
  applyStaticLabels();
  document.querySelector(".primary-upload").lastChild.textContent = ` ${t("upload")}`;
  document.querySelectorAll("[data-filter]").forEach((button) => {
    const key = button.dataset.filter;
    if (uiText[appLang]?.[key]) button.textContent = t(key);
  });
  ["placeholder", "title", "aria-label"].forEach((attr) => {
    document.querySelectorAll(`[${attr}]`).forEach((node) => {
      let value = node.getAttribute(attr);
      Object.entries(replacements).forEach(([from, to]) => {
        value = value.split(from).join(to);
      });
      node.setAttribute(attr, value);
    });
  });
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  const nodes = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  nodes.forEach((node) => {
    let value = node.nodeValue;
    Object.entries(replacements).forEach(([from, to]) => {
      value = value.split(from).join(to);
    });
    node.nodeValue = value;
  });
}

function applyStaticLabels() {
  const labels = {
    ja: {
      nav: ["ホーム", "申告チェック", "書類一覧", "口座・プロフィール", "損益一覧", "税額見込み", "取引先管理", "帳票作成", "会員・権限", "ご意見", "学習履歴"],
      eyebrow: "2026年度 / 個人事業 + 法人",
      title: "日本の中小企業向け 申告もれ防止ワークスペース",
      metrics: ["年度売上", "年度支出", "今年の利益見込み", "漏れ・確認待ち", "AI使用量削減"],
      metricNotes: ["確認済み入金 / 請求書", "証憑あり経費 / 未確認あり", "黒字/赤字を自動判定", "領収書・期限・登録番号", "局所OCR・低信頼度のみAI再判定"],
      headers: ["状態", "整理先", "保存名", "日付", "発行日", "期限", "取引先", "種別", "法人/個人", "分類", "金額", "信頼度"],
      search: "検索: 店舗名、分類、金額",
    },
    "zh-Hant": {
      nav: ["首頁", "申報檢查", "文件列表", "帳戶與資料", "損益列表", "稅額預估", "客戶管理", "表單生成", "會員與權限", "意見回饋", "學習紀錄"],
      eyebrow: "2026年度 / 個人事業主 + 法人",
      title: "日本中小企業稅務防漏工作台",
      metrics: ["年度收入", "年度支出", "今年預估損益", "缺漏與待確認", "AI使用量節省"],
      metricNotes: ["已確認入金 / 請求書", "有憑證支出 / 含未確認", "自動判斷盈利/虧損", "收據・期限・登錄號碼", "只對局部OCR與低可信度內容再判定"],
      headers: ["狀態", "歸檔目錄", "保存名稱", "日期", "發行日", "期限", "交易對象", "類型", "法人/個人", "分類", "金額", "可信度"],
      search: "搜尋：店名、分類、金額",
    },
    "zh-Hans": {
      nav: ["首页", "申报检查", "文件列表", "账户与资料", "损益列表", "税额预估", "客户管理", "表单生成", "会员与权限", "意见反馈", "学习记录"],
      eyebrow: "2026年度 / 个人事业主 + 法人",
      title: "日本中小企业税务防漏工作台",
      metrics: ["年度收入", "年度支出", "今年预估盈亏", "缺漏与待确认", "AI使用量节省"],
      metricNotes: ["已确认入金 / 请求书", "有凭证支出 / 含未确认", "自动判断盈利/亏损", "收据・期限・登记号码", "只对局部OCR与低可信度内容再判定"],
      headers: ["状态", "归档目录", "保存名称", "日期", "发行日", "期限", "交易对象", "类型", "法人/个人", "分类", "金额", "可信度"],
      search: "搜索：店名、分类、金额",
    },
    en: {
      nav: ["Home", "Filing check", "Documents", "Accounts", "P&L", "Tax estimate", "Customers", "Forms", "Membership", "Feedback", "Training log"],
      eyebrow: "FY2026 / Sole proprietors + companies",
      title: "Tax-readiness workspace for Japanese SMEs",
      metrics: ["Annual revenue", "Annual expenses", "Projected profit", "Missing / review", "AI usage saved"],
      metricNotes: ["Confirmed deposits / invoices", "Evidence-backed expenses / pending items", "Automatic profit/loss signal", "Receipts, due dates, registration numbers", "Recheck only local OCR and low-confidence fields"],
      headers: ["Status", "Folder", "Saved name", "Date", "Issue date", "Due date", "Counterparty", "Type", "Company/personal", "Category", "Amount", "Confidence"],
      search: "Search: vendor, category, amount",
    },
  }[appLang];
  if (!labels) return;
  document.querySelectorAll(".nav-list [data-view]").forEach((button, index) => {
    button.textContent = labels.nav[index] || button.textContent;
  });
  document.querySelector(".eyebrow").textContent = labels.eyebrow;
  document.querySelector(".topbar h2").textContent = labels.title;
  document.querySelectorAll(".metrics-grid article").forEach((card, index) => {
    card.querySelector("span").textContent = labels.metrics[index] || "";
    card.querySelector("small").textContent = labels.metricNotes[index] || "";
  });
  document.querySelectorAll("#documents-view th").forEach((th, index) => {
    th.textContent = labels.headers[index] || th.textContent;
  });
  searchInput.placeholder = labels.search;
}

function setSmartFilter(filter) {
  currentSmartFilter = filter === "profit" ? "" : filter;
  currentDirectoryFilter = "";
  currentFilter = filter === "review" ? "staged" : "all";
  searchInput.value = "";
  currentView = "documents";
  render();
}

function renderViews() {
  ["home", "documents", "readiness", "income", "tax", "membership", "accounts", "forms", "customers", "feedback", "training"].forEach((view) => {
    document.querySelector(`#${view}-view`)?.classList.toggle("hidden", view !== currentView);
  });

  document.querySelector("#content-grid")?.classList.toggle("hidden", currentView === "home");

  document.querySelectorAll(".home-only").forEach((section) => {
    section.classList.toggle("hidden", currentView !== "home");
  });

  document.querySelectorAll("[data-view]").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === currentView);
  });
}

function render() {
  renderViews();
  renderNotices();
  renderOcrRoadmap();
  renderActionBoard();
  renderReadiness();
  renderPolicyUpdates();
  renderDirectories();
  renderTable();
  renderDetail();
  updateMetrics();
  renderIncome();
  renderTax();
  renderMembership();
  renderAdmin();
  renderAccounts();
  renderGeneratedForms();
  renderCustomers();
  renderFeedback();
  renderTraining();
  normalizeLanguage();
}

function commitFormChanges() {
  const doc = selectedDocument();
  if (!doc) return null;
  const before = { ...doc };
  const data = new FormData(form);

  for (const [key, value] of data.entries()) {
    if (["amount", "tax_amount"].includes(key)) {
      doc[key] = Number(value || 0);
    } else {
      doc[key] = value;
    }
  }
  if (["", doc.original_name].includes(doc.renamed_name)) {
    const extension = (doc.original_name || doc.name || "file").split(".").pop();
    doc.renamed_name = buildRenamedName({ ...doc, extension });
  }
  if (doc.target_directory === "pending_review") {
    doc.target_directory = suggestDirectory(doc);
  }
  doc.review_notes = doc.review_notes || buildReviewNotes(doc);

  const changed = Object.keys(doc).filter((key) => before[key] !== doc[key]);
  return { doc, changed };
}

form.addEventListener("input", () => {
  commitFormChanges();
  renderTable();
  updateMetrics();
});

document.querySelector("#confirm-button").addEventListener("click", () => {
  const result = commitFormChanges();
  if (!result) return;
  result.doc.status = "done";
  result.doc.archive_status = "archived";
  result.doc.target_directory = result.doc.target_directory === "pending_review" ? suggestDirectory(result.doc) : result.doc.target_directory;
  result.doc.need_review = false;
  result.doc.confidence = Math.max(result.doc.confidence, 0.95);
  trainingSamples.unshift({
    id: `sample-${Date.now()}`,
    file: `${result.doc.renamed_name} -> ${result.doc.target_directory}`,
    engine: "mock-gpt-vision",
    fields: result.changed.length ? result.changed.join(", ") : "no_user_change",
    time: new Date().toLocaleString("ja-JP"),
  });
  currentFilter = "all";
  currentSmartFilter = "";
  currentDirectoryFilter = "";
  searchInput.value = "";
  render();
});

document.querySelector("#delete-button").addEventListener("click", () => {
  const index = documents.findIndex((doc) => doc.id === selectedId);
  if (index === -1) return;
  documents.splice(index, 1);
  selectedId = documents[0]?.id || "";
  currentFilter = "all";
  currentSmartFilter = "";
  currentDirectoryFilter = "";
  searchInput.value = "";
  render();
});

document.querySelector("#simulate-ai").addEventListener("click", () => {
  window.alert(`OCR状態: ${ocrRuntime.message}\n画像はローカルOCR API経由で解析します。PDF/CSVは現時点では手動確認フローです。`);
});

document.querySelectorAll(".segmented-control button").forEach((button) => {
  button.addEventListener("click", () => {
    currentFilter = button.dataset.filter;
    currentSmartFilter = "";
    currentDirectoryFilter = "";
    document.querySelectorAll(".segmented-control button").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    render();
  });
});

document.querySelectorAll("[data-view]").forEach((button) => {
  button.addEventListener("click", () => {
    currentView = button.dataset.view;
    render();
  });
});

searchInput.addEventListener("input", renderTable);

document.querySelector(".metrics-grid").addEventListener("click", (event) => {
  const card = event.target.closest("[data-smart-filter]");
  if (!card) return;
  setSmartFilter(card.dataset.smartFilter);
});

document.querySelector("#directory-grid").addEventListener("click", (event) => {
  const button = event.target.closest("[data-directory-filter]");
  if (!button) return;
  currentSmartFilter = "";
  currentDirectoryFilter = button.dataset.directoryFilter;
  currentFilter = "all";
  searchInput.value = "";
  currentView = "documents";
  render();
});

document.querySelector("#plan-grid").addEventListener("click", (event) => {
  const button = event.target.closest("[data-plan-id]");
  if (!button) return;
  subscriptionState.planId = button.dataset.planId;
  const currentPlan = activePlan();
  adminMembers[0].planId = currentPlan.id;
  adminMembers[0].employeesUsed = Math.min(employeeUsage(), currentPlan.includedEmployees);
  render();
});

document.querySelector("#add-employee-button").addEventListener("click", () => {
  const currentPlan = activePlan();
  const used = employeeUsage();
  if (used >= currentPlan.includedEmployees) {
    window.alert(`当前方案最多可增加 ${currentPlan.includedEmployees} 名员工账号。`);
    return;
  }
  const index = used + 1;
  employees.push({
    id: `emp-${Date.now()}`,
    name: `Staff ${index}`,
    email: `staff${index}@client.jp`,
    role: "staff",
    status: "invited",
  });
  adminMembers[0].employeesUsed = employeeUsage();
  render();
});

document.querySelector("#employee-table").addEventListener("change", (event) => {
  const roleId = event.target.dataset.employeeId;
  const statusId = event.target.dataset.employeeStatusId;
  if (roleId) {
    const employee = employees.find((item) => item.id === roleId);
    if (employee) employee.role = event.target.value;
  }
  if (statusId) {
    const employee = employees.find((item) => item.id === statusId);
    if (employee) employee.status = event.target.value;
  }
  renderMembership();
});

document.querySelector("#service-editor")?.addEventListener("input", (event) => {
  const id = event.target.dataset.serviceId;
  if (!id) return;
  const service = serviceItems.find((item) => item.id === id);
  if (service) service.body = event.target.value;
});

document.querySelector("#announcement-list")?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-toggle-announcement]");
  if (!button) return;
  const item = announcements.find((announcement) => announcement.id === button.dataset.toggleAnnouncement);
  if (item) item.active = !item.active;
  render();
});

document.querySelector("#ad-list")?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-toggle-ad]");
  if (!button) return;
  const item = ads.find((ad) => ad.id === button.dataset.toggleAd);
  if (item) item.active = !item.active;
  render();
});

announcementForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(announcementForm);
  const title = String(data.get("title") || "").trim();
  const body = String(data.get("body") || "").trim();
  if (!title || !body) return;
  announcements.unshift({ id: `ann-${Date.now()}`, title, body, active: true });
  announcementForm.reset();
  render();
});

adForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(adForm);
  const title = String(data.get("title") || "").trim();
  const target = String(data.get("target") || "").trim();
  if (!title || !target) return;
  ads.unshift({ id: `ad-${Date.now()}`, title, target, active: true });
  adForm.reset();
  render();
});

feedbackForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(feedbackForm);
  const message = String(data.get("message") || "").trim();
  if (!message) return;
  feedbackTickets.unshift({
    id: `fb-${Date.now()}`,
    type: data.get("type"),
    priority: data.get("priority"),
    status: "open",
    message,
    createdAt: new Date().toLocaleString("ja-JP"),
  });
  feedbackForm.reset();
  render();
});

businessFormGenerator.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(businessFormGenerator);
  const ownerType = data.get("owner_type");
  const amount = Number(data.get("amount") || 0);
  const result = findOrCreateCustomer(data.get("customer_query"), ownerType, "form");
  if (amount > 0) result.customer.revenue += amount;
  generatedForms.unshift({
    id: `form-${Date.now()}`,
    direction: String(data.get("direction") || "income"),
    template: data.get("template"),
    customer: result.customer.name,
    ownerType,
    amount,
    status: "draft",
    createdAt: new Date().toLocaleString("ja-JP"),
    title: String(data.get("document_title") || ""),
    issueDate: String(data.get("issue_date") || ""),
    dueDate: String(data.get("due_date") || ""),
    itemLabel: String(data.get("item_label") || ""),
    quantity: Number(data.get("quantity") || 1),
    unitPrice: Number(data.get("unit_price") || amount),
    taxRate: Number(data.get("tax_rate") || 10),
    paymentMethod: String(data.get("payment_method") || ""),
    validUntil: String(data.get("valid_until") || ""),
    expenseDate: String(data.get("expense_date") || ""),
    bankAccountNote: String(data.get("bank_account_note") || ""),
    requesterDepartment: String(data.get("requester_department") || ""),
    approvalOwner: String(data.get("approval_owner") || ""),
    attachmentStatus: String(data.get("attachment_status") || ""),
    memo: String(data.get("memo") || presetNoteText(data.get("preset_note"))),
    documentNumber: formNumber(String(data.get("template") || "invoice")),
  });
  formDraft = currentFormDraft();
  render();
});

businessFormGenerator.addEventListener("input", () => {
  renderFormPreview();
});

businessFormGenerator.addEventListener("change", () => {
  renderFormPreview();
});

previewFormButton?.addEventListener("click", () => {
  renderFormPreview(true);
});

customerSearch.addEventListener("input", renderCustomers);

companyProfileForm?.addEventListener("input", (event) => {
  if (!event.target.name) return;
  companyProfile[event.target.name] = event.target.value;
  renderFormPreview();
});

personalProfileForm?.addEventListener("input", (event) => {
  if (!event.target.name) return;
  personalProfile[event.target.name] = event.target.value;
  renderFormPreview();
});

phoneVerificationForm?.addEventListener("input", (event) => {
  if (!event.target.name) return;
  if (event.target.name === "phone") {
    phoneVerification.phone = event.target.value;
    renderPhoneVerification();
  }
});

document.querySelector("#send-code-button")?.addEventListener("click", () => {
  phoneVerification.sent = true;
  phoneVerification.verified = false;
  phoneVerification.lastSentAt = new Date().toLocaleString("ja-JP");
  renderPhoneVerification();
});

document.querySelector("#verify-code-button")?.addEventListener("click", () => {
  const code = String(new FormData(phoneVerificationForm).get("code") || "").trim();
  if (code.length < 4) return;
  phoneVerification.verified = true;
  phoneVerification.sent = true;
  phoneVerification.lastSentAt = new Date().toLocaleString("ja-JP");
  renderPhoneVerification();
});

manualTransactionForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(manualTransactionForm);
  const type = data.get("type");
  const rawAmount = Math.abs(Number(data.get("amount") || 0));
  if (!rawAmount) return;
  bankTransactions.unshift({
    id: `txn-${Date.now()}`,
    account: data.get("account"),
    date: data.get("date"),
    description: String(data.get("description") || "手动交易"),
    amount: type === "expense" ? -rawAmount : rawAmount,
    type,
    source: "manual",
    matched: "待AI照合",
  });
  const account = accounts.find((item) => item.name === data.get("account"));
  if (account) account.balance += type === "expense" ? -rawAmount : rawAmount;
  manualTransactionForm.reset();
  renderAccounts();
});

document.querySelector("#create-customer-button").addEventListener("click", () => {
  const result = findOrCreateCustomer(customerSearch.value, "company", "search_create");
  customerSearch.value = result.customer.name;
  renderCustomers();
});

document.querySelector("#customer-list").addEventListener("input", (event) => {
  const card = event.target.closest("[data-customer-id]");
  const field = event.target.dataset.customerField;
  if (!card || !field) return;
  const customer = customers.find((item) => item.id === card.dataset.customerId);
  if (!customer) return;
  customer[field] = event.target.value;
});

document.querySelector("#customer-list").addEventListener("click", (event) => {
  const button = event.target.closest("[data-save-customer]");
  if (!button) return;
  renderCustomers();
});

document.querySelector("#feedback-list").addEventListener("change", (event) => {
  const id = event.target.dataset.feedbackId;
  if (!id) return;
  const ticket = feedbackTickets.find((item) => item.id === id);
  if (ticket) ticket.status = event.target.value;
  renderFeedback();
});

taxInputIds.forEach((id) => {
  document.querySelector(`#${id}`).addEventListener("input", renderTax);
});

languageSelect.addEventListener("change", () => {
  appLang = languageSelect.value;
  document.documentElement.lang = appLang;
  const selected = selectedDocument();
  if (selected) {
    selected.language = appLang;
    render();
  }
});

function importFiles(fileList) {
  processUploads([...fileList]);
}

fileInput.addEventListener("change", (event) => {
  importFiles(event.target.files);
  fileInput.value = "";
});

homeFileInput?.addEventListener("change", (event) => {
  importFiles(event.target.files);
  homeFileInput.value = "";
});

["dragenter", "dragover"].forEach((eventName) => {
  dropZone.addEventListener(eventName, (event) => {
    event.preventDefault();
    dropZone.classList.add("drag-over");
  });
});

["dragleave", "drop"].forEach((eventName) => {
  dropZone.addEventListener(eventName, (event) => {
    event.preventDefault();
    dropZone.classList.remove("drag-over");
  });
});

dropZone.addEventListener("drop", (event) => {
  importFiles(event.dataTransfer.files);
});

render();

async function processUploads(files) {
  if (!files.length || ocrRuntime.busy) return;
  ocrRuntime.busy = true;
  ocrRuntime.message = `OCR処理中 ${files.length}件`;
  renderOcrRoadmap();
  try {
    const processed = [];
    for (const file of files) {
      if (file.type.startsWith("image/")) {
        processed.push(await runRealOcr(file));
      } else {
        processed.push(mockOcrProvider(file));
      }
    }
    documents = [...processed, ...documents];
    selectedId = processed[0]?.id || selectedId;
    currentView = "documents";
    currentFilter = "all";
    currentSmartFilter = "";
    currentDirectoryFilter = "";
    searchInput.value = "";
    ocrRuntime.message = `OCR完了 ${processed.length}件 / 画像はAPI解析、非画像は手動確認`;
    render();
  } catch (error) {
    ocrRuntime.message = `OCR失敗: ${error.message || "server error"}`;
    renderOcrRoadmap();
    window.alert(`OCRに失敗しました: ${error.message || "server error"}`);
  } finally {
    ocrRuntime.busy = false;
    renderOcrRoadmap();
  }
}

async function runRealOcr(file) {
  const dataUrl = await readFileAsDataUrl(file);
  const response = await fetch("http://localhost:4173/api/ocr", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      fileName: file.name,
      dataUrl,
      language: languageSelect.value,
    }),
  });
  const payload = await response.json();
  if (!response.ok || !payload.ok || !payload.document) {
    throw new Error(payload.error || "OCR API error");
  }
  return payload.document;
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(new Error("ファイル読込に失敗しました"));
    reader.readAsDataURL(file);
  });
}
