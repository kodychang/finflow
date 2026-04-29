const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const PORT = Number(process.env.PORT || 4173);
const ROOT = __dirname;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";
const OPENAI_MODEL = process.env.OPENAI_OCR_MODEL || "gpt-4.1-mini";

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
  const prompt = [
    "You are extracting structured OCR data for Japanese SME bookkeeping and tax workflows.",
    "Return JSON only. No markdown.",
    "If a field is unknown, use empty string for text fields, 0 for numeric amounts, false for booleans.",
    "Use one of document_type: receipt, invoice, contract, bank_statement, tax_document, other.",
    "Use one of owner_type: company, personal.",
    "Use one of transaction_type: income, expense, other.",
    "Prefer Japanese accounting categories such as 売上, 広告宣伝費, 交通費, 通信費, 接待交際費, 消耗品費, 外注費, 家賃, 水道光熱費, 雑費, 税金, 契約書, 銀行明細.",
    `Language hint: ${languageHint || "ja"}.`,
    `Original file name: ${fileName}.`,
    'JSON schema: {"document_type":"","owner_type":"","transaction_type":"","date":"","issue_date":"","due_date":"","amount":0,"tax_amount":0,"tax_rate":"","vendor":"","invoice_number":"","category":"","payment_method":"","summary":"","ocr_text":"","confidence":0,"need_review":true}',
  ].join("\n");

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      input: [
        {
          role: "user",
          content: [
            { type: "input_text", text: prompt },
            { type: "input_image", image_url: dataUrl },
          ],
        },
      ],
      max_output_tokens: 1400,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error ${response.status}: ${errorText}`);
  }

  const payload = await response.json();
  const rawText = payload.output_text || "";
  const parsed = JSON.parse(rawText);
  return parsed;
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
    const { fileName = "upload.jpg", dataUrl = "", language = "ja" } = payload;
    if (!dataUrl.startsWith("data:")) {
      sendJson(res, 400, { error: "dataUrl is required" });
      return;
    }

    const ocr = await callOpenAIForOcr({ fileName, dataUrl, languageHint: language });
    const extension = path.extname(fileName).replace(".", "") || "jpg";
    const normalized = {
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
      review_notes: "Gemini/GPT 系の vision OCR で抽出。確認後の修正データは将来の PaddleOCR 学習候補として保存します。",
      ocr_text: ocr.ocr_text || "",
      hash: `sha256:${fileName.length}-${Date.now()}`,
      language,
      ocr_engine: `openai:${OPENAI_MODEL}`,
    };

    sendJson(res, 200, { ok: true, document: normalized });
  } catch (error) {
    sendJson(res, 500, { error: error.message || "OCR failed" });
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
  serveStatic(req, res);
});

server.listen(PORT, () => {
  console.log(`FinFlow server running at http://localhost:${PORT}`);
});
