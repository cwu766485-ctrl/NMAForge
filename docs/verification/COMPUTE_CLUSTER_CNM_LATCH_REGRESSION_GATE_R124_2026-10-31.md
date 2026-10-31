# Compute Cluster CNM Latch Regression Gate — R124

**Date:** 2026-10-31  
**Purpose:** make R123's legal CNM descriptor-latch test a required check in every default three-seed Compute Cluster regression  
**Executed code/test SHA:** `752c9e0327c18b8775f3bfac62f4cf5483dc38d7`, tree `9232a92b09f4fed7573ecdc50c786f5680b8281e`  
**Published test-only SHA:** `863771c1062ff8390dc82c705594c5cef3289e3c`, same tree `9232a92b09f4fed7573ecdc50c786f5680b8281e`

## Change

`dv/uvm/sim/Makefile` now requires `[CLUSTER_CNM_PARAMETER_LATCH_PASS]` in each seed log from `uvm_compute_cluster_regress`. If a seed omits the marker, the Make target fails. This makes the R123 CNM launch-parameter check part of the regression acceptance gate. The product RTL, SPEC, sequence, and checker logic are unchanged from the published R123 source tree.

## Exact-SHA verification

Tool versions: VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

| Run ID | Seeds | Command | Result |
|---|---|---|---|
| `CL-CNM-LATCH-GATE-R124-20261031` | `20261025`, `20261026`, `20261027` | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r124_cnm_latch_gate_752c9e0 COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | PASS at exact tested SHA. The new marker appears once per seed. Each run reports UVM warning/error/fatal `0/0/0`, declared `cluster_cg` coverage 100%, 41,776 checked words, zero mismatch/unknown/stale epoch/orphan. Each CNM case sees 10 CNM/scalar overlap cycles, one scalar descriptor-word write, and 16 outputs equal to independent signed four-bank K=64 Golden `47,104`. |
| `CL-CNM-LATCH-MUTATION-R124-20261031` | default | `make -C dv/uvm/sim uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r124_cnm_latch_gate_752c9e0 COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r124_cnm_latch_gate_mutations_752c9e0` | PASS `28/28`: address, data, owner, WSTRB, completion error code, write after error, response epoch, and Done / Missing Done / Duplicate Done for all seven engines. The Make campaign reports “expected checker verified per mutation.” These are passive-monitor sensitivity probes, not an RTL mutation score. |
| `CL-CNM-LATCH-SMOKE-R124-20261031` | default | `make -C dv/subsystem/top_smoke/sim ai_smoke` | PASS, mapper reports 86 descriptors / 60 tensors and smoke ends with `TEST PASS`. Existing fixture notice `[LOOP-REROLL-ENABLED]` remains. |

UVM output root: `/tmp/nmaforge_r124_cnm_latch_gate_752c9e0`. The final compile log SHA-256 is `9e2137d707d0899496d40e0cfa55b1399e65a079f3a85e2e054f68a00a92cb11`. Seed run log SHA-256 values:

| Seed | `run.log` SHA-256 |
|---|---|
| `20261025` | `62ba9817eda9f05d201af9d751d2c74a4492af558e0facd239bda23c289b9a4d` |
| `20261026` | `541aee548382cbe35c1bc1f4e9b4ae480bf071d618d6ca1a934dce792579c2a2` |
| `20261027` | `e295d861d09e3f68e9a9c646c2486c159444e6f11333a9b374ed3d59485b38a7` |

URG dashboard SHA-256: `55b65fe75f2f472af2ab87ca60d33586682a8402bd9f4edfd25741d38b5008ff`; URG log SHA-256: `b32e29ffaa35cde774c5347c83eb193849ade4381bbb9fd7a58fe62b41773dd4`. The mixed DUT/TB/UVM summary remains 55.34% (line/condition/FSM/branch/assert/group `68.72/61.89/40.99/58.71/72.00/29.72%`); this is not global functional coverage. Assertions remain 17/22 with real successes, zero failures/incomplete; three AXI properties have attempts but no successful antecedent in this compute-only workload, two UVM RAL properties have no attempts, and only the W stall cover matches (3). The separate R92/R102 evidence remains the AXI traffic evidence.

Top Smoke log SHA-256: `5221b9202c9028c531996dbd6e7f83d1e149084236702aec3b60d48809cefa4a` at `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`. Mutation logs and databases remain outside Git under `/tmp/nmaforge_r124_cnm_latch_gate_mutations_752c9e0/`.

## Requirement disposition

| Requirement | Evidence added | Status |
|---|---|---|
| `REQ-CL-005` | R123 adds the functional CNM descriptor-latch stimulus/checkers; R124 makes its pass marker mandatory on each of three regression seeds | **PARTIAL**; only one CNM descriptor word/field and one legal overlap scenario are covered |

The full 38-row disposition remains 24 PASS-SCOPED / 14 PARTIAL. The R124 change adds no product behavior and promotes no requirement. `CL-DV-v1.0` remains **HOLD**.
