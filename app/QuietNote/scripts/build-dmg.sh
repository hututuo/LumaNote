#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT/support/Info.plist")"
APP_DIR="$ROOT/build/LumaNote.app"
DMG_DIR="$ROOT/build/dmg"
STAGING_DIR="$DMG_DIR/LumaNote"
DMG_PATH="$ROOT/build/LumaNote-$VERSION-macos-arm64.dmg"

if [ ! -d "$APP_DIR" ]; then
  echo "Missing $APP_DIR. Run ./scripts/build-app.sh first." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

ditto "$APP_DIR" "$STAGING_DIR/LumaNote.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "LumaNote" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
echo "$DMG_PATH"
