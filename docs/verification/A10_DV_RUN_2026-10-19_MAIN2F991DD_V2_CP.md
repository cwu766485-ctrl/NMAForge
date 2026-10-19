# A10 V2 Command Processor replay at exact pushed `main`

## Identity and environment

- Exact pushed `main` SHA: `2f991dd55ff885c4034faf7d7da773804e62ca58`.
- Detached worktree: `/tmp/nmaforge_clean_2f991dd_v2cp_20261019`.
- Rocky Linux 8.10 / WSL2; VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.
- Artifacts: `/tmp/nmaforge_a10_main2f991dd_v2cp_20261019/`.
- The worktree was clean before and after both campaigns; no VCS, simulator,
  or URG process remained at final audit.

This replay uses the current checked-in CP UVM package and Makefile at the
exact pushed SHA. It is block-level CP evidence, not a full top-level lifecycle
or A10/V5 signoff claim.

## 3-seed × 24-profile mixed error/abort/reset matrix

```sh
make -C dv/block/command_processor/uvm cov-regress \
  OUT=/tmp/nmaforge_a10_main2f991dd_v2cp_20261019/mixed \
  SEEDS='20261019 20261020 20261021' \
  VCS='vcs -licwait 1' URG=urg
```

The checked-in Makefile ran all 24 `MIXED_COV_CASES` for each seed. All 72
logs passed `check-log`, including the command-ring, completion writer,
macro-descriptor, fetch/decode/compute error, abort, reset, high-payload,
protection and recovery markers. Each log reported `scenario_bins=32/32` and
UVM warning/error/fatal=`0/0/0`. URG passed the Makefile's `cp_cg` gate at
63/63 variables and 34/34 crosses; high-payload 1/1, mixed reset words 4/4,
kind×delay×reset 24/24, and abort timing 7/7.

## 200-seed random campaign

```sh
make -C dv/block/command_processor/uvm cov-random-regress \
  OUT=/tmp/nmaforge_a10_main2f991dd_v2cp_20261019/random \
  RANDOM_SEED_START=20262021 RANDOM_SEED_COUNT=200 \
  VCS='vcs -licwait 1' URG=urg
```

All 200 logs and VDBs were present; every seed had `scenario_bins=32/32`,
UVM warning/error/fatal=`0/0/0`, and passed the Makefile severity and URG
coverage gates. The merged random URG again reached `cp_cg` 63/63 variables
+ 34/34 crosses, high-payload 1/1, reset words 4/4, kind×delay×reset 24/24,
and abort timing 7/7. Assertions: 13 successful, 0 failed, 0 incomplete; two
UVM RAL internal properties were not attempted. Cover properties: 4/4
matched.

## Raw DUT coverage and top-level checks

From the CP random campaign's `urg_random_merged/modinfo.txt`:

| DUT module | Line | Condition | Toggle | FSM transitions | Branch |
|---|---:|---:|---:|---:|---:|
| `ai_command_processor` | 100.00% | 94.05% | 13.21% | 100.00% | 100.00% |
| `ai_completion_writer` | 100.00% | 100.00% | 41.81% | 100.00% | 100.00% |

CP condition coverage is 237/252; the 15 raw `Not Covered` outcomes remain
unwaived, with their existing formal/assume-guarantee notes in the A10 RTM.
The 200-seed expansion did not improve the bit-level toggle residuals; these
remain real V5 coverage-review work, not functional failures.

The same exact-SHA worktree also passed:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke SEED=20261019
make -C dv/subsystem/top_smoke/sim ai_run \
  AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261019
```

Both printed `TEST PASS`. The regressions changed no RTL, SPEC, or ABI, and all
build/simulation/coverage artifacts remained outside Git under `/tmp`.

This closes exact-main reproducibility for the selected current CP matrix and
random slices. CP residual toggle/condition review and overall V2/V5/A10
requirement closure remain open.
