# Compute Cluster Request × Pending-Response Owner Cross (R311)

**Result:** PASS for the measured reset cut; the full owner cross remains open.

## Fixed candidate and run

- Published branch: `feat/compute-cluster-closeout-audit`
- Exact tested GitHub SHA: `23a51b1f8942a9db7df8b15ee9337690aa9405b7`
- Source tree: `1c207f50c54664047d0be3a1ce538300b4b0d81e`
- Test ID: `TC-CL-R311-REQUEST-X-PENDING-RESPONSE-OWNER-RESET`
- Run ID: `R311-RESET-OWNER-CROSS-CLEAN-3S-20261104`
- Seeds: `20261025`, `20261026`, `20261027`
- Tools: Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`
- Logs and URG summary archive SHA-256: `3d0c36cb422e53ace8811673ad7fe72414a196838f70340b4d589b6f253c4f23`

The run used a detached clean worktree at the exact published SHA:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r311_clean_23a51b1_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The reset monitor already counted accepted reads and returned responses per real engine. R311 records the seven-bit pending-response owner mask and per-owner outstanding counts at the post-stall reset cut, then samples a UVM cross of the held-request owner and each owner with a pending accepted read. The test keeps the existing requirement that a pending old-epoch read remain after the one-cycle held-request stall.

Each seed passes the full real-top Cluster regression. Each has seven held-request owner cuts, seven pending-response owner pairs, and the same observed pairs:

| Held request owner | Pending response owner | Pair samples across 3 seeds |
|---|---|---:|
| INT8 | KV | 3 |
| FP | INT8 | 3 |
| CNM | Matrix | 3 |
| Matrix | Matrix | 3 |
| SFU | FP | 3 |
| Conv | SFU | 3 |
| KV | Conv | 3 |

The raw UVM requester × response-owner cross is **7/49 bins (14.29%)** after merging all three seeds. The two owner coverpoints are 7/7 and 6/7 respectively. The UVM log's covergroup aggregate of 66.7% is not the cross percentage. The other 42 cross bins have not been proven unreachable; no illegal traffic was added to force them. They remain unclosed pending legal-reachability analysis and broader stimulus.

Each seed's Memory Scoreboard checks 342,799 words with zero mismatch, unknown read, or stale epoch. The Response Owner Ledger is `147675` accepted / `147654` checked / `21` reset-dropped, with zero route/data/error mismatch and zero pending. UVM warning/error/fatal counts are `0/0/0`; compile output contains no `Warning-`, `Error-`, `[TFIPC]`, or `Fatal` diagnostics.

## Requirement impact and limits

This adds exact owner attribution for the sampled legal reset cuts and strengthens `REQ-CL-006`, `REQ-CL-018`, `REQ-PC-006`, and `REQ-PC-007`. It does not close them: 42/49 raw requester × pending-response-owner bins remain unhit and undispositioned, and the broader fault × phase × reset × backpressure and memory-service-contention scope remains open. No RTM row is promoted; the 38-row matrix remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

Generated simulation, coverage databases, and logs remain outside the repository. The archive contains the compile transcript, three per-seed logs, and the merged URG `grpinfo.txt` / `groups.txt` summaries.
