
SEED = $(shell date +%s)
AI_RANDOM_CASES ?= 4
AI_SEED ?= 12345
AI_REF_CASES ?= 1000
AI_REF_SEED ?= 20260722
# The WSL image keeps an old python3 (3.6) alongside newer interpreters.
# Pick the first installed Python that can parse the A3/A4 reference model;
# callers may still override PYTHON for a managed VNC/CI environment.
PYTHON ?= $(shell for p in python3.12 python3.11 python3.10 python3.9 python3.8 python3; do command -v $$p >/dev/null 2>&1 && $$p -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 7) else 1)' >/dev/null 2>&1 && { echo $$p; exit; }; done; echo python3)

all: ai_smoke

ai_transformer_gen:
	$(PYTHON) ../../../../sw/tools/cimforge_mapper.py

ai_comp: ai_transformer_gen
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-top tb_ai_accel_smoke -f ai_accel.f ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv -l ai_comp.log

ai_run:
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) -l ai_accel_smoke.log

ai_smoke: ai_comp ai_run

# Full top-level mixed-dot throughput sweep.  The single-tile baseline avoids
# DMA/compute overlap; three-tile runs use the production ping-pong pipeline to
# overlap actual DMA and FP traffic at the shared SPAD arbiter.  External DDR is
# modeled behaviorally, with seeded AXI RVALID latency and WREADY
# back-pressure in overlap runs.
FP_BENCH_SEED ?= 20261013
ai_fp_dot_dma_benchmark: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +FP_DOT_DMA_BENCH \
		+FP_BENCH_SEED=$(FP_BENCH_SEED) -l ai_fp_dot_dma_benchmark.log

# Optional V3 subsystem stress: inject seeded read/write SLVERR at a random
# beat of multi-beat DMA bursts and check completion plus AXI drain-to-idle.
ai_dma_error_stress: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +AI_DMA_ERROR_STRESS \
		-l ai_dma_error_stress.log

# Activity-aware smoke: uses exactly the same top-level regression as
# ai_smoke, but writes a VCD only when explicitly requested.  Convert it on
# the Synopsys Linux environment with `make ai_smoke_saif` before DC power.
ACLK_PERIOD_NS ?= 10.0
ACLK_PERIOD_TAG := $(subst .,_,$(ACLK_PERIOD_NS))ns
VCD_FILE ?= ai_accel_smoke_$(ACLK_PERIOD_TAG).vcd
SAIF_FILE ?= ai_accel_smoke_$(ACLK_PERIOD_TAG).saif
SAIF_DC_FILE ?= $(basename $(SAIF_FILE))_dc.saif
SAIF_INSTANCE ?= tb_ai_accel_smoke/dut

ai_smoke_vcd: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +VCD_FILE=$(VCD_FILE) -l ai_accel_smoke_vcd.log

ai_smoke_saif: ai_smoke_vcd
	vcd2saif -input $(VCD_FILE) -output $(SAIF_FILE) -instance $(SAIF_INSTANCE)
	$(PYTHON) ../../../../syn/normalize_saif_root.py --input $(SAIF_FILE) --output $(SAIF_DC_FILE) --testbench tb_ai_accel_smoke --dut dut --top ai_accel_top

ai_transformer: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) -l ai_transformer.log

# Short Linux/VCS gate: all directed AXI/DMA/A4 tests with random compute
# cases disabled. Use this after an RTL edit before the seeded regression.
ai_quick: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) -l ai_quick.log

# Integer reference model is intentionally a separate gate: it validates the
# documented A3/A4 fixed-point contract without claiming RTL coverage.
ai_a4_ref:
	$(PYTHON) ../../../block/compute/matrix/ref/ai_a3_reference.py --cases $(AI_REF_CASES) --seed $(AI_REF_SEED)

ai_precheck: ai_a4_ref ai_quick

# Focused Linux/VCS gates for the unified DMA and scratchpad line/RR arbiter.
ai_dma_comp:
	vcs -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-top tb_ai_axi128_dma ../../../../rtl/dma/ai_axi128_dma.v \
		../../../block/dma/tb/tb_ai_axi128_dma.sv -o simv_dma -l ai_dma_comp.log

ai_dma_run: ai_dma_comp
	./simv_dma -l ai_dma_run.log

ai_spad_arb_comp:
	vcs -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-top tb_ai_spad_arbiter_rr ../../../../rtl/memory/ai_spad_arbiter.v \
		../../../block/spad_arbiter/tb/tb_ai_spad_arbiter_rr.sv -o simv_spad_arb \
		-l ai_spad_arb_comp.log

ai_spad_arb_run: ai_spad_arb_comp
	./simv_spad_arb -l ai_spad_arb_run.log
	@grep -q '3-client sustained SPAD round-robin PASS grants=10/10/10 max_wait=2' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter 3-client fairness marker missing"; exit 1; }
	@grep -q 'Seeded request-mode SPAD RR PASS' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter seeded request-mode fairness marker missing"; exit 1; }
	@grep -q 'CNM/DMA SPAD contention PASS cnm_grants=6 dma_line_grants=6' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter CNM/DMA contention marker missing"; exit 1; }
	@grep -q 'Scratchpad response parity alignment PASS' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter response/parity marker missing"; exit 1; }

ai_upgrade_vcs: ai_dma_run ai_spad_arb_run ai_quick

# Focused VCS tests.  Each target creates a separate executable, KDB and log,
# so a directed failure can be inspected in Verdi without rebuilding ai_smoke.
VCS_FOCUSED = vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ns +define+VCS

ai_a6_dma_comp:
	$(VCS_FOCUSED) -top tb_ai_axi128_dma ../../../../rtl/dma/ai_axi128_dma.v \
		../../../block/dma/tb/tb_ai_axi128_dma.sv -o simv_a6_dma -l ai_a6_dma_comp.log

ai_a6_dma_run: ai_a6_dma_comp
	./simv_a6_dma -l ai_a6_dma_run.log

ai_a6_datapaths_comp:
	$(VCS_FOCUSED) -top tb_ai_a6_datapaths \
		../../../../rtl/compute/cnn/ai_conv3x3_linebuffer_core.v \
		../../../../rtl/compute/kv/ai_kv_cache_engine.v \
		../../../block/compute/cnn_kv/tb/tb_ai_a6_datapaths.sv -o simv_a6_datapaths -l ai_a6_datapaths_comp.log

ai_a6_datapaths_run: ai_a6_datapaths_comp
	./simv_a6_datapaths -l ai_a6_datapaths_run.log

ai_a7_vcs: ai_a6_dma_run ai_a6_datapaths_run ai_spad_arb_run

# A2.2 unit gate for the four independent bank-local controllers.
# This focused executable has occasionally been removed while its VCS .daidir
# cache remains (for example after a WSL/Windows file sync).  In that state VCS
# says the design is unchanged but does not recreate simv_cnm_a22.  Clear only
# this target's generated cache before compile; it does not touch ai_smoke.
ai_cnm_a22_comp:
	rm -rf simv_cnm_a22 simv_cnm_a22.daidir
	$(VCS_FOCUSED) -top tb_ai_banked_cnm_a22 \
		../../../../rtl/compute/cnm/ai_bank_pe.v \
		../../../../rtl/compute/cnm/ai_bank_local_controller.v \
		../../../../rtl/compute/cnm/ai_banked_cnm_core.v \
		../../../block/compute/cnm/tb/tb_ai_banked_cnm_a22.sv -o simv_cnm_a22 -l ai_cnm_a22_comp.log

ai_cnm_a22_run: ai_cnm_a22_comp
	./simv_cnm_a22 -l ai_cnm_a22_run.log

ai_cnm_a22: ai_cnm_a22_run

# Comparable VCS microbenchmarks: each A2/A3 case performs 64*L INT8 MACs.
ai_cnm_a2_gemv_bench_comp:
	rm -rf simv_cnm_a2_gemv_bench simv_cnm_a2_gemv_bench.daidir
	$(VCS_FOCUSED) -top tb_ai_cnm_a2_gemv_bench \
		../../../../rtl/compute/cnm/ai_bank_pe.v \
		../../../../rtl/compute/cnm/ai_bank_local_controller.v \
		../../../../rtl/compute/cnm/ai_banked_cnm_core.v \
		../../../block/compute/cnm/tb/tb_ai_cnm_a2_gemv_bench.sv -o simv_cnm_a2_gemv_bench -l ai_cnm_a2_gemv_bench_comp.log

ai_cnm_a2_gemv_bench_run: ai_cnm_a2_gemv_bench_comp
	./simv_cnm_a2_gemv_bench -l ai_cnm_a2_gemv_bench_run.log

ai_cnm_a2_gemv_bench: ai_cnm_a2_gemv_bench_run

ai_tensor_a3_gemm_bench_comp:
	rm -rf simv_tensor_a3_gemm_bench simv_tensor_a3_gemm_bench.daidir
	$(VCS_FOCUSED) -top tb_ai_tensor_a3_gemm_bench \
		../../../../rtl/compute/matrix/ai_tensor_matrix_datapath.v \
		../../../../rtl/compute/matrix/ai_tensor_matrix_core.v \
		../../../block/compute/matrix/tb/tb_ai_tensor_a3_gemm_bench.sv -o simv_tensor_a3_gemm_bench -l ai_tensor_a3_gemm_bench_comp.log

ai_tensor_a3_gemm_bench_run: ai_tensor_a3_gemm_bench_comp
	./simv_tensor_a3_gemm_bench -l ai_tensor_a3_gemm_bench_run.log

ai_tensor_a3_gemm_bench: ai_tensor_a3_gemm_bench_run

ai_cnm_compare: ai_cnm_a2_gemv_bench ai_tensor_a3_gemm_bench

# CNM signoff gate: microarchitecture throughput, SPAD arbitration under
# CNM/DMA contention, then the full AXI/DMA/compute smoke regression.
ai_cnm_signoff: ai_cnm_compare ai_spad_arb_run ai_smoke

ai_async_fifo_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo.sv -o simv_async_fifo -l ai_async_fifo_comp.log

ai_async_fifo_run: ai_async_fifo_comp
	./simv_async_fifo -l ai_async_fifo_run.log

ai_async_fifo: ai_async_fifo_run

ai_async_fifo_random_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo_random \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo_random.sv -o simv_async_fifo_random -l ai_async_fifo_random_comp.log

ai_async_fifo_random_run: ai_async_fifo_random_comp
	./simv_async_fifo_random +SEED=$(AI_SEED) -l ai_async_fifo_random_run.log

ai_async_fifo_random: ai_async_fifo_random_run

ai_async_fifo_reset_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo_reset \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo_reset.sv -o simv_async_fifo_reset -l ai_async_fifo_reset_comp.log

ai_async_fifo_reset_run: ai_async_fifo_reset_comp
	./simv_async_fifo_reset -l ai_async_fifo_reset_run.log

ai_async_fifo_reset: ai_async_fifo_reset_run

ai_ctrl_compute_cdc_comp:
	$(VCS_FOCUSED) -top tb_ai_ctrl_compute_cdc \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../../rtl/control/cdc/ai_ctrl_compute_cdc.v \
		../../../block/cdc/tb/tb_ai_ctrl_compute_cdc.sv -o simv_ctrl_compute_cdc -l ai_ctrl_compute_cdc_comp.log

ai_ctrl_compute_cdc_run: ai_ctrl_compute_cdc_comp
	./simv_ctrl_compute_cdc -l ai_ctrl_compute_cdc_run.log

ai_ctrl_compute_cdc: ai_ctrl_compute_cdc_run

clean:
	rm -rf csrc simv* *.log ucli.key *.vpd vc_hdrs.h DVE* novas* *.daidir *.vdb *.key
