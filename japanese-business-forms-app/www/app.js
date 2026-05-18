const DOC_TYPES = {
  estimate: {
    title: "見積書",
    subtitle: "Quotation",
    pageTitle: "見積書作成",
    totalLabel: "御見積金額",
    dueLabel: "有効期限",
    prefix: "EST",
  },
  order: {
    title: "客先注文記録",
    subtitle: "Customer Order Record",
    pageTitle: "客先注文記録",
    totalLabel: "注文金額",
    dueLabel: "納期",
    prefix: "ORD",
  },
  purchaseOrder: {
    title: "発注書",
    subtitle: "Purchase Order",
    pageTitle: "発注書作成",
    totalLabel: "発注金額",
    dueLabel: "納期",
    prefix: "PO",
  },
  delivery: {
    title: "納品書",
    subtitle: "Delivery Note",
    pageTitle: "納品書作成",
    totalLabel: "納品金額",
    dueLabel: "納品日",
    prefix: "DLV",
  },
  invoice: {
    title: "請求書",
    subtitle: "Invoice",
    pageTitle: "請求書作成",
    totalLabel: "ご請求金額",
    dueLabel: "支払期限",
    prefix: "INV",
  },
  receipt: {
    title: "領収書",
    subtitle: "Receipt",
    pageTitle: "領収書作成",
    totalLabel: "領収金額",
    dueLabel: "受領日",
    prefix: "RCT",
  },
  acceptance: {
    title: "受領書",
    subtitle: "Acceptance Receipt",
    pageTitle: "受領書作成",
    totalLabel: "受領金額",
    dueLabel: "受領日",
    prefix: "ACP",
  },
  customerFiles: {
    title: "顧客書類",
    subtitle: "Customer Files",
    pageTitle: "顧客書類管理",
    totalLabel: "記録金額",
    dueLabel: "確認期限",
    prefix: "CF",
  },
};

const STORAGE_KEY = "shokoForms.documents.v1";
const FORM_OBJECT_SCHEMA_VERSION = 2;
const CUSTOMER_KEY = "shokoForms.customers.v1";
const ITEM_KEY = "shokoForms.items.v1";
const TEMPLATE_KEY = "shokoForms.templates.v1";
const SETTINGS_KEY = "shokoForms.settings.v1";
const OPERATION_KEY = "shokoForms.operations.v1";
const NIIX_COMPANY_NAME = "NIIX株式会社";
const GOOGLE_DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile";

const ARCHIVE_FORM_TYPES = [
  { key: "estimate", types: ["estimate"], label: "見積" },
  { key: "order", types: ["order", "purchaseOrder"], label: "注文/発注" },
  { key: "delivery", types: ["delivery"], label: "納品" },
  { key: "invoice", types: ["invoice"], label: "請求" },
  { key: "receipt", types: ["receipt"], label: "領収" },
];

const INBOUND_ARCHIVE_FORM_TYPES = [
  { key: "customerFiles", types: ["customerFiles", "estimate", "order", "delivery", "invoice", "receipt", "acceptance"], label: "顧客書類" },
];

const CUSTOMER_FILE_GROUPS = [
  { key: "estimate", label: "見積書", hint: "取引先から受領した見積書を保存" },
  { key: "invoice", label: "請求書", hint: "取引先から受領した請求書を保存" },
  { key: "receipt", label: "領収書", hint: "取引先から受領した領収書を保存" },
];

const DEFAULT_SEAL_SETTINGS = {
  enabled: true,
  imageDataUrl: "",
  fit: "contain",
  sizePreset: "medium",
  width: 96,
  height: 96,
  x: 166,
  y: 74,
  opacity: 0.95,
  rotation: -4,
};

const SEAL_STYLE_GRIDS = {
  style_1: { columns: 1, flow: "row" },
  style_2: { columns: 2, flow: "column" },
  style_3: { columns: 3, flow: "column" },
  style_4: { rows: 1, flow: "column" },
  style_5: { rows: 2, flow: "row" },
  style_6: { rows: 3, flow: "row" },
  style_7: { columns: 2, rows: 1, flow: "column" },
  style_8: { columns: 3, rows: 1, flow: "column" },
  style_9: { auto: true },
};

const SEAL_FONT_FAMILIES = {
  gyoshotai: "Yuji Syuku",
  kaishotai: "Noto Serif JP",
  kointai: "Shippori Mincho",
  tenshotai: "Noto Serif JP",
};

const SEAL_SIZE_PRESETS = {
  small: { width: 72, height: 72 },
  medium: { width: 96, height: 96 },
  large: { width: 120, height: 120 },
};

const FLOW_STEPS = [
  { type: "estimate", label: "見積", note: "条件・金額を提示" },
  { type: "order", label: "注文選択", note: "客先注文の受領記録または発注書", alternates: ["purchaseOrder"] },
  { type: "delivery", label: "納品", note: "出荷・納品記録" },
  { type: "invoice", label: "請求", note: "振込先と支払期限" },
  { type: "receipt", label: "領収", note: "入金後の証憑" },
];

const COPY_TARGETS = ["estimate", "order", "purchaseOrder", "delivery", "invoice", "receipt", "acceptance"];

const REFERENCE_TYPES = Object.fromEntries(
  Object.keys(DOC_TYPES).map((type) => [type, Object.keys(DOC_TYPES).filter((candidate) => candidate !== type)]),
);

const CHAIN_ORDER = ["estimate", "order", "invoice", "receipt"];
const CHAIN_ALTERNATES = {
  order: ["order", "purchaseOrder"],
};

const RELATED_MENU_LABELS = {
  estimate: "見積",
  order: "注文選択",
  delivery: "納品",
  invoice: "請求",
  receipt: "領収書",
};

const NOTICE_TEMPLATES = {
  priceChange: {
    label: "価格調整通知",
    title: "価格調整のお知らせ",
    body: "仕入価格または為替変動により、価格を調整する可能性があります。確定価格はご注文時に改めてご案内いたします。",
  },
  delay: {
    label: "納期遅延通知",
    title: "納期遅延のお知らせ",
    body: "物流状況または在庫状況により、納期が変更となる可能性があります。確定次第、速やかにご連絡いたします。",
  },
  businessHours: {
    label: "営業時間通知",
    title: "営業時間のお知らせ",
    body: "弊社営業時間外のお問い合わせは、翌営業日以降に順次対応いたします。",
  },
  cancel: {
    label: "注文取消通知",
    title: "注文取消条件のお知らせ",
    body: "正式発注後のキャンセルは、手配状況によりキャンセル費用が発生する場合があります。",
  },
  general: {
    label: "一般通知",
    title: "お知らせ",
    body: "本件に関する補足事項をご確認ください。",
  },
};

const SPECIFIC_LABELS = {
  estimate: "見積条件",
  order: "注文条件",
  purchaseOrder: "発注条件",
  delivery: "物流・納品情報",
  invoice: "請求条件",
  receipt: "領収内容",
  acceptance: "受領内容",
};

const FORM_DEFINITIONS = {
  estimate: {
    partySection: "見積先",
    partyName: "見積先会社名 / 氏名",
    issuerSection: "見積発行者",
    transactionLabel: "見積日",
    dueLabel: "有効期限",
    secondaryLabel: "支払条件",
    specificsLabel: "見積条件",
    totalLabel: "御見積金額",
    lead: "下記の通り、お見積り申し上げます。",
    notesPlaceholder: "有効期限、納入予定、見積条件など",
    secondaryPlaceholder: "例: 月末締め翌月末払い / 銀行振込",
    specificsPlaceholder: "例: 価格条件、納期、保証、見積範囲",
    defaultNotes: "本見積の内容にご不明点がございましたらお問い合わせください。",
    defaultSpecifics: "見積有効期限、納入予定、税率・合計金額を確認してください。",
  },
  order: {
    partySection: "注文元",
    partyName: "注文元会社名 / 氏名",
    issuerSection: "記録担当",
    transactionLabel: "受領日",
    dueLabel: "希望納期",
    secondaryLabel: "受領確認",
    specificsLabel: "注文記録メモ",
    totalLabel: "注文金額",
    lead: "客先から受領した注文内容を記録します。",
    notesPlaceholder: "客先注文の確認事項、取引条件、社内メモなど",
    secondaryPlaceholder: "例: 客先メール確認済み / 金額確認待ち",
    specificsPlaceholder: "例: 添付注文書の版、納品希望日、確認履歴",
    defaultNotes: "客先から受領した注文資料を添付し、取引内容を確認してください。",
    defaultSpecifics: "受領した注文ファイル、希望納期、関連見積番号を確認してください。",
  },
  purchaseOrder: {
    partySection: "注文送付先",
    partyName: "注文送付先会社名 / 氏名",
    issuerSection: "注文発行者",
    transactionLabel: "発注日",
    dueLabel: "納期",
    secondaryLabel: "支払・発注条件",
    specificsLabel: "購買条件",
    totalLabel: "発注金額",
    lead: "下記の通り、注文を発行いたします。",
    notesPlaceholder: "支払条件、検収、キャンセル条件、納入場所など",
    secondaryPlaceholder: "例: 検収後月末締め翌月末払い",
    specificsPlaceholder: "例: 納入場所、検収条件、納品書同梱、分納可否",
    defaultNotes: "注文内容をご確認の上、手配をお願いいたします。",
    defaultSpecifics: "支払・発注条件、納入場所、検収条件を確認してください。",
  },
  delivery: {
    partySection: "納品先",
    partyName: "納品先会社名 / 氏名",
    issuerSection: "納品者",
    transactionLabel: "出荷日",
    dueLabel: "納品日",
    secondaryLabel: "納品場所",
    specificsLabel: "物流・納品情報",
    totalLabel: "納品金額",
    lead: "下記の通り、納品いたしました。",
    notesPlaceholder: "納品・検収時の注意事項など",
    secondaryPlaceholder: "例: 納品先住所 / 倉庫 / 担当者",
    specificsPlaceholder: "例: 配送会社、送り状番号、納品場所、検収期限",
    defaultNotes: "上記の通り、納品いたしましたことを証明いたします。",
    defaultSpecifics: "物流情報、納品場所、検収期限を入力してください。",
  },
  invoice: {
    partySection: "請求先",
    partyName: "請求先会社名 / 氏名",
    issuerSection: "請求者",
    transactionLabel: "取引年月日",
    dueLabel: "支払期限",
    secondaryLabel: "振込先",
    specificsLabel: "請求条件",
    totalLabel: "ご請求金額",
    lead: "下記の通り、ご請求申し上げます。",
    notesPlaceholder: "振込手数料、請求条件、入金確認など",
    secondaryPlaceholder: "例: 三井住友銀行 東京支店 普通 1234567",
    specificsPlaceholder: "例: 支払期限、源泉徴収、請求条件",
    defaultNotes: "お支払期限までにお振込みをお願いいたします。",
    defaultSpecifics: "振込先、支払期限、請求条件を確認してください。",
  },
  receipt: {
    partySection: "領収先",
    partyName: "領収先会社名 / 氏名",
    issuerSection: "領収者",
    transactionLabel: "入金日",
    dueLabel: "領収日",
    secondaryLabel: "支払方法",
    specificsLabel: "領収内容",
    totalLabel: "領収金額",
    lead: "下記の金額を領収いたしました。",
    notesPlaceholder: "但し書き、支払方法、入金確認など",
    secondaryPlaceholder: "例: 銀行振込 / 現金 / クレジットカード",
    specificsPlaceholder: "例: 但し書き、入金日、領収方法",
    defaultNotes: "上記正に領収いたしました。",
    defaultSpecifics: "入金日、領収但し書き、支払方法を確認してください。",
  },
  acceptance: {
    partySection: "受領元",
    partyName: "受領元会社名 / 氏名",
    issuerSection: "受領者",
    transactionLabel: "受領日",
    dueLabel: "検収期限",
    secondaryLabel: "受領場所",
    specificsLabel: "受領・検収内容",
    totalLabel: "受領金額",
    lead: "下記の通り、受領いたしました。",
    notesPlaceholder: "受領品、検収結果、差異など",
    secondaryPlaceholder: "例: 受領場所 / 担当者",
    specificsPlaceholder: "例: 受領数量、検収結果、差異、保管場所",
    defaultNotes: "上記の通り、受領いたしました。",
    defaultSpecifics: "受領数量、検収結果、差異を確認してください。",
  },
  customerFiles: {
    partySection: "取引先",
    partyName: "取引先会社名 / 氏名",
    issuerSection: "記録担当",
    transactionLabel: "受領日",
    dueLabel: "確認期限",
    secondaryLabel: "確認状況",
    specificsLabel: "顧客書類メモ",
    totalLabel: "記録金額",
    lead: "取引先から受領した書類を一つのプロジェクトとして保管します。",
    notesPlaceholder: "受領した見積書、請求書、領収書、メールなどの確認事項",
    secondaryPlaceholder: "例: 見積書・請求書・領収書を受領済み / 内容確認待ち",
    specificsPlaceholder: "例: ファイルの種類、確認日、差戻し事項、社内処理状況",
    defaultNotes: "取引先から受領した書類ファイルを添付し、確認状況を記録してください。",
    defaultSpecifics: "見積書、請求書、領収書などを同じページで管理します。",
  },
};

const BUILT_IN_TEMPLATES = [
  { id: "monochrome", name: "日本帳票", style: "monochrome", accent: "#2e3031", builtin: true },
  { id: "corporate", name: "企業標準", style: "corporate", accent: "#dfff00", builtin: true },
  { id: "ledger", name: "明細表", style: "ledger", accent: "#62666a", builtin: true },
  { id: "indigo", name: "濃灰罫線", style: "indigo", accent: "#1f2224", builtin: true },
  { id: "sepia", name: "淡灰罫線", style: "sepia", accent: "#aeb3b7", builtin: true },
];

const SAMPLE_CUSTOMER = {
  customerName: "株式会社青葉商事",
  customerAddress: "〒100-0001\n東京都千代田区千代田1-1",
  customerContact: "経理部 佐藤 様",
  customerPhone: "03-1111-2222",
  customerEmail: "keiri@aoba.example",
  customerFax: "03-1111-2223",
  customerContactPhone: "090-1234-5678",
};

const SAMPLE_ISSUER = {
  issuerName: "合同会社Shoko Studio",
  issuerRegistration: "T1234567890123",
  issuerAddress: "〒150-0001\n東京都渋谷区神宮前1-2-3",
  issuerContact: "営業部 田中",
  issuerPhone: "03-1234-5678",
  issuerEmail: "billing@example.jp",
};

const state = {
  docType: "invoice",
  currentId: crypto.randomUUID(),
  projectId: "",
  projectName: "",
  projectDirection: "outbound",
  templateId: "monochrome",
  sourceDocumentId: "",
  sourceDocumentNumber: "",
  sourceDocumentType: "",
  relatedFormIds: [],
  relatedDocumentNumbers: {},
  relatedDocumentType: "",
  relatedNumberMode: "auto",
  convertedDocumentIds: [],
  selectedCustomerId: "",
  lines: [],
  notices: [],
  customerOrderFiles: [],
  isDirty: false,
  issuerLogo: "",
  pendingCompanyLogo: "",
  companyLogoMarkedForDeletion: false,
  dismissedFlowIssues: [],
  leaveGuardResolve: null,
  selectedArchiveProjectId: "",
  previewSnapshotTimer: null,
  previewSnapshotUrl: "",
  previewSnapshotToken: 0,
  googleAccessToken: "",
  googleTokenExpiresAt: 0,
  mobileExpandedSections: new Set(),
  mobileTitleRestoreTimer: null,
  mobileLastScrollTop: 0,
};

const els = {};
const previewAssetDataUrlCache = new Map();

const dialogPageNavigation = {
  installed: false,
  stack: [],
  closingFromHistory: false,
};

function isNativeApp() {
  const previewMode = new URLSearchParams(window.location.search).get("native") === "ios";
  return Boolean(previewMode || window.Capacitor?.isNativePlatform?.() || window.Capacitor?.getPlatform?.() === "ios");
}

function syncNativeAppChrome() {
  document.body.classList.toggle("native-app", isNativeApp());
}

function dialogPageTitle(dialog) {
  return dialog?.querySelector("h2, h3")?.textContent?.trim() || dialog?.id || "page";
}

function updateDialogPageState() {
  document.body.classList.toggle("dialog-page-open", dialogPageNavigation.stack.some((dialog) => dialog.open));
}

function removeDialogPage(dialog) {
  dialogPageNavigation.stack = dialogPageNavigation.stack.filter((item) => item !== dialog);
  dialog.classList.remove("dialog-page");
  delete dialog.dataset.dialogPageToken;
  updateDialogPageState();
}

function prepareDialogPageHeader(dialog) {
  const header = dialog?.querySelector("header, .dialog-header");
  const button = header?.querySelector('button[value="cancel"], button.icon-button');
  if (!header || !button) return;
  button.classList.add("dialog-back-button");
  button.textContent = "‹";
  button.setAttribute("aria-label", "戻る");
  button.setAttribute("title", "戻る");
  header.prepend(button);
}

function closeTopDialogPageFromHistory() {
  const dialog = [...dialogPageNavigation.stack].reverse().find((item) => item.open);
  if (!dialog) return;
  dialogPageNavigation.closingFromHistory = true;
  dialog.close("back");
  window.setTimeout(() => {
    dialogPageNavigation.closingFromHistory = false;
  }, 0);
}

function openDialogPage(dialog) {
  if (!dialog || dialog.dataset.dialogPageToken) return;
  const token = crypto.randomUUID();
  dialog.dataset.dialogPageToken = token;
  dialog.classList.add("dialog-page");
  prepareDialogPageHeader(dialog);
  dialogPageNavigation.stack.push(dialog);
  updateDialogPageState();
  window.history.pushState(
    {
      ...(window.history.state || {}),
      dialogPageToken: token,
      dialogPageTitle: dialogPageTitle(dialog),
    },
    "",
    window.location.href,
  );
}

function installDialogPageNavigation() {
  if (dialogPageNavigation.installed || !window.HTMLDialogElement) return;
  dialogPageNavigation.installed = true;
  const nativeShowModal = HTMLDialogElement.prototype.showModal;
  const nativeShow = HTMLDialogElement.prototype.show;

  HTMLDialogElement.prototype.showModal = function showModalAsPage() {
    const wasOpen = this.open;
    nativeShowModal.call(this);
    if (!wasOpen) openDialogPage(this);
  };

  HTMLDialogElement.prototype.show = function showAsPage() {
    const wasOpen = this.open;
    nativeShow.call(this);
    if (!wasOpen) openDialogPage(this);
  };

  window.addEventListener("popstate", closeTopDialogPageFromHistory);

  document.addEventListener(
    "close",
    (event) => {
      const dialog = event.target;
      if (!(dialog instanceof HTMLDialogElement) || !dialog.dataset.dialogPageToken) return;
      const wasTop = dialogPageNavigation.stack.at(-1) === dialog;
      removeDialogPage(dialog);
      if (wasTop && !dialogPageNavigation.closingFromHistory) window.history.back();
    },
    true,
  );
}

function yen(value) {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
    maximumFractionDigits: 0,
  }).format(Number(value || 0));
}

function japanDateParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  return Object.fromEntries(parts.map((part) => [part.type, part.value]));
}

function today() {
  const { year, month, day } = japanDateParts();
  return `${year}-${month}-${day}`;
}

function addDays(days) {
  const { year, month, day } = japanDateParts();
  const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day) + days));
  const next = japanDateParts(date);
  return `${next.year}-${next.month}-${next.day}`;
}

function formatDate(value) {
  if (!value) return "";
  return value.replaceAll("-", "/");
}

function loadDocuments() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]").map(normalizeFormObject);
  } catch {
    return [];
  }
}

function storeDocuments(documents) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(documents.map(normalizeFormObject)));
}

function readStore(key, fallback) {
  try {
    return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
  } catch {
    return fallback;
  }
}

function writeStore(key, value) {
  localStorage.setItem(key, JSON.stringify(value));
}

function automaticAccountId(email = "") {
  const suffix = String(email || "").trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40);
  return `acct-${suffix || crypto.randomUUID().slice(0, 8)}-${Date.now().toString(36)}`;
}

function accountLabel(settings = loadSettings()) {
  const provider = settings.accountProvider === "google" ? "Google" : settings.accountProvider === "email" ? "Email" : "未登録";
  const name = settings.accountName || settings.accountEmail || "未登録";
  const id = settings.accountId ? `ID: ${settings.accountId}` : "ID未発行";
  return { provider, name, id };
}

function updateBackupStatus(message) {
  if (els.backupOutput) els.backupOutput.value = message;
}

function loadTemplates() {
  const custom = readStore(TEMPLATE_KEY, []);
  return [...BUILT_IN_TEMPLATES, ...custom];
}

function selectedTemplate() {
  return loadTemplates().find((template) => template.id === state.templateId) || BUILT_IN_TEMPLATES[1];
}

function formDefinition(type = state.docType) {
  return FORM_DEFINITIONS[type] || FORM_DEFINITIONS.invoice;
}

function showsPrices(type = state.docType, projectDirection = state.projectDirection) {
  return normalizeProjectDirection(projectDirection) !== "inbound" && !["order", "delivery", "customerFiles"].includes(type);
}

function isCustomerOrderRecord(type = state.docType) {
  return type === "order";
}

function normalizeProjectDirection(value) {
  return value === "inbound" ? "inbound" : "outbound";
}

function isInboundProject(doc = state) {
  return normalizeProjectDirection(doc.projectDirection) === "inbound";
}

function isReceivedDocumentRecord(doc = getFormData()) {
  return doc.docType === "customerFiles" || isInboundProject(doc) || isCustomerOrderRecord(doc.docType);
}

function isCustomerFilesDocument(doc = getFormData()) {
  return doc.docType === "customerFiles";
}

function normalizeCustomerOrderFile(file = {}) {
  return {
    id: file.id || crypto.randomUUID(),
    name: file.name || "customer-order-file",
    category: file.category || file.group || "general",
    type: file.type || "application/octet-stream",
    size: Number(file.size || 0),
    dataUrl: file.dataUrl || "",
    serverUrl: file.serverUrl || file.url || "",
    uploadedAt: file.uploadedAt || new Date().toISOString(),
  };
}

function formatFileSize(bytes = 0) {
  const size = Number(bytes || 0);
  if (size >= 1024 * 1024) return `${(size / 1024 / 1024).toFixed(1)} MB`;
  if (size >= 1024) return `${Math.round(size / 1024)} KB`;
  return `${size} B`;
}

function normalizeCustomer(customer = {}) {
  return {
    id: customer.id || crypto.randomUUID(),
    companyName: customer.companyName || customer.name || "",
    companyAddress: customer.companyAddress || customer.address || "",
    companyPhone: customer.companyPhone || customer.phone || "",
    email: customer.email || "",
    fax: customer.fax || "",
    contactName: customer.contactName || customer.contact || "",
    contactPhone: customer.contactPhone || "",
    contactEmail: customer.contactEmail || "",
    department: customer.department || "",
    other: customer.other || customer.notes || "",
    updatedAt: customer.updatedAt || new Date().toISOString(),
  };
}

function normalizeCompany(company = {}) {
  return {
    id: company.id || crypto.randomUUID(),
    logo: company.logo || "",
    name: company.name || company.issuerName || "",
    registration: company.registration || company.issuerRegistration || "",
    address: company.address || company.issuerAddress || "",
    phone: company.phone || company.issuerPhone || "",
    contact: company.contact || company.issuerContact || "",
    email: company.email || company.issuerEmail || "",
    isDefault: Boolean(company.isDefault),
    updatedAt: company.updatedAt || new Date().toISOString(),
  };
}

function settingsCompanies() {
  return (loadSettings().companies || []).map(normalizeCompany);
}

function saveCompanyRecord(company, { makeDefault = true } = {}) {
  const normalized = normalizeCompany({ ...company, isDefault: makeDefault });
  const companies = settingsCompanies().filter((item) => item.id !== normalized.id && item.name !== normalized.name);
  const next = [normalized, ...companies].map((item, index) => ({ ...item, isDefault: makeDefault ? index === 0 : item.isDefault }));
  storeSettings({ ...loadSettings(), companies: next });
  return normalized;
}

function defaultCompany() {
  const companies = settingsCompanies();
  return companies.find((company) => company.isDefault) || companies[0] || null;
}

function ensureNiixCompany() {
  const companies = settingsCompanies();
  if (companies.some((company) => company.name === NIIX_COMPANY_NAME)) return;
  saveCompanyRecord({
    name: NIIX_COMPANY_NAME,
    registration: "",
    address: "東京都内 NIIX株式会社 管理拠点",
    contact: "Archive Desk",
    phone: "",
    email: "",
  }, { makeDefault: !companies.length });
}

function applyCompanyToIssuer(company) {
  if (!company) return;
  state.issuerLogo = company.logo || "";
  els.issuerName.value = company.name || "";
  els.issuerRegistration.value = company.registration || "";
  els.issuerAddress.value = company.address || "";
  if (els.issuerContact) els.issuerContact.value = company.contact || "";
  els.issuerPhone.value = company.phone || "";
  els.issuerEmail.value = company.email || "";
  renderPreview();
  setDirty(true);
}

function upsertIssuerFromDocument(doc = getFormData()) {
  if (!doc.issuerName) return;
  const existing = settingsCompanies().find((company) => company.name === doc.issuerName) || {};
  saveCompanyRecord({
    ...existing,
    logo: state.issuerLogo || existing.logo || "",
    name: doc.issuerName,
    registration: doc.issuerRegistration,
    address: doc.issuerAddress,
    contact: doc.issuerContact,
    phone: doc.issuerPhone,
    email: doc.issuerEmail,
  }, { makeDefault: !defaultCompany() || existing.isDefault });
}

function upsertCustomerFromDocument(doc = getFormData()) {
  if (!doc.customerName) return;
  const existing = loadCustomers().find((customer) => customer.companyName === doc.customerName) || {};
  saveCustomerRecord({
    ...existing,
    companyName: doc.customerName,
    companyAddress: doc.customerAddress,
    email: doc.customerEmail || existing.email || "",
    contactName: doc.customerContact,
    updatedAt: new Date().toISOString(),
  }, { silent: true });
}

function loadCustomers() {
  return readStore(CUSTOMER_KEY, []).map(normalizeCustomer);
}

function storeCustomers(customers) {
  writeStore(CUSTOMER_KEY, customers.map(normalizeCustomer));
}

function selectedCustomer() {
  return loadCustomers().find((customer) => customer.id === state.selectedCustomerId) || null;
}

function customerDisplayContact(customer) {
  return [customer.department, customer.contactName].filter(Boolean).join(" ") || "-";
}

function normalizeSmartText(value = "") {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "")
    .replace(/[ー－‐-]/g, "-");
}

function uniqueValues(values = []) {
  return [...new Set(values.map((value) => String(value || "").trim()).filter(Boolean))];
}

function customerSmartValues(customer = {}) {
  return uniqueValues([
    customer.companyName,
    customer.companyAddress,
    customer.companyPhone,
    customer.email,
    customer.fax,
    customer.contactName,
    customer.contactPhone,
    customer.contactEmail,
    customer.department,
    customer.other,
    customerDisplayContact(customer) === "-" ? "" : customerDisplayContact(customer),
  ]);
}

function companySmartValues(company = {}) {
  return uniqueValues([
    company.name,
    company.registration,
    company.address,
    company.phone,
    company.contact,
    company.email,
  ]);
}

function itemSmartValues(item = {}) {
  return uniqueValues([
    item.name,
    item.model,
    item.specification,
    item.unitPrice ? String(item.unitPrice) : "",
  ]);
}

function smartMatch(records = [], value = "", valuesForRecord = () => []) {
  const needle = normalizeSmartText(value);
  if (!needle) return null;
  const exactMatches = records.filter((record) => valuesForRecord(record).some((entry) => normalizeSmartText(entry) === needle));
  if (exactMatches.length === 1) return exactMatches[0];
  if (needle.length < 3) return null;
  const partialMatches = records.filter((record) => valuesForRecord(record).some((entry) => {
    const haystack = normalizeSmartText(entry);
    return haystack && haystack.includes(needle);
  }));
  return partialMatches.length === 1 ? partialMatches[0] : null;
}

function findCustomerBySmartInput(value = "") {
  return smartMatch(loadCustomers(), value, customerSmartValues);
}

function findCompanyBySmartInput(value = "") {
  return smartMatch(settingsCompanies(), value, companySmartValues);
}

function findItemBySmartInput(value = "") {
  return smartMatch(readStore(ITEM_KEY, []).map(normalizeItem), value, itemSmartValues);
}

function applyCustomerToDocument(customer) {
  if (!customer) return;
  els.customerName.value = customer.companyName || "";
  els.customerAddress.value = customer.companyAddress || "";
  els.customerContact.value = customerDisplayContact(customer);
  if (els.customerEmail) els.customerEmail.value = customer.email || customer.contactEmail || "";
  renderPreview();
  setDirty(true);
}

function seedItems() {
  if (readStore(ITEM_KEY, []).length) return;
  writeStore(ITEM_KEY, [
    { id: crypto.randomUUID(), name: "智慧ミラー", model: "SM-GLASS-42", specification: "42インチ / Android OS / 壁掛け金具付き", unitPrice: 98000 },
    { id: crypto.randomUUID(), name: "Webサイト制作 一式", model: "WEB-PROD", specification: "企画・設計・実装 一式", unitPrice: 180000 },
    { id: crypto.randomUUID(), name: "保守サポート 月額", model: "SUPPORT-M", specification: "月次保守 / 軽微修正", unitPrice: 30000 },
  ]);
}

function normalizeItem(item = {}) {
  const fallbackModels = {
    "智慧ミラー": "SM-GLASS-42",
    "Webサイト制作 一式": "WEB-PROD",
    "保守サポート 月額": "SUPPORT-M",
  };
  return {
    id: item.id || crypto.randomUUID(),
    name: item.name || "",
    model: item.model || item.sku || fallbackModels[item.name] || "",
    specification: item.specification || item.spec || "",
    unitPrice: Number(item.unitPrice || 0),
  };
}

function migrateItems() {
  const items = readStore(ITEM_KEY, [])
    .filter((item) => item.name !== "軽減税率対象サンプル")
    .map(normalizeItem);
  writeStore(ITEM_KEY, items);
}

function nextDocNumber(type) {
  const docs = loadDocuments();
  const used = usedDocumentNumbers(docs);
  let count = docs.filter((doc) => doc.docType === type).length + 1;
  const ymd = today().replaceAll("-", "");
  let candidate = "";
  do {
    candidate = `${DOC_TYPES[type]?.prefix || "DOC"}-${ymd}-${String(count).padStart(3, "0")}`;
    count += 1;
  } while (used.has(candidate));
  return candidate;
}

function usedDocumentNumbers(docs = loadDocuments()) {
  const numbers = new Set();
  docs.forEach((doc) => {
    [
      doc.docNumber,
      doc.sourceDocumentNumber,
      doc.customRelatedNumber,
      ...Object.values(doc.relatedDocumentNumbers || {}),
    ].filter(Boolean).forEach((number) => numbers.add(String(number)));
  });
  return numbers;
}

function compactUnique(values = []) {
  return [...new Set(values.filter(Boolean).map(String))];
}

function normalizeFormObject(doc = {}) {
  const id = doc.id || doc.formObjectId || crypto.randomUUID();
  const docType = DOC_TYPES[doc.docType] ? doc.docType : "invoice";
  const relatedFormIds = compactUnique([
    ...(doc.relatedFormIds || []),
    doc.sourceDocumentId,
    ...(doc.convertedDocumentIds || []),
  ]).filter((relatedId) => relatedId !== id);
  return {
    ...doc,
    id,
    formObjectId: doc.formObjectId || id,
    objectType: "form",
    schemaVersion: FORM_OBJECT_SCHEMA_VERSION,
    docType,
    projectDirection: normalizeProjectDirection(doc.projectDirection),
    relatedFormIds,
    relatedDocumentNumbers: singleRelatedDocumentNumbers({ ...doc, docType }),
    relatedDocumentType: relatedDocumentType(doc),
    relatedNumberMode: relatedNumberMode(doc),
    convertedDocumentIds: compactUnique(doc.convertedDocumentIds || []),
    customerOrderFiles: Array.isArray(doc.customerOrderFiles) ? doc.customerOrderFiles.map(normalizeCustomerOrderFile) : [],
    updatedAt: doc.updatedAt || new Date().toISOString(),
  };
}

function collectDocumentNumbers(doc = {}) {
  return {
    ...(doc.relatedDocumentNumbers || {}),
    ...(doc.sourceDocumentType && doc.sourceDocumentNumber ? { [doc.sourceDocumentType]: doc.sourceDocumentNumber } : {}),
    ...(doc.docType && doc.docNumber ? { [doc.docType]: doc.docNumber } : {}),
  };
}

function canonicalChainType(type) {
  if (type === "purchaseOrder") return "order";
  return CHAIN_ORDER.includes(type) ? type : "";
}

function equivalentChainTypes(type) {
  const canonical = canonicalChainType(type);
  return canonical ? (CHAIN_ALTERNATES[canonical] || [canonical]) : [type].filter(Boolean);
}

function priorChainTypes(type) {
  const canonical = canonicalChainType(type);
  const index = CHAIN_ORDER.indexOf(canonical);
  return index > 0 ? CHAIN_ORDER.slice(0, index) : [];
}

function immediateUpstreamTypes(type) {
  const priors = priorChainTypes(type);
  const immediate = priors.at(-1);
  return immediate ? equivalentChainTypes(immediate) : [];
}

function chainNumberForType(numbers = {}, type) {
  return equivalentChainTypes(type).map((candidate) => numbers[candidate]).find(Boolean) || numbers[type] || "";
}

function assignChainNumber(numbers = {}, type, value) {
  const canonical = canonicalChainType(type) || type;
  return value ? { ...numbers, [canonical]: value } : { ...numbers };
}

function ensurePlaceholderNumber(type, numbers = {}, docs = loadDocuments()) {
  const existing = chainNumberForType(numbers, type);
  if (existing) return existing;
  const used = usedDocumentNumbers(docs);
  Object.values(numbers).filter(Boolean).forEach((number) => used.add(String(number)));
  let count = docs.filter((doc) => equivalentChainTypes(type).includes(doc.docType)).length + 1;
  const ymd = today().replaceAll("-", "");
  let candidate = "";
  do {
    candidate = `${DOC_TYPES[type]?.prefix || "DOC"}-${ymd}-${String(count).padStart(3, "0")}`;
    count += 1;
  } while (used.has(candidate));
  return candidate;
}

function inheritedRelatedNumbers(source = {}, targetType = source.docType) {
  const docs = loadDocuments();
  const immediate = immediateUpstreamTypes(targetType)[0];
  if (!immediate) return {};
  const sourceNumbers = collectDocumentNumbers(source);
  const sourceIsImmediate = equivalentChainTypes(immediate).includes(source.docType);
  const number = sourceIsImmediate
    ? source.docNumber
    : chainNumberForType(sourceNumbers, immediate) || ensurePlaceholderNumber(immediate, sourceNumbers, docs);
  return assignChainNumber({}, immediate, number);
}

function inheritedRelatedNumberFor(doc = {}) {
  const numbers = collectDocumentNumbers(doc);
  const immediate = immediateUpstreamTypes(doc.docType);
  return immediate.map((type) => numbers[type]).find(Boolean) ||
    priorChainTypes(doc.docType).reverse().map((type) => chainNumberForType(numbers, type)).find(Boolean) ||
    doc.sourceDocumentNumber ||
    "";
}

function relatedNumberMode(doc = {}) {
  if (doc.docType === "estimate") return "manual";
  const mode = doc.relatedNumberMode || (doc.customRelatedNumber ? "manual" : "auto");
  return ["auto", "manual", "overwrite", "blank"].includes(mode) ? mode : "auto";
}

function relatedMenuOptions(docType = state.docType) {
  const current = canonicalChainType(docType) || docType;
  return FLOW_STEPS
    .map((step) => ({ type: step.type, label: RELATED_MENU_LABELS[step.type] || step.label }))
    .filter((option) => option.type !== current && !equivalentChainTypes(option.type).includes(docType));
}

function relatedDocumentType(doc = {}) {
  const options = relatedMenuOptions(doc.docType);
  if (!options.length) return "";
  const optionTypes = options.map((option) => option.type);
  const explicit = canonicalChainType(doc.relatedDocumentType) || doc.relatedDocumentType;
  if (optionTypes.includes(explicit)) return explicit;
  const entryType = canonicalChainType(singleReferenceEntry(doc)?.type) || singleReferenceEntry(doc)?.type;
  if (optionTypes.includes(entryType)) return entryType;
  const upstream = immediateUpstreamTypes(doc.docType).map((type) => canonicalChainType(type) || type).find((type) => optionTypes.includes(type));
  return upstream || optionTypes[0] || "";
}

function applyRelatedNumberMode(doc = {}) {
  const mode = relatedNumberMode(doc);
  if (mode === "blank") {
    return {
      ...doc,
      sourceDocumentId: "",
      sourceDocumentNumber: "",
      sourceDocumentType: "",
      relatedFormIds: [],
      relatedDocumentNumbers: {},
      relatedDocumentType: "",
      customRelatedNumber: "",
      relatedNumberMode: mode,
    };
  }
  if (mode === "auto") {
    return { ...doc, customRelatedNumber: inheritedRelatedNumberFor(doc), relatedNumberMode: mode };
  }
  return { ...doc, relatedNumberMode: mode };
}

function singleRelatedDocumentNumbers(doc = {}) {
  if (relatedNumberMode(doc) === "blank") return {};
  const upstreamTypes = immediateUpstreamTypes(doc.docType);
  const upstreamType = upstreamTypes[0];
  if (!upstreamType) return {};
  const custom = String(doc.customRelatedNumber || "").trim();
  if (custom) return assignChainNumber({}, upstreamType, custom);
  const numbers = { ...(doc.relatedDocumentNumbers || {}) };
  const existingType = upstreamTypes.find((type) => numbers[type]);
  if (existingType) return assignChainNumber({}, existingType, numbers[existingType]);
  if (upstreamTypes.includes(doc.sourceDocumentType) && doc.sourceDocumentNumber) {
    return assignChainNumber({}, doc.sourceDocumentType, doc.sourceDocumentNumber);
  }
  return {};
}

function referenceEntries(doc = {}, options = {}) {
  if (doc.docType === "estimate") return [];
  const entry = singleReferenceEntry(doc, options);
  return entry ? [entry] : [];
}

function singleReferenceEntry(doc = {}, options = {}) {
  if (relatedNumberMode(doc) === "blank") return null;
  const numbers = collectDocumentNumbers(doc);
  const upstreamTypes = immediateUpstreamTypes(doc.docType);
  const custom = String(doc.customRelatedNumber || "").trim();
  const customType = upstreamTypes[0] || doc.sourceDocumentType || "";
  if (custom) return { type: customType, title: DOC_TYPES[customType]?.title || "帳票", number: custom };
  const upstreamNumber = upstreamTypes.map((type) => numbers[type]).find(Boolean);
  if (upstreamNumber) {
    const type = upstreamTypes.find((candidate) => numbers[candidate] === upstreamNumber) || upstreamTypes[0];
    return { type, title: DOC_TYPES[type]?.title || "帳票", number: upstreamNumber };
  }
  if (doc.sourceDocumentType && doc.sourceDocumentNumber && doc.sourceDocumentType !== doc.docType) {
    return {
      type: doc.sourceDocumentType,
      title: DOC_TYPES[doc.sourceDocumentType]?.title || "帳票",
      number: doc.sourceDocumentNumber,
    };
  }
  if (!options.includeCurrent) return null;
  const fallback = Object.entries(numbers).find(([type, number]) => type !== doc.docType && number);
  return fallback ? { type: fallback[0], title: DOC_TYPES[fallback[0]]?.title || "帳票", number: fallback[1] } : null;
}

function formatReferenceEntries(entries) {
  return entries.map((entry) => `${entry.title} ${entry.number}`).join(" / ");
}

function documentReferenceText(doc) {
  const refs = referenceEntries(doc);
  return refs.length ? ` / 関連: ${formatReferenceEntries(refs)}` : "";
}

function defaultDocument(type = state.docType, options = {}) {
  const definition = formDefinition(type);
  const projectDirection = normalizeProjectDirection(options.projectDirection || state.projectDirection);
  return {
    id: crypto.randomUUID(),
    projectId: "",
    projectName: "",
    projectDirection,
    docType: type,
    templateId: state.templateId || "monochrome",
    docNumber: nextDocNumber(type),
    issueDate: today(),
    transactionDate: today(),
    dueDate: addDays(30),
    honorific: "御中",
    customerName: "",
    customerAddress: "",
    customerContact: "",
    customerEmail: "",
    issuerName: "",
    issuerRegistration: "",
    issuerAddress: "",
    issuerContact: "",
    issuerPhone: "",
    issuerEmail: "",
    notes: definition.defaultNotes,
    bankDetails: "",
    documentSpecifics: definition.defaultSpecifics,
    taxRate: 8,
    sourceDocumentId: "",
    sourceDocumentNumber: "",
    sourceDocumentType: "",
    relatedFormIds: [],
    relatedDocumentNumbers: {},
    relatedDocumentType: "",
    customRelatedNumber: "",
    relatedNumberMode: "auto",
    showRelatedNumber: true,
    convertedDocumentIds: [],
    notices: [],
    customerOrderFiles: [],
    lines: projectDirection === "inbound" || type === "customerFiles" || isCustomerOrderRecord(type)
      ? [{ id: crypto.randomUUID(), name: "", model: "", specification: "", quantity: 1, unitPrice: 0 }]
      : [{ id: crypto.randomUUID(), name: "智慧ミラー", model: "SM-GLASS-42", specification: "42インチ / Android OS / 壁掛け金具付き", quantity: 10, unitPrice: 98000 }],
  };
}

function taxRateFromMode(taxMode) {
  if (taxMode === "standard10") return 10;
  if (taxMode === "none") return 0;
  return 8;
}

function taxModeFromRate(taxRate) {
  if (taxRate <= 0) return "none";
  if (taxRate === 10) return "standard10";
  return "reduced8";
}

function normalizeTaxRate(value, fallback = 8) {
  if (value === undefined || value === null || value === "") return fallback;
  const rate = Number(value);
  if (!Number.isFinite(rate)) return fallback;
  return Math.max(0, rate);
}

function documentTaxRate(doc) {
  if (doc.taxRate !== undefined && doc.taxRate !== null && doc.taxRate !== "") {
    return normalizeTaxRate(doc.taxRate);
  }
  return taxRateFromMode(doc.taxMode);
}

function getFormData() {
  const taxRate = normalizeTaxRate(els.taxRate?.value, 8);
  const relatedNumberInput = els.customRelatedNumber?.value.trim() || "";
  return {
    id: state.currentId,
    projectId: state.projectId || "",
    projectName: state.projectName || "",
    projectDirection: normalizeProjectDirection(state.projectDirection),
    docType: state.docType,
    templateId: state.templateId,
    docNumber: els.docNumber.value.trim(),
    issueDate: els.issueDate.value,
    transactionDate: els.transactionDate?.value || els.issueDate.value,
    dueDate: els.dueDate.value,
    honorific: els.honorific.value,
    customerName: els.customerName.value.trim(),
    customerAddress: els.customerAddress.value.trim(),
    customerContact: els.customerContact.value.trim(),
    customerEmail: els.customerEmail?.value.trim() || "",
    issuerName: els.issuerName.value.trim(),
    issuerRegistration: els.issuerRegistration.value.trim(),
    issuerAddress: els.issuerAddress.value.trim(),
    issuerContact: els.issuerContact?.value.trim() || "",
    issuerPhone: els.issuerPhone.value.trim(),
    issuerEmail: els.issuerEmail.value.trim(),
    notes: els.notes.value.trim(),
    bankDetails: els.bankDetails.value.trim(),
    documentSpecifics: els.documentSpecifics?.value.trim() || "",
    taxRate,
    taxMode: taxModeFromRate(taxRate),
    sourceDocumentId: state.sourceDocumentId || "",
    sourceDocumentNumber: state.sourceDocumentNumber || "",
    sourceDocumentType: state.sourceDocumentType || "",
    formObjectId: state.currentId,
    objectType: "form",
    schemaVersion: FORM_OBJECT_SCHEMA_VERSION,
    relatedFormIds: compactUnique(state.relatedFormIds || []).filter((id) => id !== state.currentId),
    relatedDocumentNumbers: {
      ...(state.relatedDocumentNumbers || {}),
    },
    relatedDocumentType: els.relatedDocumentType?.value || state.relatedDocumentType || "",
    customRelatedNumber: relatedNumberInput,
    relatedNumberMode: state.docType === "estimate" ? "manual" : relatedNumberInput ? "manual" : "auto",
    showRelatedNumber: state.docType !== "estimate" && (els.showRelatedNumber ? els.showRelatedNumber.checked : true),
    convertedDocumentIds: [...(state.convertedDocumentIds || [])],
    notices: [...(state.notices || [])],
    customerOrderFiles: [...(state.customerOrderFiles || [])].map(normalizeCustomerOrderFile),
    issuerLogo: state.issuerLogo || "",
    lines: state.lines.map((line) => ({
      id: line.id,
      sourceLineId: line.sourceLineId || "",
      name: line.name,
      model: line.model || "",
      specification: line.specification || "",
      quantity: Number(line.quantity || 0),
      unitPrice: Number(line.unitPrice || 0),
    })),
    updatedAt: new Date().toISOString(),
  };
}

function setFormData(doc) {
  doc = applyRelatedNumberMode(normalizeFormObject(doc));
  const docType = DOC_TYPES[doc.docType] ? doc.docType : "invoice";
  state.mobileExpandedSections = new Set();
  state.currentId = doc.id;
  state.projectId = doc.projectId || "";
  state.projectName = doc.projectName || "";
  state.projectDirection = normalizeProjectDirection(doc.projectDirection);
  state.docType = docType;
  state.templateId = doc.templateId || state.templateId || "monochrome";
  state.sourceDocumentId = doc.sourceDocumentId || "";
  state.sourceDocumentNumber = doc.sourceDocumentNumber || "";
  state.sourceDocumentType = doc.sourceDocumentType || "";
  state.relatedFormIds = compactUnique(doc.relatedFormIds || []).filter((id) => id !== doc.id);
  state.relatedDocumentNumbers = { ...(doc.relatedDocumentNumbers || {}) };
  state.relatedDocumentType = relatedDocumentType(doc);
  state.relatedNumberMode = relatedNumberMode(doc);
  state.convertedDocumentIds = Array.isArray(doc.convertedDocumentIds) ? doc.convertedDocumentIds : [];
  state.notices = Array.isArray(doc.notices) ? doc.notices : [];
  state.customerOrderFiles = Array.isArray(doc.customerOrderFiles) ? doc.customerOrderFiles.map(normalizeCustomerOrderFile) : [];
  state.lines = doc.lines?.length ? doc.lines : defaultDocument(docType).lines;
  state.issuerLogo = doc.issuerLogo || defaultCompany()?.logo || "";
  if (!doc.issuerName) {
    const company = defaultCompany();
    if (company) {
      doc = {
        ...doc,
        issuerName: company.name,
        issuerRegistration: company.registration,
        issuerAddress: company.address,
        issuerContact: company.contact,
        issuerPhone: company.phone,
        issuerEmail: company.email,
      };
    }
  }

  for (const key of [
    "docNumber",
    "issueDate",
    "transactionDate",
    "dueDate",
    "honorific",
    "showRelatedNumber",
    "relatedDocumentType",
    "customRelatedNumber",
    "relatedNumberMode",
    "customerName",
    "customerAddress",
    "customerContact",
    "customerEmail",
    "issuerName",
    "issuerRegistration",
    "issuerAddress",
    "issuerContact",
    "issuerPhone",
    "issuerEmail",
    "notes",
    "bankDetails",
    "documentSpecifics",
    "taxRate",
  ]) {
    if (els[key]) els[key].value = doc[key] || "";
  }
  if (els.taxRate) els.taxRate.value = documentTaxRate(doc);
  if (els.showRelatedNumber) els.showRelatedNumber.checked = doc.showRelatedNumber !== false;
  renderRelatedDocumentTypeOptions(doc);
  renderRelatedNumberPicker(doc);
  if (els.relatedDocumentType) els.relatedDocumentType.value = state.relatedDocumentType;
  if (els.customRelatedNumber) els.customRelatedNumber.value = doc.customRelatedNumber || "";
  if (els.relatedNumberMode) els.relatedNumberMode.value = doc.customRelatedNumber || inheritedRelatedNumberFor(doc) || "";

  renderLines();
  renderAll();
  setDirty(false);
}

function totals(doc) {
  const subtotal = doc.lines.reduce((total, line) => total + Number(line.quantity || 0) * Number(line.unitPrice || 0), 0);
  const taxRate = documentTaxRate(doc);
  const taxable10 = 0;
  const taxable8 = taxRate > 0 ? subtotal : 0;
  const taxable0 = taxRate > 0 ? 0 : subtotal;
  const tax8 = Math.floor(taxable8 * (taxRate / 100));
  const tax10 = 0;
  return { subtotal, taxRate, taxable8, taxable10, taxable0, tax8, tax10, total: subtotal + tax8 };
}

function documentIssueItems(doc, sum = totals(doc)) {
  const definition = formDefinition(doc.docType);
  const issues = [];
  const isReceivedRecord = isReceivedDocumentRecord(doc);
  const isCustomerFiles = isCustomerFilesDocument(doc);
  if (!String(doc.docNumber || "").trim()) issues.push({ id: "docNumber", message: "帳票番号が未入力", field: "docNumber" });
  if (!String(doc.customerName || "").trim()) issues.push({ id: "customerName", message: `${definition.partySection || "取引先"}が未入力`, field: "customerName" });
  if (!isReceivedRecord && !String(doc.issuerName || "").trim()) issues.push({ id: "issuerName", message: `${definition.issuerSection || "発行者"}が未入力`, field: "issuerName" });
  if (!isCustomerFiles && !String(doc.issueDate || "").trim()) issues.push({ id: "issueDate", message: "発行日が未入力", field: "issueDate" });
  if (!isCustomerFiles && !String(doc.transactionDate || "").trim()) issues.push({ id: "transactionDate", message: `${definition.transactionLabel || "取引日"}が未入力`, field: "transactionDate" });
  if (!isCustomerFiles && !String(doc.dueDate || "").trim()) issues.push({ id: "dueDate", message: `${definition.dueLabel || "期限"}が未入力`, field: "dueDate" });
  if (isReceivedRecord) {
    const hasFiles = doc.customerOrderFiles?.some((file) => file.dataUrl);
    const hasMemo = [doc.notes, doc.documentSpecifics]
      .some((value) => {
        const text = String(value || "").trim();
        return text && text !== definition.defaultNotes && text !== definition.defaultSpecifics;
      });
    const hasLines = doc.lines?.some((line) => String(line.name || "").trim());
    if (!hasFiles && !hasMemo && !hasLines) issues.push({ id: "customerOrderFiles", message: "受領資料または確認メモが未入力", field: "customerOrderFileInput" });
  } else if (!doc.lines?.length || doc.lines.every((line) => !String(line.name || "").trim())) {
    issues.push({ id: "lineItems", message: "明細が未入力", field: "lineItems" });
  }
  if (doc.docType === "purchaseOrder" && !String(doc.bankDetails || "").trim()) issues.push({ id: "bankDetails", message: "支払・発注条件が未入力", field: "bankDetails" });
  if (doc.docType === "purchaseOrder" && sum.total <= 0) issues.push({ id: "total", message: "発注金額を確認", field: "lineItems" });
  if (["invoice", "receipt"].includes(doc.docType) && !/^T\d{13}$/.test(doc.issuerRegistration || "")) issues.push({ id: "issuerRegistration", message: "登録番号を確認", field: "issuerRegistration" });
  if (["invoice", "receipt"].includes(doc.docType) && sum.total <= 0) issues.push({ id: "total", message: "合計金額を確認", field: "lineItems" });
  return issues;
}

function documentIssueMessages(doc, sum = totals(doc)) {
  return documentIssueItems(doc, sum).map((issue) => issue.message);
}

function simplifiedFieldTitle(label) {
  if (!label) return null;
  const existing = label.querySelector(":scope > .input-title, :scope > span[id$='Label']");
  if (existing) return existing;

  const title = document.createElement("span");
  title.className = "input-title";
  const text = Array.from(label.childNodes)
    .filter((node) => node.nodeType === Node.TEXT_NODE)
    .map((node) => node.textContent.trim())
    .filter(Boolean)
    .join(" ");

  Array.from(label.childNodes)
    .filter((node) => node.nodeType === Node.TEXT_NODE)
    .forEach((node) => node.remove());

  const firstControl = label.querySelector(":scope > input, :scope > textarea, :scope > select");
  if (firstControl) label.insertBefore(title, firstControl);
  else label.prepend(title);
  if (text) title.dataset.defaultLabel = text;
  return title;
}

function labelTitleText(label) {
  const title = label?.querySelector(":scope > .input-title, :scope > span[id$='Label']");
  if (title?.dataset.defaultLabel) return title.dataset.defaultLabel;
  const text = title?.textContent?.trim();
  if (text) return text;
  return Array.from(label?.childNodes || [])
    .filter((node) => node.nodeType === Node.TEXT_NODE)
    .map((node) => node.textContent.trim())
    .filter(Boolean)
    .join(" ");
}

function simplifyInputLabels(root = document) {
  root.querySelectorAll("label").forEach((label) => {
    const control = label.querySelector(":scope > input:not([type='radio']):not([type='checkbox']):not([type='file']):not([type='color']):not([type='hidden']), :scope > select, :scope > textarea");
    if (!control) return;
    const title = simplifiedFieldTitle(label);
    const text = labelTitleText(label) || control.getAttribute("aria-label") || control.name || control.id;
    if (title && !title.dataset.defaultLabel) title.dataset.defaultLabel = text;
    if (text && control.matches("input, textarea")) control.placeholder = text;
    label.classList.add("simplified-field");
  });
  updatePrefixedFields(root);
}

function updateSimplifiedPlaceholders(root = document) {
  root.querySelectorAll("label.simplified-field").forEach((label) => {
    const control = label.querySelector(":scope > input:not([type='radio']):not([type='checkbox']):not([type='file']):not([type='color']):not([type='hidden']), :scope > select, :scope > textarea");
    if (!control) return;
    const title = label.querySelector(":scope > .input-title, :scope > span[id$='Label']");
    const text = title?.dataset.defaultLabel || title?.textContent?.trim() || labelTitleText(label);
    if (text) {
      if (control.matches("input, textarea")) control.placeholder = text;
      if (title) title.dataset.defaultLabel = text;
    }
  });
  updatePrefixedFields(root);
}

function updatePrefixedFields(root = document) {
  root.querySelectorAll("label.simplified-field").forEach((label) => {
    const control = label.querySelector(":scope > input:not([type='radio']):not([type='checkbox']):not([type='file']):not([type='color']):not([type='hidden']), :scope > select, :scope > textarea");
    if (!control || !label) return;
    const title = label.querySelector(":scope > .input-title, :scope > span[id$='Label']");
    const text = title?.dataset.defaultLabel || title?.textContent?.trim() || labelTitleText(label);
    if (!text) return;
    const isDate = control.type === "date";
    const isTextarea = control.tagName === "TEXTAREA";
    label.classList.toggle("date-prefixed-field", isDate);
    label.classList.toggle("textarea-prefixed-field", isTextarea);
    label.classList.toggle("input-prefixed-field", !isDate && !isTextarea);
    label.dataset.fieldPrefix = text;
    control.dataset.fieldTitle = text;
    delete label.dataset.datePrefix;
    if (control.matches("input, textarea")) control.placeholder = text;
    control.title = text;
    control.setAttribute("aria-label", text);
    control.style.setProperty("--field-prefix-width", "0px");
  });
}

function clearFieldIssueTitles(root = document) {
  root.querySelectorAll("label.simplified-field").forEach((label) => {
    const control = label.querySelector(":scope > input, :scope > textarea");
    const title = label.querySelector(":scope > .input-title, :scope > span[id$='Label']");
    label.classList.remove("has-field-issue");
    if (title) title.textContent = "";
    if (control) {
      control.removeAttribute("aria-invalid");
      if (control.dataset.defaultPlaceholder !== undefined) {
        control.placeholder = control.dataset.defaultPlaceholder;
        delete control.dataset.defaultPlaceholder;
      }
    }
  });
  document.querySelectorAll(".line-table th.has-field-issue").forEach((heading) => {
    heading.textContent = heading.dataset.defaultLabel || heading.textContent;
    heading.classList.remove("has-field-issue");
  });
  root.querySelectorAll('[aria-invalid="true"]').forEach((control) => {
    control.removeAttribute("aria-invalid");
    if (control.dataset.defaultPlaceholder !== undefined) {
      control.placeholder = control.dataset.defaultPlaceholder;
      delete control.dataset.defaultPlaceholder;
    }
  });
}

function showFieldIssue(fieldId, message) {
  if (fieldId === "lineItems") {
    const heading = document.querySelector(".line-table th:first-child");
    if (heading) {
      if (!heading.dataset.defaultLabel) heading.dataset.defaultLabel = heading.textContent.trim();
      heading.textContent = message;
      heading.classList.add("has-field-issue");
    }
    els.lineItems?.querySelectorAll("input").forEach((input) => {
      if (input.dataset.defaultPlaceholder === undefined) input.dataset.defaultPlaceholder = input.placeholder || "";
      input.placeholder = message;
      input.setAttribute("aria-invalid", "true");
    });
    return;
  }

  const control = els[fieldId] || document.getElementById(fieldId);
  const label = control?.closest("label");
  if (!control || !label) return;
  const title = simplifiedFieldTitle(label);
  label.classList.add("simplified-field", "has-field-issue");
  if (title) title.textContent = message;
  if (control.matches("input, textarea")) {
    if (control.dataset.defaultPlaceholder === undefined) control.dataset.defaultPlaceholder = control.placeholder || "";
    control.placeholder = message;
  }
  control.setAttribute("aria-invalid", "true");
}

function renderFieldIssues(doc = getFormData()) {
  clearFieldIssueTitles();
  const issues = documentIssueItems(doc);
  issues.forEach((issue) => showFieldIssue(issue.field, issue.message));
  renderMobileSectionIssueSummaries(issues);
}

function isMobileFormLayout() {
  return Boolean(window.matchMedia?.("(max-width: 760px)").matches);
}

function formSectionKey(section, index) {
  if (!section.dataset.mobileSectionKey) section.dataset.mobileSectionKey = `section-${index}`;
  return section.dataset.mobileSectionKey;
}

function sectionForIssueField(fieldId) {
  if (fieldId === "lineItems") return els.lineItems?.closest(".form-section") || null;
  const control = els[fieldId] || document.getElementById(fieldId);
  return control?.closest(".form-section") || null;
}

function ensureSectionIssueNode(section) {
  const heading = section?.querySelector(":scope > .section-heading");
  if (!heading) return null;
  let node = heading.querySelector(":scope > .section-issue-summary");
  if (!node) {
    node = document.createElement("span");
    node.className = "section-issue-summary";
    heading.appendChild(node);
  }
  return node;
}

function renderMobileSectionIssueSummaries(issues = documentIssueItems()) {
  const sections = [...(els.documentForm?.querySelectorAll(":scope > .form-section") || [])];
  sections.forEach((section) => {
    const node = ensureSectionIssueNode(section);
    if (!node) return;
    node.textContent = "";
    node.hidden = true;
  });

  const messagesBySection = new Map();
  issues.forEach((issue) => {
    const section = sectionForIssueField(issue.field);
    if (!section) return;
    const messages = messagesBySection.get(section) || [];
    messages.push(issue.message);
    messagesBySection.set(section, messages);
  });

  messagesBySection.forEach((messages, section) => {
    const node = ensureSectionIssueNode(section);
    if (!node) return;
    node.textContent = compactUnique(messages).join(" / ");
    node.hidden = false;
  });
  syncMobileFormAccordions();
}

function syncMobileFormAccordions() {
  const sections = [...(els.documentForm?.querySelectorAll(":scope > .form-section") || [])];
  sections.forEach((section, index) => {
    const key = formSectionKey(section, index);
    const heading = section.querySelector(":scope > .section-heading");
    const isBasic = index === 0;
    const isLineSection = Boolean(section.querySelector("#lineItems")) || heading?.querySelector("h2")?.textContent.trim() === "明細";
    const canCollapse = isMobileFormLayout() && Boolean(heading) && !isBasic && !isLineSection;
    const collapsed = canCollapse && !state.mobileExpandedSections.has(key);
    section.classList.toggle("mobile-collapsible-section", canCollapse);
    section.classList.toggle("mobile-force-expanded", isMobileFormLayout() && isLineSection);
    section.classList.toggle("mobile-collapsed", collapsed);
    if (heading) {
      heading.setAttribute("role", canCollapse ? "button" : "presentation");
      heading.setAttribute("aria-expanded", String(!collapsed));
      heading.tabIndex = canCollapse ? 0 : -1;
    }
  });
}

function toggleMobileFormSection(section) {
  if (!isMobileFormLayout() || !section || section.parentElement !== els.documentForm) return;
  const sections = [...els.documentForm.querySelectorAll(":scope > .form-section")];
  const index = sections.indexOf(section);
  if (index <= 0) return;
  if (section.classList.contains("mobile-force-expanded")) return;
  const key = formSectionKey(section, index);
  if (state.mobileExpandedSections.has(key)) state.mobileExpandedSections.delete(key);
  else state.mobileExpandedSections.add(key);
  syncMobileFormAccordions();
}

function restoreMobileTitle() {
  window.clearTimeout(state.mobileTitleRestoreTimer);
  state.mobileTitleRestoreTimer = null;
  document.body.classList.remove("mobile-title-hidden");
}

function hideMobileTitleWhileScrolling(scroller) {
  if (!isMobileFormLayout()) return;
  state.mobileLastScrollTop = scroller?.scrollTop || 0;
}

function bindMobileTitleAutoHide() {
  const scrollers = [els.documentForm, document.querySelector(".preview-column")].filter(Boolean);
  scrollers.forEach((scroller) => {
    scroller.addEventListener("scroll", () => hideMobileTitleWhileScrolling(scroller), { passive: true });
    scroller.addEventListener("touchstart", () => {
      state.mobileLastScrollTop = scroller.scrollTop || 0;
      window.clearTimeout(state.mobileTitleRestoreTimer);
    }, { passive: true });
    scroller.addEventListener("touchend", restoreMobileTitle, { passive: true });
    scroller.addEventListener("touchcancel", restoreMobileTitle, { passive: true });
  });
}

function syncMobileActionBarPosition() {
  const bar = document.querySelector(".mobile-action-bar");
  if (!bar) return;
  const viewport = window.visualViewport;
  const activeElement = document.activeElement;
  const isEditing = activeElement?.matches?.("input, textarea, select");
  const bottomInset = viewport && isEditing ? Math.max(0, window.innerHeight - viewport.height - viewport.offsetTop) : 0;
  document.documentElement.style.setProperty("--mobile-viewport-bottom", `${Math.round(bottomInset)}px`);
}

function bindMobileActionBarStability() {
  syncMobileActionBarPosition();
  window.addEventListener("resize", syncMobileActionBarPosition, { passive: true });
  window.addEventListener("orientationchange", syncMobileActionBarPosition, { passive: true });
  window.addEventListener("focusin", syncMobileActionBarPosition, { passive: true });
  window.addEventListener("focusout", () => {
    document.documentElement.style.setProperty("--mobile-viewport-bottom", "0px");
  }, { passive: true });
  window.visualViewport?.addEventListener("resize", syncMobileActionBarPosition, { passive: true });
}

function relatedFlowDocuments(currentDoc = getFormData()) {
  const docs = loadDocuments();
  const ids = new Set([
    currentDoc.id,
    currentDoc.sourceDocumentId,
    ...(currentDoc.convertedDocumentIds || []),
    ...(currentDoc.relatedFormIds || []),
  ].filter(Boolean));
  const numbers = new Set([currentDoc.docNumber, currentDoc.sourceDocumentNumber, currentDoc.customRelatedNumber, ...Object.values(currentDoc.relatedDocumentNumbers || {})].filter(Boolean));
  const projectIds = new Set([currentDoc.projectId].filter(Boolean));
  let changed = true;
  while (changed) {
    changed = false;
    docs.forEach((doc) => {
      const docNumbers = [doc.docNumber, doc.sourceDocumentNumber, doc.customRelatedNumber, ...Object.values(doc.relatedDocumentNumbers || {})].filter(Boolean);
      const docIds = [doc.id, doc.sourceDocumentId, ...(doc.convertedDocumentIds || []), ...(doc.relatedFormIds || [])].filter(Boolean);
      const linked =
        docIds.some((id) => ids.has(id)) ||
        docNumbers.some((number) => numbers.has(number)) ||
        (doc.projectId && projectIds.has(doc.projectId));
      if (!linked) return;
      const before = ids.size + numbers.size + projectIds.size;
      docIds.forEach((id) => ids.add(id));
      docNumbers.forEach((number) => numbers.add(number));
      if (doc.projectId) projectIds.add(doc.projectId);
      changed = ids.size + numbers.size + projectIds.size !== before;
    });
  }

  const byType = new Map();
  docs
    .filter((doc) => {
      const docIds = [doc.id, doc.sourceDocumentId, ...(doc.convertedDocumentIds || []), ...(doc.relatedFormIds || [])].filter(Boolean);
      return docIds.some((id) => ids.has(id)) ||
        [doc.docNumber, doc.sourceDocumentNumber, doc.customRelatedNumber, ...Object.values(doc.relatedDocumentNumbers || {})].some((number) => numbers.has(number)) ||
        (doc.projectId && projectIds.has(doc.projectId));
    })
    .forEach((doc) => {
      const current = byType.get(doc.docType);
      if (!current || String(doc.updatedAt || "").localeCompare(String(current.updatedAt || "")) > 0) {
        byType.set(doc.docType, doc);
      }
    });
  byType.set(currentDoc.docType, currentDoc);
  return byType;
}

function archiveFormKey(type) {
  if (type === "customerFiles") return "customerFiles";
  return ARCHIVE_FORM_TYPES.find((entry) => entry.types.includes(type))?.key || type;
}

function archiveEntriesForProject(projectOrDoc = {}) {
  return isInboundProject(projectOrDoc) ? INBOUND_ARCHIVE_FORM_TYPES : ARCHIVE_FORM_TYPES;
}

function docArchiveDate(doc = {}) {
  return doc.transactionDate || doc.issueDate || doc.updatedAt?.slice(0, 10) || today();
}

function weekStart(value) {
  const base = value ? new Date(`${value}T00:00:00`) : new Date();
  const day = base.getDay();
  const offset = day === 0 ? -6 : 1 - day;
  base.setDate(base.getDate() + offset);
  return base.toISOString().slice(0, 10);
}

function addDateDays(value, days) {
  const date = new Date(`${value}T00:00:00`);
  date.setDate(date.getDate() + days);
  return date.toISOString().slice(0, 10);
}

function archiveCompanyName(project) {
  return project.companyName || NIIX_COMPANY_NAME;
}

function projectDirectionLabel(projectOrDoc = {}) {
  return isInboundProject(projectOrDoc) ? "受領管理" : "発行管理";
}

function projectDisplayName(project) {
  return project.projectName || project.primaryDoc?.projectName || project.primaryDoc?.customerName || `Project ${project.id.slice(0, 8)}`;
}

function buildArchiveProjects() {
  const docs = loadDocuments();
  const seen = new Set();
  const projects = [];

  docs.forEach((doc) => {
    if (seen.has(doc.id)) return;
    const related = relatedFlowDocuments(doc);
    if (doc.projectId) {
      docs.filter((item) => item.projectId === doc.projectId).forEach((item) => related.set(item.docType, item));
    }
    const projectDocs = [...related.values()].filter((item) => item?.id && !seen.has(item.id));
    projectDocs.forEach((item) => seen.add(item.id));
    const allDocs = projectDocs.length ? projectDocs : [doc];
    const sorted = [...allDocs].sort((a, b) => String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")));
    const primaryDoc = sorted[0] || doc;
    const projectId = primaryDoc.projectId || doc.projectId || `legacy-${allDocs.map((item) => item.id).sort()[0]}`;
    const formMap = {};
    allDocs.forEach((item) => {
      const key = isInboundProject(item) ? "customerFiles" : archiveFormKey(item.docType);
      if (!formMap[key] || String(item.updatedAt || "").localeCompare(String(formMap[key].updatedAt || "")) > 0) {
        formMap[key] = item;
      }
    });
    const archiveDate = allDocs.map(docArchiveDate).sort().at(-1) || today();
    const latestUpdatedAt = sorted[0]?.updatedAt || `${archiveDate}T00:00:00.000Z`;
    const projectDirection = normalizeProjectDirection(primaryDoc.projectDirection);
    projects.push({
      id: projectId,
      projectName: primaryDoc.projectName || "",
      projectDirection,
      companyName: projectDirection === "inbound" ? (primaryDoc.customerName || "") : (primaryDoc.issuerName || defaultCompany()?.name || NIIX_COMPANY_NAME),
      customerName: primaryDoc.customerName || "",
      date: archiveDate,
      week: weekStart(archiveDate),
      latestUpdatedAt,
      primaryDoc,
      docs: allDocs,
      formMap,
      completed: archiveEntriesForProject({ projectDirection }).filter((entry) => formMap[entry.key]).length,
    });
  });

  return projects.sort((a, b) => {
    const dateOrder = String(b.date).localeCompare(String(a.date));
    if (dateOrder) return dateOrder;
    return String(b.latestUpdatedAt || "").localeCompare(String(a.latestUpdatedAt || ""));
  });
}

function archiveProjectById(id) {
  return buildArchiveProjects().find((project) => project.id === id) || null;
}

function archiveSearchText(project) {
  return [
    project.id,
    projectDisplayName(project),
    projectDirectionLabel(project),
    archiveCompanyName(project),
    project.customerName,
    ...project.docs.flatMap((doc) => [doc.docNumber, DOC_TYPES[doc.docType]?.title, doc.customerName, doc.issuerName]),
  ].join(" ").toLowerCase();
}

function filteredArchiveProjects() {
  const query = (els.archiveSearchInput?.value || "").trim().toLowerCase();
  return buildArchiveProjects().filter((project) => !query || archiveSearchText(project).includes(query));
}

function groupArchiveProjects(projects) {
  return projects.reduce((groups, project) => {
    const company = archiveCompanyName(project);
    if (!groups[company]) groups[company] = {};
    if (!groups[company][project.week]) groups[company][project.week] = [];
    groups[company][project.week].push(project);
    return groups;
  }, {});
}

function renderArchiveStatusDots(project) {
  return archiveEntriesForProject(project).map((entry) => {
    const doc = project.formMap[entry.key];
    const title = doc ? `${entry.label}: ${doc.docNumber}` : `${entry.label}: 未作成`;
    return `<button class="archive-status-dot ${doc ? "is-on" : "is-missing"}" type="button" title="${escapeHtml(title)}" data-project-form="${escapeHtml(project.id)}" data-form-key="${escapeHtml(entry.key)}">${escapeHtml(entry.label)}</button>`;
  }).join("");
}

function renderArchiveTimeline() {
  if (!els.archiveTimeline) return;
  const projects = filteredArchiveProjects();
  const groups = groupArchiveProjects(projects);
  els.archiveTimeline.innerHTML = "";
  if (!projects.length) {
    els.archiveTimeline.innerHTML = `<div class="empty-master">該当する项目档案はありません。</div>`;
    renderArchiveDetail(null);
    return;
  }
  if (!state.selectedArchiveProjectId || !projects.some((project) => project.id === state.selectedArchiveProjectId)) {
    state.selectedArchiveProjectId = projects[0].id;
  }

  Object.entries(groups).forEach(([company, weeks]) => {
    const section = document.createElement("section");
    section.className = "archive-company-group";
    Object.entries(weeks)
      .sort(([a], [b]) => String(b).localeCompare(String(a)))
      .forEach(([week, weekProjects]) => {
        const weekNode = document.createElement("section");
        weekNode.className = "archive-week-group";
        weekNode.innerHTML = `
          <div class="archive-week-label">
            <strong>${escapeHtml(company)}</strong>
            <span><b>${escapeHtml(formatDate(week))}</b><em>${escapeHtml(formatDate(addDateDays(week, 6)))} まで</em></span>
          </div>
          <div class="archive-week-projects"></div>
        `;
        const projectList = weekNode.querySelector(".archive-week-projects");
        weekProjects
          .sort((a, b) => {
            const dateOrder = String(b.date).localeCompare(String(a.date));
            if (dateOrder) return dateOrder;
            return String(b.latestUpdatedAt || "").localeCompare(String(a.latestUpdatedAt || ""));
          })
          .forEach((project) => {
          const button = document.createElement("div");
          button.className = `archive-project-row ${project.id === state.selectedArchiveProjectId ? "active" : ""}`;
          button.tabIndex = 0;
          button.setAttribute("role", "button");
          button.dataset.projectId = project.id;
          button.innerHTML = `
            <input type="checkbox" data-project-check="${escapeHtml(project.id)}" aria-label="项目を選択" />
            <div class="archive-project-main">
              <div class="archive-project-title">
                <strong>${escapeHtml(projectDisplayName(project))}</strong>
                <small>${escapeHtml(projectDirectionLabel(project))} ${project.completed}/${archiveEntriesForProject(project).length}</small>
              </div>
              <span>${escapeHtml(projectDirectionLabel(project))} / ${escapeHtml(project.customerName || "取引先未入力")} / ${escapeHtml(formatDate(project.date))}</span>
              <div class="archive-status">${renderArchiveStatusDots(project)}</div>
            </div>
          `;
          projectList.appendChild(button);
        });
        section.appendChild(weekNode);
      });
    els.archiveTimeline.appendChild(section);
  });
  renderArchiveDetail(archiveProjectById(state.selectedArchiveProjectId));
}

function renderArchiveDetail(project) {
  if (!els.archiveDetail) return;
  if (!project) {
    els.archiveDetail.innerHTML = `<p class="empty-master">项目を選択してください。</p>`;
    return;
  }
  els.archiveDetail.innerHTML = `
    <div class="archive-detail-head">
      <div>
        <p class="eyebrow">${escapeHtml(archiveCompanyName(project))}</p>
        <h3>${escapeHtml(projectDisplayName(project))}</h3>
        <span>${escapeHtml(projectDirectionLabel(project))} / ${escapeHtml(project.customerName || "取引先未入力")} / ${escapeHtml(formatDate(project.date))}</span>
      </div>
      <div class="archive-detail-actions">
        <button class="secondary-button" type="button" data-export-project="${escapeHtml(project.id)}">ZIP</button>
        <button class="secondary-button danger-button" type="button" data-delete-project="${escapeHtml(project.id)}">项目削除</button>
      </div>
    </div>
    <div class="archive-form-list">
      ${archiveEntriesForProject(project).map((entry) => {
        const doc = project.formMap[entry.key];
        return `
          <div class="archive-form-row ${doc ? "is-complete" : "is-missing"}">
            <button class="archive-form-open" type="button" data-project-form="${escapeHtml(project.id)}" data-form-key="${escapeHtml(entry.key)}">
              <strong>${escapeHtml(entry.label)}</strong>
              <span>${escapeHtml(doc ? `${doc.docNumber} / ${formatDate(doc.updatedAt?.slice(0, 10))}` : "未作成 - クリックして作成")}</span>
            </button>
            ${doc ? `<button class="secondary-button danger-button archive-form-delete" type="button" data-delete-form="${escapeHtml(doc.id)}">削除</button>` : ""}
          </div>
        `;
      }).join("")}
    </div>
  `;
}

async function openArchiveProjectForm(projectId, formKey) {
  const project = archiveProjectById(projectId);
  if (!project) return;
  const entry = archiveEntriesForProject(project).find((item) => item.key === formKey);
  if (!entry) return;
  const existing = project.formMap[entry.key];
  if (existing) {
    if (await loadDocument(existing.id)) {
      els.archiveDialog?.close();
      setMobileView("form");
    }
    return;
  }
  if (!(await confirmLeaveCurrentDocument())) return;
  let targetType = entry.key === "customerFiles"
    ? "customerFiles"
    : entry.key === "order" && entry.types.length > 1
    ? (isInboundProject(project) ? "order" : "purchaseOrder")
    : entry.types[0];
  const source = project.primaryDoc || project.docs[0] || defaultDocument(targetType);
  const next = buildConvertedDocument(source, targetType);
  next.projectId = project.id.startsWith("legacy-") ? crypto.randomUUID() : project.id;
  next.projectName = projectDisplayName(project);
  next.projectDirection = normalizeProjectDirection(project.projectDirection);
  next.docType = targetType;
  next.docNumber = chainNumberForType(next.relatedDocumentNumbers || {}, targetType) || nextDocNumber(targetType);
  next.issueDate = today();
  next.transactionDate = today();
  next.updatedAt = new Date().toISOString();
  const docs = loadDocuments().map((doc) => project.docs.some((item) => item.id === doc.id) ? { ...doc, projectId: next.projectId, projectName: next.projectName } : doc);
  upsertDocument(docs, next);
  storeDocuments(docs);
  setFormData(next);
  els.archiveDialog?.close();
  setMobileView("form");
}

function archiveProjectNameForCompany(companyName) {
  return `${today()} ${companyName}`.trim();
}

function renderArchiveProjectCompanyOptions() {
  if (!els.archiveProjectCompanySelect) return;
  const customers = loadCustomers();
  els.archiveProjectCompanySelect.innerHTML = `<option value="">既存会社を選択</option>${customers.map((customer) => `<option value="${escapeHtml(customer.id)}">${escapeHtml(customer.companyName || "会社名未入力")}</option>`).join("")}`;
  updateArchiveProjectNamePreview();
}

function selectedArchiveProjectCompany() {
  const typedName = els.archiveProjectCompanyNameInput?.value.trim() || "";
  if (typedName) {
    return normalizeCustomer({
      companyName: typedName,
      companyAddress: els.archiveProjectCompanyAddressInput?.value.trim() || "",
      contactName: els.archiveProjectCompanyContactInput?.value.trim() || "",
    });
  }
  const selectedId = els.archiveProjectCompanySelect?.value || "";
  return loadCustomers().find((customer) => customer.id === selectedId) || null;
}

function updateArchiveProjectNamePreview() {
  if (!els.archiveProjectNamePreview) return;
  const company = selectedArchiveProjectCompany();
  els.archiveProjectNamePreview.textContent = company?.companyName ? archiveProjectNameForCompany(company.companyName) : "-";
}

function openArchiveProjectDialog() {
  renderArchiveProjectCompanyOptions();
  document.querySelectorAll('input[name="archiveProjectDirection"]').forEach((input) => {
    input.checked = input.value === "outbound";
  });
  if (els.archiveProjectCompanyNameInput) els.archiveProjectCompanyNameInput.value = "";
  if (els.archiveProjectCompanyAddressInput) els.archiveProjectCompanyAddressInput.value = "";
  if (els.archiveProjectCompanyContactInput) els.archiveProjectCompanyContactInput.value = "";
  updateArchiveProjectNamePreview();
  els.archiveProjectDialog?.showModal();
}

function createArchiveProject() {
  const company = selectedArchiveProjectCompany();
  if (!company?.companyName) {
    window.alert("交易会社を選択、または新会社名を入力してください。");
    return;
  }
  const savedCompany = saveCustomerRecord(company, { silent: true });
  const projectDirection = normalizeProjectDirection(document.querySelector('input[name="archiveProjectDirection"]:checked')?.value);
  const projectId = crypto.randomUUID();
  const doc = defaultDocument(projectDirection === "inbound" ? "customerFiles" : "estimate", { projectDirection });
  doc.projectId = projectId;
  doc.projectName = archiveProjectNameForCompany(savedCompany.companyName);
  doc.projectDirection = projectDirection;
  doc.customerName = savedCompany.companyName;
  doc.customerAddress = savedCompany.companyAddress;
  doc.customerContact = customerDisplayContact(savedCompany) === "-" ? "" : customerDisplayContact(savedCompany);
  doc.issuerName = NIIX_COMPANY_NAME;
  setFormData(doc);
  els.archiveProjectDialog?.close();
  els.archiveDialog?.close();
  setMobileView("form");
}

function deleteArchiveProject(projectId) {
  const project = archiveProjectById(projectId);
  if (!project) return;
  const label = `项目 ${projectDisplayName(project)}`;
  if (!confirmRepeatedDelete(label)) return;
  const ids = new Set(project.docs.map((doc) => doc.id));
  storeDocuments(loadDocuments().filter((doc) => !ids.has(doc.id)));
  logOperation({ category: "変更", priority: "重要", assignee: loadSettings().accountName || "自分", memo: `${label} を削除` });
  state.selectedArchiveProjectId = "";
  if (ids.has(state.currentId)) setFormData(defaultDocument("invoice"));
  syncProjectSurfaces();
}

function deleteArchiveForm(docId) {
  const doc = loadDocuments().find((item) => item.id === docId);
  if (!doc) return;
  const label = `${DOC_TYPES[doc.docType]?.title || "帳票"} ${doc.docNumber || ""}`.trim();
  if (!confirmRepeatedDelete(label)) return;
  storeDocuments(loadDocuments().filter((item) => item.id !== docId));
  logOperation({ category: "変更", priority: "重要", assignee: loadSettings().accountName || "自分", memo: `${label} を削除`, docNumber: doc.docNumber });
  if (state.currentId === docId) setFormData(defaultDocument("invoice"));
  syncProjectSurfaces();
}

function flowStepEntries(doc = getFormData()) {
  if (isInboundProject(doc)) {
    const stepIssues = documentIssueMessages(doc);
    return [{
      step: { type: "customerFiles", label: "顧客書類", note: "受領書類を一括保管" },
      stepDoc: doc,
      isCurrent: true,
      status: "現在",
      badgeClass: stepIssues.length ? "has-issues" : "is-ok",
      badgeText: stepIssues.length ? `${stepIssues.length}件` : "OK",
      stepText: doc.docNumber || "未保存",
    }];
  }
  const related = relatedFlowDocuments(doc);
  return FLOW_STEPS.map((step) => {
    const stepDoc =
      step.type === doc.docType || step.alternates?.includes(doc.docType)
        ? doc
        : related.get(step.type) || step.alternates?.map((type) => related.get(type)).find(Boolean);
    const stepIssues = stepDoc ? documentIssueMessages(stepDoc) : [];
    const isCurrent = stepDoc?.id === doc.id || step.type === doc.docType || step.alternates?.includes(doc.docType);
    const status = isCurrent ? "現在" : stepDoc ? "作成済" : "未作成";
    const badgeClass = stepIssues.length ? "has-issues" : stepDoc ? "is-ok" : "can-create";
    const badgeText = stepDoc ? (stepIssues.length ? `${stepIssues.length}件` : "OK") : "作成";
    const refs = stepDoc ? referenceEntries(stepDoc) : [];
    const stepText = stepDoc?.docNumber
      ? `${stepDoc.docNumber}${refs.length ? ` / 関連: ${formatReferenceEntries(refs)}` : ""}`
      : "未作成";
    return { step, stepDoc, isCurrent, status, badgeClass, badgeText, stepText };
  });
}

function renderFlowSidebar() {
  const entries = flowStepEntries();
  if (els.flowSteps) {
    els.flowSteps.innerHTML = entries.map(({ step, stepDoc, isCurrent, status, badgeClass, badgeText, stepText }) => {
    return `
      <button class="flow-step ${isCurrent ? "active" : ""} ${stepDoc ? "is-done" : "is-pending"}" type="button" data-flow-type="${escapeHtml(stepDoc?.docType || step.type)}">
        <span>${escapeHtml(step.label)}<b>${escapeHtml(status)}</b></span>
        <small>${escapeHtml(stepText)}</small>
        <em class="${badgeClass}">${badgeText}</em>
      </button>
    `;
    }).join("");
  }
  if (els.topFlowTabs) {
    els.topFlowTabs.innerHTML = entries.map(({ step, stepDoc, isCurrent, badgeClass, badgeText }) => `
      <button class="top-flow-tab ${isCurrent ? "active" : ""} ${stepDoc ? "is-done" : "is-pending"}" type="button" data-flow-type="${escapeHtml(stepDoc?.docType || step.type)}">
        <span>${escapeHtml(step.label)}</span>
        <em class="${badgeClass}">${badgeText}</em>
      </button>
    `).join("");
  }
}

function renderLines() {
  els.lineItems.innerHTML = "";
  const hasPrices = showsPrices();
  els.lineItems.closest(".line-table")?.classList.toggle("has-prices", hasPrices);
  if (els.lineItemsHead) {
    els.lineItemsHead.innerHTML = hasPrices
      ? `<tr><th>品目</th><th>型番</th><th>仕様</th><th>数量</th><th>単価</th><th></th></tr>`
      : `<tr><th>品目</th><th>型番</th><th>仕様</th><th>数量</th><th></th></tr>`;
  }
  state.lines.forEach((line) => {
    const tr = document.createElement("tr");
    tr.innerHTML = hasPrices
      ? `
      <td><input class="item-name" data-field="name" data-id="${line.id}" type="text" value="${escapeHtml(line.name)}" placeholder="品目" list="itemSmartOptions" /></td>
      <td><input class="item-model" data-field="model" data-id="${line.id}" type="text" value="${escapeHtml(line.model || "")}" placeholder="型番" list="itemSmartOptions" /></td>
      <td><input class="item-spec" data-field="specification" data-id="${line.id}" type="text" value="${escapeHtml(line.specification || "")}" placeholder="仕様" list="itemSmartOptions" /></td>
      <td><input data-field="quantity" data-id="${line.id}" type="number" min="0" step="0.01" value="${line.quantity}" placeholder="数量" /></td>
      <td><input data-field="unitPrice" data-id="${line.id}" type="number" min="0" step="1" value="${line.unitPrice}" placeholder="単価" /></td>
      <td><button class="remove-line" data-remove="${line.id}" type="button" aria-label="行を削除">x</button></td>
    `
      : `
      <td><input class="item-name" data-field="name" data-id="${line.id}" type="text" value="${escapeHtml(line.name)}" placeholder="品目" list="itemSmartOptions" /></td>
      <td><input class="item-model" data-field="model" data-id="${line.id}" type="text" value="${escapeHtml(line.model || "")}" placeholder="型番" list="itemSmartOptions" /></td>
      <td><input class="item-spec" data-field="specification" data-id="${line.id}" type="text" value="${escapeHtml(line.specification || "")}" placeholder="仕様" list="itemSmartOptions" /></td>
      <td><input data-field="quantity" data-id="${line.id}" type="number" min="0" step="0.01" value="${line.quantity}" placeholder="数量" /></td>
      <td><button class="remove-line" data-remove="${line.id}" type="button" aria-label="行を削除">x</button></td>
    `;
    els.lineItems.appendChild(tr);
  });
}

function renderNotices() {
  if (!els.noticeList) return;
  els.noticeList.innerHTML = "";
  if (!state.notices.length) {
    els.noticeList.innerHTML = `<div class="empty-master">通知はまだありません。価格調整、遅延、営業時間、注文取消などの連絡を追加できます。</div>`;
    return;
  }

  state.notices.forEach((notice) => {
    const type = NOTICE_TEMPLATES[notice.type]?.label || "通知";
    const item = document.createElement("div");
    item.className = "notice-item";
    item.innerHTML = `
      <div>
        <strong>${escapeHtml(notice.title || type)}</strong>
        <span>${escapeHtml(type)} / ${escapeHtml(formatDate(notice.createdAt?.slice(0, 10)) || "")}</span>
        <p>${escapeHtml(notice.body || "-")}</p>
      </div>
      <button class="remove-line" data-remove-notice="${escapeHtml(notice.id)}" type="button" aria-label="通知を削除">x</button>
    `;
    els.noticeList.appendChild(item);
  });
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function fileDownloadMarkup(file, className = "attached-file-link") {
  const href = file.serverUrl || file.dataUrl;
  if (!href) return `<span>${escapeHtml(file.name)}</span>`;
  return `<a class="${className}" href="${escapeHtml(href)}" target="_blank" rel="noopener" download="${escapeHtml(file.name)}">${escapeHtml(file.name)}</a>`;
}

function isImageAttachment(file = {}) {
  return String(file.type || "").startsWith("image/") || /^data:image\//.test(String(file.dataUrl || ""));
}

function attachmentActionsMarkup(file = {}) {
  const href = file.serverUrl || file.dataUrl;
  if (!href) return "";
  return `
    <div class="attached-file-actions">
      <a class="secondary-button attached-file-action" href="${escapeHtml(href)}" target="_blank" rel="noopener">プレビュー</a>
      <a class="secondary-button attached-file-action" href="${escapeHtml(href)}" download="${escapeHtml(file.name)}">ダウンロード</a>
    </div>
  `;
}

function attachmentPreviewMarkup(file = {}, options = {}) {
  const meta = `${file.type || "file"} / ${formatFileSize(file.size)} / ${formatDate(file.uploadedAt?.slice(0, 10)) || ""}`;
  const previewUrl = file.serverUrl || file.dataUrl;
  const status = file.serverUrl ? "サーバー保存済み" : file.dataUrl ? "読込済み" : "未読込";
  const thumbnail = isImageAttachment(file) && previewUrl
    ? `<a class="attached-file-thumb" href="${escapeHtml(previewUrl)}" target="_blank" rel="noopener" download="${escapeHtml(file.name)}"><img src="${escapeHtml(previewUrl)}" alt="${escapeHtml(file.name)}" /></a>`
    : `<div class="attached-file-icon" aria-hidden="true">${escapeHtml(fileExtensionLabel(file.name, file.type))}</div>`;
  return `
    ${thumbnail}
    <div class="attached-file-detail">
      ${fileDownloadMarkup(file)}
      <small>${escapeHtml(meta)}</small>
      <span class="attached-file-read-state">${escapeHtml(status)}</span>
      ${options.actions ? attachmentActionsMarkup(file) : ""}
    </div>
  `;
}

function fileExtensionLabel(name = "", type = "") {
  const ext = String(name || "").split(".").pop();
  if (ext && ext !== name) return ext.slice(0, 4).toUpperCase();
  if (String(type).includes("pdf")) return "PDF";
  if (String(type).startsWith("image/")) return "IMG";
  return "FILE";
}

function customerFileGroupLabel(category = "general") {
  return CUSTOMER_FILE_GROUPS.find((group) => group.key === category)?.label || "その他";
}

function renderCustomerFileGroups(files = []) {
  return CUSTOMER_FILE_GROUPS.map((group) => {
    const groupFiles = files.filter((file) => file.category === group.key);
    return `
      <section class="customer-file-group" data-customer-file-drop-zone="${escapeHtml(group.key)}">
        <div class="customer-file-group-head">
          <div>
            <strong>${escapeHtml(group.label)}</strong>
            <span>${escapeHtml(group.hint)}</span>
          </div>
          <em>${groupFiles.length ? `${groupFiles.length}件` : "未添付"}</em>
        </div>
        <div class="customer-file-actions">
          <label class="customer-file-upload-button">
            <span>サーバーへアップロード</span>
            <input type="file" multiple data-customer-file-category="${escapeHtml(group.key)}" accept=".pdf,.png,.jpg,.jpeg,.webp,.doc,.docx,.xls,.xlsx,.csv,.txt,.eml,.msg,image/*,application/pdf" />
          </label>
          <div class="customer-file-path-import">
            <input type="text" data-customer-file-path="${escapeHtml(group.key)}" placeholder="/Users/name/Documents/file.pdf" />
            <button class="secondary-button" type="button" data-import-customer-file-path="${escapeHtml(group.key)}">読込</button>
          </div>
        </div>
        <div class="attached-file-list">
          ${groupFiles.length
            ? groupFiles.map((file) => `
              <div class="attached-file-row">
                ${attachmentPreviewMarkup(file)}
                <button class="secondary-button danger-button" type="button" data-remove-order-file="${escapeHtml(file.id)}">削除</button>
              </div>
            `).join("")
            : `<p class="empty-master">${escapeHtml(group.label)}はまだ添付されていません。</p>`}
        </div>
      </section>
    `;
  }).join("");
}

function renderCustomerOrderFiles() {
  const doc = getFormData();
  const isRecord = isReceivedDocumentRecord(doc);
  if (els.customerOrderFileSection) els.customerOrderFileSection.hidden = !isRecord || isNativeApp();
  if (!isRecord || isNativeApp()) return;
  const title = doc.docType === "customerFiles" ? "顧客書類ファイル" : isInboundProject(doc) ? `受領${DOC_TYPES[doc.docType]?.title || "帳票"}ファイル` : "客先注文ファイル";
  const hint = isInboundProject(doc)
    ? doc.docType === "customerFiles"
      ? "取引先から受領した見積書、請求書、領収書、メール、確認資料を保存"
      : `取引先から受領した${DOC_TYPES[doc.docType]?.title || "帳票"}、メール、確認資料を保存`
    : "客先から受領した注文書・メール・確認資料を保存";
  if (els.customerOrderFileTitle) els.customerOrderFileTitle.textContent = title;
  if (els.customerOrderFileHint) els.customerOrderFileHint.textContent = hint;
  const files = (state.customerOrderFiles || []).map(normalizeCustomerOrderFile);
  if (els.customerOrderFileInput) {
    const defaultUploadField = els.customerOrderFileInput.closest(".file-upload-field");
    if (defaultUploadField) defaultUploadField.hidden = doc.docType === "customerFiles";
  }
  if (els.customerOrderFileStatus) {
    els.customerOrderFileStatus.textContent = files.length ? `${files.length}件添付` : "未添付";
  }
  if (els.customerOrderFileList) {
    els.customerOrderFileList.classList.toggle("customer-file-group-grid", doc.docType === "customerFiles");
    if (doc.docType === "customerFiles") {
      els.customerOrderFileList.innerHTML = renderCustomerFileGroups(files);
      return;
    }
    els.customerOrderFileList.innerHTML = files.length
      ? files.map((file) => `
        <div class="attached-file-row">
          ${attachmentPreviewMarkup(file)}
          <button class="secondary-button danger-button" type="button" data-remove-order-file="${escapeHtml(file.id)}">削除</button>
        </div>
      `).join("")
      : `<p class="empty-master">${escapeHtml(hint)}してください。</p>`;
  }
}

function renderOrderRecordPreview(doc = getFormData()) {
  if (!els.orderRecordPreview) return;
  const isRecord = isReceivedDocumentRecord(doc);
  els.orderRecordPreview.hidden = !isRecord;
  if (els.printArea) els.printArea.hidden = isRecord;
  if (els.previewPngFrame && isRecord) els.previewPngFrame.hidden = true;
  if (!isRecord) return;

  const refs = isCustomerFilesDocument(doc) ? [] : referenceEntries(doc);
  if (els.orderRecordTitle) els.orderRecordTitle.textContent = doc.docType === "customerFiles" ? "顧客書類記録" : isInboundProject(doc) ? `受領${DOC_TYPES[doc.docType]?.title || "帳票"}記録` : "注文記録";
  if (els.orderRecordNumber) els.orderRecordNumber.textContent = doc.docNumber || "-";
  if (els.orderRecordDate) els.orderRecordDate.textContent = formatDate(doc.transactionDate || doc.issueDate) || "-";
  if (els.orderRecordDueDate) els.orderRecordDueDate.textContent = formatDate(doc.dueDate) || "-";
  if (els.orderRecordCustomer) els.orderRecordCustomer.textContent = [doc.customerName, doc.customerContact, doc.customerEmail].filter(Boolean).join(" / ") || "-";
  if (els.orderRecordSource) els.orderRecordSource.textContent = refs.length ? formatReferenceEntries(refs) : "-";
  els.orderRecordSource?.closest("div")?.toggleAttribute("hidden", isCustomerFilesDocument(doc));
  if (els.orderRecordNotes) els.orderRecordNotes.textContent = [doc.notes, doc.documentSpecifics].filter(Boolean).join("\n\n") || "-";
  if (els.orderRecordFiles) {
    const files = doc.customerOrderFiles || [];
    els.orderRecordFiles.innerHTML = isCustomerFilesDocument(doc)
      ? renderPreviewCustomerFileGroups(files)
      : files.length
      ? files.map((file) => `
        <div class="order-record-file">
          ${attachmentPreviewMarkup(file, { actions: true })}
          <span>${escapeHtml(customerFileGroupLabel(file.category))} / ${escapeHtml(formatFileSize(file.size))} / ${escapeHtml(formatDate(file.uploadedAt?.slice(0, 10)) || "")}</span>
        </div>
      `).join("")
      : `<p class="empty-master">添付ファイルはまだありません。</p>`;
  }
}

function renderPreviewCustomerFileGroups(files = []) {
  return CUSTOMER_FILE_GROUPS.map((group) => {
    const groupFiles = files.filter((file) => file.category === group.key);
    return `
      <div class="preview-customer-file-group">
        <strong>${escapeHtml(group.label)}</strong>
        ${groupFiles.length
          ? groupFiles.map((file) => `
            <div class="order-record-file">
              ${attachmentPreviewMarkup(file, { actions: true })}
              <span>${escapeHtml(formatFileSize(file.size))} / ${escapeHtml(formatDate(file.uploadedAt?.slice(0, 10)) || "")}</span>
            </div>
          `).join("")
          : `<p class="empty-master">${escapeHtml(group.label)}はまだ添付されていません。</p>`}
      </div>
    `;
  }).join("");
}

function setFieldHidden(id, hidden) {
  const field = els[id];
  const label = field?.closest("label");
  if (label) label.hidden = hidden;
}

function syncCustomerFilesFormVisibility(isCustomerFiles = isCustomerFilesDocument()) {
  [
    "issueDate",
    "transactionDate",
    "dueDate",
    "honorific",
    "relatedNumberPicker",
    "taxRate",
  ].forEach((id) => setFieldHidden(id, isCustomerFiles));
  if (els.relatedNumberPickerWrap) els.relatedNumberPickerWrap.hidden = isCustomerFiles;
  [
    "issuerRegistration",
    "issuerAddress",
    "issuerPhone",
    "issuerEmail",
  ].forEach((id) => setFieldHidden(id, isCustomerFiles));
  if (els.loadIssuerBtn) els.loadIssuerBtn.hidden = isCustomerFiles;
  document.querySelector(".notice-editor")?.toggleAttribute("hidden", isCustomerFiles);
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.addEventListener("load", () => resolve(String(reader.result || "")));
    reader.addEventListener("error", () => reject(reader.error || new Error("ファイルを読み込めませんでした。")));
    reader.readAsDataURL(file);
  });
}

function confirmRepeatedDelete(label = "対象") {
  const target = String(label || "対象").trim();
  if (!window.confirm(`${target} を削除します。この操作は元に戻せません。続行しますか？`)) return false;
  return window.confirm(`最終確認: ${target} を本当に削除しますか？`);
}

function lineDetailParts(line) {
  return [line.model, ...String(line.specification || "").split("/")]
    .map((part) => part.trim())
    .filter(Boolean);
}

function toggleTotalRow(element, visible) {
  const row = element?.closest("div");
  if (row) row.hidden = !visible;
}

function formatTaxRate(rate) {
  return Number.isInteger(rate) ? String(rate) : String(Number(rate.toFixed(2))).replace(/\.?0+$/, "");
}

function hasQualifiedInvoiceRegistration(doc = getFormData()) {
  return /^T\d{13}$/.test(String(doc.issuerRegistration || "").trim());
}

function renderPreview() {
  const doc = getFormData();
  const config = DOC_TYPES[doc.docType] || DOC_TYPES.invoice;
  const definition = formDefinition(doc.docType);
  const sum = totals(doc);
  const hasPrices = showsPrices(doc.docType, doc.projectDirection);
  const isRecord = isReceivedDocumentRecord(doc);
  const isCustomerFiles = isCustomerFilesDocument(doc);

  applyTemplate();
  syncCustomerFilesFormVisibility(isCustomerFiles);
  if (els.printArea) els.printArea.hidden = isRecord;
  els.printArea?.classList.toggle("no-prices", !hasPrices);
  els.documentForm?.classList.toggle("no-prices", !hasPrices);
  if (els.taxRate) els.taxRate.closest("label").hidden = !hasPrices;
  if (els.templateSelect) els.templateSelect.closest(".toolbar")?.classList.toggle("hidden", isRecord);
  if (els.copyJsonBtn) els.copyJsonBtn.hidden = isRecord;
  if (els.downloadPdfBtn) els.downloadPdfBtn.hidden = isRecord;
  document.getElementById("printBtn")?.toggleAttribute("hidden", isRecord);
  document.querySelectorAll('[data-mobile-action="preview"], [data-mobile-action="pdf"], [data-mobile-action="download-pdf"]').forEach((button) => {
    button.hidden = isRecord;
  });
  renderFormDefinition(definition, config);
  els.pageTitle.textContent = doc.docType === "customerFiles" ? config.pageTitle : isInboundProject(doc) ? `受領${config.title}記録` : config.pageTitle;
  els.previewTitle.textContent = config.title;
  els.previewSubtitle.textContent = config.subtitle;
  if (els.previewLead) els.previewLead.textContent = definition.lead;
  els.totalLabel.textContent = definition.totalLabel || config.totalLabel;
  els.previewNumber.textContent = doc.docNumber;
  els.previewIssueDate.textContent = formatDate(doc.issueDate);
  if (els.previewTransactionDate) els.previewTransactionDate.textContent = formatDate(doc.transactionDate);
  els.previewDueDate.textContent = formatDate(doc.dueDate);
  if (els.previewSourceRow && els.previewSource) {
    syncRelatedNumberVisibility(doc);
  }
  els.previewCustomerName.textContent = `${doc.customerName || "取引先名"} ${doc.honorific || ""}`.trim();
  els.previewCustomerAddress.textContent = doc.customerAddress;
  els.previewCustomerContact.textContent = [doc.customerContact, doc.customerEmail].filter(Boolean).join(" / ");
  els.previewIssuerName.textContent = doc.issuerName || "自社名";
  els.previewIssuerAddress.textContent = doc.issuerAddress;
  els.previewIssuerRegistration.textContent = doc.issuerRegistration ? `登録番号: ${doc.issuerRegistration}` : "";
  els.previewIssuerContact.textContent = [doc.issuerContact, doc.issuerPhone, doc.issuerEmail].filter(Boolean).join(" / ");
  if (state.issuerLogo && els.previewLogo) {
    els.previewLogo.innerHTML = `<img alt="Logo" src="${state.issuerLogo}" />`;
    els.previewLogo.hidden = false;
  } else if (els.previewLogo) {
    els.previewLogo.innerHTML = "";
    els.previewLogo.hidden = true;
  }
  els.printArea?.classList.toggle("has-logo", Boolean(state.issuerLogo));
  if (els.invoiceBadge) els.invoiceBadge.hidden = !hasQualifiedInvoiceRegistration(doc);
  syncSealSurfaces();
  if (els.totalBanner) {
    els.totalBanner.hidden = !hasPrices || !["invoice", "receipt", "acceptance"].includes(doc.docType);
  }
  els.previewGrandTotal.textContent = hasPrices ? yen(sum.total) : "";
  if (els.previewBannerBank && els.previewBannerBankText) {
    els.previewBannerBank.hidden = !hasPrices || doc.docType !== "invoice";
    const bankText = doc.bankDetails || "-";
    const dueText = doc.dueDate ? `支払期限: ${formatDate(doc.dueDate)}` : "支払期限: -";
    els.previewBannerBankText.textContent = doc.docType === "invoice" ? `${bankText}\n${dueText}` : "";
  }
  els.previewSubtotal.textContent = hasPrices ? yen(sum.subtotal) : "";
  if (els.previewTaxable8) els.previewTaxable8.textContent = yen(sum.taxable8);
  if (els.previewTaxable10) els.previewTaxable10.textContent = yen(sum.taxable10);
  if (els.previewTaxable0) els.previewTaxable0.textContent = yen(sum.taxable0);
  els.previewTax8.textContent = yen(sum.tax8);
  els.previewTax10.textContent = yen(sum.tax10);
  const taxRateLabel = formatTaxRate(sum.taxRate);
  if (els.previewTaxableRateLabel) els.previewTaxableRateLabel.textContent = `${taxRateLabel}%対象`;
  if (els.previewTaxRateLabel) els.previewTaxRateLabel.textContent = `消費税 ${taxRateLabel}%`;
  toggleTotalRow(els.previewTaxable10, false);
  toggleTotalRow(els.previewTax10, false);
  toggleTotalRow(els.previewTaxable8, sum.taxRate > 0);
  toggleTotalRow(els.previewTax8, sum.taxRate > 0);
  toggleTotalRow(els.previewTaxable0, sum.taxRate <= 0);
  els.previewTotal.textContent = hasPrices ? yen(sum.total) : "";
  els.previewNotes.textContent = doc.notes || "-";
  els.previewBank.textContent = doc.bankDetails || "-";
  if (els.previewSpecificsTitle) els.previewSpecificsTitle.textContent = definition.specificsLabel || SPECIFIC_LABELS[doc.docType] || "帳票別メモ";
  if (els.previewSpecifics) els.previewSpecifics.textContent = doc.documentSpecifics || "-";
  if (els.previewNoticeSection && els.previewNotices) {
    els.previewNoticeSection.hidden = !doc.notices.length;
    els.previewNotices.innerHTML = doc.notices
      .map((notice) => {
        const type = NOTICE_TEMPLATES[notice.type]?.label || "通知";
        return `<div class="preview-notice"><strong>${escapeHtml(notice.title || type)}</strong><span>${escapeHtml(type)}</span><p>${escapeHtml(notice.body || "-")}</p></div>`;
      })
      .join("");
  }

  if (els.previewLineHead) {
    els.previewLineHead.innerHTML = hasPrices
      ? `<tr><th>品目</th><th>型番 / 仕様</th><th>数量</th><th>単価</th><th>金額</th></tr>`
      : `<tr><th>品目</th><th>型番 / 仕様</th><th>数量</th></tr>`;
  }
  els.previewLines.innerHTML = "";
  doc.lines.forEach((line) => {
    const amount = Number(line.quantity || 0) * Number(line.unitPrice || 0);
    const detailItems = lineDetailParts(line);
    const detailMarkup = detailItems.length
      ? `<span class="line-detail-stack">${escapeHtml(detailItems.join(" | "))}</span>`
      : "-";
    const tr = document.createElement("tr");
    tr.innerHTML = hasPrices
      ? `
      <td>${escapeHtml(line.name || "-")}</td>
      <td class="line-detail-cell">${detailMarkup}</td>
      <td>${Number(line.quantity || 0).toLocaleString("ja-JP")}</td>
      <td>${yen(line.unitPrice)}</td>
      <td>${yen(amount)}</td>
    `
      : `
      <td>${escapeHtml(line.name || "-")}</td>
      <td class="line-detail-cell">${detailMarkup}</td>
      <td>${Number(line.quantity || 0).toLocaleString("ja-JP")}</td>
    `;
    els.previewLines.appendChild(tr);
  });

  renderConversionPanel();
  renderCopyAsControl();
  renderTemplateControls();
  renderCustomerOrderFiles();
  renderOrderRecordPreview(doc);
  renderFieldIssues(doc);
  renderFlowSidebar();
  if (isRecord) {
    window.clearTimeout(state.previewSnapshotTimer);
    syncPreviewRasterMode(false);
  } else {
    schedulePreviewSnapshot();
  }
}

function shouldRasterizePreview() {
  return true;
}

function syncPreviewRasterMode(active) {
  document.body.classList.toggle("preview-raster-mode", active);
  if (els.previewPngFrame) {
    els.previewPngFrame.hidden = !active;
    els.previewPngFrame.classList.toggle("is-rendering", active && !els.previewPngImage?.src);
  }
}

function waitForImageLoad(url) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    const timeout = window.setTimeout(() => {
      image.onload = null;
      image.onerror = null;
      reject(new Error("Image preview load timed out."));
    }, 8000);
    image.onload = () => {
      window.clearTimeout(timeout);
      resolve();
    };
    image.onerror = () => {
      window.clearTimeout(timeout);
      reject(new Error("Image preview could not be loaded."));
    };
    image.src = url;
  });
}

function setPreviewPngStatus(message = "", isError = false) {
  if (!els.previewPngStatus) return;
  els.previewPngStatus.textContent = message;
  els.previewPngStatus.hidden = !message;
  els.previewPngStatus.classList.toggle("is-error", Boolean(isError));
}

function collectInlineCss() {
  return [...document.styleSheets]
    .map((sheet) => {
      try {
        return [...sheet.cssRules].map((rule) => rule.cssText).join("\n");
      } catch {
        return "";
      }
    })
    .filter(Boolean)
    .join("\n");
}

function blobToDataUrl(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

async function assetUrlToDataUrl(url) {
  const absoluteUrl = new URL(url, window.location.href).href;
  if (previewAssetDataUrlCache.has(absoluteUrl)) return previewAssetDataUrlCache.get(absoluteUrl);
  const response = await fetch(absoluteUrl);
  if (!response.ok) throw new Error(`Preview asset could not be loaded: ${absoluteUrl}`);
  const dataUrl = await blobToDataUrl(await response.blob());
  previewAssetDataUrlCache.set(absoluteUrl, dataUrl);
  return dataUrl;
}

async function inlineCssAssetUrls(css) {
  const matches = [...css.matchAll(/url\((['"]?)(?!data:|blob:|#)([^'")]+)\1\)/g)];
  let nextCss = css;
  for (const match of matches) {
    const original = match[0];
    const assetUrl = match[2].trim();
    try {
      const dataUrl = await assetUrlToDataUrl(assetUrl);
      nextCss = nextCss.replaceAll(original, `url("${dataUrl}")`);
    } catch (error) {
      console.warn("preview asset inline failed", error);
    }
  }
  return nextCss;
}

async function localPreviewSvgUrl() {
  const clone = els.printArea.cloneNode(true);
  clone.removeAttribute("id");
  const width = 1240;
  const height = Math.max(1754, Math.ceil((els.printArea.scrollHeight || els.printArea.offsetHeight || 1754) * 1.48));
  clone.style.width = `${width}px`;
  clone.style.maxWidth = `${width}px`;
  clone.style.minHeight = `${height}px`;
  clone.style.margin = "0";
  clone.style.boxShadow = "none";
  const css = (await inlineCssAssetUrls(collectInlineCss())).replaceAll("]]>", "]]]]><![CDATA[>");
  const overrideCss = `
          .document-preview {
            width: ${width}px !important;
            max-width: ${width}px !important;
            min-height: ${height}px !important;
            margin: 0 !important;
            box-shadow: none !important;
            transform: none !important;
          }
          .document-safe-area {
            max-width: none !important;
          }
  `;
  const markup = new XMLSerializer().serializeToString(clone);
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
      <foreignObject width="100%" height="100%">
        <div xmlns="http://www.w3.org/1999/xhtml" style="margin:0;background:#fff;">
          <style><![CDATA[${css}]]></style>
          <style><![CDATA[${overrideCss}]]></style>
          ${markup}
        </div>
      </foreignObject>
    </svg>
  `;
  return URL.createObjectURL(new Blob([svg], { type: "image/svg+xml;charset=utf-8" }));
}

function canvasToPngBlob(canvas) {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
      else reject(new Error("Canvas PNG export failed."));
    }, "image/png", 1);
  });
}

async function renderLocalPreviewPngBlob() {
  if (window.html2canvas) {
    const clone = els.printArea.cloneNode(true);
    clone.removeAttribute("id");
    const width = 1240;
    const height = Math.max(1754, Math.ceil((els.printArea.scrollHeight || els.printArea.offsetHeight || 1754) * 1.48));
    clone.style.position = "absolute";
    clone.style.top = "0";
    clone.style.left = "-10000px";
    clone.style.width = `${width}px`;
    clone.style.maxWidth = `${width}px`;
    clone.style.minHeight = `${height}px`;
    clone.style.margin = "0";
    clone.style.boxShadow = "none";
    clone.style.opacity = "1";
    clone.style.pointerEvents = "none";
    document.body.appendChild(clone);
    try {
      await document.fonts?.ready;
      const canvas = await window.html2canvas(clone, {
        backgroundColor: "#ffffff",
        height,
        logging: false,
        scale: 1,
        useCORS: true,
        width,
        windowHeight: height,
        windowWidth: width,
      });
      return await canvasToPngBlob(canvas);
    } finally {
      clone.remove();
    }
  }

  const svgUrl = await localPreviewSvgUrl();
  try {
    const image = new Image();
    const loaded = new Promise((resolve, reject) => {
      const timeout = window.setTimeout(() => {
        image.onload = null;
        image.onerror = null;
        reject(new Error("Local SVG preview load timed out."));
      }, 8000);
      image.onload = () => {
        window.clearTimeout(timeout);
        resolve();
      };
      image.onerror = () => {
        window.clearTimeout(timeout);
        reject(new Error("Local SVG preview could not be loaded."));
      };
    });
    image.src = svgUrl;
    await loaded;
    const canvas = document.createElement("canvas");
    canvas.width = image.naturalWidth || 1240;
    canvas.height = image.naturalHeight || 1754;
    const context = canvas.getContext("2d", { alpha: false });
    if (!context) throw new Error("Canvas is not available.");
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(image, 0, 0);
    return await canvasToPngBlob(canvas);
  } finally {
    URL.revokeObjectURL(svgUrl);
  }
}

async function renderPreviewPng() {
  if (!els.previewPngFrame || !els.previewPngImage || !els.printArea) return;
  const active = shouldRasterizePreview();
  if (!active) {
    syncPreviewRasterMode(false);
    if (state.previewSnapshotUrl) URL.revokeObjectURL(state.previewSnapshotUrl);
    state.previewSnapshotUrl = "";
    els.previewPngImage.removeAttribute("src");
    return;
  }
  const previewColumn = els.previewPngFrame.closest(".preview-column");
  if (previewColumn && !previewColumn.getClientRects().length) return;

  const token = ++state.previewSnapshotToken;
  syncPreviewRasterMode(true);
  els.previewPngFrame.classList.add("is-rendering");
  setPreviewPngStatus("本機PNG生成中...");
  try {
    const pngUrl = URL.createObjectURL(await renderLocalPreviewPngBlob());
    await waitForImageLoad(pngUrl);
    if (token !== state.previewSnapshotToken) {
      URL.revokeObjectURL(pngUrl);
      return;
    }
    if (state.previewSnapshotUrl) URL.revokeObjectURL(state.previewSnapshotUrl);
    state.previewSnapshotUrl = pngUrl;
    els.previewPngImage.src = pngUrl;
    setPreviewPngStatus("");
    syncPreviewRasterMode(true);
  } catch (error) {
    console.warn("local preview png render failed", error);
    setPreviewPngStatus("本機PNG預覽無法生成。請返回輸入頁再進入確認頁重試。", true);
    syncPreviewRasterMode(true);
  } finally {
    if (token === state.previewSnapshotToken) {
      els.previewPngFrame.classList.remove("is-rendering");
    }
  }
}

function schedulePreviewSnapshot() {
  window.clearTimeout(state.previewSnapshotTimer);
  state.previewSnapshotTimer = null;
  state.previewSnapshotToken += 1;
  if (state.previewSnapshotUrl) {
    URL.revokeObjectURL(state.previewSnapshotUrl);
    state.previewSnapshotUrl = "";
  }
  if (els.previewPngImage) els.previewPngImage.removeAttribute("src");
  const active = shouldRasterizePreview();
  syncPreviewRasterMode(active);
  setPreviewPngStatus(active ? "本機PNG生成中..." : "");
  if (active) {
    state.previewSnapshotTimer = window.setTimeout(() => {
      renderPreviewPng();
    }, 120);
  }
}

function syncRelatedNumberVisibility(doc = getFormData()) {
  if (!els.previewSourceRow || !els.previewSource) return;
  doc = applyRelatedNumberMode(doc);
  const refs = referenceEntries(doc);
  const text = refs.length ? formatReferenceEntries(refs) : "";
  const shouldShow = doc.docType !== "estimate" && Boolean(doc.showRelatedNumber) && Boolean(text);
  els.previewSource.textContent = text || "関連番号なし";
  els.previewSourceRow.hidden = !shouldShow;
}

function renderFormDefinition(definition, config) {
  const labelMap = {
    basicSectionTitle: "基本情報",
    docNumberLabel: `${config.title}番号`,
    issueDateLabel: "発行日",
    transactionDateLabel: definition.transactionLabel,
    dueDateLabel: definition.dueLabel,
    taxRateLabel: "税(%)",
    partySectionTitle: definition.partySection,
    partyNameLabel: definition.partyName,
    partyAddressLabel: `${definition.partySection}住所`,
    partyContactLabel: `${definition.partySection}担当者`,
    partyEmailLabel: `${definition.partySection}Email`,
    issuerSectionTitle: definition.issuerSection,
    notesLabel: "備考",
    bankDetailsLabel: definition.secondaryLabel,
    documentSpecificsLabel: definition.specificsLabel,
    previewNumberLabel: "番号",
    previewIssueDateLabel: "発行日",
    previewTransactionDateLabel: definition.transactionLabel,
    previewDueDateLabel: definition.dueLabel,
    previewSourceLabel: "関連番号",
    relatedNumberPickerLabel: "関連番号",
    relatedDocumentTypeLabel: "関連先",
    customRelatedNumberLabel: "関連番号",
    relatedNumberModeLabel: "関連番号",
    previewBankTitle: definition.secondaryLabel,
  };

  Object.entries(labelMap).forEach(([id, value]) => {
    if (els[id]) {
      els[id].textContent = value;
      els[id].dataset.defaultLabel = value;
    }
  });

  if (els.customerName) els.customerName.placeholder = definition.partyName;
  if (els.customerAddress) els.customerAddress.placeholder = `${definition.partySection}の住所`;
  if (els.customerContact) els.customerContact.placeholder = `${definition.partySection}の担当者`;
  if (els.customerEmail) els.customerEmail.placeholder = `${definition.partySection}のEmail`;
  if (els.notes) els.notes.placeholder = definition.notesPlaceholder;
  if (els.bankDetails) els.bankDetails.placeholder = definition.secondaryPlaceholder;
  if (els.documentSpecifics) els.documentSpecifics.placeholder = definition.specificsPlaceholder;
  renderRelatedDocumentTypeOptions();
  renderRelatedNumberPicker();
  syncRelatedNumberModeControl();
  updateSimplifiedPlaceholders();
}

function syncRelatedNumberModeControl() {
  if (!els.relatedNumberMode) return;
  els.relatedNumberMode.disabled = false;
  els.relatedNumberMode.title = state.docType === "estimate"
    ? "見積書の関連番号は手動入力のみです"
    : "入力すると対応する上流帳票番号を更新します";
}

function renderRelatedDocumentTypeOptions(doc = getFormData()) {
  if (!els.relatedDocumentType) return;
  const selected = relatedDocumentType(doc);
  const options = relatedMenuOptions(doc.docType);
  els.relatedDocumentType.innerHTML = options
    .map((option) => `<option value="${escapeHtml(option.type)}">${escapeHtml(option.label)}</option>`)
    .join("");
  if (selected && options.some((option) => option.type === selected)) {
    els.relatedDocumentType.value = selected;
  }
  state.relatedDocumentType = els.relatedDocumentType.value || selected || "";
}

function chainRank(type) {
  const canonical = canonicalChainType(type) || type;
  const index = CHAIN_ORDER.indexOf(canonical);
  return index >= 0 ? index : 99;
}

function selectableRelatedTypes(docType = state.docType) {
  if (docType === "estimate") return [];
  return CHAIN_ORDER.filter((type) => type !== canonicalChainType(docType));
}

function relatedPickerDocuments(doc = getFormData()) {
  const allowed = new Set(selectableRelatedTypes(doc.docType));
  const docs = currentProjectDocuments(doc)
    .filter((item) => item.id !== doc.id && item.docNumber && allowed.has(canonicalChainType(item.docType)))
    .sort((a, b) => {
      const rank = chainRank(a.docType) - chainRank(b.docType);
      if (rank) return rank;
      return String(b.updatedAt || "").localeCompare(String(a.updatedAt || ""));
    });
  const seen = new Set();
  return docs.filter((item) => {
    const key = `${canonicalChainType(item.docType)}:${item.docNumber}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function relatedPickerLabelForType(type) {
  return RELATED_MENU_LABELS[canonicalChainType(type) || type] || DOC_TYPES[type]?.title || "帳票";
}

function selectedRelatedPickerValue(doc = getFormData(), docs = relatedPickerDocuments(doc)) {
  if (doc.sourceDocumentId && docs.some((item) => item.id === doc.sourceDocumentId)) return `doc:${doc.sourceDocumentId}`;
  const number = String(doc.customRelatedNumber || doc.sourceDocumentNumber || inheritedRelatedNumberFor(doc) || "").trim();
  const byNumber = docs.find((item) => item.docNumber === number);
  if (byNumber) return `doc:${byNumber.id}`;
  const upstream = immediateUpstreamTypes(doc.docType);
  const byType = docs.find((item) => upstream.includes(item.docType));
  return byType ? `doc:${byType.id}` : "";
}

function renderRelatedNumberPicker(doc = getFormData()) {
  if (!els.relatedNumberPicker) return;
  const wrap = els.relatedNumberPickerWrap || els.relatedNumberPicker.closest("label");
  const isEstimate = doc.docType === "estimate";
  if (wrap) wrap.hidden = isEstimate;
  if (els.showRelatedNumber) els.showRelatedNumber.checked = !isEstimate;
  if (isEstimate) {
    els.relatedNumberPicker.innerHTML = "";
    if (els.customRelatedNumber) els.customRelatedNumber.value = "";
    return;
  }

  const docs = relatedPickerDocuments(doc);
  const existingTypes = new Set(docs.map((item) => canonicalChainType(item.docType)));
  const missingTypes = selectableRelatedTypes(doc.docType).filter((type) => !existingTypes.has(type));
  const selected = selectedRelatedPickerValue(doc, docs);
  els.relatedNumberPicker.innerHTML = [
    `<option value="">関連番号なし</option>`,
    ...docs.map((item) => `<option value="doc:${escapeHtml(item.id)}">${escapeHtml(relatedPickerLabelForType(item.docType))} ${escapeHtml(item.docNumber)}</option>`),
    ...missingTypes.map((type) => `<option value="missing:${escapeHtml(type)}">${escapeHtml(relatedPickerLabelForType(type))} 未作成</option>`),
  ].join("");
  els.relatedNumberPicker.value = selected;
  if (selected.startsWith("doc:")) {
    const selectedDoc = docs.find((item) => `doc:${item.id}` === selected);
    if (selectedDoc && els.customRelatedNumber) els.customRelatedNumber.value = selectedDoc.docNumber;
  } else if (els.customRelatedNumber) {
    els.customRelatedNumber.value = "";
  }
}

async function applyRelatedPickerSelection(value = els.relatedNumberPicker?.value || "") {
  const current = getFormData();
  if (!value) {
    state.sourceDocumentId = "";
    state.sourceDocumentNumber = "";
    state.sourceDocumentType = "";
    state.relatedDocumentNumbers = {};
    if (els.customRelatedNumber) els.customRelatedNumber.value = "";
    return true;
  }
  if (value.startsWith("doc:")) {
    const id = value.slice(4);
    const selected = loadDocuments().find((doc) => doc.id === id);
    if (!selected) return false;
    state.sourceDocumentId = selected.id;
    state.sourceDocumentNumber = selected.docNumber;
    state.sourceDocumentType = selected.docType;
    state.relatedFormIds = compactUnique([...(state.relatedFormIds || []), selected.id]).filter((item) => item !== state.currentId);
    state.relatedDocumentNumbers = assignChainNumber({}, selected.docType, selected.docNumber);
    state.relatedDocumentType = canonicalChainType(selected.docType) || selected.docType;
    if (els.customRelatedNumber) els.customRelatedNumber.value = selected.docNumber;
    if (els.showRelatedNumber) els.showRelatedNumber.checked = true;
    return true;
  }
  if (value.startsWith("missing:")) {
    const type = value.slice(8);
    const label = relatedPickerLabelForType(type);
    const shouldCreate = window.confirm(`${label}はまだ作成されていません。新しく作成しますか？`);
    if (shouldCreate) {
      await copyCurrentDocumentAs(type);
    } else {
      renderRelatedNumberPicker(current);
    }
    return false;
  }
  return false;
}

function renderConversionPanel() {
  if (!els.conversionTarget || !els.convertDocumentBtn || !els.conversionStatus) return;

  const targets = COPY_TARGETS.filter((target) => target !== state.docType);
  const selectedTarget = els.conversionTarget.value;
  els.conversionTarget.innerHTML = "";

  if (!targets.length) {
    els.conversionStatus.textContent = `${DOC_TYPES[state.docType]?.title || "この帳票"}から作成できる変換先はありません`;
    els.conversionTarget.disabled = true;
    els.convertDocumentBtn.disabled = true;
    return;
  }

  targets.forEach((target) => {
    const option = document.createElement("option");
    option.value = target;
    option.textContent = DOC_TYPES[target].title;
    els.conversionTarget.appendChild(option);
  });
  els.conversionTarget.disabled = false;
  els.convertDocumentBtn.disabled = false;
  if (targets.includes(selectedTarget)) els.conversionTarget.value = selectedTarget;
  els.conversionStatus.textContent = `${DOC_TYPES[state.docType].title}から全帳票へ変換できます`;
}

function renderCopyAsControl() {
  if (!els.nextStepBtn) return;
  els.nextStepBtn.classList.add("hidden");
  els.nextStepBtn.disabled = true;
  els.nextStepBtn.textContent = "関連帳票";
}

function currentProjectDocuments(currentDoc = getFormData()) {
  const docs = loadDocuments();
  const related = relatedFlowDocuments(currentDoc);
  const ids = new Set([currentDoc.id, ...[...related.values()].map((doc) => doc.id)].filter(Boolean));
  const projectIds = new Set([currentDoc.projectId, ...[...related.values()].map((doc) => doc.projectId)].filter(Boolean));
  const result = new Map();
  docs
    .filter((doc) => ids.has(doc.id) || (doc.projectId && projectIds.has(doc.projectId)))
    .forEach((doc) => result.set(doc.id, doc));
  result.set(currentDoc.id, currentDoc);
  return [...result.values()];
}

function detailSourceDocuments(currentDoc = getFormData()) {
  const docs = currentProjectDocuments(currentDoc).filter((doc) => doc.id !== currentDoc.id && doc.lines?.some((line) => String(line.name || "").trim()));
  const sourceTypes = currentDoc.docType === "estimate"
    ? ["order", "purchaseOrder", "delivery", "invoice", "receipt", "acceptance"]
    : ["estimate"];
  const sourceRank = new Map(sourceTypes.map((type, index) => [type, index]));
  return docs
    .filter((doc) => sourceRank.has(doc.docType))
    .sort((a, b) => {
      const typeOrder = sourceRank.get(a.docType) - sourceRank.get(b.docType);
      if (typeOrder) return typeOrder;
      return String(b.updatedAt || "").localeCompare(String(a.updatedAt || ""));
    });
}

function cloneLineForCurrentDocument(line = {}) {
  return {
    id: crypto.randomUUID(),
    sourceLineId: line.id || line.sourceLineId || "",
    name: line.name || "",
    model: line.model || "",
    specification: line.specification || "",
    quantity: Number(line.quantity || 0) || 1,
    unitPrice: Number(line.unitPrice || 0),
  };
}

function appendProjectLines(lines = []) {
  const cloned = lines.map(cloneLineForCurrentDocument).filter((line) => String(line.name || "").trim());
  if (!cloned.length) return;
  const hasOnlyBlankLine = state.lines.length === 1 && !String(state.lines[0].name || "").trim();
  state.lines = hasOnlyBlankLine ? cloned : [...state.lines, ...cloned];
  renderLines();
  renderPreview();
  setDirty(true);
}

function uniqueProjectSourceLines(sources = []) {
  const seen = new Set();
  const lines = [];
  sources.forEach((source) => {
    (source.lines || []).forEach((line) => {
      if (!String(line.name || "").trim()) return;
      const key = [line.sourceLineId || line.id || "", line.name || "", line.model || "", line.specification || "", Number(line.quantity || 0), Number(line.unitPrice || 0)].join("|");
      if (seen.has(key)) return;
      seen.add(key);
      lines.push(line);
    });
  });
  return lines;
}

function projectLineSourceEmptyText(doc = getFormData()) {
  if (doc.docType === "estimate") return "同一项目の注文・発注・納品・請求・領収明細はまだありません。";
  return "同一项目の見積明細はまだありません。";
}

function ensureProjectLinesDialog() {
  let dialog = document.getElementById("projectLinesDialog");
  if (dialog) return dialog;
  dialog = document.createElement("dialog");
  dialog.id = "projectLinesDialog";
  dialog.className = "project-lines-dialog";
  dialog.innerHTML = `
    <form method="dialog">
      <header>
        <div>
          <p class="eyebrow">Project line items</p>
          <h2>案件明細読込</h2>
        </div>
        <button class="icon-button" value="cancel" aria-label="閉じる">x</button>
      </header>
      <div id="projectLineSourceList" class="project-line-source-list"></div>
    </form>
  `;
  document.body.appendChild(dialog);
  return dialog;
}

function renderProjectLineSources() {
  const dialog = ensureProjectLinesDialog();
  const list = dialog.querySelector("#projectLineSourceList");
  const currentDoc = getFormData();
  const sources = detailSourceDocuments(currentDoc);
  if (!sources.length) {
    list.innerHTML = `<p class="empty-master">${escapeHtml(projectLineSourceEmptyText(currentDoc))}</p>`;
    return;
  }
  const allLines = uniqueProjectSourceLines(sources);
  list.innerHTML = `
    <div class="project-line-bulk-actions">
      <span>${sources.length}帳票 / ${allLines.length}明細</span>
      <button class="primary-button" type="button" data-load-all-project-lines>全明細読込</button>
    </div>
    ${sources.map((doc) => {
    const lines = (doc.lines || []).filter((line) => String(line.name || "").trim());
    return `
      <section class="project-line-source">
        <div class="project-line-source-head">
          <div>
            <strong>${escapeHtml(DOC_TYPES[doc.docType]?.title || "帳票")} ${escapeHtml(doc.docNumber || "")}</strong>
            <span>${escapeHtml(formatDate(doc.transactionDate || doc.issueDate || doc.updatedAt?.slice(0, 10)))} / ${lines.length}件</span>
          </div>
          <button class="secondary-button" type="button" data-load-source-lines="${escapeHtml(doc.id)}">全部読込</button>
        </div>
        <div class="project-line-source-lines">
          ${lines.map((line) => `
            <button class="master-list-item" type="button" data-load-source-line="${escapeHtml(doc.id)}" data-line-id="${escapeHtml(line.id)}">
              <strong>${escapeHtml(line.name || "品目未入力")}</strong>
              <span>${escapeHtml([line.model, line.specification].filter(Boolean).join(" / ") || "詳細未入力")}</span>
              <small>${Number(line.quantity || 0).toLocaleString("ja-JP")} x ${yen(line.unitPrice)}</small>
            </button>
          `).join("")}
        </div>
      </section>
    `;
  }).join("")}
  `;
}

function openProjectLinesDialog() {
  const dialog = ensureProjectLinesDialog();
  renderProjectLineSources();
  dialog.showModal();
}

function applyTemplate() {
  if (!els.printArea) return;
  const template = selectedTemplate();
  els.printArea.dataset.template = template.style;
  els.printArea.style.setProperty("--template-accent", template.accent || "#2f3744");
  if (els.previewLogo) els.previewLogo.style.background = "transparent";
}

function renderTemplateControls() {
  if (!els.templateSelect) return;
  const selected = els.templateSelect.value;
  const templates = loadTemplates();
  els.templateSelect.innerHTML = "";
  templates.forEach((template) => {
    const option = document.createElement("option");
    option.value = template.id;
    option.textContent = template.builtin ? template.name : `追加: ${template.name}`;
    els.templateSelect.appendChild(option);
  });
  els.templateSelect.value = templates.some((template) => template.id === state.templateId) ? state.templateId : selected || "monochrome";
  if (els.templatePalette) {
    els.templatePalette.innerHTML = "";
    templates.forEach((template) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "template-dot";
      button.dataset.templateId = template.id;
      button.style.setProperty("--dot-color", template.accent || "#2f3744");
      button.title = template.name;
      button.setAttribute("aria-label", template.name);
      button.setAttribute("aria-pressed", String(template.id === els.templateSelect.value));
      els.templatePalette.appendChild(button);
    });
  }
}

function convertedNotes(source, targetType) {
  const sourceLabel = DOC_TYPES[source.docType]?.title || "帳票";
  const sourceInfo = `${sourceLabel} ${source.docNumber}`;
  if (source.docType === "estimate" && targetType === "order") return `${sourceInfo}の内容に基づき客先注文記録を作成しました。受領した注文書・メール・確認資料を添付してください。`;
  if (source.docType === "estimate" && targetType === "purchaseOrder") return `${sourceInfo}の内容に基づき発注書を作成しました。支払・発注条件と納入場所を確認してください。`;
  if (source.docType === "order" && targetType === "delivery") return `${sourceInfo}の注文内容に基づき納品書を作成しました。物流情報を追記してください。`;
  if (source.docType === "purchaseOrder" && targetType === "delivery") return `${sourceInfo}の発注内容に基づき納品書を作成しました。物流情報を追記してください。`;
  if (source.docType === "delivery" && targetType === "invoice") return `${sourceInfo}の納品内容に基づき請求書を作成しました。請求条件を確認してください。`;
  if (targetType === "receipt") return `${sourceInfo}に対する領収として発行します。`;
  if (targetType === "invoice") return `${sourceInfo}から請求書へ変換しました。`;
  if (targetType === "order") return `${sourceInfo}に基づき客先注文記録を作成します。`;
  if (targetType === "purchaseOrder") return `${sourceInfo}に基づき発注書を作成します。`;
  return `${sourceInfo}から変換しました。`;
}

function buildConvertedDocument(source, targetType) {
  const relatedDocumentNumbers = inheritedRelatedNumbers(source, targetType);
  const inheritedTargetNumber = chainNumberForType(collectDocumentNumbers(source), targetType);
  const newId = crypto.randomUUID();
  return {
    ...source,
    id: newId,
    formObjectId: newId,
    objectType: "form",
    schemaVersion: FORM_OBJECT_SCHEMA_VERSION,
    projectId: source.projectId || "",
    projectName: source.projectName || "",
    projectDirection: normalizeProjectDirection(source.projectDirection),
    docType: targetType,
    docNumber: inheritedTargetNumber || nextDocNumber(targetType),
    issueDate: today(),
    transactionDate: source.transactionDate || source.issueDate || today(),
    dueDate: targetType === "receipt" ? today() : addDays(30),
    notes: convertedNotes(source, targetType),
    documentSpecifics: defaultSpecifics(source, targetType),
    sourceDocumentId: source.id,
    sourceDocumentNumber: source.docNumber,
    sourceDocumentType: source.docType,
    relatedFormIds: compactUnique([source.id, source.sourceDocumentId, ...(source.relatedFormIds || []), ...(source.convertedDocumentIds || [])]),
    relatedDocumentNumbers,
    relatedDocumentType: relatedDocumentType({ docType: targetType, sourceDocumentType: source.docType, sourceDocumentNumber: source.docNumber, relatedDocumentNumbers }),
    customRelatedNumber: inheritedRelatedNumberFor({ ...source, docType: targetType, sourceDocumentNumber: source.docNumber, sourceDocumentType: source.docType, relatedDocumentNumbers }),
    relatedNumberMode: "auto",
    convertedDocumentIds: [],
    customerOrderFiles: normalizeProjectDirection(source.projectDirection) === "inbound" || targetType === "order" ? [] : [],
    lines: source.lines.map((line) => ({
      ...line,
      id: crypto.randomUUID(),
      sourceLineId: line.id,
    })),
    updatedAt: new Date().toISOString(),
  };
}

function defaultSpecifics(source, targetType) {
  const productSummary = source.lines
    .map((line) => [line.name, line.model, line.specification, `${Number(line.quantity || 0).toLocaleString("ja-JP")}台`].filter(Boolean).join(" / "))
    .join("\n");
  const definition = formDefinition(targetType);
  if (targetType === "estimate") return source.documentSpecifics || definition.defaultSpecifics;
  if (targetType === "order") return `注文内容:\n${productSummary}`;
  if (targetType === "purchaseOrder") return `発注条件、納入場所、検収条件を確認してください。\n発注予定品:\n${productSummary}`;
  if (targetType === "delivery") return `物流情報を入力してください。\n納品予定品:\n${productSummary}`;
  if (targetType === "invoice") return source.bankDetails ? "振込先と支払期限を確認してください。" : definition.defaultSpecifics;
  if (targetType === "receipt") return definition.defaultSpecifics;
  return source.documentSpecifics || "";
}

function upsertDocument(docs, doc) {
  const normalized = normalizeFormObject(doc);
  const index = docs.findIndex((item) => item.id === normalized.id);
  if (index >= 0) docs[index] = normalized;
  else docs.push(normalized);
}

function documentLinksTo(doc = {}, target = {}, oldNumber = "") {
  if (!doc?.id || !target?.id || doc.id === target.id) return false;
  const targetNumbers = [target.docNumber, oldNumber].filter(Boolean).map(String);
  const docNumbers = [doc.sourceDocumentNumber, doc.customRelatedNumber, ...Object.values(doc.relatedDocumentNumbers || {})].filter(Boolean).map(String);
  return doc.sourceDocumentId === target.id ||
    (doc.relatedFormIds || []).includes(target.id) ||
    (target.relatedFormIds || []).includes(doc.id) ||
    docNumbers.some((number) => targetNumbers.includes(number)) ||
    (doc.projectId && target.projectId && doc.projectId === target.projectId && priorChainTypes(doc.docType).includes(canonicalChainType(target.docType)));
}

function updateDocReferenceTo(doc = {}, target = {}, oldNumber = "") {
  if (relatedNumberMode(doc) === "blank") return doc;
  if (!documentLinksTo(doc, target, oldNumber)) return doc;
  const targetIsImmediateUpstream = immediateUpstreamTypes(doc.docType).includes(target.docType);
  const numbers = targetIsImmediateUpstream ? {} : { ...(doc.relatedDocumentNumbers || {}) };
  const targetType = canonicalChainType(target.docType) || target.docType;
  if (targetIsImmediateUpstream && target.docNumber) numbers[targetType] = target.docNumber;
  let next = {
    ...doc,
    relatedFormIds: compactUnique([...(doc.relatedFormIds || []), target.id]).filter((id) => id !== doc.id),
    relatedDocumentNumbers: numbers,
  };
  if (next.sourceDocumentId === target.id) {
    next.sourceDocumentNumber = target.docNumber || "";
    next.sourceDocumentType = target.docType;
  }
  if (relatedNumberMode(next) === "auto") next.customRelatedNumber = inheritedRelatedNumberFor(next);
  return { ...next, updatedAt: new Date().toISOString() };
}

function propagateDocumentNumber(docs, target, oldNumber = "") {
  let changed = false;
  const nextDocs = docs.map((doc) => {
    const next = updateDocReferenceTo(doc, target, oldNumber);
    if (JSON.stringify(next) !== JSON.stringify(doc)) changed = true;
    return next;
  });
  return changed ? nextDocs : docs;
}

function findImmediateUpstream(docs, doc) {
  const upstreamTypes = immediateUpstreamTypes(doc.docType);
  if (!upstreamTypes.length) return null;
  if (doc.sourceDocumentId) {
    const byId = docs.find((item) => item.id === doc.sourceDocumentId && upstreamTypes.includes(item.docType));
    if (byId) return byId;
  }
  const numbers = collectDocumentNumbers(doc);
  const upstreamNumber = upstreamTypes.map((type) => numbers[type]).find(Boolean) || doc.customRelatedNumber || "";
  return docs.find((item) => upstreamTypes.includes(item.docType) && item.docNumber === upstreamNumber) || null;
}

function applyReverseRelatedNumberOverwrite(docs, doc) {
  if (relatedNumberMode(doc) !== "overwrite" || !doc.customRelatedNumber) return { docs, doc, upstream: null, oldNumber: "" };
  const upstream = findImmediateUpstream(docs, doc);
  if (!upstream) return { docs, doc, upstream: null, oldNumber: "" };
  const oldNumber = upstream.docNumber || "";
  const updatedUpstream = normalizeFormObject({ ...upstream, docNumber: doc.customRelatedNumber, updatedAt: new Date().toISOString() });
  let nextDoc = {
    ...doc,
    sourceDocumentId: doc.sourceDocumentId || updatedUpstream.id,
    sourceDocumentNumber: updatedUpstream.docNumber,
    sourceDocumentType: updatedUpstream.docType,
    relatedFormIds: compactUnique([...(doc.relatedFormIds || []), updatedUpstream.id]).filter((id) => id !== doc.id),
    relatedDocumentNumbers: assignChainNumber(doc.relatedDocumentNumbers || {}, updatedUpstream.docType, updatedUpstream.docNumber),
  };
  nextDoc = normalizeFormObject(nextDoc);
  const nextDocs = docs.map((item) => item.id === updatedUpstream.id ? updatedUpstream : item);
  return { docs: nextDocs, doc: nextDoc, upstream: updatedUpstream, oldNumber };
}

async function convertCurrentDocument() {
  const targetType = els.conversionTarget?.value;
  if (!targetType || targetType === state.docType || !DOC_TYPES[targetType]) return;
  if (!(await confirmLeaveCurrentDocument())) return;

  const source = getFormData();
  const converted = buildConvertedDocument(source, targetType);
  const linkedSource = {
    ...source,
    relatedFormIds: compactUnique([...(source.relatedFormIds || []), converted.id]),
    convertedDocumentIds: [...new Set([...(source.convertedDocumentIds || []), converted.id])],
    updatedAt: new Date().toISOString(),
  };
  const docs = loadDocuments();
  upsertDocument(docs, linkedSource);
  upsertDocument(docs, converted);
  storeDocuments(docs);
  logOperation({ category: "変更", priority: "通常", assignee: loadSettings().accountName || "自分", memo: `${source.docNumber} から ${converted.docNumber} を変換作成`, docNumber: converted.docNumber });
  setFormData(converted);
}

async function copyCurrentDocumentAs(targetType) {
  if (!targetType || targetType === state.docType || !DOC_TYPES[targetType]) return;
  if (!(await confirmLeaveCurrentDocument())) return;

  const source = getFormData();
  const converted = buildConvertedDocument(source, targetType);
  const linkedSource = {
    ...source,
    relatedFormIds: compactUnique([...(source.relatedFormIds || []), converted.id]),
    convertedDocumentIds: [...new Set([...(source.convertedDocumentIds || []), converted.id])],
    updatedAt: new Date().toISOString(),
  };
  const docs = loadDocuments();
  upsertDocument(docs, linkedSource);
  upsertDocument(docs, converted);
  storeDocuments(docs);
  logOperation({ category: "変更", priority: "通常", assignee: loadSettings().accountName || "自分", memo: `${source.docNumber} から ${converted.docNumber} をコピー作成`, docNumber: converted.docNumber });
  setFormData(converted);
}

function renderRecent() {
  const docs = loadDocuments()
    .sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)))
    .slice(0, 20);

  els.recentList.innerHTML = "";
  if (!docs.length) {
    els.recentList.innerHTML = `<option value="">保存済みなし</option>`;
    els.recentList.disabled = true;
    return;
  }
  els.recentList.disabled = false;
  els.recentList.innerHTML = `<option value="">最近の帳票を選択</option>`;

  docs.forEach((doc) => {
    const option = document.createElement("option");
    option.value = doc.id;
    const source = documentReferenceText(doc);
    option.textContent = `${doc.docNumber} ${DOC_TYPES[doc.docType]?.title || "帳票"} / ${doc.customerName || "取引先未入力"}${source}`;
    els.recentList.appendChild(option);
  });
}

async function copyTextToClipboard(text) {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // Fall through to textarea copy when browser focus/permission blocks Clipboard API.
    }
  }
  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.top = "-1000px";
  document.body.appendChild(textarea);
  textarea.select();
  const ok = document.execCommand("copy");
  textarea.remove();
  return ok;
}

function chooseOrderDirection() {
  const dialog = els.orderDirectionDialog;
  if (!dialog?.showModal) {
    const answer = window.prompt("注文種別を選択してください。\n1: 取引先へ発行する発注書\n2: 取引先から受領した注文記録", "1");
    return Promise.resolve(answer === "1" ? "purchaseOrder" : answer === "2" ? "order" : "");
  }
  return new Promise((resolve) => {
    const handleClose = () => {
      dialog.removeEventListener("close", handleClose);
      resolve(["order", "purchaseOrder"].includes(dialog.returnValue) ? dialog.returnValue : "");
    };
    dialog.addEventListener("close", handleClose, { once: true });
    dialog.returnValue = "";
    dialog.showModal();
  });
}

async function openFlowDocument(type) {
  const doc = getFormData();
  if (type === doc.docType) return;
  const related = relatedFlowDocuments(doc);
  if (type === "order" && !related.get("order") && !related.get("purchaseOrder") && doc.docType !== "purchaseOrder") {
    const selectedType = doc.projectId
      ? (isInboundProject(doc) ? "order" : "purchaseOrder")
      : await chooseOrderDirection();
    if (!selectedType) return;
    type = selectedType;
  }
  const target = related.get(type);
  if (target) {
    await loadDocument(target.id);
    return;
  }
  const targetTitle = DOC_TYPES[type]?.title || "帳票";
  if (!window.confirm(`${targetTitle}はまだ作成されていません。新しく作成しますか？`)) return;
  await copyCurrentDocumentAs(type);
}

function manageFlowIssue(fieldId) {
  const target = fieldId === "lineItems" ? els.lineItems?.querySelector("input, select, button") || els.lineItems : els[fieldId] || document.getElementById(fieldId);
  if (!target) return;
  target.scrollIntoView({ behavior: "smooth", block: "center" });
  window.setTimeout(() => {
    if (typeof target.focus === "function") target.focus();
  }, 220);
}

function renderHistory() {
  if (!els.historyList) return;
  const type = els.historyTypeFilter?.value || "";
  const query = (els.historySearchInput?.value || "").trim().toLowerCase();
  const docs = loadDocuments()
    .filter((doc) => !type || doc.docType === type)
    .filter((doc) => {
      const haystack = [doc.docNumber, DOC_TYPES[doc.docType]?.title, doc.customerName, doc.sourceDocumentNumber, doc.customRelatedNumber, ...Object.values(doc.relatedDocumentNumbers || {})].join(" ").toLowerCase();
      return !query || haystack.includes(query);
    })
    .sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));

  els.historyList.innerHTML = "";
  if (!docs.length) {
    els.historyList.innerHTML = `<div class="empty-master">条件に一致する履歴はありません。</div>`;
    return;
  }

  docs.forEach((doc) => {
    const row = document.createElement("button");
    row.className = "history-item";
    row.type = "button";
    const source = documentReferenceText(doc);
    row.innerHTML = `
      <strong>${escapeHtml(doc.docNumber)}</strong>
      <span>${escapeHtml(DOC_TYPES[doc.docType]?.title || "帳票")} / ${escapeHtml(doc.customerName || "取引先未入力")}${escapeHtml(source)}</span>
      <small>${escapeHtml(formatDate(doc.updatedAt?.slice(0, 10)) || "-")}</small>
    `;
    row.addEventListener("click", async () => {
      if (await loadDocument(doc.id)) {
        els.historyDialog.close();
        setMobileView("form");
      }
    });
    els.historyList.appendChild(row);
  });
}

function openHistoryDialog() {
  if (!els.historyDialog) return;
  els.historyTypeFilter.innerHTML = `<option value="">すべての帳票</option>`;
  Object.entries(DOC_TYPES).forEach(([type, config]) => {
    const option = document.createElement("option");
    option.value = type;
    option.textContent = config.title;
    els.historyTypeFilter.appendChild(option);
  });
  els.historySearchInput.value = "";
  renderHistory();
  els.historyDialog.showModal();
}

function loadSettings() {
  return readStore(SETTINGS_KEY, {
    accountId: "",
    accountProvider: "",
    accountName: "",
    accountEmail: "",
    googleClientId: "",
    googleDriveFileId: "",
    staff: [],
    companies: [],
    seal: DEFAULT_SEAL_SETTINGS,
  });
}

function storeSettings(settings) {
  writeStore(SETTINGS_KEY, settings);
}

function normalizeSealSettings(settings = {}) {
  const preset = SEAL_SIZE_PRESETS[settings.sizePreset] ? settings.sizePreset : "custom";
  const presetSize = SEAL_SIZE_PRESETS[preset] || {};
  const widthSource = presetSize.width || settings.width || settings.size || DEFAULT_SEAL_SETTINGS.width;
  const heightSource = presetSize.height || settings.height || settings.size || DEFAULT_SEAL_SETTINGS.height;
  const width = Math.min(180, Math.max(24, Number(widthSource)));
  const height = Math.min(180, Math.max(24, Number(heightSource)));
  const opacity = Math.min(1, Math.max(0.1, Number(settings.opacity || DEFAULT_SEAL_SETTINGS.opacity)));
  const fit = ["contain", "cover", "fill"].includes(settings.fit) ? settings.fit : DEFAULT_SEAL_SETTINGS.fit;
  return {
    ...DEFAULT_SEAL_SETTINGS,
    ...settings,
    enabled: settings.enabled !== false,
    imageDataUrl: String(settings.imageDataUrl || ""),
    fit,
    width,
    height,
    sizePreset: preset,
    x: Math.min(210, Math.max(0, Number(settings.x ?? DEFAULT_SEAL_SETTINGS.x))),
    y: Math.min(297, Math.max(0, Number(settings.y ?? DEFAULT_SEAL_SETTINGS.y))),
    opacity,
    rotation: Math.min(45, Math.max(-45, Number(settings.rotation || DEFAULT_SEAL_SETTINGS.rotation))),
  };
}

function currentSealSettings() {
  return normalizeSealSettings(loadSettings().seal || {});
}

function stableHash(value = "") {
  let hash = 2166136261;
  for (const char of String(value)) {
    hash ^= char.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function seededRandom(seed, salt = "") {
  let value = stableHash(`${seed}:${salt}`);
  value += 0x6d2b79f5;
  value = Math.imul(value ^ (value >>> 15), value | 1);
  value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
  return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
}

function sealRandomizedPlacement(settings = currentSealSettings(), doc = getFormData()) {
  const seed = [doc.id || state.currentId, doc.docNumber, doc.docType, "seal"].filter(Boolean).join("|");
  const pxToMm = 25.4 / 96;
  const widthMm = Number(settings.width || DEFAULT_SEAL_SETTINGS.width) * pxToMm;
  const heightMm = Number(settings.height || DEFAULT_SEAL_SETTINGS.height) * pxToMm;
  const xRatio = 0.05 + seededRandom(seed, "x-ratio") * 0.1;
  const yRatio = 0.05 + seededRandom(seed, "y-ratio") * 0.1;
  const rotationDelta = 5 + seededRandom(seed, "rotation-delta") * 10;
  const xSign = seededRandom(seed, "x-sign") < 0.5 ? -1 : 1;
  const ySign = seededRandom(seed, "y-sign") < 0.5 ? -1 : 1;
  const rotationSign = seededRandom(seed, "rotation-sign") < 0.5 ? -1 : 1;
  return {
    ...settings,
    x: Math.min(210, Math.max(0, Number(settings.x) + xSign * widthMm * xRatio)),
    y: Math.min(297, Math.max(0, Number(settings.y) + ySign * heightMm * yRatio)),
    rotation: Math.min(45, Math.max(-45, Number(settings.rotation) + rotationSign * rotationDelta)),
  };
}

function sealGridFor(settings, count) {
  const config = SEAL_STYLE_GRIDS[settings.style] || SEAL_STYLE_GRIDS.style_9;
  if (config.auto) {
    if (count <= 3) return { columns: count, rows: 1, flow: "column" };
    const columns = Math.ceil(Math.sqrt(count));
    return { columns, rows: Math.ceil(count / columns), flow: "row" };
  }
  if (config.columns && config.rows) return config;
  if (config.columns) return { ...config, rows: Math.ceil(count / config.columns) };
  if (config.rows) return { ...config, columns: Math.ceil(count / config.rows) };
  return { columns: 1, rows: count, flow: "row" };
}

function buildSealMarkup(settings = currentSealSettings(), options = {}) {
  if (!settings.enabled || !settings.imageDataUrl) return "";
  const width = Number(options.width || settings.width);
  const height = Number(options.height || settings.height);
  const x = Number(options.x ?? settings.x);
  const y = Number(options.y ?? settings.y);
  const fit = settings.fit === "fill" ? "fill" : settings.fit === "cover" ? "cover" : "contain";
  const style = [
    `--seal-x:${x}mm`,
    `--seal-y:${y}mm`,
    `--seal-width:${width}px`,
    `--seal-height:${height}px`,
    `--seal-opacity:${settings.opacity}`,
    `--seal-rotation:${settings.rotation}deg`,
  ].join(";");
  return `<div class="inkantan-seal inkantan-seal-image" style="${style}" aria-label="画像印章"><img class="top-image" alt="" src="${escapeHtml(settings.imageDataUrl)}" style="object-fit:${fit}" /></div>`;
}

function renderSettings() {
  const settings = loadSettings();
  if (els.accountStatus) {
    const label = accountLabel(settings);
    els.accountStatus.innerHTML = `<strong>${escapeHtml(label.provider)} / ${escapeHtml(label.name)}</strong><span>${escapeHtml(label.id)}</span>`;
  }
  if (els.settingsAccountName) els.settingsAccountName.value = settings.accountName || "";
  if (els.settingsAccountEmail) els.settingsAccountEmail.value = settings.accountEmail || "";
  if (els.settingsGoogleClientId) els.settingsGoogleClientId.value = settings.googleClientId || "";
  renderCompanySettings();
  renderSealSettings();
  renderStaffSettings();
}

function renderSealSettings() {
  const settings = currentSealSettings();
  if (els.sealEnabledInput) els.sealEnabledInput.value = String(settings.enabled);
  if (els.sealFitInput) els.sealFitInput.value = settings.fit;
  if (els.sealSizePresetInput) els.sealSizePresetInput.value = settings.sizePreset;
  if (els.sealWidthInput) els.sealWidthInput.value = settings.width;
  if (els.sealHeightInput) els.sealHeightInput.value = settings.height;
  if (els.sealXInput) els.sealXInput.value = settings.x;
  if (els.sealYInput) els.sealYInput.value = settings.y;
  if (els.sealOpacityInput) els.sealOpacityInput.value = settings.opacity;
  if (els.sealRotationInput) els.sealRotationInput.value = settings.rotation;
  if (els.sealImageInput) els.sealImageInput.value = "";
  if (els.sealImageStatus) els.sealImageStatus.textContent = settings.imageDataUrl ? "画像設定済み" : "画像未設定";
  if (els.clearSealImageBtn) els.clearSealImageBtn.disabled = !settings.imageDataUrl;
  if (els.sealPositionMarker) {
    els.sealPositionMarker.style.setProperty("--seal-x", settings.x);
    els.sealPositionMarker.style.setProperty("--seal-y", settings.y);
  }
  syncSealSurfaces(settings);
}

function syncSealSurfaces(settings = currentSealSettings()) {
  const baseMarkup = buildSealMarkup(settings);
  if (els.sealSettingsPreview) els.sealSettingsPreview.innerHTML = baseMarkup;
  if (els.previewSeal) els.previewSeal.innerHTML = baseMarkup;
}

function currentCompanyLogo(company = defaultCompany() || {}) {
  return state.companyLogoMarkedForDeletion ? "" : state.pendingCompanyLogo || company.logo || "";
}

function renderCompanyLogoSettings(company = defaultCompany() || {}) {
  const currentLogo = currentCompanyLogo(company);
  if (els.companyLogoPreview) {
    els.companyLogoPreview.innerHTML = currentLogo ? `<img alt="Logo" src="${escapeHtml(currentLogo)}" />` : "";
    els.companyLogoPreview.classList.toggle("is-empty", !currentLogo);
  }
  if (els.companyLogoStatus) {
    els.companyLogoStatus.textContent = currentLogo ? "Logo設定済み" : "Logo未設定";
  }
  if (els.clearCompanyLogoBtn) {
    els.clearCompanyLogoBtn.disabled = !currentLogo && !company.logo;
  }
  if (els.companyLogoInput) els.companyLogoInput.value = "";
}

function renderCompanySettings() {
  const company = defaultCompany() || {};
  if (els.companyNameInput) els.companyNameInput.value = company.name || "";
  if (els.companyRegistrationInput) els.companyRegistrationInput.value = company.registration || "";
  if (els.companyAddressInput) els.companyAddressInput.value = company.address || "";
  if (els.companyPhoneInput) els.companyPhoneInput.value = company.phone || "";
  if (els.companyContactInput) els.companyContactInput.value = company.contact || "";
  if (els.companyEmailInput) els.companyEmailInput.value = company.email || "";
  renderCompanyLogoSettings(company);
  if (!els.companyList) return;
  const companies = settingsCompanies();
  els.companyList.innerHTML = companies.length ? "" : `<div class="empty-master">自社情報はまだ保存されていません。</div>`;
  companies.forEach((item) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `master-list-item ${item.isDefault ? "active" : ""}`;
    button.innerHTML = `<strong>${escapeHtml(item.name || "名称未入力")}</strong><span>${escapeHtml([item.contact, item.phone, item.email].filter(Boolean).join(" / "))}</span><small>${item.isDefault ? "既定" : "クリックで既定に設定"}</small>`;
    button.addEventListener("click", () => {
      state.pendingCompanyLogo = "";
      state.companyLogoMarkedForDeletion = false;
      saveCompanyRecord(item, { makeDefault: true });
      renderSettings();
      applyCompanyToIssuer(item);
    });
    els.companyList.appendChild(button);
  });
  renderCompanyOptions();
}

function renderStaffSettings() {
  if (!els.staffList) return;
  els.staffList.innerHTML = "";
  const settings = loadSettings();
  const staff = settings.staff || [];
  if (!staff.length) {
    els.staffList.innerHTML = `<div class="empty-master">招待済み社員はありません。</div>`;
  }
  staff.forEach((member) => {
    const item = document.createElement("div");
    item.className = "staff-item";
    const invite = member.inviteUrl ? `<small>${escapeHtml(member.inviteUrl)}</small>` : "";
    item.innerHTML = `
      <div><strong>${escapeHtml(member.name)}</strong><span>${escapeHtml(member.role)} / ${escapeHtml(member.status || "有効")}</span>${invite}</div>
      <div class="staff-actions">
        ${member.inviteUrl ? `<button class="secondary-button" data-copy-invite="${escapeHtml(member.id)}" type="button">リンクコピー</button>` : ""}
        <button class="secondary-button danger-button" data-remove-staff="${escapeHtml(member.id)}" type="button">削除</button>
      </div>
    `;
    els.staffList.appendChild(item);
  });
  renderOperationAssignees();
}

function renderCompanyOptions() {
  if (els.issuerCompanyOptions) {
    els.issuerCompanyOptions.innerHTML = settingsCompanies()
      .flatMap((company) => companySmartValues(company).map((value) => `<option value="${escapeHtml(value)}">${escapeHtml(company.name || "")}</option>`))
      .join("");
  }
  if (els.customerOptions) {
    els.customerOptions.innerHTML = loadCustomers()
      .map((customer) => `<option value="${escapeHtml(customer.companyName)}">${escapeHtml([customerDisplayContact(customer), customer.email].filter(Boolean).join(" / "))}</option>`)
      .join("");
  }
  if (els.customerSmartOptions) {
    els.customerSmartOptions.innerHTML = loadCustomers()
      .flatMap((customer) => customerSmartValues(customer).map((value) => `<option value="${escapeHtml(value)}">${escapeHtml(customer.companyName || "")}</option>`))
      .join("");
  }
  renderItemSmartOptions();
}

function renderItemSmartOptions() {
  const list = document.getElementById("itemSmartOptions");
  if (!list) return;
  list.innerHTML = readStore(ITEM_KEY, []).map(normalizeItem)
    .flatMap((item) => itemSmartValues(item).map((value) => `<option value="${escapeHtml(value)}">${escapeHtml([item.name, item.model].filter(Boolean).join(" / "))}</option>`))
    .join("");
}

function logOperation(entry = {}) {
  const operations = readStore(OPERATION_KEY, []);
  operations.unshift({
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    category: entry.category || "通知",
    priority: entry.priority || "通常",
    assignee: entry.assignee || "",
    status: entry.status || "未対応",
    memo: entry.memo || "",
    docNumber: entry.docNumber || getFormData().docNumber || "",
  });
  writeStore(OPERATION_KEY, operations.slice(0, 200));
}

function renderOperationAssignees() {
  if (!els.operationAssigneeInput) return;
  const staff = loadSettings().staff || [];
  const options = [`<option value="">担当者未指定</option>`, ...staff.map((member) => `<option value="${escapeHtml(member.name)}">${escapeHtml(member.name)} / ${escapeHtml(member.role)}</option>`)];
  els.operationAssigneeInput.innerHTML = options.join("");
}

function renderOperationHistory() {
  if (!els.operationList) return;
  const category = els.operationFilterCategory?.value || "";
  const priority = els.operationFilterPriority?.value || "";
  const query = (els.operationSearchInput?.value || "").trim().toLowerCase();
  const operations = readStore(OPERATION_KEY, [])
    .filter((item) => !category || item.category === category)
    .filter((item) => !priority || item.priority === priority)
    .filter((item) => !query || [item.category, item.priority, item.assignee, item.memo, item.docNumber].join(" ").toLowerCase().includes(query));
  els.operationList.innerHTML = operations.length ? "" : `<div class="empty-master">操作履歴はまだありません。</div>`;
  operations.forEach((item) => {
    const row = document.createElement("div");
    row.className = "history-item";
    row.innerHTML = `
      <strong>${escapeHtml(item.category)} / ${escapeHtml(item.priority)}</strong>
      <span>${escapeHtml(item.memo || "-")}</span>
      <small>${escapeHtml([item.assignee, item.status, item.docNumber, formatDate(item.createdAt?.slice(0, 10))].filter(Boolean).join(" / "))}</small>
    `;
    els.operationList.appendChild(row);
  });
}

function openOperationDialog() {
  const categories = ["承認", "確認依頼", "リマインド", "変更", "通知", "保存", "招待"];
  const priorities = ["重要", "通常", "低"];
  if (els.operationFilterCategory) els.operationFilterCategory.innerHTML = `<option value="">すべての类别</option>${categories.map((item) => `<option value="${item}">${item}</option>`).join("")}`;
  if (els.operationFilterPriority) els.operationFilterPriority.innerHTML = `<option value="">すべての重要度</option>${priorities.map((item) => `<option value="${item}">${item}</option>`).join("")}`;
  renderOperationAssignees();
  renderOperationHistory();
  els.operationDialog.showModal();
}

function acceptInviteFromUrl() {
  const params = new URLSearchParams(location.search);
  const token = params.get("invite");
  if (!token) return;
  const settings = loadSettings();
  const staff = (settings.staff || []).map((member) => (member.inviteToken === token ? { ...member, status: "参加済み" } : member));
  const member = staff.find((item) => item.inviteToken === token);
  if (!member) return;
  storeSettings({ ...settings, staff });
  logOperation({ category: "招待", priority: "通常", assignee: member.name, status: "参加済み", memo: `${member.name} が招待リンクから参加` });
  alert(`${member.name} として参加しました。`);
  history.replaceState(null, "", location.pathname);
}

function openSettingsDialog() {
  state.pendingCompanyLogo = "";
  state.companyLogoMarkedForDeletion = false;
  renderSettings();
  els.backupOutput.value = "";
  els.settingsDialog.showModal();
}

function companyFromSettingsForm(existing = {}) {
  const logo = state.companyLogoMarkedForDeletion ? "" : state.pendingCompanyLogo || existing.logo || "";
  return normalizeCompany({
    ...existing,
    logo,
    name: els.companyNameInput.value.trim(),
    registration: els.companyRegistrationInput.value.trim(),
    address: els.companyAddressInput.value.trim(),
    phone: els.companyPhoneInput.value.trim(),
    contact: els.companyContactInput.value.trim(),
    email: els.companyEmailInput.value.trim(),
    updatedAt: new Date().toISOString(),
  });
}

function buildBackupPayload() {
  return {
    app: "shoko-forms",
    version: 2,
    exportedAt: new Date().toISOString(),
    documents: loadDocuments(),
    customers: loadCustomers(),
    items: readStore(ITEM_KEY, []),
    templates: readStore(TEMPLATE_KEY, []),
    settings: loadSettings(),
  };
}

function downloadBlob(blob, filename) {
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  link.click();
  URL.revokeObjectURL(link.href);
}

function exportBackup() {
  const payload = buildBackupPayload();
  const json = JSON.stringify(payload, null, 2);
  els.backupOutput.value = json;
  const blob = new Blob([json], { type: "application/json" });
  downloadBlob(blob, `shoko-forms-backup-${today()}.json`);
}

function crc32(bytes) {
  let crc = -1;
  for (const byte of bytes) {
    crc ^= byte;
    for (let i = 0; i < 8; i += 1) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ -1) >>> 0;
}

function dosDateTime(date = new Date()) {
  const time = (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2);
  const day = date.getDate();
  const month = date.getMonth() + 1;
  const year = Math.max(1980, date.getFullYear()) - 1980;
  return { time, date: (year << 9) | (month << 5) | day };
}

function u16(value) {
  return [value & 255, (value >>> 8) & 255];
}

function u32(value) {
  return [value & 255, (value >>> 8) & 255, (value >>> 16) & 255, (value >>> 24) & 255];
}

function fileContentBytes(content) {
  if (content instanceof Uint8Array) return content;
  if (content instanceof ArrayBuffer) return new Uint8Array(content);
  return new TextEncoder().encode(String(content ?? ""));
}

function makeZip(files) {
  const encoder = new TextEncoder();
  const localParts = [];
  const centralParts = [];
  let offset = 0;
  const stamp = dosDateTime();

  files.forEach((file) => {
    const nameBytes = encoder.encode(file.name);
    const contentBytes = fileContentBytes(file.content);
    const checksum = crc32(contentBytes);
    const localHeader = new Uint8Array([
      ...u32(0x04034b50), ...u16(20), ...u16(2048), ...u16(0), ...u16(stamp.time), ...u16(stamp.date),
      ...u32(checksum), ...u32(contentBytes.length), ...u32(contentBytes.length), ...u16(nameBytes.length), ...u16(0),
    ]);
    localParts.push(localHeader, nameBytes, contentBytes);
    const centralHeader = new Uint8Array([
      ...u32(0x02014b50), ...u16(20), ...u16(20), ...u16(2048), ...u16(0), ...u16(stamp.time), ...u16(stamp.date),
      ...u32(checksum), ...u32(contentBytes.length), ...u32(contentBytes.length), ...u16(nameBytes.length), ...u16(0), ...u16(0),
      ...u16(0), ...u16(0), ...u32(0), ...u32(offset),
    ]);
    centralParts.push(centralHeader, nameBytes);
    offset += localHeader.length + nameBytes.length + contentBytes.length;
  });

  const centralSize = centralParts.reduce((total, part) => total + part.length, 0);
  const end = new Uint8Array([
    ...u32(0x06054b50), ...u16(0), ...u16(0), ...u16(files.length), ...u16(files.length), ...u32(centralSize), ...u32(offset), ...u16(0),
  ]);
  return new Blob([...localParts, ...centralParts, end], { type: "application/zip" });
}

function exportBackupZip({ download = true } = {}) {
  const payload = buildBackupPayload();
  const json = JSON.stringify(payload, null, 2);
  const zip = makeZip([
    { name: "backup.json", content: json },
    { name: "manifest.json", content: JSON.stringify({ app: payload.app, version: payload.version, exportedAt: payload.exportedAt }, null, 2) },
  ]);
  els.backupOutput.value = json;
  if (download) downloadBlob(zip, `shoko-forms-backup-${today()}.zip`);
  return zip;
}

function safeFilename(value) {
  return String(value || "project").replace(/[\\/:*?"<>|]+/g, "_").replace(/\s+/g, "_").slice(0, 80);
}

function buildArchivePdfPayload(doc, overrides = {}) {
  const currentDoc = getFormData();
  const wasDirty = state.isDirty;

  try {
    setFormData(doc);
    renderPreview();
    return {
      ...buildDocumentRenderPayload(getFormData()),
      ...overrides,
    };
  } finally {
    setFormData(currentDoc);
    renderPreview();
    setDirty(wasDirty);
  }
}

async function archivePdfFile(doc, base = "") {
  const title = `${doc.docNumber || ""} ${DOC_TYPES[doc.docType]?.title || "帳票"}`.trim();
  const filename = `${safeFilename(doc.docNumber || doc.id)}-${safeFilename(DOC_TYPES[doc.docType]?.title || doc.docType)}.html`;
  const payload = buildArchivePdfPayload(doc, { title, filename });
  return {
    name: `${base}${filename}`,
    content: new TextEncoder().encode(`<!doctype html><html lang="ja"><head><meta charset="utf-8"><title>${escapeHtml(title)}</title><link rel="stylesheet" href="../styles.css"></head><body>${payload.html}</body></html>`),
  };
}

function dataUrlToBytes(dataUrl = "") {
  const match = String(dataUrl).match(/^data:.*?;base64,(.*)$/);
  if (!match) return new TextEncoder().encode(dataUrl);
  const binary = atob(match[1]);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function archiveOrderRecordFiles(doc, base = "") {
  const folder = `${base}${safeFilename(doc.docNumber || doc.id)}-${safeFilename(isInboundProject(doc) ? "受領帳票記録" : "注文記録")}/`;
  const files = [{
    name: `${folder}record.json`,
    content: JSON.stringify({
      id: doc.id,
      docType: doc.docType,
      title: DOC_TYPES[doc.docType]?.title || "",
      projectDirection: normalizeProjectDirection(doc.projectDirection),
      docNumber: doc.docNumber,
      customerName: doc.customerName,
      customerContact: doc.customerContact,
      customerEmail: doc.customerEmail,
      issueDate: doc.issueDate,
      transactionDate: doc.transactionDate,
      dueDate: doc.dueDate,
      sourceDocumentNumber: doc.sourceDocumentNumber,
      relatedDocumentNumbers: doc.relatedDocumentNumbers || {},
      notes: doc.notes,
      documentSpecifics: doc.documentSpecifics,
      files: (doc.customerOrderFiles || []).map((file) => ({
        name: file.name,
        category: file.category || "general",
        type: file.type,
        size: file.size,
        uploadedAt: file.uploadedAt,
      })),
    }, null, 2),
  }];
  (doc.customerOrderFiles || []).forEach((file, index) => {
    if (!file.dataUrl) return;
    files.push({
      name: `${folder}${String(index + 1).padStart(2, "0")}-${safeFilename(file.name)}`,
      content: dataUrlToBytes(file.dataUrl),
    });
  });
  return files;
}

async function archiveProjectPdfFiles(project) {
  const base = `${safeFilename(projectDisplayName(project))}/`;
  const files = [];
  for (const doc of project.docs) {
    if (isReceivedDocumentRecord(doc)) files.push(...archiveOrderRecordFiles(doc, base));
    else files.push(await archivePdfFile(doc, base));
  }
  files.push({
    name: `${base}project-index.json`,
    content: JSON.stringify({
      projectId: project.id,
      projectName: projectDisplayName(project),
      projectDirection: normalizeProjectDirection(project.projectDirection),
      companyName: archiveCompanyName(project),
      customerName: project.customerName,
      date: project.date,
      forms: archiveEntriesForProject(project).map((entry) => ({
        type: entry.label,
        docNumber: project.formMap[entry.key]?.docNumber || "",
        completed: Boolean(project.formMap[entry.key]),
      })),
    }, null, 2),
  });
  return files;
}

async function downloadArchiveProjects(projects) {
  if (!projects.length) return;
  const files = [];
  for (const project of projects) {
    files.push(...await archiveProjectPdfFiles(project));
  }
  const zip = makeZip(files);
  const link = document.createElement("a");
  link.href = URL.createObjectURL(zip);
  link.download = projects.length === 1
    ? `${safeFilename(projectDisplayName(projects[0]))}.zip`
    : `niix-project-archive-${today()}.zip`;
  link.click();
  URL.revokeObjectURL(link.href);
}

function buildDocumentRenderPayload(doc = getFormData()) {
  const clone = els.printArea.cloneNode(true);
  const sourceRow = clone.querySelector("#previewSourceRow");
  if (sourceRow) sourceRow.hidden = doc.showRelatedNumber === false || sourceRow.hidden;
  const badge = clone.querySelector("#invoiceBadge");
  if (badge) badge.hidden = !hasQualifiedInvoiceRegistration(doc);
  const filename = `${doc.docNumber || "document"}.pdf`;
  return {
    title: doc.docNumber || DOC_TYPES[doc.docType]?.title || "帳票",
    filename,
    html: clone.outerHTML,
    accent: selectedTemplate().accent || "#2f3744",
  };
}

function buildPdfPayload() {
  renderPreview();
  return buildDocumentRenderPayload();
}

async function buildPreviewPngBlob() {
  renderPreview();
  return renderLocalPreviewPngBlob();
}

function pngFilename(doc = getFormData()) {
  return `${safeFilename(doc.docNumber || DOC_TYPES[doc.docType]?.title || "document")}.png`;
}

function ensurePngLightbox() {
  let dialog = document.getElementById("pngLightboxDialog");
  if (dialog) return dialog;
  dialog = document.createElement("dialog");
  dialog.id = "pngLightboxDialog";
  dialog.className = "png-lightbox-dialog";
  dialog.innerHTML = `
    <form method="dialog" class="modal-card png-lightbox-card">
      <header class="dialog-header">
        <div>
          <p class="eyebrow">Rendered PNG preview</p>
          <h2>PNGプレビュー</h2>
        </div>
        <button class="icon-button" value="cancel" type="submit" aria-label="閉じる">x</button>
      </header>
      <div class="png-lightbox-actions">
        <button class="secondary-button" data-copy-png type="button">PNGをコピー</button>
        <a class="primary-button" data-download-png>PNGダウンロード</a>
      </div>
      <div class="png-lightbox-stage">
        <img alt="帳票PNGプレビュー" data-png-preview />
      </div>
    </form>
  `;
  document.body.appendChild(dialog);
  return dialog;
}

async function copyPngBlob(blob) {
  if (!navigator.clipboard?.write || !window.ClipboardItem) return false;
  await navigator.clipboard.write([new ClipboardItem({ "image/png": blob })]);
  return true;
}

async function openPngLightbox() {
  const button = els.copyJsonBtn || document.getElementById("copyJsonBtn");
  const original = button?.textContent || "";
  if (button) {
    button.disabled = true;
    button.textContent = "PNG生成中";
  }
  let objectUrl = "";
  try {
    const blob = await buildPreviewPngBlob();
    objectUrl = URL.createObjectURL(blob);
    const dialog = ensurePngLightbox();
    const image = dialog.querySelector("[data-png-preview]");
    const download = dialog.querySelector("[data-download-png]");
    const copy = dialog.querySelector("[data-copy-png]");
    if (dialog.dataset.objectUrl) URL.revokeObjectURL(dialog.dataset.objectUrl);
    dialog.dataset.objectUrl = objectUrl;
    image.src = objectUrl;
    download.href = objectUrl;
    download.download = pngFilename();
    copy.textContent = "PNGをコピー";
    copy.onclick = async () => {
      copy.disabled = true;
      try {
        const copied = await copyPngBlob(blob);
        copy.textContent = copied ? "コピー済み" : "コピー非対応";
      } catch {
        copy.textContent = "コピー失敗";
      } finally {
        window.setTimeout(() => {
          copy.textContent = "PNGをコピー";
          copy.disabled = false;
        }, 1400);
      }
    };
    dialog.addEventListener("close", () => {
      if (dialog.dataset.objectUrl) {
        URL.revokeObjectURL(dialog.dataset.objectUrl);
        dialog.dataset.objectUrl = "";
      }
      image.removeAttribute("src");
    }, { once: true });
    dialog.showModal();
  } catch (error) {
    if (objectUrl) URL.revokeObjectURL(objectUrl);
    window.alert(error.message || "PNG生成に失敗しました。");
  } finally {
    if (button) {
      button.disabled = false;
      button.textContent = original;
    }
  }
}

function pickArray(source = {}, names = []) {
  for (const name of names) {
    const value = source[name];
    if (Array.isArray(value)) return value;
    if (value && typeof value === "object") {
      const nested = Object.values(value).find(Array.isArray);
      if (nested) return nested;
    }
  }
  return null;
}

function normalizeBackupPayload(raw = {}) {
  const source = raw.data && typeof raw.data === "object" ? { ...raw, ...raw.data } : raw;
  const documents = pickArray(source, ["documents", "docs", "forms", "records", "archives", "archiveDocuments"]);
  const customers = pickArray(source, ["customers", "clients", "partners", "customerMaster"]);
  const items = pickArray(source, ["items", "products", "services", "itemMaster"]);
  const templates = pickArray(source, ["templates", "layouts"]);
  const settings = source.settings || source.preferences || source.config || null;
  if (!documents && !customers && !items && !templates && !settings && (source.docType || source.docNumber)) {
    return { documents: [source] };
  }
  return { documents, customers, items, templates, settings };
}

function mergeById(existing = [], incoming = []) {
  const byKey = new Map();
  existing.forEach((item) => byKey.set(item.id || item.docNumber || item.companyName || item.name || crypto.randomUUID(), item));
  incoming.forEach((item) => {
    const key = item.id || item.docNumber || item.companyName || item.name || crypto.randomUUID();
    byKey.set(key, { ...byKey.get(key), ...item });
  });
  return [...byKey.values()];
}

function applyBackupPayload(rawPayload) {
  const payload = normalizeBackupPayload(rawPayload);
  let changed = 0;
  if (Array.isArray(payload.documents)) {
    storeDocuments(mergeById(loadDocuments(), payload.documents));
    changed += payload.documents.length;
  }
  if (Array.isArray(payload.customers)) {
    storeCustomers(mergeById(loadCustomers(), payload.customers.map(normalizeCustomer)));
    changed += payload.customers.length;
  }
  if (Array.isArray(payload.items)) {
    writeStore(ITEM_KEY, mergeById(readStore(ITEM_KEY, []), payload.items.map(normalizeItem)));
    changed += payload.items.length;
  }
  if (Array.isArray(payload.templates)) {
    writeStore(TEMPLATE_KEY, mergeById(readStore(TEMPLATE_KEY, []), payload.templates));
    changed += payload.templates.length;
  }
  if (payload.settings && typeof payload.settings === "object") {
    const current = loadSettings();
    storeSettings({
      ...current,
      ...payload.settings,
      companies: mergeById(current.companies || [], (payload.settings.companies || []).map(normalizeCompany)),
      staff: mergeById(current.staff || [], payload.settings.staff || []),
      seal: normalizeSealSettings({ ...current.seal, ...payload.settings.seal }),
    });
    changed += 1;
  }
  renderAll();
  renderSettings();
  syncProjectSurfaces();
  return changed;
}

async function inflateZipContent(bytes, compression) {
  if (compression === 0) return bytes;
  if (compression === 8 && "DecompressionStream" in window) {
    const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
    return new Uint8Array(await new Response(stream).arrayBuffer());
  }
  throw new Error("Unsupported ZIP compression.");
}

async function readZipJsonPayloads(file) {
  const bytes = new Uint8Array(await file.arrayBuffer());
  const decoder = new TextDecoder();
  const payloads = [];
  const u16At = (offset) => bytes[offset] | (bytes[offset + 1] << 8);
  const u32At = (offset) => (bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24)) >>> 0;
  const entries = [];
  for (let offset = Math.max(0, bytes.length - 22); offset >= Math.max(0, bytes.length - 66000); offset -= 1) {
    if (u32At(offset) !== 0x06054b50) continue;
    let centralOffset = u32At(offset + 16);
    const count = u16At(offset + 10);
    for (let index = 0; index < count && centralOffset + 46 <= bytes.length; index += 1) {
      if (u32At(centralOffset) !== 0x02014b50) break;
      const nameLength = u16At(centralOffset + 28);
      const extraLength = u16At(centralOffset + 30);
      const commentLength = u16At(centralOffset + 32);
      const name = decoder.decode(bytes.slice(centralOffset + 46, centralOffset + 46 + nameLength));
      entries.push({
        name,
        compression: u16At(centralOffset + 10),
        compressedSize: u32At(centralOffset + 20),
        localOffset: u32At(centralOffset + 42),
      });
      centralOffset += 46 + nameLength + extraLength + commentLength;
    }
    break;
  }
  if (!entries.length) {
    let offset = 0;
    while (offset + 30 <= bytes.length && u32At(offset) === 0x04034b50) {
      const nameLength = u16At(offset + 26);
      const extraLength = u16At(offset + 28);
      const compressedSize = u32At(offset + 18);
      const nameStart = offset + 30;
      const name = decoder.decode(bytes.slice(nameStart, nameStart + nameLength));
      entries.push({ name, compression: u16At(offset + 8), compressedSize, localOffset: offset });
      offset = nameStart + nameLength + extraLength + compressedSize;
    }
  }
  for (const entry of entries) {
    if (!entry.name.toLowerCase().endsWith(".json")) continue;
    if (u32At(entry.localOffset) !== 0x04034b50) continue;
    const nameLength = u16At(entry.localOffset + 26);
    const extraLength = u16At(entry.localOffset + 28);
    const contentStart = entry.localOffset + 30 + nameLength + extraLength;
    const contentEnd = contentStart + entry.compressedSize;
    if (contentEnd > bytes.length) continue;
    try {
      const content = await inflateZipContent(bytes.slice(contentStart, contentEnd), entry.compression);
      payloads.push(JSON.parse(decoder.decode(content)));
    } catch {
      // Ignore unrelated JSON fragments in loose backup archives.
    }
  }
  return payloads;
}

async function importBackup(file) {
  if (!file) return;
  try {
    const isZip = file.type.includes("zip") || file.name.toLowerCase().endsWith(".zip");
    const payloads = isZip ? await readZipJsonPayloads(file) : [JSON.parse(await file.text())];
    if (!payloads.length) throw new Error("No JSON payloads found.");
    let changed = 0;
    payloads.sort((a, b) => (a.documents || a.docs || a.forms ? -1 : 1) - (b.documents || b.docs || b.forms ? -1 : 1));
    payloads.forEach((payload) => {
      changed += applyBackupPayload(payload);
    });
    updateBackupStatus(`バックアップを読み込みました。${changed} 件のデータ候補を取り込みました。`);
  } catch (error) {
    updateBackupStatus(`バックアップを読み込めませんでした。${error.message || "形式を確認してください。"}`);
  } finally {
    if (els.importBackupInput) els.importBackupInput.value = "";
  }
}

function saveAccountSettings(partial = {}) {
  const settings = loadSettings();
  storeSettings({
    ...settings,
    ...partial,
    googleClientId: els.settingsGoogleClientId?.value.trim() || settings.googleClientId || "",
  });
  renderSettings();
}

function registerEmailAccount() {
  const email = els.settingsAccountEmail?.value.trim() || "";
  if (!email) {
    updateBackupStatus("Emailを入力してから登録してください。");
    return;
  }
  saveAccountSettings({
    accountId: loadSettings().accountId || automaticAccountId(email),
    accountProvider: "email",
    accountName: els.settingsAccountName?.value.trim() || email.split("@")[0],
    accountEmail: email,
  });
  logOperation({ category: "保存", priority: "通常", assignee: email, memo: "Emailアカウントを登録" });
  updateBackupStatus("Emailアカウントを登録しました。");
}

function loadGoogleIdentityScript() {
  if (window.google?.accounts?.oauth2) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const existing = document.querySelector("script[data-google-identity]");
    if (existing) {
      existing.addEventListener("load", resolve, { once: true });
      existing.addEventListener("error", reject, { once: true });
      return;
    }
    const script = document.createElement("script");
    script.src = "https://accounts.google.com/gsi/client";
    script.async = true;
    script.defer = true;
    script.dataset.googleIdentity = "true";
    script.addEventListener("load", resolve, { once: true });
    script.addEventListener("error", () => reject(new Error("Google Identity Servicesを読み込めませんでした。")), { once: true });
    document.head.appendChild(script);
  });
}

async function requestGoogleAccessToken() {
  const settings = loadSettings();
  const clientId = els.settingsGoogleClientId?.value.trim() || settings.googleClientId || "";
  if (!clientId) throw new Error("Google Client IDを設定してください。");
  if (state.googleAccessToken && Date.now() < state.googleTokenExpiresAt - 60000) return state.googleAccessToken;
  await loadGoogleIdentityScript();
  return new Promise((resolve, reject) => {
    const tokenClient = google.accounts.oauth2.initTokenClient({
      client_id: clientId,
      scope: GOOGLE_DRIVE_SCOPE,
      prompt: "",
      callback: async (response) => {
        if (response.error) {
          reject(new Error(response.error_description || response.error));
          return;
        }
        state.googleAccessToken = response.access_token;
        state.googleTokenExpiresAt = Date.now() + Number(response.expires_in || 3600) * 1000;
        storeSettings({ ...settings, googleClientId: clientId });
        resolve(response.access_token);
      },
      error_callback: () => reject(new Error("Google認証がキャンセルされました。")),
    });
    tokenClient.requestAccessToken({ prompt: state.googleAccessToken ? "" : "consent" });
  });
}

async function googleLogin() {
  try {
    const token = await requestGoogleAccessToken();
    const response = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
      headers: { authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw new Error(await response.text() || "Googleユーザー情報を取得できませんでした。");
    const profile = await response.json();
    saveAccountSettings({
      accountId: profile.sub ? `google-${profile.sub}` : loadSettings().accountId || automaticAccountId(profile.email),
      accountProvider: "google",
      accountName: profile.name || profile.email || els.settingsAccountName?.value.trim() || "",
      accountEmail: profile.email || els.settingsAccountEmail?.value.trim() || "",
    });
    logOperation({ category: "保存", priority: "通常", assignee: profile.email || "", memo: "Googleアカウントでログイン" });
    updateBackupStatus("Googleアカウントでログインしました。Driveバックアップを利用できます。");
  } catch (error) {
    updateBackupStatus(error.message || "Googleログインに失敗しました。");
  }
}

async function uploadBackupToDrive() {
  try {
    const token = await requestGoogleAccessToken();
    const zip = exportBackupZip({ download: false });
    const filename = `shoko-forms-backup-${today()}-${Date.now().toString(36)}.zip`;
    const metadata = {
      name: filename,
      mimeType: "application/zip",
      appProperties: { app: "shoko-forms", accountId: loadSettings().accountId || "" },
    };
    const boundary = `shoko_${crypto.randomUUID()}`;
    const body = new Blob([
      `--${boundary}\r\ncontent-type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n`,
      `--${boundary}\r\ncontent-type: application/zip\r\n\r\n`,
      zip,
      `\r\n--${boundary}--`,
    ], { type: `multipart/related; boundary=${boundary}` });
    const response = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink", {
      method: "POST",
      headers: { authorization: `Bearer ${token}` },
      body,
    });
    if (!response.ok) throw new Error(await response.text() || "Drive保存に失敗しました。");
    const file = await response.json();
    storeSettings({ ...loadSettings(), googleDriveFileId: file.id });
    updateBackupStatus(`Google Driveに保存しました。\n${file.name}\n${file.webViewLink || ""}`);
  } catch (error) {
    updateBackupStatus(error.message || "Google Drive保存に失敗しました。");
  }
}

async function restoreLatestBackupFromDrive() {
  try {
    const token = await requestGoogleAccessToken();
    const query = encodeURIComponent("name contains 'shoko-forms-backup' and trashed = false");
    const listResponse = await fetch(`https://www.googleapis.com/drive/v3/files?q=${query}&orderBy=modifiedTime desc&pageSize=10&fields=files(id,name,mimeType,modifiedTime)`, {
      headers: { authorization: `Bearer ${token}` },
    });
    if (!listResponse.ok) throw new Error(await listResponse.text() || "Driveバックアップ一覧を取得できませんでした。");
    const files = (await listResponse.json()).files || [];
    const file = files.find((item) => item.name?.toLowerCase().endsWith(".zip") || item.name?.toLowerCase().endsWith(".json"));
    if (!file) throw new Error("Driveに shoko-forms-backup のバックアップが見つかりません。");
    const fileResponse = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(file.id)}?alt=media`, {
      headers: { authorization: `Bearer ${token}` },
    });
    if (!fileResponse.ok) throw new Error(await fileResponse.text() || "Driveバックアップを取得できませんでした。");
    const blob = await fileResponse.blob();
    await importBackup(new File([blob], file.name, { type: file.mimeType || blob.type }));
    updateBackupStatus(`Google Driveから最新バックアップを読み込みました。\n${file.name}\n${file.modifiedTime || ""}`);
  } catch (error) {
    updateBackupStatus(error.message || "Google Drive読込に失敗しました。");
  }
}

function renderNav() {
  if (els.docTypeSelect) els.docTypeSelect.value = state.docType;
  document.querySelectorAll("[data-doc-type-option]").forEach((button) => {
    const isActive = button.dataset.docTypeOption === state.docType;
    button.classList.toggle("is-active", isActive);
    button.setAttribute("aria-pressed", isActive ? "true" : "false");
  });
}

function renderAll() {
  renderNav();
  renderNotices();
  renderPreview();
  renderFieldIssues();
  renderRecent();
  renderCompanyOptions();
  syncOpenDialogs();
}

function syncOpenDialogs() {
  if (els.historyDialog?.open) renderHistory();
  if (els.customerDialog?.open) renderCustomerMaster();
  if (els.itemDialog?.open) renderItemMaster();
  if (els.operationDialog?.open) {
    renderOperationAssignees();
    renderOperationHistory();
  }
  if (els.archiveDialog?.open) renderArchiveTimeline();
}

function syncProjectSurfaces() {
  renderRecent();
  renderCompanyOptions();
  renderTemplateControls();
  renderFlowSidebar();
  syncOpenDialogs();
}

function setMobileView(view = "form") {
  const nextView = ["menu", "form", "preview"].includes(view) ? view : "form";
  document.body.classList.remove("mobile-view-menu", "mobile-view-form", "mobile-view-preview");
  restoreMobileTitle();
  document.body.classList.add(`mobile-view-${nextView}`);
  document.body.dataset.mobileView = nextView;
  document.querySelectorAll(".mobile-view-switcher [data-mobile-view]").forEach((button) => {
    const isActive = button.dataset.mobileView === nextView;
    button.classList.toggle("is-active", isActive);
    button.setAttribute("aria-current", isActive ? "step" : "false");
  });
  schedulePreviewSnapshot();
}

function setDirty(isDirty = true) {
  state.isDirty = isDirty;
  els.saveStatus.textContent = isDirty ? "未保存" : "保存済み";
  els.saveStatus.style.color = isDirty ? "var(--warn)" : "var(--accent)";
}

function showSaveFeedback() {
  if (!els.saveBtn) return;
  const original = els.saveBtn.textContent;
  els.saveBtn.textContent = "保存済み";
  els.saveBtn.disabled = true;
  setTimeout(() => {
    els.saveBtn.textContent = original;
    els.saveBtn.disabled = false;
  }, 1200);
}

function deleteCurrentDocumentRecord() {
  const doc = getFormData();
  const label = `${DOC_TYPES[doc.docType]?.title || "帳票"} ${doc.docNumber || ""}`.trim();
  if (!confirmRepeatedDelete(label || "現在の帳票")) return;
  const docs = loadDocuments();
  const nextDocs = docs.filter((item) => {
    if (item.id === doc.id) return false;
    return !(doc.docNumber && item.docNumber === doc.docNumber);
  });
  if (nextDocs.length !== docs.length) {
    storeDocuments(nextDocs);
    logOperation({
      category: "変更",
      priority: "通常",
      assignee: loadSettings().accountName || "自分",
      memo: `${DOC_TYPES[doc.docType]?.title || "帳票"} ${doc.docNumber} を削除`,
      docNumber: doc.docNumber,
    });
  }
  setDirty(false);
  syncProjectSurfaces();
}

function discardCurrentDocumentChanges() {
  const saved = loadDocuments().find((item) => item.id === state.currentId);
  if (saved) {
    setFormData(saved);
    return;
  }
  setDirty(false);
}

async function confirmLeaveCurrentDocument() {
  if (!state.isDirty) return true;
  if (!els.leaveGuardDialog) {
    return window.confirm("未保存の変更があります。保存せずに移動しますか？");
  }

  const doc = getFormData();
  els.leaveGuardTitle.textContent = `${DOC_TYPES[doc.docType]?.title || "帳票"} ${doc.docNumber || ""}`.trim();
  els.leaveGuardMessage.textContent = "この帳票ページを離れる前に、保存・破棄・削除の処理を選択してください。未保存の帳票は削除でそのまま破棄されます。";
  els.leaveGuardDeleteBtn.disabled = false;

  if (els.leaveGuardDialog.open) els.leaveGuardDialog.close("cancel");

  return new Promise((resolve) => {
    state.leaveGuardResolve = resolve;
    els.leaveGuardDialog.showModal();
  });
}

function resolveLeaveGuard(action) {
  const resolve = state.leaveGuardResolve;
  state.leaveGuardResolve = null;
  if (!resolve) return;

  if (action === "save") {
    saveDocument();
    resolve(true);
    return;
  }
  if (action === "discard") {
    discardCurrentDocumentChanges();
    resolve(true);
    return;
  }
  if (action === "delete") {
    deleteCurrentDocumentRecord();
    resolve(true);
    return;
  }
  resolve(false);
}

function saveDocument() {
  let doc = normalizeFormObject(applyRelatedNumberMode({
    ...getFormData(),
    projectId: state.projectId || crypto.randomUUID(),
    projectName: state.projectName || els.customerName.value.trim() || `NIIX Project ${today().replaceAll("-", "")}`,
  }));
  state.projectId = doc.projectId;
  state.projectName = doc.projectName;
  let docs = loadDocuments();
  const previous = docs.find((item) => item.id === doc.id);
  const overwriteResult = applyReverseRelatedNumberOverwrite(docs, doc);
  docs = overwriteResult.docs;
  doc = overwriteResult.doc;
  upsertDocument(docs, doc);
  docs = propagateDocumentNumber(docs, doc, previous?.docNumber || "");
  if (overwriteResult.upstream) {
    docs = propagateDocumentNumber(docs, overwriteResult.upstream, overwriteResult.oldNumber);
  }
  try {
    storeDocuments(docs);
  } catch (error) {
    const hasAttachments = doc.customerOrderFiles?.some((file) => file.dataUrl);
    const message = hasAttachments
      ? "保存容量が不足しています。添付ファイルを減らすか、8MB以下のより小さいファイルを選択してください。"
      : "保存に失敗しました。ブラウザの保存容量を確認してください。";
    window.alert(message);
    throw error;
  }
  upsertIssuerFromDocument(doc);
  upsertCustomerFromDocument(doc);
  logOperation({
    category: "保存",
    priority: "通常",
    assignee: loadSettings().accountName || "自分",
    memo: `${DOC_TYPES[doc.docType]?.title || "帳票"} ${doc.docNumber} を保存`,
    docNumber: doc.docNumber,
  });
  syncProjectSurfaces();
  setFormData(doc);
  setDirty(false);
  showSaveFeedback();
}

function buildEmailHtml() {
  const doc = getFormData();
  const clone = els.printArea.cloneNode(true);
  const title = `${doc.docNumber || ""} ${DOC_TYPES[doc.docType]?.title || "帳票"}`.trim();
  const accent = selectedTemplate().accent || "#2f3744";
  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <style>
    body { margin: 0; padding: 16px; background: #f1f4f6; color: #172026; font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Yu Gothic", Meiryo, sans-serif; }
    .mail-wrap { max-width: 760px; margin: 0 auto; background: #fff; }
    .document-preview { width: auto !important; min-height: 0 !important; margin: 0 !important; padding: 24px !important; box-shadow: none !important; --template-accent: ${accent}; }
    .doc-topline { display: none !important; }
    table { width: 100%; border-collapse: collapse; }
    img, iframe { max-width: 100%; }
    @media (max-width: 640px) {
      body { padding: 0; }
      .document-preview { padding: 16px !important; font-size: 12px !important; }
      .doc-header, .party-row, .summary-row { display: block !important; }
      .meta-grid, .issuer-block, .summary-table { margin-top: 16px !important; }
      .line-table { display: block; overflow-x: auto; white-space: nowrap; }
    }
  </style>
</head>
<body><div class="mail-wrap">${clone.outerHTML}</div></body>
</html>`;
}

async function exportEmailHtml() {
  const html = buildEmailHtml();
  const filename = `${getFormData().docNumber || "document"}-mail.html`;
  let dialog = document.getElementById("htmlMailDialog");
  if (!dialog) {
    dialog = document.createElement("dialog");
    dialog.id = "htmlMailDialog";
    dialog.className = "html-mail-dialog";
    dialog.innerHTML = `
      <form method="dialog" class="modal-card html-mail-card">
        <header class="dialog-header">
          <h2>HTMLメール</h2>
          <button class="icon-button" value="cancel" type="submit">×</button>
        </header>
        <div class="html-mail-actions">
          <button class="secondary-button" data-copy-html type="button">表示内容をコピー</button>
          <a class="primary-button" data-download-html>HTML保存</a>
        </div>
        <div class="html-mail-preview"></div>
        <textarea class="html-mail-source" spellcheck="false" hidden></textarea>
      </form>
    `;
    document.body.appendChild(dialog);
  }
  dialog.querySelector(".html-mail-source").value = html;
  const preview = dialog.querySelector(".html-mail-preview");
  preview.innerHTML = new DOMParser().parseFromString(html, "text/html").body.innerHTML;
  const download = dialog.querySelector("[data-download-html]");
  if (download.href) URL.revokeObjectURL(download.href);
  download.href = URL.createObjectURL(new Blob([html], { type: "text/html;charset=utf-8" }));
  download.download = filename;
  const copyButton = dialog.querySelector("[data-copy-html]");
  copyButton.textContent = "表示内容をコピー";
  copyButton.onclick = async () => {
    try {
      if (window.ClipboardItem) {
        await navigator.clipboard.write([
          new ClipboardItem({
            "text/html": new Blob([html], { type: "text/html" }),
            "text/plain": new Blob([preview.innerText], { type: "text/plain" }),
          }),
        ]);
      } else {
        const range = document.createRange();
        range.selectNodeContents(preview);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
        document.execCommand("copy");
        selection.removeAllRanges();
      }
      copyButton.textContent = "コピー済み";
    } catch {
      const range = document.createRange();
      range.selectNodeContents(preview);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      document.execCommand("copy");
      selection.removeAllRanges();
      copyButton.textContent = "コピー済み";
    }
  };
  dialog.addEventListener("close", () => URL.revokeObjectURL(download.href), { once: true });
  dialog.showModal();
}

async function createPdfFile() {
  const payload = buildPdfPayload();
  return {
    filename: payload.filename || "document.pdf",
    html: payload.html,
  };
}

async function exportPdf() {
  const pdfFile = await createPdfFile();
  showPdfPreview(pdfFile, pdfFile.html);
}

async function downloadPdfDirect() {
  if (!window.confirm("最終PDFを生成して保存しますか？")) return;
  printWithBrowserFallback("iOSアプリ版ではPDF保存はシステムの印刷 / 共有シートから実行してください。");
}

async function printPdfDirect() {
  if (!window.confirm("最終PDFを生成して印刷を開始しますか？")) return;
  printWithBrowserFallback();
}

function printWithBrowserFallback(message = "") {
  if (message) window.alert(message);
  window.setTimeout(() => window.print(), 80);
}

function triggerPdfDownload(url, filename = "document.pdf") {
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.rel = "noopener";
  link.style.display = "none";
  document.body.appendChild(link);
  link.click();
  link.remove();
}

function triggerPdfPrint(url) {
  if (!url) {
    printWithBrowserFallback("PDF印刷URLを取得できませんでした。ブラウザ印刷を開きます。");
    return;
  }
  let frame = document.getElementById("hiddenPdfPrintFrame");
  if (!frame) {
    frame = document.createElement("iframe");
    frame.id = "hiddenPdfPrintFrame";
    frame.className = "hidden-print-frame";
    frame.title = "PDF印刷";
    document.body.appendChild(frame);
  }
  const fallbackTimer = window.setTimeout(() => {
    window.open(url, "_blank", "noopener");
  }, 2200);
  frame.onload = () => {
    try {
      window.clearTimeout(fallbackTimer);
      frame.contentWindow.focus();
      frame.contentWindow.print();
    } catch (error) {
      window.clearTimeout(fallbackTimer);
      const opened = window.open(url, "_blank", "noopener");
      if (!opened) window.location.href = url;
    }
  };
  frame.src = url;
}

function openPdfPrintUrl(printUrl) {
  const opened = window.open(printUrl, "_blank", "noopener");
  if (!opened) window.location.href = printUrl;
}

function fitPdfPreview(dialog) {
  const preview = dialog?.querySelector(".pdf-html-preview");
  const sheet = dialog?.querySelector(".pdf-preview-sheet");
  const documentPreview = sheet?.querySelector(".document-preview");
  if (!preview || !sheet || !documentPreview) return;
  const availableWidth = Math.max(0, preview.clientWidth - 24);
  const naturalWidth = documentPreview.offsetWidth || 794;
  const scale = Math.min(1, availableWidth / naturalWidth);
  sheet.style.setProperty("--pdf-preview-scale", String(scale || 1));
  sheet.style.width = `${Math.ceil(naturalWidth * scale)}px`;
  sheet.style.minHeight = `${Math.ceil((documentPreview.offsetHeight || 1123) * scale)}px`;
}

function showPdfPreview(pdfFile, html) {
  let dialog = document.getElementById("pdfPreviewDialog");
  if (!dialog) {
    dialog = document.createElement("dialog");
    dialog.id = "pdfPreviewDialog";
    dialog.className = "pdf-dialog";
    dialog.innerHTML = `
      <form method="dialog" class="modal-card pdf-card">
        <header class="dialog-header">
          <h2>PDFプレビュー</h2>
          <button class="icon-button" value="cancel" type="submit">×</button>
        </header>
        <div class="pdf-actions">
          <button class="secondary-button" data-print-pdf type="button">PDF印刷</button>
          <button class="primary-button" data-download-pdf type="button">PDF保存</button>
        </div>
        <div class="pdf-html-preview"></div>
      </form>
    `;
    dialog.addEventListener("close", () => {
      dialog.querySelector(".pdf-html-preview").innerHTML = "";
    });
    dialog._pdfPreviewResize = () => fitPdfPreview(dialog);
    window.addEventListener("resize", dialog._pdfPreviewResize);
    document.body.appendChild(dialog);
  }
  if (dialog.open) dialog.close();

  const actions = dialog.querySelector(".pdf-actions");
  actions.innerHTML = `
    <button class="secondary-button" data-print-pdf type="button">PDF印刷</button>
    <button class="primary-button" data-download-pdf type="button">PDF保存</button>
  `;
  dialog.querySelector(".pdf-html-preview").innerHTML = `<div class="pdf-preview-sheet">${html || pdfFile.html || ""}</div>`;
  const printButton = dialog.querySelector("[data-print-pdf]");
  const downloadButton = dialog.querySelector("[data-download-pdf]");
  downloadButton.onclick = () => printWithBrowserFallback("iOSアプリ版ではPDF保存はシステムの印刷 / 共有シートから実行してください。");
  printButton.onclick = () => printWithBrowserFallback();
  dialog.showModal();
  window.requestAnimationFrame(() => fitPdfPreview(dialog));
}

function submitPdfForm() {
  printWithBrowserFallback();
}

async function loadDocument(id) {
  if (!(await confirmLeaveCurrentDocument())) return false;
  const doc = loadDocuments().find((item) => item.id === id);
  if (!doc) return false;
  setFormData(doc);
  return true;
}

async function switchDocType(type) {
  if (!(await confirmLeaveCurrentDocument())) {
    renderNav();
    return;
  }
  const next = defaultDocument(type);
  setFormData(next);
}

function documentFromUrl() {
  const params = new URLSearchParams(location.search);
  const id = params.get("form") || params.get("doc") || params.get("id");
  if (!id) return null;
  return loadDocuments().find((doc) => doc.id === id || doc.formObjectId === id || doc.docNumber === id) || null;
}

function renderCustomerMaster() {
  const query = (els.customerSearchInput?.value || "").trim().toLowerCase();
  const customers = loadCustomers().filter((customer) => {
    const haystack = [
      customer.companyName,
      customer.companyAddress,
      customer.companyPhone,
      customer.email,
      customer.fax,
      customer.contactName,
      customer.contactPhone,
      customer.contactEmail,
      customer.department,
      customer.other,
    ].join(" ").toLowerCase();
    return !query || haystack.includes(query);
  });
  if (!els.customerMasterList) return;
  if (!customers.length) {
    els.customerMasterList.innerHTML = `<p class="empty-master">取引先はまだ保存されていません。</p>`;
    renderCustomerDetail(null);
    return;
  }
  if (!state.selectedCustomerId || !customers.some((customer) => customer.id === state.selectedCustomerId)) {
    state.selectedCustomerId = customers[0].id;
  }
  els.customerMasterList.innerHTML = "";
  customers.forEach((customer) => {
    const button = document.createElement("button");
    button.className = `master-list-item ${customer.id === state.selectedCustomerId ? "active" : ""}`;
    button.type = "button";
    button.innerHTML = `
      <strong>${escapeHtml(customer.companyName || "会社名未入力")}</strong>
      <span>${escapeHtml(customerDisplayContact(customer))}</span>
      <small>${escapeHtml([customer.companyPhone, customer.email].filter(Boolean).join(" / "))}</small>
    `;
    button.addEventListener("click", () => {
      state.selectedCustomerId = customer.id;
      renderCustomerMaster();
    });
    els.customerMasterList.appendChild(button);
  });
  renderCustomerDetail(selectedCustomer());
}

function renderCustomerDetail(customer) {
  if (!els.customerDetailView || !els.customerEditForm) return;
  els.customerEditForm.classList.add("hidden");
  els.customerDetailView.classList.remove("hidden");
  els.applyCustomerBtn.disabled = !customer;
  els.editCustomerBtn.disabled = !customer;
  els.deleteCustomerBtn.disabled = !customer;

  if (!customer) {
    els.customerDetailTitle.textContent = "取引先を選択";
    els.customerDetailView.innerHTML = `<p class="empty-master">左の一覧から取引先を選択、または新規作成してください。</p>`;
    return;
  }

  els.customerDetailTitle.textContent = customer.companyName || "会社名未入力";
  els.customerDetailView.innerHTML = `
    ${detailRow("会社名称", customer.companyName)}
    ${detailRow("会社地址", customer.companyAddress)}
    ${detailRow("会社電話", customer.companyPhone)}
    ${detailRow("Email", customer.email)}
    ${detailRow("FAX", customer.fax)}
    ${detailRow("聯絡人", customer.contactName)}
    ${detailRow("聯絡人電話", customer.contactPhone)}
    ${detailRow("聯絡人Email", customer.contactEmail)}
    ${detailRow("部署 / 役職", customer.department)}
    ${detailRow("其他", customer.other)}
  `;
}

function detailRow(label, value) {
  return `<div><dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value || "-")}</dd></div>`;
}

function fillCustomerEditForm(customer = {}) {
  const normalized = normalizeCustomer(customer);
  els.customerCompanyInput.value = normalized.companyName;
  els.customerAddressInput.value = normalized.companyAddress;
  els.customerPhoneInput.value = normalized.companyPhone;
  els.customerEmailInput.value = normalized.email;
  els.customerFaxInput.value = normalized.fax;
  els.customerContactNameInput.value = normalized.contactName;
  els.customerContactPhoneInput.value = normalized.contactPhone;
  els.customerContactEmailInput.value = normalized.contactEmail;
  els.customerDepartmentInput.value = normalized.department;
  els.customerOtherInput.value = normalized.other;
}

function openCustomerEdit(customer = null) {
  if (!els.customerEditForm || !els.customerDetailView) return;
  if (!customer) state.selectedCustomerId = "";
  fillCustomerEditForm(customer || {});
  els.customerDetailTitle.textContent = customer ? "取引先を編集" : "取引先を新規追加";
  els.customerDetailView.classList.add("hidden");
  els.customerEditForm.classList.remove("hidden");
  els.applyCustomerBtn.disabled = true;
  els.editCustomerBtn.disabled = true;
  els.deleteCustomerBtn.disabled = !customer;
}

function customerFromEditForm(existing = {}) {
  return normalizeCustomer({
    ...existing,
    companyName: els.customerCompanyInput.value.trim(),
    companyAddress: els.customerAddressInput.value.trim(),
    companyPhone: els.customerPhoneInput.value.trim(),
    email: els.customerEmailInput.value.trim(),
    fax: els.customerFaxInput.value.trim(),
    contactName: els.customerContactNameInput.value.trim(),
    contactPhone: els.customerContactPhoneInput.value.trim(),
    contactEmail: els.customerContactEmailInput.value.trim(),
    department: els.customerDepartmentInput.value.trim(),
    other: els.customerOtherInput.value.trim(),
    updatedAt: new Date().toISOString(),
  });
}

function saveCustomerRecord(customer, options = {}) {
  const normalized = normalizeCustomer(customer);
  const customers = loadCustomers();
  const index = customers.findIndex((item) => item.id === normalized.id || (normalized.companyName && item.companyName === normalized.companyName));
  if (index >= 0) customers[index] = normalized;
  else customers.unshift(normalized);
  storeCustomers(customers);
  state.selectedCustomerId = normalized.id;
  if (!options.silent) renderCustomerMaster();
  renderCompanyOptions();
  syncOpenDialogs();
  return normalized;
}

function renderItemMaster() {
  const items = readStore(ITEM_KEY, []).map(normalizeItem);
  renderItemSmartOptions();
  if (!els.itemMasterList) return;
  els.itemMasterList.innerHTML = "";
  if (!items.length) {
    els.itemMasterList.innerHTML = `<p class="empty-master">商品・サービスはまだ保存されていません。</p>`;
    return;
  }
  items.forEach((item) => {
    const row = document.createElement("div");
    row.className = "item-master-row";
    row.innerHTML = `
      <button class="master-list-item" type="button" data-item-apply="${escapeHtml(item.id)}">
        <strong>${escapeHtml(item.name)}</strong>
        <span>${escapeHtml([item.model || "番号未設定", item.specification].filter(Boolean).join(" / "))} / ${yen(item.unitPrice)}</span>
      </button>
      <button class="text-button danger" type="button" data-item-delete="${escapeHtml(item.id)}">削除</button>
    `;
    row.querySelector("[data-item-apply]")?.addEventListener("click", () => {
      state.lines.push({
        id: crypto.randomUUID(),
        name: item.name,
        model: item.model || "",
        specification: item.specification || "",
        quantity: 1,
        unitPrice: item.unitPrice,
      });
      els.itemDialog.close();
      renderLines();
      renderPreview();
      setDirty(true);
    });
    row.querySelector("[data-item-delete]")?.addEventListener("click", () => {
      if (!confirmRepeatedDelete(`商品・サービス ${item.name || ""}`.trim())) return;
      writeStore(ITEM_KEY, items.filter((record) => record.id !== item.id));
      renderItemMaster();
    });
    els.itemMasterList.appendChild(row);
  });
}

function applyItemToLine(line, item, { preserveQuantity = true } = {}) {
  if (!line || !item) return false;
  const currentQuantity = Number(line.quantity || 0) || 1;
  line.name = item.name || line.name || "";
  line.model = item.model || line.model || "";
  line.specification = item.specification || line.specification || "";
  line.unitPrice = Number(item.unitPrice || line.unitPrice || 0);
  if (preserveQuantity) line.quantity = currentQuantity;
  return true;
}

function applySmartCustomerFromInput(input) {
  if (!input) return false;
  const customer = findCustomerBySmartInput(input.value);
  if (!customer) return false;
  applyCustomerToDocument(customer);
  return true;
}

function applySmartCompanyFromInput(input) {
  if (!input) return false;
  const company = findCompanyBySmartInput(input.value);
  if (!company) return false;
  applyCompanyToIssuer(company);
  return true;
}

function applySmartItemFromInput(input) {
  if (!input?.dataset?.id || !["name", "model", "specification"].includes(input.dataset.field)) return false;
  const item = findItemBySmartInput(input.value);
  if (!item) return false;
  const line = state.lines.find((record) => record.id === input.dataset.id);
  if (!applyItemToLine(line, item)) return false;
  renderLines();
  renderPreview();
  setDirty(true);
  return true;
}

function applySmartItemMasterFromInput(input) {
  if (!input) return false;
  const item = findItemBySmartInput(input.value);
  if (!item) return false;
  if (els.itemNameInput) els.itemNameInput.value = item.name || "";
  if (els.itemModelInput) els.itemModelInput.value = item.model || "";
  if (els.itemSpecInput) els.itemSpecInput.value = item.specification || "";
  if (els.itemPriceInput) els.itemPriceInput.value = item.unitPrice || "";
  return true;
}

function bindElements() {
  for (const id of [
    "pageTitle",
    "saveBtn",
    "saveStatus",
    "leaveGuardDialog",
    "leaveGuardTitle",
    "leaveGuardMessage",
    "leaveGuardDeleteBtn",
    "leaveGuardDiscardBtn",
    "leaveGuardCancelBtn",
    "leaveGuardSaveBtn",
    "orderDirectionDialog",
    "recentList",
    "flowSteps",
    "topFlowTabs",
    "documentForm",
    "docTypeSelect",
    "docTypeOptions",
    "basicSectionTitle",
    "docNumberLabel",
    "issueDateLabel",
    "transactionDateLabel",
    "dueDateLabel",
    "taxRateLabel",
    "relatedNumberPickerWrap",
    "relatedNumberPickerLabel",
    "relatedDocumentTypeLabel",
    "customRelatedNumberLabel",
    "relatedNumberModeLabel",
    "partySectionTitle",
    "partyNameLabel",
    "partyAddressLabel",
    "partyContactLabel",
    "partyEmailLabel",
    "issuerSectionTitle",
    "loadIssuerBtn",
    "notesLabel",
    "bankDetailsLabel",
    "documentSpecificsLabel",
    "docNumber",
    "issueDate",
    "transactionDate",
    "dueDate",
    "relatedNumberPicker",
    "relatedDocumentType",
    "customRelatedNumber",
    "relatedNumberMode",
    "honorific",
    "customerName",
    "customerAddress",
    "customerContact",
    "customerEmail",
    "issuerName",
    "issuerRegistration",
    "issuerAddress",
    "issuerContact",
    "issuerPhone",
    "issuerEmail",
    "issuerCompanyOptions",
    "customerOptions",
    "customerSmartOptions",
    "notes",
    "bankDetails",
    "documentSpecifics",
    "taxRate",
    "noticeType",
    "noticeTitle",
    "noticeBody",
    "noticeList",
    "customerOrderFileSection",
    "customerOrderFileTitle",
    "customerOrderFileHint",
    "customerOrderFileStatus",
    "customerOrderFileInput",
    "customerOrderFileList",
    "orderRecordPreview",
    "orderRecordTitle",
    "orderRecordNumber",
    "orderRecordDate",
    "orderRecordDueDate",
    "orderRecordCustomer",
    "orderRecordSource",
    "orderRecordFiles",
    "orderRecordNotes",
    "previewNoticeSection",
    "previewNotices",
    "lineItems",
    "lineItemsHead",
    "previewTitle",
    "previewSubtitle",
    "previewNumber",
    "previewLead",
    "previewNumberLabel",
    "previewIssueDateLabel",
    "previewTransactionDateLabel",
    "previewDueDateLabel",
    "previewSourceLabel",
    "previewIssueDate",
    "previewTransactionDate",
    "previewDueDate",
    "previewSourceRow",
    "previewSource",
    "previewSeal",
    "previewCustomerName",
    "previewCustomerAddress",
    "previewCustomerContact",
    "invoiceBadge",
    "previewLogo",
    "previewIssuerName",
    "previewIssuerAddress",
    "previewIssuerRegistration",
    "previewIssuerContact",
    "totalBanner",
    "totalLabel",
    "previewGrandTotal",
    "previewBannerBank",
    "previewBannerBankText",
    "previewLines",
    "previewLineHead",
    "previewSubtotal",
    "previewTaxable8",
    "previewTaxable10",
    "previewTaxable0",
    "previewTax8",
    "previewTax10",
    "previewTaxableRateLabel",
    "previewTaxRateLabel",
    "previewTotal",
    "previewNotes",
    "previewBankTitle",
    "previewBank",
    "previewSpecificsTitle",
    "previewSpecifics",
    "printArea",
    "previewPngFrame",
    "previewPngImage",
    "previewPngStatus",
    "templateSelect",
    "templatePalette",
    "copyJsonBtn",
    "downloadPdfBtn",
    "printBtn",
    "jsonDialog",
    "jsonOutput",
    "historyDialog",
    "historyTypeFilter",
    "historySearchInput",
    "historyList",
    "settingsDialog",
    "accountStatus",
    "settingsAccountName",
    "settingsAccountEmail",
    "settingsGoogleClientId",
    "saveSettingsBtn",
    "registerEmailAccountBtn",
    "googleLoginBtn",
    "sealEnabledInput",
    "sealImageInput",
    "clearSealImageBtn",
    "sealImageStatus",
    "sealFitInput",
    "sealSizePresetInput",
    "sealWidthInput",
    "sealHeightInput",
    "sealXInput",
    "sealYInput",
    "sealOpacityInput",
    "sealRotationInput",
    "sealSettingsPreview",
    "sealPositionPad",
    "sealPositionMarker",
    "companyLogoInput",
    "companyLogoPreview",
    "clearCompanyLogoBtn",
    "companyLogoStatus",
    "companyNameInput",
    "companyRegistrationInput",
    "companyAddressInput",
    "companyPhoneInput",
    "companyContactInput",
    "companyEmailInput",
    "saveCompanyBtn",
    "companyList",
    "staffNameInput",
    "staffRoleInput",
    "inviteStaffBtn",
    "staffList",
    "operationDialog",
    "operationCategoryInput",
    "operationPriorityInput",
    "operationAssigneeInput",
    "operationMemoInput",
    "addOperationBtn",
    "operationFilterCategory",
    "operationFilterPriority",
    "operationSearchInput",
    "operationList",
    "archiveDialog",
    "archiveProjectDialog",
    "createFormObjectBtn",
    "archiveSearchInput",
    "newArchiveProjectBtn",
    "archiveProjectCompanySelect",
    "archiveProjectCompanyNameInput",
    "archiveProjectCompanyAddressInput",
    "archiveProjectCompanyContactInput",
    "archiveProjectNamePreview",
    "confirmCreateArchiveProjectBtn",
    "exportSelectedProjectsBtn",
    "archiveTimeline",
    "archiveDetail",
    "exportBackupBtn",
    "exportBackupZipBtn",
    "backupToDriveBtn",
    "restoreFromDriveBtn",
    "importBackupInput",
    "backupOutput",
    "conversionStatus",
    "conversionTarget",
    "convertDocumentBtn",
    "nextStepBtn",
    "customerDialog",
    "customerSearchInput",
    "newCustomerBtn",
    "customerMasterList",
    "customerDetailTitle",
    "customerDetailView",
    "customerEditForm",
    "applyCustomerBtn",
    "editCustomerBtn",
    "customerCompanyInput",
    "customerAddressInput",
    "customerPhoneInput",
    "customerEmailInput",
    "customerFaxInput",
    "customerContactNameInput",
    "customerContactPhoneInput",
    "customerContactEmailInput",
    "customerDepartmentInput",
    "customerOtherInput",
    "deleteCustomerBtn",
    "cancelCustomerEditBtn",
    "saveCustomerDetailBtn",
    "itemDialog",
    "itemNameInput",
    "itemModelInput",
    "itemSpecInput",
    "itemPriceInput",
    "itemMasterList",
  ]) {
    els[id] = document.getElementById(id);
  }
}

function bindEvents() {
  document.querySelectorAll(".mobile-view-switcher [data-mobile-view]").forEach((button) => {
    button.addEventListener("click", () => setMobileView(button.dataset.mobileView));
  });

  document.querySelectorAll("[data-mobile-action]").forEach((button) => {
    button.addEventListener("click", async () => {
      const action = button.dataset.mobileAction;
      if (["menu", "form", "preview"].includes(action)) {
        setMobileView(action);
        if (action === "preview" && isNativeApp() && !isCustomerOrderRecord()) {
          try {
            await exportPdf();
          } catch (error) {
            console.error("pdf preview failed", error);
            window.alert(error.message || "PDFプレビューに失敗しました。");
          }
        }
        return;
      }
      if (action === "save") {
        saveDocument();
        return;
      }
      if (action === "pdf") {
        document.getElementById("printBtn")?.click();
        return;
      }
      if (action === "download-pdf") {
        document.getElementById("downloadPdfBtn")?.click();
        return;
      }
      if (action === "new" && (await confirmLeaveCurrentDocument())) {
        setFormData(defaultDocument(state.docType));
        setMobileView("form");
      }
    });
  });
  bindMobileTitleAutoHide();

  window.addEventListener("beforeunload", (event) => {
    if (!state.isDirty) return;
    event.preventDefault();
    event.returnValue = "";
  });
  window.addEventListener("resize", () => {
    schedulePreviewSnapshot();
    syncMobileFormAccordions();
  });

  els.documentForm?.addEventListener("click", (event) => {
    const heading = event.target.closest(".form-section > .section-heading");
    if (!heading || event.target.closest("button, a, input, select, textarea, label")) return;
    toggleMobileFormSection(heading.closest(".form-section"));
  });

  els.documentForm?.addEventListener("keydown", (event) => {
    if (!["Enter", " "].includes(event.key)) return;
    const heading = event.target.closest(".form-section > .section-heading");
    if (!heading) return;
    event.preventDefault();
    toggleMobileFormSection(heading.closest(".form-section"));
  });

  els.leaveGuardDialog?.addEventListener("close", () => {
    resolveLeaveGuard(els.leaveGuardDialog.returnValue || "cancel");
  });

  els.documentForm.addEventListener("input", () => {
    renderPreview();
    setDirty(true);
  });
  els.documentForm.addEventListener("change", () => {
    renderPreview();
    setDirty(true);
  });
  ["click", "input", "change"].forEach((eventName) => {
    els.showRelatedNumber?.addEventListener(eventName, () => {
      window.requestAnimationFrame(() => {
        syncRelatedNumberVisibility();
        setDirty(true);
      });
    });
  });
  const handleRelatedNumberPicker = async () => {
    if (!(await applyRelatedPickerSelection())) return;
    renderPreview();
    setDirty(true);
  };
  els.relatedNumberPicker?.addEventListener("input", handleRelatedNumberPicker);
  els.relatedNumberPicker?.addEventListener("change", handleRelatedNumberPicker);
  els.relatedNumberMode?.addEventListener("input", () => {
    if (els.customRelatedNumber) els.customRelatedNumber.value = els.relatedNumberMode.value.trim();
    renderPreview();
    setDirty(true);
  });
  els.relatedNumberMode?.addEventListener("change", () => {
    if (els.customRelatedNumber) els.customRelatedNumber.value = els.relatedNumberMode.value.trim();
    renderPreview();
    setDirty(true);
  });
  els.relatedDocumentType?.addEventListener("change", () => {
    state.relatedDocumentType = els.relatedDocumentType.value;
    renderPreview();
    setDirty(true);
  });
  els.customRelatedNumber?.addEventListener("input", () => {
    if (els.relatedNumberMode) {
      els.relatedNumberMode.value = els.customRelatedNumber.value.trim();
      renderPreview();
      setDirty(true);
    }
  });

  els.lineItems.addEventListener("input", (event) => {
    const input = event.target.closest("[data-id]");
    if (!input) return;
    const line = state.lines.find((item) => item.id === input.dataset.id);
    if (!line) return;
    line[input.dataset.field] = ["name", "model", "specification"].includes(input.dataset.field) ? input.value : Number(input.value);
    if (applySmartItemFromInput(input)) return;
    renderPreview();
    setDirty(true);
  });

  els.lineItems.addEventListener("click", (event) => {
    const button = event.target.closest("[data-remove]");
    if (!button) return;
    if (!confirmRepeatedDelete("明細行")) return;
    state.lines = state.lines.filter((line) => line.id !== button.dataset.remove);
    if (!state.lines.length) {
      state.lines.push({ id: crypto.randomUUID(), name: "", model: "", specification: "", quantity: 1, unitPrice: 0 });
    }
    renderLines();
    renderPreview();
    setDirty(true);
  });

  els.noticeType?.addEventListener("change", () => {
    const template = NOTICE_TEMPLATES[els.noticeType.value] || NOTICE_TEMPLATES.general;
    if (!els.noticeTitle.value.trim()) els.noticeTitle.value = template.title;
    if (!els.noticeBody.value.trim()) els.noticeBody.value = template.body;
  });

  document.getElementById("addNoticeBtn")?.addEventListener("click", () => {
    const template = NOTICE_TEMPLATES[els.noticeType.value] || NOTICE_TEMPLATES.general;
    const title = els.noticeTitle.value.trim() || template.title;
    const body = els.noticeBody.value.trim() || template.body;
    state.notices.push({
      id: crypto.randomUUID(),
      type: els.noticeType.value || "general",
      title,
      body,
      createdAt: new Date().toISOString(),
    });
    els.noticeTitle.value = "";
    els.noticeBody.value = "";
    renderNotices();
    renderPreview();
    setDirty(true);
  });

  els.noticeList?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-remove-notice]");
    if (!button) return;
    if (!confirmRepeatedDelete("通知")) return;
    state.notices = state.notices.filter((notice) => notice.id !== button.dataset.removeNotice);
    renderNotices();
    renderPreview();
    setDirty(true);
  });

  const readCustomerFilesLocally = async (files) => {
    const readFile = (file) => new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve({
        id: crypto.randomUUID(),
        name: file.name,
        type: file.type || "application/octet-stream",
        size: file.size,
        dataUrl: reader.result,
        uploadedAt: new Date().toISOString(),
      });
      reader.onerror = () => reject(reader.error || new Error("ファイルを読み込めませんでした。"));
      reader.readAsDataURL(file);
    });
    return Promise.all(files.map(readFile));
  };

  const handleCustomerFileUpload = async (source, category = "general") => {
    const files = Array.isArray(source) ? source : [...(source?.files || [])];
    if (!files.length) return;
    const maxBytes = 8 * 1024 * 1024;
    const tooLarge = files.find((file) => file.size > maxBytes);
    if (tooLarge) {
      window.alert(`${tooLarge.name} は8MBを超えています。バックアップに含めるため、8MB以下のファイルを選択してください。`);
      if (source && "value" in source) source.value = "";
      return;
    }
    const uploadedAt = new Date().toISOString();
    if (els.customerOrderFileStatus) els.customerOrderFileStatus.textContent = "読込中...";
    try {
      const uploaded = await readCustomerFilesLocally(files);
      const attachments = uploaded.map((file) => normalizeCustomerOrderFile({
        category,
        uploadedAt,
        ...file,
      }));
      state.customerOrderFiles = [...(state.customerOrderFiles || []), ...attachments];
      if (source && "value" in source) source.value = "";
      renderCustomerOrderFiles();
      renderPreview();
      if (els.customerOrderFileStatus) els.customerOrderFileStatus.textContent = `${state.customerOrderFiles.length}件添付済み`;
      setDirty(true);
    } catch (error) {
      if (source && "value" in source) source.value = "";
      if (els.customerOrderFileStatus) els.customerOrderFileStatus.textContent = "読込失敗";
      window.alert(error?.message || "ファイルを読み込めませんでした。");
    }
  };

  const importCustomerFilePath = async (category = "general") => {
    if (els.customerOrderFileStatus) els.customerOrderFileStatus.textContent = "ファイル選択を使用してください";
    window.alert("iOSアプリ版では絶対パス指定ではなく、ファイル選択から添付してください。");
  };

  els.customerOrderFileInput?.addEventListener("change", async (event) => {
    event.stopPropagation();
    await handleCustomerFileUpload(event.target, "general");
  });

  els.customerOrderFileList?.addEventListener("change", async (event) => {
    event.stopPropagation();
    const input = event.target.closest("[data-customer-file-category]");
    if (!input) return;
    await handleCustomerFileUpload(input, input.dataset.customerFileCategory || "general");
  });

  els.customerOrderFileList?.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-import-customer-file-path]");
    if (!button) return;
    await importCustomerFilePath(button.dataset.importCustomerFilePath || "general");
  });

  els.customerOrderFileList?.addEventListener("keydown", async (event) => {
    const input = event.target.closest("[data-customer-file-path]");
    if (!input || event.key !== "Enter") return;
    event.preventDefault();
    await importCustomerFilePath(input.dataset.customerFilePath || "general");
  });

  els.customerOrderFileSection?.addEventListener("dragover", (event) => {
    const zone = event.target.closest("[data-customer-file-drop-zone], .file-upload-field");
    if (!zone) return;
    event.preventDefault();
    zone.classList.add("is-drag-over");
    if (event.dataTransfer) event.dataTransfer.dropEffect = "copy";
  });

  els.customerOrderFileSection?.addEventListener("dragleave", (event) => {
    const zone = event.target.closest("[data-customer-file-drop-zone], .file-upload-field");
    if (!zone || zone.contains(event.relatedTarget)) return;
    zone.classList.remove("is-drag-over");
  });

  els.customerOrderFileSection?.addEventListener("drop", async (event) => {
    const zone = event.target.closest("[data-customer-file-drop-zone], .file-upload-field");
    if (!zone) return;
    event.preventDefault();
    zone.classList.remove("is-drag-over");
    const files = [...(event.dataTransfer?.files || [])];
    const category = zone.dataset.customerFileDropZone || "general";
    await handleCustomerFileUpload(files, category);
  });

  els.customerOrderFileList?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-remove-order-file]");
    if (!button) return;
    const file = (state.customerOrderFiles || []).find((item) => item.id === button.dataset.removeOrderFile);
    if (!confirmRepeatedDelete(file?.name || "注文ファイル")) return;
    state.customerOrderFiles = (state.customerOrderFiles || []).filter((item) => item.id !== button.dataset.removeOrderFile);
    renderCustomerOrderFiles();
    renderPreview();
    setDirty(true);
  });

  document.getElementById("addLineBtn").addEventListener("click", () => {
    state.lines.push({ id: crypto.randomUUID(), name: "", model: "", specification: "", quantity: 1, unitPrice: 0 });
    renderLines();
    renderPreview();
    setDirty(true);
  });

  document.getElementById("addProductLineBtn")?.addEventListener("click", () => {
    renderItemMaster();
    els.itemDialog.showModal();
  });

  document.getElementById("loadProjectLinesBtn")?.addEventListener("click", openProjectLinesDialog);

  document.addEventListener("click", (event) => {
    const allButton = event.target.closest("[data-load-all-project-lines]");
    const sourceButton = event.target.closest("[data-load-source-lines]");
    const lineButton = event.target.closest("[data-load-source-line]");
    if (!allButton && !sourceButton && !lineButton) return;
    const sources = detailSourceDocuments();
    if (allButton) {
      appendProjectLines(uniqueProjectSourceLines(sources));
      document.getElementById("projectLinesDialog")?.close();
      return;
    }
    const sourceId = (sourceButton || lineButton).dataset.loadSourceLines || lineButton?.dataset.loadSourceLine;
    const source = sources.find((doc) => doc.id === sourceId);
    if (!source) return;
    if (sourceButton) {
      appendProjectLines(source.lines || []);
    } else {
      const line = (source.lines || []).find((item) => item.id === lineButton.dataset.lineId);
      appendProjectLines(line ? [line] : []);
    }
    document.getElementById("projectLinesDialog")?.close();
  });

  document.getElementById("saveBtn").addEventListener("click", saveDocument);
  els.downloadPdfBtn?.addEventListener("click", async () => {
    const button = els.downloadPdfBtn;
    const original = button.textContent;
    button.disabled = true;
    button.textContent = "PDF生成中";
    try {
      await downloadPdfDirect();
    } catch (error) {
      console.error("pdf download failed", error);
      window.alert(error.message || "PDFダウンロードに失敗しました。");
    } finally {
      button.disabled = false;
      button.textContent = original;
    }
  });
  document.getElementById("printBtn").addEventListener("click", async () => {
    const button = document.getElementById("printBtn");
    const original = button.textContent;
    button.disabled = true;
    button.textContent = "PDF生成中";
    try {
      await printPdfDirect();
    } catch (error) {
      console.error("pdf button failed", error);
      printWithBrowserFallback(error.message || "PDF出力に失敗したため、ブラウザ印刷を開きます。");
    } finally {
      button.disabled = false;
      button.textContent = original;
    }
  });
  document.getElementById("newDocumentBtn").addEventListener("click", async () => {
    if (await confirmLeaveCurrentDocument()) setFormData(defaultDocument(state.docType));
  });
  els.flowSteps?.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-flow-type]");
    if (!button) return;
    await openFlowDocument(button.dataset.flowType);
    setMobileView("form");
  });
  els.topFlowTabs?.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-flow-type]");
    if (!button) return;
    await openFlowDocument(button.dataset.flowType);
    setMobileView("form");
  });
  document.getElementById("openSettingsBtn")?.addEventListener("click", openSettingsDialog);
  els.recentList?.addEventListener("change", async () => {
    const id = els.recentList.value;
    if (!id) return;
    if (await loadDocument(id)) setMobileView("form");
    els.recentList.value = "";
  });
  els.historyTypeFilter?.addEventListener("change", renderHistory);
  els.historySearchInput?.addEventListener("input", renderHistory);
  els.saveSettingsBtn?.addEventListener("click", () => {
    const settings = loadSettings();
    storeSettings({
      ...settings,
      accountName: els.settingsAccountName.value.trim(),
      accountEmail: els.settingsAccountEmail.value.trim(),
      googleClientId: els.settingsGoogleClientId.value.trim(),
    });
    renderSettings();
  });
  els.registerEmailAccountBtn?.addEventListener("click", registerEmailAccount);
  els.googleLoginBtn?.addEventListener("click", googleLogin);
  [
    "sealEnabledInput",
    "sealFitInput",
    "sealSizePresetInput",
    "sealWidthInput",
    "sealHeightInput",
    "sealXInput",
    "sealYInput",
    "sealOpacityInput",
    "sealRotationInput",
  ].forEach((id) => {
    const updateSeal = () => {
      const settings = loadSettings();
      storeSettings({
        ...settings,
        seal: normalizeSealSettings({
          ...currentSealSettings(),
          enabled: els.sealEnabledInput.value === "true",
          fit: els.sealFitInput.value,
          sizePreset: els.sealSizePresetInput.value,
          width: Number(els.sealWidthInput.value),
          height: Number(els.sealHeightInput.value),
          x: Number(els.sealXInput.value),
          y: Number(els.sealYInput.value),
          opacity: Number(els.sealOpacityInput.value),
          rotation: Number(els.sealRotationInput.value),
        }),
      });
      renderSealSettings();
      renderPreview();
    };
    els[id]?.addEventListener("input", updateSeal);
    els[id]?.addEventListener("change", updateSeal);
  });
  els.sealImageInput?.addEventListener("change", (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      window.alert("画像ファイルを選択してください。");
      return;
    }
    const reader = new FileReader();
    reader.addEventListener("load", () => {
      const settings = loadSettings();
      storeSettings({
        ...settings,
        seal: normalizeSealSettings({
          ...currentSealSettings(),
          enabled: true,
          imageDataUrl: String(reader.result || ""),
        }),
      });
      renderSealSettings();
      renderPreview();
    });
    reader.readAsDataURL(file);
  });
  els.clearSealImageBtn?.addEventListener("click", () => {
    if (!confirmRepeatedDelete("印章画像")) return;
    const settings = loadSettings();
    storeSettings({
      ...settings,
      seal: normalizeSealSettings({
        ...currentSealSettings(),
        imageDataUrl: "",
      }),
    });
    renderSealSettings();
    renderPreview();
  });
  els.sealPositionPad?.addEventListener("click", (event) => {
    const rect = els.sealPositionPad.getBoundingClientRect();
    const x = Math.round(((event.clientX - rect.left) / rect.width) * 210);
    const y = Math.round(((event.clientY - rect.top) / rect.height) * 297);
    const settings = loadSettings();
    storeSettings({
      ...settings,
      seal: normalizeSealSettings({
        ...currentSealSettings(),
        x,
        y,
      }),
    });
    renderSealSettings();
    renderPreview();
  });
  els.printArea?.addEventListener("click", (event) => {
    if (!els.settingsDialog?.open) return;
    const rect = els.printArea.getBoundingClientRect();
    const x = Math.round(((event.clientX - rect.left) / rect.width) * 210);
    const y = Math.round(((event.clientY - rect.top) / rect.height) * 297);
    const settings = loadSettings();
    storeSettings({
      ...settings,
      seal: normalizeSealSettings({
        ...currentSealSettings(),
        x,
        y,
      }),
    });
    renderSealSettings();
    renderPreview();
  });
  els.companyLogoInput?.addEventListener("change", (event) => {
    const file = event.target.files?.[0];
    if (!file) {
      state.pendingCompanyLogo = "";
      renderCompanyLogoSettings();
      return;
    }
    const reader = new FileReader();
    reader.addEventListener("load", () => {
      state.pendingCompanyLogo = String(reader.result || "");
      state.companyLogoMarkedForDeletion = false;
      renderCompanyLogoSettings();
    });
    reader.readAsDataURL(file);
  });
  els.clearCompanyLogoBtn?.addEventListener("click", () => {
    if (!confirmRepeatedDelete("Logo")) return;
    state.pendingCompanyLogo = "";
    state.companyLogoMarkedForDeletion = true;
    state.issuerLogo = "";
    renderCompanyLogoSettings();
    renderPreview();
    setDirty(true);
  });
  els.saveCompanyBtn?.addEventListener("click", () => {
    const existing = defaultCompany() || {};
    const company = companyFromSettingsForm(existing);
    if (!company.name) return;
    saveCompanyRecord(company, { makeDefault: true });
    state.pendingCompanyLogo = "";
    state.companyLogoMarkedForDeletion = false;
    applyCompanyToIssuer(company);
    renderSettings();
    syncProjectSurfaces();
    logOperation({ category: "変更", priority: "通常", assignee: loadSettings().accountName || "自分", memo: `自社情報 ${company.name} を保存` });
  });
  els.inviteStaffBtn?.addEventListener("click", () => {
    const name = els.staffNameInput.value.trim();
    if (!name) return;
    const settings = loadSettings();
    const token = crypto.randomUUID();
    const inviteUrl = `${location.origin}${location.pathname}?invite=${encodeURIComponent(token)}`;
    const staff = [{ id: crypto.randomUUID(), name, role: els.staffRoleInput.value, status: "招待中", inviteToken: token, inviteUrl, invitedAt: new Date().toISOString() }, ...(settings.staff || [])];
    storeSettings({ ...settings, staff });
    els.staffNameInput.value = "";
    renderSettings();
    syncProjectSurfaces();
    logOperation({ category: "招待", priority: "通常", assignee: name, status: "招待中", memo: `${name} に招待リンクを発行` });
  });
  els.staffList?.addEventListener("click", (event) => {
    const copyButton = event.target.closest("[data-copy-invite]");
    if (copyButton) {
      const member = (loadSettings().staff || []).find((item) => item.id === copyButton.dataset.copyInvite);
      if (member?.inviteUrl) navigator.clipboard?.writeText(member.inviteUrl);
      copyButton.textContent = "コピー済み";
      return;
    }
    const button = event.target.closest("[data-remove-staff]");
    if (!button) return;
    if (!confirmRepeatedDelete("社員アカウント")) return;
    const settings = loadSettings();
    storeSettings({ ...settings, staff: (settings.staff || []).filter((member) => member.id !== button.dataset.removeStaff) });
    renderSettings();
    syncProjectSurfaces();
  });
  document.getElementById("openOperationHistoryBtn")?.addEventListener("click", openOperationDialog);
  document.getElementById("openArchiveManagerBtn")?.addEventListener("click", () => {
    renderArchiveTimeline();
    els.archiveDialog?.showModal();
  });
  els.createFormObjectBtn?.addEventListener("click", openArchiveProjectDialog);
  els.archiveSearchInput?.addEventListener("input", renderArchiveTimeline);
  els.newArchiveProjectBtn?.addEventListener("click", openArchiveProjectDialog);
  els.confirmCreateArchiveProjectBtn?.addEventListener("click", createArchiveProject);
  els.archiveProjectCompanySelect?.addEventListener("change", () => {
    if (els.archiveProjectCompanySelect.value) {
      els.archiveProjectCompanyNameInput.value = "";
      els.archiveProjectCompanyAddressInput.value = "";
      els.archiveProjectCompanyContactInput.value = "";
    }
    updateArchiveProjectNamePreview();
  });
  [els.archiveProjectCompanyNameInput, els.archiveProjectCompanyAddressInput, els.archiveProjectCompanyContactInput].forEach((input) => {
    input?.addEventListener("input", () => {
      if (els.archiveProjectCompanyNameInput.value.trim()) els.archiveProjectCompanySelect.value = "";
      updateArchiveProjectNamePreview();
    });
  });
  els.exportSelectedProjectsBtn?.addEventListener("click", async () => {
    const ids = [...els.archiveTimeline.querySelectorAll("[data-project-check]:checked")].map((input) => input.dataset.projectCheck);
    const button = els.exportSelectedProjectsBtn;
    const original = button.textContent;
    button.disabled = true;
    button.textContent = "PDF生成中";
    try {
      await downloadArchiveProjects(buildArchiveProjects().filter((project) => ids.includes(project.id)));
    } catch (error) {
      window.alert(error.message || "PDF ZIP生成に失敗しました。");
    } finally {
      button.disabled = false;
      button.textContent = original;
    }
  });
  els.archiveTimeline?.addEventListener("click", async (event) => {
    const formButton = event.target.closest("[data-project-form]");
    if (formButton) {
      event.stopPropagation();
      await openArchiveProjectForm(formButton.dataset.projectForm, formButton.dataset.formKey);
      return;
    }
    const checkbox = event.target.closest("[data-project-check]");
    if (checkbox) {
      event.stopPropagation();
      return;
    }
    const button = event.target.closest("[data-project-id]");
    if (!button) return;
    state.selectedArchiveProjectId = button.dataset.projectId;
    renderArchiveTimeline();
  });
  els.archiveDetail?.addEventListener("click", async (event) => {
    const deleteProjectButton = event.target.closest("[data-delete-project]");
    if (deleteProjectButton) {
      deleteArchiveProject(deleteProjectButton.dataset.deleteProject);
      return;
    }
    const deleteFormButton = event.target.closest("[data-delete-form]");
    if (deleteFormButton) {
      deleteArchiveForm(deleteFormButton.dataset.deleteForm);
      return;
    }
    const exportButton = event.target.closest("[data-export-project]");
    if (exportButton) {
      const project = archiveProjectById(exportButton.dataset.exportProject);
      if (!project) return;
      const original = exportButton.textContent;
      exportButton.disabled = true;
      exportButton.textContent = "PDF生成中";
      try {
        await downloadArchiveProjects([project]);
      } catch (error) {
        window.alert(error.message || "PDF ZIP生成に失敗しました。");
      } finally {
        exportButton.disabled = false;
        exportButton.textContent = original;
      }
      return;
    }
    const formButton = event.target.closest("[data-project-form]");
    if (!formButton) return;
    await openArchiveProjectForm(formButton.dataset.projectForm, formButton.dataset.formKey);
  });
  els.operationFilterCategory?.addEventListener("change", renderOperationHistory);
  els.operationFilterPriority?.addEventListener("change", renderOperationHistory);
  els.operationSearchInput?.addEventListener("input", renderOperationHistory);
  els.addOperationBtn?.addEventListener("click", () => {
    logOperation({
      category: els.operationCategoryInput.value,
      priority: els.operationPriorityInput.value,
      assignee: els.operationAssigneeInput.value,
      memo: els.operationMemoInput.value.trim(),
      status: els.operationCategoryInput.value === "承認" ? "承認待ち" : "未対応",
    });
    els.operationMemoInput.value = "";
    syncProjectSurfaces();
  });
  els.exportBackupBtn?.addEventListener("click", exportBackup);
  els.exportBackupZipBtn?.addEventListener("click", () => exportBackupZip());
  els.backupToDriveBtn?.addEventListener("click", uploadBackupToDrive);
  els.restoreFromDriveBtn?.addEventListener("click", restoreLatestBackupFromDrive);
  els.importBackupInput?.addEventListener("change", (event) => importBackup(event.target.files?.[0]));
  els.convertDocumentBtn?.addEventListener("click", convertCurrentDocument);
  els.nextStepBtn?.addEventListener("click", () => copyCurrentDocumentAs(els.conversionTarget?.value));
  els.templateSelect?.addEventListener("change", () => {
    state.templateId = els.templateSelect.value;
    renderPreview();
    setDirty(true);
  });
  els.templatePalette?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-template-id]");
    if (!button) return;
    state.templateId = button.dataset.templateId;
    if (els.templateSelect) els.templateSelect.value = state.templateId;
    renderPreview();
    setDirty(true);
  });

  document.getElementById("loadCustomerBtn").addEventListener("click", () => {
    renderCustomerMaster();
    els.customerDialog.showModal();
  });

  [els.customerName, els.customerAddress, els.customerContact, els.customerEmail].forEach((input) => {
    input?.addEventListener("input", () => {
      renderCompanyOptions();
      applySmartCustomerFromInput(input);
    });
    input?.addEventListener("change", () => applySmartCustomerFromInput(input));
  });

  document.getElementById("loadIssuerBtn").addEventListener("click", () => {
    for (const [key, value] of Object.entries(SAMPLE_ISSUER)) els[key].value = value;
    saveCompanyRecord({
      name: SAMPLE_ISSUER.issuerName,
      registration: SAMPLE_ISSUER.issuerRegistration,
      address: SAMPLE_ISSUER.issuerAddress,
      contact: SAMPLE_ISSUER.issuerContact,
      phone: SAMPLE_ISSUER.issuerPhone,
      email: SAMPLE_ISSUER.issuerEmail,
    });
    renderPreview();
    setDirty(true);
  });
  [els.issuerName, els.issuerRegistration, els.issuerAddress, els.issuerContact, els.issuerPhone, els.issuerEmail].forEach((input) => {
    input?.addEventListener("input", () => {
      renderCompanyOptions();
      applySmartCompanyFromInput(input);
    });
    input?.addEventListener("change", () => applySmartCompanyFromInput(input));
  });

  document.getElementById("saveCustomerBtn")?.addEventListener("click", () => {
    const doc = getFormData();
    if (!doc.customerName) return;
    const existing = loadCustomers().find((customer) => customer.companyName === doc.customerName) || {};
    saveCustomerRecord({
      ...existing,
      companyName: doc.customerName,
      companyAddress: doc.customerAddress,
      email: doc.customerEmail || existing.email || "",
      contactName: doc.customerContact,
    });
  });

  document.getElementById("openCustomerMasterBtn")?.addEventListener("click", () => {
    renderCustomerMaster();
    els.customerDialog.showModal();
  });

  els.customerSearchInput?.addEventListener("input", renderCustomerMaster);
  els.newCustomerBtn?.addEventListener("click", () => openCustomerEdit(null));
  els.editCustomerBtn?.addEventListener("click", () => openCustomerEdit(selectedCustomer()));
  els.cancelCustomerEditBtn?.addEventListener("click", () => renderCustomerDetail(selectedCustomer()));
  els.applyCustomerBtn?.addEventListener("click", () => {
    applyCustomerToDocument(selectedCustomer());
    els.customerDialog.close();
  });
  els.saveCustomerDetailBtn?.addEventListener("click", () => {
    const existing = selectedCustomer() || {};
    const customer = customerFromEditForm(existing);
    if (!customer.companyName) return;
    saveCustomerRecord(customer);
  });
  els.deleteCustomerBtn?.addEventListener("click", () => {
    const customer = selectedCustomer();
    if (!customer) return;
    if (!confirmRepeatedDelete(`取引先 ${customer.companyName || ""}`.trim())) return;
    storeCustomers(loadCustomers().filter((item) => item.id !== customer.id));
    state.selectedCustomerId = "";
    syncProjectSurfaces();
  });

  document.getElementById("openItemMasterBtn")?.addEventListener("click", () => {
    renderItemMaster();
    els.itemDialog.showModal();
  });

  [els.itemNameInput, els.itemModelInput, els.itemSpecInput].forEach((input) => {
    input?.addEventListener("input", () => applySmartItemMasterFromInput(input));
    input?.addEventListener("change", () => applySmartItemMasterFromInput(input));
  });

  document.getElementById("saveItemBtn")?.addEventListener("click", () => {
    const name = els.itemNameInput.value.trim();
    if (!name) return;
    const items = readStore(ITEM_KEY, []).map(normalizeItem);
    const record = {
      id: crypto.randomUUID(),
      name,
      model: els.itemModelInput.value.trim(),
      specification: els.itemSpecInput?.value.trim() || "",
      unitPrice: Number(els.itemPriceInput.value || 0),
    };
    writeStore(ITEM_KEY, [record, ...items.filter((item) => item.name !== name && item.model !== record.model)].slice(0, 50));
    els.itemNameInput.value = "";
    els.itemModelInput.value = "";
    if (els.itemSpecInput) els.itemSpecInput.value = "";
    els.itemPriceInput.value = "";
    syncProjectSurfaces();
  });

  if (els.docTypeSelect) {
    els.docTypeSelect.innerHTML = Object.entries(DOC_TYPES)
      .map(([type, config]) => `<option value="${type}">${config.title} / ${config.subtitle}</option>`)
      .join("");
    els.docTypeSelect.addEventListener("change", async () => {
      await switchDocType(els.docTypeSelect.value);
      setMobileView("form");
    });
  }

  if (els.docTypeOptions) {
    els.docTypeOptions.innerHTML = Object.entries(DOC_TYPES)
      .map(([type, config]) => `
        <button class="doc-type-option" type="button" data-doc-type-option="${type}" aria-pressed="false">
          <strong>${config.title}</strong>
          <span>${config.subtitle}</span>
        </button>
      `)
      .join("");
    els.docTypeOptions.querySelectorAll("[data-doc-type-option]").forEach((button) => {
      button.addEventListener("click", async () => {
        await switchDocType(button.dataset.docTypeOption);
        setMobileView("form");
      });
    });
  }

  document.getElementById("copyJsonBtn")?.addEventListener("click", async () => {
    const button = document.getElementById("copyJsonBtn");
    const original = button?.textContent || "";
    if (button) {
      button.disabled = true;
      button.textContent = "PDF生成中";
    }
    try {
      await exportPdf();
    } catch (error) {
      console.error("pdf preview failed", error);
      window.alert(error.message || "PDFプレビューに失敗しました。");
    } finally {
      if (button) {
        button.disabled = false;
        button.textContent = original;
      }
    }
  });
}

function init() {
  syncNativeAppChrome();
  installDialogPageNavigation();
  bindElements();
  seedItems();
  migrateItems();
  ensureNiixCompany();
  simplifyInputLabels();
  bindEvents();
  bindMobileActionBarStability();
  setMobileView("menu");
  setFormData(documentFromUrl() || defaultDocument("invoice"));
  acceptInviteFromUrl();
}

init();
