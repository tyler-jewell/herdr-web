#!/usr/bin/env bash
# DON'T: hardcode OFFICIAL_TARGETS inventories in product JS/Go.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if grep -R --include='*.js' --include='*.go' -nE 'OFFICIAL_TARGETS\s*=' "$ROOT/js" "$ROOT/cmd" "$ROOT/scripts" 2>/dev/null; then
  echo "FAIL: frozen OFFICIAL_TARGETS"
  exit 1
fi
echo "no frozen targets"
