#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
cd "$ROOT"

APP_NAME="LumaNote"
APP_BUNDLE="$APP_NAME.app"
BUNDLE_ID="com.hututuo.lumanote"
ARCHIVE_ARCH="${LUMANOTE_RELEASE_ARCH:-arm64}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-hututuo/LumaNote}"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-$BUNDLE_ID}"
VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT/support/Info.plist")"
BUILD="$(plutil -extract CFBundleVersion raw -o - "$ROOT/support/Info.plist")"
TAG="${LUMANOTE_RELEASE_TAG:-v$VERSION}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/}"
RELEASE_DIR="$ROOT/build/releases/$TAG"
APPCAST_DIR="$REPO_ROOT/appcast-test"
APPCAST_BUILD_DIR="$RELEASE_DIR/appcast-input"
DOC_RELEASE_NOTES="$REPO_ROOT/docs/releases/$TAG.md"
APPCAST_NOTES="$APPCAST_DIR/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.md"
VERSIONED_ZIP="$RELEASE_DIR/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.zip"
EXISTING_APPCAST_ZIP="$APPCAST_DIR/$(basename "$VERSIONED_ZIP")"
COMPAT_ZIP="$RELEASE_DIR/$APP_NAME.app.zip"
DMG_SOURCE="$ROOT/build/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.dmg"
DMG_TARGET="$RELEASE_DIR/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.dmg"
SHA_FILE="$RELEASE_DIR/SHA256SUMS-$TAG.txt"
APPCAST_XML="$APPCAST_DIR/appcast.xml"
SIGN_UPDATE="$ROOT/.build/artifacts/sparkle/Sparkle/bin/sign_update"
GENERATE_APPCAST="$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"

require_clean_tree() {
  if [ "${LUMANOTE_ALLOW_DIRTY:-0}" = "1" ]; then
    return
  fi

  if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "Working tree has uncommitted changes. Commit them first or set LUMANOTE_ALLOW_DIRTY=1." >&2
    exit 1
  fi
}

require_release_notes() {
  if [ ! -f "$DOC_RELEASE_NOTES" ]; then
    echo "Missing release notes: $DOC_RELEASE_NOTES" >&2
    exit 1
  fi
}

extract_appcast_signature() {
  sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$APPCAST_XML" | head -n 1
}

require_clean_tree
require_release_notes

LUMANOTE_BUILD_CONFIGURATION=release "$ROOT/scripts/build-app.sh"
codesign -d -r- "$ROOT/build/$APP_BUNDLE" 2>&1 | grep -F "designated => identifier \"$BUNDLE_ID\"" >/dev/null

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR" "$APPCAST_DIR"

ditto -c -k --sequesterRsrc --keepParent "$ROOT/build/$APP_BUNDLE" "$VERSIONED_ZIP"
cp "$VERSIONED_ZIP" "$COMPAT_ZIP"
cp "$DOC_RELEASE_NOTES" "$APPCAST_NOTES"

"$ROOT/scripts/build-dmg.sh"
cp "$DMG_SOURCE" "$DMG_TARGET"

if [ "${LUMANOTE_SKIP_APPCAST:-0}" != "1" ]; then
  rm -rf "$APPCAST_BUILD_DIR"
  mkdir -p "$APPCAST_BUILD_DIR"
  cp "$VERSIONED_ZIP" "$APPCAST_BUILD_DIR/$(basename "$VERSIONED_ZIP")"
  cp "$DOC_RELEASE_NOTES" "$APPCAST_BUILD_DIR/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.md"
  if [ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]; then
    KEY_ARGS=(--ed-key-file "$SPARKLE_PRIVATE_KEY_FILE")
  else
    KEY_ARGS=(--account "$SPARKLE_ACCOUNT")
  fi
  "$GENERATE_APPCAST" \
    "${KEY_ARGS[@]}" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    --embed-release-notes \
    "$APPCAST_BUILD_DIR"

  cp "$APPCAST_BUILD_DIR/appcast.xml" "$APPCAST_XML"

  SIGNATURE="$(extract_appcast_signature)"
  if [ -z "$SIGNATURE" ]; then
    echo "Unable to find sparkle:edSignature in $APPCAST_XML" >&2
    exit 1
  fi
  "$SIGN_UPDATE" "${KEY_ARGS[@]}" --verify "$APPCAST_BUILD_DIR/$(basename "$VERSIONED_ZIP")" "$SIGNATURE"
elif [ -f "$EXISTING_APPCAST_ZIP" ]; then
  cp "$EXISTING_APPCAST_ZIP" "$VERSIONED_ZIP"
  echo "Reused existing appcast update zip because LUMANOTE_SKIP_APPCAST=1: $EXISTING_APPCAST_ZIP"
fi

(
  cd "$RELEASE_DIR"
  shasum -a 256 "$(basename "$DMG_TARGET")" "$(basename "$VERSIONED_ZIP")" "$(basename "$COMPAT_ZIP")" > "$SHA_FILE"
)

codesign --verify --deep --strict --verbose=2 "$ROOT/build/$APP_BUNDLE"
hdiutil verify "$DMG_TARGET"

cat <<SUMMARY
Release prepared.
Version: $VERSION ($BUILD)
Tag: $TAG
Release directory: $RELEASE_DIR
DMG: $DMG_TARGET
Sparkle zip: $VERSIONED_ZIP
Compatibility zip: $COMPAT_ZIP
SHA256: $SHA_FILE
Appcast: $APPCAST_XML
Download URL prefix: $DOWNLOAD_URL_PREFIX
SUMMARY
