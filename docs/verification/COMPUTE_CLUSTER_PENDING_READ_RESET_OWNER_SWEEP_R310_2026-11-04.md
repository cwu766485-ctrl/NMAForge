# Compute Cluster Pending-Read Reset Owner Sweep (R310)

**Result:** PASS for the named test scope; this strengthens reset evidence but does not close the affected RTM requirements.

## Fixed published candidate and run

- Published branch: `feat/compute-cluster-closeout-audit`
- Exact tested GitHub SHA: `a061c2ea96a874d0755674c75139154a2e6e391f`
- Source tree: `7a4051b78d2f874c014f67e2db4045d88d7b7815`
- Test ID: `TC-CL-R310-SEVEN-ENGINE-RESET-WITH-PENDING-READ-OWNER-SWEEP`
- Run ID: `R310-RESET-PENDING-RESPONSE-OWNER-CLEAN-3S-20261104`
- Seeds: `20261025`, `20261026`, `20261027`
- Tools: Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`
- Logs-only archive SHA-256: `04556913c3c3108eefcab07865a5079a7701720e17d13e00face264b9ed1ad4e`

The run was launched from a detached clean worktree at the exact published SHA:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r310_clean_a061c2e_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

For each of the seven request-owner cuts, all seven real engines were active and had accepted work. The selected production request was valid and ready, then held stable and unaccepted for one sampled cycle. The test now requires at least two systemwide accepted reads before applying that stall and requires at least one accepted old-epoch read to remain pending after the stall edge. All seven cuts meet this condition on all three seeds. Reset quieting, stale-activity suppression, ordered recovery completions, and complete seven-engine Golden images pass. Focused request-owner bins are 7/7 (100%) per seed; UVM severity is 0/0/0.

`pending_reads=1` is a systemwide outstanding-response count at each cut; this test does not claim that the pending response belongs to the same engine whose new request is held. It establishes the legal overlap of a held requester, at least one accepted old-epoch response, shared reset, and recovery.

Each seed's full Memory Scoreboard checks 342,799 words with zero mismatch, unknown read, or stale-epoch response. The Response Owner Ledger ends `accepted=147675`, `checked=147654`, `reset_dropped=21`, with zero route/data/error mismatch and zero pending. UVM reports warning/error/fatal counts of 0/0/0. The compile transcript is clean of `Warning-`, `Error-`, `[TFIPC]`, and `Fatal` diagnostics.

## Requirement impact and limits

This adds bounded evidence for `REQ-CL-006`, `REQ-CL-018`, `REQ-PC-006`, and `REQ-PC-007`. Their disposition remains `PARTIAL`: the run does not exhaust requester × pending-response-owner × fault × phase × reset cases, downstream-service contention, or every legal memory-image/fault combination. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

Generated simulation and coverage outputs remain outside the repository. The archive contains the VCS compile log and three per-seed UVM logs only.
