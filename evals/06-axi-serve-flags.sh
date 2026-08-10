#!/usr/bin/env bash
# DO: serve.sh fails loud on unknown flags (AXI P6).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
set +e
out="$(bash "$ROOT/scripts/serve.sh" --not-a-flag 2>&1)"
code=$?
set -e
test "$code" -eq 2
echo "$out" | grep -q 'unknown flag'
echo "serve unknown flag exit 2"
