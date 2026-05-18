# Shoko Forms iOS

Shoko Forms is now maintained as a Capacitor iOS app. The repository keeps only the files needed to develop and package the iOS app.

## Kept Scope

- `ios/`: Xcode workspace, project settings, native app shell, Pods, and bundled public assets.
- `www/`: Capacitor web assets copied into the iOS app.
- `index.html`, `app.js`, `styles.css`, `fonts/`: source assets used by `npm run build` to refresh `www/`.
- `desktop/`, `local-sync-server.js`: local same-Wi-Fi desktop HTML editor and sync API.
- `capacitor.config.json`, `package.json`, `package-lock.json`, `scripts/build-capacitor-web.js`: iOS build and sync tooling.

## Removed Scope

The old server-side PDF/upload runtime is no longer part of the project.

PDF preview/save now uses the app's in-app preview and the iOS/browser print or share flow. Attachments are read locally into app data instead of being uploaded to a local server.

## iOS Development

```bash
cd /Volumes/AI/codex/japanese-business-forms-app
npm install
npm run cap:sync
npm run ios
```

- App ID: `com.shoko.forms`
- App name: `Shoko Forms`
- Web assets are generated into `www/` with `npm run build`, then copied into the iOS project with `npm run cap:sync`.

## Same-Wi-Fi Desktop Sync

Run the local desktop editor from the Mac:

```bash
npm run serve:sync
```

- Open the desktop form on the Mac at `http://localhost:4180`.
- The terminal also prints a LAN URL such as `http://192.168.1.20:4180`.
- On the iPhone, keep the device on the same Wi-Fi, open `設定・アカウント管理`, paste that LAN URL into `同一Wi-Fi同步`, set the `點單密碼`, then choose app-to-local sync. The first password-protected sync registers that password on the local desktop server.
- In a desktop browser, open the LAN URL or `http://localhost:4180`, enter only the `點單密碼`, then use the form editor.
- The desktop page shows generated localhost/LAN URLs as clickable links and provides a share button that shares or copies the LAN URL.
- Data is stored locally at `.sync/shoko-sync.shokobackup`.
