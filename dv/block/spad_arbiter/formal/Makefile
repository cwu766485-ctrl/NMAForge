OUT ?= /tmp/nmaforge_spad_arbiter_decode_formal
VCF ?= vcf
TIMEOUT ?= 120
FORMAL_TCL := $(abspath run_decode_invariants.tcl)
FORMAL_LOG := $(OUT)/vc_formal.log

.PHONY: decode-invariants check

decode-invariants:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(FORMAL_TCL)" -output_log_file vc_formal.log
	$(MAKE) --no-print-directory check OUT="$(OUT)"

check:
	@grep -Fq -- "- # proven       : 8" "$(FORMAL_LOG)" || \
		{ echo "SPAD arbiter invariant proof gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 8" "$(FORMAL_LOG)" || \
		{ echo "SPAD arbiter invariant vacuity gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq -- "- # covered      : 5" "$(FORMAL_LOG)" || \
		{ echo "SPAD arbiter invariant cover gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq "No setup issues found" "$(FORMAL_LOG)" || \
		{ echo "SPAD arbiter formal setup gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(FORMAL_LOG)" || \
		{ echo "SPAD arbiter formal error found; inspect $(FORMAL_LOG)"; exit 1; }
	@echo "SPAD_ARBITER_DECODE_FORMAL_PASS"
