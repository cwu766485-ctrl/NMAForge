#!/usr/bin/env bash
set -euo pipefail
run=${STAGE_B_CONTRACT_OUT:?Set a fresh absolute output directory}
test ! -e "$run"
mkdir -p "$run"
vcs -full64 -sverilog -timescale=1ns/1ps +define+VCS \
 -Mdir="$run/csrc" -top tb_stage_b_fault_contract \
 rtl/memory/ai_scratchpad.v rtl/memory/ai_spad_protection.v \
 rtl/memory/ai_spad_arbiter.v rtl/top/fabric/memory/ai_spad_response_demux.v \
 rtl/top/fabric/memory/ai_accel_spad_subsystem.v \
 rtl/top/fabric/memory/ai_accel_memory_fabric.v \
 rtl/compute/common/ai_unsigned_divider.v rtl/compute/common/ai_integer_sqrt.v \
 rtl/compute/sfu/ai_tensor_sfu_math.v rtl/compute/sfu/ai_tensor_sfu_core.v \
 tools/benchmark/stage_b/tb_fault_contract.sv \
 -o "$run/simv" -l "$run/compile.log"
"$run/simv" -l "$run/run.log"
grep -q '^STAGE_B_GATE0_RTL_PASS ' "$run/run.log"
