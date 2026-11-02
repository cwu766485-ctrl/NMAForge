# Combined UVM Functional Coverage Replay — R183

**Date:** 2026-11-02  
**Disposition:** All declared functional covergroups in the combined UVM workload set are 100%; Compute Cluster sign-off remains HOLD.  
**Tested local SHA:** `39f54b7f72f24b3cc61a57b8ce8359807aefcc48`  
**Tree:** `d18249b5338ca8324211078f3ca10fa0abad76cc`  
**Checkout:** detached clean worktree `/tmp/nmaforge_r182_final_candidate_clean`  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`; UVM 1.2.

## Workloads and results

R183 runs the existing 16-seed mixed-precision DDR/AXI coverage target on the same candidate as the R182 three-seed Compute Cluster UVM run, then merges all 19 test VDBs. Both design databases are provided to URG because the workloads were compiled separately.

| Workload | Run ID | Seeds | Result |
|---|---|---|---|
| Compute Cluster real-top UVM | `R182-COMPUTE-CLUSTER-CLEAN-3S-20261102` | `20261025/26/27` | 3/3 pass; UVM W/E/F `0/0/0`; `cluster_cg` 64/64 |
| Mixed-precision DDR/AXI UVM | `R183-MIXED-E2E-AXI-COVERAGE-16S-20261102` | `20261101..20261116` | 16/16 pass; UVM W/E/F `0/0/0`; all target Make gates pass |
| Combined URG | `R183-COMBINED-URG-19-TESTS-20261102` | 19 test VDBs | 20/20 declared functional covergroups at 100.00%; no URG errors or warnings |

The 20 functional coverage groups are:

1. AXI-Lite coverage, DMA error position, AXI4 coverage, mixed-precision E2E coverage, and Compute Cluster `cluster_cg`.
2. `matrix_cnm_shared_reset_cg`, `engine_protection_reset_cg`, `conv_reset_prefix_cg`, `fp16_abort_zero_prefix_cg`, `matrix_protection_cnm_reset_cg`, `matrix_protection_reset_cg`, `engine_pair_overlap_cg`, `matrix_cnm_prefix_reset_cg`, `cnm_protection_matrix_prefix_reset_cg`, `sfu_reset_prefix_cg`, and `scalar_reset_prefix_cg`.
3. AXI memory `axi_write_data_gap_cg`, `axi_awready_stall_cg`, `axi_read_response_gap_cg`, and `axi_arready_stall_cg`.

The 16-seed mixed-precision target also checks all six descriptor orders/layouts, four SPAD banks, six invalid-descriptor classes, FP16/BF16 K lengths 1–4 and all 16 FP16×BF16 length pairs. Its AXI master assertion gates pass, including all three AR/AW/W stall-to-accept covers.

## Checker and code-coverage disposition

Combined assertion results are 20/22 properties with real success, zero failures and zero incomplete attempts. The two properties without attempts are UVM RAL internal `do_read` and `do_write`; they remain uncovered and are not waived. Cover properties are 3/3 matched.

The same combined URG report gives DUT/testbench mixed line/condition/FSM/branch coverage of `73.62/68.15/46.69/64.58%` and assertion coverage `92.00%`. The aggregate group score is 100.00% because every declared functional covergroup in these workloads hit its goal. It does not mean 100% RTL code/FSM coverage, nor does it close untested legal scenarios outside the groups.

The 38-requirement disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`. R183 closes no requirement and does not change `CL-DV-v1.0` **HOLD**. External AXI fabric qualification, broader engine × fault × phase × reset/backpressure crosses, outstanding ABI/descriptor dispositions, and Matrix raw enabled-profile FSM misses remain open.

## Reproduction

The 16-seed Make target:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C /tmp/nmaforge_r182_final_candidate_clean/dv/uvm/sim \
  uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r183_mixed_e2e_cov \
  MIXED_E2E_COV_SEEDS='20261101 20261102 20261103 20261104 20261105 20261106 20261107 20261108 20261109 20261110 20261111 20261112 20261113 20261114 20261115 20261116'
```

The final, warning-free cross-workload URG merge:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r182_final_candidate_uvm/compile.vdb \
       /tmp/nmaforge_r183_mixed_e2e_cov/simv_uvm.vdb \
       /tmp/nmaforge_r182_final_candidate_uvm/seed_*/coverage.vdb \
       /tmp/nmaforge_r183_mixed_e2e_cov/seed_*/coverage.vdb \
  -format text -report /tmp/nmaforge_r183_combined_urg_final \
  -log /tmp/nmaforge_r183_combined_urg_final.log
```

## Evidence archive

The archive includes both design databases, all 19 run logs/VDBs, the Make log, and the final URG report/log.

- Archive: `/tmp/nmaforge_r183_combined_coverage_evidence.tar.gz`
- Archive SHA-256: `f4fe2cba51fa819d7ed7b0af32ed298bf70d2623593628250d141139fb1297eb`
- Manifest SHA-256: `5cf35568412244a3937b365d9b0d7cc6e79bc448bd534067b4cf58417f239b9a`
- Extracted directory: `/tmp/nmaforge_r183_combined_coverage_evidence`
- R182 Top Smoke and 28/28 mutation evidence: `/tmp/nmaforge_r182_signoff_evidence.tar.gz` (SHA-256 `2f9032edb6696de21cdc23f325b2725df41aeb20dee93879f15c62e0f8e0ff52`).
