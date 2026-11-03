# Mixed Precision DDR/AXI Clean Replay — R282

## Result

The 16-seed mixed-precision DDR/AXI UVM coverage regression passed on VCS
`V-2023.12-SP1_Full64`. All seeds passed the FP16/BF16/INT8 DDR oracle checks,
descriptor validator cases, DMA SLVERR-position checks, reset/recovery,
watchdog, and software-abort lifecycle checks. No UVM errors or fatals were
reported.

This is a replay of existing testpoints, not a new coverage closure. The
named mixed-E2E, DMA error-position, and four AXI transaction covergroups are
100%; the wider `cluster_cg` is 17.76% in this focused workload, leaving the
overall URG group score at 90.86%. URG has 20/22 assertion properties with
real successes, zero failures/incomplete, two UVM RAL internal properties
without attempts, and all three AXI stall covers matched. These workload
metrics do not imply 100% requirement or DUT code coverage. The 38-row RTM
remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Identity and evidence

| Item | Value |
|---|---|
| Test ID | `TC-CL-R282-MIXED-DDR-AXI-E2E` |
| Run ID | `R282-MIXED-E2E-16S-20261104` |
| Executed local commit / tree | `1b4f77b64b92e1521b576f77b4602cb959b756ee` / `c2fd480e5455805270bd8b8ac89fe41a06c222e0` |
| Published source/test candidate | `487794dfa2d931391fd5ac82f16626b7c6f878e5` / `c01a4e15f4f72ca120aa5e7d41094173c011f9ea` |
| Source/test relationship | `git diff` between the two commits contains documentation paths only; `rtl`, `dv`, `tools`, and `Makefile` are identical. |
| VCS / URG | `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |
| Seeds | `20261014`, `712345`, `987654`, `20261015`–`20261027` |
| Coverage archive | `/tmp/nmaforge_r282_mixed_e2e_16s_logs_20261104.tar.gz` |
| Archive SHA-256 | `58dd3e2c917972bb5b162ab3bb988fe04af4478140e55ede4a71e29e6f9ec5f0` |

The archive contains all 16 seed logs, the VCS compile log, merged URG
`groups.txt`, `grpinfo.txt`, `asserts.txt`, `tests.txt`, `dashboard.txt`, and
the merge log. It excludes simulator databases and generated executables.

## Command and results

Executed from `/tmp/nmaforge_r278_rrbanked_clean`:

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r282_mixed_e2e_16s \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

| Check | Result |
|---|---|
| Seed runs | 16/16 pass; each reports `UVM_ERROR=0`, `UVM_FATAL=0`, and `MIXED_E2E_PASS`. |
| Declared testpoint dimensions | Order/layout, four SPAD banks, six descriptor-validator bins, FP16/BF16 K=1..4, and all 16 length pairs pass. |
| Targeted functional coverage | Mixed E2E, DMA error position, AXI read-address stall, write-address stall, write-data gap, and read-response gap groups are each 100%. AXI-Lite and AXI4 transaction groups also report 100%. |
| Assertions | 20/22 with real successes; zero failures/incomplete. The two no-attempt properties are UVM RAL `do_read`/`do_write` internals. |
| AXI stall covers | AR 166, AW 70, W 123 matches. |
| Broader coverage disclosure | `cluster_cg` 17.76%; merged hierarchy line/condition/FSM/branch is 51.66/44.40/9.74/40.45%. These are not requirement sign-off metrics. |
| Compilation | No `Warning-`, `Error-`, or `[TFIPC]` diagnostics in the VCS compile log. |

No RTL or testbench files were changed for this replay. No RTM disposition is
promoted.
