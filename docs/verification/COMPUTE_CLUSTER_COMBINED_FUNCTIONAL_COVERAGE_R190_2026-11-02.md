# Compute Cluster combined declared functional coverage — R190

**Run ID:** R190-COMBINED-DECLARED-FC-19S-20261102  
**Exact source/test SHA:** 5068af69e5006fdc869d60244df0708c810cf3ea  
**Tree:** 885200c7b42bd5a13a5ea8e9331988ce3299da60  
**Published same-tree code commit:** 744d560c6402c64517fde47ca278e944e93060ef  
**Tools:** Synopsys VCS/URG V-2023.12-SP1_Full64 / V-2023.12-SP1. Product RTL/SPEC unchanged.

## Runs

The clean candidate has three Compute Cluster UVM seeds from R188 (20261025/26/27), including the required minimum Scalar VDOT CMDQ boundary marker, and 16 mixed-precision/AXI coverage seeds from R190:

    VCS_ARCH_OVERRIDE=linux make -C /tmp/nmaforge_r188_replay/dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg MIXED_E2E_COV_OUT=/tmp/nmaforge_r190_mixed_cov_clean_16seed MIXED_E2E_COV_SEEDS='20261014 712345 987654 20261015 20261016 20261017 20261018 20261019 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027'

The Make target passes all 16 seeds, including all legal descriptor order/layout permutations, FP16/BF16 K=1..4, AXI gaps and ready backpressure, reset/recovery, and first/last beat DMA error positions. Every mixed run has UVM warning/error/fatal 0/0/0.

URG merges the three R188 Compute Cluster seed databases with the 16 R190 mixed-precision/AXI seed databases. The combined report is at /tmp/nmaforge_r190_combined_19vdb/urg_merged.

## Results

| Metric | Result |
|---|---|
| Declared functional covergroups | 21/21 at 100.00% |
| Combined URG group score | 100.00% |
| Compute Cluster cluster_cg | 64/64 |
| RTL/testbench line / condition / FSM / branch | 73.70% / 68.72% / 46.69% / 64.70% |
| Assertions | 20/22 have real successes; 0 failures and 0 incomplete |
| Assertions without attempts | 2 UVM RAL internal properties |
| Cover properties | 3/3 matched |

All 21 group rows in the combined URG groups report are 100%. They include AXI4 and AXI-Lite groups, DMA error position, mixed end-to-end, Compute Cluster, sequence reset/prefix/engine-pair groups, and the four external AXI memory gap/stall groups. The top AXI AR/AW/W assertions have real successes and each stall-to-accept cover matches.

This is 100% of the declared functional covergroups for these workloads. It is not 100% RTL code coverage, does not prove every legal parameter × fault × phase × reset × backpressure cross, and does not close every requirement.

## Reproduction evidence

| Artifact | Path | SHA-256 |
|---|---|---|
| Mixed VCS compile log | /tmp/nmaforge_r190_mixed_cov_clean_16seed/compile.log | 5fedacc42f6ed3bc80fe125a2c83fb9521e044f9e0bca1d29b834873d249e488 |
| Mixed Make-target URG groups | /tmp/nmaforge_r190_mixed_cov_clean_16seed/urg_merged/groups.txt | f0fe1ce1b1da393f668a707a6b5456d931344e88965018aaa96c55a08d4e028f |
| Mixed Make-target URG log | /tmp/nmaforge_r190_mixed_cov_clean_16seed/urg_merged.log | b61e276da9acf1c80b2f7a2706aeecf907ac8beae8fa765c561e57b9d32e9ca0 |
| Combined URG groups | /tmp/nmaforge_r190_combined_19vdb/urg_merged/groups.txt | a9a560399050e97c239f5b375b0c41a82bb68bb611552b9af4d34320ef7e9d0b |
| Combined URG dashboard | /tmp/nmaforge_r190_combined_19vdb/urg_merged/dashboard.txt | 3ad72bbe7f7a33c025cba8d64b6bce70028c78faaaeafcde448ec39f56d17b31 |
| Combined URG assertions | /tmp/nmaforge_r190_combined_19vdb/urg_merged/asserts.txt | f13ba73488b157d6c3edf9d08f3f27af76569ba92ad29854c3bc60c559806e67 |
| Logs and URG evidence archive | /tmp/nmaforge_r190_combined_coverage_evidence.tar.gz | 614485d0bc1e4a5f8cee171d7b9cf3df3df60cabf126529f9a36624d4f99afea |
| Artifact manifest | /tmp/nmaforge_r190_combined_coverage_manifest.txt | 01154a640db54056911ee5f69a66056915aeccdcdf88966fce113845c44379d9 |

All 16 mixed seed logs, three R188 cluster seed logs, compiler logs and URG text reports are retained under /tmp and in the logs archive; generated VDB directories remain outside the repository. The mixed compile and URG logs contain no Warning-, Error-, TFIPC, or URG error/warning diagnostics.

## Sign-off effect

R190 meets the declared functional-group coverage target on this exact candidate and workload set. It does not change the 38-row RTM dispositions: 24 PASS-SCOPED / 14 PARTIAL. The legal Engine × Fault × Phase × Reset/backpressure residuals remain open, so CL-DV-v1.0 remains HOLD.
