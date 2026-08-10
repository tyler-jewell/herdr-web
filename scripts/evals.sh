#!/usr/bin/env bash
# List or run compliance evals for this isolatable product (≤10).
# When HERDR_EVALS_LAYERS is set, also runs linked methodology layers.
# Exit: 0 all pass, 1 fail, 2 usage.
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EVALS_DIR="${ROOT}/evals"
CMD="${1:-list}"

usage() {
  cat <<EOF
evals — herdr-web compliance evals (do/don't policy, not challenges)

USAGE
  evals.sh list
  evals.sh run

Layers: this product always; optional HERDR_EVALS_LAYERS=path:path (tyler-jewell layers)
Max 10 evals per layer directory.
EOF
}

case "$CMD" in
  -h | --help) usage; exit 0 ;;
  list | run) ;;
  *)
    echo "error: unknown command: $CMD"
    usage
    exit 2
    ;;
esac

list_layer() {
  local dir="$1"
  local name="$2"
  local n=0
  echo "layer: ${name}"
  echo "path: ${dir}"
  if [[ ! -d "$dir" ]]; then
    echo "empty: 0 evals (missing dir)"
    return 0
  fi
  local f
  for f in "$dir"/[0-9][0-9]-*.sh; do
    [[ -e "$f" ]] || continue
    n=$((n + 1))
    echo "  - $(basename "$f")"
  done
  if [[ "$n" -eq 0 ]]; then
    echo "empty: 0 evals"
  else
    echo "count: $n"
  fi
  if [[ "$n" -gt 10 ]]; then
    echo "error: layer ${name} has $n evals (max 10)"
    return 1
  fi
  return 0
}

run_layer() {
  local dir="$1"
  local name="$2"
  local n=0 fail=0
  echo "==> run layer ${name}"
  if [[ ! -d "$dir" ]]; then
    echo "skip: missing $dir"
    return 0
  fi
  local f
  for f in "$dir"/[0-9][0-9]-*.sh; do
    [[ -e "$f" ]] || continue
    n=$((n + 1))
    if [[ "$n" -gt 10 ]]; then
      echo "FAIL: more than 10 evals in $name"
      return 1
    fi
    echo "--- $(basename "$f")"
    if bash "$f"; then
      echo "PASS $(basename "$f")"
    else
      echo "FAIL $(basename "$f")"
      fail=$((fail + 1))
    fi
  done
  if [[ "$n" -eq 0 ]]; then
    echo "empty: 0 evals in $name"
  fi
  echo "layer_summary: ${name} ran=$n fail=$fail"
  [[ "$fail" -eq 0 ]]
}

if [[ "$CMD" == "list" ]]; then
  list_layer "$EVALS_DIR" "herdr-web"
  if [[ -n "${HERDR_EVALS_LAYERS:-}" ]]; then
    IFS=':' read -r -a layers <<<"$HERDR_EVALS_LAYERS"
    for L in "${layers[@]}"; do
      [[ -z "$L" ]] && continue
      list_layer "$L" "$(basename "$(dirname "$L")")/$(basename "$L")"
    done
  fi
  exit 0
fi

# run
fail_total=0
run_layer "$EVALS_DIR" "herdr-web" || fail_total=$((fail_total + 1))
if [[ -n "${HERDR_EVALS_LAYERS:-}" ]]; then
  IFS=':' read -r -a layers <<<"$HERDR_EVALS_LAYERS"
  for L in "${layers[@]}"; do
    [[ -z "$L" ]] && continue
    run_layer "$L" "$(basename "$(dirname "$L")")/$(basename "$L")" || fail_total=$((fail_total + 1))
  done
fi
echo "total_fail_layers=$fail_total"
[[ "$fail_total" -eq 0 ]]
