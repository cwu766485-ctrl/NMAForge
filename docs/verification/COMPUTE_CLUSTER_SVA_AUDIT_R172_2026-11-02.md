# Compute Cluster AXI SVA / TFIPC Audit — R172

**Date:** 2026-11-02
**Disposition:** Focused audit PASS; no requirement disposition promoted.
**Exact published RTL/test SHA:** `8a2d5f85add54f81019df1a8d6a29ad08bbe88d6`
**Tree:** `9701bcaa7417c0cb7babdeab4996d6714cbbf04f`
**Tools:** Synopsys VCS/URG `V-2023.12-SP1`; UVM 1.2.

## Scope

This audit checks the UVM top-level AXI master SVA port connections, compile diagnostics, assertion non-vacuity, and the declared AXI/mixed-precision functional coverage. It is an AXI DMA/behavioral-memory testbench result. It does not close the production compute requester × fault × phase × SPAD reset/backpressure cross, does not qualify arbitrary external fabric behavior, and does not alter the Compute Cluster sign-off decision.

## Commands and results

From the clean published source tree:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/uvm/sim uvm_compute_cluster_compile \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r171_audit_compile
```

**PASS:** elaboration completed with 0 errors and 0 warnings. No `TFIPC`, `Warning-`, or `Error-` diagnostic was present. In `dv/uvm/tb/tb_ai_accel_uvm.sv`, all AXI master SVA ports are explicitly connected to the matching `axi4.*` interface signals.

The focused one-seed check also passes:

```sh
cd dv/uvm/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make uvm_mixed_precision_ddr_e2e_axi_stalls
```

It observes AR/AW/W stall-to-accept SVA matches `14/5/12`, respectively, and UVM severity `0/0/0`.

The 16-seed coverage target passes with an explicit seed list:

```sh
cd dv/uvm/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r172_axi_sva_cov \
  MIXED_E2E_COV_SEEDS='20261101 20261102 20261103 20261104 20261105 20261106 20261107 20261108 20261109 20261110 20261111 20261112 20261113 20261114 20261115 20261116'
```

The Make target's functional-group and SVA gates all pass. In the merged URG report:

- 8/8 workload-applicable groups are 100%: mixed E2E, AXI-Lite, AXI4, DMA error position, ARREADY, AWREADY, read-response-gap, and write-data-gap.
- The unrelated Compute Cluster `cluster_cg` is 17.76% in this mixed-precision workload. This is a different workload from the R171 Compute Cluster run, which reports its own `cluster_cg` 64/64. Neither result is combined into a global 100% claim.
- All five top AXI master assertions have real successes, with zero failures and zero incomplete attempts. The three AR/AW/W stall-to-accept cover properties all match: `179/68/137`.
- Overall URG assertions show 20/22 successes, zero failures/incomplete, and two UVM RAL internal properties without attempts. Those two no-attempt properties remain visible and are not waived as AXI checker evidence.
- The merged group score is 90.86% because `cluster_cg` is outside this mixed workload's scope; it is not a global coverage score.

## Evidence and limits

All generated databases and logs remain outside Git. Full 16-seed logs, per-seed coverage VDBs, compile log, URG reports, focused stall run log, and checksums are archived at `/tmp/nmaforge_r172_sva_audit.tar.gz` (SHA-256 `93118dceef83dc298b9b590aaab19c130211c43cfff2f54c4c26cca79ab6c333`). The archive's text evidence checksum list is `/tmp/nmaforge_r172_sva_audit/MANIFEST.sha256`.

The Compute Cluster RTM remains **24 `PASS-SCOPED` / 14 `PARTIAL`**, and `CL-DV-v1.0` remains **HOLD**. R172 closes the requested compile/SVA connectivity and named AXI non-vacuity review for this workload only. Production engine fault ownership, full fault × phase × reset coverage, and other partial requirements remain open.
