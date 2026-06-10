#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT/support/Info.plist")"
APP_DIR="$ROOT/build/LumaNote.app"
DMG_DIR="$ROOT/build/dmg"
STAGING_DIR="$DMG_DIR/LumaNote"
BACKGROUND_PATH="$ROOT/support/dmg-background.png"
VOLUME_NAME="LumaNote"
DMG_PATH="$ROOT/build/LumaNote-$VERSION-macos-arm64.dmg"
RW_DMG_PATH="$ROOT/build/LumaNote-$VERSION-macos-arm64-rw.dmg"

if [ ! -d "$APP_DIR" ]; then
  echo "Missing $APP_DIR. Run ./scripts/build-app.sh first." >&2
  exit 1
fi

if [ ! -f "$BACKGROUND_PATH" ]; then
  "$ROOT/scripts/generate-dmg-background.swift" "$BACKGROUND_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$DMG_DIR" "$DMG_PATH" "$RW_DMG_PATH"
mkdir -p "$STAGING_DIR/.background"

ditto "$APP_DIR" "$STAGING_DIR/LumaNote.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$BACKGROUND_PATH" "$STAGING_DIR/.background/dmg-background.png"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$RW_DMG_PATH" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen)"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/\/Volumes\// {print $NF; exit}')"

if [ -z "$MOUNT_POINT" ]; then
  echo "Unable to mount temporary DMG." >&2
  printf '%s\n' "$ATTACH_OUTPUT" >&2
  exit 1
fi

cleanup_mount() {
  if mount | grep -F "on $MOUNT_POINT " >/dev/null 2>&1; then
    hdiutil detach "$MOUNT_POINT" >/dev/null || true
  fi
}
trap cleanup_mount EXIT

if ! osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to (POSIX file "$MOUNT_POINT" as alias)
  open dmgFolder
  set dmgWindow to container window of dmgFolder
  set current view of dmgWindow to icon view
  try
    set toolbar visible of dmgWindow to false
  end try
  try
    set statusbar visible of dmgWindow to false
  end try
  set bounds of dmgWindow to {120, 120, 840, 580}
  set viewOptions to icon view options of dmgWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 96
  set background picture of viewOptions to (POSIX file "$MOUNT_POINT/.background/dmg-background.png" as alias)
  set position of item "LumaNote.app" of dmgFolder to {184, 232}
  set position of item "Applications" of dmgFolder to {538, 232}
  update dmgFolder without registering applications
  delay 1
  try
    close dmgWindow
  end try
end tell
APPLESCRIPT
then
  echo "Warning: Finder DMG styling failed; continuing with an unstyled but installable DMG." >&2
fi

sync
sleep 1
hdiutil detach "$MOUNT_POINT" >/dev/null
trap - EXIT

hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null

rm -f "$RW_DMG_PATH"

hdiutil verify "$DMG_PATH"
echo "$DMG_PATH"
