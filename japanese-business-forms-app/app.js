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
const CUSTOMER_KEY = "shokoForms.customers.v1";
const ITEM_KEY = "shokoForms.items.v1";
const TEMPLATE_KEY = "shokoForms.templates.v1";
const SETTINGS_KEY = "shokoForms.settings.v1";
const OPERATION_KEY = "shokoForms.operations.v1";

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

const CONVERSION_RULES = {
  estimate: ["order", "purchaseOrder", "invoice"],
  order: ["delivery", "invoice"],
  purchaseOrder: ["delivery", "invoice"],
  delivery: ["invoice", "acceptance"],
  invoice: ["receipt"],
};

const FLOW_NEXT = {
  estimate: "order",
  order: "delivery",
  delivery: "invoice",
  invoice: "receipt",
};

const FLOW_STEPS = [
  { type: "estimate", label: "見積", note: "条件・金額を提示" },
  { type: "order", label: "注文 / 発注", note: "顧客注文と仕入発注", alternates: ["purchaseOrder"] },
  { type: "delivery", label: "納品", note: "出荷・納品記録" },
  { type: "invoice", label: "請求", note: "振込先と支払期限" },
  { type: "receipt", label: "領収", note: "入金後の証憑" },
];

const COPY_TARGETS = ["estimate", "order", "purchaseOrder", "delivery", "invoice", "receipt", "acceptance"];

const REFERENCE_TYPES = {
  order: ["estimate"],
  purchaseOrder: ["estimate"],
  delivery: ["order", "purchaseOrder"],
  invoice: ["delivery"],
  receipt: ["invoice"],
  acceptance: ["delivery"],
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
  templateId: "monochrome",
  sourceDocumentId: "",
  sourceDocumentNumber: "",
  sourceDocumentType: "",
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
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
  } catch {
    return [];
  }
}

function storeDocuments(documents) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(documents));
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
    taxMode: "standard10",
    sourceDocumentId: "",
    sourceDocumentNumber: "",
    sourceDocumentType: "",
    relatedDocumentNumbers: {},
    showRelatedNumber: true,
    convertedDocumentIds: [],
    notices: [],
    lines: [
      { id: crypto.randomUUID(), name: "智慧ミラー", model: "SM-GLASS-42", specification: "42インチ / Android OS / 壁掛け金具付き", quantity: 10, unitPrice: 98000 },
    ],
  };
}

function getFormData() {
  return {
    id: state.currentId,
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
    taxMode: els.taxMode?.value || "standard10",
    sourceDocumentId: state.sourceDocumentId || "",
    sourceDocumentNumber: state.sourceDocumentNumber || "",
    sourceDocumentType: state.sourceDocumentType || "",
    relatedDocumentNumbers: {
      ...(state.relatedDocumentNumbers || {}),
      ...(state.sourceDocumentType && state.sourceDocumentNumber ? { [state.sourceDocumentType]: state.sourceDocumentNumber } : {}),
    },
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
  state.docType = docType;
  state.templateId = doc.templateId || state.templateId || "monochrome";
  state.sourceDocumentId = doc.sourceDocumentId || "";
  state.sourceDocumentNumber = doc.sourceDocumentNumber || "";
  state.sourceDocumentType = doc.sourceDocumentType || "";
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
    "taxMode",
  ]) {
    if (els[key]) els[key].value = doc[key] || "";
  }
  if (els.taxMode) els.taxMode.value = doc.taxMode || "standard10";
  if (els.showRelatedNumber) els.showRelatedNumber.checked = doc.showRelatedNumber !== false;

  renderLines();
  renderAll();
  setDirty(false);
}

function totals(doc) {
  const subtotal = doc.lines.reduce((total, line) => total + Number(line.quantity || 0) * Number(line.unitPrice || 0), 0);
  const taxMode = doc.taxMode || "standard10";
  const taxable10 = taxMode === "standard10" ? subtotal : 0;
  const taxable8 = taxMode === "reduced8" ? subtotal : 0;
  const taxable0 = taxMode === "none" ? subtotal : 0;
  const tax8 = Math.floor(taxable8 * 0.08);
  const tax10 = Math.floor(taxable10 * 0.1);
  return { subtotal, taxable8, taxable10, taxable0, tax8, tax10, total: subtotal + tax8 + tax10 };
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
  updateDateFieldPrefixes();
}

function updateDateFieldPrefixes() {
  ["issueDate", "transactionDate", "dueDate"].forEach((fieldId) => {
    const control = els[fieldId] || document.getElementById(fieldId);
    const label = control?.closest("label");
    if (!control || !label) return;
    const title = label.querySelector(":scope > .input-title, :scope > span[id$='Label']");
    const text = title?.dataset.defaultLabel || title?.textContent?.trim() || labelTitleText(label);
    if (!text) return;
    label.classList.add("date-prefixed-field");
    label.dataset.datePrefix = text;
    control.placeholder = `${text} YYYY/MM/DD`;
    control.style.setProperty("--date-prefix-width", `${Math.max(58, text.length * 14 + 18)}px`);
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
  const ids = new Set([currentDoc.id, currentDoc.sourceDocumentId, ...(currentDoc.convertedDocumentIds || [])].filter(Boolean));
  const numbers = new Set([currentDoc.docNumber, currentDoc.sourceDocumentNumber, ...Object.values(currentDoc.relatedDocumentNumbers || {})].filter(Boolean));
  let changed = true;
  while (changed) {
    changed = false;
    docs.forEach((doc) => {
      const docNumbers = [doc.docNumber, doc.sourceDocumentNumber, ...Object.values(doc.relatedDocumentNumbers || {})].filter(Boolean);
      const linked =
        ids.has(doc.id) ||
        ids.has(doc.sourceDocumentId) ||
        (doc.convertedDocumentIds || []).some((id) => ids.has(id)) ||
        docNumbers.some((number) => numbers.has(number));
      if (!linked) return;
      const before = ids.size + numbers.size;
      ids.add(doc.id);
      if (doc.sourceDocumentId) ids.add(doc.sourceDocumentId);
      (doc.convertedDocumentIds || []).forEach((id) => ids.add(id));
      docNumbers.forEach((number) => numbers.add(number));
      changed = ids.size + numbers.size !== before;
    });
  }

  const byType = new Map();
  docs
    .filter((doc) => ids.has(doc.id) || [doc.docNumber, doc.sourceDocumentNumber, ...Object.values(doc.relatedDocumentNumbers || {})].some((number) => numbers.has(number)))
    .forEach((doc) => {
      const current = byType.get(doc.docType);
      if (!current || String(doc.updatedAt || "").localeCompare(String(current.updatedAt || "")) > 0) {
        byType.set(doc.docType, doc);
      }
    });
  byType.set(currentDoc.docType, currentDoc);
  return byType;
}

function renderFlowSidebar() {
  if (!els.flowSteps) return;
  const doc = getFormData();
  const related = relatedFlowDocuments(doc);
  els.flowSteps.innerHTML = FLOW_STEPS.map((step, index) => {
    const stepDoc =
      step.type === doc.docType || step.alternates?.includes(doc.docType)
        ? doc
        : related.get(step.type) || step.alternates?.map((type) => related.get(type)).find(Boolean);
    const stepIssues = stepDoc ? documentIssueMessages(stepDoc) : [];
    const isCurrent = stepDoc?.id === doc.id || step.type === doc.docType || step.alternates?.includes(doc.docType);
    const status = isCurrent ? "現在" : stepDoc ? "作成済" : "未作成";
    const issueText = stepDoc ? (stepIssues[0] || "確認項目OK") : step.note;
    const badgeClass = stepIssues.length ? "has-issues" : stepDoc ? "is-ok" : "can-create";
    const badgeText = stepDoc ? (stepIssues.length ? `${stepIssues.length}件` : "OK") : "作成";
    const refs = stepDoc ? referenceEntries(stepDoc) : [];
    const stepText = stepDoc?.docNumber
      ? `${stepDoc.docNumber}${refs.length ? ` / 関連: ${formatReferenceEntries(refs)}` : ""}`
      : issueText;
    return `
      <button class="flow-step ${isCurrent ? "active" : ""} ${stepDoc ? "is-done" : "is-pending"}" type="button" data-flow-type="${escapeHtml(stepDoc?.docType || step.type)}">
        <strong>${index + 1}</strong>
        <span>${escapeHtml(step.label)}<b>${escapeHtml(status)}</b></span>
        <small>${escapeHtml(stepText)}</small>
        <em class="${badgeClass}">${badgeText}</em>
      </button>
    `;
  }).join("");
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

function lineDetailParts(line) {
  return [line.model, ...String(line.specification || "").split("/")]
    .map((part) => part.trim())
    .filter(Boolean);
}

function toggleTotalRow(element, visible) {
  const row = element?.closest("div");
  if (row) row.hidden = !visible;
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
  if (els.taxSettingsSection) els.taxSettingsSection.hidden = !hasPrices;
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
  toggleTotalRow(els.previewTaxable10, doc.taxMode === "standard10");
  toggleTotalRow(els.previewTax10, doc.taxMode === "standard10");
  toggleTotalRow(els.previewTaxable8, doc.taxMode === "reduced8");
  toggleTotalRow(els.previewTax8, doc.taxMode === "reduced8");
  toggleTotalRow(els.previewTaxable0, doc.taxMode === "none");
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
}

function syncRelatedNumberVisibility(doc = getFormData()) {
  if (!els.previewSourceRow || !els.previewSource) return;
  const refs = referenceEntries(doc);
  const shouldShow = Boolean(doc.showRelatedNumber);
  els.previewSource.textContent = refs.length ? formatReferenceEntries(refs) : "関連番号なし";
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

  const nextType = FLOW_NEXT[state.docType];
  els.nextStepBtn.disabled = !nextType;
  els.nextStepBtn.textContent = nextType ? `次工程へ: ${DOC_TYPES[nextType].title}` : "次工程なし";
}

function applyTemplate() {
  if (!els.printArea) return;
  const template = selectedTemplate();
  els.printArea.dataset.template = template.style;
  els.printArea.style.setProperty("--template-accent", template.accent || "#2f3744");
  if (els.previewLogo) els.previewLogo.style.background = template.accent || "#2f3744";
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

function renderTemplateList() {
  if (!els.templateList) return;
  els.templateList.innerHTML = "";
  loadTemplates().forEach((template) => {
    const row = document.createElement("div");
    row.className = "template-list-item";
    row.innerHTML = `
      <span class="template-swatch" style="background:${escapeHtml(template.accent || "#2f3744")}"></span>
      <strong>${escapeHtml(template.name)}</strong>
      <small>${escapeHtml(template.style)}${template.builtin ? " / 標準" : ""}</small>
      <button class="text-button" data-template-apply="${escapeHtml(template.id)}" type="button">適用</button>
      ${template.builtin ? "" : `<button class="text-button danger" data-template-delete="${escapeHtml(template.id)}" type="button">削除</button>`}
    `;
    els.templateList.appendChild(row);
  });
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
  return {
    ...source,
    id: crypto.randomUUID(),
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
  const index = docs.findIndex((item) => item.id === doc.id);
  if (index >= 0) docs[index] = doc;
  else docs.push(doc);
}

async function convertCurrentDocument() {
  const targetType = els.conversionTarget?.value;
  if (!targetType || targetType === state.docType || !DOC_TYPES[targetType]) return;
  if (!(await confirmLeaveCurrentDocument())) return;

  const source = getFormData();
  const converted = buildConvertedDocument(source, targetType);
  const linkedSource = {
    ...source,
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
    .slice(0, 3);

  els.recentList.innerHTML = "";
  if (!docs.length) {
    els.recentList.innerHTML = `<div class="recent-item">保存済みなし<span>保存するとここに表示されます</span></div>`;
    return;
  }

  docs.forEach((doc) => {
    const button = document.createElement("button");
    button.className = "recent-item";
    button.type = "button";
    const source = documentReferenceText(doc);
    button.innerHTML = `${escapeHtml(doc.docNumber)}<span>${escapeHtml(DOC_TYPES[doc.docType]?.title || "帳票")} / ${escapeHtml(doc.customerName || "取引先未入力")}${escapeHtml(source)}</span>`;
    button.addEventListener("click", async () => {
      if (await loadDocument(doc.id)) setMobileView("form");
    });
    els.recentList.appendChild(button);
  });

  if (loadDocuments().length > 3) {
    const more = document.createElement("button");
    more.className = "recent-more";
    more.type = "button";
    more.textContent = "もっと見る";
    more.addEventListener("click", openHistoryDialog);
    els.recentList.appendChild(more);
  }
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
  if (CONVERSION_RULES[doc.docType]?.includes(type)) {
    await copyCurrentDocumentAs(type);
    return;
  }
  await switchDocType(type);
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
    accountName: "",
    accountEmail: "",
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
  if (els.settingsAccountName) els.settingsAccountName.value = settings.accountName || "";
  if (els.settingsAccountEmail) els.settingsAccountEmail.value = settings.accountEmail || "";
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

function exportBackup() {
  const payload = {
    exportedAt: new Date().toISOString(),
    documents: loadDocuments(),
    customers: loadCustomers(),
    items: readStore(ITEM_KEY, []),
    templates: readStore(TEMPLATE_KEY, []),
    settings: loadSettings(),
  };
  const json = JSON.stringify(payload, null, 2);
  els.backupOutput.value = json;
  const blob = new Blob([json], { type: "application/json" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = `shoko-forms-backup-${today()}.json`;
  link.click();
  URL.revokeObjectURL(link.href);
}

function buildPdfPayload() {
  const doc = getFormData();
  renderPreview();
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

function importBackup(file) {
  if (!file) return;
  const reader = new FileReader();
  reader.addEventListener("load", () => {
    try {
      const payload = JSON.parse(String(reader.result || "{}"));
      if (Array.isArray(payload.documents)) storeDocuments(payload.documents);
      if (Array.isArray(payload.customers)) storeCustomers(payload.customers);
      if (Array.isArray(payload.items)) writeStore(ITEM_KEY, payload.items);
      if (Array.isArray(payload.templates)) writeStore(TEMPLATE_KEY, payload.templates);
      if (payload.settings) storeSettings(payload.settings);
      renderAll();
      renderSettings();
      syncProjectSurfaces();
      els.backupOutput.value = "バックアップを読み込みました。";
    } catch {
      els.backupOutput.value = "バックアップJSONを読み込めませんでした。";
    }
  });
  reader.readAsText(file);
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
  if (els.templateDialog?.open) renderTemplateList();
  if (els.operationDialog?.open) {
    renderOperationAssignees();
    renderOperationHistory();
  }
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
}

function setDirty(isDirty = true) {
  state.isDirty = isDirty;
  els.saveStatus.textContent = isDirty ? "未保存" : "保存済み";
  els.saveStatus.style.color = isDirty ? "var(--warn)" : "var(--accent)";
}

function deleteCurrentDocumentRecord() {
  const doc = getFormData();
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
  const doc = getFormData();
  const docs = loadDocuments();
  const index = docs.findIndex((item) => item.id === doc.id);
  if (index >= 0) docs[index] = doc;
  else docs.push(doc);
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

async function exportPdf() {
  const payload = buildPdfPayload();
  const endpoint = location.protocol === "file:" ? "http://localhost:4180/api/pdf-file" : `${location.origin}/api/pdf-file`;
  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!response.ok) {
      const message = await response.text();
      throw new Error(message || "PDF出力に失敗しました。");
    }
    const pdfFile = await response.json();
    showPdfPreview(pdfFile, payload.html);
  } catch (error) {
    console.error("server pdf export failed", error);
    const serverUrl = location.protocol === "file:" ? "http://localhost:4180/" : `${location.origin}/`;
    printWithBrowserFallback(`PDFサーバーに接続できないため、ブラウザ印刷でPDF保存を開きます。\n${serverUrl} を起動してから再試行してください。`);
  }
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
  items.forEach((item) => {
    const button = document.createElement("button");
    button.className = "master-list-item";
    button.type = "button";
    button.innerHTML = `<strong>${escapeHtml(item.name)}</strong><span>${escapeHtml(item.model || "番号未設定")} / ${yen(item.unitPrice)}</span>`;
    button.addEventListener("click", () => {
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
    els.itemMasterList.appendChild(button);
  });
}

function bindElements() {
  for (const id of [
    "pageTitle",
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
    "documentForm",
    "docTypeSelect",
    "basicSectionTitle",
    "docNumberLabel",
    "issueDateLabel",
    "transactionDateLabel",
    "dueDateLabel",
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
    "taxMode",
    "taxSettingsSection",
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
    "previewTotal",
    "previewNotes",
    "previewBankTitle",
    "previewBank",
    "previewSpecificsTitle",
    "previewSpecifics",
    "printArea",
    "templateSelect",
    "templatePalette",
    "templateManageBtn",
    "templateDialog",
    "templateNameInput",
    "templateStyleInput",
    "templateAccentInput",
    "saveTemplateBtn",
    "templateList",
    "jsonDialog",
    "jsonOutput",
    "historyDialog",
    "historyTypeFilter",
    "historySearchInput",
    "historyList",
    "settingsDialog",
    "settingsAccountName",
    "settingsAccountEmail",
    "saveSettingsBtn",
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
    "exportBackupBtn",
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
    const item = readStore(ITEM_KEY, []).map(normalizeItem)[0];
    if (!item) return;
    state.lines.push({
      id: crypto.randomUUID(),
      name: item.name,
      model: item.model || "",
      specification: item.specification || "",
      quantity: 1,
      unitPrice: item.unitPrice,
    });
    renderLines();
    renderPreview();
    setDirty(true);
  });

  document.getElementById("saveBtn").addEventListener("click", saveDocument);
  document.getElementById("printBtn").addEventListener("click", async () => {
    const button = document.getElementById("printBtn");
    const original = button.textContent;
    button.disabled = true;
    button.textContent = location.protocol === "file:" ? "印刷画面を開く" : "PDF生成中";
    try {
      await exportPdf();
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
  document.getElementById("exportHtmlBtn")?.addEventListener("click", exportEmailHtml);
  document.getElementById("openSettingsBtn")?.addEventListener("click", openSettingsDialog);
  els.historyTypeFilter?.addEventListener("change", renderHistory);
  els.historySearchInput?.addEventListener("input", renderHistory);
  els.saveSettingsBtn?.addEventListener("click", () => {
    const settings = loadSettings();
    storeSettings({
      ...settings,
      accountName: els.settingsAccountName.value.trim(),
      accountEmail: els.settingsAccountEmail.value.trim(),
    });
    renderSettings();
  });
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
    const settings = loadSettings();
    storeSettings({ ...settings, staff: (settings.staff || []).filter((member) => member.id !== button.dataset.removeStaff) });
    renderSettings();
    syncProjectSurfaces();
  });
  document.getElementById("openOperationHistoryBtn")?.addEventListener("click", openOperationDialog);
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
  els.importBackupInput?.addEventListener("change", (event) => importBackup(event.target.files?.[0]));
  els.convertDocumentBtn?.addEventListener("click", convertCurrentDocument);
  els.nextStepBtn?.addEventListener("click", () => copyCurrentDocumentAs(FLOW_NEXT[state.docType]));
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

  els.templateManageBtn?.addEventListener("click", () => {
    renderTemplateList();
    els.templateDialog.showModal();
  });

  els.saveTemplateBtn?.addEventListener("click", () => {
    const name = els.templateNameInput.value.trim();
    if (!name) return;
    const templates = readStore(TEMPLATE_KEY, []);
    const record = {
      id: `custom-${crypto.randomUUID()}`,
      name,
      style: els.templateStyleInput.value,
      accent: els.templateAccentInput.value || "#2f3744",
      builtin: false,
    };
    writeStore(TEMPLATE_KEY, [record, ...templates.filter((template) => template.name !== name)].slice(0, 20));
    state.templateId = record.id;
    els.templateNameInput.value = "";
    syncProjectSurfaces();
    renderPreview();
    setDirty(true);
  });

  els.templateList?.addEventListener("click", (event) => {
    const applyButton = event.target.closest("[data-template-apply]");
    const deleteButton = event.target.closest("[data-template-delete]");
    if (applyButton) {
      state.templateId = applyButton.dataset.templateApply;
      syncProjectSurfaces();
      renderPreview();
      setDirty(true);
    }
    if (deleteButton) {
      const id = deleteButton.dataset.templateDelete;
      writeStore(TEMPLATE_KEY, readStore(TEMPLATE_KEY, []).filter((template) => template.id !== id));
      if (state.templateId === id) state.templateId = "monochrome";
      syncProjectSurfaces();
      renderPreview();
      setDirty(true);
    }
  });

  document.getElementById("loadCustomerBtn").addEventListener("click", () => {
    Object.assign(els.customerName, { value: SAMPLE_CUSTOMER.customerName });
    Object.assign(els.customerAddress, { value: SAMPLE_CUSTOMER.customerAddress });
    Object.assign(els.customerContact, { value: SAMPLE_CUSTOMER.customerContact });
    saveCustomerRecord({
      companyName: SAMPLE_CUSTOMER.customerName,
      companyAddress: SAMPLE_CUSTOMER.customerAddress,
      companyPhone: SAMPLE_CUSTOMER.customerPhone,
      email: SAMPLE_CUSTOMER.customerEmail,
      fax: SAMPLE_CUSTOMER.customerFax,
      contactName: "佐藤",
      contactPhone: SAMPLE_CUSTOMER.customerContactPhone,
      department: "経理部",
      other: "サンプル取引先",
    });
    renderPreview();
    setDirty(true);
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

  document.getElementById("copyJsonBtn").addEventListener("click", async () => {
    const json = JSON.stringify(getFormData(), null, 2);
    els.jsonOutput.value = json;
    try {
      await navigator.clipboard.writeText(json);
    } catch {
      // Clipboard permission is optional; the dialog still exposes the JSON.
    }
    els.jsonDialog.showModal();
  });
}

function init() {
  bindElements();
  seedItems();
  migrateItems();
  simplifyInputLabels();
  bindEvents();
  setMobileView("menu");
  setFormData(defaultDocument("invoice"));
  acceptInviteFromUrl();
}

init();
