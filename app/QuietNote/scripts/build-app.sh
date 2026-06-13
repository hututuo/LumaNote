#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_CONFIGURATION="${LUMANOTE_BUILD_CONFIGURATION:-debug}"
case "$BUILD_CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Unsupported LUMANOTE_BUILD_CONFIGURATION: $BUILD_CONFIGURATION" >&2
    exit 1
    ;;
esac

swift build -c "$BUILD_CONFIGURATION"

APP_DIR="$ROOT/build/LumaNote.app"
SIGNING_REQUIREMENT='=designated => identifier "com.hututuo.lumanote"'
SPARKLE_FRAMEWORK="$(find "$ROOT/.build" -path "*/$BUILD_CONFIGURATION/Sparkle.framework" -type d | head -n 1)"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"

if [ -z "$SPARKLE_FRAMEWORK" ]; then
  echo "Missing Sparkle.framework. Run swift build -c $BUILD_CONFIGURATION again." >&2
  exit 1
fi

cp "$ROOT/.build/$BUILD_CONFIGURATION/QuietNote" "$APP_DIR/Contents/MacOS/QuietNote"
chmod +x "$APP_DIR/Contents/MacOS/QuietNote"
if ! otool -l "$APP_DIR/Contents/MacOS/QuietNote" | grep -F '@executable_path/../Frameworks' >/dev/null; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/QuietNote"
fi
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
