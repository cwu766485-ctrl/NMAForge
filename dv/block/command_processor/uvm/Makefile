VCS ?= vcs
URG ?= urg
SEED ?= 12345
SEEDS ?= 12345 67890 24680
MIXED_COV_CASES ?= 1-0-0 1-0-1 1-0-2 1-0-3 1-1-0 1-1-1 1-1-2 1-1-3 1-3-0 1-3-1 1-3-2 1-3-3 2-0-0 2-0-1 2-0-2 2-0-3 2-1-0 2-1-1 2-1-2 2-1-3 2-3-0 2-3-1 2-3-2 2-3-3
OUT ?= /tmp/nmaforge_cp_uvm
FILELIST := ai_cp_uvm.f
CM_METRICS ?= line+cond+fsm+tgl+branch+assert
COV_OUT ?= $(OUT)/coverage
COV_SIMV := $(COV_OUT)/simv
COV_DBS := $(foreach seed,$(SEEDS),$(foreach mixed,$(MIXED_COV_CASES),$(COV_OUT)/seed_$(seed)_mixed_$(mixed).vdb))

.PHONY: compile run regress partial-reset-sweep abort-reset-sweep cov-compile cov-regress check-coverage clean
compile:
	mkdir -p $(OUT)
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps -f $(FILELIST) -top tb_ai_cp_uvm -l $(OUT)/compile.log -o $(OUT)/simv
	@! grep -Eq 'Warning-|Error-' $(OUT)/compile.log || \
	 { echo "VCS compile reported warning/error; see $(OUT)/compile.log"; exit 1; }
run: compile
	cd $(OUT) && ./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=$(SEED) -l run.log
	@$(MAKE) check-log LOG=$(OUT)/run.log
regress: compile
	@set -e; for seed in $(SEEDS); do \
	  log=$(OUT)/run_$$seed.log; \
	  echo "Running command-processor UVM seed=$$seed"; \
	  cd $(OUT) && ./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=$$seed -l $$log; \
	  $(MAKE) -C $(CURDIR) --no-print-directory check-log LOG=$$log; \
	done
partial-reset-sweep: compile
	@set -e; for words in 0 1 2 3; do \
	  log=partial_reset_words_$${words}.log; \
	  echo "Running completion-writer reset sweep accepted_words=$$words"; \
	  cd $(OUT) && ./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=20261017 \
	    +CP_ONLY_CASE=11 +CP_RESET_WORDS=$$words -l $$log; \
	  grep -Eq "\[CP/PARTIAL_RESET\].*accepted_before_reset=$$words reset_cleared=1 recovery_completions=1 tail=1" $(OUT)/$$log; \
	  grep -Eq 'UVM_WARNING[[:space:]]*:[[:space:]]+0' $(OUT)/$$log; \
	  grep -Eq 'UVM_ERROR[[:space:]]*:[[:space:]]+0' $(OUT)/$$log; \
	  grep -Eq 'UVM_FATAL[[:space:]]*:[[:space:]]+0' $(OUT)/$$log; \
	done
abort-reset-sweep: compile
	@set -e; for words in 0 1 2 3; do \
	  log=abort_reset_words_$${words}.log; \
	  echo "Running ERR_ABORT completion reset sweep accepted_words=$$words"; \
	  cd $(OUT) && ./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=20261017 \
	    +CP_ONLY_CASE=19 +CP_RESET_WORDS=$$words -l $$log; \
	  grep -Eq "\[CP/ABORT_RESET_SWEEP\].*accepted_before_reset=$$words reset_cleared=1 queued_suppressed=1 recovery_completions=1 tail=1" $(OUT)/$$log; \
	  grep -Eq 'UVM_WARNING[[:space:]]*:[[:space:]]+0' $(OUT)/$$log; \
	  grep -Eq 'UVM_ERROR[[:space:]]*:[[:space:]]+0' $(OUT)/$$log; \
	  grep -Eq 'UVM_FATAL[[:space:]]*:[[:space:]]+0' $(OUT)/$$log; \
	done
cov-compile:
	mkdir -p $(COV_OUT)/csrc
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all \
		-timescale=1ns/1ps -cm $(CM_METRICS) -cm_dir $(COV_OUT)/compile.vdb \
		-Mdir=$(COV_OUT)/csrc -f $(FILELIST) -top tb_ai_cp_uvm \
		-o $(COV_SIMV) -l $(COV_OUT)/compile.log
	@! grep -Eq 'Warning-|Error-' $(COV_OUT)/compile.log || \
	 { echo "VCS coverage compile reported warning/error; see $(COV_OUT)/compile.log"; exit 1; }
cov-regress: cov-compile
	@set -e; for seed in $(SEEDS); do \
	  for mixed in $(MIXED_COV_CASES); do \
	    kind=$${mixed%%-*}; rest=$${mixed#*-}; delay=$${rest%%-*}; reset_words=$${rest#*-}; \
	    if [ "$$reset_words" = "$$rest" ]; then reset_words=1; fi; \
	    db=seed_$${seed}_mixed_$${mixed}.vdb; log=run_$${seed}_mixed_$${mixed}.log; \
	    rm -rf $(COV_OUT)/$$db; \
	    echo "Running command-processor coverage seed=$$seed mixed_kind=$$kind abort_delay=$$delay reset_words=$$reset_words"; \
	    cd $(COV_OUT) && ./simv -cm $(CM_METRICS) -cm_dir $$db -cm_name ai_cp_test \
	      +CP_MIXED_KIND=$$kind +CP_MIXED_DELAY=$$delay +CP_MIXED_RESET_WORDS=$$reset_words \
	      +UVM_TESTNAME=ai_cp_test +ntb_random_seed=$$seed -l $$log; \
	    $(MAKE) -C $(CURDIR) --no-print-directory check-log LOG=$(COV_OUT)/$$log; \
	  done; \
	done
	$(URG) -full64 -dir $(COV_OUT)/compile.vdb $(COV_DBS) -format text \
		-report $(COV_OUT)/urg_merged -log $(COV_OUT)/urg_merge.log
	$(MAKE) --no-print-directory check-coverage COV_OUT=$(COV_OUT)
check-coverage:
	@test -s $(COV_OUT)/urg_merged/grpinfo.txt
	@grep -q 'ai_cp_uvm_pkg::ai_cp_coverage::cp_cg' $(COV_OUT)/urg_merged/grpinfo.txt || \
	 { echo "URG report is missing CP functional coverage; see $(COV_OUT)/urg_merge.log"; exit 1; }
	@grep -Eq 'Variables[[:space:]]+61[[:space:]]+0[[:space:]]+61[[:space:]]+100\.00' $(COV_OUT)/urg_merged/grpinfo.txt || \
	 { echo "CP functional variable coverage is not 61/61; see $(COV_OUT)/urg_merged/grpinfo.txt"; exit 1; }
	@grep -Eq 'Crosses[[:space:]]+34[[:space:]]+0[[:space:]]+34[[:space:]]+100\.00' $(COV_OUT)/urg_merged/grpinfo.txt || \
	 { echo "CP functional cross coverage is not 34/34; see $(COV_OUT)/urg_merged/grpinfo.txt"; exit 1; }
	@grep -Eq '^cp_mixed_reset_words[[:space:]]+4[[:space:]]+0[[:space:]]+4[[:space:]]+100\.00' $(COV_OUT)/urg_merged/grpinfo.txt || \
	 { echo "CP mixed reset-word bins are not 4/4; see $(COV_OUT)/urg_merged/grpinfo.txt"; exit 1; }
	@grep -Eq '^cp_mixed_kind_delay_reset_cross[[:space:]]+24[[:space:]]+0[[:space:]]+24[[:space:]]+100\.00' $(COV_OUT)/urg_merged/grpinfo.txt || \
	 { echo "CP mixed kind x delay x reset-word cross is not 24/24; see $(COV_OUT)/urg_merged/grpinfo.txt"; exit 1; }
	@awk '/^Group : ai_cp_uvm_pkg::ai_cp_coverage::abort_timing_cg$$/ { in_group=1; seen=1; next } /^Group :/ && in_group { in_group=0 } in_group && /^Variables[[:space:]]+7[[:space:]]+0[[:space:]]+7[[:space:]]+100\.00/ { hit=1 } END { exit !(seen && hit) }' $(COV_OUT)/urg_merged/grpinfo.txt || \
	 { echo "CP abort-timing functional coverage is not 7/7; see $(COV_OUT)/urg_merged/grpinfo.txt"; exit 1; }
	@! grep -Eq 'Error-\[UCAPI-' $(COV_OUT)/urg_merge.log || \
	 { echo "URG reported missing/corrupt design database; see $(COV_OUT)/urg_merge.log"; exit 1; }
check-log:
	@! grep -Eq '^Error:|^Error-' $(LOG) && \
	 grep -Eq '\[CP/SB\].*launches=' $(LOG) && \
	 grep -Eq '\[CP/TILE\].*tiles=3/3/3 events=1' $(LOG) && \
		 grep -Eq '\[CP/RING\].*expected=(1[2-9]|2[0-4]) accepted=[0-9]+ launches=[0-9]+ retired=[0-9]+ valid=[0-9]+ errors=[1-9][0-9]* launch_pending=0 retire_pending=0' $(LOG) && \
		 grep -Eq '\[CP/RING\].*random_outcomes desc=[1-9][0-9]* fetch=[1-9][0-9]* compute=[1-9][0-9]* success=[1-9][0-9]*' $(LOG) && \
			 grep -Eq 'scenario_bins=31/31' $(LOG) && \
			 grep -Eq '\[CP/ZERO_SIZE_EMPTY\].*cmdq_size=0 equal_pointers=1 compatibility_fetch=1 completion_task_id=1900 CPLQ_tail=1' $(LOG) && \
			 grep -Eq '\[CP/CPLQ_LAST_SLOT\].*queued=2 initial_free_slots=1 first_completion_filled_ring=1 second_held=1 red-doorbell_recovery=1 cpl_tail=2->3->0 cmdq_head=1->2' $(LOG) && \
		 grep -Eq '\[CP/WRITER_FSM\].*illegal_state_injected=1 recovered_idle=1 side_effects=0 recovery_completion=1' $(LOG) && \
		 grep -Eq '\[CP/ABORT\].*compute_abort_inputs=1 launches=2 completions=2' $(LOG) && \
		 grep -Eq '\[CP/ABORT_RESET\].*abort_inputs=2 recovery_launches=2 recovery_completions=2 partial_resets=[23]' $(LOG) && \
		 grep -Eq '\[CP/PARTIAL_RESET\].*accepted_before_reset=1 reset_cleared=1 recovery_completions=1 tail=1' $(LOG) && \
		 grep -Eq '\[CP/ABORT_RESET_SWEEP\].*accepted_before_reset=1 reset_cleared=1 queued_suppressed=1 recovery_completions=1 tail=1' $(LOG) && \
		 grep -Eq '\[CP/MIXED\].*abort_inputs=1 prefix_kind=[12] abort_delay=[0-5] reset_words=[0-3] completion_starts=3 queued_suppressed=1 recovery=1' $(LOG) && \
		 grep -Eq '\[CP/DIRECT\].*invalid_rejected=20 launches=5 events=4 direct_error_events=1 stale_abort_code_ignored=1.*direct_error_code=5 direct_no_cplq_write=1.*success=1' $(LOG) && \
		 grep -Eq '\[CP/CPLQ\].*prefill=3 held=5 resumed=5 completions=8 cmdq_wraps=2 cplq_wraps=2' $(LOG) && \
		 grep -Eq '\[CP/CPLQ\].*fetches=8 launches=8 completions=8' $(LOG) && \
		 grep -Eq '\[CP/CPL_PROTECTION\].*late_protection_abort=1 err_prot=1 completion_write=0 tail_unchanged=1' $(LOG) && \
		 grep -Eq '\[CP/FSM\].*illegal_state_injected=1 recovered_idle=1 side_effects=0' $(LOG) && \
		 grep -Eq '\[CP/SUBMIT_GUARD\].*fetch_resubmit_ignored=1 decode_resubmit_ignored=1 scheduler_busy_ignored=1 tile_busy_ignored=1 completion_abort_ignored=1 recovery=1' $(LOG) && \
		 grep -Eq '\[CP/MACRO_ADDR\].*v7 parent fetch \+ three external child fetches used 64-bit aligned addresses' $(LOG) && \
		   grep -Eq '\[CP/MACRO\].*children=3 parent_completion=7 compute_error_child_launches=1 fetch_error_child_launches=1 fetch_error_parent_completion=1 child_fetch_abort_parent=1 child_decode_abort_parent=1 child_decode_error_parent=1 child_dependency_timeout_parent=1' $(LOG) && \
		   grep -Eq '\[CP/NO_CPLQ\].*fetch_error_event=1 launch=0 completion_write=0 head_advance=1' $(LOG) && \
		   grep -Eq '\[CP/NO_CPLQ\].*fetch_abort_event=1 completion_write=0 launch=0' $(LOG) && \
		   grep -Eq '\[CP/NO_CPLQ\].*decode_abort_event=1 completion_write=0 launch=0 head_advance=1' $(LOG) && \
		   grep -Eq '\[CP/NO_CPLQ\].*invalid_desc_event=1 completion_write=0 launch=0' $(LOG) && \
		   grep -Eq '\[CP/NO_CPLQ\].*dep_timeout_event=1 completion_write=0 launch=0' $(LOG) && \
		   grep -Eq '\[CP/NO_CPLQ\].*macro_invalid_desc_event=1 parent_task_id=15a0 error_code=7 completion_write=0 cplq_tail_advance=0 child_launch=0 later_child_fetch=0 head_advance=1' $(LOG) && \
		   grep -Eq '\[CP/NO_CPLQ\].*macro_dependency_timeout_event=1 parent_task_id=15b0 error_code=12 completion_write=0 cplq_tail_advance=0 child_launch=0 later_child_fetch=0 head_advance=1' $(LOG) && \
		   grep -Eq '\[CP/NO_CPLQ\].*macro_success_events=1 macro_error_events=3 macro_desc_error_events=1 macro_dep_timeout_events=1 macro_child_launches=4' $(LOG) && \
			 grep -Eq '\[CP/MACRO\].*children=3 parent_completion=7 compute_error_child_launches=1 fetch_error_child_launches=1 fetch_error_parent_completion=1 child_fetch_abort_parent=1 child_decode_abort_parent=1 child_decode_error_parent=1 child_dependency_timeout_parent=1 no_cplq_success_children=3 no_cplq_error_stop=1 no_cplq_desc_error=1 no_cplq_dependency_timeout=1' $(LOG) && \
		 grep -Eq '\[CP/ABORT_COV\].*route_bins=3/3 direct_fetch_done=1 macro_child_fetch_parent=1 macro_child_decode_parent=1 ERR_ABORT=3' $(LOG) && \
	 grep -Eq 'UVM_WARNING[[:space:]]*:[[:space:]]+0' $(LOG) && \
	 grep -Eq 'UVM_ERROR[[:space:]]*:[[:space:]]+0' $(LOG) && \
	 grep -Eq 'UVM_FATAL[[:space:]]*:[[:space:]]+0' $(LOG) || \
	 { echo "UVM run is missing required PASS/coverage markers or reported severity; see $(LOG)"; exit 1; }
clean:
	rm -rf $(OUT)
