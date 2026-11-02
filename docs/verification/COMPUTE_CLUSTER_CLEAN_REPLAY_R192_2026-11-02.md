# Compute Cluster clean-candidate replay — R192

**Run ID:** `R192-CLEAN-CANDIDATE-SMOKE-UVM-3S-20261102`  
**Candidate commit:** `9388d6730b480d5136f7347823a25e5e2ce6d3e6`  
**Candidate tree:** `fcbf60bd035691ae88f1631c3b5db747d411ebe0`  
**Test-source identity:** RTL, UVM, subsystem smoke, and source lists are byte-identical to R188/R189 test SHA `5068af69e5006fdc869d60244df0708c810cf3ea`; this candidate adds documentation and benchmark evidence only.  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, Python `3.12`.

## Clean-worktree runs

The candidate was checked out into detached worktree `/tmp/nmaforge_r191_candidate_clean`.

Top Smoke command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make ai_smoke \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261025
```

Real-top Compute Cluster UVM command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make uvm_compute_cluster_regress \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r191_candidate_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

## Results

- Top Smoke passes its 86-descriptor/60-tensor mapper precheck and all 20 seeded random cases; the simulation ends with `TEST PASS`.
- The real-top UVM passes on all three seeds with `UVM_WARNING/ERROR/FATAL = 0/0/0`. Each run reports 69,656 checked Memory Image words, zero mismatch/unknown/stale/orphan, 22,855 accepted reads, 22,814 returned responses, 41 reset-dropped reads accounted for, and empty response ledgers.
- Each seed checks all seven real engines, 21/21 engine-pair overlaps, max-active 7, 2,694 shared-SPAD backpressure cycles, all 18 parity cases, all 19 Protection cases, and the 72/72 legal engine/operand × reset-phase cross. The declared applicable `cluster_cg` is 64/64 and focused coverage is 100%.
- The compute-only merged URG group score is 71.89%, not 100%. Assertion report: 17/22 properties have real successes; zero failures/incomplete; two UVM RAL internals have no attempts. Three AXI AR/AW properties have no real success in this compute-only workload, and only the W-stall cover matches. The separate 16-seed mixed E2E merge remains the evidence for the three AXI cover properties and 21/21 declared functional groups in R190.
- UVM compile has no `Warning-`, `Error-`, or `TFIPC`. Top Smoke retains its existing `Warning-[LOOP-REROLL-ENABLED]` fixture warning; no Error or TFIPC diagnostic.

## Evidence files

Logs and text URG reports are archived outside the repository at `/tmp/nmaforge_r192_clean_candidate_evidence.tar.gz` (SHA-256 `14499d80187adffd8c8316ee29cea60bff9d3fdfa726181865086c0952351294`). The archive includes the three seed logs, UVM compile log, merged assertion/functional reports, Top Smoke compile/run logs, and a manifest. Manifest SHA-256: `9115cd93a59173fb15ea6908bd7ac180828a03388a64ea2e404aaaee68ae91a8`.

## Sign-off effect

R192 verifies reproducibility at the documented candidate commit; it promotes no requirement. The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. Remaining gaps include the unresolved per-opcode range/stride/alias contract, broader legal production requester × fault × phase × reset/backpressure crossings, and requirement clauses not covered by the named testpoints. See the [current sign-off report](COMPUTE_CLUSTER_V1_SIGNOFF_REPORT.md) and [open-issue list](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md).
