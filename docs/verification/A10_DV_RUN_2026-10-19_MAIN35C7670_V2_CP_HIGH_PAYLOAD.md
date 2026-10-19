# Exact-SHA CP high-payload replay — 2026-10-19

## Source and environment

The replay used pushed `main` commit
`35c7670594c85d471bad1e5a975df7f16369c78f` in a detached clean worktree:
`/tmp/nmaforge_a10_cp_sha35c7670`. Rocky Linux 8.10 / WSL2, VCS and URG
`V-2023.12-SP1_Full64`.

The Rocky bridge's login shell supplied the local VCS/license environment.
Its license preflight reported `lmstat` exit 0 and a VCS feature status,
without exposing private server settings. Two earlier direct, non-login
attempts stopped before RTL compilation: first `VCS_HOME` was unset; after
setting it, the non-login shell still lacked license variables. They are
environment setup failures, not simulation failures.

## Commands and result

Executed in the detached worktree through the reviewed Rocky bridge task:

```sh
make -C dv/block/command_processor/uvm cov-regress \
  OUT=/tmp/nmaforge_a10_cp_sha35c7670_rerun/cp \
  COV_OUT=/tmp/nmaforge_a10_cp_sha35c7670_rerun/cp/coverage \
  SEEDS='20262014 20262015 20262016 20262017 20262018 20262019 20262020' \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

make -C dv/block/command_processor/uvm check-coverage \
  COV_OUT=/tmp/nmaforge_a10_cp_sha35c7670_rerun/cp/coverage

make -C dv/subsystem/top_smoke/sim ai_smoke VCS='vcs -licwait 1'
```

All 168 profiles (7 seeds × 24 mixed error/abort/reset settings) passed.
Every log contained `scenario_bins=32/32`; no log had nonzero UVM warning,
error, or fatal counts. The merged URG gates passed:

- `cp_cg`: 63/63 variables and 34/34 crosses.
- High-payload bin 1/1; mixed reset words 4/4; kind × abort-delay × reset
  cross 24/24; abort timing 7/7.
- Assertions: 13 successes, 0 failures, 0 incomplete; the 2 no-attempt
  assertions are UVM RAL `do_read`/`do_write` internals. Cover properties:
  4/4 matches.
- `ai_smoke`: `TEST PASS`.

The CP DUT raw coverage in this run is line/condition/toggle/FSM/branch
`100.00/94.05/13.21/100.00/100.00%`; the completion writer is
`100.00/100.00/41.81/100.00/100.00%`. The low toggle values remain visible
residuals and are not waived by the functional coverage result.

The high-payload test checks the ABI-v7 INT8 VDOT descriptor (`length=ffff`,
task ID `c3a5`), launch/event payload, completion base `0x78000`, all four
completion word addresses/data (`result=3e123456`, `cycles=00010023`,
`elements=ffff`), and exactly-once tail advancement. Compute/fetch/DMA
endpoints in this CP block test remain testbench modeled.

The detached source worktree was clean after the run; the original Windows
checkout's status was unchanged. Artifacts: `/tmp/nmaforge_a10_cp_sha35c7670_rerun/`.
This proves reproducibility for this CP slice only; it does not close V2,
V5, or the full A10 plan.
