VCS ?= vcs
URG ?= urg
UVM_TEST ?= control_reset_version_test
SIMV ?= simv_control_uvm
COV_DIR ?= simv_control_uvm.vdb
RUN_LOG ?= logs/$(UVM_TEST).log
CM_METRICS ?= line+cond+fsm+tgl+branch+assert
SEED ?= 20260813
TESTS := control_reset_version_test control_register_file_test control_protocol_test control_channel_backpressure_test control_inflight_reset_test control_irq_error_test \
	control_busy_abort_test control_random_rw_test control_ral_access_test

.PHONY: uvm_compile run_sim uvm_run uvm_smoke uvm_regress coverage descriptor-validator-regress

uvm_compile:
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all \
		-cm $(CM_METRICS) -cm_dir $(COV_DIR) \
		-timescale=1ns/1ps -f control_uvm.f -o $(SIMV)

run_sim:
	@mkdir -p $$(dirname $(RUN_LOG)); \
	./$(SIMV) -cm $(CM_METRICS) -cm_name $(UVM_TEST) +UVM_TESTNAME=$(UVM_TEST) +ntb_random_seed=$(SEED) +UVM_VERBOSITY=UVM_MEDIUM > $(RUN_LOG) 2>&1; rc=$$?; \
	cat $(RUN_LOG); \
	if [ $$rc -ne 0 ] || grep -Eq 'UVM_(ERROR|FATAL) :[[:space:]]*[1-9]' $(RUN_LOG); then \
	  echo "CONTROL UVM FAILED: $(UVM_TEST)"; exit 1; \
	fi

uvm_run: uvm_compile run_sim

uvm_smoke:
	$(MAKE) uvm_run UVM_TEST=control_reset_version_test

uvm_regress: uvm_compile
	@set -e; for test in $(TESTS); do \
	  echo "=== CONTROL UVM $$test ==="; \
	  $(MAKE) run_sim UVM_TEST=$$test RUN_LOG=logs/$$test.log; \
	done

coverage:
	$(URG) -dir $(COV_DIR) -report coverage/report

DESCRIPTOR_VALIDATOR_OUT ?= /tmp/nmaforge_descriptor_validator_r90
descriptor-validator-regress:
	mkdir -p $(DESCRIPTOR_VALIDATOR_OUT)
	$(VCS) -full64 -sverilog -timescale=1ns/1ps \
		-Mdir=$(DESCRIPTOR_VALIDATOR_OUT)/csrc \
		-top tb_ai_descriptor_validator \
		../../../../rtl/control/descriptor/ai_descriptor_validator.v \
		../../../../rtl/control/descriptor/ai_accel_opcode_decode.v \
		../tb/tb_ai_descriptor_validator.sv \
		-o $(DESCRIPTOR_VALIDATOR_OUT)/simv \
		-l $(DESCRIPTOR_VALIDATOR_OUT)/compile.log
	$(DESCRIPTOR_VALIDATOR_OUT)/simv -l $(DESCRIPTOR_VALIDATOR_OUT)/run.log
	@grep -q '^DESCRIPTOR_VALIDATOR_PASS legal_opcodes=27 tile_pack=1 invalid_rules=21 opcode_classes_consistent=1$$' $(DESCRIPTOR_VALIDATOR_OUT)/run.log
