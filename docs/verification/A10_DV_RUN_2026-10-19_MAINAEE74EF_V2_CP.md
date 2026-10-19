# A10 V2 Command Processor exact-SHA replay — 2026-10-19

## Result

On pushed `main` SHA `aee74ef95463705724a34ed48feeeb70dcbb25cc`, the selected
Command Processor mixed-error/abort/reset and tile-recovery coverage campaign
passed on a detached clean worktree. The top-level `ai_smoke` also passed on
the same source snapshot. This is reproducible evidence for the exercised V2
slice; it does **not** close all V2 requirements or the A10 plan.

## Environment and commands

- Rocky Linux 8.10 / VCS and URG `V-2023.12-SP1`.
- Detached worktree: `/tmp/nmaforge_clean_aee74ef_v2cp_20261019`.
- Artifacts: `/tmp/nmaforge_a10_mainaee74ef_v2cp_20261019`.
- Worktree status was clean before and after the runs.

```sh
make -C dv/block/command_processor/uvm cov-regress \
  OUT=/tmp/nmaforge_a10_mainaee74ef_v2cp_20261019/cp \
  COV_OUT=/tmp/nmaforge_a10_mainaee74ef_v2cp_20261019/cp/coverage \
  SEEDS='20262011 20262012 20262013' \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

make -C dv/subsystem/top_smoke/sim ai_smoke
```

## Evidence

- CP coverage regression: 72/72 runs passed (three seeds across the configured
  24 mixed profiles); all logs reported `scenario_bins=31/31`, and all had
  UVM warning/error/fatal counts `0/0/0`.
- URG functional coverage gates: `cp_cg` 61/61 variables and 34/34 crosses;
  reset-word coverage 4/4; mixed-kind × abort-delay × reset-word cross 24/24;
  abort timing 7/7.
- Assertions: 13 successful, 0 failed, 0 incomplete; two UVM RAL internal
  read/write properties were not attempted. All four cover properties matched.
  The 13 successes comprise 12 CP/completion-facing properties and one UVM
  component-name check.
- DUT raw code coverage:
  - `ai_command_processor`: line 250/250 (100%); condition 237/252 (94.05%);
    FSM 6/6 states and 13/13 transitions; branch 67/67.
  - `ai_completion_writer`: line 39/39; condition 4/4; FSM 3/3 states and
    4/4 transitions; branch 12/12.
- Toggle coverage remains a residual rather than a closure claim:
  `ai_command_processor` 715/6614 bits (10.81%); `ai_completion_writer`
  212/696 bits (30.46%). These percentages include wide ports and depend on
  the activity exercised by this campaign.
- Top smoke log ended with `TEST PASS`; the tested reset-recovery checks also
  passed.

## Closure boundary

The 15 `ai_command_processor` condition outcomes remain raw-uncovered in URG,
but have the assume/guarantee and formal disposition now recorded in the
[A10 RTM](A10_DV_RTM.md#2026-10-18-cp-completion-availability-condition-disposition),
without waivers or rewritten bins. Raw toggle residuals remain open. The run does not establish complete
CMDQ/CPLQ lifecycle, all descriptor/dependency/error combinations, full V2
coverage closure, or V5 closure. No RTL, testbench, SPEC, or ABI changes were
made for this replay.
