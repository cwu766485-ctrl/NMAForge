# A10 V2 CP full-width completion-payload replay

## Identity and environment

- Exact source commit: `cd506056961f5401ad2cc425fd2cfbc38376030f`.
- Detached worktree: `/tmp/nmaforge_clean_cd50605_cp_payload_20261019`.
- Rocky Linux 8.10 / WSL2; VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.
- Artifacts: `/tmp/nmaforge_a10_cd50605_cp_payload_20261019/`.
- The source worktree was clean before and after the campaigns; no VCS,
  simulator, or URG process remained at final audit.

## Verification-only change

The CP `CP_HIGH_PAYLOAD` scenario now generates seeded 32-bit
`compute_result`, `compute_cycles`, and `compute_elements` values with
`$urandom()`. Its checker compares these held input values against the event
outputs, completion-start payload, and completion SPAD words 2 and 3. The
Makefile accepts and checks the emitted eight-hex-digit payload marker.

This exercises the existing endpoint-to-completion forwarding contract. It
does not change product RTL, SPEC, ABI, queue depth, or descriptor semantics.

## Focused seed reproducibility

```sh
make -C dv/block/command_processor/uvm compile OUT=/tmp/nmaforge_a10_cp_random_payload_focused_20261019 VCS='vcs -licwait 1'
cd /tmp/nmaforge_a10_cp_random_payload_focused_20261019
./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=20262021 +CP_ONLY_CASE=31 -l focused_1.log
./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=20262021 +CP_ONLY_CASE=31 -l focused_2.log
./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=20262022 +CP_ONLY_CASE=31 -l focused_3.log
```

The exact-SHA focused binary was then run with those same three seed choices.
All runs had UVM warning/error/fatal=`0/0/0`. The repeated seed reproduced
`result=b7fe9e44 cycles=4eefbe30 elements=ee75269c`; seed `20262022` produced
`result=6aa8a9ff cycles=9e1eaaa2 elements=a9aca629`.

## Exact-SHA 200-seed UVM/URG campaign

```sh
make -C dv/block/command_processor/uvm cov-random-regress OUT=/tmp/nmaforge_a10_cd50605_cp_payload_20261019/random RANDOM_SEED_START=20262021 RANDOM_SEED_COUNT=200 VCS='vcs -licwait 1' URG=urg
```

All 200 logs and VDBs were present. Every seed passed all 32 scenario markers,
emitted a full-width payload marker, and reported UVM warning/error/fatal
`0/0/0`. There were 200 unique values for each of result, cycles, and elements.
The Makefile's coverage gates passed: `cp_cg` 63/63 variables and 34/34
crosses; high-payload 1/1; reset-word 4/4; kind×delay×reset 24/24; abort timing
7/7.

URG assertion summary: 13 successful, 0 failed, 0 incomplete; two unattempted
properties are UVM RAL internal `do_read`/`do_write`. Cover properties: 4/4.
The 15 raw CP condition outcomes remain Not Covered in URG and retain their
existing formal/assume-guarantee disposition without waivers.

## Matched raw-toggle comparison and integration checks

The prior exact-main CP 200-seed run at `2f991dd` used the same seed range and
fixed completion payload. With only the CP UVM payload stimulus/checker
changed, the DUT raw toggle coverage changed as follows:

| DUT module | Before (`2f991dd`) | After (`cd50605`) | Change |
|---|---:|---:|---:|
| `ai_command_processor` | 13.21% | 16.10% | +2.89 percentage points |
| `ai_completion_writer` | 41.81% | 50.43% | +8.62 percentage points |

This is a coverage/activity stimulus comparison, not a PPA or power result.
The CP raw line/condition/FSM-transition/branch results remain
100.00/94.05/100.00/100.00%; toggle and broader project coverage review remain
open.

The same clean source replay passed:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke SEED=20261019
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261019
```

Both printed `TEST PASS`. VCS compile output had no `Warning-` or `Error-`
diagnostics. The bridge log contained one terminal-geometry message
(`your 131072x1 screen size is bogus`); it was not a VCS/URG diagnostic and
did not affect any test or coverage gate.

This closes reproducibility for this selected CP payload-forwarding slice; it
does not close V2, V5, or A10.
