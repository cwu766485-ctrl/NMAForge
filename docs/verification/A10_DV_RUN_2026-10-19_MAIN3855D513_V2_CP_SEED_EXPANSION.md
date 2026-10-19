# A10 V2 Command Processor seed expansion — 2026-10-19

## Scope and source

- Exact pushed `main` SHA: `3855d513614782b14163e4a59c2be266b1c65998`.
- Detached clean worktree: `/tmp/nmaforge_clean_3855d51_v2cp_seedexp_20261019`.
- Artifacts: `/tmp/nmaforge_a10_main3855d51_v2cp_seedexp_20261019`.
- Rocky Linux 8.10; VCS/URG `V-2023.12-SP1_Full64`.
- This was a verification-only replay; no RTL, UVM source, SPEC, or ABI was changed.

## Commands

```sh
make -C dv/block/command_processor/uvm cov-regress \
  OUT=/tmp/nmaforge_a10_main3855d51_v2cp_seedexp_20261019/cp \
  COV_OUT=/tmp/nmaforge_a10_main3855d51_v2cp_seedexp_20261019/cp/coverage \
  SEEDS='20262014 20262015 20262016 20262017 20262018 20262019 20262020' \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

make -C dv/block/command_processor/uvm check-coverage \
  COV_OUT=/tmp/nmaforge_a10_main3855d51_v2cp_seedexp_20261019/cp/coverage

make -C dv/subsystem/top_smoke/sim ai_smoke
```

## Results

- Seven seeds × 24 configured mixed profiles passed: **168/168**. Every run
  reported `scenario_bins=31/31` and a `[CP/MIXED]` pass marker; UVM
  warning/error/fatal counts were `0/0/0` in all 168 logs.
- URG functional groups: `cp_cg` 61/61 variables and 34/34 crosses;
  `cp_mixed_reset_words` 4/4; `cp_mixed_kind_delay_reset_cross` 24/24;
  `abort_timing_cg` 7/7. The explicit Makefile `check-coverage` gate passed.
- Assertions: 13 successes, 0 failures, 0 incomplete, 2 without attempts;
  the two no-attempts are UVM RAL `do_read`/`do_write` internals. All 4/4
  cover properties matched.
- Top-level `ai_smoke` printed `TEST PASS`.
- The isolated worktree was clean before and after; source-checkout status was
  unchanged, and the final process audit found no active VCS/URG/simv process.

## Evidence boundary

This adds more exact-SHA repetitions of the existing CP mixed-profile suite;
it strengthens reproducibility, but does not add new scenario definitions or
close the full V2 lifecycle. The CP UVM environment models descriptor-fetch
and DMA endpoints; the real command processor, completion writer, and tile
scheduler are exercised. The 15 raw CP condition outcomes remain uncovered in
URG but have the existing assume/guarantee and formal disposition documented
in [A10_DV_RTM](A10_DV_RTM.md#2026-10-18-cp-completion-availability-condition-disposition),
without waivers or rewritten bins. Raw toggle coverage, broader lifecycle
interactions, and full V2/A10/V5 closure remain open.

## Artifact index

- `cp_driver.log`
- `cp/coverage/run_<seed>_mixed_<profile>.log` (168 logs)
- `cp/coverage/urg_merged/grpinfo.txt`, `asserts.txt`, `modinfo.txt`
- `cp/coverage/urg_merge.log`, `cp_check_coverage.log`, `top_smoke.log`
- `worktree_status_before.txt`, `worktree_status_after.txt`,
  `source_status_before.txt`, `source_status_after.txt`
