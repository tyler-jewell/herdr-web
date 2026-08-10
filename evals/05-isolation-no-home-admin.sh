#!/usr/bin/env bash
# DO: isolatable product must not require $HOME admin paths to start.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# serve scripts should not hardcode /Users/
if grep -nE '/Users/[a-zA-Z0-9_-]+/' "$ROOT/scripts/serve.sh" "$ROOT/cmd/bridge/main.go" "$ROOT/scripts/plugin-pane.sh" 2>/dev/null; then
  echo "FAIL: absolute home paths in serve entry"
  exit 1
fi
test -f "$ROOT/herdr-plugin.toml"
test -x "$ROOT/scripts/serve.sh" || test -f "$ROOT/scripts/serve.sh"
echo "isolation ok"
