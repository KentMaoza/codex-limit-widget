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
OLD_APP_PIDS=()

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

terminate_running_app() {
  local pid
  local old_pid
  local still_running

  OLD_APP_PIDS=()
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && OLD_APP_PIDS+=("$pid")
  done < <(/usr/bin/pgrep -x "$APP_NAME" 2>/dev/null || true)

  if (( ${#OLD_APP_PIDS[@]} == 0 )); then
    return 0
  fi

  /bin/kill "${OLD_APP_PIDS[@]}" >/dev/null 2>&1 || true
  for _ in {1..40}; do
    still_running=0
    for old_pid in "${OLD_APP_PIDS[@]}"; do
      if /bin/kill -0 "$old_pid" >/dev/null 2>&1; then
        still_running=1
        break
      fi
    done

    if (( still_running == 0 )); then
      return 0
    fi
    sleep 0.25
  done

  printf 'existing %s process did not terminate\n' "$APP_NAME" >&2
  return 1
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" --args -ApplePersistenceIgnoreState YES
}

was_old_app_pid() {
  local candidate="$1"
  local old_pid

  if (( ${#OLD_APP_PIDS[@]} == 0 )); then
    return 1
  fi

  for old_pid in "${OLD_APP_PIDS[@]}"; do
    if [[ "$candidate" == "$old_pid" ]]; then
      return 0
    fi
  done
  return 1
}

wait_for_new_process() {
  local pid

  for _ in {1..40}; do
    while IFS= read -r pid; do
      if [[ -n "$pid" ]] && ! was_old_app_pid "$pid"; then
        return 0
      fi
    done < <(/usr/bin/pgrep -x "$APP_NAME" 2>/dev/null || true)
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
  local validation_status

  if /usr/bin/python3 -c '
import json
import pathlib
import re
import sys

try:
    data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, UnicodeError, json.JSONDecodeError):
    raise SystemExit(2)

sensitive_keys = {"authorization", "accesstoken", "refreshtoken", "idtoken", "token"}

def scan(value):
    if isinstance(value, dict):
        for key, child in value.items():
            normalized_key = re.sub(r"[^a-z0-9]", "", key.lower())
            if (
                normalized_key in sensitive_keys
                or normalized_key.endswith("token")
                or re.search(r"\bbearer\b", key, re.IGNORECASE)
            ):
                raise SystemExit(3)
            scan(child)
    elif isinstance(value, list):
        for child in value:
            scan(child)
    elif isinstance(value, str) and re.search(r"\bbearer\b", value, re.IGNORECASE):
        raise SystemExit(3)

scan(data)
' "$SNAPSHOT_PATH" 2>/dev/null; then
    return 0
  else
    validation_status="$?"
  fi

  case "$validation_status" in
    2)
      printf 'Debug mirror snapshot could not be read as valid JSON\n' >&2
      ;;
    3)
      printf 'Debug mirror snapshot contains auth material\n' >&2
      ;;
    *)
      printf 'Debug mirror snapshot validation failed\n' >&2
      ;;
  esac
  return 1
}

build_app

case "$MODE" in
  build)
    ;;
  run)
    terminate_running_app
    open_app
    wait_for_new_process
    ;;
  debug)
    terminate_running_app
    lldb -- "$APP_BINARY"
    ;;
  logs)
    terminate_running_app
    open_app
    wait_for_new_process
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  smoke)
    terminate_running_app
    previous_identity="$(/usr/bin/stat -f '%i:%m:%z' "$SNAPSHOT_PATH" 2>/dev/null || printf 'missing')"
    started_at="$(date +%s)"
    open_app
    wait_for_new_process
    wait_for_fresh_snapshot "$started_at" "$previous_identity"
    validate_snapshot
    printf '%s launched and wrote a sanitized Debug mirror snapshot\n' "$APP_NAME"
    ;;
esac
