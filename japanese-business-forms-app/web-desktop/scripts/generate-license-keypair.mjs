import fs from "node:fs";
import path from "node:path";
import { makeKeyPair } from "./license-utils.mjs";

const root = process.cwd();
const keyDir = path.join(root, "license-keys");
const publicKeyFile = path.join(root, "src", "license-public-key.js");
const privateKeyFile = path.join(keyDir, "private-key.json");

if (fs.existsSync(privateKeyFile)) {
  throw new Error(`Private key already exists: ${privateKeyFile}`);
}

fs.mkdirSync(keyDir, { recursive: true });
const keyPair = makeKeyPair();
fs.writeFileSync(
  privateKeyFile,
  `${JSON.stringify(
    {
      algorithm: "ed25519",
      createdAt: new Date().toISOString(),
      publicKey: keyPair.publicKey,
      secretKey: keyPair.secretKey,
    },
    null,
    2,
  )}\n`,
);
fs.writeFileSync(publicKeyFile, `export const LICENSE_PUBLIC_KEY = "${keyPair.publicKey}";\n`);

console.log(`Public key written: ${publicKeyFile}`);
console.log(`Private key written: ${privateKeyFile}`);
console.log("Keep private-key.json secret. Use it only to generate customer license keys.");
