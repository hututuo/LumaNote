#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
UNTRACKED_SOURCE="$ROOT/Sources/ReleaseSafetyUntracked.swift"
IGNORED_SOURCE_DIR="$ROOT/Sources/build/release-safety-test"
TEMP_ROOT="$(mktemp -d /tmp/lumanote-release-safety.XXXXXX)"

cleanup() {
  rm -f -- "$UNTRACKED_SOURCE"
  rm -rf -- "$IGNORED_SOURCE_DIR" "$TEMP_ROOT"
  rmdir "$ROOT/Sources/build" >/dev/null 2>&1 || true
}
trap cleanup EXIT

expect_failure() {
  local expected="$1"
  shift
  local output status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "Expected command to fail: $*" >&2
    exit 1
  fi
  if ! grep -F "$expected" <<<"$output" >/dev/null; then
    echo "Expected failure text not found: $expected" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

if [ -n "$(git -C "$REPO_ROOT" status --porcelain=v2 --untracked-files=all)" ]; then
  echo "Run release safety tests from a clean worktree." >&2
  exit 1
fi

printf 'struct ReleaseSafetyUntracked {}\n' > "$UNTRACKED_SOURCE"
expect_failure "tracked or untracked changes" "$ROOT/scripts/prepare-release.sh"
rm -f -- "$UNTRACKED_SOURCE"

mkdir -p "$IGNORED_SOURCE_DIR"
printf 'struct ReleaseSafetyIgnored {}\n' > "$IGNORED_SOURCE_DIR/Ignored.swift"
git -C "$REPO_ROOT" check-ignore -q "app/QuietNote/Sources/build/release-safety-test/Ignored.swift"
expect_failure "Release source is not tracked by Git" "$ROOT/scripts/prepare-release.sh"
rm -rf -- "$IGNORED_SOURCE_DIR"

expect_failure \
  "LUMANOTE_SKIP_APPCAST is not allowed" \
  env LUMANOTE_SKIP_APPCAST=1 "$ROOT/scripts/prepare-release.sh"

mkdir -p "$TEMP_ROOT/source" "$TEMP_ROOT/apps"
printf 'keep me\n' > "$TEMP_ROOT/source/user-data.txt"
expect_failure \
  "Refusing to delete or replace non-Git data" \
  env \
    LUMANOTE_SOURCE_DIR="$TEMP_ROOT/source" \
    LUMANOTE_APP_DIR="$TEMP_ROOT/apps" \
    LUMANOTE_NO_OPEN=1 \
    "$REPO_ROOT/install.sh"
test -f "$TEMP_ROOT/source/user-data.txt"

echo "Release safety tests passed."
