# A10 DV Run — Command Processor Decode Busy-Hold Follow-up

**Date:** 2026-10-18

**Tested tree:** worktree based on pushed `main` `2317abb` (not a clean-checkout replay)

**Tools:** Rocky Linux 8.10 / Synopsys VCS and URG `V-2023.12-SP1_Full64`

## Scope

This testbench-only increment addresses two CP stimulus/checking issues:

1. The macro-child decode-abort sequence now waits for the parent fetch response
   to be consumed, then waits for the child fetch request and response before
   asserting abort. This synchronizes the test with the child `ST_DECODE`
   lifecycle rather than relying on the parent's fetch event.
2. `CP_SUBMIT_GUARD` now holds `compute_busy=1` for two cycles after a valid
   descriptor reaches `ST_DECODE`. It checks that launch/fetch/completion/SPAD
   write/event side effects and queue-pointer movement remain absent, then
   releases busy and checks exactly one launch, completion, and queue retirement.

No DUT RTL, specification, register ABI, or product behavior was changed.

## Commands and results

Focused macro-child decode-abort replay passed with UVM warning/error/fatal
`0/0/0`:

```sh
make -C dv/block/command_processor/uvm compile \
  OUT=/tmp/nmaforge_cp_child_decode_abort_20261018_replay1 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
cd /tmp/nmaforge_cp_child_decode_abort_20261018_replay1
./simv +UVM_TESTNAME=ai_cp_test +CP_ONLY_CASE=22 \
  +ntb_random_seed=20261018 -l child_decode_abort.log
```

Focused decode busy hold/resume passed with UVM warning/error/fatal `0/0/0`:

```sh
make -C dv/block/command_processor/uvm compile \
  OUT=/tmp/nmaforge_cp_decode_busy_focus_20261018_r2 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
cd /tmp/nmaforge_cp_decode_busy_focus_20261018_r2
./simv +UVM_TESTNAME=ai_cp_test +CP_ONLY_CASE=27 \
  +ntb_random_seed=20261018 -l focused.log
```

Full CP suite passed: scenario bins `31/31`, UVM warning/error/fatal `0/0/0`.

```sh
make -C dv/block/command_processor/uvm run \
  OUT=/tmp/nmaforge_cp_decode_busy_full_20261018 SEED=20261018 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

The three-seed × 24-profile URG campaign passed `72/72` run logs; every profile
passed the `31/31` scenario-bin gate, and no profile had nonzero UVM severity.
Merged results:

- CP line: `250/250` (100%).
- CP condition: `229/252` (90.87%); 23 condition outcomes remain for review.
- CP FSM: `6/6` states and `13/13` transitions (100%).
- CP branch: `67/67` (100%); the `ST_DECODE` compute-busy hold outcome is now
  exercised.
- Functional coverage: `cp_cg` 61/61 variables and 34/34 crosses; mixed reset
  words 4/4; kind × delay × reset 24/24; abort timing 7/7.
- Assertions: 13 successes, 0 failures, 0 incomplete; 2 no-attempt properties
  are UVM RAL internals. Four cover properties matched.

```sh
make -C dv/block/command_processor/uvm cov-regress \
  OUT=/tmp/nmaforge_cp_decode_busy_cov_20261018 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Top-level smoke passed and printed `TEST PASS`:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke
```

## Limits and next work

The 23 remaining raw condition outcomes have not been fully classified as
unreachable, untested, or instrumentation-sensitive; they are not waived by
the 100% branch result. Two UVM RAL properties had no attempts. This run closes
only the exercised CP decode busy-hold and macro-child decode-abort stimulus
slice. Descriptor-fetch integration, broader queue producer/consumer traffic,
V2 lifecycle closure, and A10/V5 acceptance remain open. This is shared
worktree evidence, not a frozen-commit or clean-checkout replay.
