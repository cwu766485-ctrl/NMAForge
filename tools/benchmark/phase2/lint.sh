#!/usr/bin/env bash
set -euo pipefail
out=${PHASE2_RUN:?Set absolute run directory}
verilator_bin=${VERILATOR:-verilator}
mkdir -p "$out"
"$verilator_bin" --lint-only --timing -Wno-fatal --top-module ai_tensor_sfu_core \
 rtl/compute/common/ai_unsigned_divider.v rtl/compute/common/ai_integer_sqrt.v \
 rtl/compute/sfu/ai_tensor_sfu_math.v rtl/compute/sfu/ai_tensor_sfu_core.v \
 > "$out/sfu-lint.log" 2>&1
"$verilator_bin" --lint-only --timing -Wno-fatal --top-module ai_tensor_sfu_core \
 rtl/compute/common/ai_unsigned_divider.v rtl/compute/common/ai_integer_sqrt.v \
 rtl/compute/sfu/ai_tensor_sfu_math.v "$out/baseline_sfu.v" \
 > "$out/sfu-lint-baseline.log" 2>&1
