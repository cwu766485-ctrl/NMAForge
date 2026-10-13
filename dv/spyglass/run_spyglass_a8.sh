#!/usr/bin/env bash
# Usage: ./run_spyglass_a8.sh {lint|cdc|rdc|all|dual_cdc|dual_rdc}
set -euo pipefail

goal="${1:-all}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$root/dv/spyglass"
cd "$workdir"

if ! command -v spyglass >/dev/null 2>&1; then
  echo "ERROR: SpyGlass is not on PATH. Load the site SpyGlass module first." >&2
  exit 127
fi

run_goal() {
  local sg_goal="$1"
  echo "[NMAForge] SpyGlass goal: $sg_goal"
  # `-batch` is required for bridge/nohup execution; without it SpyGlass can
  # wait for an interactive session after printing only its banner.
  spyglass -batch -project a8_static.prj -goal "$sg_goal"
}

run_dual_goal() {
  local sg_goal="$1"
  echo "[NMAForge] SpyGlass dual-clock goal: $sg_goal"
  spyglass -batch -project cdc_dual_clock.prj -goal "$sg_goal"
}

case "$goal" in
  lint) run_goal lint/lint_rtl ;;
  cdc)  run_goal cdc/cdc_setup; run_goal cdc/cdc_verify_struct ;;
  rdc)  run_goal rdc/rdc_verify_struct ;;
  dual_cdc) run_dual_goal cdc/cdc_setup; run_dual_goal cdc/cdc_verify_struct ;;
  dual_rdc) run_dual_goal rdc/rdc_verify_struct ;;
  all)  run_goal lint/lint_rtl; run_goal cdc/cdc_setup; run_goal cdc/cdc_verify_struct; run_goal rdc/rdc_verify_struct ;;
  *)
    echo "Usage: $0 {lint|cdc|rdc|all|dual_cdc|dual_rdc}" >&2
    exit 2
    ;;
esac
