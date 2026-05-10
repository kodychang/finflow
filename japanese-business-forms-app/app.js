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
    title: "注文書",
    subtitle: "Order",
    pageTitle: "注文書作成",
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

const DEFAULT_SEAL_SETTINGS = {
  enabled: true,
  text: "承認済",
  appearance: "solid",
  shape: "square",
  style: "style_1",
  font: "gyoshotai",
  border: "double",
  effect: "ink",
  color: "#d00000",
  colorPreset: "#d00000",
  textColor: "#ffffff",
  sizePreset: "medium",
  width: 96,
  height: 96,
  radius: 6,
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
  { type: "order", label: "注文 / 発注", note: "顧客注文と仕入発注", alternates: ["purchaseOrder"] },
  { type: "delivery", label: "納品", note: "出荷・納品記録" },
  { type: "invoice", label: "請求", note: "振込先と支払期限" },
  { type: "receipt", label: "領収", note: "入金後の証憑" },
];

const COPY_TARGETS = ["estimate", "order", "purchaseOrder", "delivery", "invoice", "receipt", "acceptance"];

const REFERENCE_TYPES = Object.fromEntries(
  Object.keys(DOC_TYPES).map((type) => [type, Object.keys(DOC_TYPES).filter((candidate) => candidate !== type)]),
);

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
    partySection: "注文先",
    partyName: "注文先会社名 / 氏名",
    issuerSection: "注文者",
    transactionLabel: "注文日",
    dueLabel: "希望納期",
    secondaryLabel: "支払方法",
    specificsLabel: "注文条件",
    totalLabel: "注文金額",
    lead: "下記の通り、注文いたします。",
    notesPlaceholder: "注文時の注意事項、検収条件など",
    secondaryPlaceholder: "例: 銀行振込 / 請求書払い",
    specificsPlaceholder: "例: 納品希望日、分納可否、注文条件",
    defaultNotes: "上記の内容をご確認の上、注文をお願いいたします。",
    defaultSpecifics: "注文内容、納期、支払方法を確認してください。",
  },
  purchaseOrder: {
    partySection: "発注先",
    partyName: "発注先会社名 / 氏名",
    issuerSection: "発注者",
    transactionLabel: "発注日",
    dueLabel: "納期",
    secondaryLabel: "発注条件",
    specificsLabel: "購買条件",
    totalLabel: "発注金額",
    lead: "下記の通り、発注いたします。",
    notesPlaceholder: "発注条件、検収、キャンセル条件など",
    secondaryPlaceholder: "例: 検収後月末締め翌月末払い",
    specificsPlaceholder: "例: 調達条件、納入場所、検収条件",
    defaultNotes: "発注内容をご確認の上、手配をお願いいたします。",
    defaultSpecifics: "発注条件、納入場所、検収条件を確認してください。",
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
};

const BUILT_IN_TEMPLATES = [
  { id: "monochrome", name: "日本帳票", style: "monochrome", accent: "#2f3744", builtin: true },
  { id: "corporate", name: "企業標準", style: "corporate", accent: "#0d6b68", builtin: true },
  { id: "ledger", name: "明細表", style: "ledger", accent: "#5f7f99", builtin: true },
  { id: "indigo", name: "藍色罫線", style: "indigo", accent: "#2f4f8f", builtin: true },
  { id: "sepia", name: "薄茶罫線", style: "sepia", accent: "#8a633a", builtin: true },
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
  templateId: "monochrome",
  sourceDocumentId: "",
  sourceDocumentNumber: "",
  sourceDocumentType: "",
  relatedFormIds: [],
  relatedDocumentNumbers: {},
  convertedDocumentIds: [],
  selectedCustomerId: "",
  lines: [],
  notices: [],
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
};

const els = {};

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

function showsPrices(type = state.docType) {
  return !["order", "delivery"].includes(type);
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

function applyCustomerToDocument(customer) {
  if (!customer) return;
  els.customerName.value = customer.companyName || "";
  els.customerAddress.value = customer.companyAddress || "";
  els.customerContact.value = customerDisplayContact(customer);
  renderPreview();
  setDirty(true);
}

function seedItems() {
  if (readStore(ITEM_KEY, []).length) return;
  writeStore(ITEM_KEY, [
    { id: crypto.randomUUID(), name: "智慧ミラー", model: "SM-GLASS-42", unitPrice: 98000 },
    { id: crypto.randomUUID(), name: "Webサイト制作 一式", model: "WEB-PROD", unitPrice: 180000 },
    { id: crypto.randomUUID(), name: "保守サポート 月額", model: "SUPPORT-M", unitPrice: 30000 },
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
  const count = loadDocuments().filter((doc) => doc.docType === type).length + 1;
  const ymd = today().replaceAll("-", "");
  return `${DOC_TYPES[type]?.prefix || "DOC"}-${ymd}-${String(count).padStart(3, "0")}`;
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
    relatedFormIds,
    relatedDocumentNumbers: { ...(doc.relatedDocumentNumbers || {}) },
    convertedDocumentIds: compactUnique(doc.convertedDocumentIds || []),
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

function referenceEntries(doc = {}, options = {}) {
  const numbers = collectDocumentNumbers(doc);
  const types = options.includeCurrent ? FLOW_STEPS.flatMap((step) => [step.type, ...(step.alternates || [])]) : REFERENCE_TYPES[doc.docType] || [];
  let entries = types
    .filter((type) => type !== doc.docType && numbers[type])
    .map((type) => ({ type, title: DOC_TYPES[type]?.title || "帳票", number: numbers[type] }));
  if (!entries.length) {
    entries = Object.entries(numbers)
      .filter(([type, number]) => type !== doc.docType && number)
      .map(([type, number]) => ({ type, title: DOC_TYPES[type]?.title || "帳票", number }));
  }
  if (!entries.length && doc.sourceDocumentType && doc.sourceDocumentNumber) {
    entries.push({
      type: doc.sourceDocumentType,
      title: DOC_TYPES[doc.sourceDocumentType]?.title || "帳票",
      number: doc.sourceDocumentNumber,
    });
  }
  return entries;
}

function formatReferenceEntries(entries) {
  return entries.map((entry) => `${entry.title} ${entry.number}`).join(" / ");
}

function documentReferenceText(doc) {
  const refs = referenceEntries(doc);
  return refs.length ? ` / 関連: ${formatReferenceEntries(refs)}` : "";
}

function defaultDocument(type = state.docType) {
  const definition = formDefinition(type);
  return {
    id: crypto.randomUUID(),
    projectId: "",
    projectName: "",
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
    customRelatedNumber: "",
    showRelatedNumber: true,
    convertedDocumentIds: [],
    notices: [],
    lines: [
      { id: crypto.randomUUID(), name: "智慧ミラー", model: "SM-GLASS-42", specification: "42インチ / Android OS / 壁掛け金具付き", quantity: 10, unitPrice: 98000 },
    ],
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
  return {
    id: state.currentId,
    projectId: state.projectId || "",
    projectName: state.projectName || "",
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
      ...(state.sourceDocumentType && state.sourceDocumentNumber ? { [state.sourceDocumentType]: state.sourceDocumentNumber } : {}),
    },
    customRelatedNumber: els.customRelatedNumber?.value.trim() || "",
    showRelatedNumber: els.showRelatedNumber ? els.showRelatedNumber.checked : true,
    convertedDocumentIds: [...(state.convertedDocumentIds || [])],
    notices: [...(state.notices || [])],
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
  const docType = DOC_TYPES[doc.docType] ? doc.docType : "invoice";
  state.currentId = doc.id;
  state.projectId = doc.projectId || "";
  state.projectName = doc.projectName || "";
  state.docType = docType;
  state.templateId = doc.templateId || state.templateId || "monochrome";
  state.sourceDocumentId = doc.sourceDocumentId || "";
  state.sourceDocumentNumber = doc.sourceDocumentNumber || "";
  state.sourceDocumentType = doc.sourceDocumentType || "";
  state.relatedFormIds = compactUnique(doc.relatedFormIds || []).filter((id) => id !== doc.id);
  state.relatedDocumentNumbers = { ...(doc.relatedDocumentNumbers || {}) };
  state.convertedDocumentIds = Array.isArray(doc.convertedDocumentIds) ? doc.convertedDocumentIds : [];
  state.notices = Array.isArray(doc.notices) ? doc.notices : [];
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
    "customRelatedNumber",
    "customerName",
    "customerAddress",
    "customerContact",
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
  if (els.customRelatedNumber) els.customRelatedNumber.value = doc.customRelatedNumber || "";

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
  if (!String(doc.docNumber || "").trim()) issues.push({ id: "docNumber", message: "帳票番号が未入力", field: "docNumber" });
  if (!String(doc.customerName || "").trim()) issues.push({ id: "customerName", message: `${definition.partySection || "取引先"}が未入力`, field: "customerName" });
  if (!String(doc.issuerName || "").trim()) issues.push({ id: "issuerName", message: `${definition.issuerSection || "発行者"}が未入力`, field: "issuerName" });
  if (!String(doc.issueDate || "").trim()) issues.push({ id: "issueDate", message: "発行日が未入力", field: "issueDate" });
  if (!String(doc.dueDate || "").trim()) issues.push({ id: "dueDate", message: `${definition.dueLabel || "期限"}が未入力`, field: "dueDate" });
  if (!doc.lines?.length || doc.lines.every((line) => !String(line.name || "").trim())) issues.push({ id: "lineItems", message: "明細が未入力", field: "lineItems" });
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
    const control = label.querySelector(":scope > input:not([type='checkbox']):not([type='file']):not([type='color']), :scope > textarea");
    if (!control) return;
    const title = simplifiedFieldTitle(label);
    const text = labelTitleText(label) || control.getAttribute("aria-label") || control.name || control.id;
    if (title && !title.dataset.defaultLabel) title.dataset.defaultLabel = text;
    if (text) control.placeholder = text;
    label.classList.add("simplified-field");
  });
}

function updateSimplifiedPlaceholders(root = document) {
  root.querySelectorAll("label.simplified-field").forEach((label) => {
    const control = label.querySelector(":scope > input:not([type='checkbox']):not([type='file']):not([type='color']), :scope > textarea");
    if (!control) return;
    const title = label.querySelector(":scope > .input-title, :scope > span[id$='Label']");
    const text = title?.dataset.defaultLabel || title?.textContent?.trim() || labelTitleText(label);
    if (text) {
      control.placeholder = text;
      if (title) title.dataset.defaultLabel = text;
    }
  });
  updatePrefixedFields();
}

function updatePrefixedFields() {
  ["docNumber", "issueDate", "transactionDate", "dueDate", "customRelatedNumber"].forEach((fieldId) => {
    const control = els[fieldId] || document.getElementById(fieldId);
    const label = control?.closest("label");
    if (!control || !label) return;
    const title = label.querySelector(":scope > .input-title, :scope > span[id$='Label']");
    const text = title?.dataset.defaultLabel || title?.textContent?.trim() || labelTitleText(label);
    if (!text) return;
    const isDate = control.type === "date";
    label.classList.toggle("date-prefixed-field", isDate);
    label.classList.toggle("input-prefixed-field", !isDate);
    label.dataset.fieldPrefix = text;
    delete label.dataset.datePrefix;
    control.placeholder = isDate ? `${text} YYYY/MM/DD` : text;
    control.title = text;
    control.setAttribute("aria-label", text);
    control.style.setProperty("--field-prefix-width", `${Math.max(58, text.length * 14 + 18)}px`);
  });
}

function clearFieldIssueTitles(root = document) {
  root.querySelectorAll("label.simplified-field").forEach((label) => {
    const control = label.querySelector(":scope > input, :scope > textarea");
    const title = label.querySelector(":scope > .input-title, :scope > span[id$='Label']");
    label.classList.remove("has-field-issue");
    if (title) title.textContent = "";
    if (control) control.removeAttribute("aria-invalid");
  });
  document.querySelectorAll(".line-table th.has-field-issue").forEach((heading) => {
    heading.textContent = heading.dataset.defaultLabel || heading.textContent;
    heading.classList.remove("has-field-issue");
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
    els.lineItems?.querySelectorAll("input").forEach((input) => input.setAttribute("aria-invalid", "true"));
    return;
  }

  const control = els[fieldId] || document.getElementById(fieldId);
  const label = control?.closest("label");
  if (!control || !label) return;
  const title = simplifiedFieldTitle(label);
  label.classList.add("simplified-field", "has-field-issue");
  if (title) title.textContent = message;
  control.setAttribute("aria-invalid", "true");
}

function renderFieldIssues(doc = getFormData()) {
  clearFieldIssueTitles();
  documentIssueItems(doc).forEach((issue) => showFieldIssue(issue.field, issue.message));
}

function relatedFlowDocuments(currentDoc = getFormData()) {
  const docs = loadDocuments();
  const ids = new Set([
    currentDoc.id,
    currentDoc.sourceDocumentId,
    ...(currentDoc.convertedDocumentIds || []),
    ...(currentDoc.relatedFormIds || []),
  ].filter(Boolean));
  const numbers = new Set([currentDoc.docNumber, currentDoc.sourceDocumentNumber, ...Object.values(currentDoc.relatedDocumentNumbers || {})].filter(Boolean));
  const projectIds = new Set([currentDoc.projectId].filter(Boolean));
  let changed = true;
  while (changed) {
    changed = false;
    docs.forEach((doc) => {
      const docNumbers = [doc.docNumber, doc.sourceDocumentNumber, ...Object.values(doc.relatedDocumentNumbers || {})].filter(Boolean);
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
        [doc.docNumber, doc.sourceDocumentNumber, ...Object.values(doc.relatedDocumentNumbers || {})].some((number) => numbers.has(number)) ||
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
  return ARCHIVE_FORM_TYPES.find((entry) => entry.types.includes(type))?.key || type;
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
      const key = archiveFormKey(item.docType);
      if (!formMap[key] || String(item.updatedAt || "").localeCompare(String(formMap[key].updatedAt || "")) > 0) {
        formMap[key] = item;
      }
    });
    const archiveDate = allDocs.map(docArchiveDate).sort().at(-1) || today();
    const latestUpdatedAt = sorted[0]?.updatedAt || `${archiveDate}T00:00:00.000Z`;
    projects.push({
      id: projectId,
      projectName: primaryDoc.projectName || "",
      companyName: primaryDoc.issuerName || defaultCompany()?.name || NIIX_COMPANY_NAME,
      customerName: primaryDoc.customerName || "",
      date: archiveDate,
      week: weekStart(archiveDate),
      latestUpdatedAt,
      primaryDoc,
      docs: allDocs,
      formMap,
      completed: ARCHIVE_FORM_TYPES.filter((entry) => formMap[entry.key]).length,
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
  return ARCHIVE_FORM_TYPES.map((entry) => {
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
                <small>${project.completed}/5</small>
              </div>
              <span>${escapeHtml(project.customerName || "取引先未入力")} / ${escapeHtml(formatDate(project.date))}</span>
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
        <span>${escapeHtml(project.customerName || "取引先未入力")} / ${escapeHtml(formatDate(project.date))}</span>
      </div>
      <div class="archive-detail-actions">
        <button class="secondary-button" type="button" data-export-project="${escapeHtml(project.id)}">ZIP</button>
        <button class="secondary-button danger-button" type="button" data-delete-project="${escapeHtml(project.id)}">项目削除</button>
      </div>
    </div>
    <div class="archive-form-list">
      ${ARCHIVE_FORM_TYPES.map((entry) => {
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
  const entry = ARCHIVE_FORM_TYPES.find((item) => item.key === formKey);
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
  const targetType = entry.types[0];
  const source = project.primaryDoc || project.docs[0] || defaultDocument(targetType);
  const next = buildConvertedDocument(source, targetType);
  next.projectId = project.id.startsWith("legacy-") ? crypto.randomUUID() : project.id;
  next.projectName = projectDisplayName(project);
  next.docType = targetType;
  next.docNumber = nextDocNumber(targetType);
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
  const projectId = crypto.randomUUID();
  const doc = defaultDocument("estimate");
  doc.projectId = projectId;
  doc.projectName = archiveProjectNameForCompany(savedCompany.companyName);
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
  if (els.lineItemsHead) {
    els.lineItemsHead.innerHTML = hasPrices
      ? `<tr><th>品目</th><th>型番</th><th>仕様</th><th>数量</th><th>単価</th><th></th></tr>`
      : `<tr><th>品目</th><th>型番</th><th>仕様</th><th>数量</th><th></th></tr>`;
  }
  state.lines.forEach((line) => {
    const tr = document.createElement("tr");
    tr.innerHTML = hasPrices
      ? `
      <td><input class="item-name" data-field="name" data-id="${line.id}" type="text" value="${escapeHtml(line.name)}" placeholder="品目" /></td>
      <td><input class="item-model" data-field="model" data-id="${line.id}" type="text" value="${escapeHtml(line.model || "")}" placeholder="型番" /></td>
      <td><input class="item-spec" data-field="specification" data-id="${line.id}" type="text" value="${escapeHtml(line.specification || "")}" placeholder="仕様" /></td>
      <td><input data-field="quantity" data-id="${line.id}" type="number" min="0" step="0.01" value="${line.quantity}" placeholder="数量" /></td>
      <td><input data-field="unitPrice" data-id="${line.id}" type="number" min="0" step="1" value="${line.unitPrice}" placeholder="単価" /></td>
      <td><button class="remove-line" data-remove="${line.id}" type="button" aria-label="行を削除">x</button></td>
    `
      : `
      <td><input class="item-name" data-field="name" data-id="${line.id}" type="text" value="${escapeHtml(line.name)}" placeholder="品目" /></td>
      <td><input class="item-model" data-field="model" data-id="${line.id}" type="text" value="${escapeHtml(line.model || "")}" placeholder="型番" /></td>
      <td><input class="item-spec" data-field="specification" data-id="${line.id}" type="text" value="${escapeHtml(line.specification || "")}" placeholder="仕様" /></td>
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

function renderPreview() {
  const doc = getFormData();
  const config = DOC_TYPES[doc.docType] || DOC_TYPES.invoice;
  const definition = formDefinition(doc.docType);
  const sum = totals(doc);
  const hasPrices = showsPrices(doc.docType);

  applyTemplate();
  els.printArea?.classList.toggle("no-prices", !hasPrices);
  els.documentForm?.classList.toggle("no-prices", !hasPrices);
  if (els.taxRate) els.taxRate.closest("label").hidden = !hasPrices;
  renderFormDefinition(definition, config);
  els.pageTitle.textContent = config.pageTitle;
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
  els.previewCustomerContact.textContent = doc.customerContact;
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
  if (els.invoiceBadge) els.invoiceBadge.hidden = !doc.issuerRegistration;
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
  renderFieldIssues(doc);
  renderFlowSidebar();
  schedulePreviewSnapshot();
}

function shouldRasterizePreview() {
  return Boolean(window.matchMedia?.("(max-width: 1920px)").matches);
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
    image.onload = resolve;
    image.onerror = reject;
    image.src = url;
  });
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
  if (document.body.dataset.mobileView && document.body.dataset.mobileView !== "preview") return;

  const token = ++state.previewSnapshotToken;
  els.previewPngFrame.classList.add("is-rendering");
  try {
    const response = await fetch("/api/preview-png", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(buildDocumentRenderPayload()),
    });
    if (!response.ok) throw new Error(await response.text() || "PNGプレビュー生成に失敗しました。");
    const pngUrl = URL.createObjectURL(await response.blob());
    await waitForImageLoad(pngUrl);
    if (token !== state.previewSnapshotToken) {
      URL.revokeObjectURL(pngUrl);
      return;
    }
    if (state.previewSnapshotUrl) URL.revokeObjectURL(state.previewSnapshotUrl);
    state.previewSnapshotUrl = pngUrl;
    els.previewPngImage.src = pngUrl;
    syncPreviewRasterMode(true);
  } catch (error) {
    console.warn("preview png render failed", error);
    if (!els.previewPngImage.src) syncPreviewRasterMode(false);
  } finally {
    if (token === state.previewSnapshotToken) {
      els.previewPngFrame.classList.remove("is-rendering");
    }
  }
}

function schedulePreviewSnapshot() {
  window.clearTimeout(state.previewSnapshotTimer);
  state.previewSnapshotTimer = window.setTimeout(renderPreviewPng, 120);
}

function syncRelatedNumberVisibility(doc = getFormData()) {
  if (!els.previewSourceRow || !els.previewSource) return;
  const refs = referenceEntries(doc);
  const custom = String(doc.customRelatedNumber || "").trim();
  const text = [refs.length ? formatReferenceEntries(refs) : "", custom].filter(Boolean).join(" / ");
  const shouldShow = Boolean(doc.showRelatedNumber);
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
    partySectionTitle: definition.partySection,
    partyNameLabel: definition.partyName,
    partyAddressLabel: `${definition.partySection}住所`,
    partyContactLabel: `${definition.partySection}担当者`,
    issuerSectionTitle: definition.issuerSection,
    notesLabel: "備考",
    bankDetailsLabel: definition.secondaryLabel,
    documentSpecificsLabel: definition.specificsLabel,
    previewNumberLabel: "番号",
    previewIssueDateLabel: "発行日",
    previewTransactionDateLabel: definition.transactionLabel,
    previewDueDateLabel: definition.dueLabel,
    previewSourceLabel: "関連番号",
    customRelatedNumberLabel: "関連番号",
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
  if (els.notes) els.notes.placeholder = definition.notesPlaceholder;
  if (els.bankDetails) els.bankDetails.placeholder = definition.secondaryPlaceholder;
  if (els.documentSpecifics) els.documentSpecifics.placeholder = definition.specificsPlaceholder;
  updateSimplifiedPlaceholders();
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
  if (source.docType === "estimate" && targetType === "order") return `${sourceInfo}の内容に基づき注文書を作成しました。必要に応じて発注条件を追記してください。`;
  if (source.docType === "order" && targetType === "delivery") return `${sourceInfo}の注文内容に基づき納品書を作成しました。物流情報を追記してください。`;
  if (source.docType === "delivery" && targetType === "invoice") return `${sourceInfo}の納品内容に基づき請求書を作成しました。請求条件を確認してください。`;
  if (targetType === "receipt") return `${sourceInfo}に対する領収として発行します。`;
  if (targetType === "invoice") return `${sourceInfo}から請求書へ変換しました。`;
  if (targetType === "order") return `${sourceInfo}に基づき注文します。`;
  return `${sourceInfo}から変換しました。`;
}

function buildConvertedDocument(source, targetType) {
  const relatedDocumentNumbers = {
    ...(source.relatedDocumentNumbers || {}),
    ...(source.sourceDocumentType && source.sourceDocumentNumber ? { [source.sourceDocumentType]: source.sourceDocumentNumber } : {}),
    [source.docType]: source.docNumber,
  };
  const newId = crypto.randomUUID();
  return {
    ...source,
    id: newId,
    formObjectId: newId,
    objectType: "form",
    schemaVersion: FORM_OBJECT_SCHEMA_VERSION,
    projectId: source.projectId || "",
    projectName: source.projectName || "",
    docType: targetType,
    docNumber: nextDocNumber(targetType),
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
    convertedDocumentIds: [],
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

async function openFlowDocument(type) {
  const doc = getFormData();
  if (type === doc.docType) return;
  const related = relatedFlowDocuments(doc);
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
      const haystack = [doc.docNumber, DOC_TYPES[doc.docType]?.title, doc.customerName, doc.sourceDocumentNumber, ...Object.values(doc.relatedDocumentNumbers || {})].join(" ").toLowerCase();
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
  const text = String(settings.text || DEFAULT_SEAL_SETTINGS.text).replace(/\s+/g, "").slice(0, 12);
  const preset = SEAL_SIZE_PRESETS[settings.sizePreset] ? settings.sizePreset : "custom";
  const presetSize = SEAL_SIZE_PRESETS[preset] || {};
  const widthSource = presetSize.width || settings.width || settings.size || DEFAULT_SEAL_SETTINGS.width;
  const heightSource = presetSize.height || settings.height || settings.size || DEFAULT_SEAL_SETTINGS.height;
  const width = Math.min(180, Math.max(48, Number(widthSource)));
  const height = Math.min(180, Math.max(48, Number(heightSource)));
  const opacity = Math.min(1, Math.max(0.6, Number(settings.opacity || DEFAULT_SEAL_SETTINGS.opacity)));
  const radius = Math.min(48, Math.max(0, Number(settings.radius ?? DEFAULT_SEAL_SETTINGS.radius)));
  const appearance = settings.appearance || DEFAULT_SEAL_SETTINGS.appearance;
  const color = settings.color || settings.colorPreset || DEFAULT_SEAL_SETTINGS.color;
  return {
    ...DEFAULT_SEAL_SETTINGS,
    ...settings,
    enabled: settings.enabled !== false,
    text,
    appearance,
    color,
    colorPreset: settings.colorPreset || color,
    textColor: settings.textColor || (appearance === "solid" ? "#ffffff" : color),
    width,
    height,
    sizePreset: preset,
    radius,
    opacity,
    rotation: Math.min(8, Math.max(-8, Number(settings.rotation || DEFAULT_SEAL_SETTINGS.rotation))),
  };
}

function currentSealSettings() {
  return normalizeSealSettings(loadSettings().seal || {});
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
  if (!settings.enabled) return "";
  const chars = Array.from(settings.text || "印");
  const grid = sealGridFor(settings, chars.length);
  const longestAxis = Math.max(grid.columns, grid.rows, 1);
  const width = Number(options.width || settings.width);
  const height = Number(options.height || settings.height);
  const unit = Math.min(width, height);
  const fontSize = Math.max(8, Math.floor((unit * 0.58) / longestAxis));
  const family = SEAL_FONT_FAMILIES[settings.font] || "Noto Serif JP";
  const isSolid = settings.appearance === "solid";
  const isOutline = settings.appearance === "outline";
  const borderWidth = Math.max(1, Math.round(unit * (settings.border === "thick" ? 0.08 : settings.border === "thin" ? 0.035 : 0.055)));
  const fallbackBackground = isSolid ? settings.color : "transparent";
  const fallbackBorder = isSolid ? "0" : `${borderWidth}px ${settings.border === "broken" ? "dashed" : "solid"} ${settings.color}`;
  const className = [
    "inkantan-seal",
    `inkantan-seal-appearance-${settings.appearance}`,
    `inkantan-seal-${settings.shape}`,
    `inkantan-seal-border-${settings.border}`,
    `inkantan-seal-effect-${settings.effect}`,
  ].join(" ");
  const style = [
    `--seal-width:${width}px`,
    `--seal-height:${height}px`,
    `--seal-unit:${unit}px`,
    `--seal-color:${settings.color}`,
    `--seal-text-color:${settings.textColor}`,
    `--seal-radius:${settings.radius}px`,
    `--seal-opacity:${settings.opacity}`,
    `--seal-rotation:${settings.rotation}deg`,
    `--seal-cols:${grid.columns}`,
    `--seal-rows:${grid.rows}`,
    `--seal-font-size:${fontSize}px`,
    `font-family:&quot;${escapeHtml(family)}&quot;,&quot;Noto Serif JP&quot;,serif`,
    `width:${width}px`,
    `height:${height}px`,
    `background-color:${fallbackBackground}`,
    `color:${settings.textColor}`,
    `border:${fallbackBorder}`,
    `border-radius:${settings.shape === "round" ? "999px" : settings.shape === "oval" ? "50%" : `${settings.radius}px`}`,
    `opacity:${settings.appearance === "faded" ? Math.min(settings.opacity, 0.78) : settings.opacity}`,
    `transform:rotate(${settings.rotation}deg)`,
  ].join(";");
  const cellStyle = `font-size:${fontSize}px;grid-template-columns:repeat(${grid.columns},minmax(0,1fr));grid-template-rows:repeat(${grid.rows},minmax(0,1fr));`;
  return `<div class="${className}" style="${style}" data-pdf-appearance="${isOutline ? "outline" : isSolid ? "solid" : "faded"}" aria-label="印章 ${escapeHtml(settings.text)}"><span data-flow="${grid.flow}" style="${cellStyle}">${chars.map((part) => `<i>${escapeHtml(part)}</i>`).join("")}</span></div>`;
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
  if (els.sealTextInput) els.sealTextInput.value = settings.text;
  if (els.sealAppearanceInput) els.sealAppearanceInput.value = settings.appearance;
  if (els.sealShapeInput) els.sealShapeInput.value = settings.shape;
  if (els.sealStyleInput) els.sealStyleInput.value = settings.style;
  if (els.sealFontInput) els.sealFontInput.value = settings.font;
  if (els.sealBorderInput) els.sealBorderInput.value = settings.border;
  if (els.sealEffectInput) els.sealEffectInput.value = settings.effect;
  if (els.sealColorPresetInput) els.sealColorPresetInput.value = ["#d00000", "#9f1010", "#e34222"].includes(settings.colorPreset) ? settings.colorPreset : "custom";
  if (els.sealColorInput) els.sealColorInput.value = settings.color;
  if (els.sealTextColorInput) els.sealTextColorInput.value = settings.textColor;
  if (els.sealSizePresetInput) els.sealSizePresetInput.value = settings.sizePreset;
  if (els.sealWidthInput) els.sealWidthInput.value = settings.width;
  if (els.sealHeightInput) els.sealHeightInput.value = settings.height;
  if (els.sealRadiusInput) els.sealRadiusInput.value = String(settings.radius);
  if (els.sealOpacityInput) els.sealOpacityInput.value = settings.opacity;
  if (els.sealRotationInput) els.sealRotationInput.value = settings.rotation;
  syncSealSurfaces(settings);
}

function syncSealSurfaces(settings = currentSealSettings()) {
  const markup = buildSealMarkup(settings);
  if (els.sealSettingsPreview) els.sealSettingsPreview.innerHTML = markup;
  if (els.previewSeal) els.previewSeal.innerHTML = markup;
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
      .map((company) => `<option value="${escapeHtml(company.name)}">${escapeHtml([company.contact, company.phone, company.email].filter(Boolean).join(" / "))}</option>`)
      .join("");
  }
  if (els.customerOptions) {
    els.customerOptions.innerHTML = loadCustomers()
      .map((customer) => `<option value="${escapeHtml(customer.companyName)}">${escapeHtml(customerDisplayContact(customer))}</option>`)
      .join("");
  }
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
  const filename = `${safeFilename(doc.docNumber || doc.id)}-${safeFilename(DOC_TYPES[doc.docType]?.title || doc.docType)}.pdf`;
  const endpoint = location.protocol === "file:" ? "http://localhost:4180/api/pdf-file" : `${location.origin}/api/pdf-file`;
  const payload = buildArchivePdfPayload(doc, { title, filename });
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await response.text() || "PDF生成に失敗しました。");
  const pdfFile = await response.json();
  const pdfResponse = await fetch(pdfFile.downloadUrl || pdfFile.inlineUrl);
  if (!pdfResponse.ok) throw new Error("生成済みPDFを取得できませんでした。");
  return {
    name: `${base}${filename}`,
    content: await pdfResponse.arrayBuffer(),
  };
}

async function archiveProjectPdfFiles(project) {
  const base = `${safeFilename(projectDisplayName(project))}/`;
  const files = [];
  for (const doc of project.docs) {
    files.push(await archivePdfFile(doc, base));
  }
  files.push({
    name: `${base}project-index.json`,
    content: JSON.stringify({
      projectId: project.id,
      projectName: projectDisplayName(project),
      companyName: archiveCompanyName(project),
      customerName: project.customerName,
      date: project.date,
      forms: ARCHIVE_FORM_TYPES.map((entry) => ({
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
  const doc = normalizeFormObject({
    ...getFormData(),
    projectId: state.projectId || crypto.randomUUID(),
    projectName: state.projectName || els.customerName.value.trim() || `NIIX Project ${today().replaceAll("-", "")}`,
  });
  state.projectId = doc.projectId;
  state.projectName = doc.projectName;
  const docs = loadDocuments();
  upsertDocument(docs, doc);
  storeDocuments(docs);
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
  const endpoint = location.protocol === "file:" ? "http://localhost:4180/api/pdf-file" : `${location.origin}/api/pdf-file`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || "PDF出力に失敗しました。");
  }
  return response.json();
}

async function exportPdf() {
  const pdfFile = await createPdfFile();
  showPdfPreview(pdfFile, buildPdfPayload().html);
}

async function downloadPdfDirect() {
  const pdfFile = await createPdfFile();
  triggerPdfDownload(pdfFile.downloadUrl || pdfFile.inlineUrl, pdfFile.filename || "document.pdf");
}

async function printPdfDirect() {
  const pdfFile = await createPdfFile();
  triggerPdfPrint(pdfFile.inlineUrl || pdfFile.downloadUrl);
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
          <a class="primary-button" data-download-pdf>ダウンロード</a>
        </div>
        <div class="pdf-html-preview"></div>
      </form>
    `;
    dialog.addEventListener("close", () => {
      dialog.querySelector(".pdf-html-preview").innerHTML = "";
    });
    document.body.appendChild(dialog);
  }
  if (dialog.open) dialog.close();

  const inlineUrl = pdfFile.inlineUrl || pdfFile.downloadUrl;
  const downloadUrl = pdfFile.downloadUrl || pdfFile.inlineUrl;
  const printUrl = pdfFile.printUrl || inlineUrl;
  const filename = pdfFile.filename || "document.pdf";
  const actions = dialog.querySelector(".pdf-actions");
  actions.innerHTML = `
    <button class="secondary-button" data-print-pdf type="button">PDF印刷</button>
    <a class="primary-button" data-download-pdf>ダウンロード</a>
  `;
  dialog.querySelector(".pdf-html-preview").innerHTML = html || "";
  const printButton = dialog.querySelector("[data-print-pdf]");
  const downloadLink = dialog.querySelector("[data-download-pdf]");
  downloadLink.href = downloadUrl;
  downloadLink.download = filename;
  downloadLink.onclick = (event) => {
    event.preventDefault();
    triggerPdfDownload(downloadUrl, filename);
  };
  printButton.onclick = () => openPdfPrintUrl(printUrl);
  dialog.showModal();
}

function submitPdfForm() {
  const payload = buildPdfPayload();
  const form = document.createElement("form");
  form.method = "POST";
  form.action = "/api/pdf";
  form.target = "_blank";
  form.style.display = "none";

  Object.entries(payload).forEach(([name, value]) => {
    const input = document.createElement("textarea");
    input.name = name;
    input.value = value;
    form.appendChild(input);
  });

  document.body.appendChild(form);
  form.submit();
  setTimeout(() => form.remove(), 1000);
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
        <span>${escapeHtml(item.model || "番号未設定")} / ${yen(item.unitPrice)}</span>
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
    "recentList",
    "flowSteps",
    "topFlowTabs",
    "documentForm",
    "docTypeSelect",
    "basicSectionTitle",
    "docNumberLabel",
    "issueDateLabel",
    "transactionDateLabel",
    "dueDateLabel",
    "customRelatedNumberLabel",
    "partySectionTitle",
    "partyNameLabel",
    "partyAddressLabel",
    "partyContactLabel",
    "issuerSectionTitle",
    "notesLabel",
    "bankDetailsLabel",
    "documentSpecificsLabel",
    "docNumber",
    "issueDate",
    "transactionDate",
    "dueDate",
    "honorific",
    "customerName",
    "customerAddress",
    "customerContact",
    "issuerName",
    "issuerRegistration",
    "issuerAddress",
    "issuerContact",
    "issuerPhone",
    "issuerEmail",
    "issuerCompanyOptions",
    "customerOptions",
    "notes",
    "bankDetails",
    "documentSpecifics",
    "taxRate",
    "noticeType",
    "noticeTitle",
    "noticeBody",
    "noticeList",
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
    "templateSelect",
    "templatePalette",
    "downloadPdfBtn",
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
    "sealTextInput",
    "sealAppearanceInput",
    "sealShapeInput",
    "sealStyleInput",
    "sealFontInput",
    "sealBorderInput",
    "sealEffectInput",
    "sealColorPresetInput",
    "sealColorInput",
    "sealTextColorInput",
    "sealSizePresetInput",
    "sealWidthInput",
    "sealHeightInput",
    "sealRadiusInput",
    "sealOpacityInput",
    "sealRotationInput",
    "sealSettingsPreview",
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

  window.addEventListener("beforeunload", (event) => {
    if (!state.isDirty) return;
    event.preventDefault();
    event.returnValue = "";
  });
  window.addEventListener("resize", schedulePreviewSnapshot);

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

  els.lineItems.addEventListener("input", (event) => {
    const input = event.target.closest("[data-id]");
    if (!input) return;
    const line = state.lines.find((item) => item.id === input.dataset.id);
    if (!line) return;
    line[input.dataset.field] = ["name", "model", "specification"].includes(input.dataset.field) ? input.value : Number(input.value);
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
    "sealTextInput",
    "sealAppearanceInput",
    "sealShapeInput",
    "sealStyleInput",
    "sealFontInput",
    "sealBorderInput",
    "sealEffectInput",
    "sealColorPresetInput",
    "sealColorInput",
    "sealTextColorInput",
    "sealSizePresetInput",
    "sealWidthInput",
    "sealHeightInput",
    "sealRadiusInput",
    "sealOpacityInput",
    "sealRotationInput",
  ].forEach((id) => {
    const updateSeal = () => {
      const selectedColor = (els.sealColorPresetInput.value === "custom" ? els.sealColorInput.value : els.sealColorPresetInput.value).trim() || DEFAULT_SEAL_SETTINGS.color;
      if (id === "sealAppearanceInput" || id === "sealColorPresetInput") {
        els.sealTextColorInput.value = els.sealAppearanceInput.value === "solid" ? "#ffffff" : selectedColor;
      }
      const settings = loadSettings();
      storeSettings({
        ...settings,
        seal: normalizeSealSettings({
          enabled: els.sealEnabledInput.value === "true",
          text: els.sealTextInput.value.trim(),
          appearance: els.sealAppearanceInput.value,
          shape: els.sealShapeInput.value,
          style: els.sealStyleInput.value,
          font: els.sealFontInput.value,
          border: els.sealBorderInput.value,
          effect: els.sealEffectInput.value,
          colorPreset: els.sealColorPresetInput.value,
          color: selectedColor,
          textColor: els.sealTextColorInput.value.trim() || (els.sealAppearanceInput.value === "solid" ? "#ffffff" : selectedColor),
          sizePreset: els.sealSizePresetInput.value,
          width: Number(els.sealWidthInput.value),
          height: Number(els.sealHeightInput.value),
          radius: Number(els.sealRadiusInput.value),
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

  els.customerName?.addEventListener("input", () => {
    renderCompanyOptions();
    const customer = loadCustomers().find((item) => item.companyName === els.customerName.value.trim());
    if (customer) applyCustomerToDocument(customer);
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
  els.issuerName?.addEventListener("input", () => {
    renderCompanyOptions();
    const company = settingsCompanies().find((item) => item.name === els.issuerName.value.trim());
    if (company) applyCompanyToIssuer(company);
  });

  document.getElementById("saveCustomerBtn")?.addEventListener("click", () => {
    const doc = getFormData();
    if (!doc.customerName) return;
    const existing = loadCustomers().find((customer) => customer.companyName === doc.customerName) || {};
    saveCustomerRecord({
      ...existing,
      companyName: doc.customerName,
      companyAddress: doc.customerAddress,
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

  document.getElementById("saveItemBtn")?.addEventListener("click", () => {
    const name = els.itemNameInput.value.trim();
    if (!name) return;
    const items = readStore(ITEM_KEY, []).map(normalizeItem);
    const record = {
      id: crypto.randomUUID(),
      name,
      model: els.itemModelInput.value.trim(),
      unitPrice: Number(els.itemPriceInput.value || 0),
    };
    writeStore(ITEM_KEY, [record, ...items.filter((item) => item.name !== name && item.model !== record.model)].slice(0, 50));
    els.itemNameInput.value = "";
    els.itemModelInput.value = "";
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

  document.getElementById("copyJsonBtn").addEventListener("change", async (event) => {
    const menu = event.currentTarget;
    const action = menu.value;
    if (!action) return;
    const placeholder = menu.options[0];
    const original = placeholder.textContent;
    const content = action === "html" ? buildEmailHtml() : JSON.stringify(getFormData(), null, 2);
    menu.disabled = true;
    try {
      const copied = await copyTextToClipboard(content);
      if (!copied) throw new Error("Clipboard copy failed");
      placeholder.textContent = "コピー済み";
    } catch {
      placeholder.textContent = "コピー失敗";
    }
    setTimeout(() => {
      placeholder.textContent = original;
      menu.value = "";
      menu.disabled = false;
    }, 1200);
  });
}

function init() {
  bindElements();
  seedItems();
  migrateItems();
  ensureNiixCompany();
  simplifyInputLabels();
  bindEvents();
  setMobileView("menu");
  setFormData(documentFromUrl() || defaultDocument("invoice"));
  acceptInviteFromUrl();
}

init();
