import nacl from "tweetnacl";
import { LICENSE_PUBLIC_KEY } from "./license-public-key";

const LICENSE_STORAGE_KEY = "shoko.forms.desktop.license.v1";
const LICENSE_PREFIX = "SHOKO-";
const TEXT_ENCODER = new TextEncoder();
const TEXT_DECODER = new TextDecoder();

export function loadStoredLicense() {
  return localStorage.getItem(LICENSE_STORAGE_KEY) ?? "";
}

export function clearStoredLicense() {
  localStorage.removeItem(LICENSE_STORAGE_KEY);
}

export function saveStoredLicense(licenseKey) {
  localStorage.setItem(LICENSE_STORAGE_KEY, licenseKey.trim());
}

export function isLicenseSystemConfigured() {
  return LICENSE_PUBLIC_KEY.trim().length > 0;
}

export function verifyLicenseKey(licenseKey, now = new Date()) {
  if (!isLicenseSystemConfigured()) {
    return {
      ok: false,
      reason: "尚未設定授權公鑰。請先執行 npm run license:keypair，並重新 build app。",
    };
  }

  const cleanKey = licenseKey.trim().replace(/\s+/g, "");
  if (!cleanKey.startsWith(LICENSE_PREFIX)) {
    return { ok: false, reason: "序號格式不正確。" };
  }

  const token = cleanKey.slice(LICENSE_PREFIX.length);
  const parts = token.split(".");
  if (parts.length !== 2) {
    return { ok: false, reason: "序號缺少簽章。" };
  }

  const [payloadPart, signaturePart] = parts;
  let payload;
  let signature;
  let publicKey;
  try {
    payload = JSON.parse(TEXT_DECODER.decode(base64UrlToBytes(payloadPart)));
    signature = base64UrlToBytes(signaturePart);
  } catch {
    return { ok: false, reason: "序號內容無法解析。" };
  }

  try {
    publicKey = base64UrlToBytes(LICENSE_PUBLIC_KEY);
  } catch {
    return { ok: false, reason: "app 內建公鑰格式不正確，請重新打包。" };
  }

  if (signature.length !== nacl.sign.signatureLength) {
    return { ok: false, reason: "序號簽章長度不正確。" };
  }

  if (publicKey.length !== nacl.sign.publicKeyLength) {
    return { ok: false, reason: "app 內建公鑰長度不正確，請重新打包。" };
  }

  const signedMessage = TEXT_ENCODER.encode(payloadPart);
  const validSignature = nacl.sign.detached.verify(signedMessage, signature, publicKey);
  if (!validSignature) {
    return { ok: false, reason: "序號簽章無效。" };
  }

  if (payload.app !== "shoko-forms-desktop") {
    return { ok: false, reason: "序號不是給這個桌面版 app 使用。" };
  }

  if (payload.v !== 1) {
    return { ok: false, reason: "不支援的序號版本。" };
  }

  const issuedAt = new Date(payload.issuedAt);
  const expiresAt = new Date(payload.expiresAt);
  const currentTime = now.getTime();
  if (Number.isNaN(issuedAt.getTime()) || Number.isNaN(expiresAt.getTime())) {
    return { ok: false, reason: "序號日期不正確。" };
  }

  const clockSkewMs = 24 * 60 * 60 * 1000;
  if (currentTime + clockSkewMs < issuedAt.getTime()) {
    return { ok: false, reason: "序號尚未生效。" };
  }

  if (currentTime > expiresAt.getTime()) {
    return { ok: false, reason: "序號已到期。" };
  }

  return {
    ok: true,
    license: payload,
    expiresAt,
    daysRemaining: Math.max(0, Math.ceil((expiresAt.getTime() - currentTime) / clockSkewMs)),
  };
}

export function formatLicenseDate(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return new Intl.DateTimeFormat("zh-Hant", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function base64UrlToBytes(value) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}
