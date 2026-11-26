#!/usr/bin/env bash
set -euo pipefail
out=${GATE1_OUT:?absolute evidence output directory}
mkdir -p "$out"
vcs -cm line+cond+fsm+branch+assert -cm_dir "$out/coverage.vdb" -full64 -sverilog -timescale=1ns/1ps -top tb_output_dma_gate1 \
 rtl/dma/ai_dma_burst_planner.v rtl/dma/ai_dma_read_slot_tracker.v \
 rtl/dma/ai_dma_write_response_tracker.v rtl/dma/ai_dma_spad_transfer_adapter.v \
 rtl/dma/ai_axi128_dma.v dv/block/dma/assertions/ai_axi128_dma_sva.sv dv/block/dma/tb/tb_output_dma_gate1.sv \
 -Mdir="$out/csrc" -o "$out/simv" -l "$out/compile.log" > "$out/compile.stdout" 2>&1
"$out/simv" -cm line+cond+fsm+branch+assert -cm_dir "$out/coverage.vdb" > "$out/run.log" 2>&1
grep -q '^OUTPUT_DMA_GATE1_PASS' "$out/run.log"
! grep -Eq "(Fatal:|Error:|SVA FAIL)" "$out/run.log"
