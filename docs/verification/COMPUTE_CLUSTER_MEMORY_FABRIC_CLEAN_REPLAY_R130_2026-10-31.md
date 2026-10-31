# Compute Cluster Memory Fabric Clean Replay — R130

**Date:** 2026-10-31  
**Selected target:** in-repository `ai_accel_memory_fabric`, production `ai_spad_arbiter`, registered four-bank SPAD, and the named reset/owner harnesses.  
**Clean source candidate:** local commit `e01ca2d8018c201552951179bc46729d1d6b8c98`, tree `3d905d0afe2bd934936a389576ee35dbd70a3f51`. The published review branch points to `f660754aaf531ba7d0075f16029a866d68cae717` with the same tree.  
**Tools:** VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

This is a clean-worktree replay of the selected fabric evidence on the latest published source tree after R129. It changes no RTL, SPEC, testbench, or build files. All four regressions used fixed seeds `20261025`, `20261026`, and `20261027`; all seed logs passed the Make target's UVM severity gate (`0/0/0`).

## Executed regressions

| Run ID | Target and exact command | Result |
|---|---|---|
| `CL-MEM-FABRIC-RESET-R130-3S` | `make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r130_fabric_reset_e01ca2d_20261031 MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Reset with accepted DMA and CNM SPAD work pending; both CNM reset phases; DMA/CNM fresh-work recovery. Declared reset groups: 3/3 at 100%. |
| `CL-BANKED-RESET-R130-3S` | `make -C dv/subsystem/dma_spad/sim subsystem_banked_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_RESET_OUT=/tmp/nmaforge_r130_banked_reset_e01ca2d_20261031 BANKED_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Flush accepted banked response, four-cycle post-reset quiet window, tagged four-bank recovery. Focused group: 100%; `ap_banked_response_tag`: 450 attempts, 3 real successes, 0 failures/incomplete. |
| `CL-BANKED-CONTENTION-R130-3S` | `make -C dv/subsystem/dma_spad/sim subsystem_banked_contention_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_CONTENTION_OUT=/tmp/nmaforge_r130_banked_contention_e01ca2d_20261031 BANKED_CONTENTION_SEEDS='20261025 20261026 20261027'` | PASS. Simultaneous Core/Banked requests through production arbitration; owner isolation and initialized-memory Golden checks. Focused group: 100%; Core and Banked response-tag assertions each have 3 real successes and 0 failures/incomplete. |
| `CL-BANKED-CORE-RESET-R130-3S` | `make -C dv/subsystem/dma_spad/sim subsystem_banked_core_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_CORE_RESET_OUT=/tmp/nmaforge_r130_banked_core_reset_e01ca2d_20261031 BANKED_CORE_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Check Core ownership while a Banked response is pending, reset flush, quiet window, and dual-owner Golden recovery. Focused group: 100%; Core tag `471/3`, Banked tag `471/3`, single-owner `471/441` attempts/successes, all with 0 failures/incomplete. |

Fabric reset owner assertions on the R130 run have real successes: `ap_cnm_response_tag` 3,969 attempts/144 successes and `ap_single_response_owner` 3,969/3,921, each with 0 failures/incomplete. The separate banked reset/contention/reset tests each record non-vacuous banked owner successes.

## Artifact hashes

The VCS and URG artifacts remain outside Git under the four `/tmp/nmaforge_r130_*_e01ca2d_20261031` roots.

| Run | Compile log SHA-256 | Seed logs SHA-256 (`20261025 / 20261026 / 20261027`) | URG dashboard / groups / assertions SHA-256 |
|---|---|---|---|
| Fabric reset | `52c0004e9f7a66285678a419c41af1b8e3e564dc2034e9dd9a9991f0b58444c1` | `830d996519d4be5662ef2f8310f43a32c6aca9bf197bbf0a4bf65f2ac7ed5ece` / `ded56746d44a9d6ef08ad221c6a8b1e9f3fdfb1d8d6de64dd6ff50cf939c96d4` / `8029c9901e15cb4de85ec15bd8f44cea7d875ddd9f0c82251ec3060007f39e61` | `ba5467b174e5f58e4409debcfef3009edfba7a18e19f4e0cebea43e66143ac9e` / `bae883e0154ca4590d44f1fdaf8bf21f829118f5abe2c0a039054bbbe57a1fcf` / `a7008899b3b3dca8c844e165c675f4cf7ca9621e2353c11b93987da09f55067c` |
| Banked reset | `d384affdcce11e5bad6862a47bf57815b320639c10ccd7b2ac504438427c0881` | `ac24357df69720e306a4c7a6362b891418df1bc59655b8466bbb33510a2453cf` / `adc04592fb8bba48571d0c3668e8f9b54cfc4b562600f4611f247fa1ee48a9f8` / `c01b4e0d5de6c278db4f960bbf457a324f8c1756031de990ffed59ca31b843f2` | `68e55228186facade148f05b57884b05e943d16707f9ab384bed24e227c37ce6` / `aef3f4867ae844bb4aa15985ebf1a6c8f021b1e8ac58e4a1ca1fb651816e1b83` / `0f640e079e194365c8ab1b2f5fed390b7e931b8a383cbb89ad0fb513f9fd50bf` |
| Banked contention | `9a3968f9eb48d0348e68cac3cac0e91fab60dc69f6dd9a82288eeb14423d9243` | `9b60faf128529f7acb9d1630e70cad5596a97c1cb93d753b0b1a26352730f056` / `6e9c48c98b7e69ea8ed842eecdaa206d37b295ac9d49172fdd2976d0c24e62d7` / `24fb6c4cc886e13c0c3e4ed36c20b6d4aebaea12274a137405f8f124544c5562` | `09984295a636e510841e2d29a5275148a5e51d57f195aad80b3fd012a700495c` / `2755e7703ea2ce4e04f1299d36a3a1aa1e089c667c7178fec9c18f94a46bb061` / `4fb97246c5674eb13822e5b90c163f0090bbeaaf49ea8bd64afe785e6587b0d7` |
| Core/Banked reset | `6c1b3a467326299ec07b4ce88101e89fc07d8fb8153d2a518ad80a03f48e04d2` | `96036a454c4037bfb4e977e46839dfeea87801c7c1a5d16694482e8959fbaa9f` / `2af60ae99d5d439147c303aa4c8153a04ca2913b38c8b1c90f4fb84eb68ad9bd` / `3ebe667112164e54862af3232e28f56fb275cea2322d0e35090f7d5a5a8cfbbf` | `4c4a1c03061e58f8708ea80ef987fcac703f5ed703690ada13108d1767f9999e` / `e84a2771fb2cdc87019ca1bf909fc7fd5cfaa299c0e152c3cc985b2450393c0c` / `2d641ccbd9b8d7860ca5698f4a207b7e85346d6b4725ebd6db921416dc6354a8` |

## Sign-off effect

This replay confirms the user's selected **in-repository `ai_accel_memory_fabric`** reset/epoch and the named banked ownership points on the current published source tree. It does not qualify an arbitrary external AXI fabric, production Matrix-engine banked contention, or the full production requester × fault × backpressure × reset matrix. `OPEN-CL-003` remains closed for the selected repository target; `REQ-CL-018`, `REQ-PC-007`, and broader `CL-COV-002/006` remain PARTIAL. The 38-row disposition remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.
