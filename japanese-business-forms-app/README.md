# Shoko Forms iPhone App

Shoko Forms is a native SwiftUI iPhone app for creating and managing Japanese business forms.

## Scope

- `ios/App/App/Native/`: SwiftUI screens, models, local document storage, PDF export, purchases, and stamp tools.
- `ios/App/App/Assets.xcassets/`: App icon and launch assets.
- `ios/App/App/Info.plist`: iPhone app metadata, document type registration, and local permissions.
- `app-store-assets/ja-JP/`: Japanese App Store metadata and exported iPhone promotional screenshots.

The repository now keeps only the native iPhone app and App Store submission assets.

## Build

Open `ios/App/App.xcodeproj` in Xcode and build the `App` target.

The target is configured for iPhone only.
