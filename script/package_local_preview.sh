#!/usr/bin/env bash
set -euo pipefail

if (( $# != 0 )); then
  printf 'usage: %s\n' "$0" >&2
  exit 2
fi

APP_NAME="Codex Limit Widget"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="/tmp/codex-limit-widget-derived"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
HOST_ARCH="$(uname -m)"
DIST_DIR="$ROOT_DIR/dist"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

case "$HOST_ARCH" in
  arm64|x86_64)
    ;;
  *)
    fail "unsupported host architecture: $HOST_ARCH"
    ;;
esac

"$ROOT_DIR/script/build_and_run.sh" build >&2

[[ -d "$APP_BUNDLE" ]] || fail "Debug app bundle was not built"
[[ "$(lipo -archs "$APP_BINARY")" == "$HOST_ARCH" ]] \
  || fail "Debug app binary is not host-architecture only"

signing_info="$(/usr/bin/codesign -dvv "$APP_BUNDLE" 2>&1)"
if ! /usr/bin/grep '^Signature=adhoc$' <<< "$signing_info" >/dev/null; then
  fail "Debug app is not ad-hoc signed"
fi

VERSION="$(/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleShortVersionString' \
  "$APP_BUNDLE/Contents/Info.plist")"
ARCHIVE_PATH="$DIST_DIR/Codex-Limit-Widget-$VERSION-$HOST_ARCH-local-preview.zip"
EXTRACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-limit-widget-preview.XXXXXX")"

cleanup() {
  rm -rf "$EXTRACT_DIR"
}
trap cleanup EXIT

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"
/usr/bin/ditto -x -k "$ARCHIVE_PATH" "$EXTRACT_DIR"

EXTRACTED_APP="$EXTRACT_DIR/$APP_NAME.app"
FRAMEWORK="$EXTRACTED_APP/Contents/Frameworks/CodexLimitCore.framework"

[[ -L "$FRAMEWORK/Versions/Current" ]] \
  || fail "Extracted framework is missing Versions/Current symlink"
[[ "$(readlink "$FRAMEWORK/Versions/Current")" == "A" ]] \
  || fail "Extracted framework Versions/Current symlink has an unexpected target"
[[ -L "$FRAMEWORK/CodexLimitCore" ]] \
  || fail "Extracted framework is missing its top-level binary symlink"
[[ "$(readlink "$FRAMEWORK/CodexLimitCore")" == "Versions/Current/CodexLimitCore" ]] \
  || fail "Extracted framework binary symlink has an unexpected target"

/usr/bin/codesign --verify --deep --strict "$EXTRACTED_APP" \
  || fail "Extracted app signature verification failed"

printf '%s\n' "$ARCHIVE_PATH"
