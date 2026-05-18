const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "www");
const entries = [
  "index.html",
  "app.js",
  "styles.css",
  "fonts",
  "vendor",
];

function copyRecursive(source, destination) {
  const stat = fs.statSync(source);
  if (stat.isDirectory()) {
    fs.mkdirSync(destination, { recursive: true });
    fs.readdirSync(source).forEach((entry) => {
      copyRecursive(path.join(source, entry), path.join(destination, entry));
    });
    return;
  }
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination);
}

fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(outDir, { recursive: true });

entries.forEach((entry) => {
  copyRecursive(path.join(root, entry), path.join(outDir, entry));
});

console.log(`Built Capacitor web assets in ${path.relative(root, outDir)}`);
