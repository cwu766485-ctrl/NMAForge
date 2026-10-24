VCS ?= vcs -licwait 1
URG ?= /opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
CLUSTER_TAG ?= multi_engine_$(shell date +%Y%m%d_%H%M%S)
CLUSTER_OUT ?= /tmp/nmaforge_compute_cluster_$(CLUSTER_TAG)
CLUSTER_FORMAL_OUT ?= $(CLUSTER_OUT)/serial_formal
CLUSTER_COV_OUT ?= $(CLUSTER_OUT)/dut_coverage

TOP_SMOKE := ../../top_smoke/sim
DMA_SPAD := ../../dma_spad/sim
FP_SIM := ../../../block/compute/fp/sim
CNN_KV_SIM := ../../../block/compute/cnn_kv/sim
MATRIX_SIM := ../../../block/compute/matrix/sim
SFU_SIM := ../../../block/compute/sfu/sim

DMA_SPAD_SEEDS ?= 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027 20261028 20261029
FP_SEEDS ?= 712345 987654 20261020
AI_RANDOM_CASES ?= 20
AI_SEED ?= 12345
AI_REF_CASES ?= 10000
AI_REF_SEED ?= 20261021
COMPUTE_SEED ?= 20261021
COMPUTE_SEEDS ?= 20261021 20261022 20261023
COMPUTE_COV_SEEDS ?= 20261021 20261022 20261023 20261024 20261025
CLUSTER_EXTRA_COV_DBS := $(CLUSTER_OUT)/cnm/random/coverage.vdb \
	$(CLUSTER_OUT)/cnn_kv/coverage.vdb \
	$(CLUSTER_OUT)/matrix/coverage.vdb \
	$(CLUSTER_OUT)/matrix/core/coverage.vdb \
	$(CLUSTER_OUT)/sfu/coverage.vdb \
	$(CLUSTER_OUT)/fp/dot_core_codecov/coverage.vdb \
	$(CLUSTER_OUT)/fp/addsub_dut_codecov/coverage.vdb \
	$(foreach seed,$(FP_SEEDS),$(CLUSTER_OUT)/fp/seed_$(seed)/coverage.vdb)

.PHONY: cluster_regress

# Multi-Engine NPU Compute Cluster Verification. The command processor
# dispatches one compute engine at a time; the DMA/SPAD subsystem phase adds
# real DMA overlap with FP/CNM traffic at the shared memory fabric.
cluster_regress:
	$(MAKE) -C $(TOP_SMOKE) ai_a7_vcs
	$(MAKE) -C $(TOP_SMOKE) ai_cnm_a22 ai_cnm_a2_gemv_bench ai_cnm_random_regress \
		CNM_RANDOM_SEEDS='$(COMPUTE_SEEDS)' CNM_RANDOM_OUT_DIR=$(CLUSTER_OUT)/cnm/random
	$(MAKE) -C $(CNN_KV_SIM) random-latency-regress SEEDS='$(COMPUTE_SEEDS)' \
		OUT_DIR=$(CLUSTER_OUT)/cnn_kv
	$(MAKE) -C $(MATRIX_SIM) datapath-random-regress SEEDS='$(COMPUTE_SEEDS)' \
		OUT_DIR=$(CLUSTER_OUT)/matrix
	$(MAKE) -C $(MATRIX_SIM) core-random-regress SEEDS='$(COMPUTE_SEEDS)' \
		CORE_OUT_DIR=$(CLUSTER_OUT)/matrix/core
	$(MAKE) -C $(MATRIX_SIM) a3-core-test
	$(MAKE) -C $(SFU_SIM) random-latency-regress SEEDS='$(COMPUTE_SEEDS)' \
		OUT_DIR=$(CLUSTER_OUT)/sfu
	$(MAKE) -C $(DMA_SPAD) subsystem_regress \
		SEEDS='$(DMA_SPAD_SEEDS)' COV_TAG=$(CLUSTER_TAG) \
		URG_REPORT=$(CLUSTER_OUT)/dma_spad/urg VCS='$(VCS)' URG=$(URG)
	$(MAKE) -C $(FP_SIM) dot-core-test \
		DOT_CORE_OUT_DIR=$(CLUSTER_OUT)/fp/dot_core \
		DOT_CORE_PARITY_MAX_OUT_DIR=$(CLUSTER_OUT)/fp/parity_max VCS='$(VCS)'
	$(MAKE) -C $(FP_SIM) dot-core-codecov-regress \
		DOT_CORE_CODECOV_SEEDS='$(COMPUTE_SEEDS)' \
		DOT_CORE_CODECOV_OUT=$(CLUSTER_OUT)/fp/dot_core_codecov \
		VCS='$(VCS)'
	$(MAKE) -C $(FP_SIM) add16-codecov-regress \
		ADD16_CODECOV_SEEDS='$(COMPUTE_SEEDS)' \
		ADD16_CODECOV_OUT=$(CLUSTER_OUT)/fp/addsub_dut_codecov \
		VCS='$(VCS)'
	$(MAKE) -C $(FP_SIM) dot-uvm-regress \
		DOT_UVM_SEEDS='$(FP_SEEDS)' DOT_UVM_OUT_DIR=$(CLUSTER_OUT)/fp \
		VCS='$(VCS)' URG=$(URG)
	python3.11 -m unittest discover -s ../../../block/compute/fp/model \
		-p test_fp_reference.py
	$(MAKE) -C $(TOP_SMOKE) ai_a4_ref \
		AI_REF_CASES=$(AI_REF_CASES) AI_REF_SEED=$(AI_REF_SEED)
	$(MAKE) -C $(TOP_SMOKE) ai_smoke \
		AI_RANDOM_CASES=$(AI_RANDOM_CASES) AI_SEED=$(AI_SEED)
	$(MAKE) -C ../formal run OUT=$(CLUSTER_FORMAL_OUT)
	$(MAKE) -C $(TOP_SMOKE) ai_compute_cluster_cov \
		AI_CLUSTER_COV_RUN=$(CLUSTER_COV_OUT) \
		AI_RANDOM_CASES=$(AI_RANDOM_CASES) \
		AI_CLUSTER_COV_SEEDS='$(COMPUTE_COV_SEEDS)' \
		AI_CLUSTER_EXTRA_COV_DBS='$(CLUSTER_EXTRA_COV_DBS)' \
		VCS='$(VCS)' URG=$(URG)
	@echo "MULTI_ENGINE_COMPUTE_CLUSTER_PASS tag=$(CLUSTER_TAG) artifacts=$(CLUSTER_OUT)"
