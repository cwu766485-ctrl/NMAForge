# Compute Cluster watchdog completion backpressure — R210

Date: 2026-11-02  
Run ID: `CL-ENGINE-WATCHDOG-CPLQ-R210-CLEAN-3S-20261102`  
Code/test SHA: `744d99716ce97f92912a4eda490eac27d2d9056a`  
Git tree: `429d30238649791d16f3a66e5ec32cbc637bf9d5`  
Simulator: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`

## Test and checker

The real top-level CMDQ test fills the four-entry completion ring's three usable slots with rejected zero-length descriptors, then dispatches one real descriptor to each of the seven engines with watchdog limit 1. While the ring is full, the test checks that the engine retires with watchdog error code 4, the completion tail stays at 3, the three existing completions remain intact, and every destination word remains at its sentinel value. It then advances `CPLQ_HEAD`, checks the held task ID and `ERR_WATCHDOG` (`0x42`) at the wrapped slot, and confirms the completion tail remains at 0 after a further observation.

Before host reads inspect the SPAD image, the checker requires accepted engine SPAD requests and responses to remain idle for three consecutive cycles. This allows the erroring operation's accepted read traffic to drain while the completion request remains blocked by the full ring. The coverage bin is sampled only after the data, queue, error, and exactly-once checkers pass.

## Clean replay results

The exact committed SHA was checked out in detached clean worktree `/tmp/nmaforge_r210_744d_clean` and run with:

```sh
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r210_744d_clean_evidence \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

| Seed | Seven-engine cases | Focused coverage | Memory scoreboard | Response owner ledger | UVM severity |
|---|---:|---:|---|---|---:|
| `20261025` | 7/7 PASS | 7/7 bins, 100% | 66,717 writes; 71,546 words; zero mismatch, unknown, or stale epoch | 3,113 accepted; 3,094 checked; 19 reset-dropped; zero route/data/error mismatch; pending 0 | 0/0/0 |
| `20261026` | 7/7 PASS | 7/7 bins, 100% | Same counts and zero errors | Same counts and zero errors | 0/0/0 |
| `20261027` | 7/7 PASS | 7/7 bins, 100% | Same counts and zero errors | Same counts and zero errors | 0/0/0 |

Each seed emits `CLUSTER_ENGINE_WATCHDOG_CPLQ_PASS` with `engines=7/7`, `blocked=7/7`, `released=7/7`, `wrapped=7/7`, `exactly-once=7/7`, and focused coverage 100%. The merged URG group `engine_watchdog_cplq_cg` is 100%. The merged overall UVM coverage score is 64.92% (group score 75.56%); these aggregates include unrelated coverage and do not indicate global coverage closure. The compile log contains no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

Evidence archive: `/tmp/nmaforge_r210_744d_clean_evidence.tar.gz`  
SHA-256: `29047271fe8951fb2b70bf4a45bccea7041006b07933b1a2780a5a05e9c58ba5`

## Disposition

This adds bounded real-engine watchdog × full-CPLQ backpressure evidence to `REQ-CL-017`, `REQ-CL-019`, `REQ-CL-027`, `REQ-PC-006`, and `REQ-PC-007`. It does not close their broader fault/phase/reset, error-priority, or requester cross-products. No product RTL was modified. The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; Compute Cluster v1.0 remains **HOLD**.
