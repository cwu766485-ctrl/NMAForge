# Compute Cluster exact published-head clean replay — R304

**Result:** PASS for the listed regression scope. This is a reproducibility replay only; it does not close any additional Requirement or change the v1.0 HOLD decision.

## Candidate and environment

| Item | Evidence |
|---|---|
| Published branch | `feat/compute-cluster-closeout-audit` |
| Exact published HEAD | `5735e942853b7ac689a19e4d8fc2e12c07a22545` |
| Tree | `57cf9af2edf8e80751f7e9e87aa41b7d0ed097e7` |
| Worktree | New detached clean checkout at the exact HEAD; initial `git status --short` was empty |
| VCS / URG | Synopsys VCS/URG `V-2023.12-SP1_Full64` |
| Evidence archive | `/tmp/nmaforge_r304_evidence_5735e94.tar.gz`; SHA-256 `fb4992f5e57c9a072b06c35343d79b69efc5c58f79f2cddce00516a6b48daebd` |

## Commands and results

From `dv/uvm/sim`:

```sh
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r304_uvm_5735e94 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

**PASS**, seeds `20261025/20261026/20261027`. All seven production engines, the production SPAD mux/arbiter, Protection, and behavioral four-bank memory are active. Each seed reports:

- `COMPUTE_CLUSTER_REAL_UVM_PASS` and UVM severity `INFO/WARNING/ERROR/FATAL = 296/0/0/0`.
- Memory Scoreboard: 277,883 words checked, zero mismatch, unknown read, or stale epoch.
- Response-owner ledger: 141,773 accepted / 141,754 checked / 19 reset-dropped; zero route/data/error mismatch and zero pending responses.
- The full directed sequence includes real opcode dispatch, Matrix/CNM ownership and contention, parity/Protection completion backpressure, abort/reset recovery, and Golden/image checks. A marker is per the named sequence scope, not a claim that every legal requirement cross is closed.

Combined three-seed URG reports score/group `68.69/84.38%`, line/condition/FSM/branch/assert `72.74/67.62/52.21/63.21/72.00%`. These whole-top values include testbench/UVM hierarchy and unexercised DDR/AXI groups; they are not DUT-only sign-off coverage. The UVM compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

From `dv/subsystem/top_smoke/sim`:

```sh
make ai_smoke AI_RANDOM_CASES=4 AI_SEED=12345
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Both simulations end in `TEST PASS`; the mapper checks 86 descriptors and 60 tensors. The Top Smoke compile retains the existing `[LOOP-REROLL-ENABLED]` fixture warning, which is disclosed and not treated as zero-warning.

## Disposition

R304 confirms that the exact latest published clean tree reproduces the three-seed real-top UVM, Top Smoke, and fixed 20-case top regression with the current VCS license. It does not rerun the eight R303 mutation variants or the broader mixed DDR/AXI URG merge. The RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. The remaining partial rows and their required dispositions are tracked in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).
