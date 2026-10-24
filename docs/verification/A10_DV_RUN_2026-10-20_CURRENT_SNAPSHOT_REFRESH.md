# A10 current-source verification refresh — 2026-10-20

## Scope and source identity

The pushed source snapshot tested here is `ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc`.
Its worktree was detached and clean before testing. That commit is a
documentation-only successor to the audited design/verification snapshot
`585854b6de85cd92efbbfdf681462d8d73b2c7c0`; RTL, filelists, and checked-in
test sources are identical between those two pushed commits.

Environment: Rocky Linux 8.10; VCS `V-2023.12-SP1_Full64`, URG
`V-2023.12-SP1`, VC Formal `V-2023.12-SP2`, SpyGlass
`V-2023.12-SP1`. Simulation/formal outputs are under `/tmp`; no generated
output was added to Git.

## Exact pushed-main CP replay at `ff1e3bb`

The 200-seed campaign used seeds `20262021..20262220` and output root
`/tmp/nmaforge_a10_ff1e3bb_cp_clean_20261020`.

```sh
make -C dv/block/command_processor/uvm cov-random-regress \
  OUT=/tmp/nmaforge_a10_ff1e3bb_cp_clean_20261020 \
  RANDOM_SEED_START=20262021 RANDOM_SEED_COUNT=200 \
  VCS='vcs -licwait 1' URG=urg
```

VCS compiled successfully and all 200 runs completed. The target's final URG
step returned 127 because `urg` was not on this shell's PATH; it did not fail
on simulation or coverage data. There were 200 run logs and 200 VDBs. Each
seed passed the Makefile's `check-log` markers, including 32/32 scenario bins
and UVM warning/error/fatal `0/0/0`. URG was then run from the installed path
and the repository coverage gate passed:

```sh
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir /tmp/nmaforge_a10_ff1e3bb_cp_clean_20261020/coverage/compile.vdb \
  /tmp/nmaforge_a10_ff1e3bb_cp_clean_20261020/coverage/random_seed_*.vdb \
  -format text \
  -report /tmp/nmaforge_a10_ff1e3bb_cp_clean_20261020/coverage/urg_random_merged \
  -log /tmp/nmaforge_a10_ff1e3bb_cp_clean_20261020/coverage/urg_random_merge.log

make -C dv/block/command_processor/uvm check-coverage \
  COV_OUT=/tmp/nmaforge_a10_ff1e3bb_cp_clean_20261020/coverage \
  URG_REPORT=urg_random_merged URG_LOG=urg_random_merge.log
```

URG gates passed: `cp_cg` 63/63 variables and 34/34 crosses; high-payload
1/1; mixed reset words 4/4; kind×delay×reset 24/24; abort timing 7/7.
Assertions: 13 successes, 0 failures, 0 incomplete; 2 unattempted properties
are UVM RAL internals. Covers: 4/4. DUT raw line/condition/toggle/FSM/branch
coverage was `100.00/94.05/20.77/100.00/100.00%` for
`ai_command_processor` and `100.00/100.00/65.66/100.00/100.00%` for
`ai_completion_writer`. Raw condition and toggle residuals remain open.

The same clean pushed snapshot passed:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Both logs ended with `TEST PASS`.

## Exact pushed-main V4 and V3 refreshes at `ff1e3bb`

The top-level DDR E2E random coverage campaign passed all 192 seeds
(`20261101..20261292`), with 192 logs and 192 VDBs. The E2E functional group,
four per-transaction AXI stall/back-pressure groups, and all Makefile-selected
functional coverage points passed at 100%; the Make target exited 0.

```sh
cd dv/uvm/sim
make uvm_mixed_precision_ddr_e2e_random_cov_regress \
  MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_ff1e3bb_v4_e2e_192_20261020
```

The DMA–SPAD–CNM subsystem regression passed 10/10 seeds. All run logs had
UVM warning/error/fatal `0/0/0`; the merged assertion report had 29 successes,
0 failures, 0 incomplete, and 2 UVM RAL internal properties without attempts.
The selected DMA command group was 14/14 variables + 5/5 crosses; arbiter
coverage was 5/5 variables + 6/6 crosses; CNM parity/abort/reset coverage was
4/4 variables + 2/2 crosses.

```sh
cd dv/subsystem/dma_spad/sim
make subsystem_regress \
  SEEDS='20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027 20261028 20261029' \
  COV_TAG=a10ff1e3bb20261020 \
  URG_REPORT=/tmp/nmaforge_a10_ff1e3bb_v3_dma_spad_20261020/urg \
  VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The RREADY stall campaign passed 16-, 64-, and 300-cycle back-pressure cases;
each run held the AXI R payload stable, drained DMA, and matched 32 SPAD words
to the memory oracle. All UVM severity counts were zero. Merged URG coverage
was 4/4 variables + 3/3 crosses, with 0 assertion failures/incomplete.

```sh
cd dv/subsystem/dma_spad/sim
make subsystem_rready_stress RREADY_STRESS_TAG=ff1e3bb_20261020 \
  VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The SPAD arbiter formal target passed on this source snapshot: setup clean,
8/8 non-vacuous assertions proven, and 4/4 covers reached.

```sh
env VC_STATIC_HOME=/opt/Synopsys/vc_formal/V-2023.12-SP2 \
  make -C dv/block/spad_arbiter/formal decode-invariants \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vc_static_shell \
  OUT=/tmp/nmaforge_a10_ff1e3bb_spad_arb_formal_20261020 TIMEOUT=120
```

## Current working-tree lint correction and recheck

After the pushed-SHA replay, the current worktree received one narrow RTL
change in `rtl/control/queue/ai_command_processor.v`: dependency timeout
paths now explicitly zero-extend the 16-bit event mask when passing it to the
32-bit event/completion result field. This preserves the existing unsigned
extension behavior and removes two SpyGlass `MatchFuncArgWidth` warnings.

The following post-change checks passed:

```sh
make -C dv/block/command_processor/uvm run SEED=20261020 \
  OUT=/tmp/nmaforge_cp_width_fix_20261020 VCS='vcs -licwait 1'
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

The CP run passed all 32/32 scenario bins with UVM warning/error/fatal
`0/0/0`. Both top-level runs ended with `TEST PASS`.

The full 200-seed CP random campaign was then repeated on this corrected
worktree for seeds `20262021..20262220`. All 200 logs passed the Makefile
scenario and severity gates, all 200 VDBs were present, and the target exited
0 after URG merge and coverage checks. The CP functional group reached 63/63
variables + 34/34 crosses; high-payload 1/1; mixed reset words 4/4;
kind×delay×reset 24/24; abort timing 7/7. Assertions were 13 success,
0 failure, 0 incomplete (2 UVM RAL internal properties without attempts), and
covers were 4/4. Raw CP line/condition/toggle/FSM/branch coverage was
`100/94.05/20.77/100/100%`; completion writer was
`100/100/65.66/100/100%`. Raw condition/toggle gaps remain open.

```sh
make -C dv/block/command_processor/uvm cov-random-regress \
  OUT=/tmp/nmaforge_cp_width_fix_random_200_20261020 \
  RANDOM_SEED_START=20262021 RANDOM_SEED_COUNT=200 \
  VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Post-change SpyGlass lint passed with 0 errors, 305 warnings, and 4 infos;
the two `MatchFuncArgWidth` messages are absent. CDC setup had 0 errors and
warnings; structural CDC had 0 errors, 1 `Reset_sync04` warning, and 37 infos,
with 0 unsynchronized crossings and 0 convergence findings.

```sh
cd dv/spyglass
PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH \
  bash ./run_spyglass_a8.sh lint
PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH \
  bash ./run_spyglass_a8.sh cdc
```

The RDC attempt on the clean pushed SHA `ff1e3bb` stalled at
`Ar_resetcross01` for about 3:49 with no CPU activity. The invocation was
terminated; it produced no RDC result and is classified as inconclusive, not
PASS or RTL failure. The later zero-extension correction does not touch reset
logic. RDC and reset sign-off remain open. `git diff --check` passed; the only
tracked RTL change is the single file noted above. No source list changed.
