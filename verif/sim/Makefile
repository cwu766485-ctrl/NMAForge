
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
	$(PYTHON) ../../sw/tools/cimforge_mapper.py

ai_comp: ai_transformer_gen
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ns +define+VCS \
		+incdir+../agents/axi_lite \
		+incdir+../agents/ai_dma \
		+incdir+../generated \
		-top tb_ai_accel_smoke -f ai_accel.f ../env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv -l ai_comp.log

ai_run:
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) -l ai_accel_smoke.log

ai_smoke: ai_comp ai_run

ai_transformer: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) -l ai_transformer.log

# Short Linux/VCS gate: all directed AXI/DMA/A4 tests with random compute
# cases disabled. Use this after an RTL edit before the seeded regression.
ai_quick: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) -l ai_quick.log

# Integer reference model is intentionally a separate gate: it validates the
# documented A3/A4 fixed-point contract without claiming RTL coverage.
ai_a4_ref:
	$(PYTHON) ../ref/ai_a3_reference.py --cases $(AI_REF_CASES) --seed $(AI_REF_SEED)

ai_precheck: ai_a4_ref ai_quick

# Focused Linux/VCS gates for the unified DMA and scratchpad line/RR arbiter.
ai_dma_comp:
	vcs -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-top tb_ai_axi128_dma ../../rtl/dma/ai_axi128_dma.v \
		../tb/tb_ai_axi128_dma.sv -o simv_dma -l ai_dma_comp.log

ai_dma_run: ai_dma_comp
	./simv_dma -l ai_dma_run.log

ai_spad_arb_comp:
	vcs -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-top tb_ai_spad_arbiter_rr ../../rtl/memory/ai_spad_arbiter.v \
		../tb/tb_ai_spad_arbiter_rr.sv -o simv_spad_arb \
		-l ai_spad_arb_comp.log

ai_spad_arb_run: ai_spad_arb_comp
	./simv_spad_arb -l ai_spad_arb_run.log

ai_upgrade_vcs: ai_dma_run ai_spad_arb_run ai_quick

# Portable directed A7 checks. These complement, but do not replace, VCS
# `ai_smoke`; the tests intentionally exercise RID/BID reordering.
ai_a6_iverilog:
	iverilog -g2012 -o /tmp/cimforge_a6_dma.vvp ../../rtl/dma/ai_axi128_dma.v ../tb/tb_ai_axi128_dma.sv
	vvp /tmp/cimforge_a6_dma.vvp
	iverilog -g2012 -o /tmp/cimforge_a6_datapaths.vvp ../../rtl/compute/ai_conv3x3_linebuffer_core.v ../../rtl/compute/ai_kv_cache_engine.v ../tb/tb_ai_a6_datapaths.sv
	vvp /tmp/cimforge_a6_datapaths.vvp
	iverilog -g2012 -o /tmp/cimforge_spad_rr.vvp ../../rtl/memory/ai_spad_arbiter.v ../tb/tb_ai_spad_arbiter_rr.sv
	vvp /tmp/cimforge_spad_rr.vvp

ai_a7_iverilog: ai_a6_iverilog

clean:
	rm -rf csrc simv* *.log ucli.key *.vpd vc_hdrs.h DVE* novas* *.daidir *.vdb *.key
