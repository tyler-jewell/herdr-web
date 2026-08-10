#!/usr/bin/env bash
# DON'T: commit secrets patterns in product tree.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if grep -R --include='*.md' --include='*.sh' --include='*.js' --include='*.py' --include='*.toml' \
  -nE 'BEGIN (RSA |OPENSSH )?PRIVATE KEY|api_key\s*=\s*["\047][a-zA-Z0-9]{16,}' \
  "$ROOT" 2>/dev/null | grep -v evals; then
  echo "FAIL: possible secrets"
  exit 1
fi
echo "no secrets patterns"
