#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
rtl_root=${PHASE4_RTL_ROOT:-$root}
out=${PHASE4_OUT:?Set absolute output directory}
mkdir -p "$out/top"
cd "$rtl_root/dv/subsystem/top_smoke/sim"
vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps +define+VCS \
 +define+AI_REPRESENTATIVE_LONG_TASK +define+AI_SPAD_WORDS_PER_BANK=${PHASE4_SPAD_WORDS:-8192} \
 +incdir+"$root/dv/subsystem/top_smoke/fixtures" \
 +incdir+../../../block/control/agent +incdir+../../../block/dma/agent \
 -Mdir="$out/top/csrc" -top tb_ai_accel_smoke -f ai_accel.f \
 ../../../block/dma/env/axi_memory_model.sv "$root/dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv" \
 -o "$out/top/simv" -l "$out/top/compile.log" > "$out/top/compile.stdout" 2>&1
