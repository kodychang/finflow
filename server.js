const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const os = require("node:os");
const { execFile } = require("node:child_process");
const { promisify } = require("node:util");

const PORT = Number(process.env.PORT || 4173);
const ROOT = __dirname;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";
const OPENAI_MODEL = process.env.OPENAI_OCR_MODEL || "gpt-4.1-mini";
const OCR_MAX_BYTES = Number(process.env.OCR_MAX_BYTES || 8 * 1024 * 1024);
const OCR_MAX_RETRIES = Number(process.env.OCR_MAX_RETRIES || 2);
const OCR_MAX_PDF_PAGES = Number(process.env.OCR_MAX_PDF_PAGES || 6);
const OCR_CACHE_PATH = path.join(ROOT, "data", "ocr_cache.json");
const TRAINING_JSONL_PATH = path.join(ROOT, "data", "paddle_ocr_training.jsonl");
const TRAINING_META_PATH = path.join(ROOT, "data", "training_samples.ndjson");
const GOOGLE_DRIVE_AUTH_PATH = path.join(ROOT, "data", "google_drive_auth.json");
const GOOGLE_DRIVE_SYNC_PATH = path.join(ROOT, "data", "google_drive_sync.json");
const PDF_RENDER_SCRIPT = path.join(ROOT, "scripts", "render_pdf_pages.swift");
const execFileAsync = promisify(execFile);
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || "";
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || "";
const GOOGLE_REDIRECT_URI = process.env.GOOGLE_REDIRECT_URI || `http://localhost:${PORT}/auth/google-drive/callback`;
const GOOGLE_DRIVE_SCOPES = [
  "openid",
  "email",
  "profile",
  "https://www.googleapis.com/auth/drive.file",
];
const oauthStates = new Map();

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
};

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  });
  res.end(JSON.stringify(payload));
}

function collectBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function ensureDataDir() {
  fs.mkdirSync(path.join(ROOT, "data"), { recursive: true });
}

function safeReadJson(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
  }
}

function safeWriteJson(filePath, value) {
  ensureDataDir();
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2));
}

function appendJsonLine(filePath, record) {
  ensureDataDir();
  fs.appendFileSync(filePath, `${JSON.stringify(record)}\n`);
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function base64UrlDecode(value) {
  const normalized = String(value || "").replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return Buffer.from(padded, "base64").toString("utf8");
}

function parseJwtPayload(token) {
  try {
    const parts = String(token || "").split(".");
    if (parts.length < 2) return {};
    return JSON.parse(base64UrlDecode(parts[1]));
  } catch {
    return {};
  }
}

function driveAuthRecord() {
  return safeReadJson(GOOGLE_DRIVE_AUTH_PATH, {
    connected: false,
    email: "",
    scope: "",
    lastSyncedAt: "",
    tokens: null,
  });
}

function saveDriveAuthRecord(record) {
  safeWriteJson(GOOGLE_DRIVE_AUTH_PATH, record);
}

function driveSyncRecord() {
  return safeReadJson(GOOGLE_DRIVE_SYNC_PATH, {
    syncedAt: "",
    folderCount: 0,
    message: "未同期",
  });
}

function saveDriveSyncRecord(record) {
  safeWriteJson(GOOGLE_DRIVE_SYNC_PATH, record);
}

function parseDataUrl(dataUrl) {
  const match = String(dataUrl).match(/^data:([^;]+);base64,(.+)$/);
  if (!match) throw new Error("Invalid data URL");
  return {
    mimeType: match[1],
    base64: match[2],
    buffer: Buffer.from(match[2], "base64"),
  };
}

function isHeicInput({ mimeType, fileName }) {
  const lower = String(fileName || "").toLowerCase();
  return mimeType === "image/heic" || mimeType === "image/heif" || lower.endsWith(".heic") || lower.endsWith(".heif");
}

async function convertHeicBufferToJpegDataUrl(buffer) {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "finflow-heic-"));
  const inputPath = path.join(tempRoot, "input.heic");
  const outputPath = path.join(tempRoot, "output.jpg");
  try {
    fs.writeFileSync(inputPath, buffer);
    await execFileAsync("/usr/bin/sips", ["-s", "format", "jpeg", inputPath, "--out", outputPath], {
      maxBuffer: 10 * 1024 * 1024,
    });
    const jpegBuffer = fs.readFileSync(outputPath);
    return `data:image/jpeg;base64,${jpegBuffer.toString("base64")}`;
  } finally {
    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
}

function extractJsonString(value) {
  const text = String(value || "").trim();
  if (!text) {
    throw new Error("OCR returned an empty response");
  }
  const fencedMatch = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  const candidate = fencedMatch ? fencedMatch[1].trim() : text;
  if (candidate.startsWith("{") && candidate.endsWith("}")) {
    return candidate;
  }
  const start = candidate.indexOf("{");
  const end = candidate.lastIndexOf("}");
  if (start !== -1 && end !== -1 && end > start) {
    return candidate.slice(start, end + 1);
  }
  throw new Error(`OCR did not return valid JSON: ${candidate.slice(0, 200)}`);
}

function extractOutputText(payload) {
  if (typeof payload.output_text === "string" && payload.output_text.trim()) {
    return payload.output_text;
  }
  const fragments = [];
  for (const item of payload.output || []) {
    for (const content of item.content || []) {
      if (content.type === "output_text" && content.text) {
        fragments.push(content.text);
      }
    }
  }
  return fragments.join("\n").trim();
}

function repairJsonString(text) {
  let repaired = String(text || "");
  repaired = repaired.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, " ");
  repaired = repaired.replace(/\r?\n/g, "\\n");
  repaired = repaired.replace(/\t/g, " ");
  repaired = repaired.replace(/\\(?!["\\/bfnrtu])/g, "\\\\");
  repaired = repaired.replace(/,\s*([}\]])/g, "$1");
  return repaired;
}

function parseOcrJson(rawText) {
  const jsonText = extractJsonString(rawText);
  try {
    return JSON.parse(jsonText);
  } catch (error) {
    const repaired = repairJsonString(jsonText);
    try {
      return JSON.parse(repaired);
    } catch {
      throw new Error(`OCR JSON parse failed: ${error.message}`);
    }
  }
}

function sanitizeFilePart(value) {
  return String(value || "")
    .trim()
    .replace(/[\\/:*?"<>|\s]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 48) || "unknown";
}

function buildRenamedName(result, extension = "jpg") {
  const date = String(result.date || result.issue_date || new Date().toISOString().slice(0, 10)).replaceAll("-", "");
  const vendor = sanitizeFilePart(result.vendor || result.counterparty || "unknown");
  const type = sanitizeFilePart(result.document_type || "document");
  const amount = Math.round(Number(result.amount || 0));
  return `${date}_${vendor}_${type}_${amount}.${sanitizeFilePart(extension).toLowerCase()}`;
}

function suggestDirectory(result) {
  const owner = result.owner_type === "personal" ? "personal" : "company";
  if (result.document_type === "invoice") return `${owner}/invoices`;
  if (result.document_type === "contract") return `${owner}/contracts`;
  if (result.document_type === "bank_statement") return `${owner}/bank`;
  if (result.document_type === "tax_document" || result.category === "税金") return `${owner}/tax`;
  return `${owner}/receipts`;
}

async function callOpenAIForOcr({ fileName, dataUrl, languageHint }) {
  const isPdf = dataUrl.startsWith("data:application/pdf");
  const prompt = buildJapanOcrPrompt({ fileName, languageHint, isPdf });
  const content = [
    { type: "input_text", text: prompt },
    isPdf
      ? {
          type: "input_file",
          filename: fileName,
          file_data: dataUrl.split(",")[1] || "",
        }
      : { type: "input_image", image_url: dataUrl },
  ];

  let lastError;
  for (let attempt = 0; attempt <= OCR_MAX_RETRIES; attempt += 1) {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        input: [{ role: "user", content }],
        max_output_tokens: 1800,
      }),
    });

    if (response.ok) {
      const payload = await response.json();
      const rawText = extractOutputText(payload);
      return parseOcrJson(rawText);
    }

    const errorText = await response.text();
    lastError = new Error(`OpenAI API error ${response.status}: ${errorText}`);
    if (![408, 409, 429, 500, 502, 503, 504].includes(response.status) || attempt === OCR_MAX_RETRIES) {
      throw lastError;
    }
    await sleep(500 * (attempt + 1));
  }

  throw lastError || new Error("OpenAI OCR request failed");
}

function buildJapanOcrPrompt({ fileName, languageHint, isPdf }) {
  const lower = String(fileName || "").toLowerCase();
  const isBankDoc = ["bank", "statement", "card", "visa", "master", "amex", "jcb", "口座", "明細", "カード"].some((keyword) => lower.includes(keyword));
  return [
    "You are an OCR extraction engine for Japanese SME bookkeeping, invoice retention, and tax filing support.",
    "Target documents include Japanese receipts, invoices, quotations, payment requests, bank statements, contracts, and tax notices.",
    "Prioritize Japanese business document conventions: 発行日, 支払期限, 合計金額, 消費税額, 税率, 登録番号, 宛名, 発行者, 支払方法.",
    "Return JSON only. No markdown. No commentary.",
    "If a field is unknown, use empty string for text fields, 0 for numeric amounts, false for booleans.",
    "Use one of document_type: receipt, invoice, contract, bank_statement, tax_document, other.",
    "Use one of owner_type: company, personal.",
    "Use one of transaction_type: income, expense, other.",
    "Prefer Japanese accounting categories such as 売上, 広告宣伝費, 交通費, 通信費, 接待交際費, 消耗品費, 外注費, 家賃, 水道光熱費, 雑費, 税金, 契約書, 銀行明細.",
    "For Japanese receipts and invoices, check whether the issuer registration number appears as T + 13 digits. Put it into invoice_number.",
    isBankDoc
      ? "This file looks like a Japanese bank statement or credit card statement. Prioritize statement issuer, account institution, closing date, payment date, total debit/credit, and classify as bank_statement when appropriate."
      : "For bank statements or credit card statements, extract the main account institution or statement issuer into vendor, and summarize visible transaction context.",
    `Language hint: ${languageHint || "ja"}.`,
    `Original file name: ${fileName}.`,
    `Input type: ${isPdf ? "pdf" : "image"}.`,
    'JSON schema: {"document_type":"","owner_type":"","transaction_type":"","date":"","issue_date":"","due_date":"","amount":0,"tax_amount":0,"tax_rate":"","vendor":"","invoice_number":"","category":"","payment_method":"","summary":"","ocr_text":"","confidence":0,"need_review":true}',
  ].join("\n");
}

async function renderPdfPages(pdfBuffer) {
  ensureDataDir();
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "finflow-pdf-"));
  const inputPath = path.join(tempRoot, "input.pdf");
  const outputDir = path.join(tempRoot, "pages");
  fs.writeFileSync(inputPath, pdfBuffer);
  const { stdout } = await execFileAsync("/usr/bin/swift", [PDF_RENDER_SCRIPT, inputPath, outputDir, String(OCR_MAX_PDF_PAGES)], {
    maxBuffer: 10 * 1024 * 1024,
  });
  const pages = JSON.parse(stdout || "[]");
  const rendered = pages.map((page) => {
    const imageBuffer = fs.readFileSync(page.path);
    return {
      page: page.page,
      dataUrl: `data:image/png;base64,${imageBuffer.toString("base64")}`,
    };
  });
  fs.rmSync(tempRoot, { recursive: true, force: true });
  return rendered;
}

function mergePageResults(pageResults) {
  if (!pageResults.length) return {};
  const merged = { ...pageResults[0] };
  merged.ocr_text = pageResults.map((item, index) => `--- page ${index + 1} ---\n${item.ocr_text || ""}`).join("\n");
  merged.summary = pageResults.map((item) => item.summary).filter(Boolean).join(" / ");
  merged.confidence = Number((pageResults.reduce((sum, item) => sum + Number(item.confidence || 0), 0) / pageResults.length).toFixed(2));
  for (const item of pageResults) {
    if (!merged.vendor && item.vendor) merged.vendor = item.vendor;
    if (!merged.invoice_number && item.invoice_number) merged.invoice_number = item.invoice_number;
    if ((!merged.amount || merged.amount === 0) && item.amount) merged.amount = item.amount;
    if ((!merged.tax_amount || merged.tax_amount === 0) && item.tax_amount) merged.tax_amount = item.tax_amount;
    if (!merged.date && item.date) merged.date = item.date;
    if (!merged.issue_date && item.issue_date) merged.issue_date = item.issue_date;
    if (!merged.due_date && item.due_date) merged.due_date = item.due_date;
  }
  return merged;
}

function normalizeOcrDocument(ocr, { fileName, language, extension, sourceHash }) {
  return {
    id: `doc-${Date.now()}-${Math.round(Math.random() * 9999)}`,
    name: fileName,
    original_name: fileName,
    renamed_name: buildRenamedName(ocr, extension),
    fileType: extension.toUpperCase(),
    status: "review",
    archive_status: "pending_review",
    target_directory: suggestDirectory(ocr),
    ai_strategy: "vision_api",
    standard_profile: "jp_invoice",
    document_type: ocr.document_type || "other",
    owner_type: ocr.owner_type || "company",
    transaction_type: ocr.transaction_type || "other",
    date: ocr.date || ocr.issue_date || "",
    created_at: new Date().toISOString().slice(0, 16),
    issued_at: ocr.issue_date || ocr.date || "",
    due_at: ocr.due_date || "",
    amount: Number(ocr.amount || 0),
    tax_amount: Number(ocr.tax_amount || 0),
    tax_rate: ocr.tax_rate || "",
    vendor: ocr.vendor || "",
    invoice_number: ocr.invoice_number || "",
    category: ocr.category || "要確認",
    payment_method: ocr.payment_method || "",
    account: "",
    tax_deductible: Boolean(ocr.transaction_type === "expense"),
    confidence: Number(ocr.confidence || 0.7),
    need_review: ocr.need_review !== false,
    summary: ocr.summary || "OCR API 解析結果。確認後に確定してください。",
    review_notes: "日本向け OCR prompt で抽出。確認後の修正データは将来の PaddleOCR 学習候補として保存します。",
    ocr_text: ocr.ocr_text || "",
    hash: sourceHash,
    language,
    ocr_engine: `openai:${OPENAI_MODEL}`,
  };
}

function saveTrainingSample(payload) {
  const timestamp = new Date().toISOString();
  const sampleId = `sample-${Date.now()}-${Math.round(Math.random() * 9999)}`;
  const metaRecord = {
    id: sampleId,
    created_at: timestamp,
    ...payload,
  };
  appendJsonLine(TRAINING_META_PATH, metaRecord);
  appendJsonLine(TRAINING_JSONL_PATH, {
    messages: [
      {
        role: "system",
        content: "Extract Japanese bookkeeping OCR fields into JSON.",
      },
      {
        role: "user",
        content: [
          { type: "input_text", text: `file_name=${payload.file_name}\nocr_engine=${payload.ocr_engine}\nocr_text=${payload.ocr_text || ""}` },
        ],
      },
      {
        role: "assistant",
        content: JSON.stringify(payload.final_document || {}),
      },
    ],
    metadata: {
      id: sampleId,
      document_type: payload.final_document?.document_type || "",
      owner_type: payload.final_document?.owner_type || "",
      changed_fields: payload.changed_fields || [],
      language: payload.language || payload.final_document?.language || "",
      confidence_before: payload.initial_document?.confidence ?? null,
      confidence_after: payload.final_document?.confidence ?? null,
      before_fields: payload.before_fields || payload.initial_document || {},
      after_fields: payload.after_fields || payload.final_document || {},
    },
  });
}

function readNdjson(filePath) {
  try {
    return fs
      .readFileSync(filePath, "utf8")
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line));
  } catch {
    return [];
  }
}

async function handleOcr(req, res) {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    });
    res.end();
    return;
  }

  if (req.method !== "POST") {
    sendJson(res, 405, { error: "Method not allowed" });
    return;
  }

  if (!OPENAI_API_KEY) {
    sendJson(res, 500, { error: "OPENAI_API_KEY is not configured" });
    return;
  }

  try {
    const body = await collectBody(req);
    const payload = JSON.parse(body || "{}");
    const { fileName = "upload.jpg", dataUrl = "", language = "ja", sourceHash = "" } = payload;
    if (!dataUrl.startsWith("data:")) {
      sendJson(res, 400, { error: "dataUrl is required" });
      return;
    }
    const parsedInput = parseDataUrl(dataUrl);
    const bytes = parsedInput.buffer.length;
    if (bytes > OCR_MAX_BYTES) {
      sendJson(res, 413, { error: `File too large for OCR. Limit is ${OCR_MAX_BYTES} bytes.` });
      return;
    }
    const cacheKey = sourceHash || sha256(`${fileName}:${parsedInput.base64.slice(0, 2000)}`);
    const cache = safeReadJson(OCR_CACHE_PATH, {});
    if (cache[cacheKey]) {
      sendJson(res, 200, { ok: true, document: { ...cache[cacheKey], id: `doc-${Date.now()}-${Math.round(Math.random() * 9999)}` }, cached: true });
      return;
    }

    let ocr;
    let sourceDataUrl = dataUrl;
    if (parsedInput.mimeType === "application/pdf") {
      const pages = await renderPdfPages(parsedInput.buffer);
      const pageResults = [];
      for (const page of pages) {
        pageResults.push(await callOpenAIForOcr({ fileName: `${fileName}#page-${page.page}`, dataUrl: page.dataUrl, languageHint: language }));
      }
      ocr = mergePageResults(pageResults);
    } else {
      if (isHeicInput({ mimeType: parsedInput.mimeType, fileName })) {
        sourceDataUrl = await convertHeicBufferToJpegDataUrl(parsedInput.buffer);
      }
      ocr = await callOpenAIForOcr({ fileName, dataUrl: sourceDataUrl, languageHint: language });
    }
    const extension = sourceDataUrl.startsWith("data:image/jpeg") ? "jpg" : path.extname(fileName).replace(".", "") || "jpg";
    const normalized = normalizeOcrDocument(ocr, { fileName, language, extension, sourceHash: cacheKey });
    cache[cacheKey] = normalized;
    safeWriteJson(OCR_CACHE_PATH, cache);

    sendJson(res, 200, { ok: true, document: normalized });
  } catch (error) {
    sendJson(res, 500, { error: error.message || "OCR failed" });
  }
}

async function handleTrainingSample(req, res) {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    });
    res.end();
    return;
  }
  if (req.method !== "POST") {
    sendJson(res, 405, { error: "Method not allowed" });
    return;
  }
  try {
    const body = await collectBody(req);
    const payload = JSON.parse(body || "{}");
    saveTrainingSample(payload);
    sendJson(res, 200, { ok: true });
  } catch (error) {
    sendJson(res, 500, { error: error.message || "training sample save failed" });
  }
}

async function handleTrainingStats(req, res) {
  const meta = readNdjson(TRAINING_META_PATH);
  const cache = safeReadJson(OCR_CACHE_PATH, {});
  const total = meta.length;
  const exactHits = meta.filter((item) => !item.changed_fields || item.changed_fields.length === 0).length;
  const latest = meta
    .slice(-10)
    .reverse()
    .map((item) => ({
      id: item.id,
      file_name: item.file_name,
      document_type: item.final_document?.document_type || "",
      language: item.language || item.final_document?.language || "",
      confidence_before: item.initial_document?.confidence ?? null,
      confidence_after: item.final_document?.confidence ?? null,
      changed_fields: item.changed_fields || [],
      created_at: item.created_at,
    }));
  sendJson(res, 200, {
    ok: true,
    stats: {
      total_samples: total,
      exact_hit_rate: total ? Number((exactHits / total).toFixed(4)) : 0,
      cache_entries: Object.keys(cache).length,
      latest_samples: latest,
    },
  });
}

async function handleGoogleDriveStatus(req, res) {
  sendJson(res, 200, { ok: true, drive: driveAuthRecord() });
}

async function handleGoogleDriveDisconnect(req, res) {
  if (req.method !== "POST") {
    sendJson(res, 405, { error: "Method not allowed" });
    return;
  }
  saveDriveAuthRecord({
    connected: false,
    email: "",
    scope: "",
    lastSyncedAt: "",
    tokens: null,
  });
  sendJson(res, 200, { ok: true });
}

async function googleApiFetch(url, options = {}, tokens = {}) {
  const headers = {
    Authorization: `Bearer ${tokens.access_token || ""}`,
    "Content-Type": "application/json; charset=utf-8",
    ...(options.headers || {}),
  };
  const response = await fetch(url, { ...options, headers });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Google Drive API error ${response.status}: ${text}`);
  }
  return response.json();
}

async function ensureDriveFolder({ name, parentId = "", tokens }) {
  const search = new URL("https://www.googleapis.com/drive/v3/files");
  const clauses = [
    `name='${String(name).replace(/'/g, "\\'")}'`,
    "mimeType='application/vnd.google-apps.folder'",
    "trashed=false",
  ];
  if (parentId) {
    clauses.push(`'${parentId}' in parents`);
  }
  search.searchParams.set("q", clauses.join(" and "));
  search.searchParams.set("fields", "files(id,name)");
  const existing = await googleApiFetch(search.toString(), { method: "GET", headers: { "Content-Type": undefined } }, tokens);
  if (existing.files?.length) {
    return existing.files[0].id;
  }
  const created = await googleApiFetch(
    "https://www.googleapis.com/drive/v3/files?fields=id,name",
    {
      method: "POST",
      body: JSON.stringify({
        name,
        mimeType: "application/vnd.google-apps.folder",
        parents: parentId ? [parentId] : undefined,
      }),
    },
    tokens,
  );
  return created.id;
}

async function handleGoogleDriveSync(req, res) {
  if (req.method !== "POST") {
    sendJson(res, 405, { error: "Method not allowed" });
    return;
  }
  const auth = driveAuthRecord();
  if (!auth.connected || !auth.tokens?.access_token) {
    sendJson(res, 400, { error: "Google Drive is not connected" });
    return;
  }
  const folders = [
    "FinFlow Backup/2026/法人/請求書",
    "FinFlow Backup/2026/法人/領収書",
    "FinFlow Backup/2026/法人/契約書",
    "FinFlow Backup/2026/法人/税務書類",
    "FinFlow Backup/2026/法人/口座明細",
    "FinFlow Backup/2026/法人/特許",
    "FinFlow Backup/2026/法人/不動産",
    "FinFlow Backup/2026/法人/検査報告",
    "FinFlow Backup/2026/法人/許認可",
    "FinFlow Backup/2026/法人/保険",
    "FinFlow Backup/2026/個人/領収書",
    "FinFlow Backup/2026/個人/税務書類",
    "FinFlow Backup/2026/個人/口座明細",
    "FinFlow Backup/2026/確認待ち",
  ];
  let createdOrFound = 0;
  for (const folderPath of folders) {
    const parts = folderPath.split("/");
    let parentId = "";
    for (const part of parts) {
      parentId = await ensureDriveFolder({ name: part, parentId, tokens: auth.tokens });
      createdOrFound += 1;
    }
  }
  const syncedAt = new Date().toISOString();
  saveDriveAuthRecord({
    ...auth,
    lastSyncedAt: syncedAt,
  });
  const result = {
    syncedAt,
    lastSyncedAt: syncedAt,
    folderCount: folders.length,
    message: "Google Drive の保存先フォルダを同期しました",
  };
  saveDriveSyncRecord(result);
  sendJson(res, 200, { ok: true, result });
}

function handleGoogleDriveStart(req, res) {
  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Google Drive OAuth is not configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.");
    return;
  }
  const state = crypto.randomBytes(24).toString("hex");
  oauthStates.set(state, Date.now());
  const authUrl = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  authUrl.searchParams.set("client_id", GOOGLE_CLIENT_ID);
  authUrl.searchParams.set("redirect_uri", GOOGLE_REDIRECT_URI);
  authUrl.searchParams.set("response_type", "code");
  authUrl.searchParams.set("scope", GOOGLE_DRIVE_SCOPES.join(" "));
  authUrl.searchParams.set("access_type", "offline");
  authUrl.searchParams.set("include_granted_scopes", "true");
  authUrl.searchParams.set("prompt", "consent");
  authUrl.searchParams.set("state", state);
  res.writeHead(302, { Location: authUrl.toString() });
  res.end();
}

async function handleGoogleDriveCallback(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const state = url.searchParams.get("state") || "";
  const code = url.searchParams.get("code") || "";
  const error = url.searchParams.get("error") || "";
  if (error) {
    res.writeHead(302, { Location: "/index.html?drive=error" });
    res.end();
    return;
  }
  if (!code || !oauthStates.has(state)) {
    res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Invalid Google OAuth callback");
    return;
  }
  oauthStates.delete(state);
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      redirect_uri: GOOGLE_REDIRECT_URI,
      grant_type: "authorization_code",
    }),
  });
  const tokenPayload = await tokenResponse.json();
  if (!tokenResponse.ok) {
    res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
    res.end(tokenPayload.error_description || tokenPayload.error || "Google token exchange failed");
    return;
  }
  const idTokenPayload = parseJwtPayload(tokenPayload.id_token || "");
  saveDriveAuthRecord({
    connected: true,
    email: idTokenPayload.email || "",
    scope: tokenPayload.scope || GOOGLE_DRIVE_SCOPES.join(" "),
    lastSyncedAt: new Date().toISOString(),
    tokens: {
      access_token: tokenPayload.access_token || "",
      refresh_token: tokenPayload.refresh_token || "",
      expiry_date: tokenPayload.expires_in ? Date.now() + Number(tokenPayload.expires_in) * 1000 : 0,
      token_type: tokenPayload.token_type || "Bearer",
    },
  });
  res.writeHead(302, { Location: "/index.html?drive=connected" });
  res.end();
}

function serveStatic(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === "/") pathname = "/index.html";
  const filePath = path.join(ROOT, pathname);
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }
  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found");
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, { "Content-Type": MIME_TYPES[ext] || "application/octet-stream" });
    res.end(data);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.url.startsWith("/auth/google-drive/start")) {
    handleGoogleDriveStart(req, res);
    return;
  }
  if (req.url.startsWith("/auth/google-drive/callback")) {
    await handleGoogleDriveCallback(req, res);
    return;
  }
  if (req.url.startsWith("/api/ocr")) {
    await handleOcr(req, res);
    return;
  }
  if (req.url.startsWith("/api/training-sample")) {
    await handleTrainingSample(req, res);
    return;
  }
  if (req.url.startsWith("/api/training-stats")) {
    await handleTrainingStats(req, res);
    return;
  }
  if (req.url.startsWith("/api/drive-auth-status")) {
    await handleGoogleDriveStatus(req, res);
    return;
  }
  if (req.url.startsWith("/api/drive-sync")) {
    await handleGoogleDriveSync(req, res);
    return;
  }
  if (req.url.startsWith("/api/drive-disconnect")) {
    await handleGoogleDriveDisconnect(req, res);
    return;
  }
  serveStatic(req, res);
});

server.listen(PORT, () => {
  console.log(`FinFlow server running at http://localhost:${PORT}`);
});
