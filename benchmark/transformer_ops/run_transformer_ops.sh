#!/usr/bin/env bash
# Matched Transformer-operator benchmark: NMAForge SFU vs pinned TinyNPU engines.
# Usage: benchmark/transformer_ops/run_transformer_ops.sh [OUT_DIR]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-${TRANSFORMER_OPS_OUT:-/tmp/nmaforge_transformer_ops}}"
PYTHON="${PYTHON:-python3.11}"
SEED="${SEED:-20261125}"
TINY_NPU_ROOT="${TINY_NPU_ROOT:-/tmp/harishsg993010-tiny-NPU-ops}"
TINY_SHA=8216c22b762011aa20c05fc2768423fd12dda59d
VCS="${VCS:-vcs -full64 -sverilog -licwait 1 -timescale=1ns/1ps}"
mkdir -p "$OUT"

if [ ! -d "$TINY_NPU_ROOT/.git" ]; then
  git clone -q https://github.com/harishsg993010/tiny-NPU "$TINY_NPU_ROOT"
fi
git -C "$TINY_NPU_ROOT" checkout -q "$TINY_SHA"
test "$(git -C "$TINY_NPU_ROOT" rev-parse HEAD)" = "$TINY_SHA"
test -z "$(git -C "$TINY_NPU_ROOT" status --porcelain --untracked-files=no)"

"$PYTHON" "$HERE/gen_vectors.py" --seed "$SEED" --out-dir "$OUT"

# NMAForge SFU: production build (streaming fast path) and the legacy-only
# build (+define+AI_SFU_LEGACY_ONLY).  Calibration against the archived
# Product Top SFU log uses the legacy build.
R="$ROOT/rtl"
SFU_SRC=("$R/compute/common/ai_unsigned_divider.v" "$R/compute/common/ai_integer_sqrt.v"
  "$R/compute/sfu/ai_tensor_sfu_math.v" "$R/compute/sfu/ai_tensor_sfu_stream.v"
  "$R/compute/sfu/ai_tensor_sfu_core.v" "$HERE/tb_nma_sfu_ops_perf.sv")
$VCS -Mdir="$OUT/nma_csrc" -top tb_nma_sfu_ops_perf "${SFU_SRC[@]}" \
  -o "$OUT/nma_simv" -l "$OUT/nma_compile.log" >/dev/null
$VCS +define+AI_SFU_LEGACY_ONLY -Mdir="$OUT/nma_legacy_csrc" -top tb_nma_sfu_ops_perf \
  "${SFU_SRC[@]}" -o "$OUT/nma_legacy_simv" -l "$OUT/nma_legacy_compile.log" >/dev/null
"$OUT/nma_legacy_simv" +VECTORS="$OUT/nma_calibration.txt" -l "$OUT/nma_calibration.log" >/dev/null
"$OUT/nma_legacy_simv" +VECTORS="$OUT/nma_vectors.txt" -l "$OUT/nma_legacy_run.log" >/dev/null
"$OUT/nma_simv" +VECTORS="$OUT/nma_vectors.txt" -l "$OUT/nma_run.log" >/dev/null
grep -q '^NMA_OP_PERF_PASS cases=20$' "$OUT/nma_legacy_run.log"
grep -q '^NMA_OP_PERF_PASS cases=20$' "$OUT/nma_run.log"

# TinyNPU engines (pinned source; two simulation-only VCS adaptations).
# 1. sram_dp: Round33 adapter, identical behaviour with always instead of
#    always_ff because VCS rejects the upstream dual-process write pattern.
# 2. softmax_engine: the upstream file uses fp16_assembled before its
#    declaration (accepted by Verilator, rejected by VCS).  The copy only moves
#    that declaration to module scope ahead of first use.
T="$TINY_NPU_ROOT/rtl"
ADAPT="$OUT/tiny_adapt"
mkdir -p "$ADAPT"
sha256sum "$T/ops/softmax_engine.sv" > "$ADAPT/softmax_engine.upstream.sha256"
awk '
  /^[[:space:]]*logic \[15:0\] fp16_assembled;[[:space:]]*$/ { next }
  { print }
  /^[[:space:]]*state_t state, state_nxt;/ && !done { print "    logic [15:0] fp16_assembled;  // VCS: hoisted declaration"; done=1 }
' "$T/ops/softmax_engine.sv" > "$ADAPT/softmax_engine.sv"
test "$(grep -c 'logic \[15:0\] fp16_assembled;' "$ADAPT/softmax_engine.sv")" = 1
diff "$T/ops/softmax_engine.sv" "$ADAPT/softmax_engine.sv" > "$ADAPT/softmax_engine.diff" || true

$VCS -Mdir="$OUT/tiny_csrc" +incdir+"$T/pkg" -top tb_tiny_ops_perf \
  "$T/pkg/npu_pkg.sv" "$T/pkg/isa_pkg.sv" "$T/pkg/fixed_pkg.sv" "$T/graph/fp16_utils.sv" \
  "$ROOT/benchmark/performance_dominance/round33/evidence/source/tiny_sram_dp_sim.sv" \
  "$T/gemm/mac_int8.sv" "$T/gemm/mac_fp16.sv" "$T/gemm/pe.sv" "$T/gemm/systolic_array.sv" \
  "$T/ops/vec_engine.sv" "$T/ops/reduce_max.sv" "$T/ops/reduce_sum.sv" "$T/ops/exp_lut.sv" \
  "$T/ops/recip_lut.sv" "$T/graph/graph_exp_lut_fp16.sv" "$ADAPT/softmax_engine.sv" \
  "$T/ops/mean_var_engine.sv" "$T/ops/rsqrt_lut.sv" "$T/graph/graph_rsqrt_lut_fp16.sv" \
  "$T/ops/layernorm_engine.sv" "$T/ops/gelu_lut.sv" "$T/ops/gelu_engine.sv" "$T/ops/silu_lut.sv" \
  "$TINY_NPU_ROOT/sim/verilator/engine_tb_top.sv" "$HERE/tb_tiny_ops_perf.sv" \
  -o "$OUT/tiny_simv" -l "$OUT/tiny_compile.log" >/dev/null
"$OUT/tiny_simv" +VECTORS="$OUT/tiny_vectors.txt" +OUT="$OUT/tiny_outputs.txt" \
  -l "$OUT/tiny_run.log" >/dev/null
grep -q '^TINY_OP_PERF_DONE cases=16$' "$OUT/tiny_run.log"

"$PYTHON" "$HERE/summarize.py" --out-dir "$OUT"
