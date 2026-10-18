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

This closes only the targeted completion-availability condition disposition.
Other CP raw condition/toggle misses, broader fault×abort×reset interactions,
full V2 lifecycle closure, global coverage disposition, fixed-SHA clean
replay, and A10/V5 remain open.
