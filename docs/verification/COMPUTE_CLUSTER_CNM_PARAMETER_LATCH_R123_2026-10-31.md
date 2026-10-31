# Compute Cluster CNM Parameter Latch — R123

**Date:** 2026-10-31  
**Disposition:** bounded `REQ-CL-005` testpoint added; requirement remains **PARTIAL**  
**Product RTL/SPEC:** unchanged; base remains R99 `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413` / SPEC v1.8  
**Executed source/test SHA:** `750fd0f9d27c8c2b0f0b9ed6f4a82f6cacb7ca45`, tree `c8b47296ee6492e8d258f4aa7dc46ebd97844711`  
**Published test-only SHA:** `1abf84864a5b6f0f1d3ef5da72fe67b41df3b367`, same tree `c8b47296ee6492e8d258f4aa7dc46ebd97844711`

## Test point

The real-top sequence starts CNM banked GEMV opcode `0x21` (task `0x0688`, M=16, K=64) from a fetched CMDQ descriptor. While CNM is busy, a concurrently dispatched scalar VDOT task (opcode `0x10`, task `0x0689`) performs a legal scheduler-side SPAD write to the fetched CNM descriptor's destination word. This avoids an illegal host/compute SPAD collision while checking that CNM retained its launch-time parameters.

The sequence observed 10 cycles with CNM and scalar both busy, including one cycle where the scalar request wrote the descriptor destination word. It then checked:

- CNM launch snapshot: opcode `0x21`, the expected C1 source addresses, and original CNM output address.
- All 16 CNM output words against independent signed four-bank K=64 Golden `47,104`.
- Mutated output destination remains at its preloaded sentinel.
- CNM completion with 16 results and scalar completion with result `70`.
- Fetched descriptor destination word contains scalar write `70` after both commands retire.
- Full memory scoreboard: `41,776` words checked per seed, zero mismatch, unknown read, stale epoch response, or orphan response.

The check is deliberately narrow. It proves one CNM launch snapshot under one legal concurrent descriptor-word write. It does not sweep the other CNM descriptor fields, CNM descriptor boundaries, or all engine/field mutation combinations; therefore it does not close `REQ-CL-005`.

## Runs and evidence

Tool versions: Synopsys VCS and URG `V-2023.12-SP1_Full64`.

| Run ID | Seeds | Command | Result and evidence |
|---|---|---|---|
| `CL-CNM-LATCH-R123-20261031` | `20261025`, `20261026`, `20261027` | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r123b_cnm_latch_uvm COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | PASS, three seeds; marker `CLUSTER_CNM_PARAMETER_LATCH_PASS`; each seed UVM warning/error/fatal `0/0/0`, `cluster_cg` 100%, 41,776 words checked with zero mismatch/unknown/stale/orphan. Logs: `/tmp/nmaforge_r123b_cnm_latch_uvm/seed_*/run.log`. |
| `CL-CNM-LATCH-R123-SMOKE` | default | `make -C dv/subsystem/top_smoke/sim ai_smoke` | PASS, `TEST PASS`; mapper precheck reports 86 descriptors / 60 tensors. Existing fixture compile notice `[LOOP-REROLL-ENABLED]` is retained. Log: `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`. |
| `CL-CNM-LATCH-R123-MUTATION` | default | `make -C dv/uvm/sim uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r123b_cnm_latch_uvm COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r123b_cnm_latch_mutations` | PASS, 28/28 expected checker catches. Categories: address, data, response owner, WSTRB, completion error code, write after error, response epoch, and Done / Missing Done / Duplicate Done for all seven engines. Logs: `/tmp/nmaforge_r123b_cnm_latch_mutations/*.log`. Expected UVM errors in mutation runs are checker-sensitivity results; this is not an RTL mutation score. |

Compile log: `/tmp/nmaforge_r123b_cnm_latch_uvm/compile.log`, SHA-256 `eaac3e608ea81dcff361200b75081308f3417d5901072f03a0b131ed4f2e63cd`. No VCS `Warning-`, `Error-`, or `[TFIPC]` diagnostics were found in that compile log.

UVM run log SHA-256 values:

| Seed | `run.log` SHA-256 |
|---|---|
| `20261025` | `d6c65a64670873c3948312fede0959303a36f12ec5057f9714156d5a1452240a` |
| `20261026` | `ae08b2ff6e3024d6b54d5a58bca1413d770fa61c0a53b139e1451dbe94a63ff1` |
| `20261027` | `c7cee3f8c6e73412ea250cffdcdc5bb7187596c0697957a6c08c2d477ec6feed` |

URG merged all three UVM VDBs at `/tmp/nmaforge_r123b_cnm_latch_uvm/urg_merged`. Dashboard SHA-256 is `90352d300a9c86659207bbdd2cb5aa0790aef8dcaa07f3f762fc49284b432474`; URG log SHA-256 is `f32e2f00cc7968dccfcebe16d93f2400d49a2ce1ae87ad60fb09ab189a7e2b11`. The declared `cluster_cg` is 100%; total mixed DUT/TB/UVM score is `55.34%` (line/condition/FSM/branch/assert/group `68.72/61.89/40.99/58.71/72.00/29.72%`). Assertions: 17/22 with real success, zero failures/incomplete; three AXI assertions have attempts but no successful antecedent in this compute-only workload and two UVM RAL internals have no attempts. Of three AXI stall cover properties, only W matches (3); AR/AW have zero matches. This run does not claim full code, SVA, or requirement coverage.

## Requirement trace and sign-off impact

| Requirement | Test ID | Checker | Coverage | Run ID / Seed | Evidence | Status |
|---|---|---|---|---|---|---|
| `REQ-CL-005` | `CL-CNM-LATCH-R123` | Launch snapshot, independent signed GEMV Golden, destination sentinel, both completions, scoreboard owner/memory checks | `cluster_cg` 100% for declared bins; no global coverage claim | `CL-CNM-LATCH-R123-20261031` / `20261025,20261026,20261027` | `/tmp/nmaforge_r123b_cnm_latch_uvm/seed_*/run.log`; tree `c8b47296ee6492e8d258f4aa7dc46ebd97844711` | **PARTIAL**; one CNM descriptor destination mutation point added |

The 38-row disposition remains 24 PASS-SCOPED / 14 PARTIAL. No requirement is promoted by this result. `CL-DV-v1.0` remains **HOLD**. The exact test tree is published on `feat/compute-cluster-closeout-6848a41` at commit `1abf84864a5b6f0f1d3ef5da72fe67b41df3b367`.
