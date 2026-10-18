VCS ?= vcs
UVM_HOME ?= $(VCS_HOME)/etc/uvm-1.2
UVM_TEST ?= dma_load_ooo_smoke_test
SIMV ?= simv_dma_uvm
COV_DIR ?= simv_dma_uvm.vdb
COV_ROOT ?= coverage
SEED ?= 20260813
CM_METRICS ?= line+cond+fsm+tgl+branch+assert
TESTS := dma_load_ooo_smoke_test dma_2d_load_test dma_gather_load_test \
	dma_store_booo_test dma_store_four_booo_test dma_2d_store_test dma_aw_stall_stability_test dma_narrow_load_test \
	dma_4k_load_test dma_4k_edge_load_test dma_short_tail_store_test dma_abort_read_test dma_read_slverr_test dma_spad_error_drain_test dma_write_slverr_test dma_abort_write_test dma_config_error_test dma_backpressure_test dma_random_stress_test

.PHONY: uvm_compile uvm_run uvm_smoke uvm_regress coverage clean

uvm_compile:
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all \
		-cm $(CM_METRICS) -cm_dir $(COV_DIR) \
		-timescale=1ns/1ps -f dma_block_uvm.f -o $(SIMV)

uvm_run: uvm_compile
	./$(SIMV) -cm $(CM_METRICS) -cm_dir $(COV_DIR) -cm_name $(UVM_TEST) \
		+UVM_TESTNAME=$(UVM_TEST) +ntb_random_seed=$(SEED) +UVM_VERBOSITY=UVM_MEDIUM

uvm_smoke:
	$(MAKE) uvm_run UVM_TEST=dma_load_ooo_smoke_test

uvm_regress:
	@set -e; for test in $(TESTS); do \
	  echo "=== DMA UVM $$test ==="; \
	  $(MAKE) uvm_run UVM_TEST=$$test COV_DIR=$(COV_ROOT)/$$test.vdb; \
	done

coverage:
	$(URG) -dir $(COV_ROOT)/*.vdb -report $(COV_ROOT)/report

clean:
	rm -rf csrc $(SIMV) $(SIMV).daidir ucli.key vc_hdrs.h *.log simv* verdiLog DVEfiles coverage
