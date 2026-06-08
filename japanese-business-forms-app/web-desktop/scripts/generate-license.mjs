import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { addMonths, makeLicenseKey } from "./license-utils.mjs";

const args = parseArgs(process.argv.slice(2));
const months = Number(args.months ?? args.m);
const customer = args.customer ?? args.c;
const email = args.email ?? "";
const plan = args.plan ?? `${months}-month`;
const quantity = Number(args.quantity ?? args.q ?? 1);

if (!Number.isInteger(months) || months < 1 || months > 60) {
  throw new Error("Use --months with an integer between 1 and 60. Examples: 3, 6, 12.");
}

if (!customer) {
  throw new Error("Use --customer to identify the buyer or company.");
}

if (!Number.isInteger(quantity) || quantity < 1 || quantity > 500) {
  throw new Error("Use --quantity with an integer between 1 and 500.");
}

const privateKeyPath = args.key
  ? path.resolve(args.key)
  : path.join(process.cwd(), "license-keys", "private-key.json");
const key = JSON.parse(fs.readFileSync(privateKeyPath, "utf8"));

const issuedAt = args.issuedAt ? new Date(args.issuedAt) : new Date();
if (Number.isNaN(issuedAt.getTime())) {
  throw new Error("--issuedAt must be a valid date.");
}

const rows = [];
for (let index = 0; index < quantity; index += 1) {
  const payload = {
    v: 1,
    app: "shoko-forms-desktop",
    customer,
    email,
    plan,
    durationMonths: months,
    issuedAt: issuedAt.toISOString(),
    expiresAt: addMonths(issuedAt, months).toISOString(),
    licenseId: crypto.randomUUID(),
    nonce: crypto.randomBytes(12).toString("hex"),
  };
  rows.push({
    customer,
    email,
    months,
    licenseId: payload.licenseId,
    expiresAt: payload.expiresAt,
    licenseKey: makeLicenseKey(payload, key.secretKey),
  });
}

const outputPath = args.out ? path.resolve(args.out) : "";
const text = rows
  .map((row) => [
    `Customer: ${row.customer}`,
    row.email ? `Email: ${row.email}` : "",
    `Months: ${row.months}`,
    `License ID: ${row.licenseId}`,
    `Expires At: ${row.expiresAt}`,
    `License Key: ${row.licenseKey}`,
  ].filter(Boolean).join("\n"))
  .join("\n\n");

if (outputPath) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${text}\n`);
  console.log(`Wrote ${rows.length} license key(s): ${outputPath}`);
} else {
  console.log(text);
}

function parseArgs(values) {
  const parsed = {};
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (!value.startsWith("--")) continue;
    const key = value.slice(2);
    const next = values[index + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      index += 1;
    }
  }
  return parsed;
}
