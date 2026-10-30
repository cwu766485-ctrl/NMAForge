# In-Repository Memory Fabric Reset Qualification — R99

**Date:** 2026-10-30<br>
**Code/test SHA:** `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`<br>
**Target selected by the user:** `ai_accel_memory_fabric` (the on-chip banked SPAD fabric)
**Decision:** selected reset/epoch testpoints PASS; Compute Cluster v1.0 sign-off remains HOLD.

## Scope

The DMA-SPAD subsystem test instantiates the repository's production `ai_accel_memory_fabric` through `ai_accel_spad_subsystem`. The selected scope checks the registered SPAD response-owner pipeline across reset, four accepted DMA reads, CNM work interrupted at two legal phases, and fresh post-reset DMA/CNM work. The external DDR responder used by the DMA test is behavioral; this report does not qualify an arbitrary external AXI fabric.

The three reset functional groups gated by the regression are `dma_cnm_shared_reset_cg`, `cnm_reset_phase_cg`, and `dma_reset_phase_cg`. URG reports 100% for all three groups. Each of the three fixed seeds logs the pass marker, two CNM reset-recovery markers, and UVM warning/error/fatal counts of `0/0/0`.

## Test evidence

| Run ID | Exact command and result |
|---|---|
| `CL-MEM-FABRIC-RESET-R99-3S` | `cd dv/subsystem/dma_spad/sim && env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make subsystem_memory_fabric_reset_regress MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_memory_fabric_reset_r99_20261030 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg` — PASS, seeds `20261025/26/27`; functional gate `3/3 groups at 100%`. |
| `CL-SPAD-CNM-PROTECTION-R99-3S` | `cd dv/subsystem/dma_spad/sim && env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make subsystem_regress COV_TAG=cl_r100_cnm_protection_response_align SEEDS='20261025 20261026 20261027' URG_REPORT=/tmp/nmaforge_cnm_protection_align_r100_20261030/urg VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg` — PASS, all three seeds; Protection functional group reports `100.00%`, and each UVM summary is `0/0/0`. |
| `CL-TOP-SMOKE-R99` | `cd dv/subsystem/top_smoke/sim && env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make ai_smoke VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs` — PASS, `TEST PASS`. |
| `CL-TOP-SEEDED-R99` | `cd dv/subsystem/top_smoke/sim && env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs` — PASS, 20 seeded random cases and `TEST PASS`. |

Primary generated evidence is outside Git: `/tmp/nmaforge_memory_fabric_reset_r99_20261030/` and `/tmp/nmaforge_cnm_protection_align_r100_20261030/`. The exact reset seed logs are `seed_{20261025,20261026,20261027}/run.log`; the full subsystem logs are `dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_cl_r100_cnm_protection_response_align_seed{20261025,20261026,20261027}.log` in the clean checkout used for this run.

## Scenarios and checker results

- Reset with four accepted DMA reads outstanding before any response; then perform fresh DMA work and compare the 32-word memory image.
- Reset during an AXI partial-read response phase with an accepted SPAD read whose registered response has not yet returned. The checked-in test logs the observed accepted request before asserting shared reset.
- Reset after CNM operand reads have completed while result writeback is pending. Both CNM reset phases verify fresh DMA and CNM tasks after recovery.
- Verify the selected reset coverage groups at 100%, zero UVM warnings/errors/fatals, and the UVM SPAD memory scoreboard on recovery.
- The full subsystem regression additionally checks CNM out-of-range A/B sources and denied destination write. It observes `ERR_PROTECTION`, preserved destination storage, and successful clean recovery.

The reset-only URG assertion report has zero failures and incomplete attempts. In that workload `ap_single_response_owner` records 3,921 real successes and `ap_cnm_response_tag` records 144; these are the exercised properties, not a claim that every assertion in the subsystem has non-vacuous coverage. The reset-only compile includes `-assert svaext`; no `[TFIPC]` diagnostic was reported. Synopsys prints non-fatal unsupported Rocky Linux 8.10 and WSL2 kernel warnings. Top Smoke also retains its known `LOOP-REROLL-ENABLED` fixture warning.

## RTL defect found and corrected at this candidate

The first full subsystem replay on the pre-fix candidate failed 17 CNM Protection checks. `ai_spad_arbiter` raises the registered CNM response one stage after request acceptance, while `ai_accel_spad_subsystem` had registered the Protection error for only one stage. The error could therefore clear before the matching response and permit a denied operand to proceed to writeback. R99 adds a request-time Protection-error register and a second aligned response register. After this fix, the three-seed full subsystem regression checks both invalid source operands and denied destination write, returns the frozen Protection error, preserves storage, and completes recovery without UVM severity.

## Disposition

The user's selected in-repository `ai_accel_memory_fabric` reset/epoch point is qualified for the scenarios above, closing that bounded integration evidence item. `REQ-CL-018` stays PARTIAL because broader legal Engine × Fault × Phase × Reset crossings remain open. The RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains HOLD. This is functional simulation with behavioral memory models, not ASIC PPA or arbitrary external-memory-fabric qualification.
