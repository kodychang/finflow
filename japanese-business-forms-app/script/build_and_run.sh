#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/ios/App/App.xcodeproj"
SCHEME="App"
DERIVED_DATA="$ROOT_DIR/.xcode-derived-mac"
APP_NAME="App"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug-maccatalyst/$APP_NAME.app"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Select full Xcode with: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS,variant=Mac Catalyst" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Expected app bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

open -n "$APP_BUNDLE"

if [[ "${1:-}" == "--verify" ]]; then
  sleep 2
  pgrep -x "$APP_NAME" >/dev/null
  echo "$APP_NAME is running."
fi
