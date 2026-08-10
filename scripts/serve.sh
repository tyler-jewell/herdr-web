#!/usr/bin/env bash
# Single-purpose local runner for herdr-web (AXI-aligned agent entry).
# Serves static files + POST /api/herdr that ONLY execs validated
# `herdr integration status|install|uninstall …` argv — no install logic here.
# Exit: 0 run, 1 error, 2 usage/unknown flag.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${HERDR_WEB_PORT:-8765}"
HOST="${HERDR_WEB_HOST:-127.0.0.1}"

usage() {
  cat <<EOF
serve — start herdr-web static UI + pure herdr integration bridge

USAGE
  serve.sh [-h|--help]
  HERDR_WEB_PORT=9000 serve.sh

NO-ARGS
  Starts server on http://${HOST}:${PORT}/ (foreground). Never interactive.

ENV
  HERDR_WEB_PORT   listen port (default 8765)
  HERDR_WEB_HOST   bind host (default 127.0.0.1)
  HERDR_WEB_ROOT   static root (default: repo root)

Requires: herdr and python3 on PATH.
AXI: https://axi.md · unknown flags exit 2.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "error:"
      echo "  code: 2"
      echo "  message: unknown flag: $1"
      echo "help[1]:"
      echo "  Run \`serve.sh --help\`"
      exit 2
      ;;
  esac
done

export HERDR_WEB_ROOT="$ROOT"
export HERDR_WEB_PORT="$PORT"
export HERDR_WEB_HOST="$HOST"

# Prefer herdr on PATH; common user install location.
export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v herdr >/dev/null 2>&1; then
  echo "error:"
  echo "  code: 1"
  echo "  message: herdr not on PATH"
  echo "help[1]:"
  echo "  Install herdr then re-run \`serve.sh\`"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error:"
  echo "  code: 1"
  echo "  message: python3 required for the tiny bridge"
  exit 1
fi

echo "bin: ${ROOT}/scripts/serve.sh"
echo "description: herdr-web static UI + pure herdr integration bridge"
echo "url: http://${HOST}:${PORT}/"
echo "bridge: POST /api/herdr {\"argv\":[\"herdr\",\"integration\",…]}"
echo "herdr: $(command -v herdr) ($(herdr --version 2>/dev/null | head -1))"
echo "help[2]:"
echo "  Open http://${HOST}:${PORT}/ and click Refresh status"
echo "  POST /api/herdr with validated herdr integration argv only"
echo "Ctrl-C to stop."

exec python3 "$ROOT/scripts/bridge.py"
