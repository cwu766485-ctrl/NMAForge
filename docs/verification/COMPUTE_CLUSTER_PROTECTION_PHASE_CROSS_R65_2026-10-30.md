# Compute Cluster SPAD Protection Phase Cross — R65

Date: 2026-10-30  
Run ID: `R65-CLUSTER-PROTECTION-PHASES-3S-2AB887A`  
Code/test SHA: `2ab887ae1b4846512e7673e3d5ea4ce0061c0d0a`  
Worktree: detached clean worktree `/tmp/nmaforge_protection_phases_r65_clean`  
Simulator / coverage: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`

## Scope and result

R65 extends the real top-level protection-denial check from one operand-read point to three legal phases:

| Phase | Real engines | Cases per seed | Checker |
|---|---|---:|---|
| Deny source A | Scalar INT8, FP, CNM, Matrix, SFU, Conv, KV | 7 | Selected request address, completion task/error owner, and 16 destination sentinel words |
| Deny source B | Scalar INT8, FP, CNM, Matrix, Conv | 5 | Same owner/completion/sentinel checks; only engines with a second source are included |
| Deny writeback | Scalar INT8, FP, CNM, Matrix, SFU, Conv, KV | 7 | Denied output access, completion task/error owner, and unchanged destination image |

The 19 test IDs map to the emitted `engine` and `phase` marker fields as follows:

| Test IDs | Marker `phase` | Marker `engine` values |
|---|---:|---|
| `CL-PROT-PHASE-001..007` | 0 | 0..6 (Scalar, FP, CNM, Matrix, SFU, Conv, KV) |
| `CL-PROT-PHASE-008..012` | 1 | 0, 1, 2, 3, 5 (Scalar, FP, CNM, Matrix, Conv) |
| `CL-PROT-PHASE-013..019` | 2 | 0..6 (Scalar, FP, CNM, Matrix, SFU, Conv, KV) |

Each seed reports 19/19 named cases; three seeds produce 57/57 passes. Engine error codes follow the frozen ABI: 6 for Scalar/FP/CNM/Matrix/SFU and 7 for Conv/KV. Descriptor fetch and completion traffic remain permitted. The source ranges are selected to avoid overlap for the tested engine formats. The test does not inject illegal addresses or unsupported WSTRB values.

Per-seed memory scoreboard: 5,940 accepted writes, 5,812 checked words, zero mismatches, zero unknown reads, zero stale-epoch responses, and epoch 9. UVM warning/error/fatal counts are `0/0/0`. The focused R65 phase-cross testpoint group is 19/19 per seed (100% of the cases defined by this test); this is not whole-Cluster functional coverage, code coverage, or requirement closure.

The exact clean SHA also passes `make ai_smoke` and `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`. The top smoke log retains its existing fixture `LOOP-REROLL-ENABLED` warning; this is not a new UVM compile warning and is not hidden by the UVM severity summary.

## Clean-SHA commands

From `/tmp/nmaforge_protection_phases_r65_clean`:

```sh
cd dv/uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_protection_phases_r65_clean_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026'

cd ../../subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All commands exited 0. UVM compile/elaboration completed for 60 modules. Three per-seed test logs each include `CLUSTER_PROTECTION_CROSS_PASS`, 19 case markers with phase counts `7/5/7`, and the scoreboard summary above. The Top Smoke log ends in `TEST PASS`; the seeded top run also ends in `TEST PASS`.

## Evidence paths and hashes

Generated simulator artifacts remain outside version control.

| Artifact | SHA-256 |
|---|---|
| `/tmp/nmaforge_protection_phases_r65_clean_uvm/compile.log` | `65e2ea1017a04a24ffea409569ed025d7f65e5a827dedbfb506ba273d4d507c3` |
| `/tmp/nmaforge_protection_phases_r65_clean_uvm/seed_20261030/run.log` | `32ca926e1e6d32aacf6b476e080d4db7964122a3fa586fd8ed6ac735fd84467d` |
| `/tmp/nmaforge_protection_phases_r65_clean_uvm/seed_20261025/run.log` | `c9d45cc3d21da48b7c9982c1c9247e762cf801d4254e345d11cba9cf36fb2b95` |
| `/tmp/nmaforge_protection_phases_r65_clean_uvm/seed_20261026/run.log` | `24fa118839bf42c5174b9beb5c86df139c64f84092ffa24af296d5310325346d` |
| `/tmp/nmaforge_protection_phases_r65_clean_uvm/urg_merged.log` | `1bb977ccb0d762a3c387ba7000c81a9ff4d2381f266338a9534427befe89ffac` |
| `dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | `5e1c2a6801850dd120d5bafb3bc36a1b7fd468823a5c9458c96d40975a8a71c5` |
| `/tmp/nmaforge_protection_phases_r65_clean_top_seeded.stdout` | `99faf0446f782578fd4680848079d559ca8e765f275edfa06be7939b0ab48289` |

## Requirement impact and limits

R65 extends the Protection portions of `REQ-CL-017` and `REQ-CL-027`, and the compute-requester/Protection slice of `REQ-PC-006`. Test IDs are `CL-PROT-PHASE-001..019`; the request-access monitor confirms the intended denied port/address, the completion checker verifies task/error attribution, and the memory-image checker verifies no unauthorized destination write. The actual 19 case markers are repeated on each seed, with seed recorded in each marker.

These requirements remain `PARTIAL`. R65 does not cover all faults, every legal phase per engine, Abort/Reset overlap, completion backpressure, all accepted-write-prefix boundaries, every requester/backpressure pair, or external-fabric compliance. No global coverage or requirement disposition is promoted. `OPEN-CL-003` remains open and Compute Cluster v1.0 remains **HOLD**.
