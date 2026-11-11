#!/usr/bin/env bash
set -euo pipefail
out=${PHASE2_DIRECTED_OUT:?Set output}
mkdir -p "$out"
${PHASE2_PYTHON:-python3.12} tools/benchmark/phase2/generate_ln32.py --out "$out"
vcs -full64 -sverilog -timescale=1ns/1ps -top tb_phase2_ln32 -Mdir="$out/csrc" \
 rtl/compute/common/ai_unsigned_divider.v rtl/compute/common/ai_integer_sqrt.v \
 rtl/compute/sfu/ai_tensor_sfu_math.v "${PHASE2_SFU_SOURCE:-rtl/compute/sfu/ai_tensor_sfu_core.v}" \
 dv/block/compute/sfu/tb/tb_phase2_ln32.sv -o "$out/simv" -l "$out/compile.log" > "$out/compile.stdout" 2>&1
"$out/simv" +PHASE2_DIR="$out" > "$out/run.log" 2>&1
grep -q '^PHASE2_LN32_DIRECTED_PASS ' "$out/run.log"
if grep -q 'Fatal:' "$out/run.log";then exit 1;fi
