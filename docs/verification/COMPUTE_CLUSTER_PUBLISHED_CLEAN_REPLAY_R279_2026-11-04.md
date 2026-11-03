# Compute Cluster Published Clean Replay — R279

## Disposition

R279 replays the published closeout commit after strengthening the Matrix/CNM
banked-client fairness test. The test now deliberately starts from the legal
`RR_BANKED` scheduler position, and the Make target requires the sustained
12/12 grant result. The exact published SHA passes the focused arbiter gate,
Top Smoke, the fixed 20-case top run, and three real-top Compute Cluster UVM
seeds. An AXI-stall integration run also activates the AR/AW/W stall-to-accept
cover properties.

This adds testpoint and reproducibility evidence; it does not close a new
requirement. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and
`CL-DV-v1.0` remains **HOLD**.

## Fixed identity and evidence

| Item | Value |
|---|---|
| Published closeout SHA | `487794dfa2d931391fd5ac82f16626b7c6f878e5` |
| Source/test tree | `c01a4e15f4f72ca120aa5e7d41094173c011f9ea` |
| Equivalent local commit | `f1b9d3e72cbdfb2e89a61d289e325f389bc76b50` (same tree and parent; GitHub generated the published commit object) |
| Test ID | `TC-PC-R279-RR-BANKED-START-MATRIX-CNM-FAIRNESS` |
| Run IDs | `R279-ARB-10K-PUBLISHED`; `R279-TOP-20-PUBLISHED`; `R279-UVM-3S-PUBLISHED`; `R279-AXI-STALL-PUBLISHED` |
| Seeds | `20261025`, `20261026`, `20261027`; top random seed `12345`; AXI-stall seed `20261015` |
| Simulator | Synopsys VCS / URG `V-2023.12-SP1` |
| Clean worktree | `/tmp/nmaforge_r278_rrbanked_clean` |
| Evidence archive | `/tmp/nmaforge_r279_published_sha_evidence_v2.tar.gz` |
| Archive SHA-256 | `b4c9c3d0d76fabd87264b0d30e51eed97815977fe8327b26dd95e34627c2618f` |

## Results

| Area | Result |
|---|---|
| `ai_spad_arb_run` | PASS. The sustained test starts at `RR_BANKED`; over 24 cycles CNM and Matrix each receive 12 grants, max observed wait is one banked-class opportunity, owner tags/lane masks are checked, and the response pipeline drains. The 10,000-cycle scheduler test passes with 3,334 grants per global client and maximum wait 2. |
| Top Smoke | PASS (`TEST PASS`). The existing `[LOOP-REROLL-ENABLED]` fixture warning remains. |
| Seeded Top | PASS, 20 cases, seed `12345`. |
| Real Compute Cluster UVM | PASS on all three seeds. Each seed checks 96,071 Memory Image words from 77,498 writes with zero mismatch, unknown read, or stale epoch. The engine response-owner ledger reports 6,139 accepted / 6,119 checked / 20 reset-dropped, with zero route/data/error mismatch and zero pending. The broader cluster scoreboard reports 33,681 reads / 33,638 responses / 43 reset-dropped, zero orphan and no pending clients. Applicable focused Compute Cluster coverage is 100%; UVM severity is 0/0/0. |
| Compile diagnostics | No `Warning-`, `Error-`, or `[TFIPC]` diagnostics in the Compute Cluster UVM compile log. |
| AXI-stall integration | PASS. Seed `20261015` exercises address stalls and active/reset/recovery paths; AR/AW/W stall-to-accept SVA covers match 14/5/12 times. UVM severity is 0/0/0. |

The Compute Cluster-only merged URG report has 17/22 assertions with real
successes, zero failures/incomplete, and two UVM RAL internal assertions with
no attempts. Three top AXI assertions have no real success in that
Compute-Cluster-only workload; the separate AXI-stall run provides actual
AR/AW/W stall-to-accept cover matches. Hierarchical line/condition/FSM/branch/
assert coverage for the Compute Cluster-only merge is 78.14/68.73/52.02/68.19/
77.27%; these figures are not requirement closure. The global raw coverage
gaps remain disclosed.

## Requirement evidence

| Requirement | Status | R279 evidence | Remaining scope |
|---|---|---|---|
| `REQ-CL-014` | PARTIAL | `TC-PC-R279-RR-BANKED-START-MATRIX-CNM-FAIRNESS`; Make gate requires `RR_BANKED` start, 24-cycle 12/12 grants, max wait 1 and response ownership. | Production seven-engine fairness across legal downstream latency, faults, phases, and reset is not closed. |
| `REQ-PC-007` | PARTIAL | Same isolated arbiter test plus three-seed production UVM owner and memory ledgers. | The full production requester-pair × fault × phase × backpressure × reset cross remains open. |

No requirement status is promoted by R279.

## Reproduction commands

Run from the detached worktree at the published SHA above.

```sh
cd dv/subsystem/top_smoke/sim
make ai_spad_arb_run VCS=/usr/local/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
make ai_smoke VCS=/usr/local/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg SEED=20261104 AI_RANDOM_CASES=20 AI_SEED=12345
make ai_run VCS=/usr/local/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg AI_RANDOM_CASES=20 AI_SEED=12345
cd ../../../../dv/uvm/sim
make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r278_rrbanked_published_3seed VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
make uvm_mixed_precision_ddr_e2e_axi_stalls VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

## Remaining blockers

- `REQ-CL-014` and `REQ-PC-007` still need broader legal production-client,
  fault, phase, memory-latency, and reset ownership crosses.
- Eleven requirements remain `PARTIAL`; the full phase-A exit review is not
  met. Keep `CL-DV-v1.0` at **HOLD**.
- The latest paired TinyNPU GEMM report remains R273: at 16×16×16 NMAForge is
  152 cycles vs a 151-cycle serialized endpoint; at 16×16×32 both are 231;
  at 32×32×64 NMAForge is 1,198 vs a modeled 1,305 cycles but reads 6,144 B
  against the model's 4,096 B allowance. This is near parity on small shapes
  and not a same-service performance win. GEMV/decode, CNN and common-memory
  comparisons remain unmeasured or unpaired.
- Behavioral-memory simulation is not ASIC PPA evidence.
