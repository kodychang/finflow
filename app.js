const yen = new Intl.NumberFormat("ja-JP", {
  style: "currency",
  currency: "JPY",
  maximumFractionDigits: 0,
});

const today = "2026-04-28";

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
  { name: "会社銀行口座", type: "bank", owner: "company", balance: 1840000, mixed: false, progress: 86 },
  { name: "会社クレジットカード", type: "credit_card", owner: "company", balance: -246800, mixed: false, progress: 72 },
  { name: "個人銀行口座", type: "bank", owner: "personal", balance: 930000, mixed: true, progress: 54 },
  { name: "PayPay", type: "payment", owner: "mixed", balance: 128000, mixed: true, progress: 38 },
];

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
  { id: "form-001", template: "invoice", customer: "株式会社サンプル", ownerType: "company", amount: 280000, status: "draft", createdAt: "2026-04-28 12:00" },
];

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
let currentView = "documents";
let trainingSamples = [];

const tableBody = document.querySelector("#document-table");
const form = document.querySelector("#detail-form");
const searchInput = document.querySelector("#search-input");
const dropZone = document.querySelector("#drop-zone");
const fileInput = document.querySelector("#file-input");
const languageSelect = document.querySelector("#language-select");
const taxInputIds = ["personal-deductions", "business-tax-rate", "corporate-local-rate", "consumption-tax-mode"];
const announcementForm = document.querySelector("#announcement-form");
const adForm = document.querySelector("#ad-form");
const feedbackForm = document.querySelector("#feedback-form");
const businessFormGenerator = document.querySelector("#business-form-generator");
const customerSearch = document.querySelector("#customer-search");

function mockOcrProvider(file) {
  const lower = file.name.toLowerCase();
  const isIncome = lower.includes("invoice") || lower.includes("売上") || lower.includes("income");
  const isBank = lower.includes("bank") || lower.includes("銀行");
  const isContract = lower.includes("contract") || lower.includes("契約");
  const amount = isIncome ? 180000 : lower.includes("tax") ? 52000 : 12800 + Math.floor(Math.random() * 68000);
  const taxAmount = Math.round(amount / 11);
  const issuedAt = inferIssueDate(lower) || today;
  const dueAt = isIncome ? addDays(issuedAt, 30) : "";
  const vendor = isIncome ? "新規クライアント" : isBank ? "銀行明細" : "未確認店舗";
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
    tax_rate: "10%",
    vendor,
    invoice_number: "",
    category: isBank ? "銀行明細" : isContract ? "契約書" : isIncome ? "売上" : guessCategory(lower),
    payment_method: isBank ? "bank_transfer" : "credit_card",
    account: isIncome || isBank ? "会社銀行口座" : "会社クレジットカード",
    tax_deductible: !isIncome,
    confidence: Number((0.62 + Math.random() * 0.27).toFixed(2)),
    need_review: true,
    summary: "AI仮解析。ユーザー確認後に学習サンプルとして保存されます。",
    review_notes: buildReviewNotes({ document_type: documentType, owner_type: ownerType, vendor, amount, issued_at: issuedAt, due_at: dueAt, invoice_number: "" }),
    ocr_text: `OCR mock: ${file.name} / amount ${amount} / generated at ${new Date().toISOString()}`,
    hash: `sha256:${file.name.length}-${file.size}-${file.lastModified}`,
    language: languageSelect.value === "ja" ? "ja/zh/en" : languageSelect.value,
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
    doc.issued_at ? "发行日已识别" : "发行日缺失",
    doc.amount ? "金额已识别" : "金额缺失",
    doc.tax_amount !== undefined ? "税额候选已识别" : "税额缺失",
    doc.invoice_number ? "登録番号已识别" : "登録番号未识别，需用户确认是否必要",
    doc.due_at ? "期限已识别" : "期限未识别或不适用",
  ];
  return `日本商务/税务标准检查: ${checks.join(" / ")}。AI建议目录: ${suggestDirectory(doc)}。为节省Token，仅提交关键字段和低置信度片段给AI复核。`;
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

function findOrCreateCustomer(query, ownerType = "company", source = "manual") {
  const name = String(query || "").trim() || "未命名客户";
  const existing = customers.find((customer) => customer.name.toLowerCase() === name.toLowerCase());
  if (existing) return { customer: existing, created: false };
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
    const text = `${doc.name} ${doc.vendor} ${doc.category} ${doc.amount}`.toLowerCase();
    return filterMatch && text.includes(query);
  });
}

function renderTable() {
  tableBody.innerHTML = filteredDocuments()
    .map(
      (doc) => `
        <tr data-id="${doc.id}" class="${doc.id === selectedId ? "selected" : ""}">
          <td><span class="status-badge ${doc.status === "done" ? "done" : "review"}">${doc.status === "done" ? "確認済" : "未確認"}</span></td>
          <td>${directoryLabel(doc.target_directory)}</td>
          <td>${doc.renamed_name}</td>
          <td>${doc.date}</td>
          <td>${doc.issued_at || "-"}</td>
          <td>${doc.due_at || "-"}</td>
          <td>${doc.vendor}</td>
          <td><span class="type-chip">${doc.document_type}</span></td>
          <td>${doc.owner_type === "company" ? "会社" : "個人"}</td>
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
    pending_review: "AI待确认",
    "company/receipts": "法人/领收书",
    "company/invoices": "法人/发票",
    "company/contracts": "法人/契约",
    "company/tax": "法人/税务",
    "company/bank": "法人/银行",
    "personal/receipts": "个人/领收书",
    "personal/tax": "个人/税务",
    "personal/bank": "个人/银行",
  };
  return labels[directory] || directory || "AI待确认";
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
  document.querySelector("#confirm-button").textContent = doc.archive_status === "archived" ? "已归档 / 更新确认" : "确认并归档";

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
      <span>今年の状態</span>
      <strong>${profitState} / ${yen.format(summary.profit)}</strong>
      <small>目标利益 ${yen.format(annualGoal.targetProfit)}，还差 ${yen.format(Math.max(0, gap))}</small>
    </article>
    <article class="action-card">
      <span>今天先做</span>
      <strong>${issues.length ? issues[0].label : "没有紧急漏项"}</strong>
      <small>${issues.length ? issues[0].doc.vendor + " / " + issues[0].doc.renamed_name : "继续上传本月收据和银行明细"}</small>
    </article>
    <article class="action-card">
      <span>防止税务误解</span>
      <strong>${issues.length} 个风险点</strong>
      <small>缺证明、缺期限、个人/法人混用、税率不明会优先提醒</small>
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
  document.querySelector("#policy-list").innerHTML = governmentFeeds
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
}

function renderAccounts() {
  document.querySelector("#account-list").innerHTML = accounts
    .map(
      (account) => `
        <article class="account-card">
          <div>
            <span>${account.owner} / ${account.type}</span>
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
  document.querySelector("#admin-member-list").innerHTML = adminMembers
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

  document.querySelector("#service-editor").innerHTML = serviceItems
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

  document.querySelector("#announcement-list").innerHTML = announcements
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

  document.querySelector("#ad-list").innerHTML = ads
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
  document.querySelector("#generated-forms").innerHTML = generatedForms
    .map(
      (formItem) => `
        <article class="feedback-ticket">
          <strong>${formTemplateLabel(formItem.template)} - ${escapeHtml(formItem.customer)}</strong>
          <div class="ticket-meta">
            <span>${formItem.ownerType === "company" ? "法人" : "个人"}</span>
            <span>${yen.format(formItem.amount)}</span>
            <span>${formItem.status}</span>
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
    tax_summary: "报税资料整理表",
  };
  return labels[template] || template;
}

function renderCustomers() {
  const query = customerSearch.value.trim().toLowerCase();
  const visible = customers.filter((customer) =>
    `${customer.name} ${customer.email} ${customer.phone} ${customer.invoiceNumber} ${customer.corporateNumber} ${customer.address} ${customer.contactName}`
      .toLowerCase()
      .includes(query),
  );
  const createHint = query && visible.length === 0 ? `<article class="feedback-ticket"><strong>没有找到「${escapeHtml(customerSearch.value)}」</strong><span>点击“搜索不到，建立新客户”会直接建立。</span></article>` : "";
  document.querySelector("#customer-list").innerHTML =
    createHint +
    visible
      .map(
        (customer) => `
          <article class="customer-card" data-customer-id="${customer.id}">
            <div class="customer-card-header">
              <div>
                <strong>${escapeHtml(customer.name)}</strong>
                <span>${customer.ownerType === "company" ? "法人客户" : "个人客户"} / 来源: ${customer.source} / 売上 ${yen.format(customer.revenue)}</span>
              </div>
              <button class="secondary-button" data-save-customer="${customer.id}">保存</button>
            </div>
            <div class="customer-edit-grid">
              ${customerInput(customer, "name", "客户/厂商名")}
              <label>
                区分
                <select data-customer-field="ownerType">
                  <option value="company" ${customer.ownerType === "company" ? "selected" : ""}>法人</option>
                  <option value="personal" ${customer.ownerType === "personal" ? "selected" : ""}>个人</option>
                </select>
              </label>
              ${customerInput(customer, "invoiceNumber", "登録番号")}
              ${customerInput(customer, "corporateNumber", "法人番号")}
              ${customerInput(customer, "postalCode", "郵便番号")}
              ${customerInput(customer, "address", "住所")}
              ${customerInput(customer, "contactName", "联系人")}
              ${customerInput(customer, "department", "部署")}
              ${customerInput(customer, "email", "Email")}
              ${customerInput(customer, "phone", "电话")}
              ${customerInput(customer, "paymentTerms", "付款条件")}
              <label class="wide">
                备注 / 报税确认事项
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

function renderViews() {
  ["documents", "readiness", "income", "tax", "policy", "membership", "admin", "accounts", "forms", "customers", "feedback", "training"].forEach((view) => {
    document.querySelector(`#${view}-view`).classList.toggle("hidden", view !== currentView);
  });

  document.querySelectorAll("[data-view]").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === currentView);
  });
}

function render() {
  renderViews();
  renderNotices();
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
  render();
});

document.querySelector("#simulate-ai").addEventListener("click", () => {
  documents = documents.map((doc) => ({
    ...doc,
    confidence: Number(Math.min(0.98, doc.confidence + 0.03).toFixed(2)),
    need_review: doc.confidence < 0.82,
  }));
  render();
});

document.querySelectorAll(".segmented-control button").forEach((button) => {
  button.addEventListener("click", () => {
    currentFilter = button.dataset.filter;
    document.querySelectorAll(".segmented-control button").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    renderTable();
  });
});

document.querySelectorAll("[data-view]").forEach((button) => {
  button.addEventListener("click", () => {
    currentView = button.dataset.view;
    render();
  });
});

searchInput.addEventListener("input", renderTable);

document.querySelector("#directory-grid").addEventListener("click", (event) => {
  const button = event.target.closest("[data-directory-filter]");
  if (!button) return;
  currentFilter = "all";
  searchInput.value = button.dataset.directoryFilter;
  renderTable();
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

document.querySelector("#service-editor").addEventListener("input", (event) => {
  const id = event.target.dataset.serviceId;
  if (!id) return;
  const service = serviceItems.find((item) => item.id === id);
  if (service) service.body = event.target.value;
});

document.querySelector("#announcement-list").addEventListener("click", (event) => {
  const button = event.target.closest("[data-toggle-announcement]");
  if (!button) return;
  const item = announcements.find((announcement) => announcement.id === button.dataset.toggleAnnouncement);
  if (item) item.active = !item.active;
  render();
});

document.querySelector("#ad-list").addEventListener("click", (event) => {
  const button = event.target.closest("[data-toggle-ad]");
  if (!button) return;
  const item = ads.find((ad) => ad.id === button.dataset.toggleAd);
  if (item) item.active = !item.active;
  render();
});

announcementForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(announcementForm);
  const title = String(data.get("title") || "").trim();
  const body = String(data.get("body") || "").trim();
  if (!title || !body) return;
  announcements.unshift({ id: `ann-${Date.now()}`, title, body, active: true });
  announcementForm.reset();
  render();
});

adForm.addEventListener("submit", (event) => {
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
    template: data.get("template"),
    customer: result.customer.name,
    ownerType,
    amount,
    status: "draft",
    createdAt: new Date().toLocaleString("ja-JP"),
  });
  businessFormGenerator.reset();
  render();
});

customerSearch.addEventListener("input", renderCustomers);

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
  document.documentElement.lang = languageSelect.value;
  const selected = selectedDocument();
  if (selected) {
    selected.language = languageSelect.value;
    renderDetail();
  }
});

function importFiles(fileList) {
  const newDocs = [...fileList].map(mockOcrProvider);
  documents = [...newDocs, ...documents];
  selectedId = newDocs[0]?.id || selectedId;
  currentView = "documents";
  render();
}

fileInput.addEventListener("change", (event) => {
  importFiles(event.target.files);
  fileInput.value = "";
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
