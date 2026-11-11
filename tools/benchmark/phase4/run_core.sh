#!/usr/bin/env bash
set -euo pipefail
out=${PHASE4_OUT:?Set absolute output directory}
mkdir -p "$out"
vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
 +define+PHASE4_WRITEBACK_TEST +define+MATRIX_PINGPONG_ENABLE=${PHASE4_ENABLE:-1} \
 +incdir+dv/block/compute/matrix/tb \
 -Mdir="$out/csrc" -top tb_ai_tensor_matrix_core_random \
 rtl/compute/matrix/ai_tensor_matrix_array.sv rtl/compute/matrix/ai_tensor_matrix_datapath.v \
 rtl/compute/matrix/ai_tensor_matrix_core.v dv/block/compute/matrix/tb/tb_ai_tensor_matrix_core_random.sv \
 -o "$out/simv" -l "$out/compile.log" > "$out/build.stdout" 2>&1
for seed in 20261021 20261022 20261023; do
 "$out/simv" +SEED="$seed" +PHASE4_WRITEBACK_ONLY > "$out/directed-$seed.log" 2>&1
 grep -q '^PHASE4_WRITEBACK_RTL_PASS ' "$out/directed-$seed.log"
 "$out/simv" +SEED="$seed" > "$out/random-$seed.log" 2>&1
 grep -q '^MATRIX_CORE_RANDOM_PASS cases=18 faults=35 ' "$out/random-$seed.log"
 "$out/simv" +SEED="$seed" +MATRIX_V2_OPCODE_FAULT_ONLY > "$out/opcode-fault-$seed.log" 2>&1
 # The current bench uses the documented plusarg checked below by its marker.
 grep -q '^MATRIX_V2_OPCODE_FAULT_PASS ' "$out/opcode-fault-$seed.log"
done
