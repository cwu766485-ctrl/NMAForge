#!/usr/bin/env bash
set -euo pipefail
# Run from repository root. Use a fresh output path for every source/configuration.
root=$(pwd)
run=${R28_OUT:?Set R28_OUT to a fresh absolute output directory}
python=${R28_PYTHON:-python3.12}
mkdir -p "$run"
(
 cd dv/subsystem/top_smoke/sim
 vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
  +define+VCS +define+AI_REPRESENTATIVE_LONG_TASK +define+AI_SPAD_WORDS_PER_BANK=8192 \
  +incdir+../../../block/control/agent +incdir+../../../block/dma/agent +incdir+../fixtures \
  -Mdir="$run/csrc" -top tb_ai_accel_smoke -f ai_accel.f \
  ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
  -o "$run/simv" -l "$run/compile.log"
)
"$python" "$root/sw/tools/run_tiny_gpt2_persistent_session.py" \
 --model "$root/benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json" \
 --simv "$run/simv" --out "$run/session" --seed 20261123 --steps 8
