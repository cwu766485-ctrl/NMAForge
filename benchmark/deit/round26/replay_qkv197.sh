#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
OUT=${1:-${TMPDIR:-/tmp}/nmaforge_deit_round26_qkv197}
PYTHON=${PYTHON:-/tmp/nmaforge_deit_round17_venv/bin/python}
VCS=${VCS:-vcs}
MODEL_DIR=${DEIT_MODEL_DIR:-/home/ray/.cache/huggingface/hub/models--facebook--deit-tiny-patch16-224/snapshots/b3428f18dcc7b543470d07f14b4a4157815d1880}
EVIDENCE="$ROOT/benchmark/deit/round24/evidence/ln_full_197"
WORKLOAD="$OUT/workload"

mkdir -p "$OUT"
"$PYTHON" "$ROOT/benchmark/deit/round26/generate_deit_qkv197_projection.py" \
  --model-dir "$MODEL_DIR" \
  --ln-manifest "$EVIDENCE/manifest.json" \
  --ln-golden "$EVIDENCE/model_golden.memh" \
  --ln-dump "$EVIDENCE/rtl_ln_dump.txt" \
  --out-dir "$WORKLOAD"

cd "$ROOT/dv/subsystem/top_smoke/sim"
"$VCS" -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps \
  +define+VCS +define+AI_REPRESENTATIVE_LONG_TASK \
  +define+AI_SPAD_WORDS_PER_BANK=16384 \
  +incdir+../../../block/control/agent +incdir+../../../block/dma/agent \
  +incdir+../fixtures -Mdir="$OUT/csrc" -top tb_ai_accel_smoke \
  -f ai_accel.f ../../../block/dma/env/axi_memory_model.sv \
  ../tb/tb_ai_accel_smoke.sv -o "$OUT/simv" -l "$OUT/compile.log"

"$OUT/simv" +ntb_random_seed=20261117 +AI_RANDOM_CASES=0 \
  +AI_SEED=20261117 +ACLK_PERIOD_NS=10.0 +AI_REPRESENTATIVE_MODEL \
  +AI_REPRESENTATIVE_LATE_DMA \
  +AI_REPRESENTATIVE_DMA_PAYLOAD="$WORKLOAD/dma_payload.memh" \
  +AI_REPRESENTATIVE_DMA_PLAN="$WORKLOAD/late_dma_plan.memh" \
  +AI_REPRESENTATIVE_MEMORY="$WORKLOAD/model_memory.memh" \
  +AI_REPRESENTATIVE_GOLDEN="$WORKLOAD/model_golden.memh" \
  +AI_REPRESENTATIVE_DESC_BASE=221184 +AI_REPRESENTATIVE_CPL_BASE=253952 \
  +AI_REPRESENTATIVE_DESC_COUNT=468 +AI_REPRESENTATIVE_QUEUE_SIZE=512 \
  +AI_REPRESENTATIVE_USEFUL_MACS=21786624 \
  +AI_REPRESENTATIVE_EXECUTED_MACS=23003136 \
  +AI_REPRESENTATIVE_PADDING_MACS=1216512 \
  +AI_REPRESENTATIVE_USEFUL_OUTPUTS=113472 \
  +AI_REPRESENTATIVE_PHYSICAL_OUTPUTS=119808 \
  +AI_REPRESENTATIVE_DUMP_FILE="$OUT/qkv_readback.txt" \
  +AI_REPRESENTATIVE_DUMP_A_BASE=90112 +AI_REPRESENTATIVE_DUMP_A_WORDS=9984 \
  +AI_REPRESENTATIVE_DUMP_B_BASE=131072 +AI_REPRESENTATIVE_DUMP_B_WORDS=20224 \
  -l "$OUT/run.log"

grep -q '^REPRESENTATIVE_MODEL_PASS desc=468 .*golden_words=29952 useful_macs=21786624 executed_macs=23003136 padding_macs=1216512 useful_output_elements=113472 physical_output_elements=119808 ' "$OUT/run.log"
grep -q '^REPRESENTATIVE_LATE_DMA_SUMMARY events=144 payload_bytes=112896 checked_words=28224 axi_read_bytes=112896 ' "$OUT/run.log"
echo "ROUND26_DEIT_QKV197_TOP_PASS out=$OUT"
