# Run from dv/uvm/sim on the Linux/VCS environment.
UVM_TEST ?= ai_version_smoke_test
VCS_HOME ?= /opt/Synopsys/vcs/V-2023.12-SP1
# Assign in the makefile so a stale shell VCS_UVM=/bin/vcs cannot shadow the
# configured installation. Callers can still override VCS_HOME or VCS_UVM.
VCS_UVM = $(VCS_HOME)/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS
RUN_LOG  ?= uvm_run_$(UVM_TEST).log
MIXED_E2E_SEEDS ?= 20261014 712345 987654 20261015 20261016 20261017
MIXED_E2E_COV_SEEDS ?= 20261014 712345 987654 20261015 20261016 20261017 20261018 20261019 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027
MIXED_E2E_COV_OUT ?= /tmp/nmaforge_mixed_precision_e2e_cov_$(shell date +%Y%m%d_%H%M%S_%N)
MIXED_E2E_RANDOM_SEEDS ?= $(shell seq 20261101 20261292)
MIXED_E2E_RANDOM_OUT ?= /tmp/nmaforge_mixed_precision_e2e_random_$(shell date +%Y%m%d_%H%M%S_%N)
URG ?= $(VCS_HOME)/bin/urg
UVM_COV_METRICS ?= line+cond+branch+fsm+assert
# Evaluate the run stamp once. Recursive $(shell date ...) expansion changes
# the output path on every reference and can make mutation targets launch a
# simv path different from the one built by their compile prerequisite.
COMPUTE_CLUSTER_RUN_STAMP := $(shell date +%Y%m%d_%H%M%S_%N)
COMPUTE_CLUSTER_UVM_OUT ?= /tmp/nmaforge_real_compute_cluster_uvm_$(COMPUTE_CLUSTER_RUN_STAMP)
COMPUTE_CLUSTER_UVM_SEEDS ?= 20261025 20261026 20261027
COMPUTE_CLUSTER_MUTATION_OUT ?= /tmp/nmaforge_compute_cluster_mutations_$(COMPUTE_CLUSTER_RUN_STAMP)

.PHONY: uvm_compile uvm_run uvm_smoke uvm_fp16_ddr_e2e uvm_mixed_precision_ddr_e2e uvm_external_macro_ddr_e2e uvm_mixed_precision_ddr_e2e_axi_stalls uvm_mixed_precision_ddr_e2e_regress uvm_mixed_precision_ddr_e2e_cov_regress uvm_mixed_precision_ddr_e2e_random_cov_regress uvm_compute_cluster_compile uvm_compute_cluster_regress uvm_compute_cluster_mutation clean
uvm_compile:
	rm -rf simv_uvm simv_uvm.daidir csrc
	$(VCS_UVM) -top tb_ai_accel_uvm -f ai_accel_uvm.f -o simv_uvm -l uvm_compile.log

uvm_run: uvm_compile
	./simv_uvm +UVM_TESTNAME=$(UVM_TEST) -l $(RUN_LOG)
	@grep -q '\*\* Report counts by severity' $(RUN_LOG) || { echo "ERROR: UVM report summary missing from $(RUN_LOG)"; exit 1; }
	@! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' $(RUN_LOG) || { echo "ERROR: UVM warning/error/fatal count is nonzero in $(RUN_LOG)"; exit 1; }

uvm_smoke: uvm_run

uvm_mixed_precision_ddr_e2e:
	$(MAKE) uvm_run UVM_TEST=ai_mixed_precision_ddr_e2e_test
	@grep -q '\[MIXED_E2E_FP_WATCHDOG_PASS\]' uvm_run_ai_mixed_precision_ddr_e2e_test.log || { echo "ERROR: real FP watchdog-to-completion check missing from uvm_run_ai_mixed_precision_ddr_e2e_test.log"; exit 1; }
	@grep -q '\[MIXED_E2E_FP_ABORT_PASS\]' uvm_run_ai_mixed_precision_ddr_e2e_test.log || { echo "ERROR: real FP software-abort-to-completion check missing from uvm_run_ai_mixed_precision_ddr_e2e_test.log"; exit 1; }

uvm_external_macro_ddr_e2e:
	$(MAKE) uvm_run UVM_TEST=ai_external_macro_ddr_e2e_test
	@grep -q '\[MACRO_EXTERNAL_DDR_E2E_PASS\]' uvm_run_ai_external_macro_ddr_e2e_test.log || { echo "ERROR: external macro DDR E2E completion check missing"; exit 1; }
	@grep -q '\[MACRO_AXI_DESC_FETCH_PASS\]' uvm_run_ai_external_macro_ddr_e2e_test.log || { echo "ERROR: external macro AXI descriptor-fetch scoreboard check missing"; exit 1; }

# Real Compute Cluster UVM: the production top, dispatcher, all seven engines,
# compute SPAD mux, scheduler arbiter, protection, and four-bank SRAM are active.
# Coverage and generated files stay outside the source tree.
uvm_compute_cluster_compile:
	mkdir -p $(COMPUTE_CLUSTER_UVM_OUT)/csrc
	$(VCS_UVM) -cm $(UVM_COV_METRICS) -cm_dir $(COMPUTE_CLUSTER_UVM_OUT)/compile.vdb \
		-Mdir=$(COMPUTE_CLUSTER_UVM_OUT)/csrc -top tb_ai_accel_uvm -f ai_accel_uvm.f \
		-o $(COMPUTE_CLUSTER_UVM_OUT)/simv_uvm -l $(COMPUTE_CLUSTER_UVM_OUT)/compile.log

uvm_compute_cluster_regress: uvm_compute_cluster_compile
	@set -e; out='$(COMPUTE_CLUSTER_UVM_OUT)'; logs=''; cov_dbs=''; \
	for seed in $(COMPUTE_CLUSTER_UVM_SEEDS); do \
		seed_dir="$$out/seed_$$seed"; mkdir -p "$$seed_dir"; \
		log="$$seed_dir/run.log"; db="$$seed_dir/coverage.vdb"; \
		logs="$$logs $$log"; cov_dbs="$$cov_dbs $$db"; \
		"$$out/simv_uvm" +UVM_TESTNAME=ai_compute_cluster_e2e_test \
			+COMPUTE_CLUSTER_SEED=$$seed +ntb_random_seed=$$seed \
			-cm $(UVM_COV_METRICS) -cm_dir "$$db" -l "$$log"; \
		grep -q '\[COMPUTE_CLUSTER_REAL_UVM_PASS\]' "$$log" || { echo "ERROR: real Compute Cluster pass marker missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_A_CACHE_BASELINE_PASS\]' "$$log" || { echo "ERROR: standalone Matrix A-tile cache baseline marker missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_CNM_OWNER_PASS\]' "$$log" || { echo "ERROR: Matrix/CNM independent response-owner check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_CNM_ADDR_PASS\]' "$$log" || { echo "ERROR: four-lane CNM address scoreboard check missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_ALL_ENGINES_PASS\].*real pair overlaps=21/21 mask=1fffff' "$$log" || { echo "ERROR: real seven-engine pairwise overlap Golden sweep missing or incomplete in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_ABORT_CROSS_PASS\]' "$$log" || { echo "ERROR: multi-engine software-abort cross missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_RESET_RECOVERY_PASS\]' "$$log" || { echo "ERROR: real compute-cluster active-reset/recovery check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_ENGINE_RESET_PASS\].*reset mask=1111111' "$$log" || { echo "ERROR: accepted-read reset/drain sweep for all seven real engines missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_ENGINE_ABORT_PASS\].*abort mask=1111111' "$$log" || { echo "ERROR: accepted-read software Abort/drain sweep for all seven real engines missing in $$log"; exit 1; }; \
		test "$$(grep -c ' \[CLUSTER_ENGINE_ABORT_CASE_PASS\] engine=' "$$log")" -eq 7 || { echo "ERROR: expected all seven real-engine accepted-read Abort cases in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_SFU_ABORT_WRITE_PREFIX_PASS\]' "$$log" || { echo "ERROR: SFU accepted-write Abort prefix check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_CONV_ABORT_WRITE_PREFIX_PASS\]' "$$log" || { echo "ERROR: Conv accepted-write Abort prefix check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_MATRIX_ABORT_WRITE_PREFIX_PASS\]' "$$log" || { echo "ERROR: Matrix accepted-write Abort prefix check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_MATRIX_LINE_ABORT_WRITE_PREFIX_PASS\]' "$$log" || { echo "ERROR: Matrix aligned Line accepted-write Abort prefix check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_CNM_ABORT_WRITE_PREFIX_PASS\]' "$$log" || { echo "ERROR: CNM accepted-write Abort prefix check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_DMA_RESPONSE_PASS\]' "$$log" || { echo "ERROR: real top DMA response-client read check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_LAUNCH_FIELDS_PASS\]' "$$log" || { echo "ERROR: descriptor launch-snapshot/unused-field checks missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_PARAMETER_LATCH_PASS\]' "$$log" || { echo "ERROR: in-flight descriptor parameter-latch check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_MATRIX_PARAMETER_LATCH_PASS\]' "$$log" || { echo "ERROR: real Matrix in-flight descriptor parameter-latch check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_SFU_PARAMETER_LATCH_PASS\]' "$$log" || { echo "ERROR: real SFU in-flight descriptor parameter-latch check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_SHARED_READONLY_PASS\]' "$$log" || { echo "ERROR: cross-engine shared read-only SPAD check missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_REQUEST_STABILITY_PASS\]' "$$log" || { echo "ERROR: stalled compute request-stability check missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_MATRIX_LINE_STALL_PASS\].*stability checks=[1-9][0-9]* violations=0' "$$log" || { echo "ERROR: real Matrix line-write backpressure stability check missing or failed in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_SERIAL_BENCH_PASS\].*total=[1-9][0-9]*' "$$log" || { echo "ERROR: serial compute benchmark timing missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_STAGED_BENCH_PASS\].*speedup=[1-9].*pair_contention_cycles=[1-9][0-9]*' "$$log" || { echo "ERROR: staged Matrix/CNM contention then SFU benchmark timing missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_PARALLEL_BENCH_PASS\].*speedup=[1-9]' "$$log" || { echo "ERROR: parallel compute benchmark timing missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_RECOVERY_BENCH\].*completion=[1-9][0-9]* cycles' "$$log" || { echo "ERROR: reset-to-recovery timing missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_RESPONSE_CLIENT_DISPOSITION\].*DMA read-response bin=[1-9][0-9]* PASS; completion read-response bin=0 WAIVED' "$$log" || { echo "ERROR: DMA/completion response-client disposition missing in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_SCOREBOARD\]' "$$log" || { echo "ERROR: compute-cluster scoreboard report missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_MEMORY_SCOREBOARD\].*checked_words=[1-9][0-9]* mismatches=0 unknown_reads=0' "$$log" || { echo "ERROR: independent scratchpad memory scoreboard did not close cleanly in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_RANDOM_FAULT_CROSS_PASS\].*parity cases=18/18' "$$log" || { echo "ERROR: randomized seven-engine parity fault cross missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_PARITY_OWNER_CROSS_PASS\].*overlap_cycles=[1-9][0-9]* shared_banked_accepts=[1-9][0-9]* matrix_rsp=[1-9][0-9]* cnm_rsp=[1-9][0-9]* route_mismatch=0; held-read fault cancellations=1' "$$log" || { echo "ERROR: concurrent Matrix parity error/CNM owner-isolation/fault-cancel cross missing or failed in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_PROTECTION_OWNER_CROSS_PASS\].*overlap_cycles=[1-9][0-9]* shared_banked_accepts=[1-9][0-9]* matrix_rsp=[1-9][0-9]* cnm_rsp=[1-9][0-9]* route_mismatch=0; no Matrix writeback; ordered completion' "$$log" || { echo "ERROR: concurrent Matrix Protection error/CNM owner-isolation cross missing or failed in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_PROTECTION_ABORT_OWNER_CROSS_PASS\].*Matrix Protection ERR 0x62 is preserved before CNM software Abort ERR 0x32; overlap_cycles=[1-9][0-9]* shared_banked_accepts=[1-9][0-9]* matrix_rsp=[1-9][0-9]* cnm_rsp=[1-9][0-9]* route_mismatch=0; no Matrix writeback; CNM outputs are Golden or untouched' "$$log" || { echo "ERROR: concurrent Matrix Protection/CNM Abort owner cross missing or failed in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_CNM_PROTECTION_MATRIX_OWNER_CROSS_PASS\].*CNM source-A Protection ERR 0x62 while Matrix remains active and completes 512-word Golden; both_busy=[1-9][0-9]* overlap=[1-9][0-9]* MatrixRsp=[1-9][0-9]* CNMRsp=[1-9][0-9]* route_mismatch=0; CNM destination unchanged' "$$log" || { echo "ERROR: concurrent CNM Protection/Matrix owner isolation cross missing or failed in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_CNM_PROTECTION_RESET_OWNER_CROSS_PASS\].*CNM source-A Protection denial concurrent with active Matrix; reset flushed both engines after [1-9][0-9]* accepted Matrix reads, no completion/writeback or post-reset stale response; overlap=[1-9][0-9]*' "$$log" || { echo "ERROR: concurrent CNM Protection/reset/Matrix owner epoch cross missing or failed in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_CPLQ_BACKPRESSURE_PASS\].*blocked_tail=3.*released_head=1.*wrapped_tail=0.*all_engines_idle=1' "$$log" || { echo "ERROR: real-engine CPLQ full hold/release/ordered completion check missing or failed in $$log"; exit 1; }; \
		test "$$(grep -c ' \[CLUSTER_FAULT_CASE_PASS\] case=' "$$log")" -eq 18 || { echo "ERROR: expected all 18 parity fault cases in $$log"; exit 1; }; \
		grep -q '\[CLUSTER_PROTECTION_CROSS_PASS\].*cases=19/19.*sourceA=7 sourceB=5 writeback=7' "$$log" || { echo "ERROR: all-engine phase-qualified real-top protection fault cross missing in $$log"; exit 1; }; \
		test "$$(grep -c ' \[CLUSTER_PROTECTION_CASE_PASS\] engine=' "$$log")" -eq 19 || { echo "ERROR: expected 19 engine/phase protection fault cases in $$log"; exit 1; }; \
		test "$$(grep -c ' \[CLUSTER_PROTECTION_CASE_PASS\].*phase=0 ' "$$log")" -eq 7 || { echo "ERROR: expected seven source-A Protection cases in $$log"; exit 1; }; \
		test "$$(grep -c ' \[CLUSTER_PROTECTION_CASE_PASS\].*phase=1 ' "$$log")" -eq 5 || { echo "ERROR: expected five source-B Protection cases in $$log"; exit 1; }; \
		test "$$(grep -c ' \[CLUSTER_PROTECTION_CASE_PASS\].*phase=2 ' "$$log")" -eq 7 || { echo "ERROR: expected seven writeback Protection cases in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_SCOREBOARD\].*reset_dropped=[1-9][0-9]*' "$$log" || { echo "ERROR: reset did not discard a tracked in-flight SPAD response"; exit 1; }; \
		grep -q '\[CLUSTER_COVERAGE\]' "$$log" || { echo "ERROR: compute-cluster coverage report missing in $$log"; exit 1; }; \
		grep -Eq '\[CLUSTER_COVERAGE\].*focused_compute_cg_applicable=100\.0%.*cpl_read:0[(]N/A[)].*matrix_banked_fault_cancel=1.*cplq_full=[1-9][0-9]*' "$$log" || { echo "ERROR: applicable compute testpoint coverage is not 100%, Matrix parity-cancel/CPLQ-full bin is missing, or completion-read N/A disposition is missing in $$log"; exit 1; }; \
		! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$$log" || { echo "ERROR: UVM warning/error/fatal count is nonzero in $$log"; exit 1; }; \
	done; \
	$(URG) -full64 -dir "$$out/compile.vdb" $$cov_dbs -format text \
		-report "$$out/urg_merged" -log "$$out/urg_merged.log"; \
	test -d "$$out/urg_merged" || { echo "ERROR: merged compute-cluster URG report missing"; exit 1; }; \
	echo "COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS: seeds=$(COMPUTE_CLUSTER_UVM_SEEDS) artifacts=$$out"

# Checker-sensitivity campaign. Mutations change only the passive monitor's
# observation copy. Lifecycle mutations run against all seven engine bits.
uvm_compute_cluster_mutation: uvm_compute_cluster_compile
	@set -e; out='$(COMPUTE_CLUSTER_MUTATION_OUT)'; mkdir -p "$$out"; \
	for mutation in address data owner wstrb; do \
	  log="$$out/$${mutation}.log"; db="$$out/$${mutation}.vdb"; \
	  case "$$mutation" in \
	    address) expected_checker=matrix_request_address ;; \
	    data) expected_checker=memory_data ;; \
	    owner) expected_checker=response_owner_route ;; \
	    wstrb) expected_checker=matrix_write_mask ;; \
	  esac; \
	  "$(COMPUTE_CLUSTER_UVM_OUT)/simv_uvm" +UVM_TESTNAME=ai_compute_cluster_e2e_test \
	    +COMPUTE_CLUSTER_SEED=20261025 +ntb_random_seed=20261025 +CL_MUTATION=$$mutation \
	    -cm $(UVM_COV_METRICS) -cm_dir "$$db" -l "$$log"; \
	  grep -q "\[CLUSTER_MUTATION_INJECTED\].*mutation=$$mutation" "$$log" || { echo "ERROR: mutation $$mutation was not injected"; exit 1; }; \
	  grep -q "\[CLUSTER_MUTATION_CAUGHT\].*mutation=$$mutation checker=$$expected_checker" "$$log" || { echo "ERROR: mutation $$mutation escaped checker $$expected_checker"; exit 1; }; \
	  grep -q 'UVM_ERROR[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$$log" || { echo "ERROR: mutation $$mutation did not produce the expected checker failure"; exit 1; }; \
	  echo "CLUSTER_MUTATION_PASS: mutation=$$mutation log=$$log"; \
	done; \
	for mutation in completion_error_code write_after_error response_epoch; do \
	  log="$$out/$${mutation}.log"; db="$$out/$${mutation}.vdb"; \
	  case "$$mutation" in \
	    completion_error_code) expected_checker=completion_error_code ;; \
	    write_after_error) expected_checker=write_after_error_prefix ;; \
	    response_epoch) expected_checker=response_epoch ;; \
	  esac; \
	  "$(COMPUTE_CLUSTER_UVM_OUT)/simv_uvm" +UVM_TESTNAME=ai_compute_cluster_e2e_test \
	    +COMPUTE_CLUSTER_SEED=20261025 +ntb_random_seed=20261025 +CL_MUTATION=$$mutation \
	    -cm $(UVM_COV_METRICS) -cm_dir "$$db" -l "$$log"; \
	  grep -q "\[CLUSTER_MUTATION_INJECTED\].*mutation=$$mutation" "$$log" || { echo "ERROR: mutation $$mutation was not injected"; exit 1; }; \
	  grep -q "\[CLUSTER_MUTATION_CAUGHT\].*mutation=$$mutation checker=$$expected_checker" "$$log" || { echo "ERROR: mutation $$mutation escaped checker $$expected_checker"; exit 1; }; \
	  grep -q 'UVM_ERROR[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$$log" || { echo "ERROR: mutation $$mutation did not produce the expected checker failure"; exit 1; }; \
	  echo "CLUSTER_MUTATION_PASS: mutation=$$mutation log=$$log"; \
	done; \
	for mutation in done missing_done duplicate_done; do \
	  for engine in 0 1 2 3 4 5 6; do \
	    log="$$out/$${mutation}_engine_$${engine}.log"; db="$$out/$${mutation}_engine_$${engine}.vdb"; \
	    "$(COMPUTE_CLUSTER_UVM_OUT)/simv_uvm" +UVM_TESTNAME=ai_compute_cluster_e2e_test \
	      +COMPUTE_CLUSTER_SEED=20261025 +ntb_random_seed=20261025 \
	      +CL_MUTATION=$$mutation +CL_MUTATION_ENGINE=$$engine \
	      -cm $(UVM_COV_METRICS) -cm_dir "$$db" -l "$$log"; \
	    grep -q "\[CLUSTER_MUTATION_INJECTED\].*mutation=$$mutation engine=$$engine" "$$log" || { echo "ERROR: mutation $$mutation for engine $$engine was not injected"; exit 1; }; \
	    grep -q "\[CLUSTER_MUTATION_CAUGHT\].*mutation=$$mutation checker=engine_done_lifecycle" "$$log" || { echo "ERROR: mutation $$mutation for engine $$engine escaped lifecycle checker"; exit 1; }; \
	    grep -q 'UVM_ERROR[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$$log" || { echo "ERROR: mutation $$mutation for engine $$engine did not produce the expected checker failure"; exit 1; }; \
	    echo "CLUSTER_MUTATION_PASS: mutation=$$mutation engine=$$engine log=$$log"; \
	  done; \
	done; \
	echo "COMPUTE_CLUSTER_MUTATION_CAMPAIGN_PASS: address data owner wstrb completion_error_code write_after_error response_epoch plus done/missing_done/duplicate_done on all seven engines (28/28); expected checker verified per mutation; artifacts=$$out"

# Opt-in AXI address/data/response gaps are seeded per vector plan and sampled
# per transaction. The focused target requires configuration and stall markers.
uvm_mixed_precision_ddr_e2e_axi_stalls: uvm_compile
	./simv_uvm +UVM_TESTNAME=ai_mixed_precision_ddr_e2e_test +MIXED_E2E_SEED=20261015 +ntb_random_seed=20261015 +MIXED_E2E_AXI_STALLS=1 +MIXED_E2E_AXI_TXN_JITTER=1 +MIXED_E2E_AR_GAP=2 +MIXED_E2E_AW_GAP=3 -l uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log
	@grep -q '\[MIXED_E2E_AXI_STALL\].*phase=pre_dma ar_gap_cfg=[0-3] aw_gap_cfg=[0-3] read_gap_cfg=[0-3] ready_gap_cfg=[0-3] txn_jitter=1' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: per-transaction AXI jitter configuration marker missing"; exit 1; }
	@grep -q '\[MIXED_E2E_AXI_STALL\].*phase=post_reset ar_gap_cfg=[0-3] aw_gap_cfg=[0-3] read_gap_cfg=[0-3] ready_gap_cfg=[0-3] txn_jitter=1' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: post-reset per-transaction AXI jitter configuration marker missing"; exit 1; }
	@grep -q '\[AXI_MEM_ADDR_STALL\] channel=AR configured=[1-3] observed=[1-9][0-9]*' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: ARREADY address backpressure was not exercised"; exit 1; }
	@grep -q '\[AXI_MEM_ADDR_STALL\] channel=AW configured=[1-3] observed=[1-9][0-9]*' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: AWREADY address backpressure was not exercised"; exit 1; }
	@grep -Eq 'c_ar_stall_then_accept, [0-9]+ attempts, [1-9][0-9]* match' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: AR stall-to-accept SVA cover was not hit"; exit 1; }
	@grep -Eq 'c_aw_stall_then_accept, [0-9]+ attempts, [1-9][0-9]* match' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: AW stall-to-accept SVA cover was not hit"; exit 1; }
	@grep -Eq 'c_w_stall_then_accept, [0-9]+ attempts, [1-9][0-9]* match' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: W stall-to-accept SVA cover was not hit"; exit 1; }
	@grep -q '\[MIXED_E2E_ACTIVE_RESET_PASS\]' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: active-compute reset check missing"; exit 1; }
	@grep -q '\[MIXED_E2E_DDR_INDEPENDENT_RESET_PASS\]' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: DDR service across accelerator-only reset check missing"; exit 1; }
	@grep -q '\[MIXED_E2E_DMA_RESET_PASS\]' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: outstanding-DMA reset check missing"; exit 1; }
	@grep -q '\[MIXED_E2E_FP_ABORT_PASS\]' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: real FP software-abort check missing"; exit 1; }
	@grep -q '\*\* Report counts by severity' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: UVM report summary missing"; exit 1; }
	@! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log || { echo "ERROR: UVM warning/error/fatal count is nonzero"; exit 1; }

# Compile once, then run reproducible randomized operands/K lengths while
# exhaustively sweeping all six legal orderings of FP16, BF16, and INT8 CMDQ
# descriptors. Keep invalid-descriptor/queue-wrap checks in every run.
uvm_mixed_precision_ddr_e2e_regress: uvm_compile
	@set -e; seed_count=$$(set -- $(MIXED_E2E_SEEDS); echo $$#); \
		[ "$$seed_count" -eq 6 ] || { echo "ERROR: MIXED_E2E_SEEDS must contain exactly six seeds for the order sweep"; exit 1; }; \
		logs=''; order=0; for seed in $(MIXED_E2E_SEEDS); do \
		fp16_k=$$((order % 4 + 1)); bf16_k=$$(((order + 1) % 4 + 1)); \
		log=uvm_run_ai_mixed_precision_ddr_e2e_seed_$${seed}_order_$${order}.log; \
		logs="$$logs $$log"; \
		./simv_uvm +UVM_TESTNAME=ai_mixed_precision_ddr_e2e_test +MIXED_E2E_SEED=$${seed} +MIXED_E2E_ORDER=$${order} +MIXED_E2E_LAYOUT=$${order} +MIXED_E2E_FP16_K=$$fp16_k +MIXED_E2E_BF16_K=$$bf16_k -l $$log; \
		grep -q '\*\* Report counts by severity' $$log || { echo "ERROR: UVM report summary missing from $$log"; exit 1; }; \
		grep -q "\[MIXED_E2E_INVALID_DESC_PASS\].*case=$${order} " $$log || { echo "ERROR: expected invalid-descriptor validator case $$order missing from $$log"; exit 1; }; \
		grep -q '\[MIXED_E2E_AXI_ERROR_PASS\]' $$log || { echo "ERROR: expected DMA AXI-error check missing from $$log"; exit 1; }; \
		grep -q '\[MIXED_E2E_AXI_ERROR_CASE_PASS\].*error-on-first-beat' $$log || { echo "ERROR: first-beat SLVERR position missing from $$log"; exit 1; }; \
		grep -q '\[MIXED_E2E_AXI_ERROR_CASE_PASS\].*error-on-last-beat' $$log || { echo "ERROR: last-beat SLVERR position missing from $$log"; exit 1; }; \
		grep -q '\[MIXED_E2E_ACTIVE_RESET_PASS\]' $$log || { echo "ERROR: active-compute reset check missing from $$log"; exit 1; }; \
		grep -q '\[MIXED_E2E_DDR_INDEPENDENT_RESET_PASS\]' $$log || { echo "ERROR: DDR service across accelerator-only reset check missing from $$log"; exit 1; }; \
		grep -q '\[MIXED_E2E_DMA_RESET_PASS\]' $$log || { echo "ERROR: outstanding-DMA reset check missing from $$log"; exit 1; }; \
		grep -q '\[MIXED_E2E_RESET_RECOVERY_PASS\]' $$log || { echo "ERROR: expected post-reset recovery check missing from $$log"; exit 1; }; \
		grep -q '\[MIXED_E2E_FP_ABORT_PASS\]' $$log || { echo "ERROR: real FP software-abort check missing from $$log"; exit 1; }; \
		grep -q "\[MIXED_E2E_ORDER\].*permutation=$${order} " $$log || { echo "ERROR: expected descriptor order $$order missing from $$log"; exit 1; }; \
		grep -q "\[MIXED_E2E_VECTOR\].*SPAD_LAYOUT=$${order} " $$log || { echo "ERROR: expected scratchpad layout $$order missing from $$log"; exit 1; }; \
		! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' $$log || { echo "ERROR: UVM warning/error/fatal count is nonzero in $$log"; exit 1; }; \
		order=$$((order + 1)); \
	done; \
	for permutation in 0 1 2 3 4 5; do \
		grep -q "\[MIXED_E2E_ORDER\].*permutation=$$permutation " $$logs || { echo "ERROR: descriptor permutation $$permutation was not covered"; exit 1; }; \
		grep -q "\[MIXED_E2E_INVALID_DESC_PASS\].*case=$$permutation " $$logs || { echo "ERROR: invalid-descriptor validator case $$permutation was not covered"; exit 1; }; \
	done; \
	for format in FP16 BF16; do for length in 1 2 3 4; do \
		grep -Eq "\\[MIXED_E2E_VECTOR\\].*$$format K=$$length " $$logs || { echo "ERROR: missing $$format K=$$length coverage across seeds: $$logs"; exit 1; }; \
	done; done; \
	echo "MIXED_E2E_LENGTH_COVERAGE_PASS: FP16/BF16 K=1..4 (odd tail and two packed words)"; \
	echo "MIXED_E2E_DESCRIPTOR_ORDER_COVERAGE_PASS: permutations=6/6"; \
	echo "MIXED_E2E_INVALID_DESCRIPTOR_COVERAGE_PASS: opcode/version/dimensions/alignment/fp_stride/fp_flags=6/6"; \
	echo "MIXED_E2E_DMA_ERROR_RESET_RECOVERY_PASS: AXI SLVERR and post-reset FP16 command=6/6"

# Coverage-enabled version sweeps the full 4x4 FP16/BF16 K-length cross while
# cycling all six descriptor orders and scratchpad layouts. Each simulation
# writes a separate VDB for a reproducible URG merge.
uvm_mixed_precision_ddr_e2e_cov_regress:
	@set -e; out='$(MIXED_E2E_COV_OUT)'; \
		seed_count=$$(set -- $(MIXED_E2E_COV_SEEDS); echo $$#); \
		[ "$$seed_count" -eq 16 ] || { echo "ERROR: MIXED_E2E_COV_SEEDS must contain exactly 16 seeds for the full FP16/BF16 K cross"; exit 1; }; \
		mkdir -p "$$out/csrc"; \
		$(VCS_UVM) -cm $(UVM_COV_METRICS) -Mdir="$$out/csrc" \
			-top tb_ai_accel_uvm -f ai_accel_uvm.f -o "$$out/simv_uvm" \
			-l "$$out/compile.log"; \
		logs=''; cov_dbs=''; run=0; \
		for seed in $(MIXED_E2E_COV_SEEDS); do \
			order=$$((run % 6)); fp16_k=$$((run / 4 + 1)); bf16_k=$$((run % 4 + 1)); \
			seed_dir="$$out/seed_$$seed"; mkdir -p "$$seed_dir"; \
			log="$$seed_dir/run.log"; db="$$seed_dir/coverage.vdb"; \
			logs="$$logs $$log"; cov_dbs="$$cov_dbs $$db"; \
			"$$out/simv_uvm" +UVM_TESTNAME=ai_mixed_precision_ddr_e2e_test \
				+MIXED_E2E_SEED=$$seed +MIXED_E2E_ORDER=$$order \
				+MIXED_E2E_LAYOUT=$$order +MIXED_E2E_FP16_K=$$fp16_k \
				+MIXED_E2E_BF16_K=$$bf16_k +MIXED_E2E_AXI_STALLS=1 +MIXED_E2E_AXI_TXN_JITTER=1 \
				+MIXED_E2E_AR_GAP=$$((run % 4)) \
				+MIXED_E2E_AW_GAP=$$(((run / 4) % 4)) \
				+ntb_random_seed=$$seed -cm $(UVM_COV_METRICS) -cm_dir "$$db" -l "$$log"; \
			grep -q '\[MIXED_E2E_PASS\]' "$$log" || { echo "ERROR: E2E pass marker missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_INVALID_REG_SLVERR_PASS\]' "$$log" || { echo "ERROR: unmapped AXI-Lite register SLVERR check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_NARROW_AXI_PASS\]' "$$log" || { echo "ERROR: narrow-32 AXI read/write lane check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_COVERAGE\]' "$$log" || { echo "ERROR: functional coverage report missing in $$log"; exit 1; }; \
			grep -q "\[MIXED_E2E_VECTOR\].*SPAD_LAYOUT=$$order " "$$log" || { echo "ERROR: scratchpad layout $$order missing in $$log"; exit 1; }; \
			grep -q "\[MIXED_E2E_INVALID_DESC_PASS\].*case=$$order " "$$log" || { echo "ERROR: invalid-descriptor case $$order missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_AXI_ERROR_PASS\]' "$$log" || { echo "ERROR: DMA SLVERR check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_AXI_ERROR_CASE_PASS\].*error-on-first-beat' "$$log" || { echo "ERROR: first-beat SLVERR position missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_AXI_ERROR_CASE_PASS\].*error-on-last-beat' "$$log" || { echo "ERROR: last-beat SLVERR position missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_ACTIVE_RESET_PASS\]' "$$log" || { echo "ERROR: active-compute reset check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_DDR_INDEPENDENT_RESET_PASS\]' "$$log" || { echo "ERROR: DDR service across accelerator-only reset check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_RESET_RECOVERY_PASS\]' "$$log" || { echo "ERROR: reset recovery check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_FP_ABORT_PASS\]' "$$log" || { echo "ERROR: real FP software-abort check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_AXI_STALL\].*phase=pre_dma ar_gap_cfg=[0-3] aw_gap_cfg=[0-3] read_gap_cfg=[0-3] ready_gap_cfg=[0-3] txn_jitter=1' "$$log" || { echo "ERROR: pre-DMA per-transaction AXI jitter missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_AXI_STALL\].*phase=post_reset ar_gap_cfg=[0-3] aw_gap_cfg=[0-3] read_gap_cfg=[0-3] ready_gap_cfg=[0-3] txn_jitter=1' "$$log" || { echo "ERROR: post-reset per-transaction AXI jitter missing in $$log"; exit 1; }; \
			grep -q "\[MIXED_E2E_AXI_STALL\].*phase=pre_dma ar_gap_cfg=$$((run % 4)) aw_gap_cfg=$$(((run / 4) % 4)) " "$$log" || { echo "ERROR: deterministic AR/AW gap pair missing in $$log"; exit 1; }; \
			! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$$log" || { echo "ERROR: UVM warning/error/fatal count is nonzero in $$log"; exit 1; }; \
			run=$$((run + 1)); \
		done; \
		grep -q '\[AXI_MEM_ADDR_STALL\] channel=AR configured=[1-3] observed=' $$logs || { echo "ERROR: address-channel AR backpressure was never exercised"; exit 1; }; \
		grep -q '\[AXI_MEM_ADDR_STALL\] channel=AW configured=[1-3] observed=' $$logs || { echo "ERROR: address-channel AW backpressure was never exercised"; exit 1; }; \
		for format in FP16 BF16; do for length in 1 2 3 4; do \
			grep -Eq "\[MIXED_E2E_VECTOR\].*$$format K=$$length " $$logs || { echo "ERROR: missing $$format K=$$length functional coverage"; exit 1; }; \
		done; done; \
		$(URG) -full64 -dir "$$out/simv_uvm.vdb" $$cov_dbs -format text \
			-report "$$out/urg_merged" -log "$$out/urg_merged.log"; \
		test -d "$$out/urg_merged" || { echo "ERROR: URG merged report directory missing"; exit 1; }; \
		! grep -Eq 'Error-\[UCAPI-DNYL\]|Design Not Loaded Yet|Limited design loaded' "$$out/urg_merged.log" || { echo "ERROR: URG did not load the complete compile-time design database"; exit 1; }; \
		grep -Fq 'ai_accel_env_pkg::ai_mixed_precision_e2e_coverage::e2e_cg' "$$out/urg_merged/groups.txt" || { echo "ERROR: merged URG report is missing the E2E functional covergroup"; exit 1; }; \
		grep -Eq '^100\.00 100\.00[[:space:]]+1[[:space:]]+100[[:space:]]+1[[:space:]]+1.*ai_accel_env_pkg::ai_mixed_precision_e2e_coverage::e2e_cg' "$$out/urg_merged/groups.txt" || { echo "ERROR: E2E functional covergroup did not reach 100%"; exit 1; }; \
		for group in axi_arready_stall_cg axi_awready_stall_cg axi_read_response_gap_cg axi_write_data_gap_cg; do \
			grep -Eq "^100\\.00 100\\.00[[:space:]]+1[[:space:]]+100[[:space:]]+1[[:space:]]+1.*tb_ai_accel_uvm\\.axi_mem_u::$${group}" "$$out/urg_merged/groups.txt" || { echo "ERROR: per-transaction AXI coverage group $$group did not reach 100%"; exit 1; }; \
		done; \
		for point in 'cp_descriptor_order 6 0 6' 'cp_spad_layout 6 0 6' 'cp_spad_bank 4 0 4' 'cp_invalid_descriptor 6 0 6' 'cp_fp16_length 4 0 4' 'cp_bf16_length 4 0 4' 'cp_axi_read_gap 4 0 4' 'cp_axi_ready_gap 4 0 4' 'cp_axi_ar_gap 4 0 4' 'cp_axi_aw_gap 4 0 4' 'cp_dma_slverr 1 0 1' 'cp_error_position 2 0 2' 'cp_reset_inflight_compute 1 0 1' 'cp_reset_inflight_dma 1 0 1' 'cp_independent_ddr_reset 1 0 1' 'cp_reset_recovery 1 0 1' 'cp_end_to_end 1 0 1' 'cp_fp_watchdog_completion 1 0 1' 'cp_fp_abort_completion 1 0 1' 'fp16_x_bf16_length 16 0 16'; do \
			set -- $$point; grep -Eq "^$$1[[:space:]]+$$2[[:space:]]+$$3[[:space:]]+$$4[[:space:]]+100\.00" "$$out/urg_merged/grpinfo.txt" || { echo "ERROR: merged functional coverage point $$1 is incomplete"; exit 1; }; \
		done; \
		for property in a_ar_payload_stable_until_accept a_aw_payload_stable_until_accept a_w_payload_stable_until_accept a_ar_burst_stays_within_4k a_aw_burst_stays_within_4k; do \
			awk -v name="tb_ai_accel_uvm.top_axi_master_protocol_sva_u.$$property" 'index($$1, name) > 0 { found=1; if (($$5+0)>0 && ($$6+0)==0 && ($$7+0)==0) pass=1 } END { exit !(found && pass) }' "$$out/urg_merged/asserts.txt" || { echo "ERROR: AXI master SVA $$property was vacuous or failed"; exit 1; }; \
		done; \
		for property in c_ar_stall_then_accept c_aw_stall_then_accept c_w_stall_then_accept; do \
			awk -v name="tb_ai_accel_uvm.top_axi_master_protocol_sva_u.$$property" 'index($$1, name) > 0 { found=1; if (($$5+0)>0 && ($$6+0)==0) pass=1 } END { exit !(found && pass) }' "$$out/urg_merged/asserts.txt" || { echo "ERROR: AXI backpressure cover $$property was not hit"; exit 1; }; \
		done; \
		echo "MIXED_E2E_FUNCTIONAL_COVERAGE_PASS: six order/layout bins, four SPAD banks, six validator bins, FP16/BF16 K=1..4 and all 16 length pairs; seeds=$(MIXED_E2E_COV_SEEDS)"; \
		echo "MIXED_E2E_URG_MERGE_PASS: $$out/urg_merged"; \
		echo "MIXED_E2E_COVERAGE_ARTIFACTS: $$out"

# Seeded random top-level campaign. Unlike the order/length sweeps above, this
# leaves legal descriptor order, SPAD layout, and both FP lengths unconstrained
# so the test's seeded UVM object randomization selects them on every run.
uvm_mixed_precision_ddr_e2e_random_cov_regress:
	@set -e; out='$(MIXED_E2E_RANDOM_OUT)'; \
		seed_count=$$(set -- $(MIXED_E2E_RANDOM_SEEDS); echo $$#); \
		[ "$$seed_count" -ge 16 ] || { echo "ERROR: provide at least 16 MIXED_E2E_RANDOM_SEEDS"; exit 1; }; \
		mkdir -p "$$out/csrc"; \
		$(VCS_UVM) -cm $(UVM_COV_METRICS) -Mdir="$$out/csrc" \
			-top tb_ai_accel_uvm -f ai_accel_uvm.f -o "$$out/simv_uvm" \
			-l "$$out/compile.log"; \
		logs=''; cov_dbs=''; \
		for seed in $(MIXED_E2E_RANDOM_SEEDS); do \
			seed_dir="$$out/seed_$$seed"; mkdir -p "$$seed_dir"; \
			log="$$seed_dir/run.log"; db="$$seed_dir/coverage.vdb"; \
			logs="$$logs $$log"; cov_dbs="$$cov_dbs $$db"; \
			"$$out/simv_uvm" +UVM_TESTNAME=ai_mixed_precision_ddr_e2e_test \
				+MIXED_E2E_SEED=$$seed +ntb_random_seed=$$seed \
				+MIXED_E2E_AXI_STALLS=1 +MIXED_E2E_AXI_TXN_JITTER=1 \
				-cm $(UVM_COV_METRICS) -cm_dir "$$db" -l "$$log"; \
			grep -q '\[MIXED_E2E_PASS\]' "$$log" || { echo "ERROR: E2E pass marker missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_INVALID_REG_SLVERR_PASS\]' "$$log" || { echo "ERROR: unmapped AXI-Lite register SLVERR check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_NARROW_AXI_PASS\]' "$$log" || { echo "ERROR: narrow-32 AXI read/write lane check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_COVERAGE\]' "$$log" || { echo "ERROR: functional coverage report missing in $$log"; exit 1; }; \
			grep -Eq '\[MIXED_E2E_ORDER\].*permutation=[0-5]' "$$log" || { echo "ERROR: randomized descriptor order missing in $$log"; exit 1; }; \
			grep -Eq '\[MIXED_E2E_VECTOR\].*SPAD_LAYOUT=[0-5] .*FP16 K=[1-4].*BF16 K=[1-4]' "$$log" || { echo "ERROR: randomized layout/FP lengths missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_INVALID_DESC_PASS\]' "$$log" || { echo "ERROR: invalid-descriptor checks missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_AXI_ERROR_PASS\]' "$$log" || { echo "ERROR: DMA SLVERR check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_ACTIVE_RESET_PASS\]' "$$log" || { echo "ERROR: active-compute reset check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_DDR_INDEPENDENT_RESET_PASS\]' "$$log" || { echo "ERROR: DDR service across accelerator-only reset check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_DMA_RESET_PASS\]' "$$log" || { echo "ERROR: outstanding-DMA reset check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_RESET_RECOVERY_PASS\]' "$$log" || { echo "ERROR: reset recovery check missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_AXI_STALL\].*phase=pre_dma ar_gap_cfg=[0-3] aw_gap_cfg=[0-3] read_gap_cfg=[0-3] ready_gap_cfg=[0-3] txn_jitter=1' "$$log" || { echo "ERROR: pre-DMA per-transaction AXI jitter missing in $$log"; exit 1; }; \
			grep -q '\[MIXED_E2E_AXI_STALL\].*phase=post_reset ar_gap_cfg=[0-3] aw_gap_cfg=[0-3] read_gap_cfg=[0-3] ready_gap_cfg=[0-3] txn_jitter=1' "$$log" || { echo "ERROR: post-reset per-transaction AXI jitter missing in $$log"; exit 1; }; \
			! grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$$log" || { echo "ERROR: UVM warning/error/fatal count is nonzero in $$log"; exit 1; }; \
		done; \
		grep -q '\[AXI_MEM_ADDR_STALL\] channel=AR configured=[1-3] observed=' $$logs || { echo "ERROR: randomized AR address backpressure was not exercised"; exit 1; }; \
		grep -q '\[AXI_MEM_ADDR_STALL\] channel=AW configured=[1-3] observed=' $$logs || { echo "ERROR: randomized AW address backpressure was not exercised"; exit 1; }; \
		$(URG) -full64 -dir "$$out/simv_uvm.vdb" $$cov_dbs -format text \
			-report "$$out/urg_merged" -log "$$out/urg_merged.log"; \
		test -d "$$out/urg_merged" || { echo "ERROR: URG merged report directory missing"; exit 1; }; \
		! grep -Eq 'Error-\[UCAPI-DNYL\]|Design Not Loaded Yet|Limited design loaded' "$$out/urg_merged.log" || { echo "ERROR: URG did not load the complete compile-time design database"; exit 1; }; \
		grep -Fq 'ai_accel_env_pkg::ai_mixed_precision_e2e_coverage::e2e_cg' "$$out/urg_merged/groups.txt" || { echo "ERROR: merged URG report is missing the E2E functional covergroup"; exit 1; }; \
		grep -Eq '^100\.00 100\.00[[:space:]]+1[[:space:]]+100[[:space:]]+1[[:space:]]+1.*ai_accel_env_pkg::ai_mixed_precision_e2e_coverage::e2e_cg' "$$out/urg_merged/groups.txt" || { echo "ERROR: randomized E2E functional covergroup did not reach 100%"; exit 1; }; \
		for group in axi_arready_stall_cg axi_awready_stall_cg axi_read_response_gap_cg axi_write_data_gap_cg; do \
			grep -Eq "^100\\.00 100\\.00[[:space:]]+1[[:space:]]+100[[:space:]]+1[[:space:]]+1.*tb_ai_accel_uvm\\.axi_mem_u::$${group}" "$$out/urg_merged/groups.txt" || { echo "ERROR: per-transaction AXI coverage group $$group did not reach 100%"; exit 1; }; \
		done; \
		for point in 'cp_descriptor_order 6 0 6' 'cp_spad_layout 6 0 6' 'cp_spad_bank 4 0 4' 'cp_invalid_descriptor 6 0 6' 'cp_fp16_length 4 0 4' 'cp_bf16_length 4 0 4' 'cp_axi_read_gap 4 0 4' 'cp_axi_ready_gap 4 0 4' 'cp_axi_ar_gap 4 0 4' 'cp_axi_aw_gap 4 0 4' 'cp_dma_slverr 1 0 1' 'cp_reset_inflight_compute 1 0 1' 'cp_reset_inflight_dma 1 0 1' 'cp_independent_ddr_reset 1 0 1' 'cp_reset_recovery 1 0 1' 'cp_end_to_end 1 0 1' 'cp_fp_watchdog_completion 1 0 1' 'cp_fp_abort_completion 1 0 1' 'fp16_x_bf16_length 16 0 16'; do \
			set -- $$point; grep -Eq "^$$1[[:space:]]+$$2[[:space:]]+$$3[[:space:]]+$$4[[:space:]]+100\.00" "$$out/urg_merged/grpinfo.txt" || { echo "ERROR: randomized functional coverage point $$1 is incomplete"; exit 1; }; \
		done; \
		echo "MIXED_E2E_RANDOM_COVERAGE_PASS: descriptor/K/data and four per-transaction AXI response/backpressure groups; seeds=$(MIXED_E2E_RANDOM_SEEDS)"; \
		echo "MIXED_E2E_RANDOM_URG_MERGE_PASS: $$out/urg_merged"; \
		echo "MIXED_E2E_RANDOM_COVERAGE_ARTIFACTS: $$out"

# Backward-compatible target name retained from the original FP16-only slice.
uvm_fp16_ddr_e2e: uvm_mixed_precision_ddr_e2e

clean:
	rm -rf csrc simv_uvm* *.log ucli.key *.vpd vc_hdrs.h DVE* novas* *.daidir *.vdb *.key
