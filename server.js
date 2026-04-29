const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const PORT = Number(process.env.PORT || 4173);
const ROOT = __dirname;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";
const OPENAI_MODEL = process.env.OPENAI_OCR_MODEL || "gpt-4.1-mini";
const OCR_MAX_BYTES = Number(process.env.OCR_MAX_BYTES || 8 * 1024 * 1024);
const OCR_MAX_RETRIES = Number(process.env.OCR_MAX_RETRIES || 2);
const OCR_CACHE_PATH = path.join(ROOT, "data", "ocr_cache.json");
const TRAINING_JSONL_PATH = path.join(ROOT, "data", "paddle_ocr_training.jsonl");
const TRAINING_META_PATH = path.join(ROOT, "data", "training_samples.ndjson");

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
      const rawText = payload.output_text || "";
      return JSON.parse(rawText);
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
    "For bank statements or credit card statements, extract the main account institution or statement issuer into vendor, and summarize visible transaction context.",
    `Language hint: ${languageHint || "ja"}.`,
    `Original file name: ${fileName}.`,
    `Input type: ${isPdf ? "pdf" : "image"}.`,
    'JSON schema: {"document_type":"","owner_type":"","transaction_type":"","date":"","issue_date":"","due_date":"","amount":0,"tax_amount":0,"tax_rate":"","vendor":"","invoice_number":"","category":"","payment_method":"","summary":"","ocr_text":"","confidence":0,"need_review":true}',
  ].join("\n");
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
    },
  });
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
    const rawBase64 = dataUrl.split(",")[1] || "";
    const bytes = Buffer.byteLength(rawBase64, "base64");
    if (bytes > OCR_MAX_BYTES) {
      sendJson(res, 413, { error: `File too large for OCR. Limit is ${OCR_MAX_BYTES} bytes.` });
      return;
    }
    const cacheKey = sourceHash || sha256(`${fileName}:${rawBase64.slice(0, 2000)}`);
    const cache = safeReadJson(OCR_CACHE_PATH, {});
    if (cache[cacheKey]) {
      sendJson(res, 200, { ok: true, document: { ...cache[cacheKey], id: `doc-${Date.now()}-${Math.round(Math.random() * 9999)}` }, cached: true });
      return;
    }

    const ocr = await callOpenAIForOcr({ fileName, dataUrl, languageHint: language });
    const extension = path.extname(fileName).replace(".", "") || "jpg";
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
  if (req.url.startsWith("/api/ocr")) {
    await handleOcr(req, res);
    return;
  }
  if (req.url.startsWith("/api/training-sample")) {
    await handleTrainingSample(req, res);
    return;
  }
  serveStatic(req, res);
});

server.listen(PORT, () => {
  console.log(`FinFlow server running at http://localhost:${PORT}`);
});
