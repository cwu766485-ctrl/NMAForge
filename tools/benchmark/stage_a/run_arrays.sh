#!/usr/bin/env bash
set -euo pipefail
run=${STAGE_A_ARRAY_OUT:?Set a fresh absolute output directory}
python=${STAGE_A_PYTHON:-python3.12}
: "${TINY_NPU_ROOT:?Set the clean pinned TinyNPU source checkout}"
: "${VERILATOR:?Set the Verilator executable}"
test ! -e "$run"
mkdir -p "$run"
vcs -full64 -sverilog -timescale=1ns/1ps -Mdir="$run/csrc" \
 -top tb_stage_a_matched_array rtl/compute/matrix/ai_tensor_matrix_array.sv \
 tools/benchmark/stage_a/tb_matched_array.sv -o "$run/simv" -l "$run/compile.log"
"$run/simv" -l "$run/nma.log"
TINYNPU_GEMM_OUT="$run/tiny" JOBS=2 bash benchmark/tinynpu/run_tinynpu_gemm.sh
"$python" tools/benchmark/generate_shared_h16_qkv.py \
 --model benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json --out "$run/qkv"
for op in q k v; do
 "$run/simv" +SHARED_OPERANDS="$run/qkv/$op.memh" \
  +SHARED_OUTPUT="$run/qkv/nma_$op.memh" -l "$run/qkv/nma_$op.log"
 SHARED_OPERANDS="$run/qkv/$op.memh" SHARED_OUTPUT="$run/qkv/tiny_$op.memh" \
  "$run/tiny/obj/Vengine_tb_top" > "$run/qkv/tiny_$op.log"
done
"$python" tools/benchmark/check_shared_h16_qkv.py --run "$run/qkv"
