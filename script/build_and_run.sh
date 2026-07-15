#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s [build|run|debug|logs|smoke]\n' "$0" >&2
}

if (( $# > 1 )); then
  usage
  exit 2
fi

MODE="${1:-run}"
case "$MODE" in
  build|run|debug|logs|smoke)
    ;;
  *)
    usage
    exit 2
    ;;
esac

APP_NAME="Codex Limit Widget"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="/tmp/codex-limit-widget-derived"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
SNAPSHOT_PATH="$HOME/Library/Containers/com.hamlet.CodexLimitWidget.LimitWidget/Data/Library/Application Support/Codex Limit Widget/limit-snapshot.json"
HOST_ARCH="$(uname -m)"

case "$HOST_ARCH" in
  arm64|x86_64)
    ;;
  *)
    printf 'unsupported host architecture: %s\n' "$HOST_ARCH" >&2
    exit 1
    ;;
esac

build_app() {
  xcodebuild \
    -project "$ROOT_DIR/Codex Limit Widget.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Debug \
    -destination "platform=macOS,arch=$HOST_ARCH" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    clean build
}

replace_running_app() {
  /usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" --args -ApplePersistenceIgnoreState YES
}

wait_for_process() {
  for _ in {1..40}; do
    if /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
      return 0
    fi
    sleep 0.25
  done

  printf '%s did not start\n' "$APP_NAME" >&2
  return 1
}

wait_for_fresh_snapshot() {
  local started_at="$1"
  local previous_identity="$2"
  local current_identity
  local modified_at

  for _ in {1..80}; do
    if [[ -f "$SNAPSHOT_PATH" ]]; then
      modified_at="$(/usr/bin/stat -f '%m' "$SNAPSHOT_PATH")"
      current_identity="$(/usr/bin/stat -f '%i:%m:%z' "$SNAPSHOT_PATH")"
      if (( modified_at >= started_at )) && [[ "$current_identity" != "$previous_identity" ]]; then
        return 0
      fi
    fi
    sleep 0.25
  done

  printf 'Debug mirror snapshot was not refreshed\n' >&2
  return 1
}

validate_snapshot() {
  if ! /usr/bin/python3 -c \
    'import json, pathlib, sys; json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' \
    "$SNAPSHOT_PATH" 2>/dev/null; then
    printf 'Debug mirror snapshot is not valid JSON\n' >&2
    return 1
  fi

  if LC_ALL=C /usr/bin/grep -Eiq \
    '"(authorization|access[-_]?token|refresh[-_]?token|id[-_]?token|token)"[[:space:]]*:|bearer[[:space:]]+[[:alnum:]_.~+/=-]+' \
    "$SNAPSHOT_PATH"; then
    printf 'Debug mirror snapshot contains auth material\n' >&2
    return 1
  fi
}

build_app

case "$MODE" in
  build)
    ;;
  run)
    replace_running_app
    open_app
    ;;
  debug)
    replace_running_app
    lldb -- "$APP_BINARY"
    ;;
  logs)
    replace_running_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  smoke)
    replace_running_app
    previous_identity="$(/usr/bin/stat -f '%i:%m:%z' "$SNAPSHOT_PATH" 2>/dev/null || printf 'missing')"
    started_at="$(date +%s)"
    open_app
    wait_for_process
    wait_for_fresh_snapshot "$started_at" "$previous_identity"
    validate_snapshot
    printf '%s launched and wrote a sanitized Debug mirror snapshot\n' "$APP_NAME"
    ;;
esac
