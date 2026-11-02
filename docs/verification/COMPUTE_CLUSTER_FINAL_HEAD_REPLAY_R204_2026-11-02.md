# R204 — Latest clean-candidate Compute Cluster replay — 2026-11-02

## Candidate and run identity

- Local clean candidate: `bce4f81ef37158cf80e46f5804256c8e7531a9d9`
- Candidate tree: `a60e7523a11795cceddb83ccce71828f204e6ff3`
- RTL/test content is unchanged from the validated `f87acc9bca3b3ecece385fadfd5623de6837ea8d` tree; candidate changes are documentation only.
- Checkout: detached clean worktree `/tmp/nmaforge_r204_clean_bce4f81`
- Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`, UVM 1.2
- Run IDs: `CL-CLEAN-HEAD-REPLAY-R204-20261102`, `CL-DECLARED-COVERAGE-R204-20261102`, `CLUSTER-DUT-MUTATION-R204-20261102`

## Results

| Gate | Result |
|---|---|
| Real-top Compute Cluster UVM | PASS, seeds `20261025/26/27`; each run reports UVM warning/error/fatal `0/0/0`, 69,656 checked memory words, 63,880 writes, and zero mismatch, unknown read, or stale epoch. |
| Top Smoke | PASS, `SEED=20261025`, `AI_SEED=12345`, 4 random cases; mapper check is 86 descriptors / 60 tensors. One existing `LOOP-REROLL-ENABLED` warning remains; no `Error-` or `[TFIPC]`. |
| Seeded Top regression | PASS, `SEED=20261025`, `AI_SEED=12345`, 20 random cases. |
| Mixed-precision E2E coverage regression | PASS, 16 seeds (`20261014`, `712345`, `987654`, and `20261015..20261027`); each has Golden, DMA error, reset/recovery and AXI stall checks. The E2E group and four AXI memory-model stall groups reach 100%. |
| Real RTL Mutation | PASS, 7/7 targeted mutants caught by assigned checkers: address, data, response owner, WSTRB, completion error, missing Done, and duplicate Done. |
| Combined functional coverage | URG merges the 3 Compute Cluster and 16 mixed E2E runs: all 21 declared functional groups are 100%. RTL/test line/condition/FSM/branch is 73.70/68.72/46.69/64.70%. Assertions are 20/22 successful, zero failure/incomplete, with two UVM RAL internal properties having no attempts; all 3 cover properties match. |

The standalone Compute Cluster `cluster_cg` is 100%; the 71.89% standalone compute-only aggregate includes unrelated inactive DMA/AXI covergroups. The combined functional-group score is 100%. This does not mean all RTL code coverage or all 38 requirements are closed.

## Reproduction commands

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r204_uvm_20261102 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r204_mixed_cov_20261102

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r204_mutation_20261102

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/top_smoke/sim ai_smoke SEED=20261025 \
  AI_RANDOM_CASES=4 AI_SEED=12345

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/top_smoke/sim ai_run SEED=20261025 \
  AI_RANDOM_CASES=20 AI_SEED=12345
```

The combined URG report merges the Compute Cluster compile/three seed VDBs and mixed E2E compile/16 seed VDBs. UVM and mixed compile logs contain zero `Warning-`, `Error-`, and `[TFIPC]` diagnostics. Top Smoke retains the fixture's existing loop-reroll warning.

Logs, URG text reports, and mutation compile/run logs are archived outside the repository at `/tmp/nmaforge_r204_evidence_20261102.tar.gz`, SHA-256 `9f32c098463213e338cd6ef4a9da9b44631771b17f48c0350bc7fbca4d3a490f`. VDBs, simulator executables, and generated compiler directories are excluded.

## Sign-off impact

R204 resolves the immediate clean-candidate replay gap after the license service was restored. It does not close the remaining legal descriptor/shape, requester × fault × phase × reset/backpressure, Matrix enabled-profile FSM, and system benchmark clauses. The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. This is not a whole-NPU sign-off.
