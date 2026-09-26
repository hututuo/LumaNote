#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${LUMANOTE_REPO:-https://github.com/hututuo/LumaNote.git}"
SOURCE_DIR="${LUMANOTE_SOURCE_DIR:-$HOME/.lumanote/source}"
SOURCE_REF="${LUMANOTE_REF:-}"
SOURCE_BRANCH="${LUMANOTE_BRANCH:-main}"
APP_INSTALL_DIR="${LUMANOTE_APP_DIR:-$HOME/Applications}"
APP_NAME="LumaNote.app"
CLONE_ROOT=""
STAGING_ROOT=""

cleanup() {
  local path
  for path in "$CLONE_ROOT" "$STAGING_ROOT"; do
    if [ -n "$path" ] && { [ -e "$path" ] || [ -L "$path" ]; }; then
      rm -rf -- "$path"
    fi
  done
}
trap cleanup EXIT

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_command git
need_command swift
need_command plutil
need_command codesign
need_command ditto

if [[ "$SOURCE_DIR" != /* ]] || [[ "$APP_INSTALL_DIR" != /* ]]; then
  echo "LUMANOTE_SOURCE_DIR and LUMANOTE_APP_DIR must be absolute paths." >&2
  exit 1
fi
case "$SOURCE_DIR" in
  /|"$HOME"|"$HOME/"|"$APP_INSTALL_DIR")
    echo "Refusing unsafe LUMANOTE_SOURCE_DIR: $SOURCE_DIR" >&2
    exit 1
    ;;
esac

normalize_repo_url() {
  local value="${1%.git}"
  value="${value#ssh://git@github.com/}"
  value="${value#git@github.com:}"
  value="${value#https://github.com/}"
  value="${value#http://github.com/}"
  printf '%s\n' "${value%/}"
}

require_clean_source() {
  if [ -n "$(git -C "$SOURCE_DIR" status --porcelain=v2 --untracked-files=all)" ]; then
    echo "Source checkout has local changes; refusing to replace or build them: $SOURCE_DIR" >&2
    exit 1
  fi
}

require_tracked_sources() {
  local source_path relative_path
  while IFS= read -r -d '' source_path; do
    relative_path="${source_path#"$SOURCE_DIR/"}"
    if ! git -C "$SOURCE_DIR" ls-files --error-unmatch -- "$relative_path" >/dev/null 2>&1; then
      echo "Source file is not tracked by Git: $relative_path" >&2
      exit 1
    fi
  done < <(find "$SOURCE_DIR/app/QuietNote/Sources" -type f -name '*.swift' -print0)
}

mkdir -p "$(dirname "$SOURCE_DIR")" "$APP_INSTALL_DIR"

if [ -e "$SOURCE_DIR" ]; then
  if git -C "$SOURCE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    SOURCE_TOP="$(git -C "$SOURCE_DIR" rev-parse --show-toplevel)"
    if [ "$(cd "$SOURCE_DIR" && pwd -P)" != "$(cd "$SOURCE_TOP" && pwd -P)" ]; then
      echo "LUMANOTE_SOURCE_DIR must be the Git worktree root: $SOURCE_DIR" >&2
      exit 1
    fi
  elif [ -d "$SOURCE_DIR" ] && [ -z "$(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    rmdir "$SOURCE_DIR"
  else
    echo "Refusing to delete or replace non-Git data at $SOURCE_DIR" >&2
    exit 1
  fi
fi

if [ ! -e "$SOURCE_DIR" ]; then
  CLONE_ROOT="$(mktemp -d "$(dirname "$SOURCE_DIR")/.lumanote-clone.XXXXXX")"
  git clone "$REPO_URL" "$CLONE_ROOT/repository"
  mv "$CLONE_ROOT/repository" "$SOURCE_DIR"
else
  require_clean_source
fi

ACTUAL_REPO_URL="$(git -C "$SOURCE_DIR" remote get-url origin)"
if [ "$(normalize_repo_url "$ACTUAL_REPO_URL")" != "$(normalize_repo_url "$REPO_URL")" ]; then
  echo "Existing source origin does not match LUMANOTE_REPO." >&2
  echo "Expected: $REPO_URL" >&2
  echo "Actual:   $ACTUAL_REPO_URL" >&2
  exit 1
fi

require_clean_source
git -C "$SOURCE_DIR" fetch --prune --tags origin
require_clean_source

if [ -z "$SOURCE_REF" ]; then
  SOURCE_REF="$(git -C "$SOURCE_DIR" for-each-ref \
    --count=1 \
    --merged="refs/remotes/origin/$SOURCE_BRANCH" \
    --sort=-version:refname \
    --format='%(refname:short)' \
    refs/tags)"
  if [ -z "$SOURCE_REF" ]; then
    echo "No stable release tag is reachable from origin/$SOURCE_BRANCH." >&2
    exit 1
  fi
fi

SOURCE_SHA="$(git -C "$SOURCE_DIR" rev-parse --verify "$SOURCE_REF^{commit}")"
git -C "$SOURCE_DIR" checkout --detach "$SOURCE_SHA"
require_clean_source
require_tracked_sources

cd "$SOURCE_DIR/app/QuietNote"
SOURCE_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - support/Info.plist)"
if [[ "$SOURCE_REF" == v* ]] && [ "$SOURCE_REF" != "v$SOURCE_VERSION" ]; then
  echo "Source tag $SOURCE_REF does not match app version $SOURCE_VERSION." >&2
  exit 1
fi
LUMANOTE_BUILD_CONFIGURATION=release ./scripts/build-app.sh

STAGING_ROOT="$(mktemp -d "$APP_INSTALL_DIR/.lumanote-install.XXXXXX")"
STAGED_APP="$STAGING_ROOT/$APP_NAME"
PREVIOUS_APP="$STAGING_ROOT/LumaNote.previous.app"
TARGET_APP="$APP_INSTALL_DIR/$APP_NAME"

ditto "build/$APP_NAME" "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

if [ -e "$TARGET_APP" ] || [ -L "$TARGET_APP" ]; then
  mv "$TARGET_APP" "$PREVIOUS_APP"
fi
if ! mv "$STAGED_APP" "$TARGET_APP"; then
  if [ -e "$PREVIOUS_APP" ] || [ -L "$PREVIOUS_APP" ]; then
    mv "$PREVIOUS_APP" "$TARGET_APP"
  fi
  echo "Installation failed; the previous app was restored." >&2
  exit 1
fi

rm -rf -- "$PREVIOUS_APP"

echo
echo "Installed $TARGET_APP"
echo "Source: $SOURCE_REF ($SOURCE_SHA)"

if [ "${LUMANOTE_NO_OPEN:-0}" != "1" ]; then
  open "$TARGET_APP"
fi
