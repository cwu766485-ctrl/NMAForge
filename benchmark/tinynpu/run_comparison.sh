#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PINNED_SHA=8216c22b762011aa20c05fc2768423fd12dda59d
SEED="${SEED:-20261029}"
RUN_DATE="$(date +%Y%m%d)"
RUN_ID="${BENCH_RUN_ID:-TINY-COMPARE-${RUN_DATE}-S${SEED}}"
OUT_DIR="${TINYNPU_BENCH_OUT:-/tmp/nmaforge_tinynpu_bench_${RUN_DATE}_${SEED}}"
WORK_ROOT="${TINYNPU_WORK_ROOT:-$OUT_DIR/reference}"
TINY_NPU_ROOT="${TINY_NPU_ROOT:-$WORK_ROOT/source}"
VERILATOR="${VERILATOR:-verilator}"
PYTHON="${PYTHON:-python3}"
VCS_VERSION="${VCS_VERSION:-}"

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

if ! "$PYTHON" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)'; then
    echo "benchmark Python must be version 3.9 or newer; set PYTHON=/path/to/python" >&2
    exit 2
fi
if ! "$PYTHON" -c 'import onnx, numpy' >/dev/null; then
    echo "benchmark Python requires onnx and numpy; install the pinned TinyNPU Python requirements" >&2
    exit 2
fi
NMA_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
mkdir -p "$OUT_DIR"

make -C "$REPO_ROOT/dv/block/compute/matrix/sim" \
    matrix-size-benchmark SEED="$SEED" \
    BENCH_OUT_DIR="$OUT_DIR/nma_size" > "$OUT_DIR/nma_size_make.log" 2>&1

make -C "$REPO_ROOT/dv/block/compute/matrix/sim" \
    tinynpu-matched-benchmark SEED="$SEED" \
    TINY_MATCH_OUT="$OUT_DIR/nma_match8" > "$OUT_DIR/nma_match8_make.log" 2>&1

make -C "$REPO_ROOT/dv/block/compute/matrix/sim" \
    core-random-compile SEED="$SEED" PHYSICAL_ARRAY_SIZE=16 \
    CORE_OUT_DIR="$OUT_DIR/nma_match16" > "$OUT_DIR/nma_match16_compile.log" 2>&1
"$OUT_DIR/nma_match16/simv" +SEED="$SEED" +TINY_NPU_MATCH_MULTI \
    -l "$OUT_DIR/nma_match16/run.log" > "$OUT_DIR/nma_match16_stdout.log" 2>&1
grep -q '^MATRIX_CORE_CASE_PASS id=105 shape_mnk=16,16,16 ' "$OUT_DIR/nma_match16/run.log"
grep -q '^MATRIX_CORE_CASE_PASS id=106 shape_mnk=16,16,32 ' "$OUT_DIR/nma_match16/run.log"
grep -q '^MATRIX_CORE_CASE_PASS id=107 shape_mnk=32,32,64 ' "$OUT_DIR/nma_match16/run.log"
grep -q '^MATRIX_TINY_NPU_MATCH_MULTI_PASS .*cases=3 ' "$OUT_DIR/nma_match16/run.log"

TINY_NPU_ROOT="$TINY_NPU_ROOT" TINYNPU_WORK_ROOT="$WORK_ROOT" \
    TINYNPU_GEMM_OUT="$OUT_DIR/tiny_gemm" VERILATOR="$VERILATOR" \
    JOBS="${JOBS:-4}" "$SCRIPT_DIR/run_tinynpu_gemm.sh" > "$OUT_DIR/tiny_gemm_script.log" 2>&1
TINY_NPU_ROOT="$TINY_NPU_ROOT" TINYNPU_WORK_ROOT="$WORK_ROOT" \
    TINYNPU_CNN_OUT="$OUT_DIR/tiny_cnn" PYTHON="$PYTHON" \
    VERILATOR="$VERILATOR" JOBS="${JOBS:-4}" \
    "$SCRIPT_DIR/run_tinynpu_cnn.sh" > "$OUT_DIR/tiny_cnn_script.log" 2>&1

make -C "$REPO_ROOT/dv/subsystem/top_smoke/sim" ai_tinynpu_cnn_match \
    AI_TINYNPU_CNN_RUN="$OUT_DIR/nma_cnn" \
    AI_TINYNPU_CNN_PYTHON="$PYTHON" \
    AI_TINYNPU_CNN_MODEL="$TINY_NPU_ROOT/models/conv1x_mini.onnx" \
    AI_TINYNPU_CNN_GOLDEN="$OUT_DIR/tiny_cnn/graph_cnn/golden.bin" \
    > "$OUT_DIR/nma_cnn_make.log" 2>&1

VERILATOR_VERSION="$("$VERILATOR" --version | head -1)"
PYTHON_VERSION="$("$PYTHON" -c 'import sys; print(sys.version.split()[0])')"
NUMPY_VERSION="$("$PYTHON" -c 'import numpy; print(numpy.__version__)')"
ONNX_VERSION="$("$PYTHON" -c 'import onnx; print(onnx.__version__)')"
if [[ -z "$VCS_VERSION" ]]; then
    VCS_VERSION="$(grep -m1 -o 'Version V-[^ ]*' "$OUT_DIR/nma_match16/compile.log" | awk '{print $2}')"
fi
if [[ -z "$VCS_VERSION" ]]; then
    echo "could not determine VCS version from compile log" >&2
    exit 3
fi
"$PYTHON" "$SCRIPT_DIR/collect_results.py" \
    --nma-sha "$NMA_SHA" --tiny-sha "$TINY_SHA" --seed "$SEED" \
    --run-id "$RUN_ID" --size-root "$OUT_DIR/nma_size" \
    --match8 "$OUT_DIR/nma_match8/run.log" \
    --match16 "$OUT_DIR/nma_match16/run.log" \
    --tiny-gemm "$OUT_DIR/tiny_gemm/run.log" \
    --tiny-engine "$OUT_DIR/tiny_gemm/engine_regression.log" \
    --tiny-cnn "$OUT_DIR/tiny_cnn/run.log" \
    --nma-cnn "$OUT_DIR/nma_cnn/run.log" \
    --nma-cnn-manifest "$OUT_DIR/nma_cnn/workload/nma_cnn_manifest.json" \
    --verilator-version "$VERILATOR_VERSION" --vcs-version "$VCS_VERSION" \
    --python-version "$PYTHON_VERSION" --numpy-version "$NUMPY_VERSION" \
    --onnx-version "$ONNX_VERSION" \
    --out-csv "$OUT_DIR/gemm_results.csv" \
    --out-cnn-csv "$OUT_DIR/cnn_results.csv" \
    --out-cnn-json "$OUT_DIR/cnn_summary.json" \
    --out-json "$OUT_DIR/benchmark_summary.json"
cp "$OUT_DIR/gemm_results.csv" "$SCRIPT_DIR/gemm_results.csv"
cp "$OUT_DIR/cnn_results.csv" "$SCRIPT_DIR/cnn_results.csv"
cp "$OUT_DIR/benchmark_summary.json" "$SCRIPT_DIR/benchmark_summary.json"
cp "$OUT_DIR/cnn_summary.json" "$SCRIPT_DIR/cnn_summary.json"
printf 'BENCHMARK_PASS run_id=%s nmaforge_sha=%s tinynpu_sha=%s output=%s\n' \
    "$RUN_ID" "$NMA_SHA" "$TINY_SHA" "$OUT_DIR"
