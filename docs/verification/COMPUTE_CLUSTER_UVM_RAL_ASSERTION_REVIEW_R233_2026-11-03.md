# Compute Cluster UVM RAL Assertion Review — R233

**Date:** 2026-11-03
**Published source/test identity:** `c5755985b0e5b1e1a850122ece983a37be112272` (the tested RTL, SPEC, and DV sources are unchanged at published R232 HEAD `3259d4da158d56aebe41c227c426b6b4b74a0f72`)
**Run ID:** `R233-CONTROL-UVM-RAL-20261103`
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Run

```sh
make -C dv/block/control/sim uvm_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

All nine Control UVM tests pass with UVM warning/error/fatal counts `0/0/0`. In particular, `control_ral_access_test` performs a VERSION frontdoor read and an OP frontdoor write/read; the scoreboard reports `observed=3 okay=3 slverr=0`.

Standalone Control URG reports 8/10 properties with real successes, zero failures and zero incomplete attempts. Its seven AXI-Lite control assertions have real successes. The remaining two properties are UVM library internals, `uvm_reg_map::do_read` and `uvm_reg_map::do_write`, with zero attempts. They remain explicitly open as UVM instrumentation disposition items; this run does not count them as DUT checker passes.

URG cannot validly merge the Control testbench database into the Compute Cluster testbench database: their top-level hierarchies differ. The exploratory merge emitted `CMR-VCINF` instance-not-found warnings and ignored the Control hierarchy, so it is excluded from the R232 combined coverage result. R232's `28/28` declared Compute Cluster functional groups and its separate AXI/engine assertions remain the applicable Cluster evidence.

**Sign-off impact:** no RTM disposition changes. The 38 requirements remain `24 PASS-SCOPED / 14 PARTIAL`; `CL-DV-v1.0` remains **HOLD**. No UVM library or product RTL was modified.

## Evidence

Text logs and standalone Control URG reports are archived at `/tmp/nmaforge_r233_control_ral_evidence_20261103.tar.gz`, SHA-256 `729621a006ba360fc91aa00fb3f83bcdd11726117c6988400338081dfeb1078e`. The archive contains the compile log, nine per-test logs, URG text reports, and a SHA-256 manifest; it excludes VCS binaries, `csrc`, waveforms, and coverage databases.
