#!/usr/bin/env bash
# DO: this layer has at most 10 compliance evals.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
n=0
for f in "$ROOT"/evals/[0-9][0-9]-*.sh; do
  [[ -e "$f" ]] || continue
  n=$((n + 1))
done
test "$n" -le 10
test "$n" -ge 1
echo "evals count=$n (<=10)"
