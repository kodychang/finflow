export const EMPTY_BACKUP = {
  version: 1,
  exportedAt: new Date().toISOString(),
  documents: [],
  customers: [],
  issuers: [],
  products: [],
  draft: null,
  textTemplates: [],
  deletedDocuments: [],
};

export const DOCUMENT_TYPE_LABELS = {
  estimate: "見積書",
  customerOrder: "受注",
  purchaseOrder: "発注書",
  delivery: "納品書",
  invoice: "請求書",
  receipt: "領収書",
  acceptance: "受領書",
  customerFiles: "プロジェクト管理",
  vendorEstimate: "仕入先見積記録",
  vendorInvoice: "仕入先請求書記録",
  vendorReceipt: "仕入先領収書記録",
  paymentNotice: "支払通知書",
};

export const DOCUMENT_TYPE_PREFIXES = {
  estimate: "EST",
  customerOrder: "ORD",
  purchaseOrder: "PO",
  delivery: "DLV",
  invoice: "INV",
  receipt: "RCT",
  acceptance: "ACP",
  customerFiles: "CF",
  vendorEstimate: "VEST",
  vendorInvoice: "VINV",
  vendorReceipt: "VRCT",
  paymentNotice: "PAY",
};

export const TEMPLATE_KIND_LABELS = {
  payment: "付款資訊",
  note: "備考",
  condition: "交易條件",
  terms: "交易條件",
};

export function documentDefaultsForType(type) {
  return {
    notes: defaultNotesForType(type),
    documentMemo: defaultMemoForType(type),
    paymentProofDate: isVendorDocumentType(type) ? new Date().toISOString() : null,
    paymentProofAmount: isVendorDocumentType(type) ? 0 : null,
    paymentProofAttachments: isVendorDocumentType(type) ? [] : [],
  };
}

export function isVendorDocumentType(type) {
  return ["vendorEstimate", "vendorInvoice", "purchaseOrder", "acceptance", "vendorReceipt", "paymentNotice"].includes(type);
}

function defaultNotesForType(type) {
  switch (type) {
    case "estimate":
      return "見積条件、納入予定、税率・合計金額を確認してください。";
    case "customerOrder":
      return "受注資料を添付し、取引内容を確認してください。";
    case "purchaseOrder":
      return "注文内容をご確認の上、手配をお願いいたします。";
    case "delivery":
      return "上記の通り納品いたします。";
    case "invoice":
      return "振込手数料は貴社にてご負担ください。";
    case "receipt":
      return "上記の金額を領収いたしました。";
    case "acceptance":
      return "上記の通り、受領いたしました。";
    case "customerFiles":
      return "取引先から受領した書類ファイルを管理します。";
    case "vendorEstimate":
      return "仕入先から受領した見積書ファイルを添付し、プロジェクト・日時・番号を記録してください。";
    case "vendorInvoice":
      return "仕入先から受領した請求書ファイルを添付し、プロジェクト・日時・番号を記録してください。";
    case "vendorReceipt":
      return "仕入先から受領した領収書ファイルを添付し、プロジェクト・日時・番号を記録してください。";
    case "paymentNotice":
      return "支払告知・支払通知書ファイルを添付し、プロジェクト・日時・番号を記録してください。";
    default:
      return "";
  }
}

function defaultMemoForType(type) {
  switch (type) {
    case "customerFiles":
      return "見積書、請求書、領収書などを同じ画面で管理します。";
    case "customerOrder":
      return "受注ファイル、希望納期、関連見積番号を確認してください。";
    case "vendorEstimate":
      return "仕入先見積書、現場写真、LINE截圖、契約関連資料をまとめて保存します。";
    case "vendorInvoice":
      return "仕入先請求書、関連する納品・発注資料、支払予定資料をまとめて保存します。";
    case "vendorReceipt":
      return "領収書、支払証憑、関連する確認資料をまとめて保存します。";
    case "paymentNotice":
      return "支払告知通知書、支払予定、関連証憑をまとめて保存します。";
    default:
      return "";
  }
}

export function validateBackup(value) {
  if (!value || typeof value !== "object") {
    throw new Error("備份文件不是 JSON 物件。");
  }
  if (value.version !== 1) {
    throw new Error(`不支援的備份版本：${value.version ?? "未知"}`);
  }
  for (const key of ["documents", "customers", "issuers", "products"]) {
    if (!Array.isArray(value[key])) {
      throw new Error(`備份缺少 ${key} 陣列。`);
    }
  }
  return true;
}

export function normalizeBackup(value) {
  validateBackup(value);
  return {
    ...EMPTY_BACKUP,
    ...value,
    documents: [...value.documents],
    customers: [...value.customers],
    issuers: [...value.issuers],
    products: [...value.products],
    textTemplates: Array.isArray(value.textTemplates) ? [...value.textTemplates] : [],
    deletedDocuments: Array.isArray(value.deletedDocuments) ? pruneDeletedDocuments(value.deletedDocuments) : [],
    draft: value.draft ?? null,
  };
}

export function mergeBackups(current, incoming) {
  const merged = normalizeBackup(current);
  const next = normalizeBackup(incoming);
  for (const key of ["documents", "customers", "issuers", "products", "textTemplates"]) {
    const ids = new Set(merged[key].map((item) => item?.id).filter(Boolean));
    for (const item of next[key]) {
      if (!item?.id || !ids.has(item.id)) {
        merged[key].push(item);
        if (item?.id) ids.add(item.id);
      }
    }
  }
  const deletedIds = new Set(merged.deletedDocuments.map((item) => item?.id).filter(Boolean));
  for (const item of next.deletedDocuments ?? []) {
    if (!item?.id || deletedIds.has(item.id)) continue;
    merged.deletedDocuments.push(item);
    deletedIds.add(item.id);
  }
  merged.deletedDocuments = pruneDeletedDocuments(merged.deletedDocuments);
  if (!merged.draft && next.draft) {
    merged.draft = next.draft;
  }
  merged.exportedAt = new Date().toISOString();
  return merged;
}

export function pruneDeletedDocuments(records = [], now = new Date()) {
  const nowTime = now.getTime();
  return records
    .filter((record) => {
      const deletedAt = new Date(record?.deletedAt ?? 0).getTime();
      return record?.document && Number.isFinite(deletedAt) && nowTime - deletedAt < 30 * 24 * 60 * 60 * 1000;
    })
    .sort((a, b) => new Date(b.deletedAt).getTime() - new Date(a.deletedAt).getTime());
}

export function makeDocument(type = "invoice") {
  const now = new Date().toISOString();
  const dueDate = new Date();
  dueDate.setDate(dueDate.getDate() + 30);
  const id = crypto.randomUUID();
  const defaults = documentDefaultsForType(type);
  const prefix = DOCUMENT_TYPE_PREFIXES[type] ?? "DOC";
  return {
    id,
    projectId: null,
    projectName: "",
    projectDirection: null,
    type,
    number: `${prefix}-${new Date().getFullYear()}-${id.slice(0, 8).toUpperCase()}`,
    issueDate: now,
    transactionDate: now,
    dueDate: dueDate.toISOString(),
    relatedNumber: "",
    honorific: "御中",
    taxRate: 10,
    colorTemplateId: "monochrome",
    customerName: "",
    customerAddress: "",
    customerContact: "",
    customerPhone: "",
    customerEmail: "",
    issuerName: "",
    issuerRegistration: "",
    issuerAddress: "",
    issuerContact: "",
    issuerPhone: "",
    issuerEmail: "",
    issuerLogoData: null,
    issuerLogoScale: 1,
    notes: defaults.notes,
    paymentDetails: "",
    documentMemo: defaults.documentMemo,
    lines: [
      {
        id: crypto.randomUUID(),
        name: "",
        model: "",
        specification: "",
        quantity: 1,
        unitPrice: 0,
      },
    ],
    orderAttachments: [],
    paymentProofDate: defaults.paymentProofDate,
    paymentProofAmount: defaults.paymentProofAmount,
    paymentProofAttachments: defaults.paymentProofAttachments,
    googleDrivePDFFileID: null,
    googleDriveJSONFileID: null,
    updatedAt: now,
  };
}

export function makeCustomer() {
  const now = new Date().toISOString();
  return {
    id: crypto.randomUUID(),
    name: "",
    contact: "",
    phone: "",
    email: "",
    address: "",
    updatedAt: now,
  };
}

export function makeIssuer() {
  const now = new Date().toISOString();
  return {
    id: crypto.randomUUID(),
    name: "",
    registration: "",
    contact: "",
    phone: "",
    email: "",
    address: "",
    logoData: null,
    logoScale: 1,
    updatedAt: now,
  };
}

export function makeProduct() {
  const now = new Date().toISOString();
  return {
    id: crypto.randomUUID(),
    name: "",
    model: "",
    specification: "",
    unitPrice: 0,
    updatedAt: now,
  };
}

export function makeTextTemplate() {
  const now = new Date().toISOString();
  return {
    id: crypto.randomUUID(),
    kind: "note",
    title: "",
    content: "",
    updatedAt: now,
  };
}

export function documentTotal(document) {
  const subtotal = (document.lines ?? []).reduce((sum, line) => {
    const quantity = Number(line.quantity);
    const unitPrice = Number(line.unitPrice);
    return sum + (Number.isFinite(quantity) ? quantity : 0) * (Number.isFinite(unitPrice) ? unitPrice : 0);
  }, 0);
  const tax = Math.round(subtotal * (Number(document.taxRate || 0) / 100));
  return { subtotal, tax, total: subtotal + tax };
}

export function formatDate(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return new Intl.DateTimeFormat("ja-JP", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

export function backupFileName() {
  const stamp = new Date()
    .toISOString()
    .replace(/[-:]/g, "")
    .replace(/\.\d+Z$/, "")
    .replace("T", "-");
  return `shoko-forms-backup-${stamp}.shokobackup`;
}
