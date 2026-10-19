# A10 Selected Baseline Replay at Exact `main` — 2026-10-19

## Identity and environment

- Exact pushed `main` SHA: `649c6c00dd22dc10910f1cc795df25fdff636b32`.
- Detached worktree: `/tmp/nmaforge_clean_649c6c0_a10_20261019`.
- Rocky Linux 8.10 / WSL2.
- VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.
- Isolated artifacts: `/tmp/nmaforge_a10_649c6c0_selected_replay_20261019/`.
- Worktree was clean before and after the campaign; no VCS/URG/simv process
  remained afterward.

This is a selected exact-SHA reproducibility replay. It does not close A10,
replace the missing full-domain FP parity proof, or claim full code-coverage
closure.

## V1 FP

The following ran at the exact SHA above:

```sh
OUT=/tmp/nmaforge_a10_649c6c0_selected_replay_20261019/fp
make -C dv/block/compute/fp/sim dot-core-test \
  DOT_CORE_OUT_DIR=$OUT/dot_core \
  DOT_CORE_PARITY_MAX_OUT_DIR=$OUT/max_parity VCS='vcs -licwait 1'

make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_RANDOM_COUNT=200 \
  DOT_UVM_SEEDS='712345 987654 20261015' \
  DOT_UVM_OUT_DIR=$OUT/uvm VCS='vcs -licwait 1' URG=urg

cd dv/block/compute/fp/model
python3.12 -m unittest -v test_fp_reference.py
```

Directed dot-core and maximum-length parity stress both passed. The three UVM
seeds each passed 484/484 bit-exact transactions with warning/error/fatal
`0/0/0` (1,452 transactions total). URG merge completed; its main selected
group reported 26/26 variables and 48/48 crosses. Python reference tests passed
19/19.

## DMA, Control, and top-level selected baseline

The official per-test Makefile test lists were used: 19 DMA tests and 9
Control tests. Each simulator was compiled once in the detached worktree, then
the named tests were run with isolated per-test VDBs and the official
line/condition/FSM/toggle/branch/assert coverage metrics. Every DMA test had
its scoreboard PASS marker and no nonzero UVM severity; all Control tests
reported zero nonzero UVM severity.

For a valid URG design load, the compile VDB was included with the per-test
simulation VDBs:

```sh
SYS=/tmp/nmaforge_a10_649c6c0_selected_replay_20261019/system_retry
make -C dv/block/dma/sim uvm_compile SIMV=simv_dma_a10 \
  COV_DIR=$SYS/dma/compile.vdb VCS='vcs -licwait 1'
for TEST in dma_load_ooo_smoke_test dma_2d_load_test dma_gather_load_test \
  dma_store_booo_test dma_store_four_booo_test dma_2d_store_test \
  dma_aw_stall_stability_test dma_narrow_load_test dma_4k_load_test \
  dma_4k_edge_load_test dma_short_tail_store_test dma_abort_read_test \
  dma_read_slverr_test dma_spad_error_drain_test dma_write_slverr_test \
  dma_abort_write_test dma_config_error_test dma_backpressure_test \
  dma_random_stress_test; do
  ./dv/block/dma/sim/simv_dma_a10 -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir $SYS/dma/vdb/$TEST.vdb -cm_name $TEST \
    +UVM_TESTNAME=$TEST +ntb_random_seed=20261019 \
    +UVM_VERBOSITY=UVM_MEDIUM -l $SYS/dma/$TEST.log
done

make -C dv/block/control/sim uvm_compile SIMV=simv_control_a10 \
  COV_DIR=$SYS/control/compile.vdb VCS='vcs -licwait 1'
for TEST in control_reset_version_test control_register_file_test \
  control_protocol_test control_channel_backpressure_test \
  control_inflight_reset_test control_irq_error_test control_busy_abort_test \
  control_random_rw_test control_ral_access_test; do
  ./dv/block/control/sim/simv_control_a10 \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir $SYS/control/vdb/$TEST.vdb -cm_name $TEST \
    +UVM_TESTNAME=$TEST +ntb_random_seed=20261019 \
    +UVM_VERBOSITY=UVM_MEDIUM -l $SYS/control/$TEST.log
done

urg -full64 -dir $SYS/dma/compile.vdb $SYS/dma/vdb/*.vdb \
  -format text -report $SYS/dma/urg_merged_with_design \
  -log $SYS/dma/urg_with_design.log
urg -full64 -dir $SYS/control/compile.vdb $SYS/control/vdb/*.vdb \
  -format text -report $SYS/control/urg_merged_with_design \
  -log $SYS/control/urg_with_design.log
```

Both corrected merges generated `grpinfo.txt` and had zero design-load errors.
The first diagnostic merge omitted the compile VDB and printed `Design not yet
loaded`; that report is invalid and superseded by the corrected merges above.

Then:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke SEED=20261019
make -C dv/subsystem/top_smoke/sim ai_run \
  AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261019
```

Both top smoke and the 20-case seeded top run printed `TEST PASS`.

## Invocation note and conclusion

An initial attempt passed an absolute `/tmp/...` `SIMV` to the block
`uvm_regress` Makefile target. That Makefile prefixes `./` to `$(SIMV)`, so the
resulting `.//tmp/...` path was not executable; no test ran in that attempt.
The replay was restarted with the supported compile-once/direct-run flow,
isolated logs/VDBs, scoreboard/severity gates, and corrected URG design input.
This was a test invocation issue, not a DUT failure.

The selected V1 FP, DMA, Control, top smoke, and 20-case top random slices are
reproduced at the exact pushed main SHA. V1-FP-04, broader V2/V3/V4 coverage
disposition, and V5/global closure remain open.
