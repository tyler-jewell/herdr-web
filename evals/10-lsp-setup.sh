#!/usr/bin/env bash
# DO: herdr-web has LSP project setup for languages in use + AGENTS rule 13 pointer.
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
grep -qiE 'HTML|vscode-html' "$ROOT/AGENTS.md"
grep -qiE 'CSS|vscode-css' "$ROOT/AGENTS.md"
# DON'T document suppressions as first resort
if grep -qiE 'prefer (eslint-disable|# noqa|@ts-ignore)' "$ROOT/AGENTS.md" "$ROOT/README.md" 2>/dev/null; then
  echo "FAIL: docs prefer suppressions"
  exit 1
fi
echo "PASS herdr-web LSP setup"
