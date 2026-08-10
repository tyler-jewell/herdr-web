#!/usr/bin/env bash
# DO: bridge only validates/runs herdr integration argv.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -q 'validate_herdr_argv' "$ROOT/scripts/bridge.py"
grep -q 'integration' "$ROOT/scripts/bridge.py"
# DON'T invent third-party install URLs in product scripts
if grep -R --include='*.js' --include='*.py' -nE 'x\.ai/cli|herdr\.dev/install' "$ROOT/js" "$ROOT/scripts" 2>/dev/null; then
  echo "FAIL: third-party install URLs in product code"
  exit 1
fi
echo "pure herdr primitives"
