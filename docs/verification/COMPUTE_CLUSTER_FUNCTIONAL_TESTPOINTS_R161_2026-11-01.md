# Compute Cluster declared DMA/SPAD/CNM functional testpoint replay — R161

**Result:** PASS for the 17 declared DMA/SPAD/CNM subsystem functional covergroups on the R160 source tree. This is not whole-Cluster requirement closure; REQ-PC-006/007 remain PARTIAL and CL-DV-v1.0 remains HOLD.

## Frozen source and execution

- Exact source commit: 34e0e55c6d1300388aec2f1645e1053cf35225bc
- Source tree: 451b66ed5c820ebade584fe261de43c3c8d2cdc9
- Worktree: /tmp/nmaforge_r160_subsystem_cov_34e0
- Tool: Synopsys VCS/URG V-2023.12-SP1_Full64, UVM 1.2
- UVM severity: 0/0/0 for all 15 runs

The source tree is the exact R160 tree, including its direction-aware real-top request-stability gate. No RTL or SPEC changes were made for this replay.

## Requirement trace and results

| Requirement | Disposition | Test ID / Checker | Result | Run ID / Seeds | Evidence |
|---|---|---|---|---|---|
| REQ-PC-006 | PARTIAL | TC-PC-R161-DMA-SPAD-BASE, TC-PC-R161-RREADY-STRESS; DMA scoreboard, SPAD image checker, accepted-request/response ledger | Three baseline scenarios plus 16/64/300-cycle RREADY stall profiles pass. These directed subsystem transactions add evidence but do not cover every production requester × fault × backpressure case. | R161-SUBSYSTEM-BASE-3S: 12345/987654/20261014; R161-RREADY: 20261097/20261098/20261099 | /tmp/nmaforge_r160_subsystem_cov_34e0/evidence_v1/default/, rready/ |
| REQ-PC-007 | PARTIAL | TC-PC-R161-BANKED-RESET, TC-PC-R161-BANKED-CONTENTION, TC-PC-R161-BANKED-CORE-RESET; production fabric grant/response owner assertions and Golden bank-data checker | Core/Banked contention and response ownership pass; reset flushes the outstanding Banked response, quiet windows hold, and both owners recover. Clients are testbench-driven at the production fabric boundary; this does not substitute for production Matrix-engine traffic. | R161-BANKED-RESET, R161-BANKED-CONTENTION, R161-BANKED-CORE-RESET; each seeds 20261025/26/27 | /tmp/nmaforge_r160_subsystem_cov_34e0/evidence_v1/banked_*/ |
| REQ-CL-018 | PARTIAL | banked_reset_epoch_cg, banked_core_reset_epoch_cg; quiet-window, response-tag, reset-ledger and recovery checkers | Both declared reset groups hit 100%; SVA owner-tag properties have real successes and zero failures/incomplete. The wider production engine × fault × phase × reset matrix remains open. | R161 Banked Reset and Banked Core Reset; 20261025/26/27 | Same report and logs |

R161 runs five existing targets and merges their 15 same-tree coverage databases: three baseline subsystem seeds, three RREADY stall profiles, and three seeds each for Banked Reset, Core/Banked Contention, and Core/Banked Reset.

## Functional coverage and assertions

URG reports **17/17 declared DMA/SPAD/CNM functional covergroups at 100.00%**:

dma_cmd_cg, dma_cnm_shared_reset_cg, dma_rready_stall_cg, banked_core_contention_cg, cnm_dma_error_overlap_cg, cnm_dma_write_abort_cg, cnm_gemv_shape_cg, banked_reset_epoch_cg, cnm_dma_abort_overlap_cg, banked_core_reset_epoch_cg, cnm_reset_phase_cg, dma_reset_phase_cg, arbiter_cg, cnm_parity_abort_reset_cg, cnm_protection_source_cg, cnm_parity_contention_cg, and cnm_parity_dma_abort_cg.

Merged assertion results: 29 real successes, zero failures and zero incomplete attempts. Two UVM RAL do_read/do_write internal properties have no attempts; they are reported as not exercised, not pass. At R160, the separate Compute Cluster group cluster_cg is 64/64. These scoped functional groups are not DUT code coverage and do not imply 100% of all Cluster Requirements or all URG groups.

The same-source subsystem runs show:

- Banked Reset: banked_reset_epoch_cg=100%; ap_banked_response_tag 450 attempts / 3 successes / 0 failures / 0 incomplete.
- Core/Banked Contention: banked_core_contention_cg=100%; ap_banked_response_tag 429 attempts / 3 successes / 0 failures / 0 incomplete.
- Core/Banked Reset: banked_core_reset_epoch_cg=100%; Core and Banked response-tag properties each 471 attempts / 3 successes; single-owner property 471 attempts / 441 successes; zero failures/incomplete.

## Commands

Run from dv/subsystem/dma_spad/sim at the exact source commit:

- make subsystem_regress VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg COV_TAG=r160_base
- make subsystem_rready_stress VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg RREADY_STRESS_TAG=r160_rready
- make subsystem_banked_reset_regress BANKED_RESET_OUT=/tmp/nmaforge_r160_subsystem_banked_reset VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
- make subsystem_banked_contention_regress BANKED_CONTENTION_OUT=/tmp/nmaforge_r160_subsystem_banked_contention VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
- make subsystem_banked_core_reset_regress BANKED_CORE_RESET_OUT=/tmp/nmaforge_r160_subsystem_banked_core_reset VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

The 15-database merge is in /tmp/nmaforge_r160_subsystem_cov_34e0/urg_merged_15. The logs-only archive has SHA-256 5fdad711f7f9abeb69f94b0a307f983b18410da84239771eb5d8b9126284fee2; the per-file manifest is /tmp/nmaforge_r160_subsystem_cov_34e0/evidence_v1/MANIFEST.sha256.

## Closure boundary

The declared subsystem functional covergroups are complete for this campaign. This does not close the 38-row RTM or convert remaining PARTIAL requirements to PASS-SCOPED. Production Matrix-engine banked contention, broader requester/fault/backpressure/reset crosses, remaining Matrix FSM/functional clauses, and other requirement-level gaps remain open. The overall disposition is still 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD.
