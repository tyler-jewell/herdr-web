#!/usr/bin/env bash
# Single-purpose local runner for herdr-web.
# Serves static files + POST /api/herdr that ONLY execs validated
# `herdr integration status|install|uninstall …` argv — no install logic here.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${HERDR_WEB_PORT:-8765}"
HOST="${HERDR_WEB_HOST:-127.0.0.1}"

export HERDR_WEB_ROOT="$ROOT"
export HERDR_WEB_PORT="$PORT"
export HERDR_WEB_HOST="$HOST"

# Prefer herdr on PATH; common user install location.
export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v herdr >/dev/null 2>&1; then
  echo "ERR: herdr not on PATH" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERR: python3 required for the tiny bridge" >&2
  exit 1
fi

echo "herdr-web: http://${HOST}:${PORT}/"
echo "bridge:    POST /api/herdr  {\"argv\":[\"herdr\",\"integration\",…]}"
echo "herdr:     $(command -v herdr)  ($(herdr --version 2>/dev/null | head -1))"
echo "cwd static: $ROOT"
echo "Ctrl-C to stop."

exec python3 "$ROOT/scripts/bridge.py"
