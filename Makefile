.DEFAULT_GOAL := help
.PHONY: help benchmark-tinynpu inference-digits inference-transformer compute-performance-report shape-adaptive-regress shape-adaptive-spad-regress

AI_DIGITS_RUN ?= /tmp/nmaforge_digits_$(shell date +%Y%m%d_%H%M%S)
PYTHON ?= $(shell for p in python3.12 python3.11 python3.10 python3.9; do command -v $$p >/dev/null 2>&1 && { echo $$p; exit 0; }; done; command -v python3)
AI_DIGITS_PYTHON ?= $(PYTHON)
TRANSFORMER_SEED ?= 20261029
COMPUTE_PERF_OUT ?= /tmp/nmaforge_compute_performance_$(shell date +%Y%m%d_%H%M%S)

help:
	@printf '%s\n' \
	  'benchmark-tinynpu          Build and run the pinned TinyNPU comparison harness' \
	  'inference-digits            Train, quantize, and run the digits MLP through NMAForge RTL' \
	  'inference-transformer       Run the checked-in 86-descriptor functional workload' \
	  'compute-performance-report Run Matrix size and eight-way ablation benchmarks' \
	  'shape-adaptive-regress      Run the isolated v2 GEMV RTL and four-way ablation' \
	  'shape-adaptive-spad-regress Run the research GEMV wrapper through real SPAD RTL'

benchmark-tinynpu:
	PYTHON="$(PYTHON)" bash benchmark/tinynpu/run_comparison.sh

inference-digits:
	$(MAKE) -C dv/subsystem/top_smoke/sim ai_digits_inference \
	  AI_DIGITS_RUN="$(AI_DIGITS_RUN)" AI_DIGITS_PYTHON="$(AI_DIGITS_PYTHON)"

inference-transformer:
	$(MAKE) -C dv/subsystem/top_smoke/sim ai_transformer AI_SEED="$(TRANSFORMER_SEED)"

compute-performance-report:
	PYTHON="$(PYTHON)" COMPUTE_PERF_OUT="$(COMPUTE_PERF_OUT)" bash benchmark/run_compute_performance.sh

shape-adaptive-regress:
	$(MAKE) -C dv/research/shape_adaptive/sim shape-adaptive-regress

shape-adaptive-spad-regress:
	$(MAKE) -C dv/research/shape_adaptive/sim shape-adaptive-spad-regress
