#!/usr/bin/env bash
# Drive unit tests against shipped js/herdr-core.js + live herdr status capture.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${HERDR_WEB_SCRATCH:-}"
JSC="/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"

if [[ ! -x "$JSC" ]]; then
  echo "ERR: JavaScriptCore jsc not found at $JSC" >&2
  exit 1
fi

STATUS_FILE="${HERDR_STATUS_FILE:-}"
HELP_FILE="${HERDR_HELP_FILE:-}"
export PATH="${HOME}/.local/bin:${PATH}"
if [[ -z "$STATUS_FILE" ]]; then
  if [[ -n "$SCRATCH" ]]; then
    STATUS_FILE="$SCRATCH/herdr-integration-status.txt"
  else
    STATUS_FILE="$(mktemp)"
    trap 'rm -f "$STATUS_FILE" "$HELP_FILE"' EXIT
  fi
  herdr integration status >"$STATUS_FILE"
fi
if [[ -z "$HELP_FILE" ]]; then
  if [[ -n "$SCRATCH" ]]; then
    HELP_FILE="$SCRATCH/herdr-integration-install-help.txt"
  else
    HELP_FILE="$(mktemp)"
  fi
  herdr integration install --help >"$HELP_FILE" 2>&1 || true
fi

echo "Using status capture: $STATUS_FILE"
echo "Using help capture:   $HELP_FILE"
cd "$ROOT/test"
"$JSC" \
  -e "var HERDR_WEB_ROOT = '$ROOT'; var HERDR_STATUS_FILE = '$STATUS_FILE'; var HERDR_HELP_FILE = '$HELP_FILE';" \
  -f "$ROOT/test/run-tests.js"
