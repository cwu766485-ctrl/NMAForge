#!/usr/bin/env bash
set -euo pipefail
out=${PHASE3_OUT:?Set absolute output directory}
mkdir -p "$out/review"
PHASE2_DIRECTED_OUT="$out/review/ln32" PHASE2_PYTHON=${PHASE3_PYTHON:-python3.12} \
 bash tools/benchmark/phase2/run_directed.sh > "$out/review/directed-driver.log" 2>&1
vcs -full64 -sverilog +define+VCS -timescale=1ns/1ps -top tb_phase3_fault_contract \
 -Mdir="$out/review/fault-csrc" rtl/compute/common/ai_unsigned_divider.v \
 rtl/compute/common/ai_integer_sqrt.v rtl/compute/sfu/ai_tensor_sfu_math.v \
 rtl/compute/sfu/ai_tensor_sfu_core.v rtl/memory/ai_scratchpad.v rtl/memory/ai_spad_protection.v \
 dv/block/compute/sfu/tb/tb_phase3_fault_contract.sv \
 -o "$out/review/fault-simv" -l "$out/review/fault-compile.log" > "$out/review/fault-compile.stdout" 2>&1
"$out/review/fault-simv" > "$out/review/fault-run.log" 2>&1
grep -q '^PHASE3_FAULT_CONTRACT_PASS ' "$out/review/fault-run.log"
! grep -q 'Fatal:' "$out/review/fault-run.log"
${VERILATOR:-verilator} --lint-only --timing -Wno-fatal --top-module ai_tensor_sfu_core \
 rtl/compute/common/ai_unsigned_divider.v rtl/compute/common/ai_integer_sqrt.v \
 rtl/compute/sfu/ai_tensor_sfu_math.v rtl/compute/sfu/ai_tensor_sfu_core.v \
 > "$out/review/lint.log" 2>&1
