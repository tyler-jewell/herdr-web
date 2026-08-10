#!/usr/bin/env bash
# DO: bridge only validates/runs herdr integration argv (Go).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -f "$ROOT/cmd/bridge/main.go"
grep -q 'validateHerdrArgv' "$ROOT/cmd/bridge/main.go"
grep -q 'integration' "$ROOT/cmd/bridge/main.go"
# DON'T invent third-party install URLs in product scripts
if grep -R --include='*.js' --include='*.go' -nE 'x\.ai/cli|herdr\.dev/install' "$ROOT/js" "$ROOT/cmd" "$ROOT/scripts" 2>/dev/null; then
  echo "FAIL: third-party install URLs in product code"
  exit 1
fi
# DON'T ship Python product code (umbrella rule 14)
if find "$ROOT" -name '*.py' -not -path '*/.git/*' 2>/dev/null | grep -q .; then
  echo "FAIL: Python files present — Go only"
  exit 1
fi
echo "pure herdr primitives"
