const http = require("node:http");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");

const PORT = Number(process.env.PORT || 4180);
const ROOT = __dirname;
const DESKTOP_DIR = path.join(ROOT, "desktop");
const DATA_DIR = path.join(ROOT, ".sync");
const DATA_FILE = path.join(DATA_DIR, "shoko-sync.shokobackup");
const PASSWORD_FILE = path.join(DATA_DIR, "order-password.json");
const SESSION_TTL_MS = 12 * 60 * 60 * 1000;
const sessions = new Map();

fs.mkdirSync(DATA_DIR, { recursive: true });

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

function nowIso() {
  return new Date().toISOString();
}

function emptyBackup() {
  return {
    version: 1,
    exportedAt: nowIso(),
    documents: [],
    customers: [],
    issuers: [],
    products: [],
    draft: null,
  };
}

function readBackup() {
  if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify(emptyBackup(), null, 2));
  }
  return JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
}

function readPassword() {
  const envPassword = process.env.SHOKO_ORDER_PASSWORD || process.env.ORDER_PASSWORD || "";
  if (envPassword) return envPassword;
  if (!fs.existsSync(PASSWORD_FILE)) return "";
  try {
    const config = JSON.parse(fs.readFileSync(PASSWORD_FILE, "utf8"));
    return typeof config.password === "string" ? config.password : "";
  } catch {
    return "";
  }
}

function writePassword(password) {
  fs.writeFileSync(PASSWORD_FILE, JSON.stringify({ password, updatedAt: nowIso() }, null, 2));
}

function hasPassword() {
  return readPassword().trim().length > 0;
}

function createSession() {
  const token = cryptoRandomToken();
  sessions.set(token, Date.now() + SESSION_TTL_MS);
  return token;
}

function cryptoRandomToken() {
  return [...crypto.randomBytes(24)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function cleanSessions() {
  const now = Date.now();
  for (const [token, expiresAt] of sessions.entries()) {
    if (expiresAt <= now) sessions.delete(token);
  }
}

function requestPassword(req) {
  return req.headers["x-shoko-order-password"] || req.headers["x-order-password"] || "";
}

function isAuthenticated(req) {
  if (!hasPassword()) return true;
  const password = readPassword();
  if (requestPassword(req) === password) return true;
  cleanSessions();
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  return Boolean(token && sessions.get(token) > Date.now());
}

function requireAuth(req, res) {
  if (isAuthenticated(req)) return true;
  sendJson(res, 401, { error: "Order password required" });
  return false;
}

function writeBackup(payload) {
  const backup = {
    ...emptyBackup(),
    ...payload,
    exportedAt: nowIso(),
    documents: Array.isArray(payload.documents) ? payload.documents : [],
    customers: Array.isArray(payload.customers) ? payload.customers : [],
    issuers: Array.isArray(payload.issuers) ? payload.issuers : [],
    products: Array.isArray(payload.products) ? payload.products : [],
    draft: payload.draft || null,
  };
  fs.writeFileSync(DATA_FILE, JSON.stringify(backup, null, 2));
  return backup;
}

function localAddresses() {
  const addresses = [];
  Object.values(os.networkInterfaces()).flat().forEach((entry) => {
    if (entry && entry.family === "IPv4" && !entry.internal) {
      addresses.push(`http://${entry.address}:${PORT}`);
    }
  });
  return addresses;
}

function send(res, status, body, type = "text/plain; charset=utf-8") {
  res.writeHead(status, {
    "content-type": type,
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,PUT,OPTIONS",
    "access-control-allow-headers": "content-type, authorization, x-shoko-order-password, x-order-password",
    "cache-control": "no-store",
  });
  res.end(body);
}

function sendJson(res, status, payload) {
  send(res, status, JSON.stringify(payload), "application/json; charset=utf-8");
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    req.on("data", (chunk) => {
      total += chunk.length;
      if (total > 20 * 1024 * 1024) {
        reject(new Error("Request body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function serveFile(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  const pathname = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname);
  const safePath = path.normalize(path.join(DESKTOP_DIR, pathname));
  if (!safePath.startsWith(DESKTOP_DIR)) {
    send(res, 403, "Forbidden");
    return;
  }
  fs.readFile(safePath, (error, data) => {
    if (error) {
      send(res, 404, "Not found");
      return;
    }
    send(res, 200, data, MIME[path.extname(safePath)] || "application/octet-stream");
  });
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    send(res, 204, "");
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

  try {
    if (url.pathname === "/api/info" && req.method === "GET") {
      sendJson(res, 200, {
        name: "Shoko Forms Local Sync",
        port: PORT,
        urls: [`http://localhost:${PORT}`, ...localAddresses()],
        passwordRequired: hasPassword(),
        dataFile: DATA_FILE,
      });
      return;
    }

    if (url.pathname === "/api/session" && req.method === "POST") {
      const body = await readBody(req);
      const payload = body ? JSON.parse(body) : {};
      const password = readPassword();
      if (!password || payload.password === password) {
        sendJson(res, 200, { token: createSession(), passwordRequired: Boolean(password) });
      } else {
        sendJson(res, 401, { error: "點單密碼不正確" });
      }
      return;
    }

    if (url.pathname === "/api/password" && req.method === "PUT") {
      if (hasPassword() && !isAuthenticated(req)) {
        sendJson(res, 401, { error: "Current order password required" });
        return;
      }
      const body = await readBody(req);
      const payload = body ? JSON.parse(body) : {};
      writePassword(String(payload.password || "").trim());
      sendJson(res, 200, { passwordRequired: hasPassword() });
      return;
    }

    if (url.pathname === "/api/backup" && req.method === "GET") {
      if (!requireAuth(req, res)) return;
      sendJson(res, 200, readBackup());
      return;
    }

    if (url.pathname === "/api/backup" && (req.method === "POST" || req.method === "PUT")) {
      if (!requireAuth(req, res)) return;
      if (!hasPassword() && requestPassword(req)) {
        writePassword(String(requestPassword(req)).trim());
      }
      const body = await readBody(req);
      const payload = body ? JSON.parse(body) : emptyBackup();
      sendJson(res, 200, writeBackup(payload));
      return;
    }

    serveFile(req, res);
  } catch (error) {
    sendJson(res, 500, { error: error.message || "Server error" });
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Shoko Forms local sync running on http://localhost:${PORT}`);
  localAddresses().forEach((url) => console.log(`LAN: ${url}`));
});
