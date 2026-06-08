#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build

APP_DIR="$ROOT/build/QuietNote.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT/.build/debug/QuietNote" "$APP_DIR/Contents/MacOS/QuietNote"
chmod +x "$APP_DIR/Contents/MacOS/QuietNote"
cp "$ROOT/support/Info.plist" "$APP_DIR/Contents/Info.plist"

plutil -lint "$APP_DIR/Contents/Info.plist"
echo "$APP_DIR"
