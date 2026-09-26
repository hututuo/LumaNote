#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_CONFIGURATION="${LUMANOTE_BUILD_CONFIGURATION:-debug}"
BUILD_ARCH="${LUMANOTE_BUILD_ARCH:-}"
BUILD_TRIPLE="${LUMANOTE_BUILD_TRIPLE:-}"
BUILD_SCRATCH_PATH="${LUMANOTE_BUILD_SCRATCH_PATH:-}"
case "$BUILD_CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Unsupported LUMANOTE_BUILD_CONFIGURATION: $BUILD_CONFIGURATION" >&2
    exit 1
    ;;
esac

SWIFT_BUILD_ARGS=(-c "$BUILD_CONFIGURATION")
if [ -n "$BUILD_ARCH" ]; then
  case "$BUILD_ARCH" in
    arm64|x86_64) ;;
    *)
      echo "Unsupported LUMANOTE_BUILD_ARCH: $BUILD_ARCH" >&2
      exit 1
      ;;
  esac
  BUILD_TRIPLE="${BUILD_TRIPLE:-$BUILD_ARCH-apple-macosx14.0}"
fi
if [ -n "$BUILD_TRIPLE" ]; then
  SWIFT_BUILD_ARGS+=(--triple "$BUILD_TRIPLE")
fi
if [ -n "$BUILD_SCRATCH_PATH" ]; then
  SWIFT_BUILD_ARGS+=(--scratch-path "$BUILD_SCRATCH_PATH")
fi

swift build "${SWIFT_BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"

APP_DIR="$ROOT/build/LumaNote.app"
SIGNING_REQUIREMENT='=designated => identifier "com.hututuo.lumanote"'
SPARKLE_FRAMEWORK="$BIN_DIR/Sparkle.framework"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"

if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
  echo "Missing Sparkle.framework. Run swift build -c $BUILD_CONFIGURATION again." >&2
  exit 1
fi

cp "$BIN_DIR/QuietNote" "$APP_DIR/Contents/MacOS/QuietNote"
chmod +x "$APP_DIR/Contents/MacOS/QuietNote"
if [ -n "$BUILD_ARCH" ]; then
  ACTUAL_ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/QuietNote")"
  if [ "$ACTUAL_ARCHS" != "$BUILD_ARCH" ]; then
    echo "Built executable architecture '$ACTUAL_ARCHS' does not match requested '$BUILD_ARCH'." >&2
    exit 1
  fi
fi
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
