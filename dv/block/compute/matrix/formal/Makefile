ROOT := ../../../../..
RUN_TAG ?= $(shell date +%Y%m%d_%H%M%S)
OUT ?= $(ROOT)/runs/matrix_fsm_formal_$(RUN_TAG)
VCF ?= /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
FORMAL_TCL := $(abspath run_fsm_guards.tcl)

.PHONY: fsm-guards gemv-request-stability
fsm-guards:
	mkdir -p "$(OUT)"
	cd "$(OUT)" && timeout --kill-after=5s 360s $(VCF) \
		-fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(FORMAL_TCL)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 5" "$(OUT)/vc_formal.log" || \
		{ echo "Matrix FSM guard proof gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # covered      : 2" "$(OUT)/vc_formal.log" || \
		{ echo "Matrix FSM reachability cover gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(OUT)/vc_formal.log" || \
		{ echo "Matrix FSM formal setup gate failed; inspect $(OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(OUT)/vc_formal.log" || \
		{ echo "Matrix FSM formal error found; inspect $(OUT)/vc_formal.log"; exit 1; }

GEMV_REQUEST_OUT ?= $(ROOT)/runs/matrix_gemv_request_formal_$(RUN_TAG)
GEMV_REQUEST_TCL := $(abspath run_gemv_request_stability.tcl)

gemv-request-stability:
	mkdir -p "$(GEMV_REQUEST_OUT)"
	cd "$(GEMV_REQUEST_OUT)" && timeout --kill-after=5s 360s $(VCF) \
		-fmode FPV -batch -no_restore -lic_wait 1 \
		-f "$(GEMV_REQUEST_TCL)" -output_log_file vc_formal.log
	@grep -Fq -- "- # proven       : 1" "$(GEMV_REQUEST_OUT)/vc_formal.log" || \
		{ echo "GEMV request stability proof gate failed; inspect $(GEMV_REQUEST_OUT)/vc_formal.log"; exit 1; }
	@grep -Fq -- "- # covered      : 1" "$(GEMV_REQUEST_OUT)/vc_formal.log" || \
		{ echo "GEMV request backpressure cover gate failed; inspect $(GEMV_REQUEST_OUT)/vc_formal.log"; exit 1; }
	@grep -Fq "No setup issues found" "$(GEMV_REQUEST_OUT)/vc_formal.log" || \
		{ echo "GEMV request formal setup gate failed; inspect $(GEMV_REQUEST_OUT)/vc_formal.log"; exit 1; }
	@! grep -Eq "Cross-module reference resolution error|Error-\\[|ERROR" "$(GEMV_REQUEST_OUT)/vc_formal.log" || \
		{ echo "GEMV request formal error found; inspect $(GEMV_REQUEST_OUT)/vc_formal.log"; exit 1; }
