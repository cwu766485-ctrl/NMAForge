# AXI Stall-to-Accept SVA Non-Vacuity — R314

**Run ID:** `R314-AXI-SVA-NONVACUITY-CLEAN-20261104`  
**Code/test SHA:** `a88c310afbfaf3b02c3c16a5accc31c04ff379f2`  
**Git tree:** `a8a0fd314f505348bb623c43133e3da464df8718`  
**Worktree:** detached clean worktree `/tmp/nmaforge_r312_clean_a88c310`  
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`

## Reproduction

Run from `dv/uvm/sim` at the same clean SHA used by R312/R313:

```sh
make uvm_mixed_precision_ddr_e2e_axi_stalls \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The existing target enables per-transaction AXI jitter and AR/AW gaps (`2`/`3`) and checks pre-DMA and post-reset phases, actual address backpressure, all three stall-to-accept SVA cover properties, the mixed-precision DDR scoreboard, DMA reset/recovery, watchdog, and Abort.

## Results

The target passes with `[MIXED_E2E_PASS]`; UVM severity is `0/0/0`. It observes actual AR and AW address stalls. The top-level SVA summary reports:

| Cover property | Attempts | Matches |
|---|---:|---:|
| `c_ar_stall_then_accept` | 3,287 | 14 |
| `c_aw_stall_then_accept` | 3,287 | 5 |
| `c_w_stall_then_accept` | 3,287 | 12 |

Compile and run logs contain no `Warning-`, `Error-`, `[TFIPC]`, or fatal diagnostic. The R312 Cluster-only run's AR/AW zero-match output is workload-specific: that test does not enable the external AXI jitter/gap profile. R314 confirms the cover properties are bound and non-vacuous under their designated stall workload.

## Sign-off effect

This resolves the named top AXI stall-cover non-vacuity review point only. It does not close any of the 38 Compute Cluster requirements or broaden the fault × phase × reset × backpressure matrix. Disposition remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Evidence archive

Compile and run logs are archived outside Git at `/tmp/nmaforge_r314_axi_sva_clean_evidence.tar.gz` (SHA-256 `eb17d4fe471ded5864db5b3be33517399d94e7b7f8f7125f26bd254e65c68ede`). The archive README includes individual log hashes.
