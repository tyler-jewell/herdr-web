#!/usr/bin/env bash
# DO: ports.toml claims herdr-web; docs/serve do not teach sticky hardcoded URL alone (rule 22).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -f "$ROOT/ports.toml"
grep -q '\[\[port\]\]' "$ROOT/ports.toml"
grep -q 'herdr-web' "$ROOT/ports.toml"
grep -q 'ports.toml' "$ROOT/scripts/serve.sh"
grep -q 'PORTS_FILE\|claim_from_ports' "$ROOT/scripts/serve.sh"
grep -qi 'ports.toml\|rule 22' "$ROOT/AGENTS.md"
# DON'T sticky-document a fixed host:port as the only user instruction
if grep -nE 'http://127\.0\.0\.1:8765|Open \*\*http://127\.0\.0\.1:' "$ROOT/README.md" 2>/dev/null; then
  echo "FAIL: sticky hardcoded local URL in README"
  exit 1
fi
# bridge/serve have no hardcoded default port 8765
if grep -nE 'HERDR_WEB_PORT", "8765"|PORT:-8765|default 8765' "$ROOT/cmd/bridge/main.go" "$ROOT/scripts/serve.sh" 2>/dev/null; then
  echo "FAIL: hardcoded 8765 default still present"
  exit 1
fi
echo "PASS ports.toml claim + no sticky hardcoded docs URL"
