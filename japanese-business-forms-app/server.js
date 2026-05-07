const http = require("node:http");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const PORT = Number(process.env.PORT || 4180);
const ROOT = __dirname;
const PDF_CACHE_TTL = 24 * 60 * 60 * 1000;
const PDF_CACHE_DIR = path.join(ROOT, ".pdf-cache");
const pdfCache = new Map();
fs.mkdirSync(PDF_CACHE_DIR, { recursive: true });

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ttf": "font/ttf",
};

function send(res, status, body, type = "text/plain; charset=utf-8") {
  res.writeHead(status, {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type",
    "content-type": type,
    "cache-control": "no-store",
  });
  res.end(body);
}

function readRequestBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => {
      chunks.push(chunk);
      if (Buffer.concat(chunks).length > 8 * 1024 * 1024) {
        reject(new Error("Request body too large"));
        req.destroy();
      }
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function pdfShell({ title, html, accent }) {
  const css = fs.readFileSync(path.join(ROOT, "styles.css"), "utf8")
    .replace(
      /\.preview-seal-slot\s*\{[\s\S]*?\.doc-topline\s*\{/m,
      `.preview-seal-slot {
  position: absolute;
  right: 0;
  bottom: 0;
  z-index: 40;
  pointer-events: none;
}

.doc-topline {`,
    );
  const fontUrl = (filename) => pathToFileURL(path.join(ROOT, "fonts", filename)).href;
  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(title || "document")}</title>
  <style>${css}</style>
  <style>
    @page { size: A4; margin: 0; }
    html, body { width: 210mm; min-height: 297mm; margin: 0; background: #fff; }
    body { font-family: Inter, "Hiragino Sans", "Yu Gothic UI", "Yu Gothic", Meiryo, sans-serif; }
    @font-face { font-family: "Noto Serif JP"; src: url("${fontUrl("noto-serif-jp-700.ttf")}") format("truetype"); font-weight: 700; font-style: normal; }
    @font-face { font-family: "Noto Serif JP"; src: url("${fontUrl("noto-serif-jp-900.ttf")}") format("truetype"); font-weight: 900; font-style: normal; }
    @font-face { font-family: "Shippori Mincho"; src: url("${fontUrl("shippori-mincho-700.ttf")}") format("truetype"); font-weight: 700; font-style: normal; }
    @font-face { font-family: "Yuji Syuku"; src: url("${fontUrl("yuji-syuku-400.ttf")}") format("truetype"); font-weight: 400; font-style: normal; }
    .document-preview, .document-preview.zoom-100 {
      width: 210mm !important;
      min-height: 297mm;
      margin: 0 !important;
      padding: 0 !important;
      overflow: hidden !important;
      box-shadow: none !important;
      --template-accent: ${accent || "#2f3744"};
    }
    .document-safe-area {
      max-width: 186mm !important;
      min-height: 269mm !important;
      padding: 14mm 12mm !important;
      overflow: hidden !important;
    }
    .doc-topline { margin: -14mm -12mm 24px !important; }
    .inkantan-seal {
      background-image: none !important;
      box-shadow: none !important;
      contain: none !important;
      display: inline-flex !important;
      align-items: center !important;
      justify-content: center !important;
      overflow: hidden !important;
      position: relative !important;
    }
    .inkantan-seal::before,
    .inkantan-seal::after {
      display: none !important;
      content: none !important;
    }
    .inkantan-seal span {
      display: grid !important;
      width: 62% !important;
      height: 62% !important;
      align-items: center !important;
      justify-items: center !important;
      overflow: hidden !important;
      padding: 0 !important;
      gap: 1px !important;
    }
    .inkantan-seal span[data-flow="column"] {
      grid-auto-flow: column !important;
    }
    .inkantan-seal i {
      display: block !important;
      width: 100% !important;
      height: 100% !important;
      overflow: hidden !important;
      text-align: center !important;
      line-height: 1 !important;
      font-style: normal !important;
    }
    .invoice-check { display: none !important; }
  </style>
</head>
<body>${html}</body>
</html>`;
}

function renderPdfBuffer(payload) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "shoko-pdf-"));
  const htmlPath = path.join(tmpDir, "document.html");
  const pdfPath = path.join(tmpDir, "document.pdf");
  fs.writeFileSync(htmlPath, pdfShell(payload), "utf8");

  const python = path.join(ROOT, ".venv", "bin", "python");
  const command = fs.existsSync(python) ? python : "python3";
  const libraryPath = ["/opt/homebrew/lib", "/usr/local/lib", process.env.DYLD_FALLBACK_LIBRARY_PATH].filter(Boolean).join(":");

  return new Promise((resolve, reject) => {
    const child = spawn(command, ["-m", "weasyprint", htmlPath, pdfPath], {
      cwd: ROOT,
      env: {
        ...process.env,
        DYLD_FALLBACK_LIBRARY_PATH: libraryPath,
      },
    });
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("close", (code) => {
      if (code !== 0) {
        fs.rm(tmpDir, { recursive: true, force: true }, () => {});
        reject(new Error(`PDF generation failed.\n${stderr || "Install WeasyPrint first."}`));
        return;
      }
      fs.readFile(pdfPath, (error, data) => {
        fs.rm(tmpDir, { recursive: true, force: true }, () => {});
        if (error) {
          reject(new Error("PDF file was not created."));
          return;
        }
        resolve(data);
      });
    });
  });
}

function pdfFilename(payload) {
  return String(payload.filename || "document.pdf").replace(/[\\/\0\r\n]/g, "_");
}

function pdfCacheFilePath(id, filename) {
  const safeId = String(id || "").replace(/[^a-z0-9-]/gi, "");
  const safeFilename = String(filename || "document.pdf").replace(/[\\/\0\r\n]/g, "_");
  return path.join(PDF_CACHE_DIR, safeId, safeFilename);
}

function getCachedPdf(id, filename = "") {
  const cached = pdfCache.get(id);
  if (cached?.filePath && fs.existsSync(cached.filePath)) return cached;
  const safeId = String(id || "").replace(/[^a-z0-9-]/gi, "");
  const dir = path.join(PDF_CACHE_DIR, safeId);
  if (!safeId || !fs.existsSync(dir)) return null;
  const safeFilename = String(filename || "").replace(/[\\/\0\r\n]/g, "_");
  const files = fs.readdirSync(dir).filter((item) => item.toLowerCase().endsWith(".pdf"));
  const match = files.find((item) => item === safeFilename) || files[0];
  if (!match) return null;
  const filePath = path.join(dir, match);
  const restored = { filename: match, filePath, createdAt: fs.statSync(filePath).mtimeMs };
  pdfCache.set(id, restored);
  return restored;
}

function sendPdf(res, data, filename, disposition = "inline") {
  const safeFilename = String(filename || "document.pdf").replace(/[\\"]/g, "_");
  const asciiFilename = safeFilename.replace(/[^\x20-\x7e]/g, "_");
  const encodedFilename = encodeURIComponent(safeFilename);
  res.writeHead(200, {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type",
    "content-type": "application/pdf",
    "content-length": data.length,
    "content-disposition": `${disposition}; filename="${asciiFilename}"; filename*=UTF-8''${encodedFilename}`,
    "cache-control": "no-store",
  });
  res.end(data);
}

function sendPdfPrintPage(req, res, id, cached) {
  const filename = encodeURIComponent(cached.filename);
  const pdfUrl = `/api/pdf-file/${encodeURIComponent(id)}/${filename}?inline=1`;
  const downloadUrl = `/api/pdf-file/${encodeURIComponent(id)}/${filename}`;
  send(res, 200, `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(cached.filename)} 印刷</title>
  <style>
    html, body { margin: 0; min-height: 100%; background: #eef1f4; color: #172026; font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Yu Gothic", Meiryo, sans-serif; }
    .print-shell { max-width: 760px; margin: 72px auto; padding: 28px; background: #fff; border: 1px solid #d7dde3; box-shadow: 0 16px 40px rgba(26,39,52,.12); }
    h1 { margin: 0 0 8px; font-size: 24px; }
    p { margin: 0 0 20px; color: #66717b; line-height: 1.7; }
    .actions { display: flex; flex-wrap: wrap; gap: 10px; }
    button, a.button { display: inline-flex; align-items: center; justify-content: center; min-height: 40px; padding: 0 16px; border: 1px solid #d7dde3; background: #fff; color: #172026; font: inherit; text-decoration: none; cursor: pointer; }
    .primary { border-color: #0d6b68; background: #0d6b68; color: #fff; }
    .file-name { margin-top: 18px; padding: 12px; background: #f7f9fb; font-weight: 700; overflow-wrap: anywhere; }
    iframe { position: fixed; width: 1px; height: 1px; left: -10px; bottom: -10px; border: 0; opacity: 0; pointer-events: none; }
  </style>
</head>
<body>
  <div class="print-shell">
    <h1>PDF 印刷 / ダウンロード</h1>
    <p>黒いPDFビューアを表示しないように、PDFは別ウィンドウまたは直接ダウンロードで開きます。</p>
    <div class="actions">
      <button class="primary" type="button" onclick="startPrint()">印刷画面を開く</button>
      <a class="button" id="openPdfLink" target="_blank" rel="noopener">PDFを開く</a>
      <a class="button" id="downloadPdfLink">ダウンロード</a>
    </div>
    <div class="file-name">${escapeHtml(cached.filename)}</div>
  </div>
  <iframe id="pdfFrame" title="PDF印刷"></iframe>
  <script>
    var pdfUrl = ${JSON.stringify(pdfUrl)};
    var downloadUrl = ${JSON.stringify(downloadUrl)};
    document.getElementById("openPdfLink").href = pdfUrl;
    document.getElementById("downloadPdfLink").href = downloadUrl;
    function openPdf() {
      var opened = window.open(pdfUrl, "_blank", "noopener");
      if (!opened) window.location.href = pdfUrl;
    }
    function startPrint() {
      var frame = document.getElementById("pdfFrame");
      var fallbackTimer = window.setTimeout(openPdf, 1800);
      frame.onload = function () {
        try {
          window.clearTimeout(fallbackTimer);
          frame.contentWindow.focus();
          frame.contentWindow.print();
        } catch (error) {
          openPdf();
        }
      };
      try {
        frame.src = pdfUrl;
      } catch (error) {
        window.clearTimeout(fallbackTimer);
        openPdf();
      }
    }
  </script>
</body>
</html>`, "text/html; charset=utf-8");
}

async function renderPdf(payload, res) {
  try {
    const data = await renderPdfBuffer(payload);
    sendPdf(res, data, pdfFilename(payload), "inline");
  } catch (error) {
    send(res, 500, error.message || "PDF generation failed.");
  }
}

async function createCachedPdf(payload, req, res) {
  try {
    const data = await renderPdfBuffer(payload);
    const id = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
    const filename = pdfFilename(payload);
    const filePath = pdfCacheFilePath(id, filename);
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, data);
    pdfCache.set(id, { data, filename, filePath, createdAt: Date.now() });
    setTimeout(() => {
      pdfCache.delete(id);
      fs.rm(path.dirname(filePath), { recursive: true, force: true }, () => {});
    }, PDF_CACHE_TTL).unref?.();
    const baseUrl = `http://${req.headers.host}`;
    send(res, 200, JSON.stringify({
      id,
      filename,
      downloadUrl: `${baseUrl}/api/pdf-file/${id}/${encodeURIComponent(filename)}`,
      inlineUrl: `${baseUrl}/api/pdf-file/${id}/${encodeURIComponent(filename)}?inline=1`,
      printUrl: `${baseUrl}/api/pdf-print/${id}/${encodeURIComponent(filename)}`,
    }), "application/json; charset=utf-8");
  } catch (error) {
    send(res, 500, error.message || "PDF generation failed.");
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (req.method === "OPTIONS") {
    send(res, 204, "");
    return;
  }

  if (req.method === "POST" && (url.pathname === "/api/pdf" || url.pathname === "/api/pdf-file")) {
    try {
      const body = await readRequestBody(req);
      const contentType = req.headers["content-type"] || "";
      const payload = contentType.includes("application/json")
        ? JSON.parse(body || "{}")
        : Object.fromEntries(new URLSearchParams(body));
      if (!payload.html) {
        send(res, 400, "Missing HTML payload.");
        return;
      }
      if (url.pathname === "/api/pdf-file") {
        await createCachedPdf(payload, req, res);
      } else {
        await renderPdf(payload, res);
      }
    } catch (error) {
      send(res, 400, error.message || "Invalid PDF request.");
    }
    return;
  }

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname.startsWith("/api/pdf-file/")) {
    const id = decodeURIComponent(url.pathname.split("/")[3] || "");
    const filename = decodeURIComponent(url.pathname.split("/").slice(4).join("/") || "");
    const cached = getCachedPdf(id, filename);
    if (!cached) {
      send(res, 404, "PDF file expired. Please generate it again.");
      return;
    }
    const disposition = url.searchParams.get("inline") === "1" ? "inline" : "attachment";
    const data = cached.data || fs.readFileSync(cached.filePath);
    sendPdf(res, data, cached.filename, disposition);
    return;
  }

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname.startsWith("/api/pdf-print/")) {
    const id = decodeURIComponent(url.pathname.split("/")[3] || "");
    const filename = decodeURIComponent(url.pathname.split("/").slice(4).join("/") || "");
    const cached = getCachedPdf(id, filename);
    if (!cached) {
      send(res, 404, "PDF file expired. Please generate it again.");
      return;
    }
    sendPdfPrintPage(req, res, id, cached);
    return;
  }

  const pathname = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname);
  const filePath = path.normalize(path.join(ROOT, pathname));

  if (!filePath.startsWith(ROOT)) {
    send(res, 403, "Forbidden");
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      send(res, 404, "Not found");
      return;
    }
    send(res, 200, data, MIME[path.extname(filePath)] || "application/octet-stream");
  });
});

server.listen(PORT, () => {
  console.log(`Shoko Forms running at http://localhost:${PORT}`);
});
