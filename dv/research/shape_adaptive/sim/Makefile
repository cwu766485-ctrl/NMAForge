REPO_ROOT := $(abspath ../../../..)
RTL := $(REPO_ROOT)/rtl/research/ai_shape_adaptive_gemv.sv
TB := $(REPO_ROOT)/dv/research/shape_adaptive/tb_shape_adaptive_gemv.sv
SPAD_RTL := $(REPO_ROOT)/rtl/research/ai_shape_adaptive_gemv_spad.sv \
	$(REPO_ROOT)/rtl/memory/ai_spad_arbiter.v \
	$(REPO_ROOT)/rtl/memory/ai_scratchpad.v
SPAD_TB := $(REPO_ROOT)/dv/research/shape_adaptive/tb_shape_adaptive_gemv_spad.sv
SUMMARIZER := $(REPO_ROOT)/dv/research/shape_adaptive/sim/collect_ablation.py
SPAD_SUMMARIZER := $(REPO_ROOT)/dv/research/shape_adaptive/sim/collect_spad_benchmark.py
SPAD_CSV := $(REPO_ROOT)/benchmark/shape_adaptive_spad_ablation.csv
SPAD_JSON := $(REPO_ROOT)/benchmark/shape_adaptive_spad_summary.json
RUN_DIR ?= /tmp/nmaforge_shape_adaptive_$(shell date +%Y%m%d_%H%M%S)
SEEDS ?= 20261025 20261026 20261027
VCS ?= vcs
PYTHON ?= python3
SOURCE_SHA ?= $(shell git -C "$(REPO_ROOT)" rev-parse HEAD)

.PHONY: shape-adaptive-regress shape-adaptive-spad-regress

shape-adaptive-regress:
	mkdir -p "$(RUN_DIR)"
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -top tb_shape_adaptive_gemv \
	  -Mdir="$(RUN_DIR)/csrc" -o "$(RUN_DIR)/simv" "$(RTL)" "$(TB)" \
	  -l "$(RUN_DIR)/compile.log" > "$(RUN_DIR)/compile.stdout" 2>&1
	@set -eu; for seed in $(SEEDS); do \
	  "$(RUN_DIR)/simv" +SEED=$$seed -l "$(RUN_DIR)/seed_$$seed.log" \
	    > "$(RUN_DIR)/seed_$$seed.stdout" 2>&1; \
	  grep -q "^SHAPE_ADAPTIVE_PASS seed=$$seed cases=12$$" "$(RUN_DIR)/seed_$$seed.log"; \
	done
	@vcs_version="$$(sed -n 's/.*Version \(V-[^ ]*\).*/\1/p' "$(RUN_DIR)/compile.log" | head -1)"; \
	$(PYTHON) "$(SUMMARIZER)" --run-dir "$(RUN_DIR)" --seeds $(SEEDS) \
	  --source-sha "$(SOURCE_SHA)" --vcs-version "$$vcs_version" \
	  --csv "$(REPO_ROOT)/benchmark/shape_adaptive_ablation.csv" \
	  --json "$(REPO_ROOT)/benchmark/shape_adaptive_summary.json"

shape-adaptive-spad-regress:
	mkdir -p "$(RUN_DIR)"
	$(VCS) -full64 -sverilog +define+VCS -timescale=1ns/1ps \
	  -top tb_shape_adaptive_gemv_spad -Mdir="$(RUN_DIR)/csrc" \
	  -o "$(RUN_DIR)/simv" $(RTL) $(SPAD_RTL) $(SPAD_TB) \
	  -l "$(RUN_DIR)/compile.log" > "$(RUN_DIR)/compile.stdout" 2>&1
	@set -eu; for seed in $(SEEDS); do \
	  "$(RUN_DIR)/simv" +SEED=$$seed -l "$(RUN_DIR)/seed_$$seed.log" \
	    > "$(RUN_DIR)/seed_$$seed.stdout" 2>&1; \
	  grep -q "^SHAPE_ADAPTIVE_SPAD_PASS seed=$$seed shapes=4 aborts=3 reset=1$$" "$(RUN_DIR)/seed_$$seed.log"; \
	done; \
	vcs_version="$$(sed -n 's/.*Version \(V-[^ ]*\).*/\1/p' "$(RUN_DIR)/compile.log" | head -1)"; \
	$(PYTHON) "$(SPAD_SUMMARIZER)" --run-dir "$(RUN_DIR)" --seeds $(SEEDS) \
	  --source-sha "$(SOURCE_SHA)" --vcs-version "$$vcs_version" \
	  --run-id "SHAPE-SPAD-$(SOURCE_SHA)-$(shell date +%Y%m%d)" \
	  --csv "$(SPAD_CSV)" --json "$(SPAD_JSON)"
