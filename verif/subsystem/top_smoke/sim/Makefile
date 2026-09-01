
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
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ns +define+VCS \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-top tb_ai_accel_smoke -f ai_accel.f ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv -l ai_comp.log

ai_run:
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) -l ai_accel_smoke.log

ai_smoke: ai_comp ai_run

# Activity-aware smoke: uses exactly the same top-level regression as
# ai_smoke, but writes a VCD only when explicitly requested.  Convert it on
# the Synopsys Linux environment with `make ai_smoke_saif` before DC power.
VCD_FILE ?= ai_accel_smoke.vcd
SAIF_FILE ?= ai_accel_smoke.saif
SAIF_INSTANCE ?= tb_ai_accel_smoke/dut

ai_smoke_vcd: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) +VCD_FILE=$(VCD_FILE) -l ai_accel_smoke_vcd.log

ai_smoke_saif: ai_smoke_vcd
	vcd2saif -input $(VCD_FILE) -output $(SAIF_FILE) -instance $(SAIF_INSTANCE)

ai_transformer: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) -l ai_transformer.log

# Short Linux/VCS gate: all directed AXI/DMA/A4 tests with random compute
# cases disabled. Use this after an RTL edit before the seeded regression.
ai_quick: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) -l ai_quick.log

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
		../../../../rtl/compute/matrix/ai_tensor_matrix_core.v \
		../../../block/compute/matrix/tb/tb_ai_tensor_a3_gemm_bench.sv -o simv_tensor_a3_gemm_bench -l ai_tensor_a3_gemm_bench_comp.log

ai_tensor_a3_gemm_bench_run: ai_tensor_a3_gemm_bench_comp
	./simv_tensor_a3_gemm_bench -l ai_tensor_a3_gemm_bench_run.log

ai_tensor_a3_gemm_bench: ai_tensor_a3_gemm_bench_run

ai_cnm_compare: ai_cnm_a2_gemv_bench ai_tensor_a3_gemm_bench

# CNM signoff gate: microarchitecture throughput, SPAD arbitration under
# CNM/DMA contention, then the full AXI/DMA/compute smoke regression.
ai_cnm_signoff: ai_cnm_compare ai_spad_arb_run ai_smoke

clean:
	rm -rf csrc simv* *.log ucli.key *.vpd vc_hdrs.h DVE* novas* *.daidir *.vdb *.key
