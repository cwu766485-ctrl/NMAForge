# Scalar CMDQ GEMV/GEMM Dispatch — R127

**Date:** 2026-10-31
**Run ID:** R127-SCALAR-CMDQ-GEMV-GEMM-3S-20261031
**Executed local test SHA:** 0b68ad884fa35f4f9b858953ffa5f3513fc124b4
**Published test-content SHA:** d9aae22f8a885a4075258a9ca8c27dbaa79bb80d
**Tree:** e1334264bb8962ed2d508affb0d273d89b6650ed (identical locally and remotely)
**Product RTL/SPEC identity:** R99 product baseline c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413; SPEC v1.8 unchanged. R127 changes only the UVM sequence and regression gate, with no product RTL or SPEC change.
**Tools:** Synopsys VCS V-2023.12-SP1_Full64; URG V-2023.12-SP1.

## Testpoint

The real top accepts two sequential CMDQ descriptors for Scalar INT8 GEMV opcode 0x11 and GEMM opcode 0x12. A passive launch monitor checks opcode order, engine 0, source/destination addresses, M/N/K fields, two launches, and no same-engine relaunch while busy. The sequence checks both completions and six result words against an independently calculated signed K=2 Golden: two GEMV outputs and four GEMM outputs.

The default three-seed regression now requires the exact pass marker and output-count check for this point in every seed. This prevents the new dispatch scenario from silently leaving the regular regression.

## Commands and results

VCS/URG command:

    make -C dv/uvm/sim uvm_compute_cluster_regress       COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r127_scalar_dispatch_20261031       COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

All three seeds pass. Each has one R127 pass marker, 2/2 checked completions, 6/6 Golden-matched output words, 33,312 scoreboard writes, and 41,832 checked memory words. Scoreboard mismatches, unknown reads, stale-epoch responses, and orphan responses are all zero. UVM warning/error/fatal is 0/0/0 on each seed. The compile log contains no Warning-, Error-, or TFIPC diagnostics.

| Seed | R127 dispatch point | Checked words | Mismatch / unknown / stale / orphan | UVM warning/error/fatal |
|---|---|---:|---:|---:|
| 20261025 | PASS | 41,832 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |
| 20261026 | PASS | 41,832 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |
| 20261027 | PASS | 41,832 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |

URG merges the three seed databases. The declared focused Compute Cluster functional group cluster_cg is 100%; this is scoped to its declared bins and does not represent whole-design functional or code coverage. The merged assertion report has 17/22 properties with real successes and zero failures/incomplete. Three top AXI properties have attempts but no real success in this compute-only workload; two UVM RAL internal properties have no attempts. The AR/AW stall cover properties are unhit and the W stall cover matches three times. These workload limitations remain explicit; separate AXI workload evidence is retained in its own reports.

## Top Smoke

Command:

    make -C dv/subsystem/top_smoke/sim ai_smoke       VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs       AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261025

PASS. The mapper precheck reports 86 descriptors and 60 tensors; the simulation log ends with TEST PASS. The existing compile diagnostic LOOP-REROLL-ENABLED remains present in the Top Smoke compile log.

## Evidence artifacts

Raw outputs are under /tmp and are not committed. SHA-256:

| Artifact | SHA-256 |
|---|---|
| UVM compile.log | bd45dbd539c0857e44a3f20eba392410884d3ed8e07e7e0d1dcb52cd1fd03ef5 |
| Seed 20261025 run.log | b842c23ed58be528f49c9394196470b48a3de7243224bb99991bfbdba688fbee |
| Seed 20261026 run.log | 4246ccb3b0c049d73a3022178af7d0b7529469c8de9ba5f816c95a0fdfd54196 |
| Seed 20261027 run.log | c430a49d16dde8eb131cd0783536970d6318814c5b44a353f186a34f1eb8dccd |
| URG merged.log | 12d9cf9bc66346b1ec6b0e9b853b0ca7bb613300d807be54c3fcdd12a70a97ea |
| URG dashboard.txt | bf27fd6ec1b329fa22d58c32e861c4a20c5f76ef619f35544ae4fd6b012c8434 |
| URG groups.txt | cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f |
| URG asserts.txt | b4a80875312b61dbe23160c48a4ffe0ba0a512608ff51422a4ba9bf5d0c4e9ca |
| Top Smoke ai_comp.log | f6d65fa485383c21808b76fa681e5dc7ce960ebed5f1c05437d9f9e3a82813b9 |
| Top Smoke ai_accel_smoke.log | 6a973a3c2faad809d821c14c0ac464e60918da85a943c667eaf46bbda2e7e8da |

## Requirement impact

R127 adds one real CMDQ-to-Scalar dispatch and numeric point to REQ-CL-002, REQ-CL-015, and REQ-CL-020. Those requirements remain PARTIAL: dispatch coverage does not span all supported opcodes/engines/shapes, and this small K=2 point does not close the complete numeric, descriptor-boundary, or fault domain. The 38-row disposition remains 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 remains HOLD.
