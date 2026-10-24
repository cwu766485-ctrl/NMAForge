VCS ?= vcs -licwait 1
SEED ?= 20261021
OUT_DIR ?= /tmp/nmaforge_matrix_datapath_$(SEED)
CORE_OUT_DIR ?= /tmp/nmaforge_matrix_core_$(SEED)
COV_METRICS := line+cond+fsm+branch

.PHONY: datapath-random-test datapath-random-compile datapath-random-run \
	core-random-test core-random-compile core-random-run a3-core-test \
	datapath-random-regress core-random-regress

datapath-random-test: datapath-random-run

datapath-random-compile:
	mkdir -p $(OUT_DIR)
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-cm $(COV_METRICS) -cm_hier $(CURDIR)/matrix_datapath.cm_hier \
		-cm_dir $(OUT_DIR)/coverage.vdb \
		-Mdir=$(OUT_DIR)/csrc \
		-top tb_ai_tensor_matrix_datapath_random \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_datapath.v \
		../tb/tb_ai_tensor_matrix_datapath_random.sv \
		-o $(OUT_DIR)/simv -l $(OUT_DIR)/compile.log

datapath-random-run: datapath-random-compile
	$(OUT_DIR)/simv +SEED=$(SEED) -cm $(COV_METRICS) \
		-cm_dir $(OUT_DIR)/coverage.vdb -cm_name matrix_datapath_seed_$(SEED) -l $(OUT_DIR)/run.log
	grep -q '^MATRIX_DATAPATH_RANDOM_PASS cases=10072 ' $(OUT_DIR)/run.log

SEEDS ?= 20261021 20261022 20261023
datapath-random-regress: datapath-random-compile
	@set -e; for seed in $(SEEDS); do \
		$(OUT_DIR)/simv +SEED=$$seed -cm $(COV_METRICS) \
			-cm_dir $(OUT_DIR)/coverage.vdb -cm_name matrix_datapath_seed_$$seed \
			-l $(OUT_DIR)/run_seed_$$seed.log; \
		grep -q "^MATRIX_DATAPATH_RANDOM_PASS cases=10072 seed=$$seed$$" $(OUT_DIR)/run_seed_$$seed.log; \
	done

a3-core-test:
	$(MAKE) -C ../../../../subsystem/top_smoke/sim ai_tensor_a3_gemm_bench

core-random-test: core-random-run

core-random-compile:
	mkdir -p $(CORE_OUT_DIR)
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-cm $(COV_METRICS) -cm_hier $(CURDIR)/matrix_core.cm_hier \
		-cm_dir $(CORE_OUT_DIR)/coverage.vdb \
		-Mdir=$(CORE_OUT_DIR)/csrc \
		-top tb_ai_tensor_matrix_core_random \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_datapath.v \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_core.v \
		../tb/tb_ai_tensor_matrix_core_random.sv \
		-o $(CORE_OUT_DIR)/simv -l $(CORE_OUT_DIR)/compile.log

core-random-run: core-random-compile
	$(CORE_OUT_DIR)/simv +SEED=$(SEED) -cm $(COV_METRICS) \
		-cm_dir $(CORE_OUT_DIR)/coverage.vdb -cm_name matrix_core_seed_$(SEED) -l $(CORE_OUT_DIR)/run.log
	grep -q '^MATRIX_CORE_RANDOM_PASS cases=6 faults=12 late_tile_faults=1 fault_abort_combo=1 reset_fault_combo=1 reset_recovery=1 ' $(CORE_OUT_DIR)/run.log

core-random-regress: core-random-compile
	@set -e; for seed in $(SEEDS); do \
		$(CORE_OUT_DIR)/simv +SEED=$$seed -cm $(COV_METRICS) \
			-cm_dir $(CORE_OUT_DIR)/coverage.vdb -cm_name matrix_core_seed_$$seed \
			-l $(CORE_OUT_DIR)/run_seed_$$seed.log; \
		grep -q "^MATRIX_CORE_RANDOM_PASS cases=6 faults=12 late_tile_faults=1 fault_abort_combo=1 reset_fault_combo=1 reset_recovery=1 seed=$$seed " $(CORE_OUT_DIR)/run_seed_$$seed.log; \
	done
