#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PINNED_SHA=8216c22b762011aa20c05fc2768423fd12dda59d
WORK_ROOT="${TINYNPU_WORK_ROOT:-${TMPDIR:-/tmp}/nmaforge_tinynpu_${PINNED_SHA:0:12}}"
TINY_NPU_ROOT="${TINY_NPU_ROOT:-$WORK_ROOT/source}"
OUT_DIR="${TINYNPU_CNN_OUT:-$WORK_ROOT/cnn}"
VERILATOR="${VERILATOR:-verilator}"
PYTHON="${PYTHON:-python3}"

ACTUAL_SHA="$(git -C "$TINY_NPU_ROOT" rev-parse HEAD)"
if [[ "$ACTUAL_SHA" != "$PINNED_SHA" ]]; then
    echo "TinyNPU source mismatch: expected $PINNED_SHA, got $ACTUAL_SHA" >&2
    exit 2
fi

RTL="$TINY_NPU_ROOT/rtl"
SIM="$TINY_NPU_ROOT/sim/verilator"
OBJ="$OUT_DIR/obj"
GRAPH="$OUT_DIR/graph_cnn"
mkdir -p "$OUT_DIR"

"$PYTHON" "$TINY_NPU_ROOT/python/onnx_compiler/compile.py" \
    --model "$TINY_NPU_ROOT/models/conv1x_mini.onnx" --outdir "$GRAPH" \
    > "$OUT_DIR/onnx_compile.log" 2>&1

if [[ ! -x "$OBJ/Vonnx_sim_top" ]]; then
    mkdir -p "$OBJ"
    "$VERILATOR" --cc --trace --trace-structs -Wall \
        -Wno-UNUSED -Wno-UNDRIVEN -Wno-PINCONNECTEMPTY \
        -Wno-DECLFILENAME -Wno-IMPORTSTAR -Wno-VARHIDDEN -Wno-WIDTH \
        -Wno-BLKSEQ -Wno-UNSIGNED -Wno-PINMISSING -Wno-UNOPTFLAT \
        -Wno-SYNCASYNCNET -Wno-fatal --x-assign unique --x-initial unique \
        -DSIMULATION -I"$RTL/pkg" -I"$RTL/bus" -I"$RTL/mem" \
        -I"$RTL/ctrl" -I"$RTL/gemm" -I"$RTL/ops" -I"$RTL/graph" \
        --top-module onnx_sim_top --prefix Vonnx_sim_top -GSRAM0_DEPTH=65536 \
        --Mdir "$OBJ" --exe "$SIM/tb_onnx_cnn_smoke.cpp" \
        --build --build-jobs "${JOBS:-4}" \
        "$RTL/pkg/npu_pkg.sv" "$RTL/pkg/isa_pkg.sv" "$RTL/pkg/fixed_pkg.sv" \
        "$RTL/graph/fp16_utils.sv" "$RTL/mem/sram_dp.sv" \
        "$RTL/mem/banked_sram.sv" "$RTL/mem/kv_cache_bank.sv" \
        "$RTL/gemm/mac_int8.sv" "$RTL/gemm/mac_fp16.sv" "$RTL/gemm/pe.sv" \
        "$RTL/gemm/systolic_array.sv" \
        "$RTL/ops/vec_engine.sv" "$RTL/ops/reduce_max.sv" "$RTL/ops/reduce_sum.sv" \
        "$RTL/ops/exp_lut.sv" "$RTL/ops/recip_lut.sv" \
        "$RTL/graph/graph_exp_lut_fp16.sv" "$RTL/ops/softmax_engine.sv" \
        "$RTL/ops/mean_var_engine.sv" "$RTL/ops/rsqrt_lut.sv" \
        "$RTL/graph/graph_rsqrt_lut_fp16.sv" "$RTL/ops/layernorm_engine.sv" \
        "$RTL/ops/gelu_lut.sv" "$RTL/ops/gelu_engine.sv" "$RTL/ops/silu_lut.sv" \
        "$RTL/ops/rmsnorm_engine.sv" "$RTL/ops/rope_engine.sv" \
        "$RTL/graph/graph_isa_pkg.sv" "$RTL/graph/tensor_table.sv" \
        "$RTL/graph/graph_fetch.sv" "$RTL/graph/graph_decode.sv" \
        "$RTL/graph/graph_dispatch.sv" "$RTL/graph/graph_top.sv" \
        "$RTL/graph/reduce_engine.sv" "$RTL/graph/graph_exp_lut.sv" \
        "$RTL/graph/graph_log_lut.sv" "$RTL/graph/graph_sqrt_lut.sv" \
        "$RTL/graph/graph_rsqrt_lut.sv" "$RTL/graph/math_engine.sv" \
        "$RTL/graph/gather_engine.sv" "$RTL/graph/slice_engine.sv" \
        "$RTL/graph/concat_engine.sv" "$RTL/graph/avgpool2d_engine.sv" \
        "$RTL/graph/maxpool2d_engine.sv" "$RTL/graph/pad_engine.sv" \
        "$RTL/graph/resize_nearest_engine.sv" "$RTL/graph/cast_engine.sv" \
        "$RTL/graph/graph_log_lut_fp16.sv" "$RTL/graph/graph_sqrt_lut_fp16.sv" \
        "$RTL/mem/tile_buffer.sv" "$RTL/gemm/gemm_ctrl.sv" \
        "$SIM/onnx_sim_top.sv" > "$OUT_DIR/compile.log" 2>&1
fi

(
    cd "$OUT_DIR"
    "$OBJ/Vonnx_sim_top" --datadir "$GRAPH"
) | tee "$OUT_DIR/run.log"
grep -q '^PASS: All 4 bytes match golden!' "$OUT_DIR/run.log"
grep -q 'Graph execution DONE at cycle ' "$OUT_DIR/run.log"
printf 'TINYNPU_CNN_PASS sha=%s model=conv1x_mini.onnx\n' "$ACTUAL_SHA"
