#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PINNED_SHA=8216c22b762011aa20c05fc2768423fd12dda59d
WORK_ROOT="${TINYNPU_WORK_ROOT:-${TMPDIR:-/tmp}/nmaforge_tinynpu_${PINNED_SHA:0:12}}"
TINY_NPU_ROOT="${TINY_NPU_ROOT:-$WORK_ROOT/source}"
OUT_DIR="${TINYNPU_GEMM_OUT:-$WORK_ROOT/gemm}"
VERILATOR="${VERILATOR:-verilator}"
CXX="${CXX:-c++}"

if [[ ! -d "$TINY_NPU_ROOT/.git" ]]; then
    mkdir -p "$(dirname "$TINY_NPU_ROOT")"
    git clone --filter=blob:none --no-checkout \
        https://github.com/harishsg993010/tiny-NPU.git "$TINY_NPU_ROOT"
    git -C "$TINY_NPU_ROOT" fetch --depth=1 origin "$PINNED_SHA"
    git -C "$TINY_NPU_ROOT" checkout --detach "$PINNED_SHA"
fi

ACTUAL_SHA="$(git -C "$TINY_NPU_ROOT" rev-parse HEAD)"
if [[ "$ACTUAL_SHA" != "$PINNED_SHA" ]]; then
    echo "TinyNPU source mismatch: expected $PINNED_SHA, got $ACTUAL_SHA" >&2
    exit 2
fi

RTL="$TINY_NPU_ROOT/rtl"
SIM="$TINY_NPU_ROOT/sim/verilator"
OBJ="$OUT_DIR/obj"
mkdir -p "$OUT_DIR"

if [[ ! -x "$OBJ/Vengine_tb_top" ]]; then
    mkdir -p "$OBJ"
    "$VERILATOR" --cc --trace --trace-structs -Wall \
        -Wno-UNUSED -Wno-UNDRIVEN -Wno-PINCONNECTEMPTY \
        -Wno-DECLFILENAME -Wno-IMPORTSTAR -Wno-VARHIDDEN -Wno-WIDTH \
        -Wno-BLKSEQ -Wno-UNSIGNED -Wno-PINMISSING -Wno-UNOPTFLAT \
        -Wno-SYNCASYNCNET -Wno-fatal --x-assign unique --x-initial unique \
        -DSIMULATION -I"$RTL/pkg" -I"$RTL/bus" -I"$RTL/mem" \
        -I"$RTL/ctrl" -I"$RTL/gemm" -I"$RTL/ops" -I"$RTL/graph" \
        --top-module engine_tb_top --prefix Vengine_tb_top --Mdir "$OBJ" \
        --exe "$SCRIPT_DIR/tb_matched_gemm.cpp" --build --build-jobs "${JOBS:-4}" \
        "$RTL/pkg/npu_pkg.sv" "$RTL/pkg/isa_pkg.sv" "$RTL/pkg/fixed_pkg.sv" \
        "$RTL/graph/fp16_utils.sv" "$RTL/bus/axi_types.sv" \
        "$RTL/mem/sram_dp.sv" "$RTL/mem/banked_sram.sv" "$RTL/mem/kv_cache_bank.sv" \
        "$RTL/gemm/mac_int8.sv" "$RTL/gemm/mac_fp16.sv" "$RTL/gemm/pe.sv" \
        "$RTL/gemm/systolic_array.sv" \
        "$RTL/ops/vec_engine.sv" "$RTL/ops/reduce_max.sv" "$RTL/ops/reduce_sum.sv" \
        "$RTL/ops/exp_lut.sv" "$RTL/ops/recip_lut.sv" \
        "$RTL/graph/graph_exp_lut_fp16.sv" "$RTL/ops/softmax_engine.sv" \
        "$RTL/ops/mean_var_engine.sv" "$RTL/ops/rsqrt_lut.sv" \
        "$RTL/graph/graph_rsqrt_lut_fp16.sv" "$RTL/ops/layernorm_engine.sv" \
        "$RTL/ops/gelu_lut.sv" "$RTL/ops/gelu_engine.sv" "$RTL/ops/silu_lut.sv" \
        "$RTL/ops/rmsnorm_engine.sv" "$RTL/ops/rope_engine.sv" \
        "$SIM/engine_tb_top.sv" > "$OUT_DIR/compile.log" 2>&1
fi

"$OBJ/Vengine_tb_top" | tee "$OUT_DIR/run.log"
grep -q '^TINYNPU_MATCHED_GEMM_PASS ' "$OUT_DIR/run.log"

# Run the pinned project’s own compute-engine regression using the same
# Verilated RTL library; this is a reference-integrity check, not a matched
# performance datapoint.
VERILATOR_REAL="$(readlink -f "$(command -v "$VERILATOR")")"
VERILATOR_ROOT="${VERILATOR_ROOT:-$(cd "$(dirname "$VERILATOR_REAL")/.." && pwd)}"
if [[ ! -x "$OUT_DIR/engine_sim" ]]; then
    "$CXX" -O2 -std=c++17 -I"$OBJ" \
        -I"$VERILATOR_ROOT/share/verilator/include" \
        -I"$VERILATOR_ROOT/share/verilator/include/vltstd" \
        -c "$SIM/tb_engines.cpp" -o "$OUT_DIR/tb_engines.o"
    "$CXX" -O2 -pthread -o "$OUT_DIR/engine_sim" "$OUT_DIR/tb_engines.o" \
        "$OBJ/Vengine_tb_top__ALL.a" "$OBJ/verilated.o" \
        "$OBJ/verilated_vcd_c.o" "$OBJ/verilated_threads.o"
fi
"$OUT_DIR/engine_sim" | tee "$OUT_DIR/engine_regression.log"
grep -q '^=== ALL ENGINE TESTS PASSED ===$' "$OUT_DIR/engine_regression.log"
printf 'TINYNPU_SHA=%s\n' "$ACTUAL_SHA"
