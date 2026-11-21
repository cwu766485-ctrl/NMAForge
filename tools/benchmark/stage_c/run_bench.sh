#!/usr/bin/env bash
set -euo pipefail
run=${STAGE_C_BENCH_OUT:?Set fresh absolute directory}
python=${STAGE_C_PYTHON:-python3}
test ! -e "$run"
"$python" tools/benchmark/stage_c/prepare_bench.py --out "$run"
vcs -full64 -sverilog -timescale=1ns/1ps -Mdir="$run/csrc" \
 -top tb_stage_c_matched_service rtl/compute/matrix/ai_tensor_matrix_array.sv \
 "$run/tb_service.sv" -o "$run/simv" -l "$run/compile.log" > "$run/compile.stdout" 2>&1
TINYNPU_GEMM_OUT="$run/tiny" bash "$run/build_tiny.sh"
"$python" tools/benchmark/stage_c/bench.py --run "$run"
