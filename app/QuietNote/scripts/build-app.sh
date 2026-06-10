#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build

APP_DIR="$ROOT/build/LumaNote.app"
SIGNING_REQUIREMENT='=designated => identifier "com.hututuo.lumanote"'
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT/.build/debug/QuietNote" "$APP_DIR/Contents/MacOS/QuietNote"
chmod +x "$APP_DIR/Contents/MacOS/QuietNote"
cp "$ROOT/support/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/support/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

plutil -lint "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - --requirements "$SIGNING_REQUIREMENT" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "$APP_DIR"
