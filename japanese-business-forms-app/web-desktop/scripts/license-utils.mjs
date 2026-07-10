import nacl from "tweetnacl";

export const LICENSE_PREFIX = "SHOKO-";

export function base64UrlEncode(bytes) {
  return Buffer.from(bytes)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

export function utf8Bytes(value) {
  return new TextEncoder().encode(value);
}

export function addMonths(date, months) {
  const next = new Date(date);
  const originalDay = next.getUTCDate();
  next.setUTCMonth(next.getUTCMonth() + months);
  if (next.getUTCDate() !== originalDay) {
    next.setUTCDate(0);
  }
  return next;
}

export function makeLicenseKey(payload, secretKeyBase64Url) {
  const payloadJson = JSON.stringify(payload);
  const payloadPart = base64UrlEncode(utf8Bytes(payloadJson));
  const secretKey = Buffer.from(secretKeyBase64Url.replace(/-/g, "+").replace(/_/g, "/"), "base64");
  const signature = nacl.sign.detached(utf8Bytes(payloadPart), secretKey);
  return `${LICENSE_PREFIX}${payloadPart}.${base64UrlEncode(signature)}`;
}

export function makeKeyPair() {
  const pair = nacl.sign.keyPair();
  return {
    publicKey: base64UrlEncode(pair.publicKey),
    secretKey: base64UrlEncode(pair.secretKey),
  };
}
