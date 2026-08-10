#!/usr/bin/env bash
# DO: integrations pane opens a real browser (not terminal-only serve).
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
echo "browser pane wired"
