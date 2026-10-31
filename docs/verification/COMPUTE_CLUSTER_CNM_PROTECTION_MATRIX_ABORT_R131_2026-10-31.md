# CNM Protection followed by Matrix Abort — R131

**Date:** 2026-10-31  
**Run ID:** `R131-CNM-PROTECTION-MATRIX-ABORT-3S-20261031`  
**Executed clean-worktree test SHA:** `207cc3896cb635ff04e7095fc18c435080507724`  
**Executed tree:** `caed517e162270fc2f64beb5382fecdccb651bd5`  
**Published test-content commit:** `78aec6c3067c97613521f5744fdba123628ce647` on `feat/compute-cluster-closeout-6848a41` (same tree).  
**Product RTL/SPEC:** unchanged; this change is UVM sequence and required regression gate only.  
**Tools:** VCS/URG `V-2023.12-SP1`; UVM 1.2.

## Testpoint

The real top dispatches a legal Matrix GEMM and CNM GEMV through shared SPAD. CNM source-A is deliberately Protection-denied while Matrix is active. The sequence waits for the CNM Protection result to leave its engine and for Matrix to commit at least one legal output Line, then issues software Abort while Matrix remains active.

The checker verifies CMDQ-ordered completions (Matrix `ERR_ABORT=0x32`, then CNM `ERR_PROTECTION=0x62`), every accepted Matrix Line address/data/WSTRB, the complete destination Memory Image (Golden values only at accepted Line addresses and untouched sentinels elsewhere), unchanged CNM destination, exact Matrix accepted-read response drain, and no new Matrix Line acceptance after the DUT samples Abort. Response-owner route mismatch must remain zero.

| Seed | Matrix reads accepted / returned | Accepted Matrix output Lines | Post-Abort Lines | CNM responses | Owner mismatches | UVM warning/error/fatal |
|---|---:|---:|---:|---:|---:|---:|
| 20261025 | 128 / 128 | 6 | 0 | 2 | 0 | 0/0/0 |
| 20261026 | 128 / 128 | 6 | 0 | 2 | 0 | 0/0/0 |
| 20261027 | 128 / 128 | 6 | 0 | 2 | 0 | 0/0/0 |

All accepted Line writes use full `WSTRB=16'hffff`, unique in-range addresses, and independent Matrix Golden data. All other Matrix destination words retain their sentinels; all CNM destination words remain unchanged. The full byte-addressed Memory Scoreboard checks 42,651 words per seed with 0 mismatch, 0 unknown read, 0 stale epoch, and 0 orphan response; pending ledgers are empty.

## Exact clean replay

Detached clean worktree: `/tmp/nmaforge_r131_clean_207cc38`.  
Output and coverage: `/tmp/nmaforge_r131_clean_207cc38/run/`.

```sh
make -C /tmp/nmaforge_r131_clean_207cc38/dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r131_clean_207cc38/run \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Result: `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`; all three seed logs contain the required R131 marker and the full regression's existing acceptance markers. The compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The declared focused `cluster_cg` is 64/64 bins (100.00%) in the merged URG report. This is the declared focused group, not global functional or code coverage.

Merged mixed DUT/testbench/UVM URG is 55.92% overall; line/condition/FSM/branch/assert/group are `69.27/63.10/41.91/59.51/72.00/29.72%`. Assertions have 17/22 real-success properties, 0 failure, and 0 incomplete; three AXI properties lack real successes in this compute-only workload and two UVM RAL properties have no attempts. A separate AXI workload is required for those properties. Top Smoke and checker-sensitivity mutation campaign are **NOT_RUN at R131**.

## Artifact hashes

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `ef9bd3bcb9bb606223fa9c3934b5a2a837d27cdc9e7d2b7a8ae2f031bb9ff094` |
| `seed_20261025/run.log` | `234671f663c18818e8e2fbdeb30a07f474e48bc36a93ada8a17b36667e146ec6` |
| `seed_20261026/run.log` | `399ffd9483f4e30fbbdb3c9743b35c0a2d6fb95387e8245c9449fd9c947ac9c5` |
| `seed_20261027/run.log` | `332db9096898f4768fd52528dcfa47a80d3084784cf8e9016a67ef60d5b857cc` |
| `urg_merged.log` | `a9544edad8b3fc57e37a849d8189cf45af125645fb01be1f7688059b9e415605` |
| `urg_merged/groups.txt` | `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` |
| `urg_merged/asserts.txt` | `313b1ca31056481997a13dcb159c1fe3ca856c5759ed8940823ed4a6a82ffda5` |
| `urg_merged/dashboard.txt` | `40fe9bf52548b40b80b093789a2295e443d40d8bd3f56d76783fcc9ad07d43b8` |

## Requirement impact and limits

R131 adds a legal Protection→Abort ordering point to `REQ-CL-017/019/027` and a real shared-SPAD owner, drain, and Memory Image point to `REQ-PC-006`. These requirements remain **PARTIAL** because the complete legal Engine × Fault × Phase × Reset/Abort and requester × backpressure matrices are not covered. No requirement disposition is promoted; the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains **HOLD**. No product RTL behavior was changed to satisfy the test.
