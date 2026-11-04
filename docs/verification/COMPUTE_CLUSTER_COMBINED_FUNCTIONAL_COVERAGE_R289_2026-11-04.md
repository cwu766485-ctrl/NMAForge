# Compute Cluster Combined Functional Coverage — R289

## Result

On the exact published closeout candidate `de40cd24d962a1d67bd021da01b5338078c0dd5d` (tree `f7333de5b745f49796f242f2f5a5ad5e435351d5`), URG merged 19 passing UVM tests: three real-top Compute Cluster seeds and sixteen mixed-precision DDR/AXI end-to-end seeds. All **37 declared functional coverage groups are 100%**, including `cluster_cg`, engine fault/recovery, descriptor-boundary, reset-prefix, overlap, and AXI stall groups.

This closes the declared group goals exercised by these workloads. It does **not** mean 100% RTL code coverage or full Requirement closure. The merged dashboard reports line 76.19%, condition 71.43%, FSM 53.31%, branch 67.46%, assertion 92.00%, and group 100.00%. These aggregate URG figures include the testbench/UVM hierarchy; they are not DUT-only numbers. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Fixed identity and runs

| Item | Value |
|---|---|
| Published candidate | `de40cd24d962a1d67bd021da01b5338078c0dd5d` |
| Candidate tree | `f7333de5b745f49796f242f2f5a5ad5e435351d5` |
| Run ID | `R289-COMBINED-FUNCTIONAL-COVERAGE-19T-20261104` |
| Cluster test | `uvm_compute_cluster_regress`; seeds `20261025`, `20261026`, `20261027` |
| Mixed DDR/AXI test | `uvm_mixed_precision_ddr_e2e_cov_regress`; seeds `20261014`–`20261027`, `712345`, `987654` |
| VCS / URG | Synopsys `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |
| Combined tests / groups | 19 / 37; all groups 100.00% |

Every Cluster seed also passed the existing independent result and Memory Image checks: 146,755 checked words, zero mismatch/unknown/stale, and a drained response-owner ledger (10,678 accepted, 10,658 checked, 20 reset-dropped; zero route/data/error mismatch). The parity-fault-owner × unaffected-completion-owner cross reached 42/42 legal pairs per seed after Golden/checker success. UVM severity was 0/0/0. The 16-seed mixed target passed its six order/layout bins, four SPAD-bank bins, six validator bins, FP16/BF16 K=1..4 cases, and all sixteen length pairs.

## Assertions and code coverage

URG reports 20/22 assertion properties with real successful attempts, zero failures, and zero incomplete attempts. The two without attempts are UVM RAL internals (`uvm_reg_map::do_read` and `do_write`); they are recorded as unattempted, not waived. All three AXI stall-to-accept cover properties matched: AR 166, AW 70, W 126.

| Aggregate metric | Coverage |
|---|---:|
| Line | 76.19% |
| Condition | 71.43% |
| FSM | 53.31% |
| Branch | 67.46% |
| Assertion | 92.00% |
| Declared functional groups | 100.00% (37/37) |

The raw Matrix FSM result remains 49/53 in the enabled profile with its reviewed legal-profile/guard dispositions. No illegal state forcing or Requirement promotion was used to increase coverage.

## Reproduction commands

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r288_clean_published_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r288_mixed16 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir /tmp/nmaforge_r288_clean_published_uvm/compile.vdb \
       /tmp/nmaforge_r288_mixed16/simv_uvm.vdb \
       /tmp/nmaforge_r288_clean_published_uvm/seed_*/coverage.vdb \
       /tmp/nmaforge_r288_mixed16/seed_*/coverage.vdb \
  -format text -report /tmp/nmaforge_r288_combined_urg \
  -log /tmp/nmaforge_r288_combined_urg.log
```

## Evidence archive and disposition

The logs-only archive is `/tmp/nmaforge_r289_combined_functional_coverage_20261104.tar.gz`, SHA-256 `55d60ca2879dc567f2ecec97f23cdfd99ade1de8925b776646c820545706bf16`; its manifest SHA-256 is `bd0caf98ee7616dcaad733e6a884cafecaa0e13d25a7b19dbbe91ef248602f1c`. The archive includes the R288 stage logs, all sixteen mixed-seed logs, and combined URG text summaries; it excludes simulator binaries and VDB databases.

No RTM disposition changes follow from this coverage merge. Broader legal fault × phase × engine × reset/backpressure closure, the four raw Matrix transitions, descriptor contracts, and several memory/response ownership clauses remain open. See the [R288 exact published-head clean replay](COMPUTE_CLUSTER_R288_PUBLISHED_HEAD_CLEAN_REPLAY_2026-11-04.md), [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md), and [Open-Issue List](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md).
