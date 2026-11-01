# Compute Cluster functional testpoint coverage replay — R166

**Review date:** 2026-11-02  
**Result:** PASS for the declared functional covergroups and directed testpoint bins in the campaigns below. This is not full requirement closure.  
**Exact clean-worktree candidate:** 8be88c10f131354fd7aeacfd3678bb08ed439e23  
**Candidate tree:** f5411eb9bad967e1feb6f933dcc12174b4034df1  
**Product baseline:** c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413, SPEC v1.8. No RTL, SPEC, UVM source, or build target was changed for this R166 evidence replay; the exact candidate is a documentation-only descendant of the R164 test content.

## Run matrix

| Run ID | Scope and run inputs | Evidence / disposition |
|---|---|---|
| R166-SUBSYSTEM-COVERAGE-15VDB-20261102 | 3 baseline seeds (12345, 987654, 20261014), RREADY stall profiles 16/64/300 (seeds 20261097/98/99), plus three seeds 20261025/26/27 each for Banked Reset, Core/Banked Contention, and Core/Banked Reset | 15 same-source run VDBs; URG reports 17/17 declared DMA/SPAD/CNM functional groups at 100.00%. |
| R166-CLUSTER-UVM-3S-20261102 | Real top, all seven production engines, seeds 20261025/26/27 | Three runs PASS, severity 0/0/0. cluster_cg is 64/64 and all 9 Compute Cluster sequence-level groups are 100.00%. |
| R166-MIXED-E2E-16S-20261102 | Existing mixed-precision DDR/AXI E2E coverage target; 16 fixed seeds from 20261014 through 20261027 as enumerated in the command/output | All target checks PASS; E2E, DMA error-position, AXI responder gap/stall, descriptor/layout, FP16/BF16 length and reset functional points are covered. |
| R166-TOP-URG-MERGE-21VDB-20261102 | Same tb_ai_accel_uvm design and exact source SHA; two compile databases, three Compute Cluster run VDBs, and sixteen mixed E2E run VDBs | URG reports 18/18 top-level functional groups at 100.00% aggregate/group score. The two UVM RAL assertions without attempts remain uncovered and disclosed. |

The 17 subsystem group names are dma_cmd_cg, dma_cnm_shared_reset_cg, dma_rready_stall_cg, banked_core_contention_cg, cnm_dma_error_overlap_cg, cnm_dma_write_abort_cg, cnm_gemv_shape_cg, banked_reset_epoch_cg, cnm_dma_abort_overlap_cg, banked_core_reset_epoch_cg, cnm_reset_phase_cg, dma_reset_phase_cg, arbiter_cg, cnm_parity_abort_reset_cg, cnm_protection_source_cg, cnm_parity_contention_cg, and cnm_parity_dma_abort_cg.

The 18 same-top groups are ai_axil_coverage::cg, dma_error_position_cg, ai_axi4_coverage::cg, ai_mixed_precision_e2e_coverage::e2e_cg, ai_compute_cluster_coverage::cluster_cg, matrix_cnm_shared_reset_cg, engine_protection_reset_cg, fp16_abort_zero_prefix_cg, matrix_protection_cnm_reset_cg, matrix_protection_reset_cg, matrix_cnm_prefix_reset_cg, cnm_protection_matrix_prefix_reset_cg, sfu_reset_prefix_cg, scalar_reset_prefix_cg, axi_write_data_gap_cg, axi_awready_stall_cg, axi_read_response_gap_cg, and axi_arready_stall_cg. The AXI4 and AXI-Lite groups have a URG group score of 100.00; URG does not provide an instance score for those two groups in this merge.

## Assertion and run diagnostics

- 34 simulation logs across the four campaigns have PASS markers and UVM severity 0/0/0.
- The subsystem merged assertion report has 31 entries: 29 real successes, zero failures, zero incomplete, and two without attempts. Both no-attempt entries are UVM RAL do_read/do_write internals.
- The same-top Compute Cluster + DDR/AXI merged assertion report has 22 entries: 20 real successes, zero failures, zero incomplete, and the same two UVM RAL internals without attempts. All three AXI stall cover properties matched.
- Both top compile logs have no Warning-, Error-, or TFIPC diagnostics.
- The Compute Cluster run marker reports focused_compute_cg_applicable=100.0% per seed and completion-read as N/A with zero samples; the separate top-level URG group cluster_cg is 64/64.

## Commands

Run from the detached clean worktree at the exact candidate SHA. The host is WSL2; the installed Synopsys VCS package provides linux64 binaries. To use its standard wrappers without changing the global installation, the campaign used a temporary VCS_HOME alias under /tmp whose linux path points to the installed linux64 directory, with VCS_ARCH_OVERRIDE=linux. VCS reports V-2023.12-SP1_Full64; URG reports V-2023.12-SP1; UVM is 1.2. The subsystem `coverage/` path was a symlink to `/tmp/nmaforge_r166_subsystem_cov_8be88c1/coverage`, so generated databases stayed outside the worktree.

~~~bash
# From dv/subsystem/dma_spad/sim; coverage/ is the /tmp symlink described above.
export VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux
make subsystem_regress VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  COV_TAG=r166_8be88c1 SEEDS='12345 987654 20261014' SIMV=simv_r166 \
  COV_DIR='/tmp/nmaforge_r166_subsystem_cov_8be88c1/coverage/dma_spad_subsystem_test_r166_8be88c1_seed$(SEED).vdb' \
  RUN_LOG='/tmp/nmaforge_r166_subsystem_cov_8be88c1/logs/dma_spad_subsystem_test_seed$(SEED).log' \
  COMPILE_LOG='/tmp/nmaforge_r166_subsystem_cov_8be88c1/logs/compile_dma_spad_subsystem_test_seed$(SEED).log' \
  URG_REPORT=/tmp/nmaforge_r166_subsystem_cov_8be88c1/urg_baseline_3seed

make subsystem_rready_stress VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  RREADY_STRESS_TAG=r166_8be88c1_rready

# The three banked targets used these explicit /tmp output paths and seeds.
make subsystem_banked_reset_regress VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  BANKED_RESET_SEEDS='20261025 20261026 20261027' BANKED_RESET_OUT=/tmp/nmaforge_r166_subsystem_cov_8be88c1/banked_reset
make subsystem_banked_contention_regress VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  BANKED_CONTENTION_SEEDS='20261025 20261026 20261027' BANKED_CONTENTION_OUT=/tmp/nmaforge_r166_subsystem_cov_8be88c1/banked_contention
make subsystem_banked_core_reset_regress VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  BANKED_CORE_RESET_SEEDS='20261025 20261026 20261027' BANKED_CORE_RESET_OUT=/tmp/nmaforge_r166_subsystem_cov_8be88c1/banked_core_reset

# From dv/uvm/sim; VCS_ARCH_OVERRIDE=linux is exported in the environment.
make uvm_compute_cluster_regress VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r166_cluster_cov_8be88c1 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
make uvm_mixed_precision_ddr_e2e_cov_regress VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r166_mixed_cov_8be88c1
~~~

The final URG merges and all per-run VDBs/logs are retained in /tmp/nmaforge_r166_subsystem_cov_8be88c1, /tmp/nmaforge_r166_cluster_cov_8be88c1, and /tmp/nmaforge_r166_mixed_cov_8be88c1. The logs-only archive is /tmp/nmaforge_r166_testpoint_evidence_8be88c1.tar.gz (SHA-256 7a9f8cd745629be7e3644d22a5502c8cc80734b981039bc762d404b879aab6ca); its MANIFEST.sha256 hashes all included files.

## Closure boundary

The named functional coverage target for these declared groups is complete at this candidate SHA: 17/17 subsystem groups and 18/18 same-top groups are 100.00%. This does not establish 100% RTL line/condition/FSM/branch/toggle coverage, exhaust every legal requester × fault × phase × reset/backpressure combination, or close every row in the 38-requirement RTM. The enabled-profile Matrix FSM remains 49/53 with the four residual transitions dispositioned as recorded in R154/R165. REQ-PC-006, REQ-PC-007, REQ-CL-018, and other affected requirements remain PARTIAL where their broader scenario obligations are open. The current disposition remains 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 remains HOLD.
