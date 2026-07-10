import React, { useEffect, useMemo, useRef, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import { createPortal } from "react-dom";
import { createRoot } from "react-dom/client";
import {
  AlertTriangle,
  Archive,
  BookOpen,
  Building2,
  Check,
  ChevronLeft,
  ChevronRight,
  CircleHelp,
  Download,
  Eye,
  FileCheck2,
  FileJson,
  FilePlus2,
  FileText,
  Folder,
  FolderOpen,
  History,
  Home,
  KeyRound,
  Languages,
  LifeBuoy,
  LayoutGrid,
  List,
  Package,
  Palette,
  Pencil,
  Plus,
  Save,
  Search,
  Settings,
  SlidersHorizontal,
  Stamp,
  Trash2,
  Upload,
  Users,
  EyeOff,
  RotateCcw,
  ZoomIn,
  ZoomOut,
} from "lucide-react";
import {
  DOCUMENT_TYPE_LABELS,
  DOCUMENT_TYPE_PREFIXES,
  TEMPLATE_KIND_LABELS,
  documentDefaultsForType,
  documentTotal,
  formatDate,
  isVendorDocumentType,
  makeCustomer,
  makeDocument,
  makeIssuer,
  makeProduct,
  makeTextTemplate,
  normalizeBackup,
  pruneDeletedDocuments,
} from "./backup";
import {
  clearStoredLicense,
  formatLicenseDate,
  loadStoredLicense,
  saveStoredLicense,
  verifyLicenseKey,
} from "./license";
import {
  chooseDataFolder,
  completeFirstRunSetup,
  exportBackup,
  getFirstRunStatus,
  importBackupText,
  initStorage,
  isTauri,
  loadState,
  openLocalFile,
  pendingOpenFiles,
  readBinaryFile,
  resetDataRoot,
  saveBinaryFileWithDialog,
  saveState,
  setDataRoot,
  writeTempBinaryFile,
} from "./tauri";
import "./styles.css";

const NAV_ITEMS = [
  { id: "home", label: "首頁", icon: Home },
  { id: "documents", label: "帳票", icon: FileText },
  { id: "company", label: "公司列表", icon: Building2, dataSection: "company" },
  { id: "files", label: "檔案列表", icon: Archive, dataSection: "files" },
  { id: "projects", label: "項目列表", icon: Folder, dataSection: "projects" },
  { id: "customers", label: "客戶列表", icon: Users, dataSection: "customers" },
  { id: "products", label: "商品列表", icon: Package, dataSection: "products" },
  { id: "templates", label: "模板列表", icon: Archive, dataSection: "templates" },
  { id: "stamp", label: "印章管理", icon: Stamp, dataSection: "stamp" },
];

const NAV_LABELS = {
  japanese: {
    home: "ホーム",
    documents: "帳票",
    company: "会社リスト",
    files: "ファイルリスト",
    projects: "案件リスト",
    customers: "顧客リスト",
    products: "商品リスト",
    templates: "テンプレート",
    stamp: "印章管理",
    settings: "設定",
    newDocument: "帳票を追加",
  },
  simplifiedChinese: {
    home: "首页",
    documents: "帐票",
    company: "公司列表",
    files: "档案列表",
    projects: "项目列表",
    customers: "客户列表",
    products: "商品列表",
    templates: "模板列表",
    stamp: "印章管理",
    settings: "设置",
    newDocument: "新增帐票",
  },
  english: {
    home: "Home",
    documents: "Forms",
    company: "Companies",
    files: "Files",
    projects: "Projects",
    customers: "Customers",
    products: "Products",
    templates: "Templates",
    stamp: "Stamp",
    settings: "Settings",
    newDocument: "New Form",
  },
  traditionalChinese: {
    home: "首頁",
    documents: "表單",
    company: "公司列表",
    files: "檔案列表",
    projects: "專案列表",
    customers: "客戶列表",
    products: "商品列表",
    templates: "範本列表",
    stamp: "印章管理",
    settings: "設定",
    newDocument: "新增表單",
  },
  korean: {
    home: "Home",
    documents: "Forms",
    company: "Companies",
    files: "Files",
    projects: "Projects",
    customers: "Customers",
    products: "Products",
    templates: "Templates",
    stamp: "Stamp",
    settings: "Settings",
    newDocument: "New Form",
  },
  nepali: {
    home: "Home",
    documents: "Forms",
    company: "Companies",
    files: "Files",
    projects: "Projects",
    customers: "Customers",
    products: "Products",
    templates: "Templates",
    stamp: "Stamp",
    settings: "Settings",
    newDocument: "New Form",
  },
  french: {
    home: "Accueil",
    documents: "Formulaires",
    company: "Entreprises",
    files: "Fichiers",
    projects: "Projets",
    customers: "Clients",
    products: "Produits",
    templates: "Modeles",
    stamp: "Tampon",
    settings: "Reglages",
    newDocument: "Nouveau",
  },
  vietnamese: {
    home: "Trang chu",
    documents: "Bieu mau",
    company: "Cong ty",
    files: "Tep",
    projects: "Du an",
    customers: "Khach hang",
    products: "San pham",
    templates: "Mau",
    stamp: "Con dau",
    settings: "Cai dat",
    newDocument: "Tao moi",
  },
};

function navCopy(languageId = "japanese") {
  return NAV_LABELS[languageId] ?? NAV_LABELS.japanese;
}

function detectSystemLanguageId() {
  const identifiers = typeof navigator === "undefined" ? [] : [navigator.language, ...(navigator.languages ?? [])];
  for (const identifier of identifiers.filter(Boolean)) {
    const normalized = identifier.toLowerCase();
    if (normalized.startsWith("ko")) return "korean";
    if (normalized.startsWith("zh-hant") || normalized.startsWith("zh-tw") || normalized.startsWith("zh-hk") || normalized.startsWith("zh-mo")) return "traditionalChinese";
    if (normalized.startsWith("zh")) return "simplifiedChinese";
    if (normalized.startsWith("ja")) return "japanese";
    if (normalized.startsWith("ne")) return "nepali";
    if (normalized.startsWith("fr")) return "french";
    if (normalized.startsWith("vi")) return "vietnamese";
    if (normalized.startsWith("en")) return "english";
  }
  return "japanese";
}

const DOCUMENT_DIRECTION_GROUPS = {
  customer: {
    label: "顧客",
    subtitle: "報價、受注、送貨、發票、收據",
    types: ["estimate", "customerOrder", "delivery", "invoice", "receipt"],
  },
  vendor: {
    label: "取引先",
    subtitle: "報價記錄、採購、收貨、請求、收據",
    types: ["vendorEstimate", "purchaseOrder", "acceptance", "vendorInvoice", "vendorReceipt"],
  },
};

const FORM_TYPE_DESCRIPTIONS = {
  estimate: "建立報價單，記錄提供給客戶的報價內容",
  customerOrder: "上傳/建立客戶訂單，記錄受注內容",
  delivery: "建立發貨單，確認商品交付與出貨內容",
  invoice: "建立請款書，向客戶整理請款明細",
  receipt: "建立收據，記錄客戶已付款項",
  vendorEstimate: "上傳供應商報價，保存採購報價記錄",
  purchaseOrder: "建立發注書，向供應商發出採購需求",
  acceptance: "建立受領書，記錄收貨與驗收結果",
  vendorInvoice: "上傳供應商請求書，保存請款憑證記錄",
  vendorReceipt: "上傳供應商收據，保存付款憑證記錄",
};

const FORM_MENU_TYPE_LABELS = {
  customerOrder: "受注ファイル",
  vendorEstimate: "見積書ファイル",
  vendorInvoice: "請求書ファイル",
  vendorReceipt: "領収書ファイル",
};

function formMenuTypeLabel(type) {
  return FORM_MENU_TYPE_LABELS[type] ?? DOCUMENT_TYPE_LABELS[type] ?? type;
}

const UPLOAD_ENABLED_TYPES_BY_DIRECTION = {
  customer: ["customerOrder"],
  vendor: ["vendorEstimate", "vendorInvoice", "vendorReceipt"],
};

const HIDDEN_DOCUMENT_TYPES = new Set(["paymentNotice"]);

function isHiddenDocumentType(type) {
  return HIDDEN_DOCUMENT_TYPES.has(type);
}

const ATTACHMENT_RECORD_DOCUMENT_TYPES = new Set(["customerOrder", "vendorEstimate", "vendorInvoice", "vendorReceipt", "paymentNotice"]);
const PRICE_VISIBLE_DOCUMENT_TYPES = new Set(["estimate", "invoice", "receipt", "purchaseOrder", "paymentNotice"]);
const TAX_VISIBLE_DOCUMENT_TYPES = new Set(["estimate", "invoice", "receipt", "purchaseOrder", "paymentNotice"]);
const DUE_DATE_VISIBLE_DOCUMENT_TYPES = new Set(["invoice", "paymentNotice"]);
const PAYMENT_DETAILS_VISIBLE_DOCUMENT_TYPES = new Set(["invoice"]);
const ISSUER_REGISTRATION_VISIBLE_DOCUMENT_TYPES = new Set(["invoice", "receipt"]);

function documentPresentationRules(type) {
  const isAttachmentRecord = ATTACHMENT_RECORD_DOCUMENT_TYPES.has(type);
  const showPrices = PRICE_VISIBLE_DOCUMENT_TYPES.has(type);
  return {
    isAttachmentRecord,
    showDueDate: DUE_DATE_VISIBLE_DOCUMENT_TYPES.has(type),
    showLinePrices: showPrices,
    showSummaryTotals: showPrices,
    showTax: TAX_VISIBLE_DOCUMENT_TYPES.has(type),
    showPaymentDetails: PAYMENT_DETAILS_VISIBLE_DOCUMENT_TYPES.has(type),
    showIssuerRegistration: ISSUER_REGISTRATION_VISIBLE_DOCUMENT_TYPES.has(type),
    partnerHeading: isVendorDocumentType(type) ? "仕入先資訊" : "客戶資訊",
    partnerSubheading: isVendorDocumentType(type) ? "供應商與聯絡資料" : "收件方與聯絡資料",
    partnerNameLabel: isVendorDocumentType(type) ? "仕入先名稱" : "客戶名稱",
    partnerContactLabel: isVendorDocumentType(type) ? "仕入先聯絡人" : "客戶聯絡人",
    partnerPhoneLabel: isVendorDocumentType(type) ? "仕入先電話" : "客戶電話",
    partnerEmailLabel: isVendorDocumentType(type) ? "仕入先 Email" : "客戶 Email",
    partnerAddressLabel: isVendorDocumentType(type) ? "仕入先地址" : "客戶地址",
    partyFallback: isVendorDocumentType(type) ? "仕入先名" : "取引先名",
  };
}

const DESKTOP_SETTINGS_KEY = "shoko.forms.desktop.settings.v1";
const DESKTOP_HINTS_SEEN_KEY = "shoko.forms.desktop.hints.seen.v1";
const STAMP_IMAGE_KEY = "native.shokoForms.defaultStampImage.v1";
const STAMP_LIBRARY_KEY = "shoko.forms.desktop.stamp.library.v1";

const APP_LANGUAGES = [
  { id: "japanese", title: "日本語", subtitle: "日本の帳票表現", locale: "ja-JP" },
  { id: "simplifiedChinese", title: "简体中文", subtitle: "中国大陆用语", locale: "zh-CN" },
  { id: "traditionalChinese", title: "繁體中文", subtitle: "繁體中文用語", locale: "zh-TW" },
  { id: "english", title: "English", subtitle: "United States wording", locale: "en-US" },
  { id: "korean", title: "한국어", subtitle: "한국어 업무 양식 표현", locale: "ko-KR" },
  { id: "nepali", title: "नेपाली", subtitle: "नेपाली इन्टरफेस", locale: "ne-NP" },
  { id: "french", title: "Français", subtitle: "Interface en français", locale: "fr-FR" },
  { id: "vietnamese", title: "Tiếng Việt", subtitle: "Giao diện tiếng Việt", locale: "vi-VN" },
];

const DESKTOP_SETTINGS_DEFAULTS = {
  interfaceLanguageId: detectSystemLanguageId(),
  pdfLanguageId: detectSystemLanguageId(),
  defaultColorTemplateId: "monochrome",
  guidanceEnabled: true,
};

const GuidanceContext = React.createContext({
  enabled: true,
  seenHintIds: [],
  dismissHint: () => {},
  resetHints: () => {},
});

const DEMO_BACKUP_URL = "/demo-data/shoko-forms-demo-100.shokobackup";

const DEFAULT_STAMP_SETTINGS = {
  normalizedCenterX: 0.5,
  normalizedCenterY: 0.5,
  scale: 1,
  rotation: 0,
  opacity: 0.82,
  brightness: 0,
  contrast: 1,
  appliesTint: false,
  removesWhiteBackground: true,
  tintRed: 1,
  tintGreen: 0,
  tintBlue: 0,
  cropTop: 0,
  cropBottom: 0,
  cropLeft: 0,
  cropRight: 0,
};

function clampNumber(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return min;
  return Math.min(max, Math.max(min, number));
}

function normalizeStampSettings(value) {
  const settings = value && typeof value === "object" ? value : {};
  return {
    normalizedCenterX: clampNumber(settings.normalizedCenterX ?? DEFAULT_STAMP_SETTINGS.normalizedCenterX, 0.05, 0.95),
    normalizedCenterY: clampNumber(settings.normalizedCenterY ?? DEFAULT_STAMP_SETTINGS.normalizedCenterY, 0.05, 0.95),
    scale: clampNumber(settings.scale ?? DEFAULT_STAMP_SETTINGS.scale, 0.25, 3),
    rotation: clampNumber(settings.rotation ?? DEFAULT_STAMP_SETTINGS.rotation, -180, 180),
    opacity: clampNumber(settings.opacity ?? DEFAULT_STAMP_SETTINGS.opacity, 0.1, 1),
    brightness: clampNumber(settings.brightness ?? DEFAULT_STAMP_SETTINGS.brightness, -0.5, 0.5),
    contrast: clampNumber(settings.contrast ?? DEFAULT_STAMP_SETTINGS.contrast, 0.4, 2),
    appliesTint: Boolean(settings.appliesTint ?? DEFAULT_STAMP_SETTINGS.appliesTint),
    removesWhiteBackground: Boolean(settings.removesWhiteBackground ?? DEFAULT_STAMP_SETTINGS.removesWhiteBackground),
    tintRed: clampNumber(settings.tintRed ?? DEFAULT_STAMP_SETTINGS.tintRed, 0, 1),
    tintGreen: clampNumber(settings.tintGreen ?? DEFAULT_STAMP_SETTINGS.tintGreen, 0, 1),
    tintBlue: clampNumber(settings.tintBlue ?? DEFAULT_STAMP_SETTINGS.tintBlue, 0, 1),
    cropTop: clampNumber(settings.cropTop ?? DEFAULT_STAMP_SETTINGS.cropTop, 0, 0.45),
    cropBottom: clampNumber(settings.cropBottom ?? DEFAULT_STAMP_SETTINGS.cropBottom, 0, 0.45),
    cropLeft: clampNumber(settings.cropLeft ?? DEFAULT_STAMP_SETTINGS.cropLeft, 0, 0.45),
    cropRight: clampNumber(settings.cropRight ?? DEFAULT_STAMP_SETTINGS.cropRight, 0, 0.45),
  };
}

function makeStableId(prefix = "id") {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function getLocalStorageItem(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function setLocalStorageItem(key, value) {
  try {
    localStorage.setItem(key, value);
    return true;
  } catch {
    return false;
  }
}

function removeLocalStorageItem(key) {
  try {
    localStorage.removeItem(key);
  } catch {
    // Local storage may be unavailable in some desktop webview states.
  }
}

function makeStampRecord(dataUrl, name = "印章") {
  const now = new Date().toISOString();
  return {
    id: makeStableId("stamp"),
    name: String(name || "印章").replace(/\.[^.]+$/, "") || "印章",
    dataUrl,
    createdAt: now,
    updatedAt: now,
  };
}

function sanitizeStampRecord(record) {
  if (!record || typeof record !== "object" || !record.dataUrl) return null;
  return {
    id: record.id || makeStableId("stamp"),
    name: String(record.name || "印章"),
    dataUrl: String(record.dataUrl),
    createdAt: record.createdAt || new Date().toISOString(),
    updatedAt: record.updatedAt || record.createdAt || new Date().toISOString(),
  };
}

function loadStoredStamps() {
  let stamps = [];
  try {
    const parsed = JSON.parse(getLocalStorageItem(STAMP_LIBRARY_KEY) || "[]");
    stamps = Array.isArray(parsed) ? parsed.map(sanitizeStampRecord).filter(Boolean) : [];
  } catch {
    stamps = [];
  }
  const legacyImage = getLocalStorageItem(STAMP_IMAGE_KEY) || "";
  if (legacyImage && !stamps.some((stamp) => stamp.dataUrl === legacyImage)) {
    stamps = [makeStampRecord(legacyImage, "預設印章"), ...stamps];
    saveStoredStamps(stamps);
  }
  return stamps;
}

function saveStoredStamps(stamps) {
  const cleanStamps = Array.isArray(stamps) ? stamps.map(sanitizeStampRecord).filter(Boolean) : [];
  setLocalStorageItem(STAMP_LIBRARY_KEY, JSON.stringify(cleanStamps));
  if (cleanStamps[0]?.dataUrl) setLocalStorageItem(STAMP_IMAGE_KEY, cleanStamps[0].dataUrl);
  else removeLocalStorageItem(STAMP_IMAGE_KEY);
  return cleanStamps;
}

function loadStoredStampImage() {
  return loadStoredStamps()[0]?.dataUrl || "";
}

function saveStoredStampImage(dataUrl) {
  if (dataUrl) saveStoredStamps([makeStampRecord(dataUrl, "預設印章")]);
  else saveStoredStamps([]);
}

function resolveStampId(document, stamps) {
  if (!stamps.length) return "";
  if (document?.stampImageId && stamps.some((stamp) => stamp.id === document.stampImageId)) {
    return document.stampImageId;
  }
  return stamps[0].id;
}

function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(reader.error || new Error("無法讀取印章圖片。"));
    reader.readAsDataURL(file);
  });
}

function stampFilter(settings) {
  const brightness = 1 + Number(settings.brightness || 0);
  return `brightness(${brightness}) contrast(${settings.contrast})`;
}

function stampTint(settings) {
  const red = Math.round((settings.tintRed ?? 1) * 255);
  const green = Math.round((settings.tintGreen ?? 0) * 255);
  const blue = Math.round((settings.tintBlue ?? 0) * 255);
  return `rgb(${red}, ${green}, ${blue})`;
}

function stampTintHue(settings) {
  const red = clampNumber(settings.tintRed ?? 1, 0, 1);
  const green = clampNumber(settings.tintGreen ?? 0, 0, 1);
  const blue = clampNumber(settings.tintBlue ?? 0, 0, 1);
  const max = Math.max(red, green, blue);
  const min = Math.min(red, green, blue);
  const delta = max - min;
  if (delta === 0) return 0;
  let hue = 0;
  if (max === red) hue = ((green - blue) / delta) % 6;
  else if (max === green) hue = (blue - red) / delta + 2;
  else hue = (red - green) / delta + 4;
  return Math.round((hue * 60 + 360) % 360);
}

function stampImageStyle(settings) {
  const tintFilter = settings.appliesTint ? ` sepia(1) saturate(8) hue-rotate(${stampTintHue(settings) - 38}deg)` : "";
  return {
    filter: `${stampFilter(settings)}${tintFilter}`,
    mixBlendMode: settings.removesWhiteBackground ? "multiply" : "normal",
    opacity: settings.opacity,
  };
}

function stampOverlayStyle(settings) {
  return {
    ...stampImageStyle(settings),
    left: `${settings.normalizedCenterX * 100}%`,
    top: `${settings.normalizedCenterY * 100}%`,
    transform: `translate(-50%, -50%) rotate(${settings.rotation}deg)`,
    width: `${190 * settings.scale}px`,
  };
}

function recordDisplayName(record) {
  return record?.name || record?.title || record?.number || "未命名資料";
}

function normalizedProfileKey(value) {
  return String(value ?? "").trim().toLowerCase();
}

function customerUsageCount(documents, customer) {
  const name = normalizedProfileKey(customer?.name);
  if (!name) return 0;
  return (documents ?? []).filter((document) => normalizedProfileKey(document.customerName) === name).length;
}

function productUsageCount(documents, product) {
  const name = normalizedProfileKey(product?.name);
  if (!name) return 0;
  const model = normalizedProfileKey(product?.model);
  const specification = normalizedProfileKey(product?.specification);
  return (documents ?? []).filter((document) =>
    (document.lines ?? []).some((line) => {
      if (normalizedProfileKey(line.name) !== name) return false;
      const lineModel = normalizedProfileKey(line.model);
      const lineSpecification = normalizedProfileKey(line.specification);
      return (!model || model === lineModel) && (!specification || specification === lineSpecification);
    }),
  ).length;
}

function recordUsageCount(collection, backup, record) {
  if (collection === "customers") return customerUsageCount(backup.documents, record);
  if (collection === "products") return productUsageCount(backup.documents, record);
  return 0;
}

function sanitizeDesktopSettings(value) {
  return {
    interfaceLanguageId: APP_LANGUAGES.some((language) => language.id === value?.interfaceLanguageId)
      ? value.interfaceLanguageId
      : DESKTOP_SETTINGS_DEFAULTS.interfaceLanguageId,
    pdfLanguageId: APP_LANGUAGES.some((language) => language.id === value?.pdfLanguageId)
      ? value.pdfLanguageId
      : DESKTOP_SETTINGS_DEFAULTS.pdfLanguageId,
    defaultColorTemplateId: PDF_COLOR_TEMPLATES[value?.defaultColorTemplateId]
      ? value.defaultColorTemplateId
      : DESKTOP_SETTINGS_DEFAULTS.defaultColorTemplateId,
    guidanceEnabled: typeof value?.guidanceEnabled === "boolean"
      ? value.guidanceEnabled
      : DESKTOP_SETTINGS_DEFAULTS.guidanceEnabled,
  };
}

function loadDesktopSettings() {
  try {
    return sanitizeDesktopSettings(JSON.parse(localStorage.getItem(DESKTOP_SETTINGS_KEY) || "{}"));
  } catch {
    return DESKTOP_SETTINGS_DEFAULTS;
  }
}

function saveDesktopSettings(nextSettings) {
  localStorage.setItem(DESKTOP_SETTINGS_KEY, JSON.stringify(nextSettings));
}

function loadSeenHints() {
  try {
    const parsed = JSON.parse(localStorage.getItem(DESKTOP_HINTS_SEEN_KEY) || "[]");
    return Array.isArray(parsed) ? parsed.filter((id) => typeof id === "string") : [];
  } catch {
    return [];
  }
}

function saveSeenHints(hintIds) {
  localStorage.setItem(DESKTOP_HINTS_SEEN_KEY, JSON.stringify([...new Set(hintIds)]));
}

function makeDeletedDocumentRecords(documents) {
  const deletedAt = new Date().toISOString();
  return documents.map((document) => ({
    id: crypto.randomUUID(),
    document,
    deletedAt,
  }));
}

function moveDocumentsToDeletedHistory(backup, ids) {
  const targetIds = new Set(ids);
  const movingDocuments = (backup.documents ?? []).filter((document) => targetIds.has(document.id));
  const nextDocuments = (backup.documents ?? []).filter((document) => !targetIds.has(document.id));
  const movingDocumentIds = new Set(movingDocuments.map((document) => document.id));
  const retainedDeleted = (backup.deletedDocuments ?? []).filter((record) => !movingDocumentIds.has(record.document?.id));
  const deletedDocuments = pruneDeletedDocuments([...makeDeletedDocumentRecords(movingDocuments), ...retainedDeleted]);
  const draft = targetIds.has(backup.draft?.id) ? nextDocuments[0] ?? null : backup.draft;
  return { ...backup, documents: nextDocuments, deletedDocuments, draft };
}

function restoreDeletedDocumentRecords(backup, recordIds) {
  const ids = new Set(recordIds);
  const records = (backup.deletedDocuments ?? []).filter((record) => ids.has(record.id));
  const existingDocumentIds = new Set((backup.documents ?? []).map((document) => document.id));
  const restoredDocuments = records
    .map((record) => record.document)
    .filter((document) => document?.id && !existingDocumentIds.has(document.id));
  const deletedDocuments = pruneDeletedDocuments((backup.deletedDocuments ?? []).filter((record) => !ids.has(record.id)));
  return {
    ...backup,
    documents: [...restoredDocuments, ...(backup.documents ?? [])].sort(newestFirst),
    deletedDocuments,
    draft: backup.draft ?? restoredDocuments[0] ?? null,
  };
}

function settingsText(languageId = "japanese") {
  const copy = {
    japanese: {
      pageEyebrow: "設定",
      pageTitle: "アプリ管理",
      pageDescription: "バックアップ、保存先、認証情報、表示設定をここで管理します。",
      stats: { documents: "帳票", customers: "顧客", issuers: "発行者", products: "商品" },
      cards: {
        language: ["言語", "操作画面と PDF 帳票の言語を分けて管理します。", "確認して適用"],
        color: ["帳票カラー", "新規帳票と現在の帳票に使う配色を選びます。", "確認して適用"],
        guidance: ["初回ガイド", "初めて使う画面や機能に操作ヒントを表示します。", "ガイド"],
        backup: ["バックアップと読み込み", "iOS またはデスクトップ版のバックアップを読み込み、現在の資料を書き出します。", "保存資料"],
        storage: ["ローカルフォルダ", "保存先フォルダを指定し、ローカルデータの場所を確認します。", "保存先"],
        license: ["デスクトップ認証", "認証状態を確認し、ログアウトできます。", "認証"],
        support: ["カスタマーサービス", "サポート、問い合わせ、必要情報を確認します。", "サポート"],
        guide: ["使用ガイド", "デスクトップ版の基本操作、PDF、バックアップ、安全上の注意。", "手順書"],
      },
      languageTitle: "言語",
      languageHeading: "言語設定",
      languageDescription: "iOS App と同じように、操作画面の言語と PDF 帳票の言語を別々に管理します。選択後、確認ボタンで反映します。",
      interfaceLanguage: "操作画面の言語",
      pdfLanguage: "PDF 帳票の言語",
      colorTitle: "帳票カラー",
      colorHeading: "帳票カラー",
      colorDescription: "選択した配色は新規帳票の標準になります。現在編集中の帳票がある場合は、確認後にその帳票にも適用されます。",
      guidanceTitle: "初回ガイド",
      guidanceHeading: "操作ヒント",
      guidanceDescription: "オンにすると、まだ確認していない画面、ボタン、データ入力エリアに短い説明が表示されます。オフにすると既読状態に関係なく非表示になります。",
      guidanceEnabled: "ヒントを表示する",
      guidanceOn: "表示中",
      guidanceOff: "非表示",
      resetGuidance: "ヒントをリセット",
      selectedColor: "選択中の配色",
      applyLanguage: "言語を適用",
      applyColor: "配色を適用",
      cancel: "キャンセル",
      close: "閉じる",
      backupTitle: "バックアップと読み込み",
      storageTitle: "ローカルフォルダ",
      licenseTitle: "デスクトップ認証",
      supportTitle: "カスタマーサービス",
      guideTitle: "使用ガイド",
    },
    simplifiedChinese: {
      pageEyebrow: "设置",
      pageTitle: "应用管理",
      pageDescription: "备份、资料夹、授权资料、语言与配色集中在这里管理。",
      stats: { documents: "帐票", customers: "客户", issuers: "发行者", products: "商品" },
      cards: {
        language: ["语言", "分开管理操作界面语言与 PDF 帐票语言。", "确认套用"],
        color: ["帐票配色", "选择新建表单与当前表单使用的模板颜色。", "确认套用"],
        guidance: ["启动提示", "第一次使用功能、点击按钮或填写资料时显示简短指引。", "提示"],
        backup: ["备份与导入", "导入 iOS 或桌面版备份，导出当前全部资料。", "资料保存"],
        storage: ["本地资料夹", "指定资料保存位置，查看本机资料路径。", "保存位置"],
        license: ["桌面版授权", "查看授权状态，或登出授权码回到登录页。", "授权"],
        support: ["客户服务", "售后服务、技术支持与联系信息。", "支持"],
        guide: ["使用需知", "桌面端操作、PDF、备份与资料安全完整说明。", "手册"],
      },
      languageTitle: "语言",
      languageHeading: "语言设置",
      languageDescription: "与 iOS App 一样，操作界面语言与 PDF 帐票语言分开管理。选择后需按确认按钮才会生效。",
      interfaceLanguage: "操作界面语言",
      pdfLanguage: "PDF 帐票语言",
      colorTitle: "帐票配色",
      colorHeading: "帐票配色",
      colorDescription: "选取的配色会保存为新建表单的默认配色；如果当前正在编辑表单，确认后也会套用到当前表单。",
      guidanceTitle: "启动提示",
      guidanceHeading: "新手提示功能",
      guidanceDescription: "开启后，尚未看过的页面、功能按钮、资料输入区会显示小提示，协助第一次使用者理解流程。关闭后所有提示都会隐藏。",
      guidanceEnabled: "显示新手提示",
      guidanceOn: "已开启",
      guidanceOff: "已关闭",
      resetGuidance: "重置已看提示",
      selectedColor: "当前选择配色",
      applyLanguage: "确认套用语言",
      applyColor: "确认套用配色",
      cancel: "取消",
      close: "关闭",
      backupTitle: "备份与导入",
      storageTitle: "本地资料夹",
      licenseTitle: "桌面版授权",
      supportTitle: "客户服务",
      guideTitle: "使用需知",
    },
    english: {
      pageEyebrow: "Settings",
      pageTitle: "Application Management",
      pageDescription: "Manage backups, folders, license data, language, and color defaults in one place.",
      stats: { documents: "Forms", customers: "Customers", issuers: "Issuers", products: "Products" },
      cards: {
        language: ["Language", "Manage the interface language and PDF output language separately.", "Confirm"],
        color: ["Document Colors", "Choose the default color template for new and current forms.", "Confirm"],
        guidance: ["First-use Tips", "Show short prompts on screens, actions, and data entry areas the first time they are used.", "Tips"],
        backup: ["Backup and Import", "Import iOS or desktop backups and export the current local data.", "Local data"],
        storage: ["Local Folder", "Choose the data folder and review local storage paths.", "Storage"],
        license: ["Desktop License", "Review license status or log out to return to the login page.", "License"],
        support: ["Customer Service", "Support, contact details, and information needed for help.", "Support"],
        guide: ["User Guide", "Desktop workflow, PDF, backup, and data safety manual.", "Manual"],
      },
      languageTitle: "Language",
      languageHeading: "Language Settings",
      languageDescription: "As in the iOS app, the operator interface language and customer-facing PDF language are managed separately. Changes apply after confirmation.",
      interfaceLanguage: "Interface Language",
      pdfLanguage: "PDF Language",
      colorTitle: "Document Colors",
      colorHeading: "Document Colors",
      colorDescription: "The selected palette becomes the default for new forms. If a form is open, confirmation also applies it to the current form.",
      guidanceTitle: "First-use Tips",
      guidanceHeading: "Guided Hints",
      guidanceDescription: "When enabled, screens, action buttons, and data entry areas show concise guidance until the user dismisses each tip.",
      guidanceEnabled: "Show first-use tips",
      guidanceOn: "Enabled",
      guidanceOff: "Disabled",
      resetGuidance: "Reset Seen Tips",
      selectedColor: "Selected Palette",
      applyLanguage: "Apply Language",
      applyColor: "Apply Colors",
      cancel: "Cancel",
      close: "Close",
      backupTitle: "Backup and Import",
      storageTitle: "Local Folder",
      licenseTitle: "Desktop License",
      supportTitle: "Customer Service",
      guideTitle: "User Guide",
    },
  };
  if (languageId === "traditionalChinese") return copy.simplifiedChinese;
  if (["korean", "nepali", "french", "vietnamese"].includes(languageId)) return copy.english;
  return copy[languageId] ?? copy.japanese;
}

function App() {
  const [paths, setPaths] = useState(null);
  const [backup, setBackup] = useState(null);
  const [licenseStatus, setLicenseStatus] = useState(() => verifyLicenseKey(loadStoredLicense()));
  const [activeView, setActiveView] = useState("home");
  const [activeDocumentDirection, setActiveDocumentDirection] = useState("customer");
  const [selectedDocumentIds, setSelectedDocumentIds] = useState({ customer: null, vendor: null });
  const [selectedRecordIds, setSelectedRecordIds] = useState({});
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("啟動中");
  const [importMode, setImportMode] = useState("merge");
  const [activeDataSection, setActiveDataSection] = useState("files");
  const [documentModalOpen, setDocumentModalOpen] = useState(false);
  const [documentModalInitialDirection, setDocumentModalInitialDirection] = useState("customer");
  const [documentModalInitialMode, setDocumentModalInitialMode] = useState("existing");
  const [documentListModalOpen, setDocumentListModalOpen] = useState(false);
  const [formProjectModal, setFormProjectModal] = useState(null);
  const [previewDocument, setPreviewDocument] = useState(null);
  const [recordModal, setRecordModal] = useState(null);
  const [noticeModal, setNoticeModal] = useState(null);
  const [deleteConfirmModal, setDeleteConfirmModal] = useState(null);
  const [unsavedLeaveModal, setUnsavedLeaveModal] = useState(null);
  const [externalImportModal, setExternalImportModal] = useState(null);
  const [dirtyDocumentIds, setDirtyDocumentIds] = useState(() => new Set());
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [storageSetupOpen, setStorageSetupOpen] = useState(false);
  const [nativeOperation, setNativeOperation] = useState(null);
  const [appSettings, setAppSettings] = useState(() => loadDesktopSettings());
  const [seenHintIds, setSeenHintIds] = useState(() => loadSeenHints());
  const savedBackupRef = useRef(null);
  const nativeOperationRef = useRef(null);
  const stampSaveSequenceRef = useRef(0);

  useEffect(() => {
    setLicenseStatus(verifyLicenseKey(loadStoredLicense()));
    bootApp();
  }, []);

  useEffect(() => {
    if (!isTauri()) return undefined;
    let unlisten = null;
    listen("external-files-opened", (event) => {
      const openedFiles = normalizeExternalOpenPaths(event.payload);
      if (!openedFiles.length) return;
      setExternalImportModal({ paths: openedFiles });
      setStatus("已接收系統開啟的檔案，請選擇導入項目與表單");
    }).then((handler) => {
      unlisten = handler;
    });
    return () => {
      if (unlisten) unlisten();
    };
  }, []);

  async function bootApp() {
    try {
      const initialPaths = await initStorage();
      setPaths(initialPaths);
      const loaded = normalizeBackup(await loadState());
      savedBackupRef.current = loaded;
      setBackup(loaded);
      setSelectedDocumentIds({
        customer: null,
        vendor: null,
      });
      setActiveDocumentDirection("customer");
      setSelectedRecordIds({
        customers: loaded.customers[0]?.id ?? null,
        issuers: loaded.issuers[0]?.id ?? null,
        products: loaded.products[0]?.id ?? null,
        templates: null,
      });
      setStatus("本地資料夾已就緒");
      const firstRunStatus = await getFirstRunStatus();
      if (firstRunStatus.shouldShowSetup) {
        setStorageSetupOpen(true);
      }
      const openedFiles = normalizeExternalOpenPaths(await pendingOpenFiles());
      if (openedFiles.length) {
        setExternalImportModal({ paths: openedFiles });
        setStatus("已接收系統開啟的檔案，請選擇導入項目與表單");
      }
    } catch (error) {
      setBackup(normalizeBackup({ version: 1, documents: [], customers: [], issuers: [], products: [] }));
      setStatus(error.message);
    }
  }

  const allDocuments = backup?.documents ?? [];
  const documents = allDocuments.filter((document) => !isHiddenDocumentType(document.type));
  const deletedDocuments = backup?.deletedDocuments ?? [];
  const visibleBackup = useMemo(() => (backup ? { ...backup, documents, deletedDocuments } : backup), [backup, documents, deletedDocuments]);
  const documentsForActiveDirection = useMemo(
    () => documents.filter((document) => documentDirectionForDocumentType(document.type) === activeDocumentDirection),
    [activeDocumentDirection, documents],
  );
  const selectedDocument =
    documentsForActiveDirection.find((document) => document.id === selectedDocumentIds[activeDocumentDirection]) ?? null;
  const selectedDocumentDirty = Boolean(selectedDocument && dirtyDocumentIds.has(selectedDocument.id));
  const isNativeOperationPending = Boolean(nativeOperation);

  async function runNativeOperation(label, action) {
    if (nativeOperationRef.current) {
      setStatus(`${nativeOperationRef.current}處理中，請稍候。`);
      return null;
    }
    nativeOperationRef.current = label;
    setNativeOperation(label);
    try {
      return await action();
    } finally {
      nativeOperationRef.current = null;
      setNativeOperation(null);
    }
  }

  const filteredDocuments = useMemo(() => {
    const clean = query.trim().toLowerCase();
    if (!clean) return documents;
    return documents.filter((document) =>
      [
        document.number,
        document.projectName,
        document.customerName,
        document.issuerName,
        document.type,
        document.documentMemo,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
        .includes(clean),
    );
  }, [documents, query]);

  function handleDocumentDirectionChange(direction) {
    const nextDirection = DOCUMENT_DIRECTION_GROUPS[direction] ? direction : "customer";
    requestLeaveEditor(() => setActiveDocumentDirection(nextDirection));
  }

  function hasUnsavedSelectedDocument() {
    return Boolean(activeView === "documents" && selectedDocument && dirtyDocumentIds.has(selectedDocument.id));
  }

  function markDocumentDirty(documentId) {
    if (!documentId) return;
    setDirtyDocumentIds((current) => {
      const next = new Set(current);
      next.add(documentId);
      return next;
    });
  }

  function updateLocalBackup(nextBackup, message = "已有未保存變更") {
    setBackup(nextBackup);
    setStatus(message);
  }

  function closeSelectedDocumentToBlank() {
    setSelectedDocumentIds({ customer: null, vendor: null });
    setActiveView("documents");
  }

  function discardUnsavedDocument() {
    if (savedBackupRef.current) {
      setBackup(savedBackupRef.current);
    }
    setDirtyDocumentIds(new Set());
    closeSelectedDocumentToBlank();
    setUnsavedLeaveModal(null);
    setStatus("已放棄未保存變更");
  }

  function requestLeaveEditor(action) {
    if (!hasUnsavedSelectedDocument()) {
      action();
      return;
    }
    setUnsavedLeaveModal({ action });
  }

  async function saveCurrentDocument(showNotice = true) {
    if (!backup || !selectedDocument) return;
    await persist(backup, "保存完成");
    if (showNotice) {
      setNoticeModal({
        title: "保存完成",
        message: `帳票「${selectedDocument.number || "未命名帳票"}」已保存到本地資料夾。`,
        details: ["保存狀態已更新為已保存。"],
      });
    }
  }

  async function saveUnsavedAndContinue() {
    const action = unsavedLeaveModal?.action;
    setUnsavedLeaveModal(null);
    await saveCurrentDocument(false);
    if (action) action();
  }

  function saveDocumentStampState(documentId, patch) {
    if (!backup || !documentId) return;
    const normalizedPatch = {};
    if (patch.stampSettings) {
      normalizedPatch.stampSettings = normalizeStampSettings(patch.stampSettings);
    }
    if (typeof patch.stampVisible === "boolean") {
      normalizedPatch.stampVisible = patch.stampVisible;
    }
    if ("stampImageId" in patch) {
      normalizedPatch.stampImageId = patch.stampImageId || null;
    }
    const updatedDocuments = allDocuments.map((document) =>
      document.id === documentId
        ? { ...document, ...normalizedPatch, updatedAt: new Date().toISOString() }
        : document,
    );
    const updatedDraft =
      backup.draft?.id === documentId
        ? { ...backup.draft, ...normalizedPatch, updatedAt: new Date().toISOString() }
        : backup.draft;
    const updatedPreview =
      previewDocument?.id === documentId
        ? { ...previewDocument, ...normalizedPatch, updatedAt: new Date().toISOString() }
        : previewDocument;
    const next = { ...backup, documents: updatedDocuments, draft: updatedDraft };
    const sequence = stampSaveSequenceRef.current + 1;
    stampSaveSequenceRef.current = sequence;
    setBackup(next);
    setPreviewDocument(updatedPreview);
    setStatus("已保存此帳票的印章設定");
    saveState(next)
      .then((saved) => {
        if (stampSaveSequenceRef.current !== sequence) return;
        savedBackupRef.current = saved;
        setBackup(saved);
      })
      .catch((error) => setStatus(error.message));
  }

  function selectDocumentDirect(document) {
    const direction = documentDirectionForDocumentType(document.type);
    setSelectedDocumentIds((ids) => ({ ...ids, [direction]: document.id }));
    setActiveDocumentDirection(direction);
    setActiveView("documents");
  }

  function selectDocument(document) {
    requestLeaveEditor(() => selectDocumentDirect(document));
  }

  function openDocumentsLanding() {
    requestLeaveEditor(() => {
      closeSelectedDocumentToBlank();
    });
  }

  function navigateToView(view) {
    if (view === "documents") {
      openDocumentsLanding();
      return;
    }
    requestLeaveEditor(() => setActiveView(view));
  }

  function openDataSection(section = "files") {
    requestLeaveEditor(() => {
      setActiveDataSection(section === "hub" ? "files" : section);
      setActiveView("data");
    });
  }

  async function persist(nextBackup, message = "已保存到本地資料夾") {
    const saved = await saveState(nextBackup);
    savedBackupRef.current = saved;
    setBackup(saved);
    setDirtyDocumentIds(new Set());
    setSelectedDocumentIds((ids) => {
      const nextIds = { ...ids };
      for (const direction of Object.keys(DOCUMENT_DIRECTION_GROUPS)) {
        if (!saved.documents.some((document) => document.id === nextIds[direction])) {
          nextIds[direction] = null;
        }
      }
      return nextIds;
    });
    setStatus(message);
  }

  async function handleFileImport(event) {
    const file = event.target.files?.[0];
    if (!file || !backup) return;
    if (nativeOperationRef.current) {
      setStatus(`${nativeOperationRef.current}處理中，請稍候。`);
      event.target.value = "";
      return;
    }
    try {
      nativeOperationRef.current = "匯入備份";
      setNativeOperation("匯入備份");
      const text = await file.text();
      const next = await importBackupText(text, importMode, backup);
      savedBackupRef.current = next;
      setBackup(next);
      setDirtyDocumentIds(new Set());
      setSelectedDocumentIds({
        customer: null,
        vendor: null,
      });
      setActiveDocumentDirection("customer");
      setSelectedRecordIds({
        customers: next.customers[0]?.id ?? null,
        issuers: next.issuers[0]?.id ?? null,
        products: next.products[0]?.id ?? null,
        templates: null,
      });
      const message = importMode === "replace" ? "已用備份檔重建本地資料" : "已合併備份檔，既有資料保留";
      setStatus(message);
      setNoticeModal({
        title: "匯入完成",
        message,
        details: [
          `帳票 ${next.documents.length} 份`,
          `客戶 ${next.customers.length} 筆`,
          `公司 ${next.issuers.length} 筆`,
          `商品 ${next.products.length} 筆`,
        ],
      });
    } catch (error) {
      setStatus(error.message);
    } finally {
      nativeOperationRef.current = null;
      setNativeOperation(null);
      event.target.value = "";
    }
  }

  async function handleExport() {
    if (!backup) return;
    await runNativeOperation("匯出備份", async () => {
      const path = await exportBackup(backup);
      setStatus(`已建立備份：${path}`);
    }).catch((error) => setStatus(error.message));
  }

  async function handleImportDemoBackup() {
    if (!backup) return;
    await runNativeOperation("匯入 demo", async () => {
      const response = await fetch(DEMO_BACKUP_URL);
      if (!response.ok) {
        throw new Error("無法讀取內建 demo 檔案。");
      }
      const text = await response.text();
      const next = await importBackupText(text, "replace", backup);
      savedBackupRef.current = next;
      setBackup(next);
      setDirtyDocumentIds(new Set());
      setSelectedDocumentIds({
        customer: null,
        vendor: null,
      });
      setActiveDocumentDirection("customer");
      setSelectedRecordIds({
        customers: next.customers[0]?.id ?? null,
        issuers: next.issuers[0]?.id ?? null,
        products: next.products[0]?.id ?? null,
        templates: null,
      });
      setStatus("已導入 demo 測試文件");
      setNoticeModal({
        title: "Demo 導入完成",
        message: "已用內建 demo 檔案建立測試資料。",
        details: [
          `帳票 ${next.documents.length} 份`,
          `客戶 ${next.customers.length} 筆`,
          `公司 ${next.issuers.length} 筆`,
          `商品 ${next.products.length} 筆`,
        ],
      });
    }).catch((error) => setStatus(error.message));
  }

  function handleDeleteAllDocuments() {
    const count = documents.length;
    if (!count) {
      setStatus("目前沒有可刪除的文件");
      return;
    }
    requestDeleteConfirmation({
      title: "刪除全部文件",
      message: `確定要刪除全部 ${count} 份文件？`,
      details: [
        "此操作只會刪除帳票/文件資料。",
        "客戶、公司、商品、模板等主檔資料會保留。",
        "文件會移到刪除歷史，30 天內可還原。",
      ],
      confirmLabel: "確認刪除全部文件",
      onConfirm: async () => {
        const next = moveDocumentsToDeletedHistory(backup, documents.map((document) => document.id));
        setSelectedDocumentIds({ customer: null, vendor: null });
        setPreviewDocument(null);
        setDocumentListModalOpen(false);
        setDirtyDocumentIds(new Set());
        await persist(next, "已刪除全部文件");
      },
    });
  }

  async function handleAddDocument(options = {}) {
    requestLeaveEditor(() => {
      setDocumentModalInitialDirection(activeDocumentDirection);
      setDocumentModalInitialMode(options.initialMode ?? "existing");
      setDocumentModalOpen(true);
    });
  }

  async function createDocumentFromModal(documentDraft) {
    const document = {
      ...documentDraft,
      colorTemplateId: documentDraft.colorTemplateId || appSettings.defaultColorTemplateId,
      updatedAt: new Date().toISOString(),
    };
    const next = { ...backup, documents: [document, ...allDocuments], draft: document };
    setDocumentModalOpen(false);
    await persist(next, "已建立新帳票草稿");
    setSelectedDocumentIds((ids) => ({ ...ids, [documentDirectionForDocumentType(document.type)]: document.id }));
    setActiveDocumentDirection(documentDirectionForDocumentType(document.type));
    setActiveView("documents");
  }

  function openFormProjectFlow(type) {
    requestLeaveEditor(() => setFormProjectModal({ type }));
  }

  async function createDocumentInProject(type, project, mode = "append") {
    const direction = documentDirectionForDocumentType(type);
    const isOverwrite = mode === "overwrite" || mode === "overwriteConfirmed";
    const currentProject = {
      ...project,
      direction,
      documents: project.documents ?? [],
    };
    if (mode === "overwrite") {
      requestDeleteConfirmation({
        title: "覆蓋既有表單",
        message: `覆蓋會刪除項目「${currentProject.name || "未命名項目"}」內既有的 ${DOCUMENT_TYPE_LABELS[type] ?? type}。`,
        details: ["此操作會先移除同類既有表單，再建立新表單。", "覆蓋後無法復原原本表單。"],
        confirmLabel: "確認覆蓋",
        onConfirm: async () => createDocumentInProject(type, project, "overwriteConfirmed"),
      });
      return;
    }
    const document = {
      ...buildDocumentForProject(type, currentProject, direction),
      colorTemplateId: appSettings.defaultColorTemplateId,
    };
    const nextDocuments =
      isOverwrite
        ? [
            document,
            ...allDocuments.filter(
              (item) =>
                !(
                  documentDirectionForDocumentType(item.type) === direction &&
                  sameProjectName(item, currentProject.name) &&
                  item.type === type
                ),
            ),
          ]
        : [document, ...allDocuments];
    setFormProjectModal(null);
    await persist(
      { ...backup, documents: nextDocuments, draft: document },
      isOverwrite ? "已覆蓋項目內既有表單，請確認新表單內容" : "已將表單放入項目",
    );
    setSelectedDocumentIds((ids) => ({ ...ids, [direction]: document.id }));
    setActiveDocumentDirection(direction);
    setActiveView("documents");
  }

  async function importExternalFilesToForm({ paths, direction, project, type }) {
    if (!paths?.length) {
      setStatus("沒有可導入的檔案");
      return;
    }
    try {
      const files = await Promise.all(paths.map(readBinaryFile));
      const attachments = files.map(externalFileToOrderAttachment);
      const currentProject =
        project ?? {
          name: defaultNewProjectName(direction, ""),
          direction,
          partnerName: "未填寫客戶/供應商",
          documents: [],
        };
      const existing = project?.documents
        ?.filter((document) => document.type === type)
        .sort(newestFirst)[0];
      const baseDocument = existing
        ? { ...existing }
        : {
            ...buildDocumentForProject(type, currentProject, direction),
            colorTemplateId: appSettings.defaultColorTemplateId,
          };
      const document = {
        ...baseDocument,
        orderAttachments: [...(baseDocument.orderAttachments ?? []), ...attachments],
        updatedAt: new Date().toISOString(),
      };
      const nextDocuments = existing
        ? allDocuments.map((item) => (item.id === document.id ? document : item))
        : [document, ...allDocuments];
      await persist({ ...backup, documents: nextDocuments, draft: document }, "已將系統檔案導入表單");
      setExternalImportModal(null);
      selectDocumentDirect(document);
    } catch (error) {
      setStatus(error.message);
    }
  }

  function requestDeleteConfirmation({ title = "確認刪除", message, details = [], confirmLabel = "確認刪除", onConfirm }) {
    setDeleteConfirmModal({ title, message, details, confirmLabel, onConfirm });
  }

  async function runDeleteConfirmation() {
    const action = deleteConfirmModal?.onConfirm;
    setDeleteConfirmModal(null);
    if (action) await action();
  }

  async function handleDeleteDocument() {
    if (!selectedDocument) return;
    requestDeleteConfirmation({
      title: "刪除帳票",
      message: `確定要刪除帳票「${selectedDocument.number || "未命名帳票"}」？`,
      details: ["文件會移到刪除歷史。", "30 天內可在設定的備份面板還原。"],
      onConfirm: async () => {
        const next = moveDocumentsToDeletedHistory(backup, [selectedDocument.id]);
        setSelectedDocumentIds((ids) => ({ ...ids, [activeDocumentDirection]: null }));
        await persist(next, "已移到刪除歷史");
      },
    });
  }

  async function handleDeleteDocuments(ids, message = "已刪除帳票", confirmMessage) {
    const targetIds = new Set(ids);
    if (!targetIds.size) return;
    const targetDocuments = documents.filter((document) => targetIds.has(document.id));
    const fallbackMessage =
      targetDocuments.length === 1
        ? `刪除帳票「${targetDocuments[0].number || DOCUMENT_TYPE_LABELS[targetDocuments[0].type] || "未命名帳票"}」？`
        : `刪除選取的 ${targetDocuments.length || targetIds.size} 份帳票？`;
    requestDeleteConfirmation({
      title: "刪除表單",
      message: confirmMessage || fallbackMessage,
      details: [
        `刪除數量：${targetDocuments.length || targetIds.size} 份`,
        "文件會移到刪除歷史，30 天內可還原。",
      ],
      onConfirm: async () => {
        const next = moveDocumentsToDeletedHistory(backup, targetIds);
        await persist(next, message === "已刪除帳票" ? "已移到刪除歷史" : message);
      },
    });
  }

  async function handleRestoreDeletedDocuments(ids) {
    const next = restoreDeletedDocumentRecords(backup, ids);
    await persist(next, "已還原刪除歷史中的文件");
  }

  async function handlePermanentlyDeleteRecords(ids) {
    const targetIds = new Set(ids);
    const next = {
      ...backup,
      deletedDocuments: pruneDeletedDocuments((backup.deletedDocuments ?? []).filter((record) => !targetIds.has(record.id))),
    };
    await persist(next, "已永久刪除所選歷史文件");
  }

  async function handleFieldChange(field, value) {
    if (!selectedDocument) return;
    if (isBlankInput(value)) {
      setStatus("空白欄位未保存");
      return;
    }
    const normalizedValue = ["taxRate", "paymentProofAmount"].includes(field) ? normalizeNumericInput(value) : value;
    let patch = { [field]: normalizedValue };
    if (field === "type") {
      const defaults = documentDefaultsForType(value);
      setActiveDocumentDirection(documentDirectionForDocumentType(value));
      patch = {
        ...patch,
        projectDirection: projectDirectionForDocumentType(value),
        notes: selectedDocument.notes?.trim() ? selectedDocument.notes : defaults.notes,
        documentMemo: selectedDocument.documentMemo?.trim() ? selectedDocument.documentMemo : defaults.documentMemo,
        paymentProofDate: isVendorDocumentType(value) ? (selectedDocument.paymentProofDate ?? defaults.paymentProofDate) : null,
        paymentProofAmount: isVendorDocumentType(value) ? (selectedDocument.paymentProofAmount ?? defaults.paymentProofAmount) : null,
        paymentProofAttachments: isVendorDocumentType(value) ? (selectedDocument.paymentProofAttachments ?? []) : [],
      };
    }
    const updated = { ...selectedDocument, ...patch, updatedAt: new Date().toISOString() };
    if (field === "type") {
      const nextDirection = documentDirectionForDocumentType(value);
      setSelectedDocumentIds((ids) => ({ ...ids, [nextDirection]: updated.id }));
    }
    const next = {
      ...backup,
      documents: allDocuments.map((document) => (document.id === updated.id ? updated : document)),
      draft: updated,
    };
    updateLocalBackup(next);
    markDocumentDirty(updated.id);
  }

  async function handleLineChange(index, field, value) {
    if (!selectedDocument) return;
    const lines = [...(selectedDocument.lines ?? [])];
    lines[index] = {
      ...lines[index],
      [field]: field === "quantity" || field === "unitPrice" ? normalizeNumericInput(value) : value,
    };
    await handleFieldChange("lines", lines);
  }

  async function handleAddLine() {
    if (!selectedDocument) return;
    await handleFieldChange("lines", [
      ...(selectedDocument.lines ?? []),
      { id: crypto.randomUUID(), name: "", model: "", specification: "", quantity: 1, unitPrice: 0 },
    ]);
  }

  async function handleDeleteLine(index) {
    if (!selectedDocument) return;
    const line = selectedDocument.lines?.[index];
    requestDeleteConfirmation({
      title: "刪除明細",
      message: `確定要刪除明細「${line?.name || `第 ${index + 1} 行`}」？`,
      details: ["刪除後無法復原。"],
      onConfirm: async () => {
        const lines = [...(selectedDocument.lines ?? [])];
        lines.splice(index, 1);
        await handleFieldChange("lines", lines);
      },
    });
  }

  async function handleOrderAttachmentUpload(files) {
    if (!selectedDocument || !files?.length) return;
    const attachments = await Promise.all(Array.from(files).map(fileToOrderAttachment));
    await handleFieldChange("orderAttachments", [
      ...(selectedDocument.orderAttachments ?? []),
      ...attachments,
    ]);
  }

  async function handleDeleteOrderAttachment(attachmentId) {
    if (!selectedDocument) return;
    await handleFieldChange(
      "orderAttachments",
      (selectedDocument.orderAttachments ?? []).filter((attachment) => attachment.id !== attachmentId),
    );
  }

  async function handleSelectCustomer(name) {
    const customer = backup.customers.find((record) => record.name === name);
    if (!customer || !selectedDocument) {
      await handleFieldChange("customerName", name);
      return;
    }
    await updateDocumentFields({
      customerName: customer.name,
      customerAddress: customer.address,
      customerContact: customer.contact,
      customerPhone: customer.phone,
      customerEmail: customer.email,
    });
  }

  async function handleSelectIssuer(name) {
    const issuer = backup.issuers.find((record) => record.name === name);
    if (!issuer || !selectedDocument) {
      await handleFieldChange("issuerName", name);
      return;
    }
    await updateDocumentFields({
      issuerName: issuer.name,
      issuerRegistration: issuer.registration,
      issuerAddress: issuer.address,
      issuerContact: issuer.contact,
      issuerPhone: issuer.phone,
      issuerEmail: issuer.email,
      issuerLogoData: issuer.logoData,
      issuerLogoScale: issuer.logoScale,
    });
  }

  async function updateDocumentFields(fields) {
    if (!selectedDocument) return;
    const updated = { ...selectedDocument, ...fields, updatedAt: new Date().toISOString() };
    updateLocalBackup(
      {
        ...backup,
        documents: allDocuments.map((document) => (document.id === updated.id ? updated : document)),
        draft: updated,
      },
      "已套用資料，尚未保存",
    );
    markDocumentDirty(updated.id);
  }

  function updateDesktopSettings(patch) {
    setAppSettings((current) => {
      const next = sanitizeDesktopSettings({ ...current, ...patch });
      saveDesktopSettings(next);
      setStatus("已更新桌面設定");
      return next;
    });
  }

  function dismissHint(hintId) {
    setSeenHintIds((current) => {
      if (current.includes(hintId)) return current;
      const next = [...current, hintId];
      saveSeenHints(next);
      return next;
    });
  }

  function resetHints() {
    saveSeenHints([]);
    setSeenHintIds([]);
    setStatus("已重置新手提示");
  }

  async function applyDefaultColorTemplate(templateId) {
    const next = sanitizeDesktopSettings({ ...appSettings, defaultColorTemplateId: templateId });
    saveDesktopSettings(next);
    setAppSettings(next);
    if (selectedDocument) {
      await updateDocumentFields({ colorTemplateId: next.defaultColorTemplateId });
    } else {
      setStatus("已更新預設帳票配色");
    }
  }

  async function handleSelectProduct(index, productName) {
    const product = backup.products.find((record) => record.name === productName);
    if (!product) {
      await handleLineChange(index, "name", productName);
      return;
    }
    const lines = [...(selectedDocument.lines ?? [])];
    lines[index] = {
      ...lines[index],
      name: product.name,
      model: product.model,
      specification: product.specification,
      unitPrice: Number(product.unitPrice || 0),
    };
    await handleFieldChange("lines", lines);
  }

  async function openProjectDocument(project, type) {
    const existingDocument = project.documents
      .filter((document) => document.type === type)
      .sort((left, right) => new Date(right.updatedAt) - new Date(left.updatedAt))[0];
    if (existingDocument) {
      selectDocument(existingDocument);
      return;
    }

    const document = { ...makeDocument(type), colorTemplateId: appSettings.defaultColorTemplateId };
    const nextDocument = {
      ...document,
      projectName: project.name === "未指定項目" ? "" : project.name,
      projectDirection: project.direction,
      customerName: project.partnerName === "未填寫客戶/供應商" ? "" : project.partnerName,
      updatedAt: new Date().toISOString(),
    };
    await createDocumentFromModal(nextDocument);
  }

  function createProject(direction) {
    const nextDirection = DOCUMENT_DIRECTION_GROUPS[direction] ? direction : "customer";
    setActiveDocumentDirection(nextDirection);
    setDocumentModalInitialDirection(nextDirection);
    setDocumentModalInitialMode("new");
    setDocumentModalOpen(true);
    setActiveDataSection("projects");
  }

  async function renameProject(project, nextName) {
    const cleanName = String(nextName ?? "").trim();
    if (!cleanName || cleanName === project.name) return;
    const updatedDocuments = allDocuments.map((document) =>
      documentDirectionForDocumentType(document.type) === project.direction && sameProjectName(document, project.name)
        ? { ...document, projectName: cleanName, updatedAt: new Date().toISOString() }
        : document,
    );
    const updatedDraft =
      backup.draft &&
      documentDirectionForDocumentType(backup.draft.type) === project.direction &&
      sameProjectName(backup.draft, project.name)
        ? { ...backup.draft, projectName: cleanName, updatedAt: new Date().toISOString() }
        : backup.draft;
    await persist({ ...backup, documents: updatedDocuments, draft: updatedDraft }, "已更新項目名稱");
  }

  async function updateProjectDetails(project, values) {
    const cleanName = String(values.name ?? "").trim();
    if (!cleanName) {
      setStatus("請輸入項目名稱");
      return;
    }
    const patches = new Map((values.documents ?? []).map((document) => [document.id, document]));
    const updatedDocuments = allDocuments.map((document) => {
      if (documentDirectionForDocumentType(document.type) !== project.direction || !sameProjectName(document, project.name)) {
        return document;
      }
      const patch = patches.get(document.id) ?? {};
      return {
        ...document,
        projectName: cleanName,
        issueDate: patch.issueDate ?? document.issueDate,
        transactionDate: patch.transactionDate ?? document.transactionDate,
        dueDate: patch.dueDate ?? document.dueDate,
        relatedNumber: patch.relatedNumber ?? document.relatedNumber,
        updatedAt: new Date().toISOString(),
      };
    });
    const updatedDraftPatch = backup.draft ? patches.get(backup.draft.id) : null;
    const updatedDraft =
      backup.draft &&
      documentDirectionForDocumentType(backup.draft.type) === project.direction &&
      sameProjectName(backup.draft, project.name)
        ? {
            ...backup.draft,
            projectName: cleanName,
            issueDate: updatedDraftPatch?.issueDate ?? backup.draft.issueDate,
            transactionDate: updatedDraftPatch?.transactionDate ?? backup.draft.transactionDate,
            dueDate: updatedDraftPatch?.dueDate ?? backup.draft.dueDate,
            relatedNumber: updatedDraftPatch?.relatedNumber ?? backup.draft.relatedNumber,
            updatedAt: new Date().toISOString(),
          }
        : backup.draft;
    await persist({ ...backup, documents: updatedDocuments, draft: updatedDraft }, "已更新項目資料");
  }

  async function updateDocumentRelation(document, relatedNumber) {
    const updated = { ...document, relatedNumber, updatedAt: new Date().toISOString() };
    await persist(
      {
        ...backup,
        documents: allDocuments.map((item) => (item.id === updated.id ? updated : item)),
        draft: selectedDocument?.id === updated.id ? updated : backup.draft,
      },
      relatedNumber ? "已更新關聯號" : "已解除關聯",
    );
  }

  async function copyDocumentToProject(source, project, mode = "append") {
    const copied = {
      ...source,
      id: crypto.randomUUID(),
      number: `${DOCUMENT_TYPE_PREFIX_FOR_COPY(source.type)}-${new Date().getFullYear()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`,
      projectName: project.name === "未指定項目" ? "" : project.name,
      projectDirection: project.direction,
      customerName: project.partnerName === "未填寫客戶/供應商" ? "" : project.partnerName,
      updatedAt: new Date().toISOString(),
    };
    const nextDocuments =
      mode === "overwrite"
        ? [copied, ...allDocuments.filter((document) => !(sameProjectName(document, project.name) && document.type === source.type))]
        : [copied, ...allDocuments];
    await persist({ ...backup, documents: nextDocuments, draft: copied }, mode === "overwrite" ? "已覆蓋項目內同類表單" : "已複製到項目");
    selectDocumentDirect(copied);
  }

  async function saveCustomerFromDocument() {
    if (!selectedDocument?.customerName?.trim()) {
      setStatus("請先輸入客戶名稱");
      return;
    }
    const existing = backup.customers.find((record) => record.name === selectedDocument.customerName);
    setRecordModal({
      collection: "customers",
      recordId: existing?.id ?? null,
      source: { type: "documentCustomer", documentId: selectedDocument.id },
      initialValues: {
        ...(existing ?? {}),
        name: selectedDocument.customerName,
        address: selectedDocument.customerAddress ?? "",
        contact: selectedDocument.customerContact ?? "",
        phone: selectedDocument.customerPhone ?? "",
        email: selectedDocument.customerEmail ?? "",
      },
    });
  }

  async function saveIssuerFromDocument() {
    if (!selectedDocument?.issuerName?.trim()) {
      setStatus("請先輸入公司名稱");
      return;
    }
    const existing = backup.issuers.find((record) => record.name === selectedDocument.issuerName);
    setRecordModal({
      collection: "issuers",
      recordId: existing?.id ?? null,
      source: { type: "documentIssuer", documentId: selectedDocument.id },
      initialValues: {
        ...(existing ?? {}),
        name: selectedDocument.issuerName,
        registration: selectedDocument.issuerRegistration ?? "",
        address: selectedDocument.issuerAddress ?? "",
        contact: selectedDocument.issuerContact ?? "",
        phone: selectedDocument.issuerPhone ?? "",
        email: selectedDocument.issuerEmail ?? "",
        logoData: selectedDocument.issuerLogoData ?? null,
        logoScale: selectedDocument.issuerLogoScale ?? 1,
      },
    });
  }

  async function saveProductFromLine(index) {
    const line = selectedDocument?.lines?.[index];
    if (!line?.name?.trim()) {
      setStatus("請先輸入品名");
      return;
    }
    const existing = backup.products.find((record) => record.name === line.name);
    setRecordModal({
      collection: "products",
      recordId: existing?.id ?? null,
      source: { type: "documentLineProduct", documentId: selectedDocument.id, lineIndex: index },
      initialValues: {
        ...(existing ?? {}),
        name: line.name,
        model: line.model ?? "",
        specification: line.specification ?? "",
        unitPrice: Number(line.unitPrice || 0),
      },
    });
  }

  async function handleChooseDataFolder() {
    await runNativeOperation("選擇資料夾", async () => {
      const folder = await chooseDataFolder();
      if (!folder) {
        setStatus("已取消資料夾選擇");
        return;
      }
      const nextPaths = await setDataRoot(folder);
      setPaths(nextPaths);
      const loaded = await loadState();
      setBackup(loaded);
      setSelectedDocumentIds({
        customer: null,
        vendor: null,
      });
      setActiveDocumentDirection("customer");
      await completeFirstRunSetup();
      setStatus("已切換本地資料夾");
    }).catch((error) => setStatus(error.message));
  }

  async function handleFirstRunChooseDataFolder() {
    await runNativeOperation("選擇資料夾", async () => {
      const folder = await chooseDataFolder();
      if (!folder) {
        setStatus("請選擇資料夾或確認使用預設資料夾");
        return;
      }
      const nextPaths = await setDataRoot(folder);
      setPaths(nextPaths);
      const loaded = await loadState();
      setBackup(loaded);
      setSelectedDocumentIds({
        customer: null,
        vendor: null,
      });
      setActiveDocumentDirection("customer");
      await completeFirstRunSetup();
      setStorageSetupOpen(false);
      setStatus("已確認本地資料夾");
    }).catch((error) => setStatus(error.message));
  }

  async function handleConfirmDefaultDataFolder() {
    await runNativeOperation("確認資料夾", async () => {
      await completeFirstRunSetup();
      setStorageSetupOpen(false);
      setStatus("已確認使用目前資料夾");
    }).catch((error) => setStatus(error.message));
  }

  async function handleResetDataFolder() {
    const confirmed = window.confirm("改回系統預設資料夾？目前指定資料夾的檔案不會被刪除。");
    if (!confirmed) return;
    await runNativeOperation("重設資料夾", async () => {
      const nextPaths = await resetDataRoot();
      setPaths(nextPaths);
      const loaded = await loadState();
      setBackup(loaded);
      setSelectedDocumentIds({
        customer: null,
        vendor: null,
      });
      setActiveDocumentDirection("customer");
      setStatus("已改回預設資料夾");
    }).catch((error) => setStatus(error.message));
  }

  async function addRecord(collection) {
    if (["customers", "issuers", "products", "textTemplates"].includes(collection)) {
      setRecordModal({ collection });
      return;
    }
    const factory = {
      customers: makeCustomer,
      issuers: makeIssuer,
      products: makeProduct,
      textTemplates: makeTextTemplate,
    }[collection];
    const record = factory();
    const next = { ...backup, [collection]: [record, ...(backup[collection] ?? [])] };
    setSelectedRecordIds((ids) => ({ ...ids, [viewIdForCollection(collection)]: record.id }));
    await persist(next, "已新增資料");
  }

  async function createRecordFromModal(collection, values) {
    const factory = {
      customers: makeCustomer,
      issuers: makeIssuer,
      products: makeProduct,
      textTemplates: makeTextTemplate,
    }[collection];
    if (!factory) return;
    if (!hasMeaningfulInput(values)) {
      setStatus("請先輸入資料");
      return;
    }
    const existingRecord = recordModal?.recordId
      ? (backup[collection] ?? []).find((record) => record.id === recordModal.recordId)
      : null;
    const record = { ...(existingRecord ?? factory()), ...values, updatedAt: new Date().toISOString() };
    if ((collection === "customers" || collection === "issuers" || collection === "products") && !record.name?.trim()) {
      const message = collection === "customers" ? "請輸入客戶名稱" : collection === "issuers" ? "請輸入公司名稱" : "請輸入品名";
      setStatus(message);
      return;
    }
    if (collection === "textTemplates" && !record.title?.trim()) {
      setStatus("請輸入模板標題");
      return;
    }
    const records = existingRecord
      ? (backup[collection] ?? []).map((item) => (item.id === record.id ? record : item))
      : [record, ...(backup[collection] ?? [])];
    let next = { ...backup, [collection]: records };
    next = applyRecordModalSource(next, recordModal?.source, record);
    setSelectedRecordIds((ids) => ({ ...ids, [viewIdForCollection(collection)]: record.id }));
    setRecordModal(null);
    await persist(next, existingRecord ? "已更新資料" : "已新增資料");
  }

  function applyRecordModalSource(nextBackup, source, record) {
    if (!source?.documentId) return nextBackup;
    const documents = nextBackup.documents.map((document) => {
      if (document.id !== source.documentId) return document;
      if (source.type === "documentCustomer") {
        return {
          ...document,
          customerName: record.name ?? document.customerName,
          customerAddress: record.address ?? document.customerAddress,
          customerContact: record.contact ?? document.customerContact,
          customerPhone: record.phone ?? document.customerPhone,
          customerEmail: record.email ?? document.customerEmail,
          updatedAt: new Date().toISOString(),
        };
      }
      if (source.type === "documentIssuer") {
        return {
          ...document,
          issuerName: record.name ?? document.issuerName,
          issuerRegistration: record.registration ?? document.issuerRegistration,
          issuerAddress: record.address ?? document.issuerAddress,
          issuerContact: record.contact ?? document.issuerContact,
          issuerPhone: record.phone ?? document.issuerPhone,
          issuerEmail: record.email ?? document.issuerEmail,
          issuerLogoData: record.logoData ?? document.issuerLogoData,
          issuerLogoScale: record.logoScale ?? document.issuerLogoScale,
          updatedAt: new Date().toISOString(),
        };
      }
      if (source.type === "documentLineProduct") {
        return {
          ...document,
          lines: (document.lines ?? []).map((line, index) =>
            index === source.lineIndex
              ? {
                  ...line,
                  name: record.name ?? line.name,
                  model: record.model ?? line.model,
                  specification: record.specification ?? line.specification,
                  unitPrice: record.unitPrice ?? line.unitPrice,
                }
              : line,
          ),
          updatedAt: new Date().toISOString(),
        };
      }
      return document;
    });
    const updatedDraft = nextBackup.draft?.id === source.documentId
      ? documents.find((document) => document.id === source.documentId) ?? nextBackup.draft
      : nextBackup.draft;
    return { ...nextBackup, documents, draft: updatedDraft };
  }

  async function updateRecord(collection, id, field, value) {
    if (isBlankInput(value)) {
      setStatus("空白欄位未保存");
      return;
    }
    const record = (backup[collection] ?? []).find((item) => item.id === id);
    const usageCount = recordUsageCount(collection, backup, record);
    if (usageCount > 0) {
      requestDeleteConfirmation({
        title: "已被保存表單使用",
        message: `「${recordDisplayName(record)}」目前被 ${usageCount} 份已保存表單使用。仍要更新這筆候選資料？`,
        details: ["更新候選資料不會自動改寫已完成表單內容。", "若要保留不同版本，請用新增建立另一筆候選資料。"],
        confirmLabel: "更新既有資料",
        onConfirm: async () => updateRecordDirect(collection, id, field, value),
      });
      return;
    }
    await updateRecordDirect(collection, id, field, value);
  }

  async function updateRecordDirect(collection, id, field, value) {
    const next = {
      ...backup,
      [collection]: (backup[collection] ?? []).map((record) =>
        record.id === id ? { ...record, [field]: field === "unitPrice" || field === "logoScale" ? normalizeNumericInput(value) : value, updatedAt: new Date().toISOString() } : record,
      ),
    };
    updateLocalBackup(next);
    markDocumentDirty(updated.id);
  }

  async function deleteRecord(collection, id) {
    const record = (backup[collection] ?? []).find((item) => item.id === id);
    const usageCount = recordUsageCount(collection, backup, record);
    requestDeleteConfirmation({
      title: "刪除資料",
      message: `確定要刪除資料「${recordDisplayName(record)}」？`,
      details: usageCount > 0
        ? [`目前被 ${usageCount} 份已保存表單使用。`, "已完成表單內容不會自動改寫。", "刪除候選資料後無法復原。"]
        : ["已建立的帳票內容不會自動刪除。", "刪除後無法復原。"],
      onConfirm: async () => {
        const viewId = viewIdForCollection(collection);
        const records = (backup[collection] ?? []).filter((record) => record.id !== id);
        setSelectedRecordIds((ids) => ({ ...ids, [viewId]: records[0]?.id ?? null }));
        await persist({ ...backup, [collection]: records }, "已刪除資料");
      },
    });
  }

  function activateLicense(licenseKey) {
    const verified = verifyLicenseKey(licenseKey);
    if (verified.ok) {
      saveStoredLicense(licenseKey);
      setActiveView("home");
      setStatus("已登入授權系統");
      setNoticeModal({
        title: "授權登入完成",
        message: "授權碼驗證成功，已進入桌面系統。",
        details: [
          `客戶：${verified.license?.customer ?? "未命名客戶"}`,
          `到期日：${formatLicenseDate(verified.expiresAt)}`,
          `剩餘 ${verified.daysRemaining} 天`,
        ],
      });
    } else {
      setStatus(verified.reason);
    }
    setLicenseStatus(verified);
    return verified;
  }

  function logoutLicense() {
    clearStoredLicense();
    setLicenseStatus(verifyLicenseKey(""));
    setPreviewDocument(null);
    setDocumentModalOpen(false);
    setDocumentListModalOpen(false);
    setRecordModal(null);
    setNoticeModal(null);
    setActiveView("home");
    setStatus("已登出授權系統");
  }

  if (!backup) {
    return <main className="loading">Loading</main>;
  }

  if (!licenseStatus.ok) {
    const storedLicense = loadStoredLicense();
    const loginMessage = status === "已登出授權系統"
      ? status
      : storedLicense
        ? licenseStatus.reason
        : "請輸入授權碼登入。";
    return <LicenseLoginPage onLogin={activateLicense} initialMessage={loginMessage} />;
  }

  const navigationText = navCopy(appSettings.interfaceLanguageId);
  const navItems = NAV_ITEMS.map((item) => ({
    ...item,
    label: navigationText[item.id] ?? item.label,
  }));
  const guidanceContextValue = {
    enabled: appSettings.guidanceEnabled,
    seenHintIds,
    dismissHint,
    resetHints,
  };

  return (
    <GuidanceContext.Provider value={guidanceContextValue}>
    <main className={sidebarCollapsed ? "app-shell sidebar-collapsed" : "app-shell"}>
      <aside className="sidebar">
        <div className="brand">
          <FileJson size={26} />
          <div className="brand-text">
            <h1>Shoko Forms</h1>
            <p>Desktop</p>
          </div>
          <button
            type="button"
            className="icon-button sidebar-toggle"
            onClick={() => setSidebarCollapsed((collapsed) => !collapsed)}
            title={sidebarCollapsed ? "展開選單" : "收合選單"}
            aria-label={sidebarCollapsed ? "展開選單" : "收合選單"}
          >
            {sidebarCollapsed ? <ChevronRight size={17} /> : <ChevronLeft size={17} />}
          </button>
        </div>

        <nav className="main-nav">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = item.dataSection
              ? activeView === "data" && activeDataSection === item.dataSection
              : activeView === item.id;
            return (
              <button
                className={isActive ? "nav-button active" : "nav-button"}
                key={item.id}
                onClick={() => {
                  if (item.dataSection) {
                    openDataSection(item.dataSection);
                  } else {
                    navigateToView(item.id);
                  }
                }}
              >
                <Icon size={17} />
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>

        <div className="toolbar">
          <button onClick={handleAddDocument}>
            <Plus size={16} />
            <span>{navigationText.newDocument}</span>
          </button>
        </div>

        <div className="sidebar-spacer" />

        <div className="sidebar-bottom">
          <button
            className={activeView === "settings" ? "nav-button active" : "nav-button"}
            onClick={() => navigateToView("settings")}
          >
            <Settings size={17} />
            <span>{navigationText.settings}</span>
          </button>
        </div>
      </aside>

      <section className="workspace">
        <ErrorBoundary resetKey={`${activeView}:${activeDataSection}`}>
        <div className="workspace-scroll">
          {activeView === "home" && (
            <HomeView
              backup={visibleBackup}
              paths={paths}
              openDocumentList={() => setDocumentListModalOpen(true)}
              openDocument={selectDocument}
              createDocument={handleAddDocument}
              createFormInProject={openFormProjectFlow}
              openDataSection={openDataSection}
            />
          )}
          {activeView === "documents" && (
            <DocumentsView
              backup={visibleBackup}
              activeDocumentDirection={activeDocumentDirection}
              selectedDocument={selectedDocument}
              openDocumentList={() => setDocumentListModalOpen(true)}
              createDocument={handleAddDocument}
              handleFieldChange={handleFieldChange}
              handleAddLine={handleAddLine}
              handleLineChange={handleLineChange}
              handleSelectCustomer={handleSelectCustomer}
              handleSelectIssuer={handleSelectIssuer}
              handleSelectProduct={handleSelectProduct}
              handleDeleteLine={handleDeleteLine}
              handleOrderAttachmentUpload={handleOrderAttachmentUpload}
              handleDeleteOrderAttachment={handleDeleteOrderAttachment}
              handleDeleteDocument={handleDeleteDocument}
              saveCustomerFromDocument={saveCustomerFromDocument}
              saveIssuerFromDocument={saveIssuerFromDocument}
              saveProductFromLine={saveProductFromLine}
              saveDocument={saveCurrentDocument}
              isSaved={!selectedDocumentDirty}
              onBack={openDocumentsLanding}
              openPreview={() => setPreviewDocument(selectedDocument)}
              createFormInProject={openFormProjectFlow}
            />
          )}
          {activeView === "data" && (
            <DataManagementView
              section={activeDataSection}
              setSection={setActiveDataSection}
              onExit={() => navigateToView("home")}
              backup={visibleBackup}
              selectedRecordIds={selectedRecordIds}
              setSelectedRecordIds={setSelectedRecordIds}
              addRecord={addRecord}
              deleteRecord={deleteRecord}
              updateRecord={updateRecord}
              openDocument={selectDocument}
              previewDocument={(document) => setPreviewDocument(document)}
              openProjectDocument={openProjectDocument}
              createProject={createProject}
              deleteDocuments={handleDeleteDocuments}
              updateDocumentRelation={updateDocumentRelation}
              copyDocumentToProject={copyDocumentToProject}
              renameProject={renameProject}
              updateProjectDetails={updateProjectDetails}
            />
          )}
          {activeView === "settings" && (
            <SettingsView
              licenseStatus={licenseStatus}
              paths={paths}
              backup={visibleBackup}
              importMode={importMode}
              setImportMode={setImportMode}
              handleFileImport={handleFileImport}
              handleExport={handleExport}
              handleImportDemoBackup={handleImportDemoBackup}
              handleDeleteAllDocuments={handleDeleteAllDocuments}
              handleChooseDataFolder={handleChooseDataFolder}
              handleResetDataFolder={handleResetDataFolder}
              isNativeOperationPending={isNativeOperationPending}
              appSettings={appSettings}
              updateDesktopSettings={updateDesktopSettings}
              applyDefaultColorTemplate={applyDefaultColorTemplate}
              activateLicense={activateLicense}
              clearLicense={logoutLicense}
              restoreDeletedDocuments={handleRestoreDeletedDocuments}
              permanentlyDeleteRecords={handlePermanentlyDeleteRecords}
            />
          )}
        </div>
        </ErrorBoundary>
      </section>
      {documentModalOpen && (
        <DocumentModal
          backup={visibleBackup}
          initialDirection={documentModalInitialDirection}
          initialProjectMode={documentModalInitialMode}
          onCancel={() => setDocumentModalOpen(false)}
          onSave={createDocumentFromModal}
        />
      )}
      {formProjectModal && (
        <FormProjectPlacementModal
          backup={visibleBackup}
          type={formProjectModal.type}
          onCancel={() => setFormProjectModal(null)}
          onCreate={createDocumentInProject}
          onPreview={(document) => setPreviewDocument(document)}
        />
      )}
      {externalImportModal && (
        <ExternalAttachmentImportModal
          backup={visibleBackup}
          paths={externalImportModal.paths}
          onCancel={() => setExternalImportModal(null)}
          onImport={importExternalFilesToForm}
        />
      )}
      {documentListModalOpen && (
        <DocumentListModal
          documents={filteredDocuments}
          query={query}
          activeDocumentDirection={activeDocumentDirection}
          setActiveDocumentDirection={handleDocumentDirectionChange}
          selectedId={selectedDocument?.id}
          setQuery={setQuery}
          onCancel={() => setDocumentListModalOpen(false)}
          onSelect={(document) => {
            selectDocument(document);
            setDocumentListModalOpen(false);
          }}
        />
      )}
      {previewDocument && (
        <ErrorBoundary resetKey={`pdf-preview:${previewDocument.id}`}>
          <PDFPreviewModal
            document={previewDocument}
            pdfLanguageId={appSettings.pdfLanguageId}
            onStampStateChange={saveDocumentStampState}
            onClose={() => setPreviewDocument(null)}
          />
        </ErrorBoundary>
      )}
      {recordModal && (
        <RecordModal
          collection={recordModal.collection}
          initialValues={recordModal.initialValues}
          isEditing={Boolean(recordModal.recordId)}
          onCancel={() => setRecordModal(null)}
          onSave={(values) => createRecordFromModal(recordModal.collection, values)}
        />
      )}
      {storageSetupOpen && (
        <StorageSetupModal
          paths={paths}
          onChooseFolder={handleFirstRunChooseDataFolder}
          onConfirmDefault={handleConfirmDefaultDataFolder}
          isPending={isNativeOperationPending}
        />
      )}
      {noticeModal && (
        <AppNoticeModal
          title={noticeModal.title}
          message={noticeModal.message}
          details={noticeModal.details}
          onClose={() => setNoticeModal(null)}
        />
      )}
      {deleteConfirmModal && (
        <DeleteConfirmModal
          title={deleteConfirmModal.title}
          message={deleteConfirmModal.message}
          details={deleteConfirmModal.details}
          confirmLabel={deleteConfirmModal.confirmLabel}
          onCancel={() => setDeleteConfirmModal(null)}
          onConfirm={runDeleteConfirmation}
        />
      )}
      {unsavedLeaveModal && (
        <UnsavedChangesModal
          documentNumber={selectedDocument?.number}
          onCancel={() => setUnsavedLeaveModal(null)}
          onDiscard={discardUnsavedDocument}
          onSave={saveUnsavedAndContinue}
        />
      )}
    </main>
    </GuidanceContext.Provider>
  );
}

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { error: null, resetKey: props.resetKey };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  static getDerivedStateFromProps(props, state) {
    if (props.resetKey !== state.resetKey) {
      return { error: null, resetKey: props.resetKey };
    }
    return null;
  }

  componentDidCatch(error) {
    console.error(error);
  }

  render() {
    if (this.state.error) {
      return (
        <div className="workspace-scroll">
          <section className="empty-state">
            <FileJson size={40} />
            <h2>畫面載入失敗</h2>
            <p>{this.state.error?.message ?? "資料顯示時發生錯誤。"}</p>
          </section>
        </div>
      );
    }
    return this.props.children;
  }
}

function AppHeader({ activeView, status, openDocumentList, importMode, setImportMode, handleFileImport, handleExport }) {
  const title = NAV_ITEMS.find((item) => item.id === activeView)?.label ?? "工作台";
  return (
    <header className="topbar">
      <div className="topbar-title-row">
        <button type="button" className="icon-button secondary-button history-button" onClick={openDocumentList} title="帳票歷史">
          <History size={17} />
        </button>
        <div>
          <h2>{title}</h2>
          <p>{status} · 桌面版功能已開放</p>
        </div>
      </div>
      <div className="backup-actions">
        <select value={importMode} onChange={(event) => setImportMode(event.target.value)}>
          <option value="merge">合併匯入</option>
          <option value="replace">替換本地</option>
        </select>
        <label className="file-button">
          <Upload size={16} />
          匯入
          <input type="file" accept=".shokobackup,application/json" onChange={handleFileImport} />
        </label>
        <button onClick={handleExport}>
          <Download size={16} />
          匯出
        </button>
      </div>
    </header>
  );
}

function HomeView({ backup, paths, openDocumentList, openDocument, createDocument, createFormInProject, openDataSection }) {
  return (
    <section className="home-view">
      <div className="home-hero">
        <div>
          <span>工作台</span>
          <h2>帳票首頁</h2>
          <p>從最近的客戶帳票或廠商帳票開始，統計與本地資料夾狀態集中在這裡。</p>
        </div>
        <div className="actions-row compact-actions">
          <GuidedControl id="home.create-document" title="新增帳票提示" description="第一次使用時從這裡開始。點擊後會引導你選擇新項目、既有項目與表單類型。">
            <button type="button" onClick={createDocument}>
              <Plus size={16} />
              新增帳票
            </button>
          </GuidedControl>
          <GuidedControl id="home.document-history" title="歷史提示" description="查看已建立帳票，搜尋客戶、編號或表單類型後可直接回到編輯。">
            <button type="button" className="secondary-button" onClick={openDocumentList}>
              <History size={16} />
              歷史
            </button>
          </GuidedControl>
          <GuidedControl id="home.files-link" title="檔案列表提示" description="進入項目與表單列表，可預覽、編輯或複製既有表單。">
            <button type="button" className="secondary-button" onClick={() => openDataSection("files")}>
              <FolderOpen size={16} />
              檔案列表
            </button>
          </GuidedControl>
        </div>
      </div>

      <section className="stats home-stats">
        <Metric label="帳票" value={backup.documents.length} />
        <Metric label="客戶" value={backup.customers.length} />
        <Metric label="發行者" value={backup.issuers.length} />
        <Metric label="商品" value={backup.products.length} />
        <div className="path-panel">
          <Folder size={16} />
          <span>{paths?.root}</span>
        </div>
      </section>

      <div className="home-document-grid">
        {Object.entries(DOCUMENT_DIRECTION_GROUPS).map(([direction, group]) => (
          <RecentDocumentPanel
            key={direction}
            title={`${group.label}帳票`}
            subtitle={group.subtitle}
            documents={backup.documents.filter((document) => documentDirectionForDocumentType(document.type) === direction)}
            onOpen={openDocument}
            onCreateType={createFormInProject}
          />
        ))}
      </div>
    </section>
  );
}

function RecentDocumentPanel({ title, subtitle, documents, onOpen, onCreateType }) {
  const recentDocuments = documents.slice(0, 6);
  const direction = documents[0] ? documentDirectionForDocumentType(documents[0].type) : title.includes("廠商") ? "vendor" : "customer";
  const types = DOCUMENT_DIRECTION_GROUPS[direction]?.types ?? [];
  return (
    <section className="home-panel">
      <div className="section-actions">
        <div>
          <h3>{title}</h3>
          <p className="panel-subtitle">{subtitle}</p>
        </div>
      </div>
      <div className="home-recent-list">
        {types.map((type) => (
          <button type="button" className="home-recent-row" key={type} onClick={() => onCreateType(type)}>
            <span>{formMenuTypeLabel(type)}</span>
            <small>建立或放入項目</small>
            <small>選取後可建立新項目，或放入既有項目</small>
          </button>
        ))}
        {recentDocuments.map((document) => (
          <button type="button" className="home-recent-row" key={document.id} onClick={() => onOpen(document)}>
            <span>{document.number || "未命名帳票"}</span>
            <small>{DOCUMENT_TYPE_LABELS[document.type] ?? document.type}</small>
            <small>{document.customerName || "未設定客戶"} · {formatDate(document.updatedAt)}</small>
          </button>
        ))}
        {recentDocuments.length === 0 && <div className="empty">尚無既有帳票</div>}
      </div>
    </section>
  );
}

function DocumentDirectionTabs({ activeDirection, documents = [], onChange, showCounts = true }) {
  return (
    <div className="document-tabs" role="tablist" aria-label="帳票分類">
      {Object.entries(DOCUMENT_DIRECTION_GROUPS).map(([direction, group]) => {
        const count = documents.filter((document) => documentDirectionForDocumentType(document.type) === direction).length;
        return (
          <button
            type="button"
            className={activeDirection === direction ? "document-tab active" : "document-tab"}
            key={direction}
            onClick={() => onChange(direction)}
            role="tab"
            aria-selected={activeDirection === direction}
          >
            <span>{group.label}</span>
            <small>{group.subtitle}</small>
            {showCounts && <b>{count}</b>}
          </button>
        );
      })}
    </div>
  );
}

function DocumentsView({
  backup,
  activeDocumentDirection,
  selectedDocument,
  openDocumentList,
  createDocument,
  handleFieldChange,
  handleAddLine,
  handleLineChange,
  handleSelectCustomer,
  handleSelectIssuer,
  handleSelectProduct,
  handleDeleteLine,
  handleOrderAttachmentUpload,
  handleDeleteOrderAttachment,
  handleDeleteDocument,
  saveCustomerFromDocument,
  saveIssuerFromDocument,
  saveProductFromLine,
  saveDocument,
  isSaved,
  onBack,
  openPreview,
  createFormInProject,
}) {
  const totals = selectedDocument ? documentTotal(selectedDocument) : { subtotal: 0, tax: 0, total: 0 };
  const projectOptions = uniqueOptions(backup.documents.map((document) => document.projectName));
  const relatedNumberOptions = uniqueOptions(backup.documents.map((document) => document.number));
  const customerOptions = uniqueOptions(backup.customers.map((customer) => customer.name));
  const issuerOptions = uniqueOptions(backup.issuers.map((issuer) => issuer.name));
  const productOptions = uniqueOptions(backup.products.map((product) => product.name));
  const customerExists = backup.customers.some((customer) => customer.name === selectedDocument?.customerName);
  const issuerExists = backup.issuers.some((issuer) => issuer.name === selectedDocument?.issuerName);
  const selectedDocumentDirection = documentDirectionForDocumentType(selectedDocument?.type);
  const activeTypeOptions = documentTypeOptionsForDirection(selectedDocumentDirection, selectedDocument?.type);
  const presentation = documentPresentationRules(selectedDocument?.type);
  return (
    <>
      {selectedDocument ? (
        <section className="editor">
          <div className="section-actions">
            <div className="editor-title-row">
              <DataBackButton onClick={onBack} />
              <div>
                <h3>帳票編輯</h3>
                <span>{isSaved ? "已保存" : "尚未保存"}</span>
              </div>
            </div>
            <div className="actions-row compact-actions">
              <GuidedControl id="documents.editor.save-button" title="保存提示" description="输入框修改后会先显示未保存。点击这里把当前帐票写入本地资料夹。">
                <button type="button" className={isSaved ? "saved-button" : ""} onClick={() => saveDocument()}>
                  <Save size={16} />
                  {isSaved ? "已保存" : "保存"}
                </button>
              </GuidedControl>
              {!presentation.isAttachmentRecord && (
                <GuidedControl id="documents.editor.preview-button" title="PDF 预览提示" description="输出前先检查版面、金额、备注与印章；也可以在预览里保存或打印 PDF。">
                  <button type="button" className="secondary-button" onClick={openPreview}>
                    <Eye size={16} />
                    PDF預覽
                  </button>
                </GuidedControl>
              )}
              <button className="danger-button" onClick={handleDeleteDocument}>
                <Trash2 size={16} />
                刪除帳票
              </button>
            </div>
          </div>
          <div className="document-editor-grid">
            <section className="form-section form-section-wide">
              <div className="form-section-heading">
                <h4>基本資訊</h4>
                <span>帳票類型、日期與專案關聯</span>
              </div>
              <div className="section-form-grid">
                <Field label="帳票編號" value={selectedDocument.number} onChange={(value) => handleFieldChange("number", value)} hint={{ id: "field.document-number", title: "帳票編號提示", description: "可手动修改编号；保存后会作为列表、搜索与 PDF 输出中的识别编号。" }} />
                <label>
                  類型
                  <select value={selectedDocument.type} onChange={(event) => handleFieldChange("type", event.target.value)}>
                    {activeTypeOptions.map((value) => (
                      <option key={value} value={value}>{DOCUMENT_TYPE_LABELS[value] ?? value}</option>
                    ))}
                  </select>
                </label>
                <Field label="発行日" type="date" value={selectedDocument.issueDate} onChange={(value) => handleFieldChange("issueDate", value)} />
                <Field label="取引年月日" type="date" value={selectedDocument.transactionDate} onChange={(value) => handleFieldChange("transactionDate", value)} />
                {presentation.showDueDate && (
                  <Field label="支払期限" type="date" value={selectedDocument.dueDate} onChange={(value) => handleFieldChange("dueDate", value)} />
                )}
                {presentation.showTax && (
                  <Field label="税率" type="number" value={selectedDocument.taxRate ?? 10} onChange={(value) => handleFieldChange("taxRate", value)} help="稅是後加的。" />
                )}
                <Field label="專案名稱" value={selectedDocument.projectName ?? ""} onChange={(value) => handleFieldChange("projectName", value)} options={projectOptions} listId="project-options" hint={{ id: "field.project-name", title: "項目名稱提示", description: "输入或选择项目名称后，相关表单会在项目列表中集中管理。" }} />
                <Field label="關聯號" value={selectedDocument.relatedNumber ?? ""} onChange={(value) => handleFieldChange("relatedNumber", value)} options={relatedNumberOptions} listId="related-number-options" hint={{ id: "field.related-number", title: "關聯號提示", description: "可选择另一张表单编号，建立报价、发票、收据等文件之间的关联。" }} />
              </div>
            </section>

            {presentation.isAttachmentRecord ? (
              <AttachmentRecordEditor
                document={selectedDocument}
                onUpload={handleOrderAttachmentUpload}
                onDelete={handleDeleteOrderAttachment}
              />
            ) : (
              <>
            <section className="form-section">
              <div className="form-section-heading">
                <h4>{presentation.partnerHeading}</h4>
                <span>{presentation.partnerSubheading}</span>
              </div>
              <div className="section-form-grid single-column">
                <div className="field-with-action">
                  <Field label={presentation.partnerNameLabel} value={selectedDocument.customerName} onChange={handleSelectCustomer} options={customerOptions} listId="customer-options" hint={{ id: "field.customer-name", title: "客戶名稱提示", description: "可输入新客户/供应商，或从既有资料中选择；选择后会带入主档资料。" }} />
                  <GuidedControl id="documents.customer-master-button" title="客戶主檔提示" description="把目前帐票中的客户资料建立或更新到客户列表，下次可直接选择。">
                    <button type="button" className="secondary-button" onClick={saveCustomerFromDocument}>
                      <Plus size={14} />
                      {customerExists ? "更新" : "建立"}
                    </button>
                  </GuidedControl>
                </div>
                <Field label="敬稱" value={selectedDocument.honorific ?? "御中"} onChange={(value) => handleFieldChange("honorific", value)} />
                <Field label={presentation.partnerContactLabel} value={selectedDocument.customerContact} onChange={(value) => handleFieldChange("customerContact", value)} />
                <Field label={presentation.partnerPhoneLabel} value={selectedDocument.customerPhone ?? ""} onChange={(value) => handleFieldChange("customerPhone", value)} />
                <Field label={presentation.partnerEmailLabel} value={selectedDocument.customerEmail ?? ""} onChange={(value) => handleFieldChange("customerEmail", value)} />
                <Field label={presentation.partnerAddressLabel} value={selectedDocument.customerAddress} onChange={(value) => handleFieldChange("customerAddress", value)} />
              </div>
            </section>

            <section className="form-section">
              <div className="form-section-heading">
                <h4>發行者資訊</h4>
                <span>開立方、登錄號與聯絡資料</span>
              </div>
              <div className="section-form-grid single-column">
                <div className="field-with-action">
                  <Field label="公司名稱" value={selectedDocument.issuerName} onChange={handleSelectIssuer} options={issuerOptions} listId="issuer-options" hint={{ id: "field.issuer-name", title: "公司名稱提示", description: "选择或输入开立方公司。旁边按钮可保存到公司列表，方便后续帐票复用。" }} />
                  <GuidedControl id="documents.issuer-master-button" title="公司主檔提示" description="把当前公司资料建立或更新到公司列表，之后建立表单时可直接带入。">
                    <button type="button" className="secondary-button" onClick={saveIssuerFromDocument}>
                      <Plus size={14} />
                      {issuerExists ? "更新" : "建立"}
                    </button>
                  </GuidedControl>
                </div>
                {presentation.showIssuerRegistration && (
                  <Field label="發行者登錄號" value={selectedDocument.issuerRegistration} onChange={(value) => handleFieldChange("issuerRegistration", value)} />
                )}
                <Field label="發行者聯絡人" value={selectedDocument.issuerContact ?? ""} onChange={(value) => handleFieldChange("issuerContact", value)} />
                <Field label="發行者電話" value={selectedDocument.issuerPhone ?? ""} onChange={(value) => handleFieldChange("issuerPhone", value)} />
                <Field label="發行者 Email" value={selectedDocument.issuerEmail ?? ""} onChange={(value) => handleFieldChange("issuerEmail", value)} />
                <Field label="發行者地址" value={selectedDocument.issuerAddress ?? ""} onChange={(value) => handleFieldChange("issuerAddress", value)} />
              </div>
            </section>
              </>
            )}
          </div>

          {!presentation.isAttachmentRecord && (
            <>
          <div className="lines-header">
            <h3>明細</h3>
            <GuidedControl id="documents.add-line-button" title="新增明細提示" description="增加一列商品明细。品名可选择商品主档，并自动带入规格与单价。">
              <button onClick={handleAddLine}>
                <Plus size={16} />
                新增明細
              </button>
            </GuidedControl>
          </div>
          <div className={["line-table", presentation.showLinePrices ? "" : "line-table-no-prices"].filter(Boolean).join(" ")}>
            <div className={["line-head", "with-delete", presentation.showLinePrices ? "" : "without-prices"].filter(Boolean).join(" ")}>
              <span>品名</span>
              <span>型號</span>
                <span>規格</span>
                <span>數量</span>
                {presentation.showLinePrices && <span>單價</span>}
                <span></span>
              </div>
            {(selectedDocument.lines ?? []).map((line, index) => (
              <div className={["line-row", "with-delete", presentation.showLinePrices ? "" : "without-prices"].filter(Boolean).join(" ")} key={line.id ?? index}>
                <GuidedControl id="line.product-name" title="品名提示" description="输入品名或选择商品主档；选择既有商品会自动带入型号、规格与单价。" className="guided-control-fill">
                  <input
                    {...plainInputAttributes()}
                    list="product-options"
                    value={line.name ?? ""}
                    onChange={(event) => handleSelectProduct(index, event.target.value)}
                    onKeyDown={(event) => handleLiteralMinus(event, (value) => handleSelectProduct(index, value))}
                  />
                </GuidedControl>
                <input
                  {...plainInputAttributes()}
                  value={line.model ?? ""}
                  onChange={(event) => handleLineChange(index, "model", event.target.value)}
                  onKeyDown={(event) => handleLiteralMinus(event, (value) => handleLineChange(index, "model", value))}
                />
                <input
                  {...plainInputAttributes()}
                  value={line.specification ?? ""}
                  onChange={(event) => handleLineChange(index, "specification", event.target.value)}
                  onKeyDown={(event) => handleLiteralMinus(event, (value) => handleLineChange(index, "specification", value))}
                />
                <input
                  {...plainInputAttributes("decimal")}
                  value={line.quantity ?? 0}
                  onChange={(event) => handleLineChange(index, "quantity", event.target.value)}
                  onKeyDown={(event) => handleLiteralMinus(event, (value) => handleLineChange(index, "quantity", value))}
                />
                {presentation.showLinePrices && (
                  <input
                    {...plainInputAttributes("decimal")}
                    value={line.unitPrice ?? 0}
                    onChange={(event) => handleLineChange(index, "unitPrice", event.target.value)}
                    onKeyDown={(event) => handleLiteralMinus(event, (value) => handleLineChange(index, "unitPrice", value))}
                  />
                )}
                <div className="line-actions">
                  <GuidedControl id="line.save-product" title="商品主檔提示" description="把这一列的品名、型号、规格与单价保存到商品列表，下次可直接选用。">
                    <button className="icon-button secondary-button" onClick={() => saveProductFromLine(index)} title="建立或更新商品">
                      <Plus size={16} />
                    </button>
                  </GuidedControl>
                  <button className="icon-button danger-button" onClick={() => handleDeleteLine(index)} title="刪除明細">
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            ))}
            <datalist id="product-options">
              {productOptions.map((option) => (
                <option key={option} value={option} />
              ))}
            </datalist>
          </div>

          <div className="summary">
            <div className="notes-grid">
              <Field label="備考" value={selectedDocument.notes ?? ""} onChange={(value) => handleFieldChange("notes", value)} multiline />
              {presentation.showPaymentDetails && (
                <Field label="振込先" value={selectedDocument.paymentDetails ?? ""} onChange={(value) => handleFieldChange("paymentDetails", value)} multiline />
              )}
              <Field label={selectedDocument.type === "invoice" ? "請求条件" : "条件"} value={selectedDocument.documentMemo ?? ""} onChange={(value) => handleFieldChange("documentMemo", value)} multiline />
              {isVendorDocumentType(selectedDocument.type) && (
                <div className="vendor-proof-grid">
                  <Field label="支払日時" type="date" value={selectedDocument.paymentProofDate ?? ""} onChange={(value) => handleFieldChange("paymentProofDate", value)} />
                  <Field label="支払金額" type="number" value={selectedDocument.paymentProofAmount ?? 0} onChange={(value) => handleFieldChange("paymentProofAmount", value)} />
                </div>
              )}
            </div>
            {presentation.showSummaryTotals && (
              <div className="total-box">
                <span>小計 {totals.subtotal.toLocaleString("ja-JP")}</span>
                {presentation.showTax && <span>稅額 {totals.tax.toLocaleString("ja-JP")}</span>}
                <strong>合計 {(presentation.showTax ? totals.total : totals.subtotal).toLocaleString("ja-JP")}</strong>
              </div>
            )}
          </div>
            </>
          )}
        </section>
      ) : (
        <DocumentEmptyState
          onCreateDocument={createDocument}
          onCreateFormInProject={createFormInProject}
        />
      )}
    </>
  );
}

function AttachmentRecordEditor({ document, onUpload, onDelete }) {
  const inputRef = useRef(null);
  const attachments = document.orderAttachments ?? [];
  return (
    <section className="form-section form-section-wide attachment-record-section">
      <div className="form-section-heading">
        <h4>{attachmentSectionTitle(document.type)}</h4>
        <span>圖片與 PDF 可直接預覽，原始檔會保存在本地資料內。</span>
      </div>
      <div className="attachment-actions">
        <GuidedControl id="documents.attachment-upload" title="附件上传提示" description="上传客户订单、供应商报价、請求書或領収書。支持图片和 PDF，上传后可在下方直接预览。">
          <button type="button" onClick={() => inputRef.current?.click()}>
            <Upload size={16} />
            上傳圖片/PDF
          </button>
        </GuidedControl>
        <input
          ref={inputRef}
          type="file"
          accept="image/*,application/pdf"
          multiple
          className="visually-hidden"
          onChange={(event) => {
            onUpload(event.target.files);
            event.target.value = "";
          }}
        />
      </div>
      {attachments.length ? (
        <div className="attachment-preview-grid">
          {attachments.map((attachment) => (
            <AttachmentPreviewCard key={attachment.id} attachment={attachment} onDelete={() => onDelete(attachment.id)} />
          ))}
        </div>
      ) : (
        <div className="attachment-empty-state">
          <FileText size={24} />
          <strong>尚未上傳附件</strong>
          <span>只需要填寫上方日期與關聯資訊，再把收到的圖片或 PDF 放在這裡。</span>
        </div>
      )}
    </section>
  );
}

function AttachmentPreviewCard({ attachment, onDelete }) {
  const isImage = attachment.contentType?.startsWith("image/");
  const isPdf = attachment.contentType === "application/pdf" || attachment.filename?.toLowerCase().endsWith(".pdf");
  const dataUrl = attachmentDataUrl(attachment);
  return (
    <article className="attachment-preview-card">
      <div className="attachment-preview-toolbar">
        <div>
          <strong>{attachment.filename || "附件"}</strong>
          <span>{formatDate(attachment.uploadedAt)}</span>
        </div>
        <button type="button" className="icon-button danger-button" onClick={onDelete} title="刪除附件">
          <Trash2 size={15} />
        </button>
      </div>
      <div className="attachment-preview-frame">
        {isImage && <img src={dataUrl} alt={attachment.filename || "附件預覽"} />}
        {isPdf && <iframe src={dataUrl} title={attachment.filename || "PDF 預覽"} />}
        {!isImage && !isPdf && (
          <div className="attachment-preview-fallback">
            <FileText size={28} />
            <span>此檔案類型無法直接預覽</span>
          </div>
        )}
      </div>
    </article>
  );
}

function DocumentEmptyState({
  onCreateDocument,
  onCreateFormInProject,
}) {
  const groups = Object.entries(DOCUMENT_DIRECTION_GROUPS);
  return (
    <section className="document-empty-state">
      <div className="document-empty-hero">
        <div>
          <span>帳票工作區</span>
          <h2>選擇要建立的空白表單</h2>
        </div>
        <div className="document-empty-toolbar">
          <GuidedControl id="documents.empty.new-button" title="建立帳票提示" description="点击后进入完整新增流程：先选项目，再选择要建立的表单。">
            <button type="button" onClick={() => onCreateDocument({ initialMode: "new" })}>
              <Plus size={16} />
              建立新帳票
            </button>
          </GuidedControl>
        </div>
      </div>
      {groups.map(([direction, group]) => (
        <div className={`document-empty-preview document-empty-preview-${direction}`} key={direction}>
          <FormTypeSectionHeader title={`${group.label}表單`} viewMode="list" />
          <FormTypeChooser
            types={group.types}
            documents={[]}
            viewMode="list"
            onSelect={onCreateFormInProject}
            className="document-empty-preview-grid blank-document-form-grid"
          />
        </div>
      ))}
    </section>
  );
}

function DocumentListModal({
  documents,
  query,
  activeDocumentDirection,
  setActiveDocumentDirection,
  selectedId,
  setQuery,
  onCancel,
  onSelect,
}) {
  const visibleDocuments = documents.filter(
    (document) => documentDirectionForDocumentType(document.type) === activeDocumentDirection,
  );
  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal-panel document-list-modal">
        <div className="section-actions sticky-modal-header">
          <div>
            <h3>帳票列表</h3>
            <p className="modal-subtitle">選擇帳票後會回到帳票編輯頁。</p>
          </div>
          <button type="button" className="secondary-button" onClick={onCancel}>
            關閉
          </button>
        </div>

        <GuidedControl id="documents.list.search" title="搜尋提示" description="输入帐票编号、客户或项目名称，可快速找到要继续编辑的表单。" className="guided-control-fill">
          <label className="modal-search">
            <Search size={16} />
            <input
              {...plainInputAttributes("search")}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="搜尋帳票、客戶、編號"
            />
          </label>
        </GuidedControl>

        <DocumentDirectionTabs
          activeDirection={activeDocumentDirection}
          documents={documents}
          onChange={setActiveDocumentDirection}
        />

        <div className="modal-document-list">
          {visibleDocuments.map((document) => (
            <button
              className={document.id === selectedId ? "modal-document-row active" : "modal-document-row"}
              key={document.id}
              onClick={() => onSelect(document)}
            >
              <span>{document.number || "未命名帳票"}</span>
              <small>{DOCUMENT_TYPE_LABELS[document.type] ?? document.type}</small>
              <small>{document.customerName || "未設定客戶"} · {formatDate(document.updatedAt)}</small>
            </button>
          ))}
          {visibleDocuments.length === 0 && <div className="empty">沒有符合條件的帳票</div>}
        </div>
      </section>
    </div>
  );
}

function DataManagementView({
  section,
  setSection,
  onExit,
  backup,
  selectedRecordIds,
  setSelectedRecordIds,
  addRecord,
  deleteRecord,
  updateRecord,
  openDocument,
  previewDocument,
  openProjectDocument,
  createProject,
  deleteDocuments,
  updateDocumentRelation,
  copyDocumentToProject,
  renameProject,
  updateProjectDetails,
}) {
  if (section === "files") {
    return (
      <FileManagementView
        backup={backup}
        onBack={onExit}
        openDocument={openDocument}
        previewDocument={previewDocument}
        deleteDocuments={deleteDocuments}
        copyDocumentToProject={copyDocumentToProject}
      />
    );
  }

  if (section === "projects") {
    return (
      <ProjectManagementView
        backup={backup}
        onBack={onExit}
        openDocument={openDocument}
        openProjectDocument={openProjectDocument}
        createProject={createProject}
        deleteDocuments={deleteDocuments}
        updateDocumentRelation={updateDocumentRelation}
        copyDocumentToProject={copyDocumentToProject}
        renameProject={renameProject}
        updateProjectDetails={updateProjectDetails}
      />
    );
  }

  if (section === "company") {
    return (
      <RecordView
        title="公司列表管理"
        records={backup.issuers}
        selectedId={selectedRecordIds.issuers}
        setSelectedId={(id) => setSelectedRecordIds((ids) => ({ ...ids, issuers: id }))}
        addRecord={() => addRecord("issuers")}
        deleteRecord={(id) => deleteRecord("issuers", id)}
        updateRecord={(id, field, value) => updateRecord("issuers", id, field, value)}
        onBack={onExit}
        fields={[
          ["name", "公司名稱"],
          ["registration", "登錄號"],
          ["contact", "聯絡人"],
          ["phone", "電話"],
          ["email", "Email"],
          ["address", "地址", "wide"],
        ]}
        summary={(record) => record.name || "未命名公司"}
      />
    );
  }

  if (section === "customers") {
    return (
      <RecordView
        title="客戶列表管理"
        records={backup.customers}
        selectedId={selectedRecordIds.customers}
        setSelectedId={(id) => setSelectedRecordIds((ids) => ({ ...ids, customers: id }))}
        addRecord={() => addRecord("customers")}
        deleteRecord={(id) => deleteRecord("customers", id)}
        updateRecord={(id, field, value) => updateRecord("customers", id, field, value)}
        usageCount={(record) => recordUsageCount("customers", backup, record)}
        onBack={onExit}
        fields={[
          ["name", "客戶名稱"],
          ["contact", "聯絡人"],
          ["phone", "電話"],
          ["email", "Email"],
          ["address", "地址", "wide"],
        ]}
        summary={(record) => record.name || "未命名客戶"}
      />
    );
  }

  if (section === "products") {
    return (
      <RecordView
        title="商品列表管理"
        records={backup.products}
        selectedId={selectedRecordIds.products}
        setSelectedId={(id) => setSelectedRecordIds((ids) => ({ ...ids, products: id }))}
        addRecord={() => addRecord("products")}
        deleteRecord={(id) => deleteRecord("products", id)}
        updateRecord={(id, field, value) => updateRecord("products", id, field, value)}
        usageCount={(record) => recordUsageCount("products", backup, record)}
        onBack={onExit}
        fields={[
          ["name", "品名"],
          ["model", "型號"],
          ["specification", "規格", "textarea"],
          ["unitPrice", "單價", "number"],
        ]}
        formClassName="product-record-form"
        summary={(record) => record.name || "未命名商品"}
      />
    );
  }

  if (section === "stamp") {
    return <StampManagementView onBack={onExit} />;
  }

  return (
    <RecordView
      title="模板列表管理"
      records={backup.textTemplates}
      selectedId={selectedRecordIds.templates}
      setSelectedId={(id) => setSelectedRecordIds((ids) => ({ ...ids, templates: id }))}
      addRecord={() => addRecord("textTemplates")}
      deleteRecord={(id) => deleteRecord("textTemplates", id)}
      updateRecord={(id, field, value) => updateRecord("textTemplates", id, field, value)}
      onBack={onExit}
      autoSelectFirst={false}
      fields={[
        ["kind", "類型", "select", TEMPLATE_KIND_LABELS],
        ["title", "標題"],
        ["content", "內容", "wide"],
      ]}
      summary={(record) => record.title || TEMPLATE_KIND_LABELS[record.kind] || "未命名模板"}
    />
  );
}

function DataBackButton({ onClick, title = "返回" }) {
  return (
    <button type="button" className="secondary-button data-back-button" onClick={onClick} aria-label={title}>
      <ChevronLeft size={16} />
      <span>{title}</span>
    </button>
  );
}

function StampManagementView({ onBack }) {
  const initialStamps = useMemo(() => loadStoredStamps(), []);
  const [stamps, setStamps] = useState(initialStamps);
  const [selectedStampId, setSelectedStampId] = useState(() => initialStamps[0]?.id || "");
  const selectedStamp = stamps.find((stamp) => stamp.id === selectedStampId) ?? stamps[0] ?? null;
  const [message, setMessage] = useState(stamps.length ? `已載入 ${stamps.length} 個印章。` : "尚未設定印章。");

  async function handleImageChange(event) {
    const files = Array.from(event.target.files ?? []);
    if (!files.length) return;
    try {
      const nextStamps = [...stamps];
      for (const file of files) {
        const dataUrl = await fileToDataUrl(file);
        nextStamps.push(makeStampRecord(dataUrl, file.name || `印章 ${nextStamps.length + 1}`));
      }
      const saved = saveStoredStamps(nextStamps);
      setStamps(saved);
      setSelectedStampId(saved[saved.length - 1]?.id || "");
      setMessage(`已新增 ${files.length} 個印章。`);
    } catch (error) {
      setMessage(error.message);
    } finally {
      event.target.value = "";
    }
  }

  function deleteStamp(id) {
    const target = stamps.find((stamp) => stamp.id === id);
    const saved = saveStoredStamps(stamps.filter((stamp) => stamp.id !== id));
    setStamps(saved);
    setSelectedStampId((currentId) => (currentId === id ? saved[0]?.id || "" : currentId));
    setMessage(target ? `已移除「${target.name}」。` : "已移除印章。");
  }

  return (
    <section className="panel-view stamp-management-view">
      <div className="management-toolbar stamp-management-toolbar">
        <DataBackButton onClick={onBack} />
        <h2>印章管理</h2>
        <GuidedControl id="stamp.upload-button" title="上傳印章提示" description="上传共用印章图片。每份帐票的位置、大小和显示状态在 PDF 预览里调整。">
          <label className="secondary-button file-upload-button stamp-upload-button">
            <Upload size={16} />
            上傳印章
            <input type="file" accept="image/*" multiple onChange={handleImageChange} />
          </label>
        </GuidedControl>
      </div>

      <div className="stamp-management-grid">
        <section className="settings-panel stamp-preview-panel">
          <div className="stamp-preview-sheet">
            <div className="stamp-preview-lines">
              <span />
              <span />
              <span />
            </div>
            {selectedStamp ? (
              <img className="stamp-preview-image" src={selectedStamp.dataUrl} alt={selectedStamp.name} />
            ) : (
              <div className="stamp-empty-preview">
                <Stamp size={42} />
                <strong>未設定印章</strong>
              </div>
            )}
          </div>
          <p>{message}</p>
        </section>

        <section className="settings-panel stamp-file-panel">
          <div className="section-actions">
            <h3>印章檔案</h3>
          </div>
          <p>這裡只管理桌面端共用的印章圖片。每份帳票的位置、大小、顏色與透明度，請在該帳票的 PDF 預覽「印章設定」中調整。</p>
          <div className="stamp-library-list">
            {stamps.map((stamp, index) => (
              <div
                className={stamp.id === selectedStamp?.id ? "stamp-library-row active" : "stamp-library-row"}
                key={stamp.id}
                onClick={() => setSelectedStampId(stamp.id)}
                role="button"
                tabIndex={0}
                onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    setSelectedStampId(stamp.id);
                  }
                }}
              >
                <img src={stamp.dataUrl} alt="" />
                <span>
                  <strong>{stamp.name || `印章 ${index + 1}`}</strong>
                  <small>{formatDate(stamp.updatedAt || stamp.createdAt)}</small>
                </span>
                <button
                  type="button"
                  className="icon-button danger-button"
                  onClick={(event) => {
                    event.stopPropagation();
                    deleteStamp(stamp.id);
                  }}
                  aria-label={`移除 ${stamp.name}`}
                  title="移除印章"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
            {stamps.length === 0 && <div className="empty">尚未上傳印章</div>}
          </div>
        </section>
      </div>
    </section>
  );
}

function StampEditorControls({ settings, onChange, includePosition = false }) {
  const tintHex = `#${[settings.tintRed, settings.tintGreen, settings.tintBlue]
    .map((value) => Math.round(clampNumber(value, 0, 1) * 255).toString(16).padStart(2, "0"))
    .join("")}`;

  function updateNumber(field, value) {
    onChange({ [field]: Number(value) });
  }

  function updateTint(value) {
    const clean = String(value || "#ff0000").replace("#", "");
    const red = parseInt(clean.slice(0, 2), 16);
    const green = parseInt(clean.slice(2, 4), 16);
    const blue = parseInt(clean.slice(4, 6), 16);
    onChange({
      tintRed: Number.isFinite(red) ? red / 255 : 1,
      tintGreen: Number.isFinite(green) ? green / 255 : 0,
      tintBlue: Number.isFinite(blue) ? blue / 255 : 0,
    });
  }

  return (
    <div className="stamp-control-grid">
      {includePosition && (
        <>
          <RangeField label="左右位置" value={settings.normalizedCenterX} min={0.05} max={0.95} step={0.01} format={(value) => `${Math.round(value * 100)}%`} onChange={(value) => updateNumber("normalizedCenterX", value)} />
          <RangeField label="上下位置" value={settings.normalizedCenterY} min={0.05} max={0.95} step={0.01} format={(value) => `${Math.round(value * 100)}%`} onChange={(value) => updateNumber("normalizedCenterY", value)} />
        </>
      )}
      <RangeField label="大小" value={settings.scale} min={0.25} max={3} step={0.05} format={(value) => `${Math.round(value * 100)}%`} onChange={(value) => updateNumber("scale", value)} />
      <RangeField label="旋轉" value={settings.rotation} min={-180} max={180} step={1} format={(value) => `${Math.round(value)}°`} onChange={(value) => updateNumber("rotation", value)} />
      <RangeField label="透明度" value={settings.opacity} min={0.1} max={1} step={0.01} format={(value) => `${Math.round(value * 100)}%`} onChange={(value) => updateNumber("opacity", value)} />
      <RangeField label="亮度" value={settings.brightness} min={-0.5} max={0.5} step={0.01} format={(value) => value.toFixed(2)} onChange={(value) => updateNumber("brightness", value)} />
      <RangeField label="對比" value={settings.contrast} min={0.4} max={2} step={0.01} format={(value) => value.toFixed(2)} onChange={(value) => updateNumber("contrast", value)} />
      <label className="stamp-checkbox">
        <input type="checkbox" checked={settings.removesWhiteBackground} onChange={(event) => onChange({ removesWhiteBackground: event.target.checked })} />
        白底透明化效果
      </label>
      <label className="stamp-checkbox">
        <input type="checkbox" checked={settings.appliesTint} onChange={(event) => onChange({ appliesTint: event.target.checked })} />
        啟用印章色
      </label>
      <label className="stamp-color-field">
        <span>印章色</span>
        <input type="color" value={tintHex} disabled={!settings.appliesTint} onChange={(event) => updateTint(event.target.value)} />
        <small>{stampTint(settings)}</small>
      </label>
    </div>
  );
}

function RangeField({ label, value, min, max, step, format, onChange }) {
  return (
    <label className="stamp-range-field">
      <span>
        <strong>{label}</strong>
        <em>{format ? format(Number(value)) : value}</em>
      </span>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}

function RecordView({ title, records, selectedId, setSelectedId, addRecord, deleteRecord, updateRecord, fields, summary, usageCount, onBack, formClassName, autoSelectFirst = true }) {
  const selected = records.find((record) => record.id === selectedId) ?? (autoSelectFirst ? records[0] : null) ?? null;
  const selectedUsageCount = selected && usageCount ? usageCount(selected) : 0;
  return (
    <section className="records-layout">
      <aside className="records-list">
        {onBack && <DataBackButton onClick={onBack} />}
        <div className="section-actions">
          <h3>{title}</h3>
          <GuidedControl id={`records.add.${title}`} title="新增資料提示" description="点击后建立新的主档资料。之后在帐票输入框中可直接选择复用。">
            <button onClick={addRecord}>
              <Plus size={16} />
              新增
            </button>
          </GuidedControl>
        </div>
        {records.map((record) => (
          <button
            className={record.id === selected?.id ? "record-row active" : "record-row"}
            key={record.id}
            onClick={() => setSelectedId(record.id)}
          >
            <span>{summary(record)}</span>
            <small>{formatDate(record.updatedAt)}</small>
          </button>
        ))}
        {records.length === 0 && <div className="empty">尚無資料</div>}
      </aside>
      <section className="record-editor">
        {selected ? (
          <>
            <div className="section-actions">
              <h3>{summary(selected)}</h3>
              <button className="danger-button" onClick={() => deleteRecord(selected.id)}>
                <Trash2 size={16} />
                刪除
              </button>
            </div>
            {selectedUsageCount > 0 && (
              <div className="inline-warning">
                <AlertTriangle size={16} />
                <span>這筆候選資料已被 {selectedUsageCount} 份已保存表單使用。修改或刪除不會自動改寫已完成表單。</span>
              </div>
            )}
            <div className={["form-grid two-column", formClassName].filter(Boolean).join(" ")}>
              {fields.map(([field, label, type, options]) => (
                <RecordField
                  key={field}
                  field={field}
                  label={label}
                  type={type}
                  options={options}
                  value={selected[field] ?? ""}
                  onChange={(value) => updateRecord(selected.id, field, value)}
                />
              ))}
            </div>
          </>
        ) : (
          <div className="empty-state">
            <Archive size={40} />
            <h2>請新增一筆資料</h2>
          </div>
        )}
      </section>
    </section>
  );
}

function FileManagementView({ backup, onBack, openDocument, previewDocument, deleteDocuments, copyDocumentToProject }) {
  const [direction, setDirection] = useState("customer");
  const [projectName, setProjectName] = useState(null);
  const [documentViewMode, setDocumentViewMode] = useState("list");

  const projectGroups = useMemo(() => projectGroupsFromDocuments(backup.documents, direction), [backup.documents, direction]);
  const selectedProject = projectGroups.find((group) => group.name === projectName) ?? null;
  const level = projectName ? "documents" : "projects";

  function navigateBack() {
    if (level === "documents") setProjectName(null);
    else onBack();
  }

  function resetDirection(nextDirection) {
    setDirection(nextDirection);
    setProjectName(null);
  }

  const title =
    level === "documents"
      ? selectedProject?.name ?? "表單列表"
      : "檔案列表管理";

  return (
    <section className="panel-view">
      <div className="management-toolbar">
        <DataBackButton onClick={navigateBack} />
        <h2>{title}</h2>
        {level === "projects" && (
          <div className="segmented-control">
            {Object.entries(DOCUMENT_DIRECTION_GROUPS).map(([key, group]) => (
              <button type="button" className={direction === key ? "active" : ""} key={key} onClick={() => resetDirection(key)}>
                {group.label}
              </button>
            ))}
          </div>
        )}
      </div>

      {level === "projects" && (
        <ManagementList title={`${DOCUMENT_DIRECTION_GROUPS[direction]?.label ?? "客戶"}項目`} emptyText="沒有項目。">
          {projectGroups.map((group) => (
            <ManagementRow
              key={group.name}
              icon={Folder}
              title={group.name}
              subtitle={`${group.partnerName} / ${group.documents.length} 份表單 / ${formatDate(group.updatedAt)}`}
              onClick={() => setProjectName(group.name)}
              actions={
                <button
                  type="button"
                  className="icon-button danger-button"
                  title="刪除項目表單"
                  onClick={(event) => {
                    event.stopPropagation();
                    deleteDocuments(
                      group.documents.map((document) => document.id),
                      "已刪除項目內表單",
                      `刪除項目「${group.name}」內的 ${group.documents.length} 份表單？`,
                    );
                  }}
                >
                  <Trash2 size={16} />
                </button>
              }
            />
          ))}
        </ManagementList>
      )}

      {level === "documents" && (
        <DocumentListManagement
          documents={(selectedProject?.documents ?? []).sort(newestFirst)}
          backup={backup}
          viewMode={documentViewMode}
          setViewMode={setDocumentViewMode}
          openDocument={openDocument}
          previewDocument={previewDocument}
          copyDocumentToProject={copyDocumentToProject}
        />
      )}
    </section>
  );
}

function DocumentListManagement({ documents, backup, viewMode, setViewMode, openDocument, previewDocument, copyDocumentToProject }) {
  return (
    <div className="settings-panel">
      <div className="form-type-section-header">
        <h3>表單列表</h3>
        <div className="segmented-control form-view-toggle" aria-label="表單列表顯示方式">
          <button type="button" className={viewMode === "list" ? "active" : ""} onClick={() => setViewMode("list")}>
            <List size={15} />
            列表
          </button>
          <button type="button" className={viewMode === "preview" ? "active" : ""} onClick={() => setViewMode("preview")}>
            <LayoutGrid size={15} />
            小預覽圖
          </button>
        </div>
      </div>

      {documents.length === 0 ? (
        <div className="empty">沒有表單。</div>
      ) : viewMode === "preview" ? (
        <div className="document-preview-list-grid">
          {documents.map((document) => (
            <DocumentPreviewManagementCard
              key={document.id}
              document={document}
              backup={backup}
              onOpen={() => openDocument(document)}
              onPreview={() => previewDocument(document)}
              onCopy={copyDocumentToProject}
            />
          ))}
        </div>
      ) : (
        <div className="data-menu-list">
          {documents.map((document) => (
            <DocumentManagementRow
              key={document.id}
              document={document}
              backup={backup}
              onOpen={() => openDocument(document)}
              onPreview={() => previewDocument(document)}
              onCopy={copyDocumentToProject}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function ProjectManagementView({
  backup,
  onBack,
  openDocument,
  openProjectDocument,
  createProject,
  deleteDocuments,
  updateDocumentRelation,
  copyDocumentToProject,
  renameProject,
  updateProjectDetails,
}) {
  const [filter, setFilter] = useState("all");
  const [query, setQuery] = useState("");
  const groups = useMemo(() => projectGroupsFromDocuments(backup.documents), [backup.documents]);
  const filteredGroups = groups.filter((group) => {
    const matchesFilter = filter === "all" || group.direction === filter;
    const cleanQuery = query.trim().toLowerCase();
    const matchesQuery = !cleanQuery || `${group.name} ${group.partnerName}`.toLowerCase().includes(cleanQuery);
    return matchesFilter && matchesQuery;
  });

  return (
    <section className="panel-view">
      <div className="management-toolbar">
        <DataBackButton onClick={onBack} />
        <h2>項目列表管理</h2>
        <GuidedControl id="projects.add-button" title="新增項目提示" description="建立新项目后，可按客户或供应商流程集中管理多张相关表单。">
          <button type="button" onClick={() => createProject(filter === "vendor" ? "vendor" : "customer", "")}>
            <Plus size={16} />
            新增
          </button>
        </GuidedControl>
      </div>

      <div className="settings-panel">
        <div className="project-filter-row">
          <div className="segmented-control">
            {[
              ["all", "全部"],
              ["customer", "客戶"],
              ["vendor", "供應商"],
            ].map(([key, label]) => (
              <button type="button" className={filter === key ? "active" : ""} key={key} onClick={() => setFilter(key)}>
                {label}
              </button>
            ))}
          </div>
          <label className="modal-search project-search">
            <Search size={16} />
            <input
              {...plainInputAttributes("search")}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="按公司名搜索"
            />
          </label>
        </div>

        <div className="project-card-list">
          {filteredGroups.map((group) => (
            <ProjectCard
              key={`${group.direction}:${group.name}`}
              group={group}
              backup={backup}
              onOpenDocument={openDocument}
              onOpenType={(type) => openProjectDocument(group, type)}
              onDelete={() => {
                deleteDocuments(
                  group.documents.map((document) => document.id),
                  "已刪除項目",
                  `刪除項目「${group.name}」與其中 ${group.documents.length} 份表單？`,
                );
              }}
              onUpdateRelation={updateDocumentRelation}
              onCopy={copyDocumentToProject}
              onRename={renameProject}
              onUpdateProject={updateProjectDetails}
            />
          ))}
          {filteredGroups.length === 0 && <div className="empty">沒有符合條件的項目。</div>}
        </div>
      </div>
    </section>
  );
}

function ManagementList({ title, emptyText, children }) {
  const items = React.Children.toArray(children).filter(Boolean);
  return (
    <div className="settings-panel">
      <h3>{title}</h3>
      <div className="data-menu-list">{items.length ? items : <div className="empty">{emptyText}</div>}</div>
    </div>
  );
}

function ManagementRow({ icon: Icon, title, subtitle, onClick, actions }) {
  const content = (
    <>
      <Icon size={18} />
      <span>
        <strong>{title}</strong>
        <small>{subtitle}</small>
      </span>
      {actions ? <span className="row-actions" onClick={(event) => event.stopPropagation()}>{actions}</span> : null}
      <ChevronRight size={17} />
    </>
  );

  if (actions) {
    return (
      <div
        className="data-menu-button data-menu-row"
        role="button"
        tabIndex={0}
        onClick={onClick}
        onKeyDown={(event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            onClick();
          }
        }}
      >
        {content}
      </div>
    );
  }

  return (
    <button type="button" className="data-menu-button" onClick={onClick}>
      {content}
    </button>
  );
}

function DocumentManagementRow({ document, backup, onOpen, onPreview, onCopy }) {
  const projects = projectGroupsFromDocuments(backup.documents).filter((project) => project.direction === documentDirectionForDocumentType(document.type));
  return (
    <div className="document-management-row">
      <div>
        <strong>{document.number || DOCUMENT_TYPE_LABELS[document.type] || "未命名表單"}</strong>
        <small>{documentSummaryText(document)}</small>
      </div>
      <div className="actions-row compact-actions">
        <button type="button" className="icon-button secondary-button" title="預覽" onClick={onPreview}>
          <Eye size={16} />
        </button>
        <button type="button" className="icon-button secondary-button" title="編輯" onClick={onOpen}>
          <Pencil size={16} />
        </button>
        <select
          defaultValue=""
          title="複製到項目"
          onChange={(event) => {
            const project = projects.find((item) => item.name === event.target.value);
            if (project) onCopy(document, project, "append");
            event.target.value = "";
          }}
        >
          <option value="">複製到項目</option>
          {projects.map((project) => (
            <option key={`${project.direction}:${project.name}`} value={project.name}>
              {project.name}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}

function DocumentPreviewManagementCard({ document, backup, onOpen, onPreview, onCopy }) {
  const projects = projectGroupsFromDocuments(backup.documents).filter((project) => project.direction === documentDirectionForDocumentType(document.type));
  return (
    <article className="document-preview-management-card">
      <div className="document-preview-thumb-frame">
        <MiniPdfPreview document={document} />
        <div className="document-preview-overlay-actions" aria-label="表單操作">
          <button type="button" className="document-preview-overlay-button" title="預覽" onClick={onPreview}>
            <Eye size={19} />
          </button>
          <button type="button" className="document-preview-overlay-button" title="編輯" onClick={onOpen}>
            <Pencil size={19} />
          </button>
        </div>
      </div>
      <div className="document-preview-management-body">
        <strong>{document.number || DOCUMENT_TYPE_LABELS[document.type] || "未命名表單"}</strong>
        <small>{documentSummaryText(document)}</small>
      </div>
      <div className="actions-row compact-actions document-preview-actions">
        <select
          defaultValue=""
          title="複製到項目"
          onChange={(event) => {
            const project = projects.find((item) => item.name === event.target.value);
            if (project) onCopy(document, project, "append");
            event.target.value = "";
          }}
        >
          <option value="">複製到項目</option>
          {projects.map((project) => (
            <option key={`${project.direction}:${project.name}`} value={project.name}>
              {project.name}
            </option>
          ))}
        </select>
      </div>
    </article>
  );
}

function ProjectCard({ group, backup, onOpenDocument, onOpenType, onDelete, onUpdateRelation, onCopy, onRename, onUpdateProject }) {
  const [editModalOpen, setEditModalOpen] = useState(false);
  const requiredTypes = DOCUMENT_DIRECTION_GROUPS[group.direction]?.types ?? [];
  const completedCount = requiredTypes.filter((type) => group.documents.some((document) => document.type === type)).length;
  const numberedDocuments = group.documents.filter((document) => document.number);

  return (
    <article className="project-card">
      <div className="project-card-header">
        <div>
          <h3>{group.name}</h3>
          <p>{DOCUMENT_DIRECTION_GROUPS[group.direction]?.label} / {completedCount}/{requiredTypes.length} 個完成 / {group.partnerName}</p>
        </div>
        <div className="actions-row compact-actions">
          <button type="button" className="secondary-button" onClick={() => setEditModalOpen(true)}>
            <Pencil size={16} />
            編輯
          </button>
          <button type="button" className="danger-button" onClick={onDelete}>
            <Trash2 size={16} />
            刪除
          </button>
        </div>
      </div>

      <div className="project-type-grid">
        {requiredTypes.map((type) => {
          const typedDocuments = group.documents.filter((document) => document.type === type).sort(newestFirst);
          const document = typedDocuments[0];
          const related = document?.relatedNumber
            ? numberedDocuments.find((candidate) => candidate.number === document.relatedNumber)
            : null;
          return (
            <button type="button" className={document ? "project-type-card" : "project-type-card empty-type"} key={type} onClick={() => (document ? onOpenDocument(document) : onOpenType(type))}>
              <div className="project-type-thumb-frame">
                <FormPreviewThumbnail document={document} />
                <span className="project-type-overlay-icon" aria-hidden="true">
                  {document ? <Pencil size={20} /> : <Upload size={22} />}
                </span>
              </div>
              <span className="project-type-card-body">
                <span>{DOCUMENT_TYPE_LABELS[type] ?? type}</span>
                <strong>{document?.number || "未建立"}</strong>
                {typedDocuments.length > 1 && <small>{typedDocuments.length} 筆</small>}
                <em className={document?.relatedNumber ? "relation-status linked" : "relation-status"}>
                  {document?.relatedNumber
                    ? `關聯：${related ? DOCUMENT_TYPE_LABELS[related.type] ?? related.type : document.relatedNumber}`
                    : "未關聯"}
                </em>
              </span>
            </button>
          );
        })}
      </div>

      {editModalOpen && (
        <ProjectEditModal
          group={group}
          onCancel={() => setEditModalOpen(false)}
          onSave={async (values) => {
            await onUpdateProject?.(group, values);
            setEditModalOpen(false);
          }}
        />
      )}
    </article>
  );
}

function ProjectEditModal({ group, onCancel, onSave }) {
  const sortedDocuments = useMemo(() => [...group.documents].sort(newestFirst), [group.documents]);
  const [projectName, setProjectName] = useState(group.name);
  const [rows, setRows] = useState(() =>
    sortedDocuments.map((document) => ({
      id: document.id,
      type: document.type,
      number: document.number,
      updatedAt: document.updatedAt,
      issueDate: document.issueDate,
      transactionDate: document.transactionDate,
      dueDate: document.dueDate,
      relatedNumber: document.relatedNumber ?? "",
    })),
  );
  const relationOptions = rows.filter((row) => row.number);

  function updateRow(id, field, value) {
    setRows((current) =>
      current.map((row) => (row.id === id ? { ...row, [field]: ["issueDate", "transactionDate", "dueDate"].includes(field) ? fromDateInputValue(value) : value } : row)),
    );
  }

  function submit(event) {
    event.preventDefault();
    onSave({ name: projectName, documents: rows });
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <form className="modal-panel project-edit-modal" onSubmit={submit}>
        <div className="section-actions sticky-modal-header">
          <div>
            <h3>編輯項目</h3>
            <p className="modal-subtitle">修改項目名稱、日期與表單關聯。</p>
          </div>
          <button type="button" className="secondary-button" onClick={onCancel}>
            取消
          </button>
        </div>

        <div className="form-grid two-column modal-grid">
          <label className="wide-field">
            項目名稱
            <input
              {...plainInputAttributes()}
              value={projectName}
              onChange={(event) => setProjectName(event.target.value)}
              onKeyDown={(event) => handleLiteralMinus(event, setProjectName)}
            />
          </label>
        </div>

        <div className="project-edit-table">
          <div className="project-edit-head">
            <span>表單</span>
            <span>日期</span>
            <span>期限</span>
            <span>發行日期</span>
            <span>交易日期</span>
            <span>關聯</span>
          </div>
          {rows.map((row) => (
            <div className="project-edit-row" key={row.id}>
              <div>
                <strong>{DOCUMENT_TYPE_LABELS[row.type] ?? row.type}</strong>
                <small>{row.number || "未命名表單"}</small>
              </div>
              <input type="date" value={toDateInputValue(row.updatedAt)} disabled />
              <input type="date" value={toDateInputValue(row.dueDate)} onChange={(event) => updateRow(row.id, "dueDate", event.target.value)} />
              <input type="date" value={toDateInputValue(row.issueDate)} onChange={(event) => updateRow(row.id, "issueDate", event.target.value)} />
              <input type="date" value={toDateInputValue(row.transactionDate)} onChange={(event) => updateRow(row.id, "transactionDate", event.target.value)} />
              <select value={row.relatedNumber ?? ""} onChange={(event) => updateRow(row.id, "relatedNumber", event.target.value)}>
                <option value="">未關聯</option>
                {relationOptions
                  .filter((candidate) => candidate.id !== row.id)
                  .map((candidate) => (
                    <option key={candidate.id} value={candidate.number}>
                      {candidate.number}
                    </option>
                  ))}
              </select>
            </div>
          ))}
        </div>

        <div className="modal-actions">
          <button type="submit">
            <Save size={16} />
            保存
          </button>
        </div>
      </form>
    </div>
  );
}

function BackupView({ paths, backup, importMode, setImportMode, handleFileImport, handleExport }) {
  return (
    <section className="panel-view">
      <div className="settings-grid">
        <Metric label="帳票" value={backup.documents.length} />
        <Metric label="客戶" value={backup.customers.length} />
        <Metric label="發行者" value={backup.issuers.length} />
        <Metric label="商品" value={backup.products.length} />
      </div>
      <div className="settings-panel">
        <h3>備份匯入與匯出</h3>
        <p>匯入 iOS app 或桌面版產生的 `.shokobackup`。合併匯入會保留本機既有資料；替換本地會使用備份檔重建資料。</p>
        <div className="backup-actions inline-actions">
          <select value={importMode} onChange={(event) => setImportMode(event.target.value)}>
            <option value="merge">合併匯入</option>
            <option value="replace">替換本地</option>
          </select>
          <label className="file-button">
            <Upload size={16} />
            匯入
            <input type="file" accept=".shokobackup,application/json" onChange={handleFileImport} />
          </label>
          <button onClick={handleExport}>
            <Download size={16} />
            匯出
          </button>
        </div>
      </div>
      <div className="settings-panel">
        <h3>本地資料夾</h3>
        <PathRow label="Root" value={paths?.root} />
        <PathRow label="Backups" value={paths?.backups} />
        <PathRow label="Imports" value={paths?.imports} />
        <PathRow label="Exports" value={paths?.exports} />
        <PathRow label="State" value={paths?.state_file} />
      </div>
    </section>
  );
}

function SettingsView({
  licenseStatus,
  paths,
  backup,
  importMode,
  setImportMode,
  handleFileImport,
  handleExport,
  handleImportDemoBackup,
  handleDeleteAllDocuments,
  handleChooseDataFolder,
  handleResetDataFolder,
  isNativeOperationPending,
  appSettings,
  updateDesktopSettings,
  applyDefaultColorTemplate,
  activateLicense,
  clearLicense,
  restoreDeletedDocuments,
  permanentlyDeleteRecords,
}) {
  const [activePanel, setActivePanel] = useState(null);
  const [pendingLanguageSettings, setPendingLanguageSettings] = useState(() => ({
    interfaceLanguageId: appSettings.interfaceLanguageId,
    pdfLanguageId: appSettings.pdfLanguageId,
  }));
  const [pendingColorTemplateId, setPendingColorTemplateId] = useState(appSettings.defaultColorTemplateId);
  const text = settingsText(appSettings.interfaceLanguageId);
  const interfaceLanguage = APP_LANGUAGES.find((language) => language.id === appSettings.interfaceLanguageId) ?? APP_LANGUAGES[0];
  const pdfLanguage = APP_LANGUAGES.find((language) => language.id === appSettings.pdfLanguageId) ?? APP_LANGUAGES[0];
  const currentColorTemplate = colorTemplateOption(appSettings.defaultColorTemplateId);
  const pendingColorTemplate = colorTemplateOption(pendingColorTemplateId);

  useEffect(() => {
    if (activePanel === "language") {
      setPendingLanguageSettings({
        interfaceLanguageId: appSettings.interfaceLanguageId,
        pdfLanguageId: appSettings.pdfLanguageId,
      });
    }
    if (activePanel === "color") {
      setPendingColorTemplateId(appSettings.defaultColorTemplateId);
    }
  }, [activePanel, appSettings.interfaceLanguageId, appSettings.pdfLanguageId, appSettings.defaultColorTemplateId]);

  function confirmLanguageSettings() {
    updateDesktopSettings(pendingLanguageSettings);
    setActivePanel(null);
  }

  async function confirmColorTemplate() {
    await applyDefaultColorTemplate(pendingColorTemplateId);
    setActivePanel(null);
  }

  const settingCards = [
    {
      id: "language",
      title: text.cards.language[0],
      description: text.cards.language[1],
      meta: `${interfaceLanguage.title} / ${pdfLanguage.title}`,
      icon: Languages,
    },
    {
      id: "color",
      title: text.cards.color[0],
      description: text.cards.color[1],
      meta: currentColorTemplate.title,
      icon: Palette,
    },
    {
      id: "guidance",
      title: text.cards.guidance[0],
      description: text.cards.guidance[1],
      meta: appSettings.guidanceEnabled ? text.guidanceOn : text.guidanceOff,
      icon: CircleHelp,
    },
    {
      id: "backup",
      title: text.cards.backup[0],
      description: text.cards.backup[1],
      meta: `${backup.documents.length} 份帳票`,
      icon: Archive,
    },
    {
      id: "storage",
      title: text.cards.storage[0],
      description: text.cards.storage[1],
      meta: paths?.is_custom ? "指定資料夾" : "系統預設",
      icon: FolderOpen,
    },
    {
      id: "license",
      title: text.cards.license[0],
      description: text.cards.license[1],
      meta: licenseStatus.ok ? "已保存" : "未設定",
      icon: KeyRound,
    },
    {
      id: "support",
      title: text.cards.support[0],
      description: text.cards.support[1],
      meta: "service@niix.jp",
      icon: LifeBuoy,
    },
    {
      id: "guide",
      title: text.cards.guide[0],
      description: text.cards.guide[1],
      meta: text.cards.guide[2],
      icon: BookOpen,
    },
  ];

  return (
    <section className="settings-page">
      <div className="settings-hero">
        <div>
          <span>{text.pageEyebrow}</span>
          <h2>{text.pageTitle}</h2>
          <p>{text.pageDescription}</p>
        </div>
      </div>

      <div className="settings-stats-row">
        <Metric label={text.stats.documents} value={backup.documents.length} />
        <Metric label={text.stats.customers} value={backup.customers.length} />
        <Metric label={text.stats.issuers} value={backup.issuers.length} />
        <Metric label={text.stats.products} value={backup.products.length} />
      </div>

      <div className="settings-card-grid">
        {settingCards.map((card) => {
          const Icon = card.icon;
          return (
            <GuidedControl
              id={`settings.card.${card.id}`}
              title={`${card.title}提示`}
              description={card.id === "guidance" ? "这里可以开启或关闭全应用的小提示，也可以重置已看过的提示。" : "点击卡片打开对应设置。设置内容会在确认后保存到本机。"}
              className="guided-control-fill"
              key={card.id}
            >
              <button type="button" className="settings-card-button" onClick={() => setActivePanel(card.id)}>
                <span className="settings-card-icon">
                  <Icon size={22} />
                </span>
                <span className="settings-card-body">
                  <strong>{card.title}</strong>
                  <small>{card.description}</small>
                </span>
                <em>{card.meta}</em>
              </button>
            </GuidedControl>
          );
        })}
      </div>

      {activePanel === "language" && (
        <SettingsModal title={text.languageTitle} closeLabel={text.close} onClose={() => setActivePanel(null)}>
          <div className="settings-modal-section">
            <h3>{text.languageHeading}</h3>
            <p>{text.languageDescription}</p>
            <div className="language-setting-grid">
              <LanguagePickerCard
                title={text.interfaceLanguage}
                value={pendingLanguageSettings.interfaceLanguageId}
                onChange={(value) => setPendingLanguageSettings((current) => ({ ...current, interfaceLanguageId: value }))}
              />
              <LanguagePickerCard
                title={text.pdfLanguage}
                value={pendingLanguageSettings.pdfLanguageId}
                onChange={(value) => setPendingLanguageSettings((current) => ({ ...current, pdfLanguageId: value }))}
              />
            </div>
          </div>
          <div className="settings-confirm-actions">
            <button type="button" className="secondary-button" onClick={() => setActivePanel(null)}>
              {text.cancel}
            </button>
            <button type="button" onClick={confirmLanguageSettings}>
              <Check size={16} />
              {text.applyLanguage}
            </button>
          </div>
        </SettingsModal>
      )}

      {activePanel === "color" && (
        <SettingsModal title={text.colorTitle} closeLabel={text.close} onClose={() => setActivePanel(null)}>
          <div className="settings-modal-section">
            <h3>{text.colorHeading}</h3>
            <p>{text.colorDescription}</p>
            <ColorTemplatePicker
              value={pendingColorTemplateId}
              onChange={setPendingColorTemplateId}
            />
            <div className="selected-color-summary" style={{ "--template-accent": pendingColorTemplate.accent }}>
              <span />
              <div>
                <small>{text.selectedColor}</small>
                <strong>{pendingColorTemplate.title}</strong>
              </div>
            </div>
          </div>
          <div className="settings-confirm-actions">
            <button type="button" className="secondary-button" onClick={() => setActivePanel(null)}>
              {text.cancel}
            </button>
            <button type="button" onClick={confirmColorTemplate}>
              <Check size={16} />
              {text.applyColor}
            </button>
          </div>
        </SettingsModal>
      )}

      {activePanel === "guidance" && (
        <SettingsModal title={text.guidanceTitle} closeLabel={text.close} onClose={() => setActivePanel(null)}>
          <GuidanceSettingsPanel
            text={text}
            appSettings={appSettings}
            updateDesktopSettings={updateDesktopSettings}
          />
        </SettingsModal>
      )}

      {activePanel === "backup" && (
        <SettingsModal title={text.backupTitle} closeLabel={text.close} onClose={() => setActivePanel(null)}>
          <div className="settings-modal-section">
            <h3>備份操作</h3>
            <p>匯入 `.shokobackup` 時可以選擇合併或替換本地資料；匯出會保存目前全部資料。</p>
            <div className="backup-actions inline-actions">
              <select value={importMode} onChange={(event) => setImportMode(event.target.value)}>
                <option value="merge">合併匯入</option>
                <option value="replace">替換本地</option>
              </select>
              <label className={isNativeOperationPending ? "file-button disabled" : "file-button"}>
                <Upload size={16} />
                匯入備份
                <input type="file" accept=".shokobackup,application/json" onChange={handleFileImport} disabled={isNativeOperationPending} />
              </label>
              <button onClick={handleExport} disabled={isNativeOperationPending}>
                <Download size={16} />
                匯出備份
              </button>
              <button type="button" className="secondary-button" onClick={handleImportDemoBackup} disabled={isNativeOperationPending}>
                <FileCheck2 size={16} />
                導入 demo 檔案
              </button>
              <button type="button" className="danger-button" onClick={handleDeleteAllDocuments} disabled={isNativeOperationPending || backup.documents.length === 0}>
                <Trash2 size={16} />
                刪除全部文件
              </button>
            </div>
          </div>
          <div className="settings-modal-section">
            <h3>Demo 與清空文件</h3>
            <p>導入 demo 檔案會用內建測試資料替換目前本地資料，適合新用戶試用流程。刪除全部文件只會刪除帳票/文件，保留客戶、公司、商品與模板主檔；點擊後會再次彈窗確認。</p>
          </div>
          <div className="settings-modal-section">
            <h3>刪除歷史</h3>
            <p>已刪除文件會保留 30 天，期間可還原；永久刪除後不再保留於本機資料。</p>
            <DeletedDocumentHistory
              records={backup.deletedDocuments ?? []}
              onRestore={(id) => restoreDeletedDocuments([id])}
              onPermanentDelete={(id) => permanentlyDeleteRecords([id])}
            />
          </div>
          <div className="settings-modal-section">
            <h3>目前資料</h3>
            <div className="settings-stats-row compact">
              <Metric label="帳票" value={backup.documents.length} />
              <Metric label="客戶" value={backup.customers.length} />
              <Metric label="發行者" value={backup.issuers.length} />
              <Metric label="商品" value={backup.products.length} />
            </div>
          </div>
        </SettingsModal>
      )}

      {activePanel === "storage" && (
        <SettingsModal title={text.storageTitle} closeLabel={text.close} onClose={() => setActivePanel(null)}>
          <div className="settings-modal-section">
            <h3>資料位置</h3>
            <p>資料夾內會保存 `state.json`、匯入紀錄、匯出備份與歷史備份。更換資料夾後會讀取新資料夾內的資料。</p>
            <div className="actions-row">
              <button onClick={handleChooseDataFolder} disabled={isNativeOperationPending}>
                <FolderOpen size={16} />
                選擇資料夾
              </button>
              <button className="secondary-button" onClick={handleResetDataFolder} disabled={isNativeOperationPending}>
                <Folder size={16} />
                使用預設資料夾
              </button>
            </div>
          </div>
          <div className="settings-modal-section">
            <h3>路徑</h3>
            <PathRow label="Root" value={paths?.root} />
            <PathRow label="Backups" value={paths?.backups} />
            <PathRow label="Imports" value={paths?.imports} />
            <PathRow label="Exports" value={paths?.exports} />
            <PathRow label="State" value={paths?.state_file} />
            <PathRow label="Config" value={paths?.config_file} />
          </div>
        </SettingsModal>
      )}

      {activePanel === "license" && (
        <SettingsModal title={text.licenseTitle} closeLabel={text.close} onClose={() => setActivePanel(null)}>
          <div className="settings-modal-section">
            <h3>授權狀態</h3>
            <p>目前桌面版需要授權碼登入。登出授權碼後會立即回到登入頁，重新輸入有效授權碼才能進入系統。</p>
            <div className="license-summary">
              <KeyRound size={24} />
              <div>
                <strong>{licenseStatus.ok ? (licenseStatus.license?.customer ?? "已保存授權資料") : "未設定授權資料"}</strong>
                <span>
                  {licenseStatus.ok
                    ? `到期 ${formatLicenseDate(licenseStatus.expiresAt)}，剩餘 ${licenseStatus.daysRemaining} 天`
                    : "不影響桌面版功能使用"}
                </span>
              </div>
            </div>
            <LicenseSettings licenseStatus={licenseStatus} activateLicense={activateLicense} clearLicense={clearLicense} />
          </div>
        </SettingsModal>
      )}

      {activePanel === "support" && (
        <SettingsModal title={text.supportTitle} closeLabel={text.close} onClose={() => setActivePanel(null)}>
          <div className="settings-modal-section">
            <h3>售後服務</h3>
            <p>支援表單建立、保存、PDF 輸出、備份匯入匯出、授權碼與資料夾設定相關問題。</p>
            <div className="support-info-list">
              <SupportInfoRow label="公司" value="NIIX株式会社" />
              <SupportInfoRow label="Email" value="service@niix.jp" />
              <SupportInfoRow label="網站" value="https://niix.jp" />
            </div>
          </div>
          <div className="settings-modal-section">
            <h3>聯絡時請提供</h3>
            <div className="guide-bullet-list">
              <span>App 名稱：Shoko Forms Desktop</span>
              <span>作業系統：macOS 或 Windows 版本</span>
              <span>發生問題的頁面、操作順序、錯誤訊息或截圖</span>
              <span>相關表單類型、帳票編號與是否可重現</span>
            </div>
          </div>
        </SettingsModal>
      )}

      {activePanel === "guide" && (
        <SettingsModal title={text.guideTitle} closeLabel={text.close} onClose={() => setActivePanel(null)}>
          <div className="settings-modal-section">
            <DesktopUsageGuide />
          </div>
        </SettingsModal>
      )}
    </section>
  );
}

function DeletedDocumentHistory({ records = [], onRestore, onPermanentDelete }) {
  if (!records.length) {
    return <p className="empty-copy">目前沒有刪除歷史。</p>;
  }
  return (
    <div className="record-list compact">
      {records.map((record) => {
        const document = record.document ?? {};
        const title = document.number || DOCUMENT_TYPE_LABELS[document.type] || "未命名文件";
        return (
          <div className="record-row" key={record.id}>
            <div>
              <strong>{title}</strong>
              <small>{DOCUMENT_TYPE_LABELS[document.type] || document.type || "Document"} / 刪除於 {formatDate(record.deletedAt)}</small>
            </div>
            <div className="inline-actions">
              <button type="button" className="secondary-button" onClick={() => onRestore(record.id)}>
                <RotateCcw size={15} />
                還原
              </button>
              <button type="button" className="danger-button" onClick={() => onPermanentDelete(record.id)}>
                <Trash2 size={15} />
                永久刪除
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function LanguagePickerCard({ title, value, onChange }) {
  return (
    <div className="ios-setting-card">
      <div className="ios-setting-card-heading">
        <Languages size={18} />
        <strong>{title}</strong>
      </div>
      <div className="language-option-list">
        {APP_LANGUAGES.map((language) => (
          <button
            type="button"
            className={value === language.id ? "language-option active" : "language-option"}
            key={language.id}
            onClick={() => onChange(language.id)}
          >
            <span>
              <strong>{language.title}</strong>
              <small>{language.subtitle}</small>
            </span>
            {value === language.id && <Check size={16} />}
          </button>
        ))}
      </div>
    </div>
  );
}

function ColorTemplatePicker({ value, onChange }) {
  return (
    <div className="color-template-picker" role="list" aria-label="帳票配色">
      {COLOR_TEMPLATE_OPTIONS.map((template) => (
        <button
          type="button"
          className={value === template.id ? "color-template-choice active" : "color-template-choice"}
          key={template.id}
          onClick={() => onChange(template.id)}
          title={template.title}
          aria-label={template.title}
          style={{ "--template-accent": template.accent }}
        >
          <span className="color-template-dot">
            <span />
          </span>
          <strong>{template.title}</strong>
          {value === template.id && <Check size={14} />}
        </button>
      ))}
    </div>
  );
}

function SupportInfoRow({ label, value }) {
  return (
    <div className="support-info-row">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function SettingsModal({ title, closeLabel = "關閉", onClose, children }) {
  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal-panel settings-modal" role="dialog" aria-modal="true" aria-label={title}>
        <div className="section-actions sticky-modal-header">
          <h3>{title}</h3>
          <button type="button" className="secondary-button" onClick={onClose}>
            {closeLabel}
          </button>
        </div>
        <div className="settings-modal-content">{children}</div>
      </section>
    </div>
  );
}

function GuidedControl({ id, title, description, children, tone = "default", className = "" }) {
  const { enabled, seenHintIds, dismissHint } = React.useContext(GuidanceContext);
  const controlRef = useRef(null);
  const tooltipRef = useRef(null);
  const hideTimerRef = useRef(null);
  const [isActive, setIsActive] = useState(false);
  const [tooltipPosition, setTooltipPosition] = useState(null);
  const shouldRenderHint = enabled && !seenHintIds.includes(id);
  const showHint = shouldRenderHint && isActive && tooltipPosition;

  function clearHideTimer() {
    if (hideTimerRef.current) {
      window.clearTimeout(hideTimerRef.current);
      hideTimerRef.current = null;
    }
  }

  function scheduleHide() {
    clearHideTimer();
    hideTimerRef.current = window.setTimeout(() => setIsActive(false), 90);
  }

  function updateTooltipPosition() {
    const control = controlRef.current;
    if (!control) return;
    const rect = control.getBoundingClientRect();
    const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 1200;
    const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 800;
    const tooltip = tooltipRef.current;
    const tooltipWidth = Math.min(360, Math.max(280, tooltip?.offsetWidth || 320));
    const tooltipHeight = tooltip?.offsetHeight || 112;
    const margin = 12;
    const gap = 10;
    const centeredLeft = rect.left + rect.width / 2 - tooltipWidth / 2;
    const left = Math.min(viewportWidth - tooltipWidth - margin, Math.max(margin, centeredLeft));
    const canShowAbove = rect.top >= tooltipHeight + gap + margin;
    const top = canShowAbove
      ? Math.max(margin, rect.top - tooltipHeight - gap)
      : Math.min(viewportHeight - tooltipHeight - margin, rect.bottom + gap);
    const arrowLeft = Math.min(tooltipWidth - 18, Math.max(18, rect.left + rect.width / 2 - left));
    setTooltipPosition({
      arrowLeft,
      placement: canShowAbove ? "top" : "bottom",
      left,
      top,
      width: tooltipWidth,
    });
  }

  function showTooltip() {
    if (!shouldRenderHint) return;
    clearHideTimer();
    setIsActive(true);
    window.requestAnimationFrame(updateTooltipPosition);
  }

  useEffect(() => {
    if (!isActive) return undefined;
    updateTooltipPosition();
    window.addEventListener("resize", updateTooltipPosition);
    window.addEventListener("scroll", updateTooltipPosition, true);
    return () => {
      window.removeEventListener("resize", updateTooltipPosition);
      window.removeEventListener("scroll", updateTooltipPosition, true);
    };
  }, [isActive]);

  useEffect(() => () => clearHideTimer(), []);

  const tooltip = showHint
    ? createPortal(
        <aside
          className={`feature-hint feature-hint-${tone} feature-hint-${tooltipPosition.placement}`}
          aria-label={title}
          ref={tooltipRef}
          style={{
            "--hint-arrow-left": `${tooltipPosition.arrowLeft}px`,
            left: `${tooltipPosition.left}px`,
            top: `${tooltipPosition.top}px`,
            width: `${tooltipPosition.width}px`,
          }}
          onMouseEnter={clearHideTimer}
          onMouseLeave={scheduleHide}
        >
          <div className="feature-hint-icon">
            <CircleHelp size={15} />
          </div>
          <div className="feature-hint-copy">
            <strong>{title}</strong>
            <p>{description}</p>
          </div>
          <button
            type="button"
            className="feature-hint-dismiss"
            onClick={(event) => {
              event.stopPropagation();
              dismissHint(id);
              setIsActive(false);
            }}
          >
            了解
          </button>
        </aside>,
        document.body,
      )
    : null;

  return (
    <span
      className={["guided-control", className].filter(Boolean).join(" ")}
      ref={controlRef}
      onMouseEnter={showTooltip}
      onMouseLeave={scheduleHide}
      onFocusCapture={showTooltip}
      onBlurCapture={scheduleHide}
    >
      {children}
      {tooltip}
    </span>
  );
}

function GuidanceSettingsPanel({ text, appSettings, updateDesktopSettings }) {
  const { seenHintIds, resetHints } = React.useContext(GuidanceContext);
  const enabled = Boolean(appSettings.guidanceEnabled);
  return (
    <>
      <div className="settings-modal-section">
        <h3>{text.guidanceHeading}</h3>
        <p>{text.guidanceDescription}</p>
        <label className="settings-toggle-row">
          <span>
            <strong>{text.guidanceEnabled}</strong>
            <small>{enabled ? text.guidanceOn : text.guidanceOff} / 已看過 {seenHintIds.length} 個提示</small>
          </span>
          <input
            type="checkbox"
            checked={enabled}
            onChange={(event) => updateDesktopSettings({ guidanceEnabled: event.target.checked })}
          />
        </label>
      </div>
      <div className="settings-confirm-actions">
        <button type="button" className="secondary-button" onClick={resetHints}>
          <RotateCcw size={16} />
          {text.resetGuidance}
        </button>
      </div>
    </>
  );
}

function DesktopUsageGuide() {
  const sections = [
    {
      title: "1. 第一次啟動與資料夾",
      items: [
        "第一次開啟時需要選擇桌面端資料夾。系統會在該資料夾內建立 state.json、backups、imports、exports 與 temp。",
        "如果改變資料夾，桌面端會讀取新資料夾的資料；原資料夾不會被自動刪除，必要時可手動保留或備份。",
        "建議把資料夾放在固定位置，不要放在會被清理工具自動刪除的臨時目錄。",
      ],
    },
    {
      title: "2. 授權登入與登出",
      items: [
        "桌面版以授權碼登入。授權碼保存在本機，不會上傳到網路。",
        "登出授權碼會回到登入頁，下一次進入系統需要重新輸入有效授權碼。",
        "登出前系統會顯示確認與警告，避免使用者誤操作。",
      ],
    },
    {
      title: "3. 建立表單與項目",
      items: [
        "從帳票頁面選擇客戶表單或廠商表單，再選擇建立新項目或放入既有項目。",
        "彈窗內的卡片式選擇是桌面端標準互動：先選擇、再確認，不會在未確認前改變資料。",
        "項目可以集中管理多張表單，例如見積書、注文記録、納品書、請求書、領収書或廠商採購相關表單。",
      ],
    },
    {
      title: "4. 輸入資料與本地資料庫",
      items: [
        "客戶名稱、公司名稱、項目名稱、關聯號、品項與模板文字可從本地資料選取。",
        "輸入內容不存在時，系統會引導建立新資料，並以彈窗補齊詳細資訊。",
        "刪除公司、客戶、項目、商品、模板、表單等資料前都需要二次確認。",
      ],
    },
    {
      title: "5. PDF 預覽與輸出",
      items: [
        "PDF 預覽會依目前表單內容即時生成，版面以 A4 列印為基準。",
        "輸出前請確認客戶、發行者、地址、明細、稅率、金額、備註、條件與關聯號。",
        "保存/列印 PDF 會產生可列印檔案，建議先在預覽中確認沒有文字溢出或欄位錯誤。",
      ],
    },
    {
      title: "6. 備份、匯入與匯出",
      items: [
        "匯出備份會把目前本地資料打包成 .shokobackup，可用於 iOS App 或另一台桌面電腦。",
        "匯入備份可選擇合併或替換。替換前建議先匯出目前資料，保留可恢復版本。",
        "匯入完成後系統會顯示完成提示，確認資料已寫入本地資料夾。",
      ],
    },
    {
      title: "7. 語言與配色設定",
      items: [
        "操作界面語言與 PDF 帳票語言分開管理，方便內部操作與客戶輸出使用不同語言。",
        "語言與配色都採用先選擇、再確認套用的方式，避免點錯時直接改變全域設定。",
        "配色會作為新建表單的預設值，也可在確認後套用到目前正在編輯的表單。",
      ],
    },
    {
      title: "8. 安全與維護",
      items: [
        "桌面端資料保存在本機，請定期備份資料夾或匯出 .shokobackup。",
        "macOS 或 Windows 第一次安裝時可能提示未知開發者或安全確認；正式發佈版本建議進行簽名與 notarization。",
        "遇到異常時，請提供作業系統版本、資料夾路徑、操作步驟、錯誤訊息與截圖，方便定位問題。",
      ],
    },
  ];

  return (
    <div className="manual-section-list">
      {sections.map((section) => (
        <article className="manual-section" key={section.title}>
          <h4>{section.title}</h4>
          <ol className="manual-steps">
            {section.items.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ol>
        </article>
      ))}
    </div>
  );
}

function AppNoticeModal({ title, message, details = [], onClose }) {
  return (
    <div className="modal-backdrop notice-backdrop" role="presentation">
      <section className="modal-panel app-notice-modal" role="dialog" aria-modal="true" aria-label={title}>
        <div className="app-notice-icon">
          <Save size={24} />
        </div>
        <h3>{title}</h3>
        <p>{message}</p>
        {details.length > 0 && (
          <div className="app-notice-details">
            {details.map((detail) => (
              <span key={detail}>{detail}</span>
            ))}
          </div>
        )}
        <div className="modal-actions">
          <button type="button" onClick={onClose}>
            完成
          </button>
        </div>
      </section>
    </div>
  );
}

function DeleteConfirmModal({ title, message, details = [], confirmLabel = "確認刪除", onCancel, onConfirm }) {
  return (
    <div className="modal-backdrop delete-confirm-backdrop" role="presentation">
      <section className="modal-panel delete-confirm-modal" role="alertdialog" aria-modal="true" aria-label={title}>
        <div className="delete-confirm-icon">
          <Trash2 size={26} />
        </div>
        <div className="delete-confirm-copy">
          <span>二次確認</span>
          <h3>{title}</h3>
          <p>{message}</p>
        </div>
        <div className="delete-confirm-warning">
          <AlertTriangle size={18} />
          <strong>此操作無法復原，請確認後再執行。</strong>
        </div>
        {details.length > 0 && (
          <div className="delete-confirm-details">
            {details.map((detail) => (
              <span key={detail}>{detail}</span>
            ))}
          </div>
        )}
        <div className="delete-confirm-actions">
          <button type="button" className="secondary-button" onClick={onCancel}>
            取消
          </button>
          <button type="button" className="danger-button" onClick={onConfirm}>
            {confirmLabel}
          </button>
        </div>
      </section>
    </div>
  );
}

function UnsavedChangesModal({ documentNumber, onCancel, onDiscard, onSave }) {
  return (
    <div className="modal-backdrop unsaved-confirm-backdrop" role="presentation">
      <section className="modal-panel unsaved-confirm-modal" role="alertdialog" aria-modal="true" aria-label="未保存提醒">
        <div className="unsaved-confirm-icon">
          <AlertTriangle size={26} />
        </div>
        <div className="delete-confirm-copy">
          <span>未保存提醒</span>
          <h3>目前帳票尚未保存</h3>
          <p>帳票「{documentNumber || "未命名帳票"}」有尚未保存的變更。離開前請選擇保存、放棄，或繼續編輯。</p>
        </div>
        <div className="unsaved-confirm-warning">
          <AlertTriangle size={18} />
          <strong>選擇放棄會取消本次未保存的修改，並回到帳票的預設空白畫面。</strong>
        </div>
        <div className="unsaved-confirm-actions">
          <button type="button" className="secondary-button" onClick={onCancel}>
            繼續編輯
          </button>
          <button type="button" className="secondary-button" onClick={onDiscard}>
            放棄變更
          </button>
          <button type="button" onClick={onSave}>
            <Save size={16} />
            保存後離開
          </button>
        </div>
      </section>
    </div>
  );
}

function LicenseLoginPage({ onLogin, initialMessage }) {
  const [licenseKey, setLicenseKey] = useState("");
  const [message, setMessage] = useState(initialMessage || "請輸入授權碼登入。");

  function submit(event) {
    event.preventDefault();
    const result = onLogin(licenseKey);
    setMessage(result.ok ? "授權成功，正在進入系統。" : result.reason);
  }

  return (
    <main className="license-login-page">
      <video className="license-login-background-video" autoPlay loop muted playsInline aria-hidden="true">
        <source src="/login-background.mp4" type="video/mp4" />
      </video>
      <div className="license-login-visual" aria-hidden="true">
        <div className="login-logo-orbit orbit-one" />
        <div className="login-logo-orbit orbit-two" />
        <div className="login-logo-mark">
          <span>SHOKO</span>
        </div>
      </div>

      <section className="license-login-panel">
        <div className="license-login-brand">
          <FileJson size={24} />
          <div>
            <strong>Shoko Forms</strong>
            <span>Desktop License</span>
          </div>
        </div>
        <h1>授權碼登入</h1>
        <p>請輸入桌面版授權碼。授權通過後才會進入本地帳票管理系統。</p>
        <form className="license-login-form" onSubmit={submit}>
          <textarea
            {...plainInputAttributes()}
            value={licenseKey}
            onChange={(event) => setLicenseKey(event.target.value)}
            onKeyDown={(event) => handleLiteralMinus(event, setLicenseKey)}
            placeholder="SHOKO-..."
            autoFocus
          />
          <button type="submit">
            <KeyRound size={17} />
            登入
          </button>
        </form>
        <div className="license-login-message">{message}</div>
      </section>
    </main>
  );
}

function StorageSetupModal({ paths, onChooseFolder, onConfirmDefault, isPending }) {
  return (
    <div className="modal-backdrop first-run-backdrop" role="presentation">
      <section className="modal-panel storage-setup-modal" role="dialog" aria-modal="true" aria-label="本地資料夾確認">
        <div className="storage-setup-icon">
          <FolderOpen size={26} />
        </div>
        <h3>選擇資料保存資料夾</h3>
        <p>第一次啟動時請確認 Shoko Forms Desktop 的本地資料夾。帳票、備份、匯入與匯出記錄都會保存在這個位置。</p>
        <div className="storage-setup-current">
          <span>目前資料夾</span>
          <strong>{paths?.root ?? "正在準備資料夾"}</strong>
        </div>
        <div className="storage-setup-actions">
          <GuidedControl id="first-run.choose-folder" title="首次資料夾提示" description="建议选择固定资料夹。之后帐票、备份、汇入与汇出记录都会保存在这里。" tone="modal">
            <button type="button" onClick={onChooseFolder} disabled={isPending}>
              <FolderOpen size={16} />
              選擇資料夾
            </button>
          </GuidedControl>
          <button type="button" className="secondary-button" onClick={onConfirmDefault} disabled={isPending}>
            <Save size={16} />
            使用目前資料夾
          </button>
        </div>
      </section>
    </div>
  );
}

function LicenseSettings({ licenseStatus, activateLicense, clearLicense }) {
  const [licenseKey, setLicenseKey] = useState("");
  const [message, setMessage] = useState("可更新目前授權碼，或登出回到登入頁。");
  const [logoutConfirmOpen, setLogoutConfirmOpen] = useState(false);

  function submit(event) {
    event.preventDefault();
    const result = activateLicense(licenseKey);
    setMessage(result.ok ? "授權資料已更新。" : result.reason);
  }

  function confirmLogout() {
    setLogoutConfirmOpen(false);
    clearLicense();
    setLicenseKey("");
    setMessage("已登出授權碼。");
  }

  return (
    <>
      <form className="license-inline-form" onSubmit={submit}>
        <textarea
          {...plainInputAttributes()}
          value={licenseKey}
          onChange={(event) => setLicenseKey(event.target.value)}
          onKeyDown={(event) => handleLiteralMinus(event, setLicenseKey)}
          placeholder="SHOKO-..."
        />
        <div className="actions-row">
          <button type="submit">
            <KeyRound size={16} />
            保存授權資料
          </button>
          <button
            type="button"
            className="danger-button"
            onClick={() => setLogoutConfirmOpen(true)}
          >
            登出授權碼
          </button>
        </div>
        <div className="license-message compact">{message}</div>
      </form>
      {logoutConfirmOpen && (
        <LogoutConfirmModal
          licenseStatus={licenseStatus}
          onCancel={() => setLogoutConfirmOpen(false)}
          onConfirm={confirmLogout}
        />
      )}
    </>
  );
}

function LogoutConfirmModal({ licenseStatus, onCancel, onConfirm }) {
  return (
    <div className="modal-backdrop logout-warning-backdrop" role="presentation">
      <section className="modal-panel logout-warning-modal" role="alertdialog" aria-modal="true" aria-label="確認登出授權碼">
        <div className="logout-warning-icon">
          <AlertTriangle size={28} />
        </div>
        <div className="logout-warning-copy">
          <span>警告</span>
          <h3>確定要登出授權碼？</h3>
          <p>登出後會立即離開桌面系統並回到授權碼登入頁。重新輸入有效授權碼前，不能進入本地帳票管理畫面。</p>
        </div>
        <div className="logout-warning-summary">
          <KeyRound size={20} />
          <div>
            <strong>{licenseStatus.ok ? (licenseStatus.license?.customer ?? "已保存授權資料") : "目前授權資料"}</strong>
            <span>
              {licenseStatus.ok
                ? `到期 ${formatLicenseDate(licenseStatus.expiresAt)}，剩餘 ${licenseStatus.daysRemaining} 天`
                : "登出會清除本機保存的授權碼"}
            </span>
          </div>
        </div>
        <div className="logout-warning-actions">
          <button type="button" className="secondary-button" onClick={onCancel}>
            取消
          </button>
          <button type="button" className="danger-button" onClick={onConfirm}>
            確認登出
          </button>
        </div>
      </section>
    </div>
  );
}

async function createPdfBytesFromElement(element) {
  const [{ default: html2canvas }, { jsPDF }] = await Promise.all([import("html2canvas"), import("jspdf")]);
  await new Promise((resolve) => requestAnimationFrame(resolve));

  const pdf = new jsPDF({ format: "a4", orientation: "portrait", unit: "mm" });
  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();

  const exportHost = window.document.createElement("div");
  exportHost.className = "pdf-export-host";
  const exportPage = element.cloneNode(true);
  exportPage.classList.add("pdf-export-page");
  exportPage.style.setProperty("--pdf-accent", element.style.getPropertyValue("--pdf-accent"));
  exportPage.style.setProperty("--pdf-soft-line", element.style.getPropertyValue("--pdf-soft-line"));
  exportPage.style.setProperty("--pdf-table-head", element.style.getPropertyValue("--pdf-table-head"));
  exportPage.style.setProperty("--pdf-total-background", element.style.getPropertyValue("--pdf-total-background"));
  exportHost.appendChild(exportPage);
  window.document.body.appendChild(exportHost);
  await new Promise((resolve) => requestAnimationFrame(resolve));

  const captureWidth = 595.2;
  const captureHeight = Math.max(841.8, Math.ceil(exportPage.scrollHeight));
  let canvas;
  try {
    const captureOptions = {
      backgroundColor: "#ffffff",
      logging: false,
      scale: 2,
      scrollX: 0,
      scrollY: 0,
      useCORS: true,
      width: captureWidth,
      height: captureHeight,
      windowWidth: captureWidth,
      windowHeight: captureHeight,
    };
    canvas = await html2canvas(exportPage, {
      ...captureOptions,
      foreignObjectRendering: true,
    });
    if (isCanvasMostlyBlank(canvas)) {
      canvas = await html2canvas(exportPage, captureOptions);
    }
  } finally {
    exportHost.remove();
  }

  const imageWidth = pageWidth;
  const rawImageHeight = (canvas.height * imageWidth) / canvas.width;
  const imageHeight = rawImageHeight <= pageHeight + 1 ? pageHeight : rawImageHeight;
  const imageData = canvas.toDataURL("image/png");

  let y = 0;
  let remainingHeight = imageHeight;
  let pageCount = 1;
  pdf.addImage(imageData, "PNG", 0, y, imageWidth, imageHeight);
  remainingHeight -= pageHeight;

  while (remainingHeight > 0.5) {
    y -= pageHeight;
    pdf.addPage();
    pageCount += 1;
    pdf.addImage(imageData, "PNG", 0, y, imageWidth, imageHeight);
    remainingHeight -= pageHeight;
  }

  if (pageCount > 1) {
    pdf.setFontSize(8.1);
    pdf.setFont("helvetica", "bold");
    for (let pageIndex = 1; pageIndex <= pageCount; pageIndex += 1) {
      pdf.setPage(pageIndex);
      pdf.text(`${pageIndex}/${pageCount}`, pageWidth / 2, pageHeight - 9.9, { align: "center" });
    }
  }

  return new Uint8Array(pdf.output("arraybuffer"));
}

function isCanvasMostlyBlank(canvas) {
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (!context) return false;
  const sampleWidth = Math.max(1, Math.floor(canvas.width / 40));
  const sampleHeight = Math.max(1, Math.floor(canvas.height / 40));
  const imageData = context.getImageData(0, 0, canvas.width, canvas.height).data;
  let sampled = 0;
  let nonWhite = 0;
  for (let y = 0; y < canvas.height; y += sampleHeight) {
    for (let x = 0; x < canvas.width; x += sampleWidth) {
      const index = (y * canvas.width + x) * 4;
      const red = imageData[index];
      const green = imageData[index + 1];
      const blue = imageData[index + 2];
      const alpha = imageData[index + 3];
      sampled += 1;
      if (alpha > 12 && (red < 245 || green < 245 || blue < 245)) {
        nonWhite += 1;
      }
    }
  }
  return sampled > 0 && nonWhite / sampled < 0.002;
}

function PDFPreviewModal({ document, pdfLanguageId = "japanese", onStampStateChange, onClose }) {
  const PDF_PAGE_WIDTH = 595.2;
  const PDF_PAGE_HEIGHT = 841.8;
  const totals = documentTotal(document);
  const previewScrollRef = useRef(null);
  const pdfPageRef = useRef(null);
  const stampDragRef = useRef(false);
  const initialStamps = useMemo(() => loadStoredStamps(), []);
  const [message, setMessage] = useState("");
  const [previewScale, setPreviewScale] = useState(1);
  const [fitPreviewScale, setFitPreviewScale] = useState(1);
  const [previewZoomMode, setPreviewZoomMode] = useState("fit");
  const [stamps, setStamps] = useState(initialStamps);
  const [selectedStampId, setSelectedStampId] = useState(() => resolveStampId(document, initialStamps));
  const [stampSettings, setStampSettings] = useState(() =>
    normalizeStampSettings(document.stampSettings ?? DEFAULT_STAMP_SETTINGS),
  );
  const [isStampVisible, setIsStampVisible] = useState(() => document.stampVisible ?? Boolean(initialStamps.length));
  const [isStampEditorOpen, setIsStampEditorOpen] = useState(false);
  const [pdfOperation, setPdfOperation] = useState(null);
  const pdfOperationRef = useRef(null);
  const selectedStamp = useMemo(
    () => stamps.find((stamp) => stamp.id === selectedStampId) ?? null,
    [selectedStampId, stamps],
  );
  const stampImage = selectedStamp?.dataUrl || "";
  const labels = pdfLabels(pdfLanguageId);
  const presentation = documentPresentationRules(document.type);
  const displayTotal = presentation.showTax ? totals.total : totals.subtotal;

  useEffect(() => {
    const nextStamps = loadStoredStamps();
    const nextStampId = resolveStampId(document, nextStamps);
    setStamps(nextStamps);
    setSelectedStampId(nextStampId);
    setStampSettings(normalizeStampSettings(document.stampSettings ?? DEFAULT_STAMP_SETTINGS));
    setIsStampVisible(document.stampVisible ?? Boolean(nextStampId));
  }, [document.id]);

  function saveCurrentDocumentStamp(nextSettings = stampSettings, nextVisible = isStampVisible, nextStampId = selectedStampId) {
    onStampStateChange?.(document.id, {
      stampSettings: nextSettings,
      stampVisible: nextVisible,
      stampImageId: nextStampId || null,
    });
  }

  useEffect(() => {
    const scrollElement = previewScrollRef.current;
    if (!scrollElement) return undefined;

    function updatePreviewScale() {
      const styles = window.getComputedStyle(scrollElement);
      const horizontalPadding = parseFloat(styles.paddingLeft || "0") + parseFloat(styles.paddingRight || "0");
      const verticalPadding = parseFloat(styles.paddingTop || "0") + parseFloat(styles.paddingBottom || "0");
      const availableWidth = scrollElement.clientWidth - horizontalPadding;
      const availableHeight = scrollElement.clientHeight - verticalPadding;
      if (availableWidth < 80 || availableHeight < 80) return;
      const nextScale = Math.min(availableWidth / PDF_PAGE_WIDTH, availableHeight / PDF_PAGE_HEIGHT);
      if (!Number.isFinite(nextScale) || nextScale <= 0) return;
      const roundedScale = Number(nextScale.toFixed(3));
      setFitPreviewScale(roundedScale);
      setPreviewScale((current) => (previewZoomMode === "fit" ? roundedScale : current));
    }

    const animationFrame = window.requestAnimationFrame(updatePreviewScale);
    const observer = new ResizeObserver(updatePreviewScale);
    observer.observe(scrollElement);
    window.addEventListener("resize", updatePreviewScale);
    return () => {
      window.cancelAnimationFrame(animationFrame);
      observer.disconnect();
      window.removeEventListener("resize", updatePreviewScale);
    };
  }, [previewZoomMode]);

  function updatePreviewZoom(nextScale, mode = "manual") {
    const clampedScale = clampNumber(nextScale, 0.35, 3);
    setPreviewScale(Number(clampedScale.toFixed(2)));
    setPreviewZoomMode(mode);
  }

  function zoomPreviewBy(delta) {
    updatePreviewZoom(previewScale + delta);
  }

  function fitPreviewToWindow() {
    updatePreviewZoom(fitPreviewScale, "fit");
  }

  async function generatePreviewPdfBytes() {
    const pageElement = pdfPageRef.current;
    if (!pageElement) {
      throw new Error("找不到 PDF 預覽內容。");
    }
    return createPdfBytesFromElement(pageElement);
  }

  function pdfFileName() {
    const safeNumber = String(document.number || "shoko-document").replace(/[\\/:*?"<>|]+/g, "-");
    return `${safeNumber}.pdf`;
  }

  async function runPdfOperation(label, action) {
    if (pdfOperationRef.current) {
      setMessage(`${pdfOperationRef.current}處理中，請稍候。`);
      return;
    }
    pdfOperationRef.current = label;
    setPdfOperation(label);
    try {
      await action();
    } finally {
      pdfOperationRef.current = null;
      setPdfOperation(null);
    }
  }

  async function savePreviewPdf() {
    await runPdfOperation("PDF生成", async () => {
      setMessage("正在生成 PDF...");
      const pdfBytes = await generatePreviewPdfBytes();
      const path = await saveBinaryFileWithDialog(pdfBytes, pdfFileName(), [{ name: "PDF", extensions: ["pdf"] }]);
      if (!path) {
        setMessage("已取消保存。");
        return;
      }
      await openLocalFile(path);
      setMessage(`已保存並打開：${path}`);
    }).catch((error) => setMessage(error.message));
  }

  async function openPrintablePdf() {
    await runPdfOperation("PDF生成", async () => {
      setMessage("正在生成 PDF...");
      const pdfBytes = await generatePreviewPdfBytes();
      const path = await writeTempBinaryFile(pdfBytes, pdfFileName());
      await openLocalFile(path);
      setMessage(`已打開 PDF：${path}`);
    }).catch((error) => setMessage(error.message));
  }

  async function handleStampImageChange(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    try {
      const dataUrl = await fileToDataUrl(file);
      const stamp = makeStampRecord(dataUrl, file.name || "印章");
      const saved = saveStoredStamps([...stamps, stamp]);
      setStamps(saved);
      setSelectedStampId(stamp.id);
      setIsStampVisible(true);
      saveCurrentDocumentStamp(stampSettings, true, stamp.id);
      setMessage(`已新增並套用「${stamp.name}」。`);
    } catch (error) {
      setMessage(error.message);
    } finally {
      event.target.value = "";
    }
  }

  function selectPreviewStamp(stampId) {
    setSelectedStampId(stampId);
    setIsStampVisible(Boolean(stampId));
    saveCurrentDocumentStamp(stampSettings, Boolean(stampId), stampId);
    const stamp = stamps.find((item) => item.id === stampId);
    setMessage(stamp ? `已套用「${stamp.name}」。` : "已取消此帳票印章。");
  }

  function updateStampSettings(patch) {
    const next = normalizeStampSettings({ ...stampSettings, ...patch });
    setStampSettings(next);
    saveCurrentDocumentStamp(next, isStampVisible);
    setMessage("已保存此帳票的印章設定。");
  }

  function updateStampPositionFromPoint(clientX, clientY, shouldAnnounce = false) {
    const pageElement = pdfPageRef.current;
    if (!pageElement) return;
    const rect = pageElement.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const normalizedCenterX = clampNumber((clientX - rect.left) / rect.width, 0.05, 0.95);
    const normalizedCenterY = clampNumber((clientY - rect.top) / rect.height, 0.05, 0.95);
    setStampSettings((current) => {
      const next = normalizeStampSettings({ ...current, normalizedCenterX, normalizedCenterY });
      saveCurrentDocumentStamp(next, isStampVisible);
      return next;
    });
    if (shouldAnnounce) {
      setMessage(`印章位置已保存：左右 ${Math.round(normalizedCenterX * 100)}%，上下 ${Math.round(normalizedCenterY * 100)}%。`);
    }
  }

  function handleStampPlacementStart(event) {
    if (event.button !== 0 && event.pointerType === "mouse") return;
    if (!stampImage) {
      setIsStampEditorOpen(true);
      setMessage("請先在印章設定中選擇印章圖片。");
      return;
    }
    event.preventDefault();
    stampDragRef.current = true;
    event.currentTarget.setPointerCapture?.(event.pointerId);
    setIsStampVisible(true);
    updateStampPositionFromPoint(event.clientX, event.clientY);
    setMessage("正在調整印章位置，放開滑鼠後會保存。");
  }

  function handleStampPlacementMove(event) {
    if (!stampDragRef.current) return;
    event.preventDefault();
    updateStampPositionFromPoint(event.clientX, event.clientY);
  }

  function handleStampPlacementEnd(event) {
    if (!stampDragRef.current) return;
    stampDragRef.current = false;
    event.currentTarget.releasePointerCapture?.(event.pointerId);
    updateStampPositionFromPoint(event.clientX, event.clientY, true);
  }

  function removePreviewStamp() {
    setSelectedStampId("");
    setIsStampVisible(false);
    saveCurrentDocumentStamp(stampSettings, false, "");
    setMessage("已從此帳票移除印章。");
  }

  const typeLabel = documentTypeTitle(document.type, pdfLanguageId);
  const subtitle = documentTypeSubtitle(document.type, pdfLanguageId);
  const issuerContact = companyContactLines(document.issuerContact, document.issuerPhone, document.issuerEmail);
  const customerContact = companyContactLines(document.customerContact, document.customerPhone, document.customerEmail);
  const paymentProof = paymentProofText(document, pdfLanguageId);
  const template = pdfColorTemplate(document.colorTemplateId);
  const pageStyle = {
    "--pdf-accent": template.accent,
    "--pdf-soft-line": template.softLine,
    "--pdf-table-head": template.tableHead,
    "--pdf-total-background": template.totalBackground,
  };

  return (
    <div className="modal-backdrop pdf-preview-backdrop" role="presentation">
      <section className="pdf-preview-shell">
        <div className="pdf-preview-toolbar">
          <div>
            <h3>PDF預覽</h3>
            <p>{message || document.number || DOCUMENT_TYPE_LABELS[document.type] || "帳票"}</p>
          </div>
          <div className="actions-row compact-actions">
            <div className="pdf-zoom-controls" aria-label="PDF 縮放">
              <button
                type="button"
                className="icon-button secondary-button"
                title="縮小"
                onClick={() => zoomPreviewBy(-0.1)}
                disabled={previewScale <= 0.36}
              >
                <ZoomOut size={16} />
              </button>
              <span>{Math.round(previewScale * 100)}%</span>
              <button
                type="button"
                className="icon-button secondary-button"
                title="放大"
                onClick={() => zoomPreviewBy(0.1)}
                disabled={previewScale >= 2.99}
              >
                <ZoomIn size={16} />
              </button>
              <button type="button" className="secondary-button" onClick={fitPreviewToWindow}>
                適合
              </button>
            </div>
            <GuidedControl id="pdf.stamp-settings-button" title="印章設定提示" description="打开后可选择印章、调整大小、颜色、透明度，也可在纸面上点击或拖曳位置。">
              <button type="button" className="secondary-button" onClick={() => setIsStampEditorOpen(true)}>
                <SlidersHorizontal size={16} />
                印章設定
              </button>
            </GuidedControl>
            <button
              type="button"
              className="secondary-button"
              disabled={!stampImage}
              onClick={() => {
                setIsStampVisible((visible) => {
                  const nextVisible = !visible;
                  saveCurrentDocumentStamp(stampSettings, nextVisible);
                  return nextVisible;
                });
              }}
            >
              {isStampVisible ? <EyeOff size={16} /> : <Stamp size={16} />}
              {isStampVisible ? "隱藏印章" : "顯示印章"}
            </button>
            <GuidedControl id="pdf.save-button" title="保存 PDF 提示" description="确认预览内容正确后，点击这里生成 PDF 并打开本地文件。">
              <button type="button" className="secondary-button" onClick={savePreviewPdf} disabled={Boolean(pdfOperation)}>
                <Download size={16} />
                保存並打開PDF
              </button>
            </GuidedControl>
            <button type="button" className="secondary-button" onClick={openPrintablePdf} disabled={Boolean(pdfOperation)}>
              <FileText size={16} />
              列印/PDF
            </button>
            <button type="button" onClick={onClose}>
              關閉
            </button>
          </div>
        </div>
        <div className="pdf-preview-scroll" ref={previewScrollRef}>
          <div
            className="pdf-page-scale-frame"
            style={{
              "--pdf-preview-scale": previewScale,
              height: `${PDF_PAGE_HEIGHT * previewScale}px`,
              width: `${PDF_PAGE_WIDTH * previewScale}px`,
            }}
          >
            <article
              ref={pdfPageRef}
              className={["pdf-page", stampImage ? "stamp-placement-enabled" : "stamp-placement-empty"].join(" ")}
              style={pageStyle}
              onPointerDown={handleStampPlacementStart}
              onPointerMove={handleStampPlacementMove}
              onPointerUp={handleStampPlacementEnd}
              onPointerCancel={handleStampPlacementEnd}
              title={stampImage ? "點擊或拖曳設定印章位置" : "請先在印章設定中選擇印章"}
            >
            {stampImage && isStampVisible && (
              <img className="pdf-stamp-overlay" src={stampImage} alt="" style={stampOverlayStyle(stampSettings)} />
            )}
            <header className="pdf-page-header">
              <div>
                <h1>{typeLabel}</h1>
                <div className="pdf-subtitle">{subtitle}</div>
                <p>{openingSentence(document.type, pdfLanguageId)}</p>
              </div>
              <div className="pdf-meta">
                <span><b>{labels.number}</b><em>{document.number || "-"}</em></span>
                <span><b>{labels.issueDate}</b><em>{formatDate(document.issueDate)}</em></span>
                <span><b>{labels.transactionDate}</b><em>{formatDate(document.transactionDate)}</em></span>
                {presentation.showDueDate && <span><b>{labels.dueDate}</b><em>{formatDate(document.dueDate)}</em></span>}
                <span><b>{labels.relatedNumber}</b><em>{document.relatedNumber || labels.noRelatedNumber}</em></span>
              </div>
            </header>

            <section className="pdf-party-grid">
              <div className="pdf-party pdf-party-customer">
                <strong>{document.customerName || presentation.partyFallback} {document.honorific || "御中"}</strong>
                <p>{document.customerAddress || "-"}</p>
                {customerContact.map((line) => <p key={line}>{line}</p>)}
              </div>
              <div className="pdf-party pdf-party-issuer">
                {presentation.showIssuerRegistration && document.issuerRegistration && (
	                  <div className="pdf-qualified">
	                    <span>{labels.qualifiedInvoice}</span>
	                    <small>{labels.registrationNumber}: {document.issuerRegistration}</small>
	                  </div>
                )}
                <strong>{document.issuerName || "自社名"}</strong>
                <p>{document.issuerAddress || "-"}</p>
                {issuerContact.map((line) => <p key={line}>{line}</p>)}
              </div>
            </section>

            {(presentation.showSummaryTotals || presentation.showPaymentDetails) && (
              <section className={["pdf-amount-box", presentation.showPaymentDetails ? "" : "pdf-amount-box-simple"].filter(Boolean).join(" ")}>
                {presentation.showSummaryTotals && (
                  <div>
	                  <span className="pdf-amount-label">{documentTypeTotalLabel(document.type, pdfLanguageId)}</span>
	                  <strong>{formatCurrency(displayTotal)}</strong>
                  </div>
                )}
                {presentation.showPaymentDetails && (
                  <div>
	                  <span className="pdf-payment-label">{labels.paymentAndDue}</span>
	                  <p>{singleLinePaymentText(document.paymentDetails)}</p>
	                  {presentation.showDueDate && <small>{labels.dueDate}: {formatDate(document.dueDate)}</small>}
                  </div>
                )}
              </section>
            )}

            <table className="pdf-lines">
              <colgroup>
                {presentation.showLinePrices ? (
                  <>
                    <col style={{ width: "150px" }} />
                    <col style={{ width: "145px" }} />
                    <col style={{ width: "50px" }} />
                    <col style={{ width: "76px" }} />
                    <col style={{ width: "90px" }} />
                  </>
                ) : (
                  <>
                    <col style={{ width: "210px" }} />
                    <col style={{ width: "240px" }} />
                    <col style={{ width: "70px" }} />
                  </>
                )}
              </colgroup>
              <thead>
                <tr>
	                  <th>{labels.itemName}</th>
	                  <th>{labels.modelSpec}</th>
	                  <th>{labels.quantity}</th>
	                  {presentation.showLinePrices && <th>{labels.unitPrice}</th>}
	                  {presentation.showLinePrices && <th>{labels.amount}</th>}
                </tr>
              </thead>
              <tbody>
                {(document.lines ?? []).map((line, index) => {
                  const quantity = Number(line.quantity);
                  const unitPrice = Number(line.unitPrice);
                  const amount = (Number.isFinite(quantity) ? quantity : 0) * (Number.isFinite(unitPrice) ? unitPrice : 0);
                  return (
                    <tr key={line.id ?? index}>
                      <td>{line.name || "-"}</td>
                      <td>{[line.model, line.specification].filter(Boolean).join(" / ") || "-"}</td>
                      <td>{quantityText(quantity)}</td>
                      {presentation.showLinePrices && <td>{formatCurrency(Number.isFinite(unitPrice) ? unitPrice : 0)}</td>}
                      {presentation.showLinePrices && <td>{formatCurrency(amount)}</td>}
                    </tr>
                  );
                })}
              </tbody>
            </table>

            <section className="pdf-bottom-grid">
              <div>
	                <h2>{labels.notes}</h2>
	                <p>{document.notes || "-"}</p>
	                {presentation.showPaymentDetails && (
                    <>
	                    <h2>{labels.paymentDetails}</h2>
	                    <p>{document.paymentDetails || "-"}</p>
                    </>
                  )}
	                <h2>{document.type === "invoice" ? labels.invoiceCondition : labels.condition}</h2>
	                <p>{document.documentMemo || defaultCondition(document.type, pdfLanguageId)}</p>
	                {isVendorDocumentType(document.type) && (
	                  <>
	                    <h2>{labels.paymentProof}</h2>
	                    <p>{paymentProof}</p>
                  </>
                )}
              </div>
              {presentation.showSummaryTotals && (
                <div className="pdf-totals">
	                <div><span>{labels.subtotal}</span><strong>{formatCurrency(totals.subtotal)}</strong></div>
	                {presentation.showTax && <div><span>{labels.tax} {Number(document.taxRate || 0)}%</span><strong>{formatCurrency(totals.tax)}</strong></div>}
	                <div className="pdf-total-row"><span>{labels.total}</span><strong>{formatCurrency(displayTotal)}</strong></div>
                </div>
              )}
            </section>
            </article>
          </div>
        </div>
        {isStampEditorOpen && (
          <div className="pdf-stamp-editor">
            <div className="section-actions">
              <div>
                <h3>印章設定</h3>
                <p>可在 PDF 上點擊或拖曳印章位置。</p>
              </div>
              <button type="button" className="icon-button secondary-button" onClick={() => setIsStampEditorOpen(false)} aria-label="關閉印章設定" title="關閉">
                關閉
              </button>
            </div>
            <div className="pdf-stamp-editor-body">
              <label className="stamp-select-field">
                <span>使用印章</span>
                <select value={selectedStampId} onChange={(event) => selectPreviewStamp(event.target.value)}>
                  <option value="">不套用印章</option>
                  {stamps.map((stamp) => (
                    <option key={stamp.id} value={stamp.id}>{stamp.name}</option>
                  ))}
                </select>
              </label>
              <label className="secondary-button file-upload-button">
                <Upload size={16} />
                新增印章
                <input type="file" accept="image/*" onChange={handleStampImageChange} />
              </label>
              {stampImage ? (
                <div className="pdf-stamp-editor-preview">
                  <img src={stampImage} alt="印章預覽" style={stampImageStyle(stampSettings)} />
                </div>
              ) : (
                <div className="stamp-empty-inline">未設定預設印章</div>
              )}
              <StampEditorControls settings={stampSettings} onChange={updateStampSettings} />
              <div className="actions-row compact-actions">
                <button type="button" className="secondary-button" onClick={() => updateStampSettings(DEFAULT_STAMP_SETTINGS)}>
                  <RotateCcw size={16} />
                  重置
                </button>
                <button type="button" className="danger-button" disabled={!stampImage} onClick={removePreviewStamp}>
                  <Trash2 size={16} />
                  取消套用
                </button>
              </div>
            </div>
          </div>
        )}
      </section>
    </div>
  );
}

function DocumentModal({ backup, initialDirection = "customer", initialProjectMode = "existing", onCancel, onSave }) {
  const initialFormGroup = DOCUMENT_DIRECTION_GROUPS[initialDirection] ? initialDirection : "customer";
  const [formGroup, setFormGroup] = useState(initialFormGroup);
  const [projectMode, setProjectMode] = useState(initialProjectMode === "new" ? "new" : "existing");
  const [formTypeView, setFormTypeView] = useState("preview");
  const [selectedProjectKey, setSelectedProjectKey] = useState("");
  const [projectName, setProjectName] = useState(() => defaultNewProjectName(initialFormGroup, ""));
  const [partnerName, setPartnerName] = useState("");
  const projectGroups = useMemo(() => projectGroupsFromDocuments(backup.documents, formGroup), [backup.documents, formGroup]);
  const selectedProject = projectGroups.find((project) => projectKey(project) === selectedProjectKey) ?? null;
  const currentProject = projectMode === "existing" && selectedProject
    ? selectedProject
    : {
        name: projectName.trim() || defaultNewProjectName(formGroup, partnerName),
        direction: formGroup,
        partnerName: partnerName.trim() || "未填寫客戶/供應商",
        documents: [],
      };
  const availableTypes = DOCUMENT_DIRECTION_GROUPS[formGroup]?.types ?? DOCUMENT_DIRECTION_GROUPS.customer.types;

  function changeFormGroup(groupKey) {
    const nextGroup = DOCUMENT_DIRECTION_GROUPS[groupKey] ? groupKey : "customer";
    setFormGroup(nextGroup);
    setProjectMode("new");
    setSelectedProjectKey("");
    setProjectName(defaultNewProjectName(nextGroup, partnerName));
  }

  function changePartnerName(name) {
    setPartnerName(name);
    if (projectMode === "new") {
      setProjectName(defaultNewProjectName(formGroup, name));
    }
  }

  function createForm(type) {
    const existingDocuments = currentProject.documents.filter((document) => document.type === type);
    if (existingDocuments.length > 0) {
      const confirmed = window.confirm(`${formMenuTypeLabel(type)} 已經建立。是否仍要再建立一份？`);
      if (!confirmed) return;
    }

    onSave(buildDocumentForProject(type, currentProject, formGroup));
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal-panel document-modal project-create-modal">
        <div className="section-actions sticky-modal-header">
          <div>
            <h3>新增帳票</h3>
            <p className="modal-subtitle">選擇項目後，從表單預覽卡片建立需要的表單。</p>
          </div>
          <button type="button" className="secondary-button" onClick={onCancel}>
            取消
          </button>
        </div>

        <div className="project-create-grid">
          <section className="settings-panel project-setup-panel">
            <div className="project-setup-header">
              <h3>建立項目</h3>
              <div className="segmented-control project-mode-control">
                <GuidedControl id="document-modal.new-project-tab" title="新項目提示" description="第一次建立流程建议从新项目开始，先填客户/供应商和项目名称。">
                  <button type="button" className={projectMode === "new" ? "active" : ""} onClick={() => setProjectMode("new")}>
                    新項目
                  </button>
                </GuidedControl>
                <button
                  type="button"
                  className={projectMode === "existing" ? "active" : ""}
                  disabled={projectGroups.length === 0}
                  onClick={() => {
                    setProjectMode("existing");
                    setSelectedProjectKey((current) => current || projectKey(projectGroups[0]));
                  }}
                >
                  現有項目
                </button>
              </div>
            </div>

            <div className="project-setup-type-row">
              <span className="form-label">項目類型</span>
              <div className="project-type-segmented">
                {Object.entries(DOCUMENT_DIRECTION_GROUPS).map(([key, group]) => (
                  <button
                    type="button"
                    className={formGroup === key ? "active" : ""}
                    key={key}
                    onClick={() => changeFormGroup(key)}
                  >
                    {group.label}
                  </button>
                ))}
              </div>
            </div>

            {projectMode === "new" ? (
              <div className="project-setup-fields">
                <Field
                  label="客戶/供應商"
                  value={partnerName}
                  onChange={changePartnerName}
                  options={uniqueOptions(backup.customers.map((customer) => customer.name))}
                  listId="project-partner-options"
                  hint={{ id: "document-modal.partner-field", title: "客戶/供應商提示", description: "输入或选择交易对象，系统会自动生成项目名称，也可手动修改。" }}
                />
                <Field label="項目名稱" value={projectName} onChange={setProjectName} hint={{ id: "document-modal.project-field", title: "項目名稱提示", description: "同一项目下可以集中保存报价、发票、收据等相关表单。" }} />
              </div>
            ) : (
              <div className="project-picker compact">
                <span className="form-label">現有項目</span>
                <div className="project-picker-list">
                  {projectGroups.map((project) => {
                    const key = projectKey(project);
                    const isActive = key === selectedProjectKey;
                    const completedTypes = new Set(project.documents.map((document) => document.type)).size;
                    return (
                      <button
                        type="button"
                        className={isActive ? "project-picker-row active" : "project-picker-row"}
                        key={key}
                        onClick={() => setSelectedProjectKey(key)}
                      >
                        <strong>{project.name}</strong>
                        <small>{project.partnerName} / {completedTypes} 個表單 / {formatDate(project.updatedAt)}</small>
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </section>

          <section className="settings-panel project-summary-panel">
            <h3>{currentProject.name}</h3>
            <p>{DOCUMENT_DIRECTION_GROUPS[formGroup]?.label} / {currentProject.partnerName}</p>
            <div className="project-progress-strip">
              <strong>{currentProject.documents.length}</strong>
              <span>已建立表單</span>
            </div>
          </section>
        </div>

        <section className="settings-panel">
          <FormTypeSectionHeader viewMode={formTypeView} onViewModeChange={setFormTypeView} />
          <FormTypeChooser
            types={availableTypes}
            documents={currentProject.documents}
            viewMode={formTypeView}
            onSelect={createForm}
          />
        </section>
      </section>
    </div>
  );
}

function FormProjectPlacementModal({ backup, type, onCancel, onCreate, onPreview }) {
  const direction = documentDirectionForDocumentType(type);
  const typeLabel = formMenuTypeLabel(type);
  const projectGroups = useMemo(() => projectGroupsFromDocuments(backup.documents, direction), [backup.documents, direction]);
  const [step, setStep] = useState("choice");
  const [selectedProjectKey, setSelectedProjectKey] = useState("");
  const [projectName, setProjectName] = useState(() => defaultNewProjectName(direction, ""));
  const [partnerName, setPartnerName] = useState("");
  const selectedProject = projectGroups.find((project) => projectKey(project) === selectedProjectKey) ?? null;
  const existingDocuments = selectedProject?.documents.filter((document) => document.type === type).sort(newestFirst) ?? [];
  const latestExistingDocument = existingDocuments[0] ?? null;

  function changePartnerName(name) {
    setPartnerName(name);
    setProjectName(defaultNewProjectName(direction, name));
  }

  function createNewProjectForm() {
    onCreate(type, {
      name: projectName.trim() || defaultNewProjectName(direction, partnerName),
      direction,
      partnerName: partnerName.trim() || "未填寫客戶/供應商",
      documents: [],
    });
  }

  function selectExistingProject(project) {
    setSelectedProjectKey(projectKey(project));
    setStep(project.documents.some((document) => document.type === type) ? "conflict" : "existing");
  }

  function createInSelectedProject(mode = "append") {
    if (!selectedProject) return;
    onCreate(type, selectedProject, mode);
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal-panel form-placement-modal">
        <div className="section-actions sticky-modal-header">
          <div>
            <h3>{typeLabel}</h3>
            <p className="modal-subtitle">選擇要建立新項目，或把這份表單放入既有項目。</p>
          </div>
          <button type="button" className="secondary-button" onClick={onCancel}>
            取消
          </button>
        </div>

        {step === "choice" && (
          <div className="placement-choice-grid">
            <button type="button" className="settings-card-button" onClick={() => setStep("new")}>
              <span className="settings-card-icon"><Folder size={20} /></span>
              <span className="settings-card-body">
                <strong>建立新的項目</strong>
                <small>先輸入客戶/供應商與項目名稱，再建立 {typeLabel}。</small>
              </span>
            </button>
            <button
              type="button"
              className="settings-card-button"
              disabled={projectGroups.length === 0}
              onClick={() => setStep("existing")}
            >
              <span className="settings-card-icon"><FolderOpen size={20} /></span>
              <span className="settings-card-body">
                <strong>選取現有項目</strong>
                <small>從既有項目中選取，再決定新增或覆蓋同類表單。</small>
              </span>
            </button>
          </div>
        )}

        {step === "new" && (
          <section className="settings-panel">
            <DataBackButton onClick={() => setStep("choice")} />
            <div className="project-setup-fields">
              <Field
                label={direction === "vendor" ? "供應商" : "客戶"}
                value={partnerName}
                onChange={changePartnerName}
                options={uniqueOptions(backup.customers.map((customer) => customer.name))}
                listId="placement-partner-options"
                hint={{ id: "placement.partner-field", title: "交易對象提示", description: "输入客户或供应商名称后，会自动带入项目名称。" }}
              />
              <Field label="項目名稱" value={projectName} onChange={setProjectName} hint={{ id: "placement.project-field", title: "項目名稱提示", description: "这份表单会保存到此项目中，方便后续从项目列表管理。" }} />
            </div>
            <div className="actions-row compact-actions modal-footer-actions">
              <GuidedControl id="placement.create-button" title="建立表單提示" description="确认项目名称后点击这里，系统会建立项目并打开新表单。">
                <button type="button" onClick={createNewProjectForm}>
                  <Plus size={16} />
                  建立項目並建立表單
                </button>
              </GuidedControl>
            </div>
          </section>
        )}

        {step === "existing" && (
          <section className="settings-panel">
            <DataBackButton onClick={() => setStep("choice")} />
            <div className="project-picker-list">
              {projectGroups.map((project) => {
                const completedTypes = new Set(project.documents.map((document) => document.type)).size;
                const hasSameType = project.documents.some((document) => document.type === type);
                return (
                  <button
                    type="button"
                    className={projectKey(project) === selectedProjectKey ? "project-picker-row active" : "project-picker-row"}
                    key={projectKey(project)}
                    onClick={() => selectExistingProject(project)}
                  >
                    <strong>{project.name}</strong>
                    <small>
                      {project.partnerName} / {completedTypes} 個表單 / {hasSameType ? `已有 ${typeLabel}` : "可新增"} / {formatDate(project.updatedAt)}
                    </small>
                  </button>
                );
              })}
            </div>
            {selectedProject && existingDocuments.length === 0 && (
              <div className="actions-row compact-actions modal-footer-actions">
                <button type="button" onClick={() => createInSelectedProject("append")}>
                  <Plus size={16} />
                  放入選取項目
                </button>
              </div>
            )}
          </section>
        )}

        {step === "conflict" && selectedProject && latestExistingDocument && (
          <section className="settings-panel overwrite-confirm-panel">
            <DataBackButton onClick={() => setStep("existing")} />
            <div className="overwrite-warning">
              <FileCheck2 size={22} />
              <div>
                <strong>{selectedProject.name} 已經有 {typeLabel}</strong>
                <p>覆蓋會移除此項目內現有的同類表單，並建立一份新的 {typeLabel}。建議先預覽現有 PDF，再決定覆蓋或新增。</p>
              </div>
            </div>
            <div className="document-management-row overwrite-document-summary">
              <div>
                <strong>{latestExistingDocument.number || typeLabel}</strong>
                <small>{documentSummaryText(latestExistingDocument)}</small>
              </div>
              <button type="button" className="secondary-button" onClick={() => onPreview(latestExistingDocument)}>
                <Eye size={16} />
                預覽現有PDF
              </button>
            </div>
            <div className="actions-row compact-actions modal-footer-actions">
              <button type="button" className="secondary-button" onClick={() => createInSelectedProject("append")}>
                <Plus size={16} />
                新增一份
              </button>
              <button type="button" className="danger-button" onClick={() => createInSelectedProject("overwrite")}>
                <Trash2 size={16} />
                覆蓋現有表單
              </button>
            </div>
          </section>
        )}
      </section>
    </div>
  );
}

function ExternalAttachmentImportModal({ backup, paths, onCancel, onImport }) {
  const initialDirection = paths.some((path) => isPdfPath(path)) ? "vendor" : "customer";
  const [direction, setDirection] = useState(DOCUMENT_DIRECTION_GROUPS[initialDirection] ? initialDirection : "customer");
  const [projectMode, setProjectMode] = useState("existing");
  const [selectedProjectKey, setSelectedProjectKey] = useState("");
  const [selectedType, setSelectedType] = useState(UPLOAD_ENABLED_TYPES_BY_DIRECTION[direction][0]);
  const projectGroups = useMemo(() => projectGroupsFromDocuments(backup.documents, direction), [backup.documents, direction]);
  const availableTypes = UPLOAD_ENABLED_TYPES_BY_DIRECTION[direction] ?? UPLOAD_ENABLED_TYPES_BY_DIRECTION.customer;
  const selectedProject = projectGroups.find((project) => projectKey(project) === selectedProjectKey) ?? null;
  const normalizedPaths = normalizeExternalOpenPaths(paths);

  useEffect(() => {
    const nextTypes = UPLOAD_ENABLED_TYPES_BY_DIRECTION[direction] ?? UPLOAD_ENABLED_TYPES_BY_DIRECTION.customer;
    setSelectedType(nextTypes[0]);
    setSelectedProjectKey(projectGroups[0] ? projectKey(projectGroups[0]) : "");
    setProjectMode(projectGroups.length ? "existing" : "new");
  }, [direction, projectGroups]);

  function chooseDirection(nextDirection) {
    if (!DOCUMENT_DIRECTION_GROUPS[nextDirection]) return;
    setDirection(nextDirection);
  }

  function submitImport() {
    onImport({
      paths: normalizedPaths,
      direction,
      project: projectMode === "existing" ? selectedProject : null,
      type: selectedType,
    });
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal-panel form-placement-modal">
        <div className="section-actions sticky-modal-header">
          <div>
            <h3>導入系統檔案</h3>
            <p className="modal-subtitle">照片或 PDF 只會導入支援文件上傳的表單。PDF 一次只支援一個檔案。</p>
          </div>
          <button type="button" className="secondary-button" onClick={onCancel}>
            取消
          </button>
        </div>

        <section className="settings-panel external-import-files">
          <h3>檔案</h3>
          <div className="data-menu-list">
            {normalizedPaths.map((path) => (
              <div className="document-management-row" key={path}>
                <div>
                  <strong>{fileNameFromPath(path)}</strong>
                  <small>{isPdfPath(path) ? "PDF" : "照片"}</small>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="settings-panel">
          <h3>項目</h3>
          <div className="segmented-control form-view-toggle">
            {Object.entries(DOCUMENT_DIRECTION_GROUPS).map(([key, group]) => (
              <button type="button" className={direction === key ? "active" : ""} key={key} onClick={() => chooseDirection(key)}>
                {group.label}
              </button>
            ))}
          </div>
          <div className="segmented-control form-view-toggle">
            <button type="button" className={projectMode === "existing" ? "active" : ""} disabled={!projectGroups.length} onClick={() => setProjectMode("existing")}>
              現有項目
            </button>
            <button type="button" className={projectMode === "new" ? "active" : ""} onClick={() => setProjectMode("new")}>
              新項目
            </button>
          </div>
          {projectMode === "existing" && (
            <div className="project-picker-list">
              {projectGroups.map((project) => (
                <button
                  type="button"
                  className={projectKey(project) === selectedProjectKey ? "project-picker-row active" : "project-picker-row"}
                  key={projectKey(project)}
                  onClick={() => setSelectedProjectKey(projectKey(project))}
                >
                  <strong>{project.name}</strong>
                  <small>{project.partnerName} / {project.documents.length} 份表單 / {formatDate(project.updatedAt)}</small>
                </button>
              ))}
            </div>
          )}
          {projectMode === "new" && <p>沒有項目時會自動建立新項目，再把檔案導入你選的表單。</p>}
        </section>

        <section className="settings-panel">
          <h3>支援上傳的表單</h3>
          <div className="project-picker-list">
            {availableTypes.map((type) => (
              <button
                type="button"
                className={selectedType === type ? "project-picker-row active" : "project-picker-row"}
                key={type}
                onClick={() => setSelectedType(type)}
              >
                <strong>{formMenuTypeLabel(type)}</strong>
                <small>{FORM_TYPE_DESCRIPTIONS[type] ?? DOCUMENT_TYPE_LABELS[type]}</small>
              </button>
            ))}
          </div>
        </section>

        <div className="actions-row compact-actions modal-footer-actions">
          <button
            type="button"
            onClick={submitImport}
            disabled={!normalizedPaths.length || (projectMode === "existing" && !selectedProject)}
          >
            <Upload size={16} />
            導入表單
          </button>
        </div>
      </section>
    </div>
  );
}

function buildDocumentForProject(type, project, direction = documentDirectionForDocumentType(type)) {
  const document = makeDocument(type);
  const sourceDocument = project.documents.find((item) => item.customerName || item.issuerName) ?? null;
  return {
    ...document,
    projectName: project.name === "未指定項目" ? "" : project.name,
    projectDirection: direction,
    customerName: project.partnerName === "未填寫客戶/供應商" ? "" : project.partnerName,
    customerAddress: sourceDocument?.customerAddress ?? document.customerAddress,
    customerContact: sourceDocument?.customerContact ?? document.customerContact,
    customerPhone: sourceDocument?.customerPhone ?? document.customerPhone,
    customerEmail: sourceDocument?.customerEmail ?? document.customerEmail,
    issuerName: sourceDocument?.issuerName ?? document.issuerName,
    issuerRegistration: sourceDocument?.issuerRegistration ?? document.issuerRegistration,
    issuerAddress: sourceDocument?.issuerAddress ?? document.issuerAddress,
    issuerContact: sourceDocument?.issuerContact ?? document.issuerContact,
    issuerPhone: sourceDocument?.issuerPhone ?? document.issuerPhone,
    issuerEmail: sourceDocument?.issuerEmail ?? document.issuerEmail,
    relatedNumber: suggestedRelatedNumber(type, project.documents),
    updatedAt: new Date().toISOString(),
  };
}

function FormTypeSectionHeader({ title = "選擇要建立的表單", viewMode, onViewModeChange }) {
  const canSwitchView = typeof onViewModeChange === "function";
  return (
    <div className="form-type-section-header">
      <h3>{title}</h3>
      {canSwitchView && (
        <div className="segmented-control form-view-toggle" aria-label="表單顯示方式">
          <button
            type="button"
            className={viewMode === "list" ? "active" : ""}
            onClick={() => onViewModeChange("list")}
          >
            <List size={15} />
            列表
          </button>
          <button
            type="button"
            className={viewMode === "preview" ? "active" : ""}
            onClick={() => onViewModeChange("preview")}
          >
            <LayoutGrid size={15} />
            小預覽圖
          </button>
        </div>
      )}
    </div>
  );
}

function FormTypeChooser({ types, documents, viewMode, onSelect, className }) {
  const rows = types.map((type) => ({
    type,
    existingDocuments: documents.filter((document) => document.type === type).sort(newestFirst),
  }));

  if (viewMode === "list") {
    return (
      <div className={["form-type-list", className].filter(Boolean).join(" ")}>
        {rows.map(({ type, existingDocuments }) => (
          <FormTypeListRow
            key={type}
            type={type}
            existingDocuments={existingDocuments}
            onClick={() => onSelect(type)}
          />
        ))}
      </div>
    );
  }

  return (
    <div className={["form-preview-grid", className].filter(Boolean).join(" ")}>
      {rows.map(({ type, existingDocuments }) => (
        <FormPreviewCard
          key={type}
          type={type}
          existingDocuments={existingDocuments}
          onClick={() => onSelect(type)}
        />
      ))}
    </div>
  );
}

function FormTypeListRow({ type, existingDocuments, onClick }) {
  const isCreated = existingDocuments.length > 0;
  const latestDocument = existingDocuments[0];
  const StatusIcon = isCreated ? FileCheck2 : FilePlus2;
  return (
    <GuidedControl id={`form-type.${type}`} title="表單類型提示" description="点击这个表单类型后，系统会建立新帐票，或让你选择新增/覆盖既有表单。" className="guided-control-fill">
      <button type="button" className={isCreated ? "form-type-list-row created" : "form-type-list-row uncreated"} onClick={onClick}>
        <span className="form-type-list-icon">
          {isCreated ? <FileCheck2 size={18} /> : <Upload size={18} />}
        </span>
        <span className="form-type-list-body">
          <strong>{formMenuTypeLabel(type)}</strong>
          <small>{isCreated ? latestDocument?.number || `${existingDocuments.length} 筆` : FORM_TYPE_DESCRIPTIONS[type] ?? "建立或上傳此表單"}</small>
        </span>
        <span className="form-preview-status">
          <StatusIcon size={14} />
          {isCreated ? "已建立" : "未建立"}
        </span>
      </button>
    </GuidedControl>
  );
}

function FormPreviewCard({ type, existingDocuments, onClick }) {
  const isCreated = existingDocuments.length > 0;
  const latestDocument = existingDocuments[0];
  return (
    <GuidedControl id={`form-preview.${type}`} title="表單卡片提示" description="点击卡片即可建立或打开这一类表单；未建立的卡片会进入新增流程。" className="guided-control-fill">
      <button type="button" className={isCreated ? "form-preview-card created" : "form-preview-card uncreated"} onClick={onClick}>
        <FormPreviewThumbnail document={latestDocument} />
        <span>{isCreated ? formatDate(latestDocument.updatedAt || latestDocument.issueDate) : formMenuTypeLabel(type)}</span>
        <strong>{formMenuTypeLabel(type)}</strong>
        {!isCreated && <small>未建立</small>}
      </button>
    </GuidedControl>
  );
}

function FormPreviewThumbnail({ document }) {
  if (document) {
    return <MiniPdfPreview document={document} />;
  }
  return (
    <div className="form-preview-paper blank-form-preview">
      <div className="preview-line wide" />
      <div className="preview-line" />
      <div className="preview-line short" />
      <div className="preview-table">
        <span />
        <span />
        <span />
      </div>
      <Upload size={28} />
    </div>
  );
}

function MiniPdfPreview({ document }) {
  const totals = documentTotal(document);
  const template = pdfColorTemplate(document.colorTemplateId);
  const lines = (document.lines ?? []).slice(0, 3);
  const presentation = documentPresentationRules(document.type);
  const displayTotal = presentation.showTax ? totals.total : totals.subtotal;
  const pageStyle = {
    "--mini-pdf-accent": template.accent,
    "--mini-pdf-soft-line": template.softLine,
    "--mini-pdf-table-head": template.tableHead,
    "--mini-pdf-total-background": template.totalBackground,
  };

  return (
    <div className="form-preview-paper mini-pdf-preview" style={pageStyle}>
      <div className="mini-pdf-header">
        <strong>{documentTypeTitle(document.type)}</strong>
        <span>{document.number || "-"}</span>
      </div>
      <div className="mini-pdf-meta">
        <span>{formatDate(document.issueDate)}</span>
        {presentation.showDueDate && <span>{formatDate(document.dueDate)}</span>}
      </div>
      <div className="mini-pdf-parties">
        <strong>{document.customerName || presentation.partyFallback}</strong>
        <span>{document.issuerName || "自社名"}</span>
      </div>
      {presentation.showSummaryTotals && <div className="mini-pdf-amount">{formatCurrency(displayTotal)}</div>}
      <div className="mini-pdf-table">
        <div className={["mini-pdf-table-head", presentation.showLinePrices ? "" : "without-prices"].filter(Boolean).join(" ")}>
          <span>品名</span>
          <span>数量</span>
          {presentation.showLinePrices && <span>金額</span>}
        </div>
        {lines.map((line, index) => {
          const quantity = Number(line.quantity || 0);
          const unitPrice = Number(line.unitPrice || 0);
          const amount = (Number.isFinite(quantity) ? quantity : 0) * (Number.isFinite(unitPrice) ? unitPrice : 0);
          return (
            <div className={["mini-pdf-table-row", presentation.showLinePrices ? "" : "without-prices"].filter(Boolean).join(" ")} key={line.id ?? index}>
              <span>{line.name || "-"}</span>
              <span>{quantityText(quantity)}</span>
              {presentation.showLinePrices && <span>{formatCurrency(amount)}</span>}
            </div>
          );
        })}
      </div>
      <div className="mini-pdf-footer">
        <span>{document.notes || defaultCondition(document.type)}</span>
      </div>
    </div>
  );
}

function RecordModal({ collection, initialValues, isEditing = false, onCancel, onSave }) {
  const config = modalConfig(collection);
  const [values, setValues] = useState({ ...config.initialValues, ...(initialValues ?? {}) });

  function update(field, value, type) {
    if (isBlankInput(value)) return;
    setValues((current) => ({ ...current, [field]: type === "number" ? normalizeNumericInput(value) : value }));
  }

  function submit(event) {
    event.preventDefault();
    if (!hasMeaningfulInput(values)) return;
    onSave(values);
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <form className="modal-panel" onSubmit={submit}>
        <div className="section-actions">
          <h3>{isEditing ? config.editTitle : config.title}</h3>
          <button type="button" className="secondary-button" onClick={onCancel}>
            取消
          </button>
        </div>
        <div className="form-grid two-column modal-grid">
          {config.fields.map(([field, label, type, options]) => (
            <RecordField
              key={field}
              field={field}
              label={label}
              type={type}
              options={options}
              value={values[field] ?? ""}
              onChange={(value) => update(field, value, type)}
            />
          ))}
        </div>
        <div className="modal-actions">
          <GuidedControl id={`record.modal.submit.${collection}`} title="保存資料提示" description="填好必要名称后点击这里。若从帐票带入，保存后会同步回当前帐票。">
            <button type="submit">
              <Save size={16} />
              {isEditing ? "更新" : "建立"}
            </button>
          </GuidedControl>
        </div>
      </form>
    </div>
  );
}

function modalConfig(collection) {
  if (collection === "issuers") {
    return {
      title: "新增公司",
      editTitle: "更新公司",
      initialValues: { name: "", registration: "", contact: "", phone: "", email: "", address: "" },
      fields: [
        ["name", "公司名稱"],
        ["registration", "登錄號"],
        ["contact", "聯絡人"],
        ["phone", "電話"],
        ["email", "Email"],
        ["address", "地址", "wide"],
      ],
    };
  }
  if (collection === "products") {
    return {
      title: "新增品項",
      editTitle: "更新品項",
      initialValues: { name: "", model: "", specification: "", unitPrice: 0 },
      fields: [
        ["name", "品名"],
        ["model", "型號"],
        ["specification", "規格", "textarea"],
        ["unitPrice", "單價", "number"],
      ],
    };
  }
  return {
    ...(collection === "customers"
      ? {
          title: "新增客戶",
          editTitle: "更新客戶",
          initialValues: { name: "", contact: "", phone: "", email: "", address: "" },
          fields: [
            ["name", "客戶名稱"],
            ["contact", "聯絡人"],
            ["phone", "電話"],
            ["email", "Email"],
            ["address", "地址", "wide"],
          ],
        }
      : {
          title: "新增模板",
          editTitle: "更新模板",
          initialValues: { kind: "note", title: "", content: "" },
          fields: [
            ["kind", "類型", "select", TEMPLATE_KIND_LABELS],
            ["title", "標題"],
            ["content", "內容", "wide"],
          ],
        }),
  };
}

function Field({ label, value, onChange, multiline = false, options = [], listId, type = "text", className, help, hint }) {
  const inputListId = listId || `${label.replace(/\s+/g, "-")}-options`;
  const cleanValue = type === "date" ? toDateInputValue(value) : value ?? "";
  const commitValue = (rawValue) => onChange(type === "date" ? fromDateInputValue(rawValue) : rawValue);
  const isAddressField = String(label).includes("地址");
  const isEmailField = String(label).toLowerCase().includes("email");
  const shouldUseTextarea = multiline || isAddressField;
  const labelClassName = [className, isAddressField ? "address-field" : "", isEmailField ? "email-field" : ""].filter(Boolean).join(" ") || undefined;
  const fieldControl = (
    <label className={labelClassName}>
      {label}
      {shouldUseTextarea ? (
        <textarea
          {...plainInputAttributes()}
          value={cleanValue}
          onChange={(event) => commitValue(event.target.value)}
          onKeyDown={(event) => handleLiteralMinus(event, commitValue)}
        />
      ) : (
        <>
          <input
            {...plainInputAttributes(type === "number" ? "decimal" : type === "date" ? "numeric" : isEmailField ? "email" : "text")}
            type={type === "date" ? "date" : isEmailField ? "email" : "text"}
            list={options.length ? inputListId : undefined}
            value={cleanValue}
            onChange={(event) => commitValue(event.target.value)}
            onKeyDown={(event) => handleLiteralMinus(event, commitValue)}
          />
          {options.length > 0 && (
            <datalist id={inputListId}>
              {options.map((option) => (
                <option key={option} value={option} />
              ))}
            </datalist>
          )}
        </>
      )}
      {help && <span className="field-help">{help}</span>}
    </label>
  );
  if (!hint) return fieldControl;
  return (
    <GuidedControl id={hint.id} title={hint.title} description={hint.description} className="guided-control-fill guided-field">
      {fieldControl}
    </GuidedControl>
  );
}

function RecordField({ field, label, value, onChange, type, options }) {
  if (type === "textarea" || (type === "wide" && String(label).includes("地址"))) {
    return (
      <Field
        className={field === "specification" ? "specification-field" : undefined}
        label={label}
        value={value}
        onChange={onChange}
        multiline
      />
    );
  }
  if (type === "select") {
    return (
      <label>
        {label}
        <select value={value} onChange={(event) => onChange(event.target.value)}>
          {Object.entries(options).map(([optionValue, optionLabel]) => (
            <option key={optionValue} value={optionValue}>{optionLabel}</option>
          ))}
        </select>
      </label>
    );
  }
  return (
    <label className={[type === "wide" ? "wide-field" : "", field === "unitPrice" ? "unit-price-field" : ""].filter(Boolean).join(" ") || undefined}>
      {label}
      <input
        {...plainInputAttributes(type === "number" ? "decimal" : "text")}
        value={value ?? ""}
        onChange={(event) => onChange(event.target.value)}
        onKeyDown={(event) => handleLiteralMinus(event, onChange)}
      />
    </label>
  );
}

function Metric({ label, value }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function PathRow({ label, value }) {
  return (
    <div className="path-row">
      <span>{label}</span>
      <strong>{value ?? "-"}</strong>
    </div>
  );
}

function defaultNewProjectName(direction, partnerName) {
  const cleanPartner = String(partnerName ?? "").trim();
  const directionLabel = DOCUMENT_DIRECTION_GROUPS[direction]?.label ?? "項目";
  return cleanPartner ? `${formatDate(new Date().toISOString())} ${cleanPartner}` : `${formatDate(new Date().toISOString())} ${directionLabel}`;
}

function projectKey(project) {
  return `${project.direction}:${project.name}`;
}

function suggestedRelatedNumber(type, documents) {
  if (type === "customerOrder") {
    return documents.find((document) => document.type === "estimate")?.number ?? "";
  }
  if (["delivery", "invoice", "receipt"].includes(type)) {
    return documents.find((document) => document.type === "customerOrder")?.number ??
      documents.find((document) => document.type === "estimate")?.number ??
      "";
  }
  if (type === "acceptance") {
    return documents.find((document) => document.type === "purchaseOrder")?.number ?? "";
  }
  if (["vendorInvoice", "vendorReceipt", "paymentNotice"].includes(type)) {
    return documents.find((document) => document.type === "acceptance")?.number ??
      documents.find((document) => document.type === "purchaseOrder")?.number ??
      "";
  }
  return "";
}

function partnerGroupsFromDocuments(documents, direction = "customer") {
  const visibleDocuments = documents.filter((document) => documentDirectionForDocumentType(document.type) === direction).sort(newestFirst);
  const groups = new Map();
  for (const document of visibleDocuments) {
    const name = cleanPartnerName(document);
    if (!groups.has(name)) {
      groups.set(name, { name, documents: [], updatedAt: document.updatedAt });
    }
    groups.get(name).documents.push(document);
  }
  return [...groups.values()].sort(groupNewestFirst);
}

function projectGroupsFromDocuments(documents, forcedDirection = null) {
  const groups = new Map();
  for (const document of documents) {
    const direction = forcedDirection ?? documentDirectionForDocumentType(document.type);
    if (forcedDirection && documentDirectionForDocumentType(document.type) !== forcedDirection) continue;
    const name = cleanProjectName(document);
    const key = `${direction}:${name}`;
    if (!groups.has(key)) {
      groups.set(key, {
        name,
        direction,
        partnerName: cleanPartnerName(document),
        documents: [],
        updatedAt: document.updatedAt,
      });
    }
    const group = groups.get(key);
    group.documents.push(document);
    if (new Date(document.updatedAt) > new Date(group.updatedAt)) {
      group.updatedAt = document.updatedAt;
    }
    if (group.partnerName === "未填寫客戶/供應商" && cleanPartnerName(document) !== group.partnerName) {
      group.partnerName = cleanPartnerName(document);
    }
  }
  return [...groups.values()].sort(groupNewestFirst);
}

function typeGroupsFromDocuments(documents, direction) {
  return (DOCUMENT_DIRECTION_GROUPS[direction]?.types ?? [])
    .map((type) => ({
      type,
      documents: documents.filter((document) => document.type === type).sort(newestFirst),
    }))
    .filter((group) => group.documents.length > 0);
}

function cleanPartnerName(document) {
  return String(document.customerName ?? "").trim() || "未填寫客戶/供應商";
}

function cleanProjectName(document) {
  return String(document.projectName ?? "").trim() || "未指定項目";
}

function sameProjectName(document, projectName) {
  return cleanProjectName(document) === projectName;
}

function newestFirst(left, right) {
  return new Date(right.updatedAt) - new Date(left.updatedAt);
}

function groupNewestFirst(left, right) {
  const dateCompare = new Date(right.updatedAt) - new Date(left.updatedAt);
  return dateCompare || left.name.localeCompare(right.name, "ja-JP");
}

function documentSummaryText(document) {
  const totals = documentTotal(document);
  const updated = formatDate(document.updatedAt);
  const issued = formatDate(document.issueDate);
  return `${updated} 更新 / 開具 ${issued} / ${formatCurrency(totals.total)}`;
}

function DOCUMENT_TYPE_PREFIX_FOR_COPY(type) {
  return DOCUMENT_TYPE_PREFIXES[type] ?? "DOC";
}

function viewIdForCollection(collection) {
  return collection === "textTemplates" ? "templates" : collection;
}

function uniqueOptions(values) {
  return [...new Set(values.map((value) => String(value ?? "").trim()).filter(Boolean))].sort((left, right) =>
    left.localeCompare(right, "ja-JP"),
  );
}

function documentDirectionForDocumentType(type) {
  if (!type) return "customer";
  if (type === "customerFiles") return "customer";
  return isVendorDocumentType(type) ? "vendor" : "customer";
}

function documentTypeOptionsForDirection(direction, currentType) {
  const group = DOCUMENT_DIRECTION_GROUPS[direction] ?? DOCUMENT_DIRECTION_GROUPS.customer;
  if (!currentType || group.types.includes(currentType)) return group.types;
  return [currentType, ...group.types];
}

function projectDirectionForDocumentType(type) {
  return documentDirectionForDocumentType(type);
}

function fileToOrderAttachment(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = String(reader.result ?? "");
      const data = dataUrl.includes(",") ? dataUrl.split(",").pop() : dataUrl;
      resolve({
        id: crypto.randomUUID(),
        filename: file.name,
        contentType: file.type || contentTypeFromFilename(file.name),
        data,
        dataUrl,
        uploadedAt: new Date().toISOString(),
      });
    };
    reader.onerror = () => reject(reader.error ?? new Error("附件讀取失敗"));
    reader.readAsDataURL(file);
  });
}

function externalFileToOrderAttachment(file) {
  const data = bytesToBase64(file.contents ?? []);
  const contentType = file.contentType || contentTypeFromFilename(file.fileName);
  return {
    id: crypto.randomUUID(),
    filename: file.fileName,
    contentType,
    data,
    dataUrl: `data:${contentType};base64,${data}`,
    uploadedAt: new Date().toISOString(),
  };
}

function bytesToBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}

function normalizeExternalOpenPaths(paths) {
  const supported = Array.from(new Set((paths ?? []).filter(Boolean))).filter(isExternalAttachmentPath);
  const firstPdf = supported.find(isPdfPath);
  if (firstPdf) return [firstPdf];
  return supported;
}

function isExternalAttachmentPath(path) {
  return /\.(pdf|png|jpe?g|webp|gif|heic|heif)$/i.test(String(path ?? ""));
}

function isPdfPath(path) {
  return /\.pdf$/i.test(String(path ?? ""));
}

function fileNameFromPath(path) {
  return String(path ?? "").split(/[\\/]/).filter(Boolean).pop() || "attachment";
}

function attachmentDataUrl(attachment) {
  if (attachment.dataUrl) return attachment.dataUrl;
  if (attachment.data) return `data:${attachment.contentType || contentTypeFromFilename(attachment.filename)};base64,${attachment.data}`;
  return "";
}

function contentTypeFromFilename(filename = "") {
  const lower = filename.toLowerCase();
  if (lower.endsWith(".pdf")) return "application/pdf";
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
  if (lower.endsWith(".gif")) return "image/gif";
  if (lower.endsWith(".webp")) return "image/webp";
  return "application/octet-stream";
}

function attachmentSectionTitle(type) {
  const labels = {
    customerOrder: "受注文件",
    vendorEstimate: "仕入先見積文件",
    vendorInvoice: "仕入先請求書文件",
    vendorReceipt: "仕入先領収書文件",
    paymentNotice: "支払通知文件",
  };
  return labels[type] ?? "附件";
}

function toDateInputValue(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value).slice(0, 10);
  return date.toISOString().slice(0, 10);
}

function fromDateInputValue(value) {
  if (!value) return "";
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? value : date.toISOString();
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const PDF_COLOR_TEMPLATES = {
  monochrome: {
    accent: "rgb(46, 48, 49)",
    softLine: "rgb(217, 217, 212)",
    tableHead: "rgb(245, 246, 247)",
    totalBackground: "rgb(245, 246, 247)",
  },
  oceanTable: {
    accent: "rgb(37, 99, 235)",
    softLine: "rgb(191, 219, 254)",
    tableHead: "rgb(219, 234, 254)",
    totalBackground: "rgb(239, 246, 255)",
  },
  mintTable: {
    accent: "rgb(15, 118, 110)",
    softLine: "rgb(153, 246, 228)",
    tableHead: "rgb(204, 251, 241)",
    totalBackground: "rgb(240, 253, 250)",
  },
  roseTable: {
    accent: "rgb(190, 18, 60)",
    softLine: "rgb(254, 205, 211)",
    tableHead: "rgb(255, 228, 230)",
    totalBackground: "rgb(255, 241, 242)",
  },
  amberTable: {
    accent: "rgb(180, 83, 9)",
    softLine: "rgb(253, 230, 138)",
    tableHead: "rgb(254, 243, 199)",
    totalBackground: "rgb(255, 251, 235)",
  },
  graphiteTable: {
    accent: "rgb(71, 85, 105)",
    softLine: "rgb(203, 213, 225)",
    tableHead: "rgb(226, 232, 240)",
    totalBackground: "rgb(241, 245, 249)",
  },
};

const COLOR_TEMPLATE_OPTIONS = [
  { id: "monochrome", title: "日本帳票", ...PDF_COLOR_TEMPLATES.monochrome },
  { id: "oceanTable", title: "海藍表格", ...PDF_COLOR_TEMPLATES.oceanTable },
  { id: "mintTable", title: "薄荷表格", ...PDF_COLOR_TEMPLATES.mintTable },
  { id: "roseTable", title: "玫瑰表格", ...PDF_COLOR_TEMPLATES.roseTable },
  { id: "amberTable", title: "琥珀表格", ...PDF_COLOR_TEMPLATES.amberTable },
  { id: "graphiteTable", title: "石墨表格", ...PDF_COLOR_TEMPLATES.graphiteTable },
];

function colorTemplateOption(templateId) {
  return COLOR_TEMPLATE_OPTIONS.find((template) => template.id === templateId) ?? COLOR_TEMPLATE_OPTIONS[0];
}

function pdfColorTemplate(templateId) {
  return PDF_COLOR_TEMPLATES[templateId] ?? PDF_COLOR_TEMPLATES.monochrome;
}

function documentTypeTitle(type, languageId = "japanese") {
  const titles = {
    japanese: DOCUMENT_TYPE_LABELS,
    simplifiedChinese: {
      estimate: "报价单",
      customerOrder: "受注",
      purchaseOrder: "采购单",
      delivery: "交货单",
      invoice: "请款单",
      receipt: "收据",
      acceptance: "验收单",
      customerFiles: "项目文件",
      vendorEstimate: "供应商报价记录",
      vendorInvoice: "供应商请款书记录",
      vendorReceipt: "供应商收据记录",
      paymentNotice: "付款通知书",
    },
    english: {
      estimate: "Quotation",
      customerOrder: "Order Received",
      purchaseOrder: "Purchase Order",
      delivery: "Delivery Note",
      invoice: "Invoice",
      receipt: "Receipt",
      acceptance: "Acceptance Receipt",
      customerFiles: "Project Documents",
      vendorEstimate: "Vendor Quotation",
      vendorInvoice: "Vendor Invoice",
      vendorReceipt: "Vendor Receipt",
      paymentNotice: "Payment Notice",
    },
  };
  return titles[languageId]?.[type] ?? DOCUMENT_TYPE_LABELS[type] ?? type ?? "帳票";
}

function documentTypeSubtitle(type, languageId = "japanese") {
  const subtitles = {
    japanese: {
    estimate: "Quotation",
    customerOrder: "受注",
    purchaseOrder: "Purchase Order",
    delivery: "Delivery Note",
    invoice: "Invoice",
    receipt: "Receipt",
    acceptance: "Acceptance Receipt",
    customerFiles: "Project Documents",
    vendorEstimate: "Vendor Quotation",
    vendorInvoice: "Vendor Invoice",
    vendorReceipt: "Vendor Receipt",
    paymentNotice: "Payment Notice",
    },
    simplifiedChinese: {
      estimate: "报价",
      customerOrder: "受注",
      purchaseOrder: "采购订单",
      delivery: "交货记录",
      invoice: "请款",
      receipt: "收据",
      acceptance: "验收记录",
      customerFiles: "项目文件",
      vendorEstimate: "供应商报价",
      vendorInvoice: "供应商请款书",
      vendorReceipt: "供应商收据",
      paymentNotice: "付款通知",
    },
    english: {
      estimate: "Quotation",
      customerOrder: "Order Received",
      purchaseOrder: "Purchase Order",
      delivery: "Delivery Note",
      invoice: "Invoice",
      receipt: "Receipt",
      acceptance: "Acceptance Receipt",
      customerFiles: "Project Documents",
      vendorEstimate: "Vendor Quotation",
      vendorInvoice: "Vendor Invoice",
      vendorReceipt: "Vendor Receipt",
      paymentNotice: "Payment Notice",
    },
  };
  return subtitles[languageId]?.[type] ?? subtitles.japanese[type] ?? "Document";
}

function documentTypeTotalLabel(type, languageId = "japanese") {
  const labels = {
    japanese: {
    estimate: "御見積金額",
    customerOrder: "受注金額",
    purchaseOrder: "発注金額",
    delivery: "納品金額",
    invoice: "ご請求金額",
    receipt: "領収金額",
    acceptance: "受領金額",
    customerFiles: "記録金額",
    vendorEstimate: "見積金額",
    vendorInvoice: "請求金額",
    vendorReceipt: "領収金額",
    paymentNotice: "支払通知金額",
    },
    simplifiedChinese: {
      estimate: "报价金额",
      customerOrder: "受注金额",
      purchaseOrder: "采购金额",
      delivery: "交货金额",
      invoice: "请款金额",
      receipt: "收据金额",
      acceptance: "验收金额",
      customerFiles: "记录金额",
      vendorEstimate: "报价金额",
      vendorInvoice: "请款金额",
      vendorReceipt: "收据金额",
      paymentNotice: "付款通知金额",
    },
    english: {
      estimate: "Quotation Amount",
      customerOrder: "Order Received Amount",
      purchaseOrder: "Purchase Amount",
      delivery: "Delivery Amount",
      invoice: "Invoice Amount",
      receipt: "Receipt Amount",
      acceptance: "Acceptance Amount",
      customerFiles: "Record Amount",
      vendorEstimate: "Quote Amount",
      vendorInvoice: "Invoice Amount",
      vendorReceipt: "Receipt Amount",
      paymentNotice: "Payment Notice Amount",
    },
  };
  return labels[languageId]?.[type] ?? labels.japanese[type] ?? "合計金額";
}

function openingSentence(type, languageId = "japanese") {
  const sentences = {
    japanese: {
    invoice: "下記の通り、ご請求申し上げます。",
    estimate: "下記の通り、お見積り申し上げます。",
    delivery: "下記の通り、納品いたします。",
    receipt: "下記の金額を領収いたしました。",
    acceptance: "下記の通り、受領いたしました。",
    purchaseOrder: "下記の通り、発注いたします。",
    customerOrder: "下記の通り、受注内容を記録します。",
    customerFiles: "下記の通り、顧客書類を管理します。",
    vendorEstimate: "下記の通り、仕入先見積内容を記録します。",
    vendorInvoice: "下記の通り、仕入先請求書内容を記録します。",
    vendorReceipt: "下記の通り、仕入先領収書内容を記録します。",
    paymentNotice: "下記の通り、支払通知内容を記録します。",
    },
    simplifiedChinese: {
      invoice: "兹按以下内容请款。",
      estimate: "兹按以下内容报价。",
      delivery: "兹按以下内容交货。",
      receipt: "已收到以下金额。",
      acceptance: "兹按以下内容完成验收。",
      purchaseOrder: "兹按以下内容发出采购订单。",
      customerOrder: "兹记录以下受注内容。",
      customerFiles: "兹按以下内容管理客户文件。",
      vendorEstimate: "兹记录以下供应商报价内容。",
      vendorInvoice: "兹记录以下供应商请款书内容。",
      vendorReceipt: "兹记录以下供应商收据内容。",
      paymentNotice: "兹记录以下付款通知内容。",
    },
    english: {
      invoice: "We hereby submit the following invoice.",
      estimate: "We hereby submit the following quotation.",
      delivery: "We hereby confirm the following delivery.",
      receipt: "We hereby acknowledge receipt of the following amount.",
      acceptance: "We hereby confirm the following acceptance.",
      purchaseOrder: "We hereby issue the following purchase order.",
      customerOrder: "We hereby record the following order received.",
      customerFiles: "We hereby manage the following project documents.",
      vendorEstimate: "We hereby record the following vendor quotation.",
      vendorInvoice: "We hereby record the following vendor invoice.",
      vendorReceipt: "We hereby record the following vendor receipt.",
      paymentNotice: "We hereby record the following payment notice.",
    },
  };
  return sentences[languageId]?.[type] ?? sentences.japanese[type] ?? "下記の通り、内容を記録します。";
}

function defaultCondition(type, languageId = "japanese") {
  if (languageId === "simplifiedChinese") {
    if (type === "invoice") return "请确认收款账户、付款期限与请款条件。";
    if (type === "estimate") return "请确认报价条件、交付计划、税率与合计金额。";
    return "请确认内容、期限与条件。";
  }
  if (languageId === "english") {
    if (type === "invoice") return "Please confirm bank details, payment due date, and invoice terms.";
    if (type === "estimate") return "Please confirm quotation terms, delivery schedule, tax rate, and total amount.";
    return "Please confirm the content, deadline, and terms.";
  }
  if (type === "invoice") return "振込先、支払期限、請求条件を確認してください。";
  if (type === "estimate") return "見積条件、納入予定、税率・合計金額を確認してください。";
  return "内容、期限、条件を確認してください。";
}

function companyContactLines(contact, phone, email) {
  return [
    contact,
    phone ? `TEL: ${phone}` : "",
    email ? `Email: ${email}` : "",
  ].filter(Boolean);
}

function singleLinePaymentText(value) {
  const lines = String(value ?? "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  return lines.length ? lines.join("  ") : "-";
}

function pdfLabels(languageId = "japanese") {
  return {
    japanese: {
      number: "番号",
      issueDate: "発行日",
      transactionDate: "取引年月日",
      dueDate: "支払期限",
      relatedNumber: "関連番号",
      noRelatedNumber: "関連番号なし",
      qualifiedInvoice: "適格請求書対応",
      registrationNumber: "登録番号",
      paymentAndDue: "振込先 / 支払期限",
      itemName: "品名",
      modelSpec: "型番 / 仕様",
      quantity: "数量",
      unitPrice: "単価",
      amount: "金額",
      notes: "備考",
      paymentDetails: "振込先",
      invoiceCondition: "請求条件",
      condition: "条件",
      paymentProof: "支払証明",
      subtotal: "小計",
      tax: "消費税",
      total: "合計",
      paymentProofDate: "支払日時",
      paymentProofAmount: "支払金額",
      paymentProofFiles: "添付ファイル",
    },
    simplifiedChinese: {
      number: "编号",
      issueDate: "发行日",
      transactionDate: "交易日期",
      dueDate: "付款期限",
      relatedNumber: "关联编号",
      noRelatedNumber: "无关联编号",
      qualifiedInvoice: "适格发票对应",
      registrationNumber: "登记编号",
      paymentAndDue: "收款账户 / 付款期限",
      itemName: "品名",
      modelSpec: "型号 / 规格",
      quantity: "数量",
      unitPrice: "单价",
      amount: "金额",
      notes: "备注",
      paymentDetails: "收款账户",
      invoiceCondition: "请款条件",
      condition: "条件",
      paymentProof: "付款证明",
      subtotal: "小计",
      tax: "消费税",
      total: "合计",
      paymentProofDate: "付款时间",
      paymentProofAmount: "付款金额",
      paymentProofFiles: "附件",
    },
    english: {
      number: "No.",
      issueDate: "Issue Date",
      transactionDate: "Transaction Date",
      dueDate: "Due Date",
      relatedNumber: "Related No.",
      noRelatedNumber: "No related number",
      qualifiedInvoice: "Qualified Invoice",
      registrationNumber: "Registration No.",
      paymentAndDue: "Payment Details / Due Date",
      itemName: "Item",
      modelSpec: "Model / Specification",
      quantity: "Qty",
      unitPrice: "Unit Price",
      amount: "Amount",
      notes: "Notes",
      paymentDetails: "Payment Details",
      invoiceCondition: "Invoice Terms",
      condition: "Terms",
      paymentProof: "Payment Proof",
      subtotal: "Subtotal",
      tax: "Tax",
      total: "Total",
      paymentProofDate: "Payment Date",
      paymentProofAmount: "Payment Amount",
      paymentProofFiles: "Attachments",
    },
  }[languageId] ?? pdfLabels("japanese");
}

function paymentProofText(document, languageId = "japanese") {
  const labels = pdfLabels(languageId);
  const lines = [];
  if (document.paymentProofDate) lines.push(`${labels.paymentProofDate}: ${formatDate(document.paymentProofDate)}`);
  if (document.paymentProofAmount !== null && document.paymentProofAmount !== undefined && document.paymentProofAmount !== "") {
    lines.push(`${labels.paymentProofAmount}: ${formatCurrency(document.paymentProofAmount)}`);
  }
  const attachments = document.paymentProofAttachments ?? [];
  if (attachments.length) {
    const names = attachments.map((item) => item?.filename).filter(Boolean).join(", ");
    lines.push(`${labels.paymentProofFiles}: ${names || attachments.length}`);
  }
  return lines.length ? lines.join("\n") : "-";
}

function quantityText(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return "-";
  return new Intl.NumberFormat("ja-JP", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 3,
  }).format(number);
}

function buildPrintableDocumentHtml(document) {
  const totals = documentTotal(document);
  const presentation = documentPresentationRules(document.type);
  const displayTotal = presentation.showTax ? totals.total : totals.subtotal;
  const customerContact = companyContactLines(document.customerContact, document.customerPhone, document.customerEmail);
  const issuerContact = companyContactLines(document.issuerContact, document.issuerPhone, document.issuerEmail);
  const paymentProof = paymentProofText(document);
  const lines = (document.lines ?? [])
    .map((line) => {
      const quantity = Number(line.quantity);
      const unitPrice = Number(line.unitPrice);
      const amount = (Number.isFinite(quantity) ? quantity : 0) * (Number.isFinite(unitPrice) ? unitPrice : 0);
      return `
        <tr>
          <td>${escapeHtml(line.name || "-")}</td>
          <td>${escapeHtml([line.model, line.specification].filter(Boolean).join(" / ") || "-")}</td>
          <td class="number">${escapeHtml(Number.isFinite(quantity) ? quantity.toLocaleString("ja-JP") : "-")}</td>
          ${presentation.showLinePrices ? `<td class="number">${escapeHtml(formatCurrency(Number.isFinite(unitPrice) ? unitPrice : 0))}</td>` : ""}
          ${presentation.showLinePrices ? `<td class="number">${escapeHtml(formatCurrency(amount))}</td>` : ""}
        </tr>
      `;
    })
    .join("");
  const metaDueDate = presentation.showDueDate ? `<span><b>支払期限</b>${escapeHtml(formatDate(document.dueDate))}</span>` : "";
  const amountSection = (presentation.showSummaryTotals || presentation.showPaymentDetails) ? `
    <section class="amount ${presentation.showPaymentDetails ? "" : "simple"}">
      ${presentation.showSummaryTotals ? `
        <div>
          <span class="label">${escapeHtml(documentTypeTotalLabel(document.type))}</span>
          <strong>${escapeHtml(formatCurrency(displayTotal))}</strong>
        </div>
      ` : ""}
      ${presentation.showPaymentDetails ? `
        <div class="payment">
          <span class="label">振込先 / 支払期限</span>
          <p>${escapeHtml(singleLinePaymentText(document.paymentDetails))}</p>
          ${presentation.showDueDate ? `<small>支払期限: ${escapeHtml(formatDate(document.dueDate))}</small>` : ""}
        </div>
      ` : ""}
    </section>
  ` : "";
  const paymentDetailsBlock = presentation.showPaymentDetails ? `
        <h2>振込先</h2>
        <div class="notes">${escapeHtml(document.paymentDetails || "-")}</div>
  ` : "";
  const totalsBlock = presentation.showSummaryTotals ? `
      <div class="totals">
        <div><span>小計</span><strong>${escapeHtml(formatCurrency(totals.subtotal))}</strong></div>
        ${presentation.showTax ? `<div><span>消費税 ${escapeHtml(Number(document.taxRate || 0))}%</span><strong>${escapeHtml(formatCurrency(totals.tax))}</strong></div>` : ""}
        <div class="total-row"><span>合計</span><strong>${escapeHtml(formatCurrency(displayTotal))}</strong></div>
      </div>
  ` : "";
  const tableColgroup = presentation.showLinePrices ? `
        <col style="width: 34%;" />
        <col style="width: 26%;" />
        <col style="width: 10%;" />
        <col style="width: 15%;" />
        <col style="width: 15%;" />
  ` : `
        <col style="width: 42%;" />
        <col style="width: 43%;" />
        <col style="width: 15%;" />
  `;
  const priceHeaders = presentation.showLinePrices ? `
          <th>単価</th>
          <th>金額</th>
  ` : "";

  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(document.number || documentTypeTitle(document.type))}</title>
  <style>
    @page { size: A4; margin: 16mm; }
    * { box-sizing: border-box; }
    body { color: #1b1f23; font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Yu Gothic", "Segoe UI", sans-serif; font-size: 12px; margin: 0; }
    .page { margin: 0 auto; max-width: 178mm; overflow: hidden; }
    .page, .page * { max-width: 100%; overflow-wrap: anywhere; word-break: break-word; }
    header { border-bottom: 2px solid #1b1f23; display: grid; gap: 24px; grid-template-columns: minmax(0, 1fr) minmax(48mm, 64mm); justify-content: space-between; padding-bottom: 22px; }
    .subtitle, .label { color: #57606a; font-size: 12px; font-weight: 800; }
    h1 { font-size: 30px; margin: 6px 0 0; }
    header p { margin: 10px 0 0; }
    .meta { color: #424a53; display: grid; gap: 5px; min-width: 0; text-align: right; }
    .meta span { display: grid; grid-template-columns: 76px 1fr; gap: 8px; }
    .party-grid { display: grid; gap: 28px; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); margin-top: 30px; }
    .party { border-bottom: 1px solid #d7dde4; min-height: 112px; padding-bottom: 14px; }
    .party strong { display: block; font-size: 19px; margin: 10px 0 12px; }
    .party p { line-height: 1.5; margin: 0 0 4px; white-space: pre-wrap; }
    .qualified { background: #ecfbfa; border: 1px solid #b8dfdd; display: inline-grid; gap: 4px; margin-bottom: 12px; padding: 7px 9px; }
    .qualified span { font-weight: 800; }
    .amount { background: #f6f8fa; border: 1px solid #d7dde4; display: grid; gap: 14px; grid-template-columns: minmax(38mm, 48mm) minmax(0, 1fr); margin: 30px 0; padding: 18px; }
    .amount.simple { grid-template-columns: 1fr; }
    .amount strong { display: block; font-size: 27px; margin: 8px 0 5px; }
    .payment p { margin: 8px 0 4px; }
    table { border-collapse: collapse; table-layout: fixed; width: 100%; }
    th, td { border: 1px solid #d7dde4; max-width: 0; padding: 10px; text-align: left; vertical-align: top; white-space: normal; }
    th { background: #edf1f5; color: #424a53; font-weight: 800; }
    .number { text-align: right; }
    .bottom { display: grid; gap: 28px; grid-template-columns: minmax(0, 1fr) minmax(48mm, 64mm); margin-top: 28px; }
    h2 { font-size: 15px; margin: 14px 0 8px; }
    h2:first-child { margin-top: 0; }
    .notes { border: 1px solid #d7dde4; line-height: 1.6; min-height: 54px; padding: 12px; white-space: pre-wrap; }
    .totals { border: 1px solid #d7dde4; }
    .totals div { display: flex; justify-content: space-between; padding: 10px 12px; }
    .totals div + div { border-top: 1px solid #d7dde4; }
    .total-row { background: #f6f8fa; font-size: 17px; }
    @media print { body { print-color-adjust: exact; -webkit-print-color-adjust: exact; } }
  </style>
</head>
<body>
  <main class="page">
    <header>
      <div>
        <h1>${escapeHtml(documentTypeTitle(document.type))}</h1>
        <div class="subtitle">${escapeHtml(documentTypeSubtitle(document.type))}</div>
        <p>${escapeHtml(openingSentence(document.type))}</p>
      </div>
      <div class="meta">
        <span><b>番号</b>${escapeHtml(document.number || "-")}</span>
        <span><b>発行日</b>${escapeHtml(formatDate(document.issueDate))}</span>
        <span><b>取引年月日</b>${escapeHtml(formatDate(document.transactionDate))}</span>
        ${metaDueDate}
        <span><b>関連番号</b>${escapeHtml(document.relatedNumber || "関連番号なし")}</span>
      </div>
    </header>
    <section class="party-grid">
      <div class="party">
        <strong>${escapeHtml(`${document.customerName || presentation.partyFallback} ${document.honorific || "御中"}`)}</strong>
        <p>${escapeHtml(document.customerAddress || "-")}</p>
        ${customerContact.map((line) => `<p>${escapeHtml(line)}</p>`).join("")}
      </div>
      <div class="party">
        ${presentation.showIssuerRegistration && document.issuerRegistration ? `<div class="qualified"><span>適格請求書対応</span><small>登録番号: ${escapeHtml(document.issuerRegistration)}</small></div>` : ""}
        <strong>${escapeHtml(document.issuerName || "未設定公司")}</strong>
        <p>${escapeHtml(document.issuerAddress || "-")}</p>
        ${issuerContact.map((line) => `<p>${escapeHtml(line)}</p>`).join("")}
      </div>
    </section>
    ${amountSection}
    <table>
      <colgroup>
        ${tableColgroup}
      </colgroup>
      <thead>
        <tr>
          <th>品名</th>
          <th>型番 / 仕様</th>
          <th>数量</th>
          ${priceHeaders}
        </tr>
      </thead>
      <tbody>${lines}</tbody>
    </table>
    <section class="bottom">
      <div>
        <h2>備考</h2>
        <div class="notes">${escapeHtml(document.notes || "-")}</div>
        ${paymentDetailsBlock}
        <h2>${escapeHtml(document.type === "invoice" ? "請求条件" : "条件")}</h2>
        <div class="notes">${escapeHtml(document.documentMemo || defaultCondition(document.type))}</div>
        ${isVendorDocumentType(document.type) ? `<h2>支払証明</h2><div class="notes">${escapeHtml(paymentProof)}</div>` : ""}
      </div>
      ${totalsBlock}
    </section>
  </main>
</body>
</html>`;
}

function formatCurrency(value) {
  const number = Number(value);
  return `¥${(Number.isFinite(number) ? number : 0).toLocaleString("ja-JP")}`;
}

function plainInputAttributes(inputMode = "text") {
  return {
    autoCapitalize: "none",
    autoComplete: "off",
    autoCorrect: "off",
    inputMode,
    lang: "en",
    spellCheck: false,
  };
}

function handleLiteralMinus(event, commit) {
  if (event.code !== "Minus" || event.metaKey || event.ctrlKey || event.altKey) return;
  const target = event.currentTarget;
  const value = String(target.value ?? "");
  const start = target.selectionStart ?? value.length;
  const end = target.selectionEnd ?? start;
  const nextValue = `${value.slice(0, start)}-${value.slice(end)}`;
  event.preventDefault();
  commit(nextValue);
  requestAnimationFrame(() => {
    try {
      target.setSelectionRange(start + 1, start + 1);
    } catch {
      // Some input implementations do not support cursor restoration.
    }
  });
}

function normalizeNumericInput(value) {
  const text = String(value ?? "");
  if (text === "" || text === "-" || text === "." || text === "-.") {
    return text;
  }
  const number = Number(text);
  return Number.isFinite(number) ? number : text;
}

function isBlankInput(value) {
  return typeof value === "string" && value.trim() === "";
}

function hasMeaningfulInput(values) {
  return Object.values(values ?? {}).some((value) => {
    if (typeof value === "string") return value.trim().length > 0;
    if (typeof value === "number") return Number.isFinite(value) && value !== 0;
    if (Array.isArray(value)) return value.length > 0;
    return value !== null && value !== undefined && value !== false;
  });
}

function hasMeaningfulDocumentInput(document) {
  const lines = document?.lines ?? [];
  return hasMeaningfulInput({
    number: document?.number,
    projectName: document?.projectName,
    relatedNumber: document?.relatedNumber,
    customerName: document?.customerName,
    customerAddress: document?.customerAddress,
    customerContact: document?.customerContact,
    customerPhone: document?.customerPhone,
    customerEmail: document?.customerEmail,
    issuerName: document?.issuerName,
    issuerRegistration: document?.issuerRegistration,
    issuerAddress: document?.issuerAddress,
    issuerContact: document?.issuerContact,
    issuerPhone: document?.issuerPhone,
    issuerEmail: document?.issuerEmail,
    notes: document?.notes,
    paymentDetails: document?.paymentDetails,
    documentMemo: document?.documentMemo,
  }) || lines.some((line) => hasMeaningfulInput(line));
}

createRoot(document.getElementById("root")).render(<App />);
