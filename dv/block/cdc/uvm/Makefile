VCS ?= vcs
URG ?= urg
SIMV ?= simv_cdc_fifo_uvm
COV_DIR ?= $(SIMV).vdb
UVM_TEST ?= cdc_fifo_order_test
SEED ?= 20260928
TESTS := cdc_fifo_order_test cdc_fifo_overflow_test cdc_fifo_underflow_test cdc_fifo_reset_test cdc_fifo_backpressure_test
CM_METRICS ?= line+cond+fsm+tgl+branch+assert
.PHONY: uvm_compile uvm_run uvm_regress clean
uvm_compile:
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -timescale=1ns/1ps +define+VCS -cm $(CM_METRICS) -cm_dir $(COV_DIR) -f cdc_fifo_uvm.f -top tb_cdc_fifo_uvm -o $(SIMV) -l uvm_compile.log
uvm_run: uvm_compile
	rm -rf $(UVM_TEST).vdb; ./$(SIMV) -cm $(CM_METRICS) -cm_dir $(UVM_TEST).vdb -cm_name $(UVM_TEST) +UVM_TESTNAME=$(UVM_TEST) +ntb_random_seed=$(SEED) -l $(UVM_TEST).log; rc=$$?; cat $(UVM_TEST).log; test $$rc -eq 0; ! grep -Eq 'UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]' $(UVM_TEST).log
uvm_regress: uvm_compile
	@set -e; for t in $(TESTS); do echo "=== CDC FIFO $$t ==="; rm -rf $$t.vdb; ./$(SIMV) -cm $(CM_METRICS) -cm_dir $$t.vdb -cm_name $$t +UVM_TESTNAME=$$t +ntb_random_seed=$(SEED) -l $$t.log; rc=$$?; cat $$t.log; test $$rc -eq 0; ! grep -Eq 'UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]' $$t.log; done
	$(URG) -full64 -dir $(COV_DIR) $(foreach t,$(TESTS),$(t).vdb) -dbname urgReport -report urgReport
clean:
	rm -rf $(SIMV) $(SIMV).daidir csrc *.log *.key *.vdb ucli.key vc_hdrs.h urgReport
