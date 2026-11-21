#!/usr/bin/env bash
set -euo pipefail
run=${STAGE_C_OUT:?Set a fresh absolute run directory}
python=${STAGE_C_PYTHON:-python3}
mkdir -p "$run"
"$python" tools/benchmark/stage_c/generate.py --model benchmark/research/stage_c/models/h32_l2_int8.json --out "$run/h32"
(
 cd dv/subsystem/top_smoke/sim
 vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
 +define+VCS +define+AI_REPRESENTATIVE_LONG_TASK +define+AI_SPAD_WORDS_PER_BANK=8192 \
 +incdir+../../../block/control/agent +incdir+../../../block/dma/agent +incdir+../fixtures \
 -Mdir="$run/csrc" -top tb_ai_accel_smoke -f ai_accel.f \
 ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
 -o "$run/simv" -l "$run/compile.log" > "$run/compile.stdout" 2>&1
)
"$run/simv" +AI_STAGE_C_TRANSFORMER +AI_STAGE_C_DIR="$run/h32" +AI_STAGE_C_STAGES=12 \
 +STAGE_A_PROFILE="$run/h32/profile" +AI_RANDOM_CASES=0 +AI_SEED=20261110 +ACLK_PERIOD_NS=4 \
 -l "$run/h32/top.log" > "$run/h32/stdout.log" 2>&1
rg -q '^STAGE_C_TOP_PASS' "$run/h32/top.log"
