ROOT := $(abspath ../../../../)
VCS ?= vcs
URG ?= urg
SEED ?= 20261016
RUN_TAG ?= a10_spad_protection_$(shell date +%Y%m%d_%H%M%S)
RUN_ROOT ?= $(ROOT)/runs/spad_protection/$(RUN_TAG)
COVERAGE := line+cond+tgl+branch
SIMV := $(RUN_ROOT)/simv
COV_DIR := $(RUN_ROOT)/coverage.vdb
URG_DIR := $(RUN_ROOT)/urg
RUN_LOG := $(RUN_ROOT)/run.log
COMPILE_LOG := $(RUN_ROOT)/compile.log
URG_LOG := $(RUN_ROOT)/urg.log
RTL := $(ROOT)/rtl/memory/ai_spad_protection.v
TB := $(ROOT)/dv/block/spad_protection/tb/tb_ai_spad_protection.sv

.PHONY: verify compile run coverage

verify: coverage

compile:
	mkdir -p "$(RUN_ROOT)"
	cd "$(RUN_ROOT)" && $(VCS) -full64 -sverilog -timescale=1ns/1ps \
		-debug_access+all -cm $(COVERAGE) -cm_dir "$(COV_DIR)" \
		-top tb_ai_spad_protection \
		-o simv "$(RTL)" "$(TB)" -l "$(COMPILE_LOG)"

run: compile
	"$(SIMV)" +SEED=$(SEED) -cm $(COVERAGE) -cm_dir "$(COV_DIR)" -l "$(RUN_LOG)"
	grep -q SPAD_PROTECTION_TEST_PASS "$(RUN_LOG)"

coverage: run
	$(URG) -full64 -dir "$(COV_DIR)" -format text \
		-report "$(URG_DIR)" -log "$(URG_LOG)"
	@! grep -Eq 'UCAPI-DNYL|Design not loaded' "$(URG_LOG)" || { \
		echo "ERROR: URG did not load the compiled design; see $(URG_LOG)"; \
		exit 1; \
	}
	@test -f "$(URG_DIR)/dashboard.txt" || { \
		echo "ERROR: URG text dashboard was not generated in $(URG_DIR)"; \
		exit 1; \
	}
