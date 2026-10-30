VCS ?= vcs -licwait 1
SEED ?= 20261021
OUT_DIR ?= /tmp/nmaforge_cnn_kv_random_latency_$(SEED)
COV_METRICS := line+cond+fsm+branch

.PHONY: random-latency-test random-latency-compile random-latency-run
.PHONY: random-latency-regress
.PHONY: tinynpu-cnn-matched-benchmark

random-latency-test: random-latency-run

random-latency-compile:
	mkdir -p $(OUT_DIR)
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-cm $(COV_METRICS) -cm_hier $(CURDIR)/cnn_kv_random.cm_hier \
		-cm_dir $(OUT_DIR)/coverage.vdb \
		-Mdir=$(OUT_DIR)/csrc \
		-top tb_ai_cnn_kv_random_latency \
		../../../../../rtl/compute/cnn/ai_conv3x3_linebuffer_core.v \
		../../../../../rtl/compute/kv/ai_kv_cache_engine.v \
		../tb/tb_ai_cnn_kv_random_latency.sv \
		-o $(OUT_DIR)/simv -l $(OUT_DIR)/compile.log

random-latency-run: random-latency-compile
	$(OUT_DIR)/simv +SEED=$(SEED) -cm $(COV_METRICS) \
		-cm_dir $(OUT_DIR)/coverage.vdb -cm_name cnn_kv_seed_$(SEED) -l $(OUT_DIR)/run.log
	grep -q '^CNN_KV_RANDOM_LATENCY_PASS ' $(OUT_DIR)/run.log
	@test "$$(grep -c '^KV_ADDRESS_CONFIG_PASS case=' $(OUT_DIR)/run.log)" -eq 10
	grep -q '^KV_ADDRESS_BOUNDARY_PASS address=0007fffc read_write=1$$' $(OUT_DIR)/run.log
	@for case_id in 0 1 2 3 4 5 6 7 8 9; do \
		grep -q "^KV_ADDRESS_CONFIG_PASS case=$$case_id$$" $(OUT_DIR)/run.log || exit 1; \
	done

SEEDS ?= 20261021 20261022 20261023
random-latency-regress: random-latency-compile
	@set -e; for seed in $(SEEDS); do \
		$(OUT_DIR)/simv +SEED=$$seed -cm $(COV_METRICS) \
			-cm_dir $(OUT_DIR)/coverage.vdb -cm_name cnn_kv_seed_$$seed \
			-l $(OUT_DIR)/run_seed_$$seed.log; \
		grep -q "^CNN_KV_RANDOM_LATENCY_PASS .*seed=$$seed " $(OUT_DIR)/run_seed_$$seed.log; \
		test "$$(grep -c '^KV_ADDRESS_CONFIG_PASS case=' $(OUT_DIR)/run_seed_$$seed.log)" -eq 10; \
		grep -q '^KV_ADDRESS_BOUNDARY_PASS address=0007fffc read_write=1$$' $(OUT_DIR)/run_seed_$$seed.log; \
		for case_id in 0 1 2 3 4 5 6 7 8 9; do \
			grep -q "^KV_ADDRESS_CONFIG_PASS case=$$case_id$$" $(OUT_DIR)/run_seed_$$seed.log || exit 1; \
		done; \
	done

TINYNPU_CNN_OUT ?= /tmp/nmaforge_cnn_tinynpu_match_$(SEED)
tinynpu-cnn-matched-benchmark:
	mkdir -p $(TINYNPU_CNN_OUT)
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-Mdir=$(TINYNPU_CNN_OUT)/csrc \
		-top tb_ai_cnn_kv_random_latency \
		../../../../../rtl/compute/cnn/ai_conv3x3_linebuffer_core.v \
		../../../../../rtl/compute/kv/ai_kv_cache_engine.v \
		../tb/tb_ai_cnn_kv_random_latency.sv \
		-o $(TINYNPU_CNN_OUT)/simv -l $(TINYNPU_CNN_OUT)/compile.log
	$(TINYNPU_CNN_OUT)/simv +SEED=$(SEED) +TINYNPU_CONV_MATCH_ONLY -l $(TINYNPU_CNN_OUT)/run.log
	grep -q '^CNN_TINYNPU_MATCH_PASS ' $(TINYNPU_CNN_OUT)/run.log
