#!/usr/bin/env bash
set -euo pipefail
run=${PHASE1_OUT:?Set absolute output directory}
mkdir -p "$run/top"
cd dv/subsystem/top_smoke/sim
vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps +define+VCS \
 +define+AI_REPRESENTATIVE_LONG_TASK +define+AI_SPAD_WORDS_PER_BANK=8192 \
 +incdir+../../../block/control/agent +incdir+../../../block/dma/agent +incdir+../fixtures \
 -Mdir="$run/top/csrc" -top tb_ai_accel_smoke -f ai_accel.f \
 ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
 -o "$run/top/simv" -l "$run/top/compile.log" > "$run/top/compile.stdout" 2>&1
