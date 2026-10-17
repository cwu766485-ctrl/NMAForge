ROOT := ../../../../..
RUN_TAG ?= $(shell date +%Y%m%d_%H%M%S)
OUT ?= $(ROOT)/runs/fp_core_formal_$(RUN_TAG)
VCF ?= vcf
FORMAL_PROBE_TIMEOUT ?= 150
FORMAL_TCL := $(abspath run_vcf.tcl)

.PHONY: run parity-probe parity-reach parity-exclusion parity-cutoff-bound parity-frontier parity-bounded parity-bounded-new-parity-last-compute check-parity-bounded parity-full-domain parity-full-cutoff parity-full-accounting check-parity-full-accounting parity-full-index-bound parity-full-response-bound parity-full-accepted-count-bound parity-full-response-assume parity-full-cutoff-assume parity-full-lifecycle-assume parity-full-progress-assume parity-full-writeback-assume parity-full-frontier-assume parity-full-ready-frontier-assume parity-full-pair-tag-match parity-full-current-pair-tag parity-full-tag-response-bound parity-full-current-pair-tag-control-abstract parity-full-writeback-control-abstract parity-full-static-slot-tags parity-full-transition-lemmas parity-full-local-transition-lemmas parity-full-pending-last-compute parity-full-new-parity-last-compute parity-full-parity-cutoff-last-element parity-full-last-compute-write-transition parity-full-last-compute-write-state
run:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && $(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(FORMAL_TCL)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 12" "$(OUT)/vc_formal.log" || \
		{ echo "VC Formal assertion-count gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # covered      : 2" "$(OUT)/vc_formal.log" || \
		{ echo "VC Formal cover-count gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Eq 'No setup issues found|Reset violations[[:space:]]*:[[:space:]]+0' "$(OUT)/vc_formal.log" || \
		{ echo "VC Formal reset-setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Eq 'No setup issues found|Clock violations[[:space:]]*:[[:space:]]+0' "$(OUT)/vc_formal.log" || \
		{ echo "VC Formal clock-setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }

# Diagnostic proof uses the same reset/SPAD contract as run_vcf.tcl, plus
# helper invariants to expose the reason the parity exclusion converges or not.
parity-probe:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_probe.tcl)" -output_log_file vc_formal.log

parity-reach:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_reach.tcl)" -output_log_file vc_formal.log

parity-exclusion:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_exclusion.tcl)" -output_log_file vc_formal.log

parity-cutoff-bound:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_cutoff_bound.tcl)" -output_log_file vc_formal.log

parity-frontier:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_frontier.tcl)" -output_log_file vc_formal.log

# Bounded short-vector proof for parity cutoff, error retirement, and the
# two-outstanding parity-response corner. It complements, but does not replace,
# the unconstrained-length parity exclusion in the canonical formal harness.
parity-bounded:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_bounded.tcl)" -output_log_file vc_formal.log
	$(MAKE) --no-print-directory check-parity-bounded OUT="$(OUT)"

parity-bounded-new-parity-last-compute:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_new_parity_blocks_last_compute \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_bounded.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Bounded new-parity final-compute proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Bounded new-parity final-compute vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Bounded new-parity final-compute setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Bounded new-parity final-compute formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

check-parity-bounded:
	@grep -Fq -- "- # proven       : 5" "$(OUT)/vc_formal.log" || \
		{ echo "Bounded parity assertion gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 5" "$(OUT)/vc_formal.log" || \
		{ echo "Bounded parity vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # covered      : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Bounded parity cover gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Bounded parity setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-domain:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_domain.tcl)" -output_log_file vc_formal.log

parity-full-cutoff:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_cutoff.tcl)" -output_log_file vc_formal.log

parity-full-accounting:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_accounting.tcl)" -output_log_file vc_formal.log
	$(MAKE) --no-print-directory check-parity-full-accounting OUT="$(OUT)"

parity-full-index-bound:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_index_bound.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain request-index bound proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain request-index setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain request-index formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-response-bound:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_response_bound.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain response-index bound proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain response-index setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain response-index formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-accepted-count-bound:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_accepted_count_bound.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain accepted-read bound proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain accepted-read setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain accepted-read formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-response-assume:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_response_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain assumed-response-index proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain assumed-response-index vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain assumed-response-index setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain assumed-response-index formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-cutoff-assume:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_cutoff_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-cutoff lemma proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-cutoff lemma vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-cutoff lemma setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-cutoff lemma formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-lifecycle-assume:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity lifecycle proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity lifecycle vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity lifecycle setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity lifecycle formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-progress-assume:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_parity_progress_stays_before_cutoff \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-progress proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-progress vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-progress setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-progress formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-writeback-assume:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_writeback_excludes_pending_parity \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-writeback proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-writeback vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-writeback setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity-writeback formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

# Use transition-local helper assertions to strengthen the parity exclusion
# proof without assuming that parity or ST_WRITE is unreachable.
parity-full-transition-lemmas:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_new_parity_blocks_last_compute,ap_last_compute_does_not_set_parity,ap_writeback_excludes_pending_parity \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 3" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity transition-lemma proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity transition-lemma setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain parity transition-lemma formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-local-transition-lemmas:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_new_parity_blocks_last_compute,ap_last_compute_does_not_set_parity \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain local transition-lemma proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain local transition-lemma vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain local transition-lemma setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain local transition-lemma formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-pending-last-compute:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_pending_parity_blocks_last_compute \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Pending-parity final-compute proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Pending-parity final-compute vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Pending-parity final-compute setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Pending-parity final-compute formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-new-parity-last-compute:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_new_parity_blocks_last_compute \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "New-parity final-compute proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "New-parity final-compute vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "New-parity final-compute setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "New-parity final-compute formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-parity-cutoff-last-element:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_parity_cutoff_not_after_last_element \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Parity-cutoff/final-element proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Parity-cutoff/final-element vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Parity-cutoff/final-element setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Parity-cutoff/final-element formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-last-compute-write-transition:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_last_compute_enters_write_without_parity \
		timeout --kill-after=5s 120s \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain final-compute/write-transition proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain final-compute/write-transition vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain final-compute/write-transition setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain final-compute/write-transition formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-last-compute-write-state:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_last_compute_enters_write_state \
		timeout --kill-after=5s 120s \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain final-compute/write-state proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain final-compute/write-state vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain final-compute/write-state setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain final-compute/write-state formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-frontier-assume:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_compute_within_returned_pair_frontier \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain compute-frontier proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain compute-frontier vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain compute-frontier setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain compute-frontier formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-ready-frontier-assume:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_ready_pair_within_returned_frontier \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain ready-pair frontier proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain ready-pair frontier vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain ready-pair frontier setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain ready-pair frontier formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-pair-tag-match:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_pair0_ready_tags_match,ap_pair1_ready_tags_match \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain pair-slot tag proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain pair-slot tag vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain pair-slot tag setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain pair-slot tag formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-current-pair-tag:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_ready_pair_tag_matches_current_element \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain current-element pair-tag proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain current-element pair-tag vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain current-element pair-tag setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain current-element pair-tag formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-tag-response-bound:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_ready_pair_tag_precedes_response_cursor \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_assume.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain pair-tag response-bound proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain pair-tag response-bound vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain pair-tag response-bound setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain pair-tag response-bound formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-current-pair-tag-control-abstract:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_ready_pair_tag_matches_current_element \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_control_abstract.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract current-pair-tag proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract current-pair-tag vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract current-pair-tag setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract current-pair-tag formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

# Full-16-bit-length parity/writeback control proof with arithmetic stubs.
# This isolated target does not alter the canonical proof or existing targets.
parity-full-writeback-control-abstract:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_writeback_control_abstract.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract parity/writeback proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract parity/writeback vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # covered      : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract parity cover gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract parity/writeback setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract parity/writeback formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

parity-full-static-slot-tags:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && PARITY_FORMAL_PROPERTIES=ap_ready_slot0_tag_matches_element,ap_ready_slot1_tag_matches_element \
		timeout --kill-after=5s "$(FORMAL_PROBE_TIMEOUT)s" \
		$(VCF) -fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(abspath run_parity_full_lifecycle_control_abstract.tcl)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract static slot-tag proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # non_vacuous  : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract static slot-tag vacuity gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract static slot-tag setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Control-abstract static slot-tag formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

check-parity-full-accounting:
	@grep -Fq -- "- # proven       : 1" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain accounting proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain accounting setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Full-domain accounting elaboration/proof error found; inspect $(OUT)/vc_formal.log"; exit 1; }
