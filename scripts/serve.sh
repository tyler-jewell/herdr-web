#!/usr/bin/env bash
# Single-purpose local runner for herdr-web (AXI-aligned agent entry).
# Serves static files + POST /api/herdr that ONLY execs validated
# `herdr integration status|install|uninstall …` argv — no install logic here.
# Exit: 0 run, 1 error, 2 usage/unknown flag.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORTS_FILE="${ROOT}/ports.toml"

# Load claimed port/host from ports.toml (sacred rule 22). Env overrides claim.
claim_from_ports_toml() {
  local want_app="${1:-herdr-web}"
  local f="$PORTS_FILE"
  [[ -f "$f" ]] || return 1
  awk -v want="$want_app" '
    /^\[\[port\]\]/ {
      if (app == want && port != "") { print port "\t" host; exit }
      app = ""; port = ""; host = "127.0.0.1"
      next
    }
    /^app[[:space:]]*=/ {
      line = $0; sub(/^[^=]*=[[:space:]]*/, "", line); gsub(/"/, "", line); app = line
    }
    /^port[[:space:]]*=/ {
      line = $0; sub(/^[^=]*=[[:space:]]*/, "", line); gsub(/[^0-9]/, "", line); port = line
    }
    /^host[[:space:]]*=/ {
      line = $0; sub(/^[^=]*=[[:space:]]*/, "", line); gsub(/"/, "", line); host = line
    }
    END {
      if (app == want && port != "") print port "\t" host
    }
  ' "$f"
}

CLAIM="$(claim_from_ports_toml herdr-web || true)"
CLAIM_PORT="$(printf '%s' "$CLAIM" | cut -f1)"
CLAIM_HOST="$(printf '%s' "$CLAIM" | cut -f2)"
if [[ -z "$CLAIM_HOST" ]]; then CLAIM_HOST="127.0.0.1"; fi

if [[ -n "${HERDR_WEB_PORT:-}" ]]; then
  PORT="$HERDR_WEB_PORT"
elif [[ -n "$CLAIM_PORT" ]]; then
  PORT="$CLAIM_PORT"
else
  echo "error:"
  echo "  code: 1"
  echo "  message: no port — set HERDR_WEB_PORT or claim [[port]] in ports.toml (rule 22)"
  exit 1
fi

if [[ -n "${HERDR_WEB_HOST:-}" ]]; then
  HOST="$HERDR_WEB_HOST"
else
  HOST="$CLAIM_HOST"
fi

usage() {
  cat <<EOF
serve — start herdr-web static UI + pure herdr integration bridge

USAGE
  serve.sh [-h|--help]
  HERDR_WEB_PORT=<port> serve.sh

NO-ARGS
  Starts server on the claimed/env port (foreground). Never interactive.
  Port claim SSoT: ports.toml (do not hardcode ports in docs).

ENV
  HERDR_WEB_PORT   listen port (overrides ports.toml claim)
  HERDR_WEB_HOST   bind host (overrides ports.toml claim)
  HERDR_WEB_ROOT   static root (default: repo root)

Requires: herdr and go on PATH (Go bridge); ports.toml claim or env.
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
# Hot-reload ON by default (isolatable product path)
export HERDR_WEB_HOT_RELOAD="${HERDR_WEB_HOT_RELOAD:-1}"

# Prefer herdr on PATH; plugin injects HERDR_BIN_PATH
export PATH="${HOME}/.local/bin:${PATH}"
if [[ -n "${HERDR_BIN_PATH:-}" ]]; then
  export PATH="$(dirname "$HERDR_BIN_PATH"):${PATH}"
fi

if ! command -v herdr >/dev/null 2>&1; then
  echo "error:"
  echo "  code: 1"
  echo "  message: herdr not on PATH"
  echo "help[1]:"
  echo "  Install herdr then re-run \`serve.sh\`"
  exit 1
fi

if ! command -v go >/dev/null 2>&1; then
  echo "error:"
  echo "  code: 1"
  echo "  message: go required for the bridge (tyler-jewell sacred rule 14)"
  echo "help[1]:"
  echo "  Install go via home-manager (packages: go gopls) then re-run"
  exit 1
fi

echo "bin: ${ROOT}/scripts/serve.sh"
echo "description: herdr-web static UI + pure herdr integration bridge"
echo "ports_file: $PORTS_FILE"
echo "port_claim: ${CLAIM_PORT:-none}"
echo "url: http://${HOST}:${PORT}/"
echo "bridge: POST /api/herdr {\"argv\":[\"herdr\",\"integration\",…]}"
echo "herdr: $(command -v herdr) ($(herdr --version 2>/dev/null | head -1))"
echo "go: $(command -v go) ($(go version 2>/dev/null))"
echo "help[2]:"
echo "  Open the url: line above (from ports.toml claim or env — rule 22)"
echo "  Port claims: $PORTS_FILE"
echo "  POST /api/herdr with validated herdr integration argv only"
echo "Ctrl-C to stop."

cd "$ROOT"
exec go run ./cmd/bridge
