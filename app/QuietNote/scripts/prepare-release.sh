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
BUILD_SCRATCH_DIR="$ROOT/build/release-scratch/$TAG"
APPCAST_DIR="$REPO_ROOT/appcast-test"
APPCAST_BUILD_DIR="$RELEASE_DIR/appcast-input"
GENERATED_APPCAST="$APPCAST_BUILD_DIR/appcast.xml"
DOC_RELEASE_NOTES="$REPO_ROOT/docs/releases/$TAG.md"
APPCAST_NOTES="$APPCAST_DIR/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.md"
VERSIONED_ZIP="$RELEASE_DIR/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.zip"
COMPAT_ZIP="$RELEASE_DIR/$APP_NAME.app.zip"
DMG_SOURCE="$ROOT/build/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.dmg"
DMG_TARGET="$RELEASE_DIR/$APP_NAME-$VERSION-macos-$ARCHIVE_ARCH.dmg"
SHA_FILE="$RELEASE_DIR/SHA256SUMS-$TAG.txt"
APPCAST_XML="$APPCAST_DIR/appcast.xml"
SOURCE_SHA_FILE="$RELEASE_DIR/SOURCE-SHA-$TAG.txt"
SIGN_UPDATE="$BUILD_SCRATCH_DIR/artifacts/sparkle/Sparkle/bin/sign_update"
GENERATE_APPCAST="$BUILD_SCRATCH_DIR/artifacts/sparkle/Sparkle/bin/generate_appcast"

require_clean_tree() {
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain=v2 --untracked-files=all)" ]; then
    echo "Working tree has tracked or untracked changes. Commit or remove them before releasing." >&2
    exit 1
  fi
}

require_tracked_sources() {
  local source_path relative_path
  while IFS= read -r -d '' source_path; do
    relative_path="${source_path#"$REPO_ROOT/"}"
    if ! git -C "$REPO_ROOT" ls-files --error-unmatch -- "$relative_path" >/dev/null 2>&1; then
      echo "Release source is not tracked by Git: $relative_path" >&2
      exit 1
    fi
  done < <(find "$ROOT/Sources" -type f -name '*.swift' -print0)
}

extract_appcast_value() {
  local element="$1"
  sed -n "s:.*<sparkle:$element>\([^<]*\)</sparkle:$element>.*:\\1:p" "$APPCAST_XML" | head -n 1
}

require_release_identity() {
  local current_build current_version tagged_sha

  if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}([.-][0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
    echo "CFBundleShortVersionString is not a safe release version: $VERSION" >&2
    exit 1
  fi
  case "$ARCHIVE_ARCH" in
    arm64|x86_64) ;;
    *)
      echo "Unsupported LUMANOTE_RELEASE_ARCH: $ARCHIVE_ARCH" >&2
      exit 1
      ;;
  esac
  if [ "$TAG" != "v$VERSION" ]; then
    echo "Release tag $TAG does not match CFBundleShortVersionString $VERSION." >&2
    exit 1
  fi
  if ! [[ "$BUILD" =~ ^[0-9]+$ ]] || [ "$BUILD" -eq 0 ]; then
    echo "CFBundleVersion must be a positive integer: $BUILD" >&2
    exit 1
  fi
  if [ "${LUMANOTE_SKIP_APPCAST:-0}" = "1" ]; then
    echo "LUMANOTE_SKIP_APPCAST is not allowed for release artifacts." >&2
    exit 1
  fi

  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/tags/$TAG"; then
    if [ "${LUMANOTE_REBUILD_EXISTING_TAG:-0}" != "1" ]; then
      echo "Release tag already exists: $TAG" >&2
      echo "Bump the version/build, or set LUMANOTE_REBUILD_EXISTING_TAG=1 for an exact tagged rebuild." >&2
      exit 1
    fi
    tagged_sha="$(git -C "$REPO_ROOT" rev-parse "$TAG^{commit}")"
    if [ "$(git -C "$REPO_ROOT" rev-parse HEAD)" != "$tagged_sha" ]; then
      echo "Tagged rebuild requires HEAD to equal $TAG ($tagged_sha)." >&2
      exit 1
    fi
    return
  fi

  if [ -f "$APPCAST_XML" ]; then
    current_build="$(extract_appcast_value version)"
    current_version="$(extract_appcast_value shortVersionString)"
    if [[ "$current_build" =~ ^[0-9]+$ ]] && [ "$BUILD" -le "$current_build" ]; then
      echo "CFBundleVersion $BUILD must be greater than appcast build $current_build." >&2
      exit 1
    fi
    if [ -n "$current_version" ] && [ "$VERSION" = "$current_version" ]; then
      echo "CFBundleShortVersionString $VERSION is already present in the appcast." >&2
      exit 1
    fi
  fi
}

require_release_notes() {
  if [ ! -f "$DOC_RELEASE_NOTES" ]; then
    echo "Missing release notes: $DOC_RELEASE_NOTES" >&2
    exit 1
  fi
}

extract_appcast_signature() {
  local appcast_path="$1"
  sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$appcast_path" | head -n 1
}

require_clean_tree
require_tracked_sources
require_release_notes
require_release_identity

rm -rf "$BUILD_SCRATCH_DIR"
swift test \
  --scratch-path "$BUILD_SCRATCH_DIR" \
  --triple "$ARCHIVE_ARCH-apple-macosx14.0"
LUMANOTE_BUILD_CONFIGURATION=release \
  LUMANOTE_BUILD_ARCH="$ARCHIVE_ARCH" \
  LUMANOTE_BUILD_SCRATCH_PATH="$BUILD_SCRATCH_DIR" \
  "$ROOT/scripts/build-app.sh"
codesign -d -r- "$ROOT/build/$APP_BUNDLE" 2>&1 | grep -F "designated => identifier \"$BUNDLE_ID\"" >/dev/null

APP_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT/build/$APP_BUNDLE/Contents/Info.plist")"
APP_BUILD="$(plutil -extract CFBundleVersion raw -o - "$ROOT/build/$APP_BUNDLE/Contents/Info.plist")"
if [ "$APP_VERSION" != "$VERSION" ] || [ "$APP_BUILD" != "$BUILD" ]; then
  echo "Built app version $APP_VERSION ($APP_BUILD) does not match source $VERSION ($BUILD)." >&2
  exit 1
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR" "$APPCAST_DIR"

ditto -c -k --sequesterRsrc --keepParent "$ROOT/build/$APP_BUNDLE" "$VERSIONED_ZIP"

LUMANOTE_RELEASE_ARCH="$ARCHIVE_ARCH" "$ROOT/scripts/build-dmg.sh"
cp "$DMG_SOURCE" "$DMG_TARGET"
codesign --verify --deep --strict --verbose=2 "$ROOT/build/$APP_BUNDLE"
hdiutil verify "$DMG_TARGET"

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

SIGNATURE="$(extract_appcast_signature "$GENERATED_APPCAST")"
if [ -z "$SIGNATURE" ]; then
  echo "Unable to find sparkle:edSignature in $GENERATED_APPCAST" >&2
  exit 1
fi
if ! grep -F "<sparkle:version>$BUILD</sparkle:version>" "$GENERATED_APPCAST" >/dev/null \
  || ! grep -F "<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>" "$GENERATED_APPCAST" >/dev/null \
  || ! grep -F "$(basename "$VERSIONED_ZIP")" "$GENERATED_APPCAST" >/dev/null; then
  echo "Generated appcast does not identify the expected versioned archive." >&2
  exit 1
fi
"$SIGN_UPDATE" "${KEY_ARGS[@]}" --verify "$APPCAST_BUILD_DIR/$(basename "$VERSIONED_ZIP")" "$SIGNATURE"

cp "$VERSIONED_ZIP" "$COMPAT_ZIP"
if ! cmp -s "$VERSIONED_ZIP" "$COMPAT_ZIP"; then
  echo "Versioned and compatibility update ZIPs differ." >&2
  exit 1
fi

SOURCE_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
printf '%s\n' "$SOURCE_SHA" > "$SOURCE_SHA_FILE"

(
  cd "$RELEASE_DIR"
  shasum -a 256 "$(basename "$DMG_TARGET")" "$(basename "$VERSIONED_ZIP")" "$(basename "$COMPAT_ZIP")" > "$SHA_FILE"
)

cp "$DOC_RELEASE_NOTES" "$APPCAST_NOTES"
cp "$GENERATED_APPCAST" "$APPCAST_XML"

cat <<SUMMARY
Release prepared.
Version: $VERSION ($BUILD)
Tag: $TAG
Source SHA: $SOURCE_SHA
Release directory: $RELEASE_DIR
DMG: $DMG_TARGET
Sparkle zip: $VERSIONED_ZIP
Compatibility zip: $COMPAT_ZIP
SHA256: $SHA_FILE
Source identity: $SOURCE_SHA_FILE
Appcast: $APPCAST_XML
Download URL prefix: $DOWNLOAD_URL_PREFIX
SUMMARY
