# A10 DV Run — CP Completion Availability Condition Disposition

**Date:** 2026-10-18
**Tested tree:** local worktree based on pushed `main` `3d8ee79`
**Environment:** Rocky Linux 8.10 / VCS+URG `V-2023.12-SP1_Full64`; VC Formal `V-2023.12-SP2`

## Scope

This increment closes the review of the seven raw RTL condition sites for
`completion_required_r && completion_available` in
`rtl/control/queue/ai_command_processor.v`. It changes only verification
stimulus/checking and the formal harness; no product RTL, SPEC, register ABI,
or cycle behavior changed.

The CP UVM tests exercise the `(completion_required, completion_available) =
(1,0)` outcome at all seven sites using a full CPLQ and the legal legacy
`CMDQ_SIZE=0` compatibility submission. They check event/error ownership,
absence of completion writes/tail movement, and command-head behavior.

The remaining `(0,1)` raw tuples require changing the CPLQ size from disabled
to enabled while a queued command is active. The integrated register block
locks configuration writes while `processor_busy` is asserted. The Control
UVM busy test now writes `CPL_SIZE=4`, asserts busy, attempts to change it to 8
and requires `SLVERR`, then reads back 4. The CP formal harness models this
integration contract with `u_cp.busy |-> $stable(cplq_size)` and proves that
an active queued FETCH/DECODE or macro RUN state with an available completion
slot must have `completion_required_r=1`.

This is a compositional disposition: the register-level lock is exercised by
Control UVM, while the reservation/availability invariant is proved in the
CP+real-completion-writer formal harness under that lock contract. It is not a
whole-top formal proof. URG raw bins remain raw bins; the seven `(0,1)` outcomes
are still reported `Not Covered`, not converted to covered or excluded.

## Commands and results

### CP UVM + URG

```sh
make -C dv/block/command_processor/uvm cov-regress \
  SEEDS='20261018 20261019 20261020' \
  COV_OUT=/tmp/nmaforge_cp_completion_availability_cov_20261018 \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Result: 72/72 seed/profile runs passed, each with 31/31 scenario bins and UVM
warning/error/fatal=`0/0/0`. Merged `cp_cg` reached 61/61 variables and 34/34
crosses. CP raw condition coverage is 237/252 (94.05%). At each of lines 437,
449, 469, 481, 494, 567, and 591, URG reports `(0,1)` as `Not Covered` and
`(1,0)` as `Covered`. The remaining overall CP misses are not claimed closed
by this targeted disposition.

Artifacts:

- URG: `/tmp/nmaforge_cp_completion_availability_cov_20261018/urg_merged/`
- Campaign log: `/tmp/nmaforge_cp_completion_availability_cov_20261018.bridge.log`

### Control UVM

```sh
make -C dv/block/control/sim uvm_regress \
  VCS='vcs -licwait 1' \
  SIMV=simv_a10_cplq_busy_guard \
  COV_DIR=/tmp/nmaforge_a10_control_cplq_busy_guard_20261018/control.vdb
```

Result: all nine Control UVM tests passed. The updated
`control_busy_abort_test` checks busy-time `CPL_SIZE` write rejection and
readback stability; every test reported UVM warning/error/fatal=`0/0/0`.
Captured log: `/tmp/nmaforge_a10_control_cplq_busy_guard_20261018/make.log`.

### VC Formal

```sh
make -C dv/block/command_processor/formal completion-ownership \
  VCF=vcf \
  OUT=/tmp/nmaforge_a10_cp_completion_availability_formal_20261018
```

Result: clean setup (`No setup issues found`), 6/6 assertions proven and
non-vacuous, and 3/3 covers reached. The new
`ap_active_available_completion_was_reserved` proof is non-vacuous and safe
through depth 79. The target printed
`CP_COMPLETION_OWNERSHIP_FORMAL_PASS`. VC Formal emitted non-fatal
`COM_OPT009/COM_OPT010` messages because this RTL-only proof has no cell-library
search/link library; this is not mapped synthesis or signoff evidence.
Artifacts: `/tmp/nmaforge_a10_cp_completion_availability_formal_20261018/`.

### Top smoke

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke VCS='vcs -licwait 1'
```

Result: `TEST PASS`; the integrated descriptor-fetch ownership monitor also
reported `[CP_FETCH_DONE_OWNED] responses=56 state=ST_FETCH`.

## Disposition and remaining scope

The `(1,0)` behavior is directly exercised in CP UVM at all seven sites. The
`(0,1)` tuple is impossible during the real queued-command lifecycle under
the tested busy-time configuration lock and the non-vacuously proven CP
reservation invariant. Raw URG still records those seven condition outcomes
as unhit, which is retained transparently for coverage accounting.

### Follow-up: descriptor fetch response ownership

The CP raw condition report contained one additional miss:
`fetch_done=1` with the abort condition true while `state_r != ST_FETCH` at
the abort-pending clear expression. The formal harness now models the producer
protocol with a one-request outstanding bit and assumes `fetch_done` only for
an outstanding request (or a same-cycle `fetch_start`). It then asserts that
every such response is consumed in `ST_FETCH`.

```sh
make -C dv/block/command_processor/formal completion-ownership \
  VCF=vcf \
  OUT=/tmp/nmaforge_a10_cp_fetch_done_ownership_formal_20261018
```

VC Formal `V-2023.12-SP2` passed with clean setup, 7/7 assertions proven and
non-vacuous, and 3/3 covers reached. The new
`ap_fetch_done_owned_by_fetch_state` property was non-vacuous and safe through
depth 79. The target printed `CP_COMPLETION_OWNERSHIP_FORMAL_PASS`; artifacts
are under `/tmp/nmaforge_a10_cp_fetch_done_ownership_formal_20261018/`.
This is an assume-guarantee proof of the CP consumer under the fetch producer's
request/response contract, not a formal proof of the real descriptor fetch
implementation. The prior top-smoke integration monitor observed 56 real
`desc_done` pulses, all while the CP was in `ST_FETCH`.

The 15 CP raw condition outcomes remaining unhit in URG are now classified:
two `cmdq_size != 0 && cmdq_empty` tuples are impossible by the definition of
`cmdq_empty`; two completion-done ownership tuples, two tile busy/done
ownership tuples, one decode abort-pending tuple, seven completion-reservation
tuples, and one fetch-done ownership tuple are covered by the non-vacuous
formal properties under their stated producer/configuration contracts. The
raw CP condition score remains 237/252 (94.05%); no bin is rewritten or
excluded. CP toggle residuals, broader fault×abort×reset interactions, full
V2 lifecycle closure, global coverage disposition, and A10/V5 remain open.
The pushed `de51846` state was subsequently replayed in a clean detached
worktree: its 72-profile CP campaign, seven formal ownership assertions, and
top `ai_smoke` passed. The pinned full SHA was
`de518464a8669776073b907692908c385c8f04df`; the detached worktree was clean
before running. The exact commands were:

```sh
make -C dv/block/command_processor/uvm cov-regress \
  OUT=/tmp/nmaforge_a10_de51846_cp_replay_20261018/cp \
  COV_OUT=/tmp/nmaforge_a10_de51846_cp_replay_20261018/cp/coverage \
  SEEDS='20261083 20261084 20261085' VCS='vcs -licwait 1' URG=urg

make -C dv/block/command_processor/formal completion-ownership \
  VCF=vcf OUT=/tmp/nmaforge_a10_de51846_cp_replay_20261018/formal

make -C dv/subsystem/top_smoke/sim ai_smoke VCS='vcs -licwait 1'
```

Coverage was 61/61 variables + 34/34 crosses, formal was 7/7 assertions
proven/non-vacuous and 3/3 covers reached, and top smoke printed `TEST PASS`.
Artifacts: `/tmp/nmaforge_a10_de51846_cp_replay_20261018/`; clean worktree:
`/tmp/nmaforge_clean_de51846_20261018/`. This replay does not include the
later tile-error recovery delta below; that delta has now been independently
replayed at its own pushed SHA.

### Follow-up: tile load-DMA error propagation

Based on pushed `de51846`, the existing `CP_TILE_PINGPONG` scenario now runs
three jobs: a successful three-tile ping-pong, a two-tile job whose first load
response asserts `dma_done` and `dma_error` together with code `0xA`, then a
successful three-tile recovery job. The checker requires the failure event to
preserve code `0xA` and zero result elements, no compute launch/store or
completion-writer start during the failed job, and a subsequent successful
job after the tile scheduler is restarted. The normal ping-pong checks retain
ordered load/compute/store ownership on both buffers. Only UVM interface,
sequence/scoreboard, behavioral DMA endpoint, and Makefile acceptance checks
changed; product RTL, SPEC, register ABI, and clock behavior did not change.

The focused `CP_ONLY_CASE=15` run compiled and reported UVM
warning/error/fatal=`0/0/0`; this mode intentionally skips full-suite aggregate
markers, so final acceptance used full-suite runs:

```sh
make -C dv/block/command_processor/uvm compile \
  OUT=/tmp/nmaforge_a10_cp_tile_error_recovery_focused_20261018/build \
  VCS='vcs -licwait 1'

(cd /tmp/nmaforge_a10_cp_tile_error_recovery_focused_20261018/build && \
  ./simv +UVM_TESTNAME=ai_cp_test +CP_ONLY_CASE=15 \
    +ntb_random_seed=20261018 -l focused.log && \
  ./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=20261018 -l full.log)
make -C /mnt/e/workspace/chip/NMAForge/dv/block/command_processor/uvm \
  check-log LOG=/tmp/nmaforge_a10_cp_tile_error_recovery_focused_20261018/build/full.log

make -C dv/block/command_processor/uvm regress \
  OUT=/tmp/nmaforge_a10_cp_tile_error_recovery_regress_20261018/cp \
  SEEDS='20261018 20261019 20261020' VCS='vcs -licwait 1'

make -C dv/block/command_processor/uvm cov-regress \
  OUT=/tmp/nmaforge_a10_cp_tile_error_recovery_cov_20261018/build \
  COV_OUT=/tmp/nmaforge_a10_cp_tile_error_recovery_cov_20261018/coverage \
  SEEDS='20261018 20261019 20261020' VCS='vcs -licwait 1' URG=urg

make -C dv/subsystem/top_smoke/sim ai_smoke VCS='vcs -licwait 1'
```

Environment: Rocky Linux 8.10, VCS/URG `V-2023.12-SP1_Full64`.

Results: focused case and the single-seed full-suite run passed; the full-suite
log had scenario bins `31/31` and UVM warning/error/fatal=`0/0/0`. The 3-seed
CP regression also passed with those same zero severities in each run. Each of
the three full runs reported
`tiles=7/6/6 events=3 dma_errors=1 recovery_events=1 error_completion_starts=0`.
The 72-profile campaign (3 seeds × 24 mixed abort/reset profiles) passed every
Makefile and URG gate; all 72 logs contained that tile/recovery marker. Merged
URG `cp_cg` reached 61/61 variables and 34/34 crosses; reset-word bins were
4/4, the mixed kind×delay×reset cross was 24/24, and abort-timing coverage was
7/7. Top `ai_smoke` printed `TEST PASS`.

This closes the directed tile load-DMA error and restart-recovery slice only.
The change was pushed as `c500b3daba529d3123ffe250644f3297ae8c16f3` and then
replayed from that exact SHA in detached clean worktree
`/tmp/nmaforge_clean_c500b3d_20261018/`. The worktree was clean before and
after the replay. The replay used the 72-profile campaign with seeds
`20261021 20261022 20261023` and top smoke; all 72 profile logs contained the
tile recovery marker, `cp_cg` reached 61/61 variables + 34/34 crosses, reset
word bins were 4/4, mixed kind×delay×reset was 24/24, and abort timing was
7/7. Top `ai_smoke` printed `TEST PASS`. Artifacts:
`/tmp/nmaforge_a10_c500b3d_tile_recovery_replay_20261018/`.

CP residual code coverage, broader V2 command/completion lifecycle closure,
and A10/V5 acceptance remain open.
