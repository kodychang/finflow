# Shoko Forms Desktop

Tauri + React desktop version for reading, editing, and exporting Shoko Forms iOS backup files.

## User Guide

- [繁體中文完整功能教程](docs/user-guide-zh-Hant.md)

## What It Does

- Reads `.shokobackup` files exported by the iOS app.
- Creates a local app data folder on first launch.
- Saves the current working copy to `state.json`.
- Exports iOS-compatible `.shokobackup` JSON files.
- Keeps exported copies in a local backup history folder.

The backup format intentionally matches the iOS app's `LocalBackup` JSON structure:

```json
{
  "version": 1,
  "exportedAt": "2026-05-24T00:00:00Z",
  "documents": [],
  "customers": [],
  "issuers": [],
  "products": [],
  "draft": null,
  "textTemplates": []
}
```

## Local Folder Layout

Tauri resolves the app data folder per platform.

Windows:

```text
C:\Users\<user>\AppData\Roaming\com.shoko.forms.desktop\
```

macOS:

```text
~/Library/Application Support/com.shoko.forms.desktop/
```

The app creates:

```text
backups/
imports/
exports/
temp/
state.json
```

## Development

Install JavaScript dependencies:

```bash
npm install
```

Run the web UI only:

```bash
npm run dev
```

Run as a Tauri desktop app:

```bash
npm run tauri:dev
```

## Build Installers

Tauri requires Rust. Install Rust first:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Then build:

```bash
npm run tauri:build
```

Build outputs are written under:

```text
src-tauri/target/release/bundle/
```

For Windows installers, run the build on Windows. For macOS `.app`/`.dmg`, run the build on macOS.

## iOS Sharing Flow

1. Export from this desktop app.
2. Send the generated `.shokobackup` to iPhone via AirDrop, iCloud Drive, email, or another file-sharing channel.
3. Open the file with the iOS Shoko Forms app.
4. Choose merge or replace in the iOS app.

## License Keys

This desktop app uses offline Ed25519-signed license keys.

- The app embeds only the public key in `src/license-public-key.js`.
- Your private key stays in `license-keys/private-key.json`.
- `license-keys/` is ignored by git and should not be shared with customers.
- Each generated license includes customer data, duration, issue date, expiry date, license ID, and a random nonce.

Create the signing key pair once:

```bash
npm run license:keypair
```

Generate one 3-month customer license:

```bash
npm run license:generate -- --customer "Customer A" --email customer@example.com --months 3
```

Generate one 6-month customer license:

```bash
npm run license:generate -- --customer "Customer B" --months 6
```

Generate one 12-month customer license:

```bash
npm run license:generate -- --customer "Customer C" --months 12
```

Generate many licenses at once and write them to a file:

```bash
npm run license:generate -- --customer "Distributor Batch" --months 6 --quantity 100 --out license-keys/batch-6-month.txt
```

The output license starts with `SHOKO-`. Send that full string to the customer. The customer enters it on the activation screen in the desktop app.

You can also use the local HTML generator:

```text
tools/license-generator.html
```

Open it in a browser, load or paste `license-keys/private-key.json`, choose the license duration, then generate TXT or CSV output. The HTML version uses the same license format as the CLI generator.

If you regenerate the key pair, old customer license keys will stop validating unless you keep the same public key in the app.
