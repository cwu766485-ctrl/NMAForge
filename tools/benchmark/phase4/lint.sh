#!/usr/bin/env bash
set -euo pipefail
out=${PHASE4_OUT:?Set absolute output directory}
base=${PHASE4_BASELINE:?Set baseline worktree}
v=${VERILATOR:-verilator}
root=$(pwd)
mkdir -p "$out"
for variant in baseline optimized; do
 src="$root"
 if [ "$variant" = baseline ]; then src="$base"; fi
 (cd "$src"; "$v" --lint-only --timing -Wno-fatal --top-module ai_tensor_matrix_core \
 rtl/compute/matrix/ai_tensor_matrix_array.sv rtl/compute/matrix/ai_tensor_matrix_datapath.v \
 rtl/compute/matrix/ai_tensor_matrix_core.v) > "$out/$variant-matrix.log" 2>&1
 (cd "$src/dv/subsystem/top_smoke/sim"; "$v" --lint-only --timing -Wno-fatal \
 -DVCS -DAI_SPAD_WORDS_PER_BANK=8192 --top-module ai_accel_top \
 -f ai_accel.f) > "$out/$variant-top.log" 2>&1
done
