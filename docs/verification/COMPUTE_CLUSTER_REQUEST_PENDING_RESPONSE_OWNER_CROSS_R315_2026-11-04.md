# Compute Cluster Request × Pending Response Owner Cross — R315

**Run IDs:** `R315-RESET-OWNER-CROSS-CLEAN-3S-20261104`, `R315-TOP-20-CLEAN-20261104`  
**Code/test SHA:** `695d348e4bb8ad77ed26ff502013765261606995`  
**Git tree:** `03c33489ad9743bfb480c38c76a24df1e5e102d5`  
**Worktree:** detached clean worktree `/tmp/nmaforge_r315_clean_695d348`  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64`

## Scope

R315 extends R312's legal Matrix held-request reset cut across the remaining
legal CMDQ descriptor order rotations. The seven original requester classes,
the canonical Matrix rotation, and the previously added Matrix rotation remain
enabled. The five additional rotations use the same legal seven-engine
descriptors and the production CMDQ/dispatcher/request path. No DUT RTL,
opcode, descriptor payload, checker, or error injection behavior changed.

Every reset cut still requires a real ready request held stable and unaccepted,
an accepted old-epoch read pending after the stall edge, a quiet reset window,
and complete seven-engine Golden recovery. No unreachable state is forced.

## Reproduction

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r315_clean_695d348_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

make ai_smoke VCS=/usr/local/bin/vcs \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261104
```

## Results

| Seed | Reset cuts | Checked memory words | Memory errors | Owner accepted / checked / reset-dropped | Owner mismatches / pending | UVM W/E/F |
|---|---:|---:|---:|---:|---:|---:|
| `20261025` | 13 | 405,647 | 0 mismatch / 0 unknown / 0 stale | 153,752 / 153,726 / 26 | 0 / 0 | 0 / 0 / 0 |
| `20261026` | 13 | 405,647 | 0 mismatch / 0 unknown / 0 stale | 153,752 / 153,726 / 26 | 0 / 0 | 0 / 0 / 0 |
| `20261027` | 13 | 405,647 | 0 mismatch / 0 unknown / 0 stale | 153,752 / 153,726 / 26 | 0 / 0 | 0 / 0 / 0 |

All 13 real cuts per seed pass, including all seven Matrix submission-order
rotations. The sequence-level reset requester bins are 7/7. The merged raw
stalled-request × pending-response-owner cross remains **8/49 (16.33%)**;
the additional legal orderings repeat already-observed response-owner pairs.
The other 41 pairs still require source-level legal reachability disposition.
The two owner coverpoints each hit 7/7; the owner-pair covergroup aggregate is
72.11%, not a closure result.

The VCS UVM compile log has no `Warning-`, `Error-`, `[TFIPC]`, or fatal
diagnostics. Top Smoke passes the mapper precheck (86 descriptors / 60
tensors) and the fixed 20-case run ends `TEST PASS`. The existing
`LOOP-REROLL-ENABLED` fixture compile warning remains.

## Requirement and sign-off effect

This is additional scoped evidence for `REQ-CL-006`, `REQ-CL-018`,
`REQ-PC-006`, and `REQ-PC-007`; it closes none. The complete 38-row RTM
remains **27 `PASS-SCOPED` / 11 `PARTIAL`**, and `CL-DV-v1.0` remains
**HOLD**. The repeated raw owner pairs mean that the next useful work is legal
request/response scheduling and reachability analysis, followed by another
directed testcase only where an additional legal pair can be demonstrated.

## Evidence archive

Logs and merged URG `grpinfo.txt` are archived outside Git at
`/tmp/nmaforge_r315_clean_695d348_evidence.tar.gz` (SHA-256
`b3779d80997591c0587fa72903e8fa188b0f8e1248242ef92f5988187539d474`).
