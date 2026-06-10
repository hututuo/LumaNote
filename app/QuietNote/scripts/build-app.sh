#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build

APP_DIR="$ROOT/build/LumaNote.app"
SIGNING_REQUIREMENT='=designated => identifier "com.hututuo.lumanote"'
SPARKLE_FRAMEWORK="$(find "$ROOT/.build" -path '*/debug/Sparkle.framework' -type d | head -n 1)"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"

if [ -z "$SPARKLE_FRAMEWORK" ]; then
  echo "Missing Sparkle.framework. Run swift build again." >&2
  exit 1
fi

cp "$ROOT/.build/debug/QuietNote" "$APP_DIR/Contents/MacOS/QuietNote"
chmod +x "$APP_DIR/Contents/MacOS/QuietNote"
cp "$ROOT/support/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/support/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
ditto "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/Sparkle.framework"

plutil -lint "$APP_DIR/Contents/Info.plist"
codesign --force --sign - --preserve-metadata=identifier,entitlements,flags "$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --sign - --preserve-metadata=identifier,entitlements,flags "$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign --force --sign - --preserve-metadata=identifier,entitlements,flags "$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign --force --sign - --preserve-metadata=identifier,entitlements,flags "$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --sign - --preserve-metadata=identifier,entitlements,flags "$APP_DIR/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - --requirements "$SIGNING_REQUIREMENT" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "$APP_DIR"
