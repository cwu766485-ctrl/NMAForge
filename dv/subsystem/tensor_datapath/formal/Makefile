ROOT := ../../../..
VCF ?= /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
TIMEOUT ?= 300
OUT ?= /tmp/nmaforge_compute_cluster_serial_formal
FORMAL_TCL := $(abspath run_compute_cluster_serial.tcl)
DISPATCHER_TCL := $(abspath run_parallel_dispatcher.tcl)
FORMAL_LOG := $(OUT)/vc_formal.log

.PHONY: run check dispatcher-pairs dispatcher-pairs-check

run:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(FORMAL_TCL)" -output_log_file vc_formal.log
	$(MAKE) --no-print-directory check OUT="$(OUT)"

check:
	@grep -Fq -- "- # proven       : 3" "$(FORMAL_LOG)" || \
		{ echo "Compute cluster serialization proof gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq -- "- # covered      : 7" "$(FORMAL_LOG)" || \
		{ echo "Compute cluster engine reachability cover gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@grep -Fq "No setup issues found" "$(FORMAL_LOG)" || \
		{ echo "Compute cluster formal setup gate failed; inspect $(FORMAL_LOG)"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(FORMAL_LOG)" || \
		{ echo "Compute cluster formal error found; inspect $(FORMAL_LOG)"; exit 1; }
	@echo "COMPUTE_CLUSTER_SERIAL_FORMAL_PASS"

dispatcher-pairs:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(DISPATCHER_TCL)" -output_log_file vc_formal.log
	$(MAKE) --no-print-directory dispatcher-pairs-check OUT="$(OUT)"

dispatcher-pairs-check:
	@grep -Fq -- "- # proven       : 5" "$(OUT)/vc_formal.log" || \
		{ echo "Parallel dispatcher proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	# Four assertions have antecedents and are checked for non-vacuity. The
	# fifth is the unconditional engine_done-to-engine_busy implication.
	@grep -Fq -- "- # non_vacuous  : 4" "$(OUT)/vc_formal.log" || \
		{ echo "Parallel dispatcher vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # covered      : 23" "$(OUT)/vc_formal.log" || \
		{ echo "Parallel engine-pair cover gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Parallel dispatcher setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Parallel dispatcher formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }
	@echo "PARALLEL_DISPATCHER_PAIRS_FORMAL_PASS"
