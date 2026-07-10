# Shoko Forms Android

Native Android port of the iOS SwiftUI app.

## Build

Open this `android/` folder in Android Studio, or build from a shell with:

```sh
ANDROID_HOME=/Users/kody/Library/Android/sdk ./gradlew assembleDebug
```

If Gradle is not installed globally, Android Studio can create/use its bundled Gradle runtime.

## Implemented

- Japanese, Simplified Chinese, and English UI/PDF language switching.
- Customer and vendor form workflows for quotes, orders, delivery notes, invoices, receipts, acceptance receipts, vendor records, and payment notices.
- Local document, project, customer, issuer, product, and text-template storage.
- Form editing with basic information, parties, issuer data, line items, notes, payment details, attachments, and payment proof.
- Project grouping and per-project document creation.
- PDF preview, PDF export, JSON backup import/export, and single-form import.
- Dark mode and form color templates.

Google Play Billing and Google Drive API credentials are intentionally left as integration hooks because Android requires separate product IDs and OAuth client configuration from the iOS StoreKit/GoogleSignIn setup.
