# Round 35 DMA load-bandwidth sweep: production ai_axi128_dma vs the AXI
# performance memory model (1 beat/cycle, pipelined latency 25/50/100 cycles,
# outstanding 1/2/4, transfers 256 B..256 KiB, every word data-checked).
# DMA_BURSTS selects the MAX_BURST_BEATS builds (16 is the SPEC v7.4 product).
VCS ?= vcs -licwait 1
DMA_BURSTS ?= 16 32 64
DMA_BW_OUT ?= /tmp/nmaforge_dma_bw
RTL := ../../../../rtl/dma
.PHONY: dma-bw-sweep
dma-bw-sweep:
	@set -e; for b in $(DMA_BURSTS); do \
		mkdir -p $(DMA_BW_OUT)/burst$$b; \
		$(VCS) -full64 -sverilog -timescale=1ns/1ps +define+DMA_BURST=$$b \
			-Mdir=$(DMA_BW_OUT)/burst$$b/csrc -top tb_dma_bandwidth $(RTL)/*.v \
			axi_perf_memory_model.sv tb_dma_bandwidth.sv \
			-o $(DMA_BW_OUT)/burst$$b/simv -l $(DMA_BW_OUT)/burst$$b/compile.log; \
		$(DMA_BW_OUT)/burst$$b/simv -l $(DMA_BW_OUT)/burst$$b/run.log; \
		grep -q '^DMA_BW_SWEEP_PASS' $(DMA_BW_OUT)/burst$$b/run.log; \
	done
