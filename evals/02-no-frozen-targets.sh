#!/usr/bin/env bash
# DON'T: hardcode OFFICIAL_TARGETS inventories in product JS/Python.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if grep -R --include='*.js' --include='*.py' -nE 'OFFICIAL_TARGETS\s*=' "$ROOT/js" "$ROOT/scripts" 2>/dev/null; then
  echo "FAIL: frozen OFFICIAL_TARGETS"
  exit 1
fi
echo "no frozen targets"
