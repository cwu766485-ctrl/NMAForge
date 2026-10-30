VCS ?= /opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
PYTHON ?= python3.12
SEED ?= 20261030
OUT ?= /tmp/nmaforge_scalar_int8_numeric_$(shell date +%Y%m%d_%H%M%S)
VECTORS := $(OUT)/scalar_int8_vectors.txt
SIMV := $(OUT)/simv
RTL := ../../../../../rtl/compute/int8/ai_int8_datapath.v \
	../../../../../rtl/compute/int8/ai_int8_compute_core.v
TB := ../tb/tb_ai_int8_numeric.sv

.PHONY: numeric-regress
numeric-regress:
	test ! -e "$(OUT)"
	mkdir -p "$(OUT)/csrc"
	$(PYTHON) ../model/generate_scalar_int8_vectors.py --seed $(SEED) --out "$(VECTORS)"
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
		-top tb_ai_int8_numeric -Mdir="$(OUT)/csrc" $(RTL) $(TB) \
		-o "$(SIMV)" -l "$(OUT)/compile.log"
	"$(SIMV)" +SEED=$(SEED) +VECTOR_FILE="$(VECTORS)" -l "$(OUT)/run.log"
	grep -q '^SCALAR_INT8_NUMERIC_PASS cases=13 ' "$(OUT)/run.log"
