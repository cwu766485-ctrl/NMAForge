PYTHON ?= python3.12
VCS ?= vcs
SEED ?= 20261013
RANDOM_CASES ?= 10000
OUT_DIR ?= /tmp/nmaforge_bf16_mul_fp32
VECTOR_FILE := $(OUT_DIR)/bf16_mul_fp32_vectors.hex
SIMV := $(OUT_DIR)/simv_bf16_mul_fp32
REPO_ROOT := ../../../../../

.PHONY: test vectors compile run fp16-mul-test fp16-mul-vectors fp16-mul-compile fp16-mul-run add-test add-vectors add-compile add-run accum-test accum-vectors accum-compile accum-run add16-test add16-vectors add16-compile add16-run dot-core-test dot-core-compile dot-core-run dot-core-random-test dot-core-random-vectors dot-uvm-test dot-uvm-vectors dot-uvm-compile dot-uvm-run dot-uvm-coverage
.PHONY: dot-uvm-regress

test: run

vectors:
	mkdir -p $(OUT_DIR)
	$(PYTHON) ../model/generate_mul_vectors.py --seed $(SEED) \
		--random-cases $(RANDOM_CASES) --output $(VECTOR_FILE)

compile: vectors
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-top tb_ai_bf16_mul_fp32 $(REPO_ROOT)rtl/compute/fp/ai_bf16_mul_fp32.v \
		../tb/tb_ai_bf16_mul_fp32.sv -o $(SIMV) -l $(OUT_DIR)/compile.log

run: compile
	$(SIMV) +VECTORS=$(VECTOR_FILE) -l $(OUT_DIR)/run.log

# Standalone FP16 multiply. Finite FP16 products are exact in FP32; special
# values are checked against the independent integer/Fraction reference.
FP16_MUL_OUT_DIR ?= /tmp/nmaforge_fp16_mul_fp32
FP16_MUL_VECTOR_FILE := $(FP16_MUL_OUT_DIR)/fp16_mul_fp32_vectors.hex
FP16_MUL_SIMV := $(FP16_MUL_OUT_DIR)/simv_fp16_mul_fp32

fp16-mul-test: fp16-mul-run

fp16-mul-vectors:
	mkdir -p $(FP16_MUL_OUT_DIR)
	$(PYTHON) ../model/generate_fp16_mul_vectors.py --seed $(SEED) \
		--random-cases $(RANDOM_CASES) --output $(FP16_MUL_VECTOR_FILE)

fp16-mul-compile: fp16-mul-vectors
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-top tb_ai_fp16_mul_fp32 $(REPO_ROOT)rtl/compute/fp/ai_fp16_mul_fp32.v \
		../tb/tb_ai_fp16_mul_fp32.sv -o $(FP16_MUL_SIMV) \
		-l $(FP16_MUL_OUT_DIR)/compile.log

fp16-mul-run: fp16-mul-compile
	$(FP16_MUL_SIMV) +VECTORS=$(FP16_MUL_VECTOR_FILE) \
		-l $(FP16_MUL_OUT_DIR)/run.log

# Independent FP32 add block target; default targets above remain BF16 multiply.
ADD_OUT_DIR ?= /tmp/nmaforge_fp32_add
ADD_VECTOR_FILE := $(ADD_OUT_DIR)/fp32_add_vectors.hex
ADD_SIMV := $(ADD_OUT_DIR)/simv_fp32_add

add-test: add-run

add-vectors:
	mkdir -p $(ADD_OUT_DIR)
	$(PYTHON) ../model/generate_fp32_add_vectors.py --seed $(SEED) \
		--random-cases $(RANDOM_CASES) --output $(ADD_VECTOR_FILE)

add-compile: add-vectors
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-top tb_ai_fp32_add $(REPO_ROOT)rtl/compute/fp/ai_fp32_add.v \
		../tb/tb_ai_fp32_add.sv -o $(ADD_SIMV) -l $(ADD_OUT_DIR)/compile.log

add-run: add-compile
	$(ADD_SIMV) +VECTORS=$(ADD_VECTOR_FILE) -l $(ADD_OUT_DIR)/run.log

# Sequential non-fused FP32 accumulator wrapper block.
ACCUM_OUT_DIR ?= /tmp/nmaforge_fp32_accumulator
ACCUM_VECTOR_FILE := $(ACCUM_OUT_DIR)/fp32_accumulator_vectors.hex
ACCUM_SIMV := $(ACCUM_OUT_DIR)/simv_fp32_accumulator

accum-test: accum-run

accum-vectors:
	mkdir -p $(ACCUM_OUT_DIR)
	$(PYTHON) ../model/generate_fp32_accumulator_vectors.py --seed $(SEED) \
		--random-cases $(RANDOM_CASES) --output $(ACCUM_VECTOR_FILE)

accum-compile: accum-vectors
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-assert svaext \
		-top tb_ai_fp32_accumulator $(REPO_ROOT)rtl/compute/fp/ai_fp32_add.v \
		$(REPO_ROOT)rtl/compute/fp/ai_fp32_accumulator.v \
		../assertions/ai_fp32_accumulator_sva.sv \
		../tb/tb_ai_fp32_accumulator.sv -o $(ACCUM_SIMV) -l $(ACCUM_OUT_DIR)/compile.log

accum-run: accum-compile
	$(ACCUM_SIMV) +VECTORS=$(ACCUM_VECTOR_FILE) -l $(ACCUM_OUT_DIR)/run.log

# Independent BF16/FP16 add/sub arithmetic block.
ADD16_OUT_DIR ?= /tmp/nmaforge_fp16_bf16_addsub
ADD16_VECTOR_FILE := $(ADD16_OUT_DIR)/fp16_bf16_addsub_vectors.hex
ADD16_SIMV := $(ADD16_OUT_DIR)/simv_fp16_bf16_addsub

add16-test: add16-run

add16-vectors:
	mkdir -p $(ADD16_OUT_DIR)
	$(PYTHON) ../model/generate_add16_vectors.py --seed $(SEED) \
		--random-cases $(RANDOM_CASES) --output $(ADD16_VECTOR_FILE)

add16-compile: add16-vectors
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-top tb_ai_fp16_bf16_addsub $(REPO_ROOT)rtl/compute/fp/ai_fp16_bf16_addsub.v \
		../tb/tb_ai_fp16_bf16_addsub.sv -o $(ADD16_SIMV) -l $(ADD16_OUT_DIR)/compile.log

add16-run: add16-compile
	$(ADD16_SIMV) +VECTORS=$(ADD16_VECTOR_FILE) -l $(ADD16_OUT_DIR)/run.log

# Standalone single-channel BF16 dot engine and SPAD transaction model.
DOT_CORE_OUT_DIR ?= /tmp/nmaforge_bf16_dot_fp32_core
DOT_CORE_SIMV := $(DOT_CORE_OUT_DIR)/simv_bf16_dot_fp32_core
DOT_RANDOM_VECTOR_FILE := $(DOT_CORE_OUT_DIR)/bf16_dot_random_vectors.txt
DOT_RANDOM_COUNT ?= 64
DOT_RANDOM_SEED ?= $(SEED)
URG ?= $(shell if command -v urg >/dev/null 2>&1; then command -v urg; elif [ -n "$$VCS_HOME" ] && [ -x "$$VCS_HOME/bin/urg" ]; then printf '%s\n' "$$VCS_HOME/bin/urg"; else printf '%s\n' urg; fi)
DOT_UVM_OUT_DIR ?= /tmp/nmaforge_bf16_dot_uvm
DOT_UVM_SEED_DIR := $(DOT_UVM_OUT_DIR)/seed_$(DOT_RANDOM_SEED)
DOT_UVM_VECTOR_FILE := $(DOT_UVM_SEED_DIR)/mixed_precision_dot_vectors.txt
DOT_UVM_SIMV := $(DOT_UVM_SEED_DIR)/simv_bf16_dot_uvm
DOT_UVM_COV_DB := $(DOT_UVM_SEED_DIR)/coverage.vdb
DOT_UVM_COV_REPORT := $(DOT_UVM_SEED_DIR)/urg_report

dot-core-test: dot-core-run

dot-core-compile:
	mkdir -p $(DOT_CORE_OUT_DIR)
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-assert svaext \
		-top tb_ai_bf16_dot_fp32_core $(REPO_ROOT)rtl/compute/fp/ai_bf16_mul_fp32.v \
		$(REPO_ROOT)rtl/compute/fp/ai_fp16_mul_fp32.v \
		$(REPO_ROOT)rtl/compute/fp/ai_fp32_add.v \
		$(REPO_ROOT)rtl/compute/fp/ai_fp32_accumulator.v \
		$(REPO_ROOT)rtl/compute/fp/ai_mixed_precision_dot_fp32_core.v \
		$(REPO_ROOT)rtl/compute/fp/ai_bf16_dot_fp32_core.v \
		../tb/tb_ai_bf16_dot_fp32_core.sv -o $(DOT_CORE_SIMV) \
		-l $(DOT_CORE_OUT_DIR)/compile.log

dot-core-run: dot-core-compile
	$(DOT_CORE_SIMV) -l $(DOT_CORE_OUT_DIR)/run.log

# Deterministic mixed-format dot throughput baseline (fixed two-cycle SPAD reads).
DOT_BENCH_OUT_DIR ?= /tmp/nmaforge_mixed_dot_throughput
DOT_BENCH_SIMV := $(DOT_BENCH_OUT_DIR)/simv_mixed_dot_throughput
DOT_BENCH_SEED ?= 20261013
DOT_BENCH_BP_PCT ?= 0

.PHONY: dot-throughput-bench dot-throughput-compile dot-throughput-run
dot-throughput-bench: dot-throughput-run

dot-throughput-compile:
	mkdir -p $(DOT_BENCH_OUT_DIR)
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-top tb_ai_mixed_dot_throughput $(REPO_ROOT)rtl/compute/fp/ai_bf16_mul_fp32.v \
		$(REPO_ROOT)rtl/compute/fp/ai_fp16_mul_fp32.v \
		$(REPO_ROOT)rtl/compute/fp/ai_fp32_add.v \
		$(REPO_ROOT)rtl/compute/fp/ai_fp32_accumulator.v \
		$(REPO_ROOT)rtl/compute/fp/ai_mixed_precision_dot_fp32_core.v \
		../tb/tb_ai_mixed_dot_throughput.sv -o $(DOT_BENCH_SIMV) \
		-l $(DOT_BENCH_OUT_DIR)/compile.log

dot-throughput-run: dot-throughput-compile
	$(DOT_BENCH_SIMV) +SEED=$(DOT_BENCH_SEED) +BP_PCT=$(DOT_BENCH_BP_PCT) \
		-l $(DOT_BENCH_OUT_DIR)/run.log

dot-core-random-vectors:
	mkdir -p $(DOT_CORE_OUT_DIR)
	$(PYTHON) ../model/generate_bf16_dot_vectors.py --seed $(DOT_RANDOM_SEED) \
		--count $(DOT_RANDOM_COUNT) --output $(DOT_RANDOM_VECTOR_FILE)

dot-core-random-test: dot-core-random-vectors dot-core-compile
	$(DOT_CORE_SIMV) +RANDOM_VECTORS=$(DOT_RANDOM_VECTOR_FILE) \
		+SEED=$(DOT_RANDOM_SEED) -l $(DOT_CORE_OUT_DIR)/random_run.log

dot-uvm-test: dot-uvm-coverage

dot-uvm-vectors:
	mkdir -p $(DOT_UVM_SEED_DIR)
	$(PYTHON) ../model/generate_mixed_dot_vectors.py --seed $(DOT_RANDOM_SEED) \
		--count $(DOT_RANDOM_COUNT) --output $(DOT_UVM_VECTOR_FILE)

dot-uvm-compile:
	mkdir -p $(DOT_UVM_SEED_DIR)/csrc
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all \
		-timescale=1ns/1ps -assert svaext -cm line+cond+branch+fsm+assert \
		-cm_dir $(DOT_UVM_COV_DB) \
		-Mdir=$(DOT_UVM_SEED_DIR)/csrc -top tb_ai_bf16_dot_uvm \
		-f ../uvm/ai_bf16_dot_uvm.f -o $(DOT_UVM_SIMV) \
		-l $(DOT_UVM_SEED_DIR)/compile.log

dot-uvm-run: dot-uvm-vectors dot-uvm-compile
	$(DOT_UVM_SIMV) +UVM_TESTNAME=mixed_precision_dot_uvm_test \
		+RANDOM_VECTORS=$(DOT_UVM_VECTOR_FILE) \
		+ntb_random_seed=$(DOT_RANDOM_SEED) -cm line+cond+branch+fsm+assert \
		-cm_dir $(DOT_UVM_COV_DB) -l $(DOT_UVM_SEED_DIR)/run.log

dot-uvm-coverage: dot-uvm-run
	$(URG) -full64 -dir $(DOT_UVM_COV_DB) -format text \
		-report $(DOT_UVM_COV_REPORT) -log $(DOT_UVM_SEED_DIR)/urg.log

DOT_UVM_SEEDS ?= 712345 987654
DOT_UVM_MERGED_REPORT := $(DOT_UVM_OUT_DIR)/urg_report_merged
DOT_UVM_COV_DBS := $(foreach seed,$(DOT_UVM_SEEDS),$(DOT_UVM_OUT_DIR)/seed_$(seed)/coverage.vdb)

dot-uvm-regress:
	@set -e; for seed in $(DOT_UVM_SEEDS); do \
		echo "=== Mixed BF16/FP16 dot UVM seed=$$seed ==="; \
		$(MAKE) dot-uvm-run DOT_RANDOM_SEED=$$seed; \
	done
	$(URG) -full64 -dir $(DOT_UVM_COV_DBS) \
		-format text -report $(DOT_UVM_MERGED_REPORT) \
		-log $(DOT_UVM_OUT_DIR)/urg_merged.log
