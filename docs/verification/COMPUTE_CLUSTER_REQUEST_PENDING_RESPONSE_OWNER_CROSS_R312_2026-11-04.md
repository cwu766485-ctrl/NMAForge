# Compute Cluster Request × Pending Response Owner Cross — R312

**Run ID:** `R312-RESET-OWNER-CROSS-CLEAN-3S-20261104`  
**Code/test SHA:** `a88c310afbfaf3b02c3c16a5accc31c04ff379f2`  
**Tree:** `a8a0fd314f505348bb623c43133e3da464df8718`  
**Status:** supplemental evidence; no requirement disposition changed.

## Scope and method

R312 permutes the submission order of the same seven legal, independent engine descriptors in the real CMDQ path. It retains the seven existing held-request reset cuts and adds a second Matrix requester cut with a different descriptor order. Each cut checks that a real ready request is held stable and unaccepted, an accepted old-epoch read remains pending after the stall edge, reset quieting holds, and all seven tasks recover against Golden images. It records the cross of the stalled requester with the engine owning the pending response. The DUT, opcode set, operands, task data, checker strictness, and external interfaces are unchanged.

The exploratory unconstrained shuffle was rejected: on seed `20261026`, the strict reset-cut checker correctly stopped when the selected held-request cut no longer had a pending old-epoch read after the stall. That failed experiment is not included in the PASS result and no checker was weakened.

## Reproduction

Detached clean worktree: `/tmp/nmaforge_r312_clean_a88c310`, exact HEAD `a88c310afbfaf3b02c3c16a5accc31c04ff379f2`, clean at run start.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r312_clean_a88c310_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Results

All three clean-SHA seeds pass the real seven-engine Cluster UVM test. Each seed executes eight held-request reset cuts (the seven engine requesters plus the second Matrix order), completes the shared-reset quiet and seven-engine Golden recovery checks, and reports UVM warning/error/fatal counts `0/0/0`.

| Seed | Memory words checked | Memory mismatch / unknown / stale | Owner accepted / checked / reset-dropped | Owner route / data / error mismatch; pending | UVM W/E/F |
|---|---:|---:|---:|---:|---:|
| `20261025` | 353,249 | 0 / 0 / 0 | 148,726 / 148,704 / 22 | 0 / 0 / 0; 0 | 0 / 0 / 0 |
| `20261026` | 353,249 | 0 / 0 / 0 | 148,726 / 148,704 / 22 | 0 / 0 / 0; 0 | 0 / 0 / 0 |
| `20261027` | 353,249 | 0 / 0 / 0 | 148,726 / 148,704 / 22 | 0 / 0 / 0; 0 | 0 / 0 / 0 |

The merged raw 7×7 cross observes **8/49 bins (16.33%)**, each three times across the three seeds:

| Held request owner | Pending response owner |
|---|---|
| INT8 | KV |
| FP | INT8 |
| CNM | Matrix |
| Matrix | CNM |
| Matrix | Matrix |
| SFU | FP |
| Conv | SFU |
| KV | Conv |

The remaining 41 raw bins have **no reachability disposition yet**. They are neither waived nor declared illegal. Continue with source-level legal scheduling/reachability analysis and add only cases reachable through the production dispatcher, mux, and arbiter. No artificial invalid traffic is required to hit a Cartesian cross.

Compile log scan found no `Warning-`, `Error-`, `[TFIPC]`, or fatal diagnostic. The top AXI assertion summary still reports `c_ar_stall_then_accept` and `c_aw_stall_then_accept` with 1,920,893 attempts and 0 matches each; `c_w_stall_then_accept` has one match. AR/AW property applicability/non-vacuity remains a review item; this run does not claim assertion closure.

## Requirement and sign-off effect

This run strengthens evidence for `REQ-CL-006`, `REQ-CL-018`, `REQ-PC-006`, and `REQ-PC-007` only. It closes none: the 38-row RTM remains **27 `PASS-SCOPED` / 11 `PARTIAL`**, and `CL-DV-v1.0` remains **HOLD**. Wider fault × phase × reset × backpressure coverage, Matrix/SFU and fabric contracts, all remaining partial clauses, SVA applicability, and independent sign-off review remain open.

## Evidence archive

Logs, compile output, and merged URG `grpinfo.txt` are archived outside the repository at `/tmp/nmaforge_r312_clean_a88c310_evidence.tar.gz` (SHA-256 `39ee47e0e9965a80ddeb1a43710f03567238023eb2daf44bf367e615206e9f7b`). This preserves generated VCS/URG data outside Git.
