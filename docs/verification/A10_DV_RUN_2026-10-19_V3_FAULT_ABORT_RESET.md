# A10 V3 exact-SHA DMA-SPAD-CNM parity/abort/reset replay

## Scope

Replay the bounded cross-layer case where a real CNM scratchpad parity error
retires while DMA is draining four accepted AXI reads after abort, followed by
a shared reset and no-reset-recovery checks for both engines. This is one V3
fault/abort/reset slice; it is not complete V3 or A10 closure.

## Source and environment

- Pinned source SHA: `c500b3daba529d3123ffe250644f3297ae8c16f3`
- Checkout: detached clean worktree `/tmp/nmaforge_clean_c500b3d_20261018`
- Tracked worktree status: clean before and after all runs
- Rocky Linux 8.10; VCS/URG `V-2023.12-SP1_Full64`
- No product RTL, SPEC, ABI, or clock behavior changed in this run

## Commands

Compile the subsystem test once in the pinned worktree:

```sh
make -C dv/subsystem/dma_spad/sim subsystem_compile \
  SEED=20261120 \
  COV_TAG=a10_c500b3d_v3_zero_retry_20261018 \
  SIMV=simv_a10_c500b3d_v3_zero_retry \
  COMPILE_LOG=/tmp/nmaforge_a10_c500b3d_v3_zero_delay_retry_20261018/compile.log \
  VCS='vcs -licwait 1'
```

Run four deterministic reset cutpoints with the same compiled simulator.
Each command uses `-cm line+cond+fsm+tgl+branch+assert`; seeds are paired
with the requested reset delay:

| Seed | `SPAD_PARITY_ABORT_RESET_DELAY` |
|---:|---:|
| 20261120 | 0 |
| 20261121 | 1 |
| 20261122 | 2 |
| 20261123 | 3 |

For each row, the invocation was:

```sh
cd dv/subsystem/dma_spad/sim
./simv_a10_c500b3d_v3_zero_retry \
  +UVM_TESTNAME=dma_spad_subsystem_test +ntb_random_seed=<seed> \
  +UVM_VERBOSITY=UVM_MEDIUM \
  +SPAD_PARITY_ABORT_RESET_DELAY=<delay> \
  -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir coverage/dma_spad_subsystem_test_a10_c500b3d_v3_zero_retry_20261018_seed<seed>.vdb \
  -l /tmp/nmaforge_a10_c500b3d_v3_zero_delay_retry_20261018/run_delay_<delay>.log
```

Run 20 randomized seeds (`20261090..20261109`) without the reset-delay
override, preserving one VDB and log per seed:

```sh
for seed in 20261090 20261091 20261092 20261093 20261094 20261095 \
            20261096 20261097 20261098 20261099 20261100 20261101 \
            20261102 20261103 20261104 20261105 20261106 20261107 \
            20261108 20261109; do
  ./simv_a10_c500b3d_v3_zero_retry \
    +UVM_TESTNAME=dma_spad_subsystem_test +ntb_random_seed=$seed \
    +UVM_VERBOSITY=UVM_MEDIUM \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir coverage/dma_spad_subsystem_test_a10_c500b3d_v3_random20_retry_20261018_seed$seed.vdb \
    -l /tmp/nmaforge_a10_c500b3d_v3_random20_clean_retry_20261018/run_$seed.log
done
```

The randomized VDBs and four forced-delay VDBs were merged together with
`urg -full64 -dir <VDB> ... -report
/tmp/nmaforge_a10_c500b3d_v3_combined_24_20261019/urg_24`. The separate
campaign reports were also generated with the subsystem Makefile's
`subsystem_coverage` target. Top smoke:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke VCS='vcs -licwait 1'
```

## Results

- All 20 randomized logs and all four forced-delay logs contained
  `[SPAD_PARITY_ABORT_RESET_PASS]` and `[TEST_DONE]`; each had UVM
  warning/error/fatal=`0/0/0`.
- Random reset-delay histogram: 0 cycles=`0`, 1 cycle=`8`, 2 cycles=`3`,
  3 cycles=`9`. The four deterministic runs add one sample at each delay
  0/1/2/3.
- Combined 24-VDB `cnm_parity_abort_reset_cg`: 4/4 variables and 2/2 crosses,
  all covered. This includes the same-cycle reset corner and the
  `parity_during_abort_drain_then_reset` cross with reset timing and four
  outstanding reads.
- URG assertions: 31 total, 29 successes, 0 failures, 0 incomplete; the two
  without attempts are UVM RAL `do_read`/`do_write` internals.
- Top `ai_smoke`: `TEST PASS`.
- Exact artifacts:
  - Random campaign: `/tmp/nmaforge_a10_c500b3d_v3_random20_clean_retry_20261018/`
  - Forced cutpoints: `/tmp/nmaforge_a10_c500b3d_v3_zero_delay_retry_20261018/`
  - Combined URG: `/tmp/nmaforge_a10_c500b3d_v3_combined_24_20261019/urg_24/`

This closes the exercised CNM parity, DMA abort-drain, and shared-reset timing
slice at the pinned SHA. Other DMA/SPAD fault combinations, residual DUT code
coverage disposition, and overall V3/A10/V5 acceptance remain open.
