# Compute Cluster Seven-Engine Reset Request-Owner Sweep (R309)

**Result:** PASS for the named test scope; this is supplemental evidence and does not close the affected RTM requirements.

## Candidate and reproducibility

- Published branch: `feat/compute-cluster-closeout-audit`
- Published test SHA: `0982a42619f9b7d7e29280fdcdae4ed68acb13fd`
- Tree SHA: `629a62204633c3ef95b6ea9add6f0bb664c503a2`
- Test ID: `TC-CL-R309-SEVEN-ENGINE-RESET-WITH-REQUEST-OWNER-SWEEP`
- Run ID: `R309-RESET-REQUEST-OWNER-SWEEP-CLEAN-3S-20261104`
- Seeds: `20261025`, `20261026`, `20261027`
- Tools: Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`
- Logs-only archive SHA-256: `49f1774b303c20173f93e2c4b5dca0f77ab4be364eea77df46d7670279d9a1b1`

The regression was run from a detached clean worktree at the published SHA:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r309_clean_replay_0982a42 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

All three seeds passed. For each selected requester, the test waited until all seven production engines were busy and had accepted work, selected that engine's real request while ready, held it stable and unaccepted for one sampled cycle, then asserted reset. It checked old-epoch quiet, all-seven-engine task recovery, ordered completions, and complete output Goldens. Focused reset-request-owner coverage reached 7/7 bins on every seed. UVM severity was 0/0/0 per seed.

Owner order was INT8, FP, CNM, Matrix, SFU, Conv, KV. The reset-cut pending-read counts in that order were `0, 1, 1, 1, 1, 0, 1`. Thus the INT8 and Conv owner-specific cuts prove held real requests, reset, quieting, and full recovery, but did not coincide with a pending old read. FP, CNM, Matrix, SFU, and KV did. This limitation is retained; prior tests separately cover other reset cuts with pending responses.

Each seed's full-run Memory Scoreboard checked 342,726 words with zero mismatch, unknown read, or stale-epoch response. The Response Owner Ledger ended `accepted=147661`, `checked=147641`, `reset_dropped=20`, with zero route/data/error mismatch and zero pending. The VCS compile transcript contains no `Warning-`, `Error-`, `[TFIPC]`, or `Fatal` diagnostics. The focused 7/7 result is not whole-design functional coverage closure.

## Requirement impact

This adds bounded reset/request ownership evidence for `REQ-CL-006`, `REQ-CL-018`, `REQ-PC-006`, and `REQ-PC-007`. Their dispositions remain `PARTIAL`: broader requester × fault × phase × reset combinations, external-fabric contract behavior, and downstream-service contention still require closure or approved disposition. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

Evidence logs are archived outside the repository to avoid committing generated simulator output. The archive contains `compile.log` and the three seed `run.log` files only.
