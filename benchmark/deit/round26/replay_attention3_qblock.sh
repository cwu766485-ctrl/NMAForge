#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
OUT=${1:-${TMPDIR:-/tmp}/nmaforge_deit_round26_attention3_qblock}
PYTHON=${PYTHON:-/tmp/nmaforge_deit_round17_venv/bin/python}
VCS=${VCS:-vcs}
PROJ=${DEIT_QKV_EVIDENCE:-/tmp/nmaforge_deit_round26_qkv197_rerun}
WORKLOAD="$OUT/workload"
mkdir -p "$OUT"

"$PYTHON" "$ROOT/benchmark/deit/round26/generate_deit_attention3_qblock.py" \
  --qkv-dump "$PROJ/qkv_readback.txt" \
  --qkv-golden "$PROJ/workload/model_golden.memh" \
  --block 0 --out-dir "$WORKLOAD"

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
  +AI_REPRESENTATIVE_DESC_BASE=200704 \
  +AI_REPRESENTATIVE_CPL_BASE=249856 \
  +AI_REPRESENTATIVE_DESC_COUNT=735 \
  +AI_REPRESENTATIVE_QUEUE_SIZE=768 \
  +AI_REPRESENTATIVE_USEFUL_MACS=1210368 \
  +AI_REPRESENTATIVE_EXECUTED_MACS=1277952 \
  +AI_REPRESENTATIVE_PADDING_MACS=67584 \
  +AI_REPRESENTATIVE_USEFUL_OUTPUTS=3072 \
  +AI_REPRESENTATIVE_PHYSICAL_OUTPUTS=3072 \
  -l "$OUT/run.log"

grep -q '^REPRESENTATIVE_LATE_DMA_SUMMARY events=90 payload_bytes=82944 checked_words=20736 axi_read_bytes=82944 ' \
  "$OUT/run.log"
grep -q '^REPRESENTATIVE_MODEL_PASS desc=735 .*golden_words=25536 useful_macs=1210368 executed_macs=1277952 padding_macs=67584 ' \
  "$OUT/run.log"
echo "ROUND26_DEIT_ATTENTION3_QBLOCK_TOP_PASS out=$OUT"
