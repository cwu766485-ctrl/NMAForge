# Scalar CMDQ Numeric Boundaries — R128

**Date:** 2026-10-31
**Run ID:** R128-SCALAR-CMDQ-NUMERIC-BOUNDARY-3S-20261031
**Executed clean-worktree SHA:** dfbebbd8c8ee68458c4261f74f041e816b6b0284
**Published test-content SHA:** 0e38b482e13eefa759441ac8ed1ab3d4d6246b37
**Tree:** a5adb3db01aee36f8363eb63a67194d5078d2398 (same local and remote tree)
**Product RTL/SPEC identity:** R99 product baseline c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413; SPEC v1.8 unchanged. This is a UVM sequence and regression-gate change only.
**Tools:** Synopsys VCS V-2023.12-SP1_Full64; URG V-2023.12-SP1.

## Declared testpoint

Seven legal real-CMDQ Scalar INT8 GEMV descriptors cover the minimum supported M=1, K=1 shape. The passive launch monitor checks opcode, source/destination addresses, dimensions, shift, activation, bias address and enable. The test compares each output against an independently calculated signed 64-bit arithmetic reference, checks each completion, and requires all seven cases in the regression pass marker.

| Case | Boundary exercised | Expected output |
|---:|---|---:|
| 0 | INT32_MAX bias plus positive dot, identity, positive saturation | 0x7fffffff |
| 1 | INT32_MIN bias plus negative dot, identity, negative saturation | 0x80000000 |
| 2 | INT32_MIN bias plus positive dot, arithmetic shift 31 | 0xffffffff (-1) |
| 3 | Positive dot through ReLU | 0x0000fc04 (64,516) |
| 4 | Negative dot through ReLU | 0x00000000 |
| 5 | Positive dot through ReLU6 upper clamp | 0x00000006 |
| 6 | Negative dot through ReLU6 lower clamp | 0x00000000 |

The regression gate requires case_mask=7f, outputs=7/7, and completions=7/7 in every seed. Thus all seven declared directed testpoints are checked in each run; this is a local testpoint measure, not whole-design functional or code coverage.

## Clean-worktree regression

Checkout: /tmp/nmaforge_r128_scalar_boundary_clean_20261031/checkout, detached at the exact executed SHA above.

Command:

    make -C dv/uvm/sim uvm_compute_cluster_regress       COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r128_scalar_boundary_clean_20261031/run       COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

All seeds pass. Each run reports case_mask=7f, seven Golden outputs and seven completions; the memory scoreboard checks 41,961 words with 33,508 writes, zero mismatches, zero unknown reads, zero stale-epoch responses, and zero orphan responses. UVM warning/error/fatal is 0/0/0 for each seed. Compile log has no Warning-, Error-, or TFIPC diagnostics.

| Seed | Cases | Golden outputs / completions | Checked words | Mismatch / unknown / stale / orphan | UVM warning/error/fatal |
|---|---|---:|---:|---:|---:|
| 20261025 | 7/7 | 7/7 and 7/7 | 41,961 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |
| 20261026 | 7/7 | 7/7 and 7/7 | 41,961 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |
| 20261027 | 7/7 | 7/7 and 7/7 | 41,961 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |

URG merges the three seed databases. The declared focused Compute Cluster group cluster_cg is 100%; this is scoped to its declared bins. The merged assertion report has 17/22 properties with real successes, zero failures/incomplete, three AXI properties with attempts but no real success in this compute-only workload, and two UVM RAL internal properties without attempts. AR/AW stall cover properties are unhit; the W stall cover matches three times. Separate AXI workload evidence remains independently attributed.

## Artifact paths and hashes

Raw artifacts are outside Git under /tmp/nmaforge_r128_scalar_boundary_clean_20261031/run/.

| Artifact | SHA-256 |
|---|---|
| compile.log | 8a335e6049295fb43e20bea635364b900703065d9b57220211df8887093cc59e |
| seed_20261025/run.log | caffa7ed01eef73445fba1b3deada0858ab9af6d1f7fd17c3cca4a50e1e49dc8 |
| seed_20261026/run.log | 641b9c0ddedf19d0186bae19eb9c3fec6f9d7562e6965395b95f194f80139d6c |
| seed_20261027/run.log | 07e7480c9a6c1ae341a0ee1137bda98a1f793b0f867282362e098ab991f19954 |
| urg_merged.log | b72e65102258f5914b783bf8c517d73534477e205a293a9fd111dcd9bf5cbb05 |
| urg_merged/dashboard.txt | e97688836979c9a8167d7bd2ee2e154bfe98668d706f3ac9c0714f2115f247af |
| urg_merged/groups.txt | cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f |
| urg_merged/asserts.txt | 3058e8ce635de8f305ac4158aebb7a0244531028435340370b00b22f38f7b603 |

## Requirement impact

R128 adds one real CMDQ legal-minimum descriptor point and seven named arithmetic boundary points to REQ-CL-002, REQ-CL-015, and REQ-CL-020. Those rows remain PARTIAL: this does not sweep all opcode/engine/shape combinations, wider K/bias/shift interactions, legacy Conv, or the complete legal fault domain. The overall 38-row disposition remains 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 remains HOLD.
