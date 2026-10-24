VCS ?= vcs -licwait 1
SEED ?= 20261021
OUT_DIR ?= /tmp/nmaforge_cnn_kv_random_latency_$(SEED)
COV_METRICS := line+cond+fsm+branch

.PHONY: random-latency-test random-latency-compile random-latency-run
.PHONY: random-latency-regress

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

SEEDS ?= 20261021 20261022 20261023
random-latency-regress: random-latency-compile
	@set -e; for seed in $(SEEDS); do \
		$(OUT_DIR)/simv +SEED=$$seed -cm $(COV_METRICS) \
			-cm_dir $(OUT_DIR)/coverage.vdb -cm_name cnn_kv_seed_$$seed \
			-l $(OUT_DIR)/run_seed_$$seed.log; \
		grep -q "^CNN_KV_RANDOM_LATENCY_PASS .*seed=$$seed " $(OUT_DIR)/run_seed_$$seed.log; \
	done
