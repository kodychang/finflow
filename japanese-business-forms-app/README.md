# Shoko Forms iOS

Shoko Forms is now maintained as a Capacitor iOS app. The repository keeps only the files needed to develop and package the iOS app.

## Kept Scope

- `ios/`: Xcode workspace, project settings, native app shell, Pods, and bundled public assets.
- `www/`: Capacitor web assets copied into the iOS app.
- `index.html`, `app.js`, `styles.css`, `fonts/`: source assets used by `npm run build` to refresh `www/`.
- `capacitor.config.json`, `package.json`, `package-lock.json`, `scripts/build-capacitor-web.js`: iOS build and sync tooling.

## Removed Scope

The standalone local web server and server-side PDF/upload runtime are no longer part of the project.

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
