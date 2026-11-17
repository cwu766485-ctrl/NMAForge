#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
OUT=${1:-${TMPDIR:-/tmp}/nmaforge_round25_deit_replay}
PYTHON=${PYTHON:-python3.12}
VCS=${VCS:-vcs}
mkdir -p "$OUT"
cd "$ROOT/dv/subsystem/top_smoke/sim"

"$VCS" -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps \
  +define+VCS +define+AI_REPRESENTATIVE_LONG_TASK \
  +define+AI_SPAD_WORDS_PER_BANK=16384 \
  +incdir+../../../block/control/agent +incdir+../../../block/dma/agent \
  +incdir+../fixtures -Mdir="$OUT/csrc" -top tb_ai_accel_smoke \
  -f ai_accel.f ../../../block/dma/env/axi_memory_model.sv \
  ../tb/tb_ai_accel_smoke.sv -o "$OUT/simv" -l "$OUT/compile.log"

for head in 0 1 2; do
  case "$head" in
    0) run_dir="$OUT/head0" ;;
    *) run_dir="$OUT/head$head" ;;
  esac
  mkdir -p "$run_dir"
  "$PYTHON" "$ROOT/benchmark/deit/round25/generate_deit_attention_qblock.py" \
    --head "$head" \
    --q-dump "$ROOT/benchmark/deit/round25/av_rootcause/inputs/q_and_k_product_readback.txt" \
    --kv-dump "$ROOT/benchmark/deit/round25/av_rootcause/inputs/qkv_product_readback.txt" \
    --projection-golden "$ROOT/benchmark/deit/round25/av_rootcause/inputs/projection_golden.memh" \
    --projection-memory "$ROOT/benchmark/deit/round25/av_rootcause/inputs/projection_memory.memh" \
    --out-dir "$run_dir/workload"
  "$OUT/simv" +ntb_random_seed=20261117 +AI_RANDOM_CASES=0 \
    +AI_SEED=20261117 +ACLK_PERIOD_NS=10.0 +AI_REPRESENTATIVE_MODEL \
    +AI_DEIT_AV_TRACE \
    +AI_REPRESENTATIVE_MEMORY="$run_dir/workload/model_memory.memh" \
    +AI_REPRESENTATIVE_GOLDEN="$run_dir/workload/model_golden.memh" \
    +AI_REPRESENTATIVE_DESC_BASE=221184 \
    +AI_REPRESENTATIVE_CPL_BASE=253952 \
    +AI_REPRESENTATIVE_DESC_COUNT=245 \
    +AI_REPRESENTATIVE_QUEUE_SIZE=512 \
    +AI_REPRESENTATIVE_USEFUL_MACS=605184 -l "$run_dir/run.log"
  grep -q '^REPRESENTATIVE_MODEL_PASS desc=245 .*golden_words=8512 useful_macs=605184 ' \
    "$run_dir/run.log"
done

"$PYTHON" "$ROOT/benchmark/deit/round25/summarize_av_closure.py"
