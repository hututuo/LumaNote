#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${LUMANOTE_REPO:-https://github.com/hututuo/LumaNote.git}"
SOURCE_DIR="${LUMANOTE_SOURCE_DIR:-$HOME/.lumanote/source}"
APP_INSTALL_DIR="${LUMANOTE_APP_DIR:-$HOME/Applications}"
APP_NAME="LumaNote.app"

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_command git
need_command swift
need_command plutil

mkdir -p "$SOURCE_DIR" "$APP_INSTALL_DIR"

if [ -d "$SOURCE_DIR/.git" ]; then
  git -C "$SOURCE_DIR" pull --ff-only
else
  rm -rf "$SOURCE_DIR"
  git clone "$REPO_URL" "$SOURCE_DIR"
fi

cd "$SOURCE_DIR/app/QuietNote"
./scripts/build-app.sh

rm -rf "$APP_INSTALL_DIR/$APP_NAME"
cp -R "build/$APP_NAME" "$APP_INSTALL_DIR/$APP_NAME"

echo
echo "Installed $APP_INSTALL_DIR/$APP_NAME"

if [ "${LUMANOTE_NO_OPEN:-0}" != "1" ]; then
  open "$APP_INSTALL_DIR/$APP_NAME"
fi
