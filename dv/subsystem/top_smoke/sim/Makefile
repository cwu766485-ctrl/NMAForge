
SEED = $(shell date +%s)
VCS ?= vcs
URG ?= /opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
VCS_HOME ?= /opt/Synopsys/vcs/V-2023.12-SP1
AI_RANDOM_CASES ?= 4
AI_SEED ?= 12345
AI_SPAD_WORDS_PER_BANK ?= 32768
AI_REF_CASES ?= 1000
AI_REF_SEED ?= 20260722
AI_TRANSFORMER_MODEL_JSON ?=
AI_TRANSFORMER_MANIFEST ?= /tmp/nmaforge_transformer_manifest.json
AI_TRANSFORMER_MAPPING_POLICY ?= gemm
AI_TRANSFORMER_SEED ?= 20261106
AI_TRANSFORMER_STEPS ?= 20000
# The WSL image keeps an old python3 (3.6) alongside newer interpreters.
# Pick the first installed Python that can parse the A3/A4 reference model;
# callers may still override PYTHON for a managed VNC/CI environment.
PYTHON ?= $(shell for p in python3.12 python3.11 python3.10 python3.9 python3.8 python3; do command -v $$p >/dev/null 2>&1 && $$p -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 7) else 1)' >/dev/null 2>&1 && { echo $$p; exit; }; done; echo python3)

all: ai_smoke

ai_transformer_gen:
	$(PYTHON) ../../../../sw/tools/cimforge_mapper.py \
		--svh ../fixtures/ai_transformer_workload.svh \
		--decode-mapping-policy "$(AI_TRANSFORMER_MAPPING_POLICY)" \
		$(if $(AI_TRANSFORMER_MODEL_JSON),--manifest "$(AI_TRANSFORMER_MANIFEST)" --model-json "$(AI_TRANSFORMER_MODEL_JSON)",)

ai_comp: ai_transformer_gen
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+define+AI_SPAD_WORDS_PER_BANK=$(AI_SPAD_WORDS_PER_BANK) \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-top tb_ai_accel_smoke -f ai_accel.f ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv -l ai_comp.log

ai_run:
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) -l ai_accel_smoke.log

ai_smoke: ai_comp ai_run
	grep -q '^MATRIX_PRODUCT_GEMV_DESCRIPTOR_PASS opcode=0x52 shape=4x16x32 dense=1 bias=1 shift=1 relu=1 outputs=64 lines=16 golden=bit-exact$$' ai_accel_smoke.log
	grep -q '^MATRIX_PRODUCT_GEMV_TAIL_DESCRIPTOR_PASS opcode=0x52 shape=1x13x17 valid_outputs=13 line_writes=3 scalar_tail=1 golden=bit-exact$$' ai_accel_smoke.log
	grep -q '^MATRIX_PRODUCT_GEMV_M8_KTAIL_DESCRIPTOR_PASS opcode=0x52 shape=8x16x19 outputs=128 lines=32 golden=bit-exact$$' ai_accel_smoke.log
	grep -q '^MATRIX_FUSED_TILE_FORWARD_CMDQ_PASS opcode=0x53 shape=16x16x16 baseline_A_reads=16 forwarded_A_reads=0 producer=bit-exact consumer=bit-exact legacy_writeback=enabled$$' ai_accel_smoke.log
	grep -q '^MATRIX_FUSED_TILE_FORWARD_CROSS_ENGINE_IMMUTABLE_PASS opcode=0x53 matrix_sfu_overlap=1 sfu_spad_accesses_during_consume=[1-9][0-9]* source_unchanged=1 sfu_output=bit-exact golden=bit-exact functional_cov=100\.00$$' ai_accel_smoke.log
	grep -q '^MATRIX_CNM_PERF_PROFILE_PASS .*cycles_closed=1 golden=bit-exact response_alias_seen=0$$' ai_accel_smoke.log

# Integrated compute DUT-only code-coverage capture. The cm_hier scope selects
# ai_accel_compute_cluster and the command processor's tile-pipeline instance;
# unrelated control, DMA, and scratchpad modules are excluded. All generated
# artifacts are isolated under /tmp.
AI_CLUSTER_COV_RUN ?= /tmp/nmaforge_compute_cluster_dut_cov_$(shell date +%Y%m%d_%H%M%S)
AI_CLUSTER_COV_METRICS := line+cond+fsm+branch
AI_CLUSTER_COV_SEEDS ?= 20261021 20261022 20261023 20261024 20261025
AI_CLUSTER_EXTRA_COV_DBS ?=
.PHONY: ai_compute_cluster_cov
ai_compute_cluster_cov:
	test ! -e "$(AI_CLUSTER_COV_RUN)"
	mkdir -p "$(AI_CLUSTER_COV_RUN)"
	$(VCS) -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-cm $(AI_CLUSTER_COV_METRICS) \
		-cm_hier $(CURDIR)/ai_compute_cluster_dut.cm_hier \
		-cm_dir $(AI_CLUSTER_COV_RUN)/coverage.vdb \
		-Mdir=$(AI_CLUSTER_COV_RUN)/csrc \
		-top tb_ai_accel_smoke -f ai_accel.f \
		../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
		-o $(AI_CLUSTER_COV_RUN)/simv -l $(AI_CLUSTER_COV_RUN)/compile.log
	@set -e; for ai_cov_seed in $(AI_CLUSTER_COV_SEEDS); do \
		echo "=== Compute-cluster DUT coverage seed=$$ai_cov_seed ==="; \
		$(AI_CLUSTER_COV_RUN)/simv +ntb_random_seed=$$ai_cov_seed \
			+AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$$ai_cov_seed \
			+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) \
			-cm $(AI_CLUSTER_COV_METRICS) -cm_dir $(AI_CLUSTER_COV_RUN)/coverage.vdb \
			-cm_name compute_seed_$$ai_cov_seed \
			-l $(AI_CLUSTER_COV_RUN)/run_seed_$$ai_cov_seed.log; \
		grep -q 'TEST PASS' $(AI_CLUSTER_COV_RUN)/run_seed_$$ai_cov_seed.log; \
	done
	VCS_HOME=$(VCS_HOME) $(URG) -full64 -lca \
		-dir $(AI_CLUSTER_COV_RUN)/coverage.vdb $(AI_CLUSTER_EXTRA_COV_DBS) \
		-flex_merge modules \
		-format text -report $(AI_CLUSTER_COV_RUN)/urg \
		-log $(AI_CLUSTER_COV_RUN)/urg.log
	! grep -Eq 'UCAPI-DNYL|Design not loaded' $(AI_CLUSTER_COV_RUN)/urg.log
	test -s $(AI_CLUSTER_COV_RUN)/urg/modinfo.txt
	VCS_HOME=$(VCS_HOME) $(URG) -full64 -lca \
		-dir $(AI_CLUSTER_COV_RUN)/coverage.vdb \
		-format text -report $(AI_CLUSTER_COV_RUN)/top_only_urg \
		-log $(AI_CLUSTER_COV_RUN)/top_only_urg.log
	! grep -Eq 'UCAPI-DNYL|Design not loaded' $(AI_CLUSTER_COV_RUN)/top_only_urg.log
	test -s $(AI_CLUSTER_COV_RUN)/top_only_urg/modinfo.txt
	echo "COMPUTE_CLUSTER_DUT_COVERAGE_PASS report=$(AI_CLUSTER_COV_RUN)/urg"

# Full top-level mixed-dot throughput sweep.  The single-tile baseline avoids
# DMA/compute overlap; three-tile runs use the production ping-pong pipeline to
# overlap actual DMA and FP traffic at the shared SPAD arbiter.  External DDR is
# modeled behaviorally, with seeded AXI RVALID latency and WREADY
# back-pressure in overlap runs.
FP_BENCH_SEED ?= 20261013
ai_fp_dot_dma_benchmark: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +FP_DOT_DMA_BENCH \
		+FP_BENCH_SEED=$(FP_BENCH_SEED) -l ai_fp_dot_dma_benchmark.log

# Round 9 reproducer for the former exploratory Matrix/DMA ping-pong probe.
ai_matrix_dma_overlap_probe: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +R9_MATRIX_DMA_OVERLAP_PROBE \
		-l ai_matrix_dma_overlap_probe.log
	grep -q '^R9_MATRIX_DMA_OVERLAP_PASS tiles=3 shape=4x4x4 ' ai_matrix_dma_overlap_probe.log

# End-to-end INT8 digits MLP through ABI-v7 Matrix/SFU descriptors and the
# production CMDQ/CPLQ/SPAD path. All generated model, simulator, and result
# files are isolated under /tmp.
AI_DIGITS_RUN ?= /tmp/nmaforge_digits_rtl_$(shell date +%Y%m%d_%H%M%S)
AI_DIGITS_PYTHON ?= python3
AI_DIGITS_MODEL ?=
AI_DIGITS_COMPACT_SPAD ?= 0
ifeq ($(AI_DIGITS_COMPACT_SPAD),1)
DIGITS_ADDRESS_PROFILE_ARG = --compact-spad
DIGITS_ADDRESS_PROFILE_DEFINE = +define+AI_DIGITS_COMPACT_SPAD
else
DIGITS_ADDRESS_PROFILE_ARG =
DIGITS_ADDRESS_PROFILE_DEFINE =
endif
.PHONY: ai_digits_inference
ai_digits_inference:
	test ! -e "$(AI_DIGITS_RUN)"
	mkdir -p "$(AI_DIGITS_RUN)"
	@if [ -n "$(AI_DIGITS_MODEL)" ]; then \
		mkdir -p "$(AI_DIGITS_RUN)/model"; \
		cp "$(AI_DIGITS_MODEL)" "$(AI_DIGITS_RUN)/model/digits_mlp_int8.npz"; \
	else \
		$(AI_DIGITS_PYTHON) ../../../../benchmark/digits/train_digits_mlp.py \
			--out-dir "$(AI_DIGITS_RUN)/model"; \
	fi
	$(AI_DIGITS_PYTHON) ../../../../benchmark/digits/generate_digits_workload.py \
		--model "$(AI_DIGITS_RUN)/model/digits_mlp_int8.npz" \
		--out-dir "$(AI_DIGITS_RUN)/workload" $(DIGITS_ADDRESS_PROFILE_ARG)
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+define+AI_SPAD_WORDS_PER_BANK=$(AI_SPAD_WORDS_PER_BANK) \
		$(DIGITS_ADDRESS_PROFILE_DEFINE) \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-Mdir=$(AI_DIGITS_RUN)/csrc -top tb_ai_accel_smoke -f ai_accel.f \
		../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
		-o $(AI_DIGITS_RUN)/simv -l $(AI_DIGITS_RUN)/compile.log
	$(AI_DIGITS_RUN)/simv +ntb_random_seed=20261029 +AI_RANDOM_CASES=0 \
		+AI_SEED=20261029 +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) \
		+AI_DIGITS_INFERENCE \
		+AI_DIGITS_MEMORY=$(AI_DIGITS_RUN)/workload/digits_spad_writes.memh \
		+AI_DIGITS_EXPECTED=$(AI_DIGITS_RUN)/workload/digits_expected.memh \
		+AI_DIGITS_HIDDEN=$(AI_DIGITS_RUN)/workload/digits_hidden_expected.memh \
		+AI_DIGITS_RTL_CSV=$(AI_DIGITS_RUN)/rtl_logits.csv \
		-l $(AI_DIGITS_RUN)/run.log
	$(AI_DIGITS_PYTHON) ../../../../benchmark/digits/digits_quantized_golden.py \
		--model "$(AI_DIGITS_RUN)/model/digits_mlp_int8.npz" \
		--rtl-logits "$(AI_DIGITS_RUN)/rtl_logits.csv" \
		--out "$(AI_DIGITS_RUN)/golden_comparison.json"

# Paired TinyNPU conv1x_mini graph through production top, Matrix/SFU/int8
# engines, ABI-v7 command/completion queues, and an independent per-layer Golden.
AI_TINYNPU_CNN_RUN ?= /tmp/nmaforge_tinynpu_cnn_rtl_$(shell date +%Y%m%d_%H%M%S)
AI_TINYNPU_CNN_PYTHON ?= python3
AI_TINYNPU_CNN_CLASSES ?= 4
AI_TINYNPU_CNN_SPAD_BASE_SHIFT ?= 0
.PHONY: ai_tinynpu_cnn_match
ai_tinynpu_cnn_match:
	test ! -e "$(AI_TINYNPU_CNN_RUN)"
	mkdir -p "$(AI_TINYNPU_CNN_RUN)"
	if [ -n "$(AI_TINYNPU_CNN_INPUT_NPZ)" ]; then \
		$(AI_TINYNPU_CNN_PYTHON) ../../../../benchmark/tinynpu/generate_nma_cnn_workload.py \
			--model "$(AI_TINYNPU_CNN_MODEL)" \
			--tiny-golden "$(AI_TINYNPU_CNN_GOLDEN)" \
			--input-npz "$(AI_TINYNPU_CNN_INPUT_NPZ)" \
			--spad-base-shift "$(AI_TINYNPU_CNN_SPAD_BASE_SHIFT)" \
			--out-dir "$(AI_TINYNPU_CNN_RUN)/workload"; \
	else \
	$(AI_TINYNPU_CNN_PYTHON) ../../../../benchmark/tinynpu/generate_nma_cnn_workload.py \
		--model "$(AI_TINYNPU_CNN_MODEL)" \
		--tiny-golden "$(AI_TINYNPU_CNN_GOLDEN)" \
		--spad-base-shift "$(AI_TINYNPU_CNN_SPAD_BASE_SHIFT)" \
		--out-dir "$(AI_TINYNPU_CNN_RUN)/workload"; \
	fi
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+define+AI_SPAD_WORDS_PER_BANK=$(AI_SPAD_WORDS_PER_BANK) \
		+define+AI_TINYNPU_CNN_SPAD_BASE_SHIFT=$(AI_TINYNPU_CNN_SPAD_BASE_SHIFT) \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-Mdir=$(AI_TINYNPU_CNN_RUN)/csrc -top tb_ai_accel_smoke -f ai_accel.f \
		../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
		-o $(AI_TINYNPU_CNN_RUN)/simv -l $(AI_TINYNPU_CNN_RUN)/compile.log
	$(AI_TINYNPU_CNN_RUN)/simv +ntb_random_seed=20261029 +AI_RANDOM_CASES=0 \
		+AI_SEED=20261029 +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +AI_TINYNPU_CNN_MATCH \
		+AI_TINYNPU_CNN_CLASSES=$(AI_TINYNPU_CNN_CLASSES) \
		+AI_TINYNPU_CNN_MEMORY=$(AI_TINYNPU_CNN_RUN)/workload/nma_cnn_spad.memh \
		+AI_TINYNPU_CNN_EXPECTED=$(AI_TINYNPU_CNN_RUN)/workload/nma_cnn_expected.memh \
		-l $(AI_TINYNPU_CNN_RUN)/run.log
	grep -q '^NMA_CNN_INFERENCE_PASS' $(AI_TINYNPU_CNN_RUN)/run.log

.PHONY: ai_tinynpu_cnn_match_128k
ai_tinynpu_cnn_match_128k:
	$(MAKE) ai_tinynpu_cnn_match \
		AI_SPAD_WORDS_PER_BANK=8192 \
		AI_TINYNPU_CNN_SPAD_BASE_SHIFT=65536

# Trained Digits CNN demo. The same Top flow supports four- and ten-class
# heads by running one four-output INT8 Matrix group per command chain.
AI_TRAINED_CNN_RUN ?= /tmp/nmaforge_trained_cnn_demo_$(shell date +%Y%m%d_%H%M%S)
AI_TRAINED_CNN_PYTHON ?= python3
AI_TRAINED_CNN_CLASSES ?= 4
.PHONY: ai_trained_cnn_demo
ai_trained_cnn_demo:
	test ! -e "$(AI_TRAINED_CNN_RUN)"
	mkdir -p "$(AI_TRAINED_CNN_RUN)/model"
	$(AI_TRAINED_CNN_PYTHON) ../../../../benchmark/tinynpu/train_nma_cnn_demo.py \
		--num-classes $(AI_TRAINED_CNN_CLASSES) \
		--out-dir "$(AI_TRAINED_CNN_RUN)/model"
	$(AI_TRAINED_CNN_PYTHON) ../../../../benchmark/tinynpu/generate_nma_cnn_demo_golden.py \
		--model "$(AI_TRAINED_CNN_RUN)/model/nma_tiny_cnn_demo_weights.npz" \
		--input-npz "$(AI_TRAINED_CNN_RUN)/model/nma_tiny_cnn_demo_input.npz" \
		--golden "$(AI_TRAINED_CNN_RUN)/model/nma_cnn_golden.bin"
	$(MAKE) ai_tinynpu_cnn_match \
		AI_TINYNPU_CNN_PYTHON="$(AI_TRAINED_CNN_PYTHON)" \
		AI_TINYNPU_CNN_CLASSES="$(AI_TRAINED_CNN_CLASSES)" \
		AI_TINYNPU_CNN_RUN="$(AI_TRAINED_CNN_RUN)/rtl" \
		AI_TINYNPU_CNN_MODEL="$(AI_TRAINED_CNN_RUN)/model/nma_tiny_cnn_demo_weights.npz" \
		AI_TINYNPU_CNN_INPUT_NPZ="$(AI_TRAINED_CNN_RUN)/model/nma_tiny_cnn_demo_input.npz" \
		AI_TINYNPU_CNN_GOLDEN="$(AI_TRAINED_CNN_RUN)/model/nma_cnn_golden.bin"

# Run the entire held-out set through the compiled production-top testbench;
# each invocation checks every CNN intermediate against an independent Golden.
.PHONY: ai_trained_cnn_dataset_regress
ai_trained_cnn_dataset_regress:
	$(MAKE) ai_trained_cnn_demo AI_TRAINED_CNN_RUN="$(AI_TRAINED_CNN_RUN)"
	$(AI_TRAINED_CNN_PYTHON) ../../../../benchmark/tinynpu/run_nma_cnn_demo_dataset.py \
		--simv "$(AI_TRAINED_CNN_RUN)/rtl/simv" \
		--model "$(AI_TRAINED_CNN_RUN)/model/nma_tiny_cnn_demo_weights.npz" \
		--testset "$(AI_TRAINED_CNN_RUN)/model/nma_tiny_cnn_demo_testset.npz" \
		--spad-base-shift "$(AI_TINYNPU_CNN_SPAD_BASE_SHIFT)" \
		--candidate-sha "$$(git rev-parse HEAD)" \
		--out-dir "$(AI_TRAINED_CNN_RUN)/dataset_replay"

AI_TENCLASS_CNN_RUN ?= /tmp/nmaforge_trained_cnn_tenclass_$(shell date +%Y%m%d_%H%M%S)
.PHONY: ai_trained_cnn_tenclass_dataset_regress
ai_trained_cnn_tenclass_dataset_regress:
	$(MAKE) ai_trained_cnn_dataset_regress \
		AI_TRAINED_CNN_RUN="$(AI_TENCLASS_CNN_RUN)" \
		AI_TRAINED_CNN_CLASSES=10

# Optional V3 subsystem stress: inject seeded read/write SLVERR at a random
# beat of multi-beat DMA bursts and check completion plus AXI drain-to-idle.
ai_dma_error_stress: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +AI_DMA_ERROR_STRESS \
		-l ai_dma_error_stress.log

# Activity-aware smoke: uses exactly the same top-level regression as
# ai_smoke, but writes a VCD only when explicitly requested.  Convert it on
# the Synopsys Linux environment with `make ai_smoke_saif` before DC power.
ACLK_PERIOD_NS ?= 10.0
ACLK_PERIOD_TAG := $(subst .,_,$(ACLK_PERIOD_NS))ns
VCD_FILE ?= ai_accel_smoke_$(ACLK_PERIOD_TAG).vcd
SAIF_FILE ?= ai_accel_smoke_$(ACLK_PERIOD_TAG).saif
SAIF_DC_FILE ?= $(basename $(SAIF_FILE))_dc.saif
SAIF_INSTANCE ?= tb_ai_accel_smoke/dut

ai_smoke_vcd: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +VCD_FILE=$(VCD_FILE) -l ai_accel_smoke_vcd.log

ai_smoke_saif: ai_smoke_vcd
	vcd2saif -input $(VCD_FILE) -output $(SAIF_FILE) -instance $(SAIF_INSTANCE)
	$(PYTHON) ../../../../syn/normalize_saif_root.py --input $(SAIF_FILE) --output $(SAIF_DC_FILE) --testbench tb_ai_accel_smoke --dut dut --top ai_accel_top

ai_transformer: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) -l ai_transformer.log

# Deterministically train/export a tiny INT8 Transformer model, map its real
# weights into ABI-v7 descriptors, and run only the Transformer path on the
# production Top with the selected scratchpad capacity.
AI_TRANSFORMER_TRAINED_MODEL ?= /tmp/nmaforge_transformer_micro_20261106.json
.PHONY: ai_transformer_trained
ai_transformer_trained:
	$(PYTHON) ../../../../sw/tools/train_transformer_micro.py \
		--out "$(AI_TRANSFORMER_TRAINED_MODEL)" --seed $(AI_TRANSFORMER_SEED) \
		--steps $(AI_TRANSFORMER_STEPS)
	$(MAKE) ai_comp AI_TRANSFORMER_MODEL_JSON="$(AI_TRANSFORMER_TRAINED_MODEL)" \
		AI_TRANSFORMER_MANIFEST="$(AI_TRANSFORMER_MANIFEST)"
	./simv +ntb_random_seed=$(AI_TRANSFORMER_SEED) +AI_RANDOM_CASES=0 \
		+AI_SEED=$(AI_TRANSFORMER_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) \
		+AI_TRANSFORMER_ONLY -l ai_transformer_trained.log

# Short Linux/VCS gate: all directed AXI/DMA/A4 tests with random compute
# cases disabled. Use this after an RTL edit before the seeded regression.
ai_quick: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) -l ai_quick.log

# Integer reference model is intentionally a separate gate: it validates the
# documented A3/A4 fixed-point contract without claiming RTL coverage.
ai_a4_ref:
	$(PYTHON) ../../../block/compute/matrix/ref/ai_a3_reference.py --cases $(AI_REF_CASES) --seed $(AI_REF_SEED)

ai_precheck: ai_a4_ref ai_quick

# Focused Linux/VCS gates for the unified DMA and scratchpad line/RR arbiter.
ai_dma_comp:
	vcs -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-top tb_ai_axi128_dma ../../../../rtl/dma/ai_axi128_dma.v \
		../../../block/dma/tb/tb_ai_axi128_dma.sv -o simv_dma -l ai_dma_comp.log

ai_dma_run: ai_dma_comp
	./simv_dma -l ai_dma_run.log

ai_spad_arb_comp:
	vcs -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-top tb_ai_spad_arbiter_rr ../../../../rtl/memory/ai_spad_arbiter.v \
		../../../block/spad_arbiter/tb/tb_ai_spad_arbiter_rr.sv -o simv_spad_arb \
		-l ai_spad_arb_comp.log

ai_spad_arb_run: ai_spad_arb_comp
	./simv_spad_arb -l ai_spad_arb_run.log
	@grep -q '3-client sustained SPAD round-robin PASS grants=10/10/10 max_wait=2' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter 3-client fairness marker missing"; exit 1; }
	@grep -q 'Seeded request-mode SPAD RR PASS' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter seeded request-mode fairness marker missing"; exit 1; }
	@grep -q 'CNM/DMA SPAD contention PASS cnm_grants=6 dma_line_grants=6' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter CNM/DMA contention marker missing"; exit 1; }
	@grep -q 'Scratchpad response parity alignment PASS' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter response/parity marker missing"; exit 1; }
	./simv_spad_arb +SPAD_RR_MODE_CYCLES=10000 -l ai_spad_arb_10k_run.log
	@grep -q 'Seeded request-mode SPAD RR PASS cycles=10000' ai_spad_arb_10k_run.log || \
		{ echo "SPAD arbiter 10000-cycle seeded request-mode marker missing"; exit 1; }

# Standalone arbiter code-coverage capture.  Keep all generated artifacts in
# an isolated run directory so this gate does not overwrite the functional
# smoke executable or its logs.
SPAD_ARB_COV_RUN ?= /tmp/nmaforge_spad_arbiter_cov_$(shell date +%Y%m%d_%H%M%S)
SPAD_ARB_COV_METRICS := line+cond+tgl+branch+assert
COMPUTE_SPAD_MUX_RR_RUN ?= /tmp/nmaforge_compute_spad_mux_rr_$(shell date +%Y%m%d_%H%M%S)
COMPUTE_SPAD_MUX_RR_METRICS := line+cond+tgl+branch+assert
COMPUTE_SPAD_PATH_RUN ?= /tmp/nmaforge_compute_spad_path_$(shell date +%Y%m%d_%H%M%S)
COMPUTE_SPAD_PATH_METRICS := line+cond+tgl+branch+assert

.PHONY: ai_spad_arb_cov
ai_spad_arb_cov:
	test ! -e "$(SPAD_ARB_COV_RUN)"
	mkdir -p "$(SPAD_ARB_COV_RUN)"
	cd "$(SPAD_ARB_COV_RUN)" && $(VCS) -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-cm $(SPAD_ARB_COV_METRICS) -cm_dir coverage.vdb \
		-top tb_ai_spad_arbiter_rr $(CURDIR)/../../../../rtl/memory/ai_spad_arbiter.v \
		$(CURDIR)/../../../block/spad_arbiter/tb/tb_ai_spad_arbiter_rr.sv \
		-o simv -l compile.log
	cd "$(SPAD_ARB_COV_RUN)" && ./simv +SPAD_RR_MODE_CYCLES=10000 \
		-cm $(SPAD_ARB_COV_METRICS) -cm_dir coverage.vdb -l run.log
	grep -q '3-client sustained SPAD round-robin PASS grants=10/10/10 max_wait=2' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'Seeded request-mode SPAD RR PASS cycles=10000' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'CNM/DMA SPAD contention PASS cnm_grants=6 dma_line_grants=6' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'Scratchpad response parity alignment PASS' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'SPAD arbiter cursor fallback request forms PASS cases=12' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'SPAD arbiter descriptor/completion priority and response PASS' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'SPAD arbiter protection-error response alignment PASS' "$(SPAD_ARB_COV_RUN)/run.log"
	$(URG) -full64 -dir "$(SPAD_ARB_COV_RUN)/coverage.vdb" -format text \
		-report "$(SPAD_ARB_COV_RUN)/urg" -log "$(SPAD_ARB_COV_RUN)/urg.log"
	! grep -Eq 'UCAPI-DNYL|Design not loaded' "$(SPAD_ARB_COV_RUN)/urg.log"
	test -s "$(SPAD_ARB_COV_RUN)/urg/modinfo.txt"
	grep -Fq 'Failure               0' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'Incomplete            0' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'Without Attempts      0' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'Uncovered         0' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'Matches           2' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'ap_idle_decode_uses_default_client' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'ap_banked_response_metadata_is_valid' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	echo "SPAD_ARBITER_COVERAGE_PASS report=$(SPAD_ARB_COV_RUN)/urg"

.PHONY: ai_compute_spad_mux_fairness
ai_compute_spad_mux_fairness:
	test ! -e "$(COMPUTE_SPAD_MUX_RR_RUN)"
	mkdir -p "$(COMPUTE_SPAD_MUX_RR_RUN)"
	cd "$(COMPUTE_SPAD_MUX_RR_RUN)" && $(VCS) -full64 -sverilog -timescale=1ns/1ps +define+VCS \
		-cm $(COMPUTE_SPAD_MUX_RR_METRICS) -cm_dir coverage.vdb \
		-top tb_ai_compute_spad_mux_fairness $(CURDIR)/../../../../rtl/top/fabric/compute/ai_compute_spad_mux.v \
		$(CURDIR)/../../../block/compute/spad_mux/tb/tb_ai_compute_spad_mux_fairness.sv \
		-o simv -l compile.log
	cd "$(COMPUTE_SPAD_MUX_RR_RUN)" && ./simv \
		-cm $(COMPUTE_SPAD_MUX_RR_METRICS) -cm_dir coverage.vdb -l run.log
	grep -q '^COMPUTE_SPAD_MUX_FAIRNESS_PASS cycles=4096' "$(COMPUTE_SPAD_MUX_RR_RUN)/run.log"
	$(URG) -full64 -dir "$(COMPUTE_SPAD_MUX_RR_RUN)/coverage.vdb" -format text \
		-report "$(COMPUTE_SPAD_MUX_RR_RUN)/urg" -log "$(COMPUTE_SPAD_MUX_RR_RUN)/urg.log"
	! grep -Eq 'UCAPI-DNYL|Design not loaded' "$(COMPUTE_SPAD_MUX_RR_RUN)/urg.log"
	grep -Fq 'Failure               0' "$(COMPUTE_SPAD_MUX_RR_RUN)/urg/asserts.txt"
	grep -Fq 'Incomplete            0' "$(COMPUTE_SPAD_MUX_RR_RUN)/urg/asserts.txt"
	grep -Fq 'Without Attempts      0' "$(COMPUTE_SPAD_MUX_RR_RUN)/urg/asserts.txt"
	grep -Fq 'ap_ready_onehot' "$(COMPUTE_SPAD_MUX_RR_RUN)/urg/asserts.txt"
	grep -Fq 'ap_stalled_payload_stable' "$(COMPUTE_SPAD_MUX_RR_RUN)/urg/asserts.txt"
	grep -Fq 'ap_response_owner_onehot' "$(COMPUTE_SPAD_MUX_RR_RUN)/urg/asserts.txt"
	echo "COMPUTE_SPAD_MUX_FAIRNESS_COVERAGE_PASS report=$(COMPUTE_SPAD_MUX_RR_RUN)/urg"

.PHONY: ai_compute_spad_path_fairness
ai_compute_spad_path_fairness:
	test ! -e "$(COMPUTE_SPAD_PATH_RUN)"
	mkdir -p "$(COMPUTE_SPAD_PATH_RUN)"
	cd "$(COMPUTE_SPAD_PATH_RUN)" && $(VCS) -full64 -sverilog -timescale=1ns/1ps +define+VCS \
		-cm $(COMPUTE_SPAD_PATH_METRICS) -cm_dir coverage.vdb \
		-top tb_ai_compute_spad_path_fairness \
		$(CURDIR)/../../../../rtl/top/fabric/compute/ai_compute_spad_mux.v \
		$(CURDIR)/../../../../rtl/memory/ai_spad_arbiter.v \
		$(CURDIR)/../../../block/compute/spad_mux/tb/tb_ai_compute_spad_path_fairness.sv \
		-o simv -l compile.log
	cd "$(COMPUTE_SPAD_PATH_RUN)" && ./simv \
		-cm $(COMPUTE_SPAD_PATH_METRICS) -cm_dir coverage.vdb -l run.log
	grep -q '^COMPUTE_SPAD_PATH_FAIRNESS_PASS cycles=4096' "$(COMPUTE_SPAD_PATH_RUN)/run.log"
	$(URG) -full64 -dir "$(COMPUTE_SPAD_PATH_RUN)/coverage.vdb" -format text \
		-report "$(COMPUTE_SPAD_PATH_RUN)/urg" -log "$(COMPUTE_SPAD_PATH_RUN)/urg.log"
	! grep -Eq 'UCAPI-DNYL|Design not loaded' "$(COMPUTE_SPAD_PATH_RUN)/urg.log"
	grep -Fq 'Failure               0' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'Incomplete            0' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'Without Attempts      0' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'ap_scheduler_grant_at_most_one' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'ap_engine_response_onehot' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'ap_core_payload_stable_under_preemption' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'cp_desc_beats_completion' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'cp_core_admitted' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'cp_banked_admitted' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	grep -Fq 'cp_dma_admitted' "$(COMPUTE_SPAD_PATH_RUN)/urg/asserts.txt"
	echo "COMPUTE_SPAD_PATH_FAIRNESS_COVERAGE_PASS report=$(COMPUTE_SPAD_PATH_RUN)/urg"

ai_upgrade_vcs: ai_dma_run ai_spad_arb_run ai_quick

# Focused VCS tests.  Each target creates a separate executable, KDB and log,
# so a directed failure can be inspected in Verdi without rebuilding ai_smoke.
VCS_FOCUSED = vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ns +define+VCS

ai_a6_dma_comp:
	$(VCS_FOCUSED) -top tb_ai_axi128_dma ../../../../rtl/dma/ai_axi128_dma.v \
		../../../../rtl/dma/ai_dma_burst_planner.v \
		../../../../rtl/dma/ai_dma_read_slot_tracker.v \
		../../../../rtl/dma/ai_dma_write_response_tracker.v \
		../../../../rtl/dma/ai_dma_spad_transfer_adapter.v \
		../../../block/dma/tb/tb_ai_axi128_dma.sv -o simv_a6_dma -l ai_a6_dma_comp.log

ai_a6_dma_run: ai_a6_dma_comp
	./simv_a6_dma -l ai_a6_dma_run.log

ai_a6_datapaths_comp:
	$(VCS_FOCUSED) -top tb_ai_a6_datapaths \
		../../../../rtl/compute/cnn/ai_conv3x3_linebuffer_core.v \
		../../../../rtl/compute/kv/ai_kv_cache_engine.v \
		../../../block/compute/cnn_kv/tb/tb_ai_a6_datapaths.sv -o simv_a6_datapaths -l ai_a6_datapaths_comp.log

ai_a6_datapaths_run: ai_a6_datapaths_comp
	./simv_a6_datapaths -l ai_a6_datapaths_run.log

ai_a7_vcs: ai_a6_dma_run ai_a6_datapaths_run ai_spad_arb_run

# A2.2 unit gate for the four independent bank-local controllers.
# This focused executable has occasionally been removed while its VCS .daidir
# cache remains (for example after a WSL/Windows file sync).  In that state VCS
# says the design is unchanged but does not recreate simv_cnm_a22.  Clear only
# this target's generated cache before compile; it does not touch ai_smoke.
ai_cnm_a22_comp:
	rm -rf simv_cnm_a22 simv_cnm_a22.daidir
	$(VCS_FOCUSED) -top tb_ai_banked_cnm_a22 \
		../../../../rtl/compute/cnm/ai_bank_pe.v \
		../../../../rtl/compute/cnm/ai_bank_local_controller.v \
		../../../../rtl/compute/cnm/ai_banked_cnm_core.v \
		../../../block/compute/cnm/tb/tb_ai_banked_cnm_a22.sv -o simv_cnm_a22 -l ai_cnm_a22_comp.log

ai_cnm_a22_run: ai_cnm_a22_comp
	./simv_cnm_a22 -l ai_cnm_a22_run.log

ai_cnm_a22: ai_cnm_a22_run

# Comparable VCS microbenchmarks: each A2/A3 case performs 64*L INT8 MACs.
ai_cnm_a2_gemv_bench_comp:
	rm -rf simv_cnm_a2_gemv_bench simv_cnm_a2_gemv_bench.daidir
	$(VCS_FOCUSED) -top tb_ai_cnm_a2_gemv_bench \
		../../../../rtl/compute/cnm/ai_bank_pe.v \
		../../../../rtl/compute/cnm/ai_bank_local_controller.v \
		../../../../rtl/compute/cnm/ai_banked_cnm_core.v \
		../../../block/compute/cnm/tb/tb_ai_cnm_a2_gemv_bench.sv -o simv_cnm_a2_gemv_bench -l ai_cnm_a2_gemv_bench_comp.log

ai_cnm_a2_gemv_bench_run: ai_cnm_a2_gemv_bench_comp
	./simv_cnm_a2_gemv_bench -l ai_cnm_a2_gemv_bench_run.log

ai_cnm_a2_gemv_bench: ai_cnm_a2_gemv_bench_run

# Seeded CNM oracle regression. Random signed bytes are generated from the
# address and seed, then independently reduced by the testbench reference.
CNM_RANDOM_SEEDS ?= 20261021 20261022 20261023
ifndef CNM_RANDOM_OUT_DIR
CNM_RANDOM_OUT_DIR := /tmp/nmaforge_cnm_random_$(shell date +%Y%m%d_%H%M%S)
endif
ai_cnm_random_compile:
	mkdir -p $(CNM_RANDOM_OUT_DIR)
	$(VCS_FOCUSED) -Mdir=$(CNM_RANDOM_OUT_DIR)/csrc -top tb_ai_banked_cnm_random \
		-cm line+cond+fsm+branch \
		-cm_hier $(CURDIR)/../../../block/compute/cnm/tb/cnm_random.cm_hier \
		-cm_dir $(CNM_RANDOM_OUT_DIR)/coverage.vdb \
		../../../../rtl/compute/cnm/ai_bank_pe.v \
		../../../../rtl/compute/cnm/ai_bank_local_controller.v \
		../../../../rtl/compute/cnm/ai_banked_cnm_core.v \
		../../../block/compute/cnm/tb/tb_ai_banked_cnm_random.sv \
		-o $(CNM_RANDOM_OUT_DIR)/simv -l $(CNM_RANDOM_OUT_DIR)/compile.log

.PHONY: ai_cnm_random_compile ai_cnm_random_regress
ai_cnm_random_regress: ai_cnm_random_compile
	@set -e; for seed in $(CNM_RANDOM_SEEDS); do \
		$(CNM_RANDOM_OUT_DIR)/simv +SEED=$$seed -cm line+cond+fsm+branch \
			-cm_dir $(CNM_RANDOM_OUT_DIR)/coverage.vdb -cm_name cnm_seed_$$seed \
			-l $(CNM_RANDOM_OUT_DIR)/run_seed_$$seed.log; \
		grep -q "^CNM_RANDOM_PASS golden_cases=17 faults=8 phase_abort=6 phase_reset=6 late_faults=1 reset_fault_combo=1 reset_recovery=1 wait_a=1 prefetch_backpressure=1 stable_stall=1 responses_drained=1 fast_response=1 seed=$$seed$$" $(CNM_RANDOM_OUT_DIR)/run_seed_$$seed.log; \
	done

ai_tensor_a3_gemm_bench_comp:
	rm -rf simv_tensor_a3_gemm_bench simv_tensor_a3_gemm_bench.daidir
	$(VCS_FOCUSED) -top tb_ai_tensor_a3_gemm_bench \
		../../../../rtl/compute/matrix/ai_tensor_matrix_datapath.v \
		../../../../rtl/compute/matrix/ai_tensor_matrix_array.sv \
		../../../../rtl/compute/matrix/ai_tensor_matrix_core.v \
		../../../block/compute/matrix/tb/tb_ai_tensor_a3_gemm_bench.sv -o simv_tensor_a3_gemm_bench -l ai_tensor_a3_gemm_bench_comp.log

ai_tensor_a3_gemm_bench_run: ai_tensor_a3_gemm_bench_comp
	./simv_tensor_a3_gemm_bench -l ai_tensor_a3_gemm_bench_run.log

ai_tensor_a3_gemm_bench: ai_tensor_a3_gemm_bench_run

ai_cnm_compare: ai_cnm_a2_gemv_bench ai_tensor_a3_gemm_bench

# CNM signoff gate: microarchitecture throughput, SPAD arbitration under
# CNM/DMA contention, then the full AXI/DMA/compute smoke regression.
ai_cnm_signoff: ai_cnm_compare ai_spad_arb_run ai_smoke

ai_async_fifo_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo.sv -o simv_async_fifo -l ai_async_fifo_comp.log

ai_async_fifo_run: ai_async_fifo_comp
	./simv_async_fifo -l ai_async_fifo_run.log

ai_async_fifo: ai_async_fifo_run

ai_async_fifo_random_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo_random \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo_random.sv -o simv_async_fifo_random -l ai_async_fifo_random_comp.log

ai_async_fifo_random_run: ai_async_fifo_random_comp
	./simv_async_fifo_random +SEED=$(AI_SEED) -l ai_async_fifo_random_run.log

ai_async_fifo_random: ai_async_fifo_random_run

ai_async_fifo_reset_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo_reset \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo_reset.sv -o simv_async_fifo_reset -l ai_async_fifo_reset_comp.log

ai_async_fifo_reset_run: ai_async_fifo_reset_comp
	./simv_async_fifo_reset -l ai_async_fifo_reset_run.log

ai_async_fifo_reset: ai_async_fifo_reset_run

ai_ctrl_compute_cdc_comp:
	$(VCS_FOCUSED) -top tb_ai_ctrl_compute_cdc \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../../rtl/control/cdc/ai_ctrl_compute_cdc.v \
		../../../block/cdc/tb/tb_ai_ctrl_compute_cdc.sv -o simv_ctrl_compute_cdc -l ai_ctrl_compute_cdc_comp.log

ai_ctrl_compute_cdc_run: ai_ctrl_compute_cdc_comp
	./simv_ctrl_compute_cdc -l ai_ctrl_compute_cdc_run.log

ai_ctrl_compute_cdc: ai_ctrl_compute_cdc_run

clean:
	rm -rf csrc simv* *.log ucli.key *.vpd vc_hdrs.h DVE* novas* *.daidir *.vdb *.key

# Reproducible two-layer >=100K-MAC INT8 pointwise CNN through production Top CMDQ.
AI_REPRESENTATIVE_RUN ?= /tmp/nmaforge_representative_cnn_$(shell date +%Y%m%d_%H%M%S)
AI_REPRESENTATIVE_PYTHON ?= $(PYTHON)
AI_REPRESENTATIVE_SEED ?= 20261108
AI_REPRESENTATIVE_SPAD_WORDS_PER_BANK ?= 8192
AI_REPRESENTATIVE_FUSION_MODE ?= legacy
AI_REPRESENTATIVE_DESC_COUNT ?= 4
.PHONY: ai_representative_cnn
ai_representative_cnn:
	test ! -e "$(AI_REPRESENTATIVE_RUN)"
	mkdir -p "$(AI_REPRESENTATIVE_RUN)"
	$(AI_REPRESENTATIVE_PYTHON) ../../../../benchmark/representative/generate_pointwise_cnn_workload.py \
		--seed "$(AI_REPRESENTATIVE_SEED)" \
		--fusion-mode "$(AI_REPRESENTATIVE_FUSION_MODE)" \
		--out-dir "$(AI_REPRESENTATIVE_RUN)/workload"
	$(AI_REPRESENTATIVE_PYTHON) ../../../../benchmark/representative/verify_pointwise_cnn_workload.py \
		--workload-dir "$(AI_REPRESENTATIVE_RUN)/workload"
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+define+AI_REPRESENTATIVE_LONG_TASK \
		+define+AI_SPAD_WORDS_PER_BANK=$(AI_REPRESENTATIVE_SPAD_WORDS_PER_BANK) \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-Mdir=$(AI_REPRESENTATIVE_RUN)/csrc -top tb_ai_accel_smoke -f ai_accel.f \
		../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
		-o $(AI_REPRESENTATIVE_RUN)/simv -l $(AI_REPRESENTATIVE_RUN)/compile.log
	$(AI_REPRESENTATIVE_RUN)/simv +ntb_random_seed=$(AI_REPRESENTATIVE_SEED) \
		+AI_RANDOM_CASES=0 +AI_SEED=$(AI_REPRESENTATIVE_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +AI_REPRESENTATIVE_MODEL \
		+AI_REPRESENTATIVE_MEMORY=$(AI_REPRESENTATIVE_RUN)/workload/model_memory.memh \
		+AI_REPRESENTATIVE_GOLDEN=$(AI_REPRESENTATIVE_RUN)/workload/model_golden.memh \
		+AI_REPRESENTATIVE_DESC_BASE=102400 +AI_REPRESENTATIVE_CPL_BASE=102912 \
		+AI_REPRESENTATIVE_DESC_COUNT=$(AI_REPRESENTATIVE_DESC_COUNT) +AI_REPRESENTATIVE_USEFUL_MACS=262144 \
		-l $(AI_REPRESENTATIVE_RUN)/run.log
	grep -q '^REPRESENTATIVE_MODEL_PASS ' "$(AI_REPRESENTATIVE_RUN)/run.log"

# Trained synthetic H=16/two-head QKV projection subgraph through Top CMDQ.
# This is deliberately a QKV-only Gate G2 workload, not full Transformer DV.
AI_H16_QKV_RUN ?= /tmp/nmaforge_h16_qkv_$(shell date +%Y%m%d_%H%M%S)
AI_H16_QKV_PYTHON ?= python3.12
AI_H16_QKV_SEED ?= 20261113
.PHONY: ai_h16_qkv_top
ai_h16_qkv_top:
	test ! -e "$(AI_H16_QKV_RUN)"
	mkdir -p "$(AI_H16_QKV_RUN)"
	$(AI_H16_QKV_PYTHON) ../../../../sw/tools/train_transformer_h16_qkv.py \
		--seed "$(AI_H16_QKV_SEED)" --out "$(AI_H16_QKV_RUN)/model.json"
	$(AI_H16_QKV_PYTHON) ../../../../sw/tools/cimforge_mapper.py \
		--model-json "$(AI_H16_QKV_RUN)/model.json" \
		--h16-qkv-top-dir "$(AI_H16_QKV_RUN)/workload"
	$(AI_H16_QKV_PYTHON) ../../../../sw/tools/verify_transformer_h16_qkv.py \
		--model "$(AI_H16_QKV_RUN)/model.json" \
		--workload-dir "$(AI_H16_QKV_RUN)/workload"
	$(VCS) -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+define+AI_REPRESENTATIVE_LONG_TASK \
		+define+AI_SPAD_WORDS_PER_BANK=8192 \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-Mdir=$(AI_H16_QKV_RUN)/csrc -top tb_ai_accel_smoke -f ai_accel.f \
		../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
		-o $(AI_H16_QKV_RUN)/simv -l $(AI_H16_QKV_RUN)/compile.log
	$(AI_H16_QKV_RUN)/simv +ntb_random_seed=$(AI_H16_QKV_SEED) \
		+AI_RANDOM_CASES=0 +AI_SEED=$(AI_H16_QKV_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +AI_REPRESENTATIVE_MODEL \
		+AI_REPRESENTATIVE_MEMORY=$(AI_H16_QKV_RUN)/workload/model_memory.memh \
		+AI_REPRESENTATIVE_GOLDEN=$(AI_H16_QKV_RUN)/workload/model_golden.memh \
		+AI_REPRESENTATIVE_DESC_BASE=20480 +AI_REPRESENTATIVE_CPL_BASE=20736 \
		+AI_REPRESENTATIVE_DESC_COUNT=3 +AI_REPRESENTATIVE_USEFUL_MACS=6144 \
		-l $(AI_H16_QKV_RUN)/run.log
	grep -q '^REPRESENTATIVE_MODEL_PASS desc=3 golden_words=384 useful_macs=6144 ' \
		"$(AI_H16_QKV_RUN)/run.log"

AI_H16_ATTENTION_RUN ?= /tmp/nmaforge_h16_attention_$(shell date +%Y%m%d_%H%M%S)
AI_H16_ATTENTION_PYTHON ?= python3.12
AI_H16_ATTENTION_SEED ?= 20261113
.PHONY: ai_h16_attention_top
ai_h16_attention_top:
	test ! -e "$(AI_H16_ATTENTION_RUN)"
	mkdir -p "$(AI_H16_ATTENTION_RUN)"
	$(AI_H16_ATTENTION_PYTHON) ../../../../sw/tools/train_transformer_h16_qkv.py \
		--seed "$(AI_H16_ATTENTION_SEED)" --out "$(AI_H16_ATTENTION_RUN)/model.json"
	$(AI_H16_ATTENTION_PYTHON) ../../../../sw/tools/cimforge_mapper.py \
		--model-json "$(AI_H16_ATTENTION_RUN)/model.json" \
		--h16-attention-top-dir "$(AI_H16_ATTENTION_RUN)/workload"
	$(AI_H16_ATTENTION_PYTHON) ../../../../sw/tools/verify_transformer_h16_attention.py \
		--model "$(AI_H16_ATTENTION_RUN)/model.json" \
		--workload-dir "$(AI_H16_ATTENTION_RUN)/workload"
	$(VCS) -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+define+AI_REPRESENTATIVE_LONG_TASK \
		+define+AI_SPAD_WORDS_PER_BANK=8192 \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-Mdir=$(AI_H16_ATTENTION_RUN)/csrc -top tb_ai_accel_smoke -f ai_accel.f \
		../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
		-o $(AI_H16_ATTENTION_RUN)/simv -l $(AI_H16_ATTENTION_RUN)/compile.log
	$(AI_H16_ATTENTION_RUN)/simv +ntb_random_seed=$(AI_H16_ATTENTION_SEED) \
		+AI_RANDOM_CASES=0 +AI_SEED=$(AI_H16_ATTENTION_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +AI_REPRESENTATIVE_MODEL \
		+AI_REPRESENTATIVE_MEMORY=$(AI_H16_ATTENTION_RUN)/workload/model_memory.memh \
		+AI_REPRESENTATIVE_GOLDEN=$(AI_H16_ATTENTION_RUN)/workload/model_golden.memh \
		+AI_REPRESENTATIVE_DESC_BASE=$$($(AI_H16_ATTENTION_PYTHON) -c 'import json;print(json.load(open("$(AI_H16_ATTENTION_RUN)/workload/manifest.json"))["descriptor_base"])') \
		+AI_REPRESENTATIVE_CPL_BASE=$$($(AI_H16_ATTENTION_PYTHON) -c 'import json;print(json.load(open("$(AI_H16_ATTENTION_RUN)/workload/manifest.json"))["completion_base"])') \
		+AI_REPRESENTATIVE_DESC_COUNT=$$($(AI_H16_ATTENTION_PYTHON) -c 'import json;print(json.load(open("$(AI_H16_ATTENTION_RUN)/workload/manifest.json"))["descriptor_count"])') \
		+AI_REPRESENTATIVE_USEFUL_MACS=$$($(AI_H16_ATTENTION_PYTHON) -c 'import json;print(json.load(open("$(AI_H16_ATTENTION_RUN)/workload/manifest.json"))["useful_macs"])') \
		-l $(AI_H16_ATTENTION_RUN)/run.log
	grep -q '^REPRESENTATIVE_MODEL_PASS ' "$(AI_H16_ATTENTION_RUN)/run.log"
