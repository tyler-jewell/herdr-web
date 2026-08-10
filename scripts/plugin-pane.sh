#!/usr/bin/env bash
# Long-lived plugin pane: serve Integrations UI (hot-reload) in Herdr side-by-side.
set -euo pipefail
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"
export HERDR_WEB_ROOT="$ROOT"
export HERDR_WEB_HOT_RELOAD="${HERDR_WEB_HOT_RELOAD:-1}"
export PATH="${HOME}/.local/bin:${PATH}"
# Prefer Herdr-injected binary
if [[ -n "${HERDR_BIN_PATH:-}" ]]; then
  export PATH="$(dirname "$HERDR_BIN_PATH"):${PATH}"
fi
exec bash "$ROOT/scripts/serve.sh"
