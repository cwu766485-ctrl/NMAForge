# Compute Cluster Combined Functional Coverage — R219

**Date:** 2026-11-03  
**Fixed RTL/UVM source SHA:** `09f9d31209fdcc803ec322cf3822bd51e763665a`  
**Source tree:** `9778101254417c7272c37d8177e319e70849c8b4`  
**Run ID:** `R219-COMBINED-FUNCTIONAL-COVERAGE-19S-20261103`  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`

## Result

The combined URG database contains 19 passing runs from the same RTL/UVM source tree: three real-top Compute Cluster runs (`20261025/26/27`) and the full 16-seed mixed-precision DDR/AXI E2E coverage sweep (`20261014`, `712345`, `987654`, and `20261015` through `20261027`). All 26 declared functional covergroups in `groups.txt` are at 100.00% (26/26). The mixed E2E target also checks its 20 required coverpoints individually (ordering/layout, banks, descriptor validation, FP16/BF16 K values and their cross, AXI gaps, error position, resets, recovery, watchdog, abort, and end-to-end completion); the target exits nonzero if any point is incomplete. The run logs report zero UVM warning, error, or fatal. The Compute Cluster Memory Image checks total 217,536 words across three seeds with zero mismatch, unknown, stale, or orphan responses; the response-owner ledgers drain without route/data/error mismatch. The 16 mixed E2E runs check another 2,384 words with zero mismatch/unknown/stale reads.

This is 100% of the **declared functional covergroups in this merged test plan**. URG raw RTL coverage remains line 73.95%, condition 69.39%, FSM 46.69%, and branch 64.95%. Do not interpret group closure as 100% code coverage or as closure of all 38 RTM requirements.

| Metric | Result |
|---|---:|
| Merged tests | 19 |
| Declared functional covergroups at goal | 26 / 26 (100%) |
| Raw line / condition / FSM / branch | 73.95% / 69.39% / 46.69% / 64.95% |
| Assertion properties with successes | 20 / 22 |
| Assertion failures / incomplete | 0 / 0 |
| UVM RAL internal assertions without attempts | 2 |
| AXI stall cover properties matched | 3 / 3 |

The two no-attempt assertions are internal `uvm_reg_map::do_read` and `uvm_reg_map::do_write` properties. They are listed as such in `asserts.txt`; they are not counted as successful design assertions. All three AXI AR/AW/W stall-to-accept cover properties have matches. Both VCS compile logs end with zero errors and warnings and contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Reproduction

The mixed E2E sweep was executed with the checked-in 16-seed target, including its per-seed pass-marker, scoreboard, SVA, functional-bin, and zero-UVM-severity checks:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r219_mixed_e2e_cov_20261103
```

The Compute Cluster input is the three-seed `uvm_compute_cluster_regress` at the same RTL/UVM source SHA, archived under `/tmp/nmaforge_r218_compute_cluster_20261103`. The merged URG report was produced from the compile-time database and all 19 per-seed VDBs; exact inputs and tool command are recorded in `urg/dashboard.txt` and `urg/tests.txt` inside the evidence archive.

The logs-only archive includes both compile logs, all 19 per-seed run logs, URG dashboard/group/assertion/test reports, and a per-file SHA-256 manifest. It excludes executables, VDBs, and generated compiler directories:

- Archive: `/tmp/nmaforge_r219_combined_functional_coverage_evidence_20261103.tar.gz`
- Archive SHA-256: `dd08cb9027150aa17cf27f2ed61a7eefbb005d90104188c21463d1341b59de0c`
- Manifest SHA-256: `465b406a53bbebaf1b2fe5c6b46a301d55415a2faad7f61f22da845fd659aee9`

## Sign-off impact and remaining work

The latest 38-row RTM audit remains 24 `PASS-SCOPED` and 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. R219 closes the named functional group bins in this merged test plan, but it does not close the remaining requirement clauses: Matrix transfer/descriptor contract boundaries, complete legal fault × phase × reset × backpressure combinations, and selected numeric/ownership scenarios still require requirement-level evidence and review. Matrix raw FSM coverage remains profile-dependent (49/53 in the enabled configuration); formally justified and separately covered dispositions remain in the existing FSM reports. No unreachable or illegal transition was stimulated to increase coverage.

No product RTL or DV source changed for R219; this is test/review evidence on the fixed source SHA above. This result is not ASIC PPA evidence and does not claim a TinyNPU performance comparison.
