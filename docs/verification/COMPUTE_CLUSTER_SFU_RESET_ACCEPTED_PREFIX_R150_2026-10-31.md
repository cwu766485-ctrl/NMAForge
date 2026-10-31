# Compute Cluster SFU reset after accepted output prefix — R150

**Date:** 2026-10-31  
**Published test SHA:** `b49c1bacdcc64d459edce8cbc01dec3fa8237cf0`  
**Tree SHA:** `6f33bacb71fb31e97122c54b185f9aad87e00d33`  
**Product RTL/SPEC:** unchanged; the selected in-repository `ai_accel_memory_fabric` remains reset through the real top-level `aresetn` path.  
**Tools:** Synopsys VCS and URG `V-2023.12-SP1_Full64`, UVM 1.2.

## Testpoint

`TC-CL-R150-SFU-RESET-ACCEPTED-PREFIX` runs a legal SFU GELU descriptor (`opcode=0x35`, 64 scalar outputs) through the real top and production shared-SPAD route. The independent signed Golden repeats input values `16,-16,32,-32` and output values `8,-8,17,-15`. A live `valid && ready` monitor records the accepted SFU output address and data. The sequence asserts accelerator reset immediately after the first output word is accepted, while the SFU is still busy.

The checkers require a proper accepted prefix (`1/64` in all three seeds), verify its address and Golden value, and check every unaccepted destination word remains its sentinel. They also check that the old task does not advance `CPLQ_TAIL` or modify its completion image, all engines clear during four reset cycles, and no old-epoch SFU write or tagged response appears during reset or eight release-quiet cycles. The same descriptor is then reissued in the new epoch; all 64 output words and completion payload match Golden. The focused `sfu_reset_prefix_cg` has six legal phase bins and reaches 6/6 per seed.

The reset is applied at the real top, so `ai_accel_memory_fabric`, its arbiter and SPAD subsystem receive the shared reset. This particular SFU cut occurs after operand reads have completed: `reset_dropped_reads=0` for this case. It therefore adds accepted-write-prefix reset evidence and does not claim a pending-response fabric reset point; the previously documented R99/R114 fabric slices remain separate bounded evidence.

## Fixed-SHA regression

The following checks ran in a detached clean worktree at the published SHA above.

| Run ID | Seeds / command | Result |
|---|---|---|
| `R150-UVM-SFU-RESET-PREFIX-3S-20261031` | `make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r150_clean_replay_b49 COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | 3/3 PASS; VCS compile and URG merge exit 0 |
| `R150-MUTATION-28-20261031` | `make uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r150_clean_replay_b49 COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r150_clean_mutations_b49` | 28/28 expected checker catches |
| `R150-TOP-SMOKE-20261031` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261025 SEED=20261025` | Mapper 86 descriptors / 60 tensors; `TEST PASS` |
| `R150-TOP-20-20261031` | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261026` | 20 randomized cases; `TEST PASS` |

| Seed | Focused accepted prefix / recovery | Memory and response scoreboard | Applicable compute coverage | UVM warning/error/fatal |
|---:|---|---|---:|---:|
| 20261025 | 1/64; completion suppressed; 64/64 recovery; bins 6/6 | 63,497 words; 0 mismatch/unknown/stale/orphan; 20,107 reads, 20,075 responses, 32 reset drops over the full sequence; pending ledgers empty | 100.0% | 0/0/0 |
| 20261026 | 1/64; completion suppressed; 64/64 recovery; bins 6/6 | Same counters and zero-error disposition | 100.0% | 0/0/0 |
| 20261027 | 1/64; completion suppressed; 64/64 recovery; bins 6/6 | Same counters and zero-error disposition | 100.0% | 0/0/0 |

The UVM compile reports zero errors and zero warnings. The three-seed merged URG mixed DUT/testbench/UVM score is **60.42%** (line/condition/FSM/branch/assert/group `69.51/63.60/44.49/59.80/72.00/53.15%`). The report has 17/22 assertion properties with real successes, zero failures and incomplete attempts; five are uncovered (three top AXI AR/AW properties have no real success in this workload, and two UVM RAL internals had no attempts). One of three cover properties matches. These mixed metrics are not functional closure percentages. The declared applicable compute functional group is 100% for this workload only.

The checker-sensitivity campaign covers Address, Data, response Owner, WSTRB, completion error code, write-after-error prefix, response epoch, and Done/Missing-Done/Duplicate-Done on all seven engines. Its injected errors mutate passive monitor observations; they are not DUT fault injection or an RTL mutation score. Top Smoke retains the existing fixture warning `[LOOP-REROLL-ENABLED]`; VCS reports no compile error.

## Evidence archive

The `/tmp/nmaforge_r150_evidence_b49.tar.gz` archive (SHA-256 `c08bd6870921c8ec219407a380f621eb09e706cd28f774bbb3d55d880727c8cb`) contains the VCS compile log, all three seed logs, merged URG text reports, all 28 mutation logs, and separate Top Smoke / 20-case Top compile and runtime logs. Coverage databases and generated simulator/build directories are excluded. The archive README records the commands and result scope.

## RTM disposition

R150 adds one real-SFU accepted-output reset cut point. `REQ-CL-017/018/019/027` and `REQ-PC-006/007` remain `PARTIAL`: other engine/reset cut points, pending-response cases, legal fault × phase × engine × reset combinations, and shared-owner contention are still open. No requirement status changes. The overall RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
