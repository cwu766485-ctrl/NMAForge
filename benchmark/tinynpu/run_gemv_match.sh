#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PINNED_SHA=8216c22b762011aa20c05fc2768423fd12dda59d
SEED="${SEED:-20261029}"
RUN_DATE="$(date +%Y%m%d)"
RUN_ID="${BENCH_RUN_ID:-GEMV-MATCH-${RUN_DATE}-S${SEED}}"
OUT_DIR="${GEMV_BENCH_OUT:-/tmp/nmaforge_gemv_match_${RUN_DATE}_${SEED}}"
WORK_ROOT="${TINYNPU_WORK_ROOT:-$OUT_DIR/reference}"
TINY_NPU_ROOT="${TINY_NPU_ROOT:-$WORK_ROOT/source}"
VERILATOR="${VERILATOR:-verilator}"
PYTHON="${PYTHON:-python3}"
VCS_VERSION="${VCS_VERSION:-V-2023.12-SP1_Full64}"

if [[ ! -d "$TINY_NPU_ROOT/.git" ]]; then
    mkdir -p "$(dirname "$TINY_NPU_ROOT")"
    git clone --filter=blob:none --no-checkout \
        https://github.com/harishsg993010/tiny-NPU.git "$TINY_NPU_ROOT"
    git -C "$TINY_NPU_ROOT" fetch --depth=1 origin "$PINNED_SHA"
    git -C "$TINY_NPU_ROOT" checkout --detach "$PINNED_SHA"
fi
TINY_SHA="$(git -C "$TINY_NPU_ROOT" rev-parse HEAD)"
if [[ "$TINY_SHA" != "$PINNED_SHA" ]]; then
    echo "TinyNPU source mismatch: expected $PINNED_SHA, got $TINY_SHA" >&2
    exit 2
fi
NMA_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
mkdir -p "$OUT_DIR"

make -C "$REPO_ROOT/dv/block/compute/matrix/sim" product-gemv-test \
    SEED="$SEED" PHYSICAL_ARRAY_SIZE=16 OUTSTANDING_DEPTH=4 \
    NEXT_K_PREFETCH_ENABLE=1 GEMV_B_TILE_CACHE_ENABLE=1 \
    CORE_OUT_DIR="$OUT_DIR/nmaforge" > "$OUT_DIR/nmaforge_make.log" 2>&1

TINY_NPU_ROOT="$TINY_NPU_ROOT" TINYNPU_WORK_ROOT="$WORK_ROOT" \
    TINYNPU_GEMM_OUT="$OUT_DIR/tinynpu" VERILATOR="$VERILATOR" \
    JOBS="${JOBS:-4}" bash "$SCRIPT_DIR/run_tinynpu_gemm.sh" \
    > "$OUT_DIR/tinynpu_script.log" 2>&1

"$PYTHON" "$SCRIPT_DIR/summarize_gemv_compare.py" \
    --nma-sha "$NMA_SHA" --tiny-sha "$TINY_SHA" --seed "$SEED" \
    --run-id "$RUN_ID" --nma-log "$OUT_DIR/nmaforge/product_gemv.log" \
    --tiny-log "$OUT_DIR/tinynpu/run.log" --vcs-version "$VCS_VERSION" \
    --verilator-version "$($VERILATOR --version | head -1)" \
    --out-csv "$OUT_DIR/gemv_results.csv" \
    --out-json "$OUT_DIR/gemv_summary.json"
cp "$OUT_DIR/gemv_results.csv" "$SCRIPT_DIR/gemv_results.csv"
cp "$OUT_DIR/gemv_summary.json" "$SCRIPT_DIR/gemv_summary.json"
printf 'GEMV_COMPARE_PASS run_id=%s nmaforge_sha=%s tinynpu_sha=%s output=%s\n' \
    "$RUN_ID" "$NMA_SHA" "$TINY_SHA" "$OUT_DIR"
