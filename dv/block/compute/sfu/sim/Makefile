PYTHON ?= python3.12
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
		../../../../../rtl/compute/sfu/ai_tensor_sfu_stream.v \
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

# Round 34: legacy-only vs streaming fast-path differential equivalence.
# Two ai_tensor_sfu_core instances (FAST_PATH_ENABLE_P=0/1) run identical
# random commands against independent ordered SPAD models with randomized
# ready back-pressure and 1..4 cycle multi-outstanding read latency
# (EQUIV_STALL=0 selects fixed two-cycle latency, as on Product Top).
EQUIV_SEEDS ?= 20261125 20261126 20261127
EQUIV_OUT ?= /tmp/nmaforge_sfu_stream_equiv
EQUIV_STALL ?= 1
.PHONY: stream-equiv-compile stream-equiv-regress
stream-equiv-compile:
	mkdir -p $(EQUIV_OUT)
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -Mdir=$(EQUIV_OUT)/csrc \
		-top tb_sfu_stream_equiv \
		../../../../../rtl/compute/common/ai_unsigned_divider.v \
		../../../../../rtl/compute/common/ai_integer_sqrt.v \
		../../../../../rtl/compute/sfu/ai_tensor_sfu_math.v \
		../../../../../rtl/compute/sfu/ai_tensor_sfu_stream.v \
		../../../../../rtl/compute/sfu/ai_tensor_sfu_core.v \
		../tb/tb_sfu_stream_equiv.sv -o $(EQUIV_OUT)/simv -l $(EQUIV_OUT)/compile.log
stream-equiv-regress: stream-equiv-compile
	@set -e; for seed in $(EQUIV_SEEDS); do \
		$(PYTHON) ../model/generate_stream_equiv_vectors.py --seed $$seed \
			--output $(EQUIV_OUT)/vectors_$$seed.txt; \
		$(EQUIV_OUT)/simv +VECTORS=$(EQUIV_OUT)/vectors_$$seed.txt \
			$(if $(filter 0,$(EQUIV_STALL)),+NO_STALL,) -l $(EQUIV_OUT)/run_$$seed.log; \
		grep -q '^SFU_STREAM_EQUIV_PASS ' $(EQUIV_OUT)/run_$$seed.log; \
	done

# Round 35: SFU descriptor flag[7] modes (programmable LUT activation on GELU,
# round-to-nearest REQUANT) against the independent Python Golden with random
# back-pressure / multi-outstanding latency; legacy-only core must reject.
ACT_OUT ?= /tmp/nmaforge_sfu_act_modes
ACT_SEEDS ?= 20261125 20261126 20261127
.PHONY: act-modes-regress
act-modes-regress:
	mkdir -p $(ACT_OUT)
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -Mdir=$(ACT_OUT)/csrc -top tb_sfu_act_modes \
		../../../../../rtl/compute/common/ai_unsigned_divider.v \
		../../../../../rtl/compute/common/ai_integer_sqrt.v \
		../../../../../rtl/compute/sfu/ai_tensor_sfu_math.v \
		../../../../../rtl/compute/sfu/ai_tensor_sfu_stream.v \
		../../../../../rtl/compute/sfu/ai_tensor_sfu_core.v \
		../tb/tb_sfu_stream_equiv.sv ../tb/tb_sfu_act_modes.sv \
		-o $(ACT_OUT)/simv -l $(ACT_OUT)/compile.log
	@set -e; for seed in $(ACT_SEEDS); do \
		$(PYTHON) ../model/generate_act_mode_vectors.py --seed $$seed --output $(ACT_OUT)/v_$$seed.txt; \
		$(ACT_OUT)/simv +VECTORS=$(ACT_OUT)/v_$$seed.txt -l $(ACT_OUT)/run_$$seed.log; \
		grep -q '^SFU_ACT_MODES_PASS ' $(ACT_OUT)/run_$$seed.log; \
	done
