#!/usr/bin/env bash
# DO: ship a valid herdr-plugin.toml with required fields.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
f="$ROOT/herdr-plugin.toml"
test -f "$f"
grep -q '^id = ' "$f"
grep -q '^name = ' "$f"
grep -q '^version = ' "$f"
grep -q '^min_herdr_version = ' "$f"
grep -q 'tyler-jewell.herdr-web' "$f"
echo "manifest ok"
