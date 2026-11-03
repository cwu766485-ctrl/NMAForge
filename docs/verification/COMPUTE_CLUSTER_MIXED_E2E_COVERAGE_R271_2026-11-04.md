# Mixed-Precision DDR/AXI Coverage Replay — R271

## Result and scope

R271 passes the 16-seed mixed-precision DDR/AXI end-to-end coverage regression on the published closeout source tree. It supplements current AXI protocol, reset/epoch, and mixed-format execution evidence. It does not close every external-fabric contract or the remaining 11 PARTIAL requirements; `CL-DV-v1.0` remains **HOLD**.

## Reproducible identity

| Item | Value |
|---|---|
| Published closeout HEAD | `fbce080dea40581cbe11132fb67c152fa5fad03a` |
| Published source tree | `344201fbca00ad2494fbe5974d3c81f7951d4a6f` |
| Executed local commit | `3a9c89e9bd4e313a247a2db9811520563ce0d4f9` |
| Executed source tree | `344201fbca00ad2494fbe5974d3c81f7951d4a6f` |
| Run ID | `R271-MIXED-E2E-COV-FBCE080-20261104` |
| Seeds | `20261014`, `712345`, `987654`, `20261015`–`20261027` (16 total) |
| Test | `ai_mixed_precision_ddr_e2e_test` |
| Simulator / coverage | Synopsys VCS and URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |

The executed local commit and published HEAD have identical Git trees. The local checkout was clean; this records exact published source content rather than claiming the run process checked out the published commit object itself.

## Checks and results

- All 16 seeds pass the mixed-precision DDR/AXI E2E test with UVM warning/error/fatal `0/0/0`.
- The Make target verifies all 16 FP16 × BF16 length pairs (`K=1..4`), all six descriptor orders and SPAD layouts, four SPAD banks, six invalid-descriptor cases, DMA first/last-beat SLVERR behavior, reset while compute and DMA are in flight, reset recovery, and FP Abort/Watchdog completion.
- The E2E functional covergroup and four per-transaction AXI groups (ARREADY, AWREADY, read-response gap, write-data gap) each report 100% for their declared bins.
- AR/AW/W payload-stability and 4 KiB-boundary assertions have nonzero real successes and zero failures/incomplete. AR/AW/W stall-to-accept covers match 166/70/123 times in the merged run. Two UVM RAL library properties have no attempts; they are not DUT assertions.
- Compile transcript contains no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.
- The unrelated Compute Cluster covergroup is only 17.76% in this mixed-E2E workload. This workload is not the seven-engine cluster coverage run and is not used to claim full Cluster coverage.

## Command

```bash
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
  make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r270_exact_fbce_mixed_cov
```

## Evidence

- Run output: `/tmp/nmaforge_r270_exact_fbce_mixed_cov`
- Logs and URG text-report archive: `/tmp/nmaforge_r271_mixed_e2e_cov_evidence.tar.gz`
- Archive SHA-256: `c60abe3fa5381b7ae19b56d623ea7c22c475636c41aa28f8e61c1ef716e6b33a`

The archive contains the VCS compile transcript, all 16 per-seed logs, and merged URG `asserts.txt`, `groups.txt`, and `grpinfo.txt`. Generated executables, VDB databases, and other generated directories are not committed.

## Current TinyNPU distance

This replay is verification evidence, not a TinyNPU comparison. The latest paired controller result remains [R259](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R259_2026-11-03.md), using TinyNPU SHA `8216c22b762011aa20c05fc2768423fd12dda59d` and the same signed INT8 vectors:

| Workload | NMAForge cycles | TinyNPU comparison endpoint | Relative result | Qualification |
|---|---:|---:|---:|---|
| 16×16×16 | 152 | 151 | NMAForge +0.7% cycles | TinyNPU endpoint includes serialized 16 B/cycle memory estimate |
| 16×16×32 | 231 | 231 | Tie | Same modeled-memory limitation |
| 32×32×64 | 1,198 | 1,305 | NMAForge −8.2% cycles | NMAForge reads 6,144 B; TinyNPU estimate is 4,096 B |

The first two shapes are effectively neck-and-neck; the largest is promising but does not establish a fair product advantage because the memory service is not matched. NMAForge's internal D4/P1/C1 versus D2/P0/C0 Matrix ablation improves the five-workload cycle sum by 24.88% and read traffic by 21.28% under the behavioral SPAD model, but that is not a TinyNPU win. A common enforced-memory RTL comparison, GEMV/decode and larger CNN workloads, and implementation PPA remain open. No ASIC timing or power result is inferred from the behavioral model.
