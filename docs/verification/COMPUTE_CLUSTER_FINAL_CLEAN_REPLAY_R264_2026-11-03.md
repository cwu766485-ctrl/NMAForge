# Compute Cluster Published Clean Replay — R264

**Decision:** replay PASS; no requirement disposition promoted. The current 38-row review remains **27 PASS-SCOPED / 11 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.

## Frozen source and worktree

| Item | Evidence |
|---|---|
| Published source/test SHA | `67641e4fd5653ce0ef2bf8d8f8ae3cefabb0ea7e` |
| Tree SHA | `a0776e1c1bc9bb4dff7717386c93a42d6b907b63` |
| Frozen R158 published ancestor | `8e3735e930f01c4a6bbb6a79251e153611dfcda2` (verified ancestor of this SHA) |
| Worktree | Detached clean checkout; `git status --short` and final `git diff --exit-code` empty |
| Tools | VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, UVM 1.2; mapper Python 3.12 |

All simulator outputs were directed outside the repository except the canonical Top Smoke build/log files inside the disposable detached worktree. No RTL or test source was edited during this replay.

## Commands

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r263_published_67641e4/uvm \
  COMPUTE_CLUSTER_UVM_BASE_OUT=/tmp/nmaforge_r263_published_67641e4/uvm_base

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r263_published_67641e4/mixed_e2e

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
make -C dv/subsystem/top_smoke/sim ai_smoke SEED=12345 AI_RANDOM_CASES=20 AI_SEED=12345
```

## Results

| Run ID | Result and evidence |
|---|---|
| `R264-CLUSTER-UVM-CLEAN-3S-20261103` | PASS, seeds `20261025/26/27`; compile/elaboration `0 errors, 0 warnings`; each seed UVM severity `0/0/0`, Memory Scoreboard `96,595` checked words with zero mismatch/unknown/stale, and response ledger `6,139 accepted / 6,119 checked / 20 reset-dropped / 0 pending`. R263 32×32×64 real-CMDQ GEMM checks `1,024/1,024` INT32 Golden outputs, completion and both guards; all 21 engine-pair bins pass. |
| `R264-MIXED-E2E-AXI-COVERAGE-16S-20261103` | PASS, all 16 seeds and all Make-required pass markers; each UVM severity `0/0/0`. Merged E2E functional group and four per-transaction AXI groups are 100%; five AXI protocol assertions have real successes (AR burst/payload `176/166`, AW burst/payload `80/70`, W payload `123`); AR/AW/W stall-to-accept covers match `166/70/123`. URG reports 20/22 assertions with real successes, 0 failure/incomplete, and two unattempted properties are UVM RAL internals. |
| `R264-TOP-SMOKE-20-20261103` | PASS with fixed simulator and workload seed `12345`, 20 random cases, mapper `86 descriptors / 60 tensors`, and final `TEST PASS`. The existing `[LOOP-REROLL-ENABLED]` fixture warning is visible; the compile completes without errors. |

## Coverage and remaining limits

The Cluster-only UVM merge contains 33 covergroups and scores 82.96% overall; the declared Compute Cluster `cluster_cg` is 100%. In that compute-only profile, AXI AR/AW traffic is absent: those protocol assertions have no real successes and AR/AW stall covers are not hit (W has three matches). The separate 16-seed mixed E2E run at the same source SHA supplies the missing AXI evidence above. This is scoped functional and assertion evidence, not global 100% functional or raw RTL coverage closure.

R264 confirms clean reproducibility of the published closeout SHA, including the frozen R158 lineage, real seven-engine UVM, AXI assertion non-vacuity, and Top Smoke. It does not close the 11 remaining `PARTIAL` requirement rows, approve exclusions, or authorize full v1.0 sign-off. Existing contracts and legal fault/phase/reset/backpressure gaps remain governed by the Execution RTM; no illegal stimulus or forced internal state was used.

## Archived evidence

Logs-only archive: `/tmp/nmaforge_r264_final_tree_clean_replay_20261103_logs.tar.gz`

SHA-256: `3b2b6025c14e5c9b2f41056925aa24c04351627fb62691a12ba2efba1f40823d`

The archive contains compile and run logs, URG text reports, and a manifest. It excludes VDBs, simulator binaries, `csrc`, waveforms, and proprietary tool databases.