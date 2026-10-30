VCS ?= vcs
UVM_TEST ?= dma_spad_subsystem_test
SIMV ?= simv_dma_spad_uvm
SEED ?= 20261014
SEEDS ?= 12345 987654 20261014
COV_TAG ?=
COV_SUFFIX = $(if $(strip $(COV_TAG)),_$(COV_TAG),)
COV_DIR ?= coverage/$(UVM_TEST)$(COV_SUFFIX)_seed$(SEED).vdb
RUN_LOG ?= $(UVM_TEST)$(COV_SUFFIX)_seed$(SEED).log
COMPILE_LOG ?= compile_$(UVM_TEST)$(COV_SUFFIX)_seed$(SEED).log
URG ?= urg
URG_REPORT ?= coverage/urg_$(UVM_TEST)$(COV_SUFFIX)_3seed
RREADY_SIMV ?= simv_dma_spad_rready_stall
RREADY_COV_DIR ?= coverage/$(UVM_TEST)_rready_stall_seed$(SEED).vdb
RREADY_RUN_LOG ?= $(UVM_TEST)_rready_stall_seed$(SEED).log
RREADY_COMPILE_LOG ?= compile_$(UVM_TEST)_rready_stall_seed$(SEED).log
RREADY_STALL_CYCLES ?= 16
RREADY_STRESS_TAG ?= a10_rready_stress
MEMORY_FABRIC_RESET_SEEDS ?= 20261025 20261026 20261027
MEMORY_FABRIC_RESET_OUT ?= /tmp/nmaforge_memory_fabric_reset_$(shell date +%Y%m%d_%H%M%S_%N)

.PHONY: subsystem_compile subsystem_run subsystem_regress subsystem_coverage subsystem_rready_stall_run subsystem_rready_stress subsystem_memory_fabric_reset_regress subsystem_clean

subsystem_compile:
	mkdir -p $(dir $(COV_DIR))
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -assert svaext \
		-cm line+cond+fsm+tgl+branch+assert -cm_dir $(COV_DIR) \
		-timescale=1ns/1ps +define+VCS -top tb_ai_dma_spad_subsystem_uvm \
		-f dma_spad_subsystem_uvm.f -o $(SIMV) -l $(COMPILE_LOG)

subsystem_run: subsystem_compile
	./$(SIMV) +UVM_TESTNAME=$(UVM_TEST) +ntb_random_seed=$(SEED) +UVM_VERBOSITY=UVM_MEDIUM \
		-cm line+cond+fsm+tgl+branch+assert -cm_dir $(COV_DIR) -l $(RUN_LOG)
	@grep -q '\*\* Report counts by severity' $(RUN_LOG) || { echo "ERROR: UVM report summary missing"; exit 1; }
	@! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' $(RUN_LOG) || { echo "ERROR: UVM warning/error/fatal count is nonzero"; exit 1; }

subsystem_rready_stall_run:
	$(MAKE) --no-print-directory subsystem_compile UVM_TEST=$(UVM_TEST)_rready_stall SIMV=$(RREADY_SIMV) COV_DIR=$(RREADY_COV_DIR) COMPILE_LOG=$(RREADY_COMPILE_LOG)
	$(RREADY_SIMV) +UVM_TESTNAME=$(UVM_TEST) +ntb_random_seed=$(SEED) +UVM_VERBOSITY=UVM_MEDIUM \
		+A10_RREADY_STALL_ONLY +A10_RREADY_STALL_CYCLES=$(RREADY_STALL_CYCLES) \
		-cm line+cond+fsm+tgl+branch+assert \
		-cm_dir $(RREADY_COV_DIR) -l $(RREADY_RUN_LOG)
	@grep -q 'DMA_RREADY_STALL_PASS' $(RREADY_RUN_LOG) || { echo "ERROR: RREADY stall pass marker missing"; exit 1; }
	@grep -q '\*\* Report counts by severity' $(RREADY_RUN_LOG) || { echo "ERROR: UVM report summary missing"; exit 1; }
	@! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' $(RREADY_RUN_LOG) || { echo "ERROR: UVM warning/error/fatal count is nonzero"; exit 1; }

subsystem_rready_stress:
	$(MAKE) --no-print-directory subsystem_rready_stall_run SEED=20261097 RREADY_STALL_CYCLES=16 \
		RREADY_SIMV=./simv_$(RREADY_STRESS_TAG)_16 \
		RREADY_COV_DIR=coverage/$(RREADY_STRESS_TAG)_16.vdb \
		RREADY_RUN_LOG=$(RREADY_STRESS_TAG)_16.log \
		RREADY_COMPILE_LOG=compile_$(RREADY_STRESS_TAG)_16.log
	$(MAKE) --no-print-directory subsystem_rready_stall_run SEED=20261098 RREADY_STALL_CYCLES=64 \
		RREADY_SIMV=./simv_$(RREADY_STRESS_TAG)_64 \
		RREADY_COV_DIR=coverage/$(RREADY_STRESS_TAG)_64.vdb \
		RREADY_RUN_LOG=$(RREADY_STRESS_TAG)_64.log \
		RREADY_COMPILE_LOG=compile_$(RREADY_STRESS_TAG)_64.log
	$(MAKE) --no-print-directory subsystem_rready_stall_run SEED=20261099 RREADY_STALL_CYCLES=300 \
		RREADY_SIMV=./simv_$(RREADY_STRESS_TAG)_300 \
		RREADY_COV_DIR=coverage/$(RREADY_STRESS_TAG)_300.vdb \
		RREADY_RUN_LOG=$(RREADY_STRESS_TAG)_300.log \
		RREADY_COMPILE_LOG=compile_$(RREADY_STRESS_TAG)_300.log
	$(URG) -full64 -dir coverage/$(RREADY_STRESS_TAG)_16.vdb \
		-dir coverage/$(RREADY_STRESS_TAG)_64.vdb \
		-dir coverage/$(RREADY_STRESS_TAG)_300.vdb \
		-report coverage/urg_$(RREADY_STRESS_TAG)
	@test -f coverage/urg_$(RREADY_STRESS_TAG)/dashboard.html || { echo "ERROR: RREADY stress URG dashboard missing"; exit 1; }

# Focused reset qualification for the in-repository ai_accel_memory_fabric.
# This is the on-chip SPAD fabric boundary, distinct from an arbitrary external
# AXI fabric implementation. It checks reset with external AXI reads pending,
# with a real CNM SPAD response pending, and verifies fresh post-reset work.
subsystem_memory_fabric_reset_regress:
	@set -e; out='$(MEMORY_FABRIC_RESET_OUT)'; mkdir -p "$$out/csrc"; \
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -assert svaext \
		-cm line+cond+fsm+tgl+branch+assert -cm_dir "$$out/compile.vdb" \
		-Mdir="$$out/csrc" -timescale=1ns/1ps +define+VCS -top tb_ai_dma_spad_subsystem_uvm \
		-f dma_spad_subsystem_uvm.f -o "$$out/simv" -l "$$out/compile.log"; \
	logs=''; dbs=''; \
	for seed in $(MEMORY_FABRIC_RESET_SEEDS); do \
		seed_dir="$$out/seed_$$seed"; mkdir -p "$$seed_dir"; \
		log="$$seed_dir/run.log"; db="$$seed_dir/coverage.vdb"; logs="$$logs $$log"; dbs="$$dbs -dir $$db"; \
		"$$out/simv" +UVM_TESTNAME=dma_spad_subsystem_test +A10_MEMORY_FABRIC_RESET_ONLY \
			+ntb_random_seed=$$seed +UVM_VERBOSITY=UVM_MEDIUM \
			-cm line+cond+fsm+tgl+branch+assert -cm_dir "$$db" -l "$$log"; \
		grep -q '\[MEMORY_FABRIC_RESET_ONLY_PASS\]' "$$log" || { echo "ERROR: fabric reset pass marker missing in $$log"; exit 1; }; \
		grep -q '\[DMA_CNM_RESET_SETUP\].*accepted SPAD read without its response' "$$log" || { echo "ERROR: reset was not exercised with a real accepted SPAD response pending in $$log"; exit 1; }; \
		[ "$$(grep -c 'UVM_INFO.*\[DMA_CNM_RESET_RECOVERY_PASS\]' "$$log")" -eq 2 ] || { echo "ERROR: both CNM reset phases did not recover in $$log"; exit 1; }; \
		grep -q '\*\* Report counts by severity' "$$log" || { echo "ERROR: UVM report summary missing in $$log"; exit 1; }; \
		! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$$log" || { echo "ERROR: UVM warning/error/fatal count is nonzero in $$log"; exit 1; }; \
		done; \
	$(URG) -full64 -dir "$$out/compile.vdb" $$dbs -report "$$out/urg"; \
	test -f "$$out/urg/dashboard.html" || { echo "ERROR: fabric reset URG dashboard missing"; exit 1; }; \
	python3 -c 'import re,sys; h=open(sys.argv[1],encoding="utf-8").read(); ns=("dma_spad_subsystem_pkg::dma_spad_subsystem_monitor::dma_cnm_shared_reset_cg","dma_spad_subsystem_pkg::dma_spad_subsystem_monitor::cnm_reset_phase_cg","dma_spad_subsystem_pkg::dma_spad_subsystem_monitor::dma_reset_phase_cg"); bad=[n for n in ns if not (lambda m:m and "100.00" in m.group(0))(re.search(r"<tr[^>]*>.*?"+re.escape(n)+r".*?</tr>",h,re.S))]; print("MEMORY_FABRIC_RESET_FUNCTIONAL_COVERAGE="+("PASS: 3/3 groups at 100%" if not bad else "FAIL: "+", ".join(bad))); sys.exit(bool(bad))' "$$out/urg/groups.html"; \
	echo "MEMORY_FABRIC_RESET_REGRESS_PASS: seeds=$(MEMORY_FABRIC_RESET_SEEDS) pending-SPAD-response/owner-flush plus DMA/CNM recovery; logs=$$logs; coverage=$$out/urg"

subsystem_regress:
	@set -e; for seed in $(SEEDS); do \
		$(MAKE) --no-print-directory subsystem_run SEED=$$seed COV_TAG=$(COV_TAG); \
	done
	$(MAKE) --no-print-directory subsystem_coverage COV_TAG=$(COV_TAG)

subsystem_coverage:
	$(URG) -full64 $(foreach seed,$(SEEDS),-dir coverage/$(UVM_TEST)$(COV_SUFFIX)_seed$(seed).vdb) -report $(URG_REPORT)
	@test -f $(URG_REPORT)/dashboard.html || { echo "ERROR: URG dashboard missing"; exit 1; }

subsystem_clean:
	rm -rf csrc $(SIMV) $(SIMV).daidir ucli.key vc_hdrs.h *.log simv* verdiLog DVEfiles *.vdb
