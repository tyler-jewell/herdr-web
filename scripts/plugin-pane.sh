#!/usr/bin/env bash
# Long-lived plugin pane: serve Integrations UI and open a *real browser*
# (official.browser in-pane when available, else system browser).
#
# Host Chrome/Bun/PATH and Herdr graphics settings belong in version-controlled
# machine config (home-manager + ~/.config/herdr/config.toml) — not ad-hoc exports.
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"
export HERDR_WEB_ROOT="$ROOT"
export HERDR_WEB_HOT_RELOAD="${HERDR_WEB_HOT_RELOAD:-1}"
export PATH="${HOME}/.local/bin:${PATH}"

if [[ -n "${HERDR_BIN_PATH:-}" ]]; then
  export PATH="$(dirname "$HERDR_BIN_PATH"):${PATH}"
fi

HERDR_BIN="${HERDR_BIN_PATH:-herdr}"
HOST="${HERDR_WEB_HOST:-127.0.0.1}"
PORT="${HERDR_WEB_PORT:-8765}"
URL="http://${HOST}:${PORT}/"
SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

port_listening() {
  # Pure bash TCP probe — no Python, no lsof/nc required.
  if (echo >/dev/tcp/"$HOST"/"$PORT") >/dev/null 2>&1; then
    return 0
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsS -o /dev/null --max-time 1 "http://${HOST}:${PORT}/" 2>/dev/null && return 0
  fi
  return 1
}

wait_for_url() {
  local i
  for i in $(seq 1 50); do
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS -o /dev/null --max-time 1 "$URL" 2>/dev/null; then
        return 0
      fi
    elif port_listening; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

open_real_browser() {
  # 1) In-pane Chromium via official.browser (Herdr graphics pane).
  # Chrome is discovered by official.browser from PATH / its own rules —
  # do not inject one-off HERDR_BROWSER_CHROME workarounds here.
  echo "browser: trying official.browser → $URL"
  local err="" rc=0
  set +e
  err="$("$HERDR_BIN" plugin pane open \
    --plugin official.browser \
    --entrypoint browser \
    --placement split \
    --direction right \
    --env "HERDR_BROWSER_INITIAL_URL=${URL}" \
    --focus 2>&1)"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    echo "browser: in-pane Chromium opened (official.browser)"
    return 0
  fi
  echo "browser: official.browser open failed (rc=$rc); falling back to system browser"
  if [[ -n "$err" ]]; then
    echo "browser: detail: $err"
  fi
  echo "help[1]:"
  echo "  Fix host setup in version-controlled config (not shell exports):"
  echo "  - ~/.config/herdr/config.toml  → [experimental] kitty_graphics = true"
  echo "  - home-manager (~/system)      → bun + chromium on PATH for official.browser"
  echo "  - herdr plugin install ogulcancelik/herdr-browser --yes"
  echo "  Then: herdr server reload-config  (or restart server if PATH changed)"

  # 2) System browser (actual GUI browser window).
  if command -v open >/dev/null 2>&1; then
    echo "browser: open (macOS) → $URL"
    open "$URL" && return 0
  fi
  if command -v xdg-open >/dev/null 2>&1; then
    echo "browser: xdg-open → $URL"
    xdg-open "$URL" && return 0
  fi

  echo "error:"
  echo "  code: 1"
  echo "  message: no browser available to open $URL"
  echo "help[1]:"
  echo "  Install official.browser (tracked host packages) or open $URL manually"
  return 1
}

echo "bin: ${ROOT}/scripts/plugin-pane.sh"
echo "description: herdr-web Integrations UI + real browser"
echo "url: $URL"

if port_listening; then
  echo "serve: already listening on ${HOST}:${PORT} (reusing)"
else
  echo "serve: starting bridge on ${HOST}:${PORT}"
  bash "$ROOT/scripts/serve.sh" &
  SERVER_PID=$!
  if ! wait_for_url; then
    echo "error:"
    echo "  code: 1"
    echo "  message: bridge did not become ready at $URL"
    exit 1
  fi
  echo "serve: ready (pid ${SERVER_PID})"
fi

open_real_browser || true

echo "help[2]:"
echo "  UI is open in a real browser at $URL"
echo "  This pane keeps the bridge alive (hot-reload on)."
echo "  Ctrl-C / close pane to stop a bridge we started here."

if [[ -n "${SERVER_PID}" ]]; then
  wait "${SERVER_PID}"
else
  # Reusing an external serve process — stay open so the plugin pane remains useful.
  while true; do
    if ! port_listening; then
      echo "serve: listener gone; exiting"
      exit 1
    fi
    sleep 2
  done
fi
