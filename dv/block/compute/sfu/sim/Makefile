PYTHON ?= python3.11
VCS ?= vcs -licwait 1
SEED ?= 20261021
OUT_DIR ?= /tmp/nmaforge_sfu_random_latency_$(SEED)
VECTOR_FILE := $(OUT_DIR)/sfu_vectors.txt
COV_METRICS := line+cond+fsm+branch

.PHONY: random-latency-test vectors compile run random-latency-regress

random-latency-test: run

vectors:
	mkdir -p $(OUT_DIR)
	$(PYTHON) ../model/generate_sfu_vectors.py --seed $(SEED) --output $(VECTOR_FILE)

compile: vectors
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-cm $(COV_METRICS) -cm_hier $(CURDIR)/sfu_random.cm_hier \
		-cm_dir $(OUT_DIR)/coverage.vdb \
		-Mdir=$(OUT_DIR)/csrc \
		-top tb_ai_tensor_sfu_random \
		../../../../../rtl/compute/common/ai_unsigned_divider.v \
		../../../../../rtl/compute/common/ai_integer_sqrt.v \
		../../../../../rtl/compute/sfu/ai_tensor_sfu_math.v \
		../../../../../rtl/compute/sfu/ai_tensor_sfu_core.v \
		../tb/tb_ai_tensor_sfu_random.sv \
		-o $(OUT_DIR)/simv -l $(OUT_DIR)/compile.log

run: compile
	$(OUT_DIR)/simv +SEED=$(SEED) +VECTORS=$(VECTOR_FILE) \
		-cm $(COV_METRICS) -cm_dir $(OUT_DIR)/coverage.vdb \
		-cm_name sfu_seed_$(SEED) -l $(OUT_DIR)/run.log
	grep -q '^SFU_RANDOM_LATENCY_PASS cases=64 error_cases=9 late_faults=1 abort_watchdog=1 reset_fault_combo=1 reset_recovery=1 fsm_reset_states=39 fsm_abort_states=39 rms_gamma_bypass=1 tile_a_pack=1 ' $(OUT_DIR)/run.log
	grep -q '^SFU_PARAMETER_LATCH_PASS op=GELU length=16 mutated=all_command_inputs golden_words=16$$' $(OUT_DIR)/run.log

SEEDS ?= 20261021 20261022 20261023
random-latency-regress: compile
	@set -e; for seed in $(SEEDS); do \
		mkdir -p $(OUT_DIR)/seed_$$seed; \
		$(PYTHON) ../model/generate_sfu_vectors.py --seed $$seed \
			--output $(OUT_DIR)/seed_$$seed/sfu_vectors.txt; \
		$(OUT_DIR)/simv +SEED=$$seed +VECTORS=$(OUT_DIR)/seed_$$seed/sfu_vectors.txt \
			-cm $(COV_METRICS) -cm_dir $(OUT_DIR)/coverage.vdb -cm_name sfu_seed_$$seed \
			-l $(OUT_DIR)/seed_$$seed/run.log; \
		grep -q "^SFU_RANDOM_LATENCY_PASS cases=64 error_cases=9 late_faults=1 abort_watchdog=1 reset_fault_combo=1 reset_recovery=1 fsm_reset_states=39 fsm_abort_states=39 rms_gamma_bypass=1 tile_a_pack=1 seed=$$seed " \
			$(OUT_DIR)/seed_$$seed/run.log; \
		grep -q '^SFU_PARAMETER_LATCH_PASS op=GELU length=16 mutated=all_command_inputs golden_words=16$$' \
			$(OUT_DIR)/seed_$$seed/run.log; \
	done
