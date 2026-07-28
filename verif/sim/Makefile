
SEED = $(shell date +%s)
COV_OPTS = -cm line+fsm+tgl+cond+branch
TEST=ahb_sramc_base_test
RUN_ARGS =
WAVE ?= 0
SEEDS ?= 101 202 303 404 505
RANDOM_SRAM_CASES ?= 50
RANDOM_VECTOR_CASES ?= 4
AI_RANDOM_CASES ?= 4
AI_SEED ?= 12345
VDB ?= simv.vdb
AI_REF_CASES ?= 1000
AI_REF_SEED ?= 20260722
# The WSL image keeps an old python3 (3.6) alongside newer interpreters.
# Pick the first installed Python that can parse the A3/A4 reference model;
# callers may still override PYTHON for a managed VNC/CI environment.
PYTHON ?= $(shell for p in python3.12 python3.11 python3.10 python3.9 python3.8 python3; do command -v $$p >/dev/null 2>&1 && $$p -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 7) else 1)' >/dev/null 2>&1 && { echo $$p; exit; }; done; echo python3)

all: comp run

comp:
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -top ahb_sramc_svtb_top -f rtl.f $(COV_OPTS) \
		+incdir+../agent/ahb \
		+incdir+../env \
		+incdir+../tests \
		+incdir+../tb \
		../agent/ahb/ahb_slv_if.sv \
		../agent/ahb/ahb_slv_pkt.sv \
		../agent/ahb/ahb_slv_generator.sv \
		../agent/ahb/ahb_slv_driver_base.sv \
		../agent/ahb/ahb_slv_driver.sv \
		../agent/ahb/ahb_slv_monitor.sv \
		../agent/ahb/ahb_slv_scoreboard.sv \
		../env/ahb_slv_fcoverage.sv \
		../env/vec_accel_sva.sv \
		../tests/ahb_sramc_base_test.sv \
		../tests/ahb_sramc_test.sv \
		../tb/ahb_sramc_svtb_top.sv  -l comp.log

run:
ifeq ($(WAVE),1)
	./simv +ntb_random_seed=${SEED} +VPD_ON $(RUN_ARGS) $(COV_OPTS) -l ${TEST}.log
else
	./simv +ntb_random_seed=${SEED} $(RUN_ARGS) $(COV_OPTS) -l ${TEST}.log
endif

regress: comp
	SEEDS="$(SEEDS)" RANDOM_SRAM_CASES=$(RANDOM_SRAM_CASES) RANDOM_VECTOR_CASES=$(RANDOM_VECTOR_CASES) bash run_regression.sh

verdi:
	verdi -sv -f rtl.f \
		+incdir+../agent/ahb \
		+incdir+../env \
		+incdir+../tests \
		+incdir+../tb \
		../agent/ahb/ahb_slv_if.sv \
		../agent/ahb/ahb_slv_pkt.sv \
		../agent/ahb/ahb_slv_generator.sv \
		../agent/ahb/ahb_slv_driver_base.sv \
		../agent/ahb/ahb_slv_driver.sv \
		../agent/ahb/ahb_slv_monitor.sv \
		../agent/ahb/ahb_slv_scoreboard.sv \
		../env/ahb_slv_fcoverage.sv \
		../env/vec_accel_sva.sv \
		../tests/ahb_sramc_base_test.sv \
		../tests/ahb_sramc_test.sv \
		../tb/ahb_sramc_svtb_top.sv \
		-ssf vcdplus.vpd &

cov_text:
	python parse_vcs_cov.py $(VDB)

regress_cov:
	python parse_vcs_cov.py regression/regression.vdb

ai_comp:
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ns +define+VCS \
		+incdir+../agents/axi_lite \
		+incdir+../agents/ai_dma \
		-top tb_ai_accel_smoke -f ai_accel.f ../env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv -l ai_comp.log

ai_run:
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) -l ai_accel_smoke.log

ai_smoke: ai_comp ai_run

# Short Linux/VCS gate: all directed AXI/DMA/A4 tests plus no legacy random
# compute cases.  Use this after an RTL edit before the seeded regression.
ai_quick: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) -l ai_quick.log

# Integer reference model is intentionally a separate gate: it validates the
# documented A3/A4 fixed-point contract without claiming RTL coverage.
ai_a4_ref:
	$(PYTHON) ../ref/ai_a3_reference.py --cases $(AI_REF_CASES) --seed $(AI_REF_SEED)

ai_precheck: ai_a4_ref ai_quick

# Portable directed A6 checks. These complement, but do not replace, VCS
# `ai_smoke`; the tests intentionally exercise RID/BID reordering.
ai_a6_iverilog:
	iverilog -g2012 -o /tmp/cimforge_a6_dma.vvp ../../rtl/dma/ai_axi128_dma_ooo.v ../tb/tb_ai_axi128_dma_ooo.sv
	vvp /tmp/cimforge_a6_dma.vvp
	iverilog -g2012 -o /tmp/cimforge_a6_datapaths.vvp ../../rtl/compute/ai_conv3x3_linebuffer_core.v ../../rtl/compute/ai_kv_cache_engine.v ../tb/tb_ai_a6_datapaths.sv
	vvp /tmp/cimforge_a6_datapaths.vvp

clean:
	rm -rf csrc simv* *.log ucli.key *.vpd vc_hdrs.h DVE* novas* *.daidir *.vdb *.key
