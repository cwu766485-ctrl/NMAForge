#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${COMPUTE_PERF_OUT:-/tmp/nmaforge_compute_performance_$(date +%Y%m%d_%H%M%S)}"
SEEDS="${SEEDS:-20261025 20261026 20261027}"
PYTHON="${PYTHON:-python3}"

mkdir -p "$OUT_DIR"
for seed in $SEEDS; do
    make -C "$REPO_ROOT/dv/block/compute/matrix/sim" \
        matrix-size-benchmark SEED="$seed" \
        BENCH_OUT_DIR="$OUT_DIR/size_$seed" > "$OUT_DIR/size_${seed}_make.log" 2>&1
    make -C "$REPO_ROOT/dv/block/compute/matrix/sim" \
        matrix-config-comparison SEED="$seed" \
        MATRIX_CONFIG_OUT="$OUT_DIR/ablation_$seed" \
        > "$OUT_DIR/ablation_${seed}_make.log" 2>&1
done

"$PYTHON" "$SCRIPT_DIR/summarize_compute_performance.py" --out-dir "$OUT_DIR"
printf 'COMPUTE_PERFORMANCE_PASS seeds=%s output=%s\n' "$SEEDS" "$OUT_DIR"
