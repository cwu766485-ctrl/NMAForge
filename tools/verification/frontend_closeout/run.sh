#!/usr/bin/env bash
# Run in a clean, isolated checkout. Generated outputs stay outside git.
set -euo pipefail
: "${CLOSEOUT_OUT:?absolute external output directory}"
: "${CLOSEOUT_PYTHON:?Python 3.12 with numpy}"
root=$(git rev-parse --show-toplevel)
cd "$root"
mkdir -p "$CLOSEOUT_OUT"
git rev-parse HEAD > "$CLOSEOUT_OUT/source.sha"
PHASE4_OUT="$CLOSEOUT_OUT" bash tools/benchmark/phase4/build_top.sh
"$CLOSEOUT_PYTHON" tools/benchmark/phase2/run_top.py --out "$CLOSEOUT_OUT" > "$CLOSEOUT_OUT/workloads.log" 2>&1
for mode in normal backpressure; do
 args=(); if [ "$mode" = backpressure ]; then args+=(--backpressure); fi
 "$CLOSEOUT_PYTHON" tools/benchmark/final_ab/run.py --out "$CLOSEOUT_OUT/system-$mode" --simv "$CLOSEOUT_OUT/top/simv" "${args[@]}" > "$CLOSEOUT_OUT/system-$mode.log" 2>&1
done
GATE1_OUT="$CLOSEOUT_OUT/dma" bash tools/benchmark/output_dma_gate1/run.sh
PHASE4_OUT="$CLOSEOUT_OUT/matrix" bash tools/benchmark/phase4/run_core.sh
"$CLOSEOUT_PYTHON" tools/benchmark/arch_opt_round2/check_mapper.py
