# Compute Cluster Published Clean Replay — R267 — 2026-11-03

## Result

The latest published closeout candidate passes the requested fixed-SHA replay
and seven temporary RTL mutation checks. This adds reproducibility and checker
sensitivity evidence only; none of the 38 requirement dispositions changes.
The current review remains **27 PASS-SCOPED / 11 PARTIAL**, and
`CL-DV-v1.0` remains **HOLD**.

## Frozen identity

| Item | Evidence |
|---|---|
| Published candidate | `bb2a1a843cda878c04bfe12773ebd9bd9871ff14` |
| Candidate tree | `0a67e76249ea7668f86f225e491bfeecdb979351` |
| Frozen R158 ancestor | `8e3735e930f01c4a6bbb6a79251e153611dfcda2` (ancestor verified) |
| Worktree | Detached `/tmp/nmaforge_r267_published_bb2a1a8`; clean after replay |
| Executable RTL/DV content | Byte-identical to R264-tested SHA `67641e4fd5653ce0ef2bf8d8f8ae3cefabb0ea7e`; intervening commits are documentation-only |
| Tools | Synopsys VCS/URG `V-2023.12-SP1_Full64`, UVM 1.2 |

## Runs and evidence

| Run ID | Result |
|---|---|
| `R267-CLUSTER-UVM-3S-20261103` | PASS on seeds `20261025/26/27`. Each run reports UVM warning/error/fatal `0/0/0`; Memory Scoreboard `77,501` writes and `96,595` checked words with zero mismatch, unknown read, or stale epoch; response ledger `6,139 accepted / 6,119 checked / 20 reset-dropped / 0 pending`, with zero route/data/error mismatch. |
| `R267-MIXED-E2E-AXI-16S-20261103` | PASS on 16 seeds `20261014..20261027`, `712345`, `987654`; all runs report UVM severity `0/0/0`. URG group score is 90.86%; 20/22 assertions have real successes, zero failure/incomplete, and the two unattempted properties are UVM RAL internals. AXI AR/AW/W stall-to-accept evidence is present in the merged run. |
| `R267-TOP-SMOKE-20-20261103` | PASS, seed `12345`, 20 random cases, final `TEST PASS`. The existing `[LOOP-REROLL-ENABLED]` fixture warning remains; there are no compile errors. |
| `R267-DUT-MUTATION-7-20261103` | PASS, all seven temporary RTL mutants are caught by their expected production checkers: Address, Data, Response Owner, WSTRB, Completion Error, Missing Done, Duplicate Done. |

The Cluster-only URG group score is 82.96%; declared `cluster_cg` is 64/64.
Cluster-only assertions with real successes are 17/22, with zero failure or
incomplete checks, two no-attempt UVM RAL internals, and three attempted
properties without a real success. The separate mixed E2E contributes AXI
assertion/stall evidence; these two reports are not presented as a single
global DUT coverage percentage. Cluster compile and mutant compile logs have
no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The Top Smoke fixture warning
is disclosed above.

## Reproduction commands

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r267_bb2a1a8/cluster \
  COMPUTE_CLUSTER_UVM_BASE_OUT=/tmp/nmaforge_r267_bb2a1a8/cluster_base \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r267_bb2a1a8/mixed_e2e \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=12345 AI_RANDOM_CASES=20 AI_SEED=12345

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
python3 dv/uvm/sim/run_compute_cluster_dut_mutations.py \
  --out /tmp/nmaforge_r267_bb2a1a8/mutations \
  --vcs-home /tmp/nmaforge_vcs_home_linux_alias \
  --seed 20261025 --timeout 600
```

## Limits and next review

The 64/64 `cluster_cg` result covers only the bins declared in that covergroup;
it does not mean every planned testpoint or requirement clause is closed. The
11 `PARTIAL` rows still include legal Engine × Fault × Phase × Reset ×
Backpressure/owner crosses, Matrix FSM raw transition misses and their broader
integration scope, plus remaining descriptor/numeric/interface clauses.
No illegal stimulus or forced internal state was used. Checker mutations
measure sensitivity, not functional closure. Keep `CL-DV-v1.0` at **HOLD**.

For TinyNPU distance, the latest paired run remains R259: the largest tested
GEMM is 8.2% fewer NMAForge controller cycles than TinyNPU's serialized memory
estimate, but NMAForge reads 6,144 B versus 4,096 B modeled for TinyNPU. That
does not establish a same-bandwidth product win. See the [TinyNPU comparison
report](../benchmark/NMAFORGE_VS_TINY_NPU.md) and [R259 matched-controller
evidence](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R259_2026-11-03.md).

Logs-only archive:
`/tmp/nmaforge_r267_bb2a1a8_logs.tar.gz`
SHA-256: `4ef8f2f4fa1323e95780133434bab0cc9bd99fe35b7e0527bc2830b095a2f3c4`

The archive contains compile/run/URG text, mutation outputs, and Top Smoke
logs. It excludes VDBs, simulator binaries, `csrc`, waveforms, and proprietary
tool databases.
