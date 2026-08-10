#!/usr/bin/env bash
# DO: herdr-web has LSP project setup for languages in use + AGENTS rule 13 pointer.
# HTML/CSS must use standalone public servers (vscode-langservers-extracted), NOT require VS Code IDE.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -f "$ROOT/jsconfig.json"
test -f "$ROOT/pyrightconfig.json"
grep -q 'checkJs' "$ROOT/jsconfig.json"
grep -q 'strict' "$ROOT/jsconfig.json"
grep -q 'typeCheckingMode' "$ROOT/pyrightconfig.json"
grep -q 'strict' "$ROOT/pyrightconfig.json"
grep -q 'LSP\|rule 13' "$ROOT/AGENTS.md"
grep -qi 'typescript-language-server\|Pyright\|bash-language-server' "$ROOT/AGENTS.md"
grep -qi 'HTML' "$ROOT/AGENTS.md"
grep -qi 'CSS' "$ROOT/AGENTS.md"
# Standalone HTML/CSS package — not "install VS Code"
grep -qi 'vscode-langservers-extracted' "$ROOT/AGENTS.md"
grep -qiE 'no VS Code|not.*VS Code|without VS Code|not the VS Code' "$ROOT/AGENTS.md"
# DON'T require downloading VS Code IDE as the LSP path
if grep -qiE 'download Visual Studio Code|install VS Code (to|for) (get|use) (html|css)' "$ROOT/AGENTS.md" "$ROOT/README.md" 2>/dev/null; then
  echo "FAIL: docs require VS Code IDE for HTML/CSS LSP"
  exit 1
fi
# DON'T document suppressions as first resort
if grep -qiE 'prefer (eslint-disable|# noqa|@ts-ignore)' "$ROOT/AGENTS.md" "$ROOT/README.md" 2>/dev/null; then
  echo "FAIL: docs prefer suppressions"
  exit 1
fi
echo "PASS herdr-web LSP setup (standalone HTML/CSS, no VS Code IDE)"
