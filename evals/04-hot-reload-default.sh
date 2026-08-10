#!/usr/bin/env bash
# DO: hot-reload default on for isolatable serve path (Go bridge).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRIDGE="$ROOT/cmd/bridge/main.go"
test -f "$BRIDGE"
grep -q 'HERDR_WEB_HOT_RELOAD' "$BRIDGE"
grep -q '__hmr' "$BRIDGE"
grep -q 'herdr-web-hmr' "$BRIDGE"
# default must not be off
if grep -q 'HERDR_WEB_HOT_RELOAD.*0' "$ROOT/scripts/serve.sh" 2>/dev/null; then
  # allow only disable path, not default 0
  if grep -qE 'HOT_RELOAD:-0|HOT_RELOAD=0' "$ROOT/scripts/serve.sh"; then
    echo "FAIL: hot reload defaulted off"
    exit 1
  fi
fi
echo "hot-reload default wired"
