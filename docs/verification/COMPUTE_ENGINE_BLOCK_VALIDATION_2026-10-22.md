# Multi-Engine Compute Validation Record — 2026-10-22

## Result

The final selected `cluster_regress` completed with exit status 0 and printed
`MULTI_ENGINE_COMPUTE_CLUSTER_PASS` using tag
`multi_engine_20261022_fullrtl_final`. It ran on the current worktree; this is
not a frozen-SHA clean replay. This turn changed coverage scopes, simulation
targets, and documentation, with no product RTL behavior changes.

The regression validated all five compute groups and merged DUT-only code
coverage from direct benches and the real top path. `rtl/compute` contains 23
module definitions; all 23 appear in the merged URG report. Twenty have
executable code bins. The three wiring-only wrappers—`ai_bf16_dot_fp32_core`,
`ai_bf16_addsub`, and `ai_fp16_addsub`—have no applicable line/condition/FSM/
branch bins. `ai_accel_compute_cluster` is included as an additional cluster
module definition.

| Group | Seeded functional result |
|---|---|
| CNM | Signed INT8 oracle: 8 vector lengths × 3 seeds. A2.2 and GEMV lengths 16/64/256 pass. DMA–SPAD–CNM UVM: 10 seeds, including protection/parity errors, abort/drain, and recovery; each seed has UVM warning/error/fatal `0/0/0`. |
| CNN/KV | Three seeds, each with 24 signed convolution cases and 24 KV round trips; randomized 0–7-cycle response delay and ready stalls. |
| Matrix | Three seeds, each with 10,072 datapath cases, five full-core layout/numerical cases, and ten error/recovery cases; A3 core benchmark passes. |
| SFU | Three seeds × 64 independent-oracle vectors, covering all eight opcodes and lengths 1/2/3/4/7/8/15/16; causal query token zero is covered at lengths 1 and 7. |
| FP | Three UVM seeds × 212/212 bit-exact transactions, with selected functional groups at 100%; three BF16 compatibility-wrapper seeds × 71 transactions; three add/sub seeds × 20,032 reference vectors; maximum-length parity and FP reference 19/19 pass. |

The aggregate also passed top smoke with 20 seeded INT8 cases, 10,000 A4
reference cases, and the compute-cluster serial-dispatch formal. VC Formal
proved 3/3 assertions and reached 7/7 engine-dispatch covers; setup reported no
issues.

## DUT-only code coverage

URG merged 29 coverage test instances: five top seeds and three seeds each for
CNM, CNN/KV, Matrix datapath, Matrix core, SFU, BF16 compatibility wrapper,
FP16/BF16 add/sub, and mixed-format FP UVM. Matching module definitions were
merged with `-flex_merge modules`.

| Coverage view | Line | Condition | FSM | Branch |
|---|---:|---:|---:|---:|
| Merged compute RTL definitions plus cluster shell | 89.21% | 84.75% | 45.33% | 82.06% |
| Integrated top compute hierarchy, five seeds only | 74.99% | 65.43% | 30.93% | 61.36% |

The detailed per-module table and group dispositions are in the
[compute-engine status page](COMPUTE_ENGINE_STATUS.md). The five-seed top
scope selects `ai_accel_compute_cluster` and the command processor's
`ai_tile_pipeline` instance. Each focused `cm_hier` scope selects DUT
instances, excluding testbench bookkeeping from code bins.

URG reports the expected `UCAPI-SNF` missing-FSM shape for the combinational
Matrix datapath and FP add/sub arithmetic core. `-lca` also emits its standard
feature-enabled warning for module flex merge. Neither is a simulation failure;
uncovered bins remain visible.

## Reproduction

```sh
env -u VCS_ARCH_OVERRIDE make -C dv/subsystem/tensor_datapath/sim cluster_regress \
  CLUSTER_TAG=multi_engine_20261022_fullrtl_final \
  CLUSTER_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261022_fullrtl_final \
  COMPUTE_SEEDS='20261021 20261022 20261023' \
  COMPUTE_COV_SEEDS='20261021 20261022 20261023 20261024 20261025' \
  AI_RANDOM_CASES=20 AI_SEED=20261022 \
  VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Tools: VCS/URG `V-2023.12-SP1_Full64`; VC Formal `V-2023.12-SP2`. The host is
Rocky Linux 8.10 on WSL2. VCS printed unsupported-host/kernel notices, but the
simulations, formal run, and URG report completed. The main merged report is
under
`/tmp/nmaforge_compute_cluster_multi_engine_20261022_fullrtl_final/dut_coverage/urg/`;
the top-only report is under `dut_coverage/top_only_urg/`. DMA–SPAD tagged logs
and VDBs were moved from the simulation directory to the run's
`dma_spad/repo_artifacts/` after simulation.

## Remaining verification work

This is partial raw coverage and selected functional closure. Uncovered DUT
bins, broader per-engine fault × abort × reset combinations, full-domain FP
parity formal, and project-wide UVM/formal/LEC/DFT closure remain open. The
formal run checks serial dispatch and ownership; it does not prove engine
arithmetic or full-top behavior.
