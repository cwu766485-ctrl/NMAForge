# Compute Cluster Clean Closeout Replay — R135

**Replay metadata**

- Date: 2026-10-31
- Run ID: `R135-PUBLISHED-CLOSEOUT-CLEAN-REPLAY-20261031`
- Published candidate: GitHub commit `486a348c021fe629ebc8198fd555a02a836643e3`
- Executed clean checkout: local commit `d5a3c9058ddc8215d9903f8506c1bf2668315fc7`
- Common tree: `a2e3aafe29262b9237c97d7f4d90e4a9f22e118b`
- Tool: VCS/URG `V-2023.12-SP1`; test seeds `20261025`, `20261026`, `20261027`.

The executed detached worktree is byte-identical by Git tree to the published closeout commit. The replay made no RTL, SPEC, testbench, or build changes. Build, run, and URG outputs remain outside the repository under `/tmp` except ignored Top Smoke outputs in the temporary clean worktree.

## Executed tests

| Run ID | Exact command | Result |
|---|---|---|
| `R135-TOP-SMOKE-486A` | `make -C /tmp/nmaforge_r135_clean_486a/dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345 AI_CLUSTER_COV_RUN=/tmp/nmaforge_r135_top_smoke_486a_20261031` | PASS. Mapper precheck: 86 descriptors / 60 tensors; VCS ends with `TEST PASS`. Existing fixture compile diagnostic `[LOOP-REROLL-ENABLED]` remains; VCS reports no compile errors. |
| `R135-CLUSTER-UVM-3S-486A` | `make -C /tmp/nmaforge_r135_clean_486a/dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r135_cluster_uvm_486a_20261031 COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | PASS on all three seeds; `COMPUTE_CLUSTER_REAL_UVM_PASS`, UVM warning/error/fatal `0/0/0`, applicable focused compute coverage `100.0%`. Real Matrix/CNM parallel GEMV and response tags, four-bank Golden, prefetch, queued SFU work, all-engine Abort/Reset recovery are exercised. |
| `R135-MEM-FABRIC-RESET-3S-486A` | `make -C /tmp/nmaforge_r135_clean_486a/dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r135_fabric_reset_486a_20261031 MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Selected in-repository `ai_accel_memory_fabric`: accepted DMA/CNM SPAD work, reset epoch flush, partial DMA read reset, both CNM reset phases, and fresh DMA/CNM recovery. Declared reset groups 3/3 (100%). |
| `R135-BANKED-RESET-3S-486A` | `make -C /tmp/nmaforge_r135_clean_486a/dv/subsystem/dma_spad/sim subsystem_banked_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_RESET_OUT=/tmp/nmaforge_r135_banked_reset_486a_20261031 BANKED_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Accepted banked response is flushed across reset; stale response is suppressed and tag-3 four-bank Golden recovery passes. Focused epoch group 100%; `ap_banked_response_tag`: 450 attempts, 3 real successes, 0 failures/incomplete. |
| `R135-BANKED-CONTENTION-3S-486A` | `make -C /tmp/nmaforge_r135_clean_486a/dv/subsystem/dma_spad/sim subsystem_banked_contention_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_CONTENTION_OUT=/tmp/nmaforge_r135_banked_contention_486a_20261031 BANKED_CONTENTION_SEEDS='20261025 20261026 20261027'` | PASS. Simultaneous scalar/Core and banked requests are serialized by the production arbiter; owner and Golden data are checked. Focused contention group 100%; Core/Banked response tags each have 3 real successes, 0 failures/incomplete. |
| `R135-BANKED-CORE-RESET-3S-486A` | `make -C /tmp/nmaforge_r135_clean_486a/dv/subsystem/dma_spad/sim subsystem_banked_core_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_CORE_RESET_OUT=/tmp/nmaforge_r135_banked_core_reset_486a_20261031 BANKED_CORE_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Concurrent Core/Banked owner response, reset flush, quiet window, and dual-owner Golden recovery pass. Focused group 100%; Core tag `471/3`, Banked tag `471/3`, single-owner `471/441` attempts/real successes, with 0 failures/incomplete. |

All four memory-fabric targets reported UVM severity `0/0/0` on every seed. The fabric reset URG report has 3,969 attempts, 144 real successes for `ap_cnm_response_tag`, and 3,969/3,921 attempts/successes for `ap_single_response_owner`; both have 0 failures/incomplete.

## Coverage and checker disposition

The UVM run's declared applicable focused compute functional group is 100%. The merged raw URG coverage is **not** 100%: score 55.92%; line 69.27%; condition 63.10%; FSM 41.91%; branch 59.51%; assertion real-success score 72.00%; group score 29.72%. Do not use the focused functional-bin result as a whole-design code-coverage or sign-off claim. `CPLQ` read response remains N/A for the write-only completion writer. The previously identified compute-only AXI and UVM RAL no-attempt properties remain outside this replay's workload.

The response-owner assertions above are non-vacuous with real successes. The replay closes reproducibility of the selected repository `ai_accel_memory_fabric` reset/epoch and named banked owner/reset testpoints at the published closeout tree. It does not close production-engine × fault × phase × reset/backpressure coverage, all Matrix FSM transitions, or all requirement clauses.

## Artifact SHA-256

Raw simulation and URG artifacts are retained outside Git at the paths in the commands above.

| Artifact | SHA-256 |
|---|---|
| Top Smoke `ai_accel_smoke.log` | `8acf163c992dcf4402b73bf6b10510fc8e67786a6de5ba08425b3c53c8f37af6` |
| Top Smoke `ai_comp.log` | `5e61b6384df970c2450d07255029e450b7c700273bbd3f51dfe1b74c51fd85f8` |
| Cluster UVM compile log | `b1ff051fa8f47d506db901c1922af6d27d5928be52808758597c7c488e387f3e` |
| Cluster UVM seed `20261025 / 20261026 / 20261027` | `6ea5630ec7a401030d7550bee01e40cc0840351a6e48e2648b399561b23c0d27` / `94d651e62a49c1540860ec6df347cbffd2873a9d8bcccf5a9c221e78d9cf77b6` / `4c689f432bb1a7886d32723daf26800408a434bd2d4a02c0d2ae666d0076e858` |
| Cluster URG dashboard / assertions / groups / merge log | `8039b6c88f621431ba847389c8b02d178b4da218023ff677ce554068a29cd8de` / `313b1ca31056481997a13dcb159c1fe3ca856c5759ed8940823ed4a6a82ffda5` / `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` / `d8005c93aae89584c73b51052726a778e30595617e2aea846206029cb0625e70` |
| Fabric reset compile log | `d2562656e3cf4419dd33648af60e0275ce308b315c3694471879482eec1cbac8` |
| Banked reset / contention / Core-reset compile logs | `032df76ed21627acbdae12e135ec0b6acf60368f35db8545233f6e1124a7cb40` / `f80f12db35e3430a21b8d59798fbe377eeb89d1e6bbefc09bcd2d6e507777079` / `d53c2ea27e2fa049a64ab393729cd7ac297f3f7dced686baa3e08d1c204852b0` |
| Fabric reset seed logs `20261025 / 20261026 / 20261027` | `f0daf9b6199c543c4f1c8bf8b8978ad1bcdb8976af8e219455ebed8f3b3f32ca` / `f213e192769f1f7fe92870663a86bd7a695bd7de7100ae09013a357ff4bacc5f` / `94e05cbb0fb40ed5e69a6b297a0bd0611cda397f9d8ae12fe3aef1b5a8e090ea` |
| Banked reset seed logs `20261025 / 20261026 / 20261027` | `942408412da88be03891b8ac87246476eae04afbf1983df74691e1994958dce8` / `943a103f02225b6567cac35ae4f593ddbb48d7d84e31a2c3aecf666316e310f1` / `af2567c76bc7ee825a22a45ef6f48938ef6f7f93112fd224b8e2d92ac8cba4e5` |
| Contention seed logs `20261025 / 20261026 / 20261027` | `86e4d570e734457c60c5b1c6e87d7626f91ee32db3c2289d94512d8d4212859b` / `1512af29f7c0b9ed83b27b53191b244f73fe43dfd7317d0714d7a5653f2460f1` / `5956c28d2e0e8d400d9dce6cbc284ec42e2ad8123531f97bfc7ec4af07b1a523` |
| Core/Banked reset seed logs `20261025 / 20261026 / 20261027` | `d7ad648e7d8554370aa45d66b3481267a1d72672a74cc39c2a07748f2a4b4c24` / `7450571e5e5cfa138a70c5a452b5625571a7240e0b713a60af162bafb2690848` / `dfefdc1eae5546527883105a9a2e62de357bec9ce60d234b22cd9a00a69db9c2` |
| URG dashboards: fabric reset / banked reset / contention / Core-reset | `f06b00a63d8ec6046bdfb267176fac2d77bb8f0f4332a9cfe5cf1297e373e2a8` / `b4aa95dec007974060ec58128c8220abf1be492c921c2e29838a23452c4f7489` / `517f1a838aa89b4a278239657bf6ec16c77fda6552bac88900a75a31009fa5dd` / `2d2727bc38d6ec8b1e397297d35608932c73c30b03aadfa75e7b260db82ee991` |
| URG owner assertions: fabric reset / banked reset / contention / Core-reset | `34bca941ccce64d01bec5c7f11b055630716458aed343126146586112d87c2a3` / `d05c13192470e47c7dd1c1642c9f5961503f015e1568257a4ab0271e5aea478e` / `4a9f8099162507b80642e764c88e5651d80279aba9711eb242e917872edd491b` / `8cf2eeaa46a88e986249fa94cb2f97a181aefb2abc743c7593326db5b3ac2de8` |

## Sign-off effect

R135 updates the clean-replay identity and confirms the named runs on the published closeout tree. `OPEN-CL-003` remains closed for the user-selected in-repository fabric. Requirement totals do not change: 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**. Production requester/fault/phase/backpressure combinations, complete legal FSM disposition, remaining functional requirement clauses, 64×64/GEMV benchmark breadth, measured common-memory RTL comparison, and candidate PPA remain open or separately scoped.
