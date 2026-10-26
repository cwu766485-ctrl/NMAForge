VCS ?= vcs -licwait 1
URG ?= /opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
SEED ?= 20261021
OUT_DIR ?= /tmp/nmaforge_matrix_datapath_$(SEED)
CORE_OUT_DIR ?= /tmp/nmaforge_matrix_core_$(SEED)
ARRAY_OUT_DIR ?= /tmp/nmaforge_matrix_array_20261025
ARRAY_SEEDS ?= 20261025 20261026 20261027
ARRAY_SIZES ?= 8 16
OUTSTANDING_DEPTH ?= 4
A_TILE_CACHE_ENABLE ?= 1
NEXT_K_PREFETCH_ENABLE ?= 1
COV_METRICS := line+cond+fsm+branch

.PHONY: datapath-random-test datapath-random-compile datapath-random-run \
	core-random-test core-random-compile core-random-run a3-core-test \
	datapath-random-regress core-random-regress array-random-regress \
	matrix-size-benchmark matrix-pipeline-benchmark matrix-config-comparison

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
		+define+MATRIX_MAX_OUTSTANDING_READS=$(OUTSTANDING_DEPTH) \
		+define+MATRIX_A_TILE_CACHE_ENABLE=$(A_TILE_CACHE_ENABLE) \
		+define+MATRIX_NEXT_K_PREFETCH_ENABLE=$(NEXT_K_PREFETCH_ENABLE) \
		-cm $(COV_METRICS) -cm_hier $(CURDIR)/matrix_core.cm_hier \
		-cm_dir $(CORE_OUT_DIR)/coverage.vdb \
		-Mdir=$(CORE_OUT_DIR)/csrc \
		-top tb_ai_tensor_matrix_core_random \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_datapath.v \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_array.sv \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_core.v \
		../tb/tb_ai_tensor_matrix_core_random.sv \
		-o $(CORE_OUT_DIR)/simv -l $(CORE_OUT_DIR)/compile.log

core-random-run: core-random-compile
	$(CORE_OUT_DIR)/simv +SEED=$(SEED) -cm $(COV_METRICS) \
		-cm_dir $(CORE_OUT_DIR)/coverage.vdb -cm_name matrix_core_seed_$(SEED) -l $(CORE_OUT_DIR)/run.log
	grep -q '^MATRIX_CORE_RANDOM_PASS cases=17 faults=17 late_tile_faults=1 fault_abort_combo=1 reset_fault_combo=1 reset_recovery=1 outstanding_abort=1 outstanding_parity=1 prefetch_parity=1 prefetch_abort=1 prefetch_watchdog=1 prefetch_reset=1 ' $(CORE_OUT_DIR)/run.log

core-random-regress: core-random-compile
	@set -e; for seed in $(SEEDS); do \
		$(CORE_OUT_DIR)/simv +SEED=$$seed -cm $(COV_METRICS) \
			-cm_dir $(CORE_OUT_DIR)/coverage.vdb -cm_name matrix_core_seed_$$seed \
			-l $(CORE_OUT_DIR)/run_seed_$$seed.log; \
		grep -q "^MATRIX_CORE_RANDOM_PASS cases=17 faults=17 late_tile_faults=1 fault_abort_combo=1 reset_fault_combo=1 reset_recovery=1 outstanding_abort=1 outstanding_parity=1 prefetch_parity=1 prefetch_abort=1 prefetch_watchdog=1 prefetch_reset=1 seed=$$seed " $(CORE_OUT_DIR)/run_seed_$$seed.log; \
	done

array-random-regress:
	@set -e; for size in $(ARRAY_SIZES); do \
		out=$(ARRAY_OUT_DIR)/size_$$size; mkdir -p $$out; \
		$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
			-cm $(COV_METRICS) -cm_hier $(CURDIR)/matrix_array.cm_hier \
			-cm_dir $$out/coverage.vdb -Mdir=$$out/csrc \
			+define+ARRAY_SIZE=$$size -top tb_ai_tensor_matrix_array \
			../../../../../rtl/compute/matrix/ai_tensor_matrix_array.sv \
			../tb/tb_ai_tensor_matrix_array.sv \
			-o $$out/simv -l $$out/compile.log; \
		for seed in $(ARRAY_SEEDS); do \
			$$out/simv +SEED=$$seed -cm $(COV_METRICS) \
				-cm_dir $$out/coverage.vdb -cm_name matrix_array_$${size}_seed_$$seed \
				-l $$out/run_seed_$$seed.log; \
			grep -q "^MATRIX_ARRAY_PASS size=$$size cases=4 saturation=2 overlapped_loads=25 functional_coverage=100.00 seed=$$seed$$" $$out/run_seed_$$seed.log; \
		done; \
		$(URG) -full64 -dir $$out/coverage.vdb -format text -report $$out/urg -log $$out/urg.log; \
	done


BENCH_OUT_DIR ?= /tmp/nmaforge_matrix_size_benchmark_$(SEED)
matrix-size-benchmark:
	@set -e; for size in 4 8 16; do \
		out=$(BENCH_OUT_DIR)/array_$$size; mkdir -p $$out; \
		$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
			+define+MATRIX_MAX_OUTSTANDING_READS=$(OUTSTANDING_DEPTH) \
			+define+MATRIX_A_TILE_CACHE_ENABLE=$(A_TILE_CACHE_ENABLE) \
			+define+MATRIX_NEXT_K_PREFETCH_ENABLE=$(NEXT_K_PREFETCH_ENABLE) \
			-cm $(COV_METRICS) -cm_hier $(CURDIR)/matrix_core.cm_hier \
			-cm_dir $$out/coverage.vdb -Mdir=$$out/csrc \
			+define+MATRIX_ARRAY_SIZE=$$size -top tb_ai_tensor_matrix_core_random \
			../../../../../rtl/compute/matrix/ai_tensor_matrix_datapath.v \
			../../../../../rtl/compute/matrix/ai_tensor_matrix_array.sv \
			../../../../../rtl/compute/matrix/ai_tensor_matrix_core.v \
			../tb/tb_ai_tensor_matrix_core_random.sv \
			-o $$out/simv -l $$out/compile.log; \
		$$out/simv +SEED=$(SEED) +MATRIX_BENCHMARK_ONLY \
			-cm $(COV_METRICS) -cm_dir $$out/coverage.vdb \
			-cm_name matrix_size_array_$${size}_seed_$(SEED) -l $$out/run.log; \
		for case_id in 100 101 102 103 104; do \
			grep -q "^MATRIX_CORE_CASE_PASS id=$$case_id .*physical_array=$${size}x$${size}$$" $$out/run.log; \
		done; \
		grep -q '^MATRIX_SIZE_BENCHMARK_PASS ' $$out/run.log; \
	done

PIPELINE_ARRAY_SIZE ?= 16
PIPELINE_BENCH_OUT ?= /tmp/nmaforge_matrix_pipeline_benchmark_d$(OUTSTANDING_DEPTH)_p$(NEXT_K_PREFETCH_ENABLE)_c$(A_TILE_CACHE_ENABLE)_$(SEED)
matrix-pipeline-benchmark:
	mkdir -p $(PIPELINE_BENCH_OUT)
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		+define+MATRIX_MAX_OUTSTANDING_READS=$(OUTSTANDING_DEPTH) \
		+define+MATRIX_A_TILE_CACHE_ENABLE=$(A_TILE_CACHE_ENABLE) \
		+define+MATRIX_NEXT_K_PREFETCH_ENABLE=$(NEXT_K_PREFETCH_ENABLE) \
		+define+MATRIX_ARRAY_SIZE=$(PIPELINE_ARRAY_SIZE) -top tb_ai_tensor_matrix_core_random \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_datapath.v \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_array.sv \
		../../../../../rtl/compute/matrix/ai_tensor_matrix_core.v \
		../tb/tb_ai_tensor_matrix_core_random.sv \
		-o $(PIPELINE_BENCH_OUT)/simv -l $(PIPELINE_BENCH_OUT)/compile.log
	$(PIPELINE_BENCH_OUT)/simv +SEED=$(SEED) +MATRIX_BENCHMARK_ONLY \
		-l $(PIPELINE_BENCH_OUT)/run.log
	@grep -q '^MATRIX_SIZE_BENCHMARK_PASS .*outstanding_depth=$(OUTSTANDING_DEPTH) next_k_prefetch=$(NEXT_K_PREFETCH_ENABLE) a_tile_cache=$(A_TILE_CACHE_ENABLE) ' $(PIPELINE_BENCH_OUT)/run.log
	@for case_id in 100 101 102 103 104; do grep -q "^MATRIX_CORE_CASE_PASS id=$$case_id .*physical_array=$(PIPELINE_ARRAY_SIZE)x$(PIPELINE_ARRAY_SIZE)$$" $(PIPELINE_BENCH_OUT)/run.log || exit 1; done

MATRIX_CONFIG_OUT ?= /tmp/nmaforge_matrix_config_compare_$(SEED)
matrix-config-comparison:
	@set -e; for depth in 2 4; do \
		for prefetch in 0 1; do \
			for cache in 0 1; do \
				out=$(MATRIX_CONFIG_OUT)/depth_$$depth/prefetch_$$prefetch/cache_$$cache; \
				$(MAKE) --no-print-directory matrix-pipeline-benchmark \
					SEED=$(SEED) OUTSTANDING_DEPTH=$$depth \
					PIPELINE_ARRAY_SIZE=16 \
					NEXT_K_PREFETCH_ENABLE=$$prefetch A_TILE_CACHE_ENABLE=$$cache \
					PIPELINE_BENCH_OUT=$$out; \
			done; \
		done; \
	done; \
	python3 ../../../../../tools/summarize_matrix_config_bench.py --root $(MATRIX_CONFIG_OUT) --seed $(SEED)
