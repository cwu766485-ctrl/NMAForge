# A10 V3 exact-SHA DMA-SPAD-CNM clean replay

## Scope and source

- Pushed `main` SHA: `7271c548d7ba30457c0b1ce2e11de88358cc54c2`
- Detached worktree: `/tmp/nmaforge_clean_7271c54_v3_20261019`
- Artifacts: `/tmp/nmaforge_a10_main7271c54_v3_full10_20261019`
- Rocky Linux 8.10; VCS and URG `V-2023.12-SP1_Full64`
- This commit adds documentation after `c500b3d`; RTL and DV sources used
  here are the sources at the stated pushed SHA.
- No product RTL, SPEC, ABI, or clock behavior changed in this run.

## Reproduction

Compile once with line, condition, FSM, toggle, branch, and assertion
instrumentation:

```sh
out=/tmp/nmaforge_a10_main7271c54_v3_full10_20261019
make -C dv/subsystem/dma_spad/sim subsystem_compile \
  SIMV=$out/simv COV_DIR=$out/compile.vdb COMPILE_LOG=$out/compile.log \
  VCS="vcs -licwait 1 -Mdir=$out/csrc"
```

Run the full `dma_spad_subsystem_test` with seeds `20263001..20263010`, one
log and VDB per seed:

```sh
cd dv/subsystem/dma_spad/sim
for seed in 20263001 20263002 20263003 20263004 20263005 \
            20263006 20263007 20263008 20263009 20263010; do
  $out/simv +UVM_TESTNAME=dma_spad_subsystem_test \
    +ntb_random_seed=$seed +UVM_VERBOSITY=UVM_MEDIUM \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir $out/seed_$seed.vdb -l $out/seed_$seed.log
done
```

The existing `subsystem_rready_stall_run` target was run at 16, 64, and 300
cycles (seeds `20261097`, `20261098`, `20261099`). Each run used unique
simulator, coverage, compile-log, and run-log paths under `$out`. For example:

```sh
make -C dv/subsystem/dma_spad/sim subsystem_rready_stall_run \
  SEED=20261097 RREADY_STALL_CYCLES=16 \
  RREADY_SIMV=$out/simv_rready_16 RREADY_COV_DIR=$out/rready_16.vdb \
  RREADY_RUN_LOG=$out/rready_16.log RREADY_COMPILE_LOG=$out/compile_rready_16.log \
  VCS="vcs -licwait 1 -Mdir=$out/csrc_rready_16"
```

The shared-reset cutpoints 0/1/2/3 used seeds `20263011..20263014` and the
same main simulator:

```sh
for delay in 0 1 2 3; do
  seed=$((20263011 + delay))
  $out/simv +UVM_TESTNAME=dma_spad_subsystem_test \
    +ntb_random_seed=$seed +UVM_VERBOSITY=UVM_MEDIUM \
    +SPAD_PARITY_ABORT_RESET_DELAY=$delay \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir $out/reset_delay_$delay.vdb -l $out/reset_delay_$delay.log
done
```

The final URG merge included the compile database plus 10 seeded, 3 RREADY,
and 4 forced-reset runtime VDBs. The compile database is required for URG to
load the design associated with the tests. The output was checked for design
load errors.

```sh
db_args=(-dir $out/compile.vdb)
for seed in 20263001 20263002 20263003 20263004 20263005 \
            20263006 20263007 20263008 20263009 20263010; do
  db_args+=(-dir $out/seed_$seed.vdb)
done
for profile in 16 64 300; do db_args+=(-dir $out/rready_$profile.vdb); done
for delay in 0 1 2 3; do db_args+=(-dir $out/reset_delay_$delay.vdb); done
urg -full64 "${db_args[@]}" -format text \
  -report $out/urg_final -log $out/urg_final.log
make -C dv/subsystem/top_smoke/sim ai_smoke
```

## Results

- Full subsystem: 10/10 seeds reached `[SPAD_CNM_DMA_PASS]` and `[TEST_DONE]`;
  UVM warning/error/fatal=`0/0/0` for every seed.
- RREADY: 16/64/300-cycle profiles all passed, holding the AXI R payload
  stable, draining four accepted DMA reads, and matching all 32 SPAD words to
  the memory oracle.
- Reset cutpoints: all four runs reached
  `[SPAD_PARITY_ABORT_RESET_PASS]` and `[TEST_DONE]`, severity=`0/0/0`.
- Combined URG `dma_rready_stall_cg`: 4/4 variables and 3/3 crosses (100%).
- Combined URG `cnm_parity_abort_reset_cg`: 4/4 variables and 2/2 crosses
  (100%), including same-cycle reset and four outstanding DMA reads.
- URG assertions: 31 total; 29 successes, 0 failures, 0 incomplete. Two
  without attempts are UVM RAL `do_read`/`do_write` internals, not DUT passes.
- VCS compile log had no `Warning-`/`Error-` diagnostics; top `ai_smoke`
  printed `TEST PASS`. Detached worktree remained semantically clean.

This is reproducible evidence for selected DMA-SPAD-CNM scenarios, not full
V3 acceptance. AXI RREADY stress does not demonstrate scheduler fairness under
a scratchpad response-ready stall; `ai_spad_arbiter` has no downstream response-
ready input. Broader fault/abort/reset combinations, DUT-only residual code
coverage disposition, full command/completion lifecycle, and overall A10/V5
closure remain open.
