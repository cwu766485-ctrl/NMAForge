# Gate 1 reproduction

Run in isolated candidate root with VCS V-2023.12-SP1_Full64:

```bash
GATE1_OUT=/tmp/g1/directed bash tools/benchmark/output_dma_gate1/run.sh
make -C dv/block/compute/matrix/sim product-opcode-fault-regress SEEDS='20261116 20261112 20261113' CORE_OUT_DIR=/tmp/g1/matrix
make -C dv/subsystem/top_smoke/sim ai_comp
(cd dv/subsystem/top_smoke/sim && ./simv +OUTPUT_DMA_GATE1 +AI_RANDOM_CASES=20 +AI_SEED=20261116)
make -C dv/subsystem/top_smoke/sim ai_matrix_dma_overlap_probe
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
mkdir -p /tmp/g1/uvm
make -C dv/block/dma/sim uvm_compile SIMV=/tmp/g1/uvm/simv COV_DIR=/tmp/g1/uvm/coverage.vdb
/tmp/g1/uvm/simv +UVM_TESTNAME=dma_aw_stall_stability_test +ntb_random_seed=20261116
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -dir /tmp/g1/directed/coverage.vdb -report /tmp/g1/report
```

Other selected UVM tests are enumerated in the report. Never accept exit0 alone:
require TEST PASS/no TEST FAIL; directed OUTPUT_DMA_GATE1_PASS and no Error/Fatal;
UVM_ERROR/FATAL both0. Top parity injection is behavioralVCS only, guarded for
optional memory fabric hierarchy. It is not a public hardware injection feature.
Evidence includes pre-fix failing seed and final source hashes. No DUT RTL changed.

The original expanded suite failed at case11 (late parity with pending B). Its
pre-fix log is preserved. Current minimal RTL repair must pass all12cases with
this same unchanged done-after-B check. See report for remaining cross coverage.
