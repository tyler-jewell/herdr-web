#!/usr/bin/env bash
# DO: integrations pane opens a real browser (not terminal-only serve).
# DON'T: document ad-hoc `export HERDR_BROWSER_CHROME=…` — host config is VC.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pane="$ROOT/scripts/plugin-pane.sh"
test -f "$pane"
# Must try official.browser and/or system open/xdg-open
grep -q 'official.browser' "$pane"
grep -q 'HERDR_BROWSER_INITIAL_URL' "$pane"
grep -qE 'open |xdg-open' "$pane"
# Must not only exec serve without browser open path
if ! grep -q 'open_real_browser' "$pane"; then
  echo "FAIL: missing open_real_browser"
  exit 1
fi
# Anti-pattern: one-off shell exports instead of tracked host config
if grep -nE 'export HERDR_BROWSER_CHROME=|optional: export HERDR_BROWSER' "$pane"; then
  echo "FAIL: ad-hoc HERDR_BROWSER_CHROME export — put Chrome/PATH in home-manager / tracked herdr config"
  exit 1
fi
# Help should point at version-controlled config, not shell workarounds
grep -q 'config.toml' "$pane"
echo "browser pane wired"
