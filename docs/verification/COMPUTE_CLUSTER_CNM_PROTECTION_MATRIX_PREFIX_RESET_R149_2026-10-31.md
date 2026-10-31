# Compute Cluster CNM Protection with Matrix accepted-prefix reset — R149

**Date:** 2026-10-31
**Published test SHA:** `cc5528e938640450c2a06c00f938a2efbd81faaf`
**Published test tree:** `25510596ff019cf002ec01a31b94705b7e929556`
**Product RTL/SPEC identity:** unchanged from RTL/DV baseline `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, Compute Cluster SPEC v1.8
**Tools:** Synopsys VCS and URG `V-2023.12-SP1_Full64`

## Testpoint

`TC-CL-R149-CNM-PROTECTION-MATRIX-PREFIX-RESET` launches a legal 16×32×16 Matrix GEMM and a 16-output CNM GEMV through CMDQ and the production shared-SPAD path. The test denies CNM source-A reads with the configured Protection region while both engines are active. After the CNM Protection error `0x62` is consumed, the still-busy Matrix accepts one 128-bit Golden output Line (4 of 512 result words); shared reset is asserted before Matrix completes.

The checkers validate the accepted Line's address, full WSTRB and four Golden words; all other Matrix destination words remain their original sentinels. They also verify that the old epoch does not advance CPLQ_TAIL or modify its completion image, reset and release stay quiet, and no stale response or owner mismatch appears. The test then republishes both legal tasks in a fresh epoch and checks complete Matrix and CNM Golden images plus ordered completions.

The six explicitly sampled legal phase bins are: Protection consumed while Matrix is active; Matrix Golden prefix accepted after Protection retirement; quiet reset; quiet release; prefix and untouched suffix preserved; full Golden recovery. This is a focused functional group, not global closure.

## Three-seed results

| Run ID | Seed | Matrix prefix before reset | Memory scoreboard | Reset/drain and routing | UVM warning/error/fatal |
|---|---:|---:|---|---|---:|
| `R149-UVM-CNM-PROTECTION-MATRIX-PREFIX-RESET-3S-20261031` | 20261025 | 1/128 Lines = 4/512 words; accepted Line is Golden | 63,400 checked words; 0 mismatch, unknown, stale epoch, or orphan | 20,010 reads, 19,978 responses, 32 reset-dropped; pending ledgers empty | 0/0/0 |
| same | 20261026 | 1/128 Lines = 4/512 words; accepted Line is Golden | 63,400 checked words; 0 mismatch, unknown, stale epoch, or orphan | 20,010 reads, 19,978 responses, 32 reset-dropped; pending ledgers empty | 0/0/0 |
| same | 20261027 | 1/128 Lines = 4/512 words; accepted Line is Golden | 63,400 checked words; 0 mismatch, unknown, stale epoch, or orphan | 20,010 reads, 19,978 responses, 32 reset-dropped; pending ledgers empty | 0/0/0 |

Each seed reports the dedicated `cnm_protection_matrix_prefix_reset_cg` at 6/6 bins and the declared applicable `cluster_cg` at 100%. The merged URG run contains three tests; its mixed DUT/testbench/UVM score is 59.68% (line/condition/FSM/branch/assert/group 69.51/63.60/44.30/59.80/72.00/48.89%). Assertion report: 17/22 properties have real successes, with zero failures/incomplete; three AXI AR/AW properties have no real successes in this compute workload and two UVM RAL properties have no attempts. These raw mixed metrics are not functional closure percentages.

## Same-source replay and checker sensitivity

All runs below use the published R149 source tree above.

| Run ID | Command | Result |
|---|---|---|
| `R149-UVM-CNM-PROTECTION-MATRIX-PREFIX-RESET-3S-20261031` | `make -C dv/uvm/sim COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r149_e68a3e4_clean COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' uvm_compute_cluster_regress` | Three seeds PASS; compile/URG merge succeeds |
| `R149-MUTATION-28-20261031` | `make -C dv/uvm/sim COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r149_e68a3e4_clean COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r149_e68a3e4_mutations uvm_compute_cluster_mutation` | 28/28 expected checker catches: Address, Data, Owner, WSTRB, completion error code, write-after-error, response epoch, and Done/Missing-Done/Duplicate-Done across seven engines |
| `R149-TOP-SMOKE-20261031` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261025 SEED=20261025` | Mapper 86 descriptors/60 tensors; `TEST PASS` |
| `R149-TOP-20-20261031` | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261026` | 20 random cases; `TEST PASS` |

Mutation runs perturb the passive checker observation path; they are checker-sensitivity tests, not RTL fault injection. Top compilation retains the existing fixture warning `[LOOP-REROLL-ENABLED]`; VCS reports no compilation errors. The three-seed UVM compile reports no errors or warnings.

## Evidence archive

The `/tmp/nmaforge_r149_evidence.tar.gz` archive contains the three UVM logs and compile log, merged URG dashboard/groups/assertions, all 28 mutation logs and campaign console, and separate Top Smoke and 20-case Top compile/runtime logs. VDBs and generated simulator directories are excluded. Archive SHA-256: `d0fb1d19bc0dbf963204c49434e8a53ed6f7d1321443f40faa74a05f1d35ff4a`.

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `455457ce4e4f0602fa2602d3c560beaed217be9e07ff9a810e0963887c13b980` |
| UVM seed 20261025 | `b3bca9400f986aa93fa2b96d69c3813ab6f5e4b808ca84848b3af8ad2650190d` |
| UVM seed 20261026 | `d15aff34e24af0d547674bdb067672f55e63ed2c7a91d5f726544e1b5a70dac7` |
| UVM seed 20261027 | `05d7f15c2fc37e60857ccec5614baca91800a2f2125b78d4abcee7412669e6b5` |
| merged URG dashboard | `86455888145c8e80e2a09a658e515e801eb52b1ac8a572f0dd0c81358cce58c6` |
| checker-sensitivity campaign console | `67dcbd48cd1740dbd57322fff4e981e30a0d5ebd454553aba364a9728e98b737` |
| Top Smoke runtime log | `e6c70e12d15e8e21a0d832f1f5138d9efab45eafb6100d70aec2b1fc67378445` |
| Top 20 runtime log | `a66a17d20551b046ac733199dcac9ce82d4ed0ee08214327a8a7ccc7667d9949` |

## Disposition

R149 adds one legal Matrix/CNM Protection/reset point with an accepted Matrix output prefix. It changes only UVM sequence coverage and the regression gate; product RTL and SPEC are unchanged. `REQ-CL-017/018/019/027` and `REQ-PC-006/007` remain `PARTIAL` because other legal engines, faults, phases, reset points, response profiles and backpressure combinations remain unclosed. The overall table remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
