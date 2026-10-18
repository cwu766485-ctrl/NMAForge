ROOT := ../../../..
OUT ?= /tmp/nmaforge_cp_completion_ownership_formal
VCF ?= vcf
TIMEOUT ?= 180
FORMAL_TCL := $(abspath run_completion_ownership.tcl)
FORMAL_LOG := $(OUT)/vc_formal.log

.PHONY: completion-ownership check clean

completion-ownership:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(FORMAL_TCL)" -output_log_file vc_formal.log
	$(MAKE) --no-print-directory check OUT="$(OUT)"

check:
	@grep -Fq -- "- # proven       : 3" "$(FORMAL_LOG)" || \
		{ echo "CP completion ownership proof gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 3" "$(FORMAL_LOG)" || \
		{ echo "CP completion ownership vacuity gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq -- "- # covered      : 2" "$(FORMAL_LOG)" || \
		{ echo "CP completion ownership cover gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq "cp_completion_ownership_formal_top.cp_completion_done_with_pending_command" "$(FORMAL_LOG)" || \
		{ echo "CP pending-command completion cover missing; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq "cp_completion_ownership_formal_top.ap_decode_abort_pending_requires_live_abort" "$(FORMAL_LOG)" || \
		{ echo "CP decode abort-pending invariant proof missing; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq "No setup issues found" "$(FORMAL_LOG)" || \
		{ echo "CP completion ownership setup gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(FORMAL_LOG)" || \
		{ echo "CP completion ownership formal error found; inspect $(FORMAL_LOG)"; exit 1; }
	@echo "CP_COMPLETION_OWNERSHIP_FORMAL_PASS"

clean:
	rm -rf "$(OUT)"
