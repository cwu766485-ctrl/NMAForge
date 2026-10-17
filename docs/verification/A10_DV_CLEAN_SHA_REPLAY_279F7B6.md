# A10 Verification: Clean-SHA Replay at `279f7b6`

**Run date:** 2026-10-17
**Commit:** `279f7b697342df7b90172c2c3ac4cc33dd8d6498`
**Branch:** `main` (pushed to `origin/main`)
**Checkout:** isolated detached worktree at `tmp/a10_clean_279f7b6`; no tracked edits were made in that worktree.
**Environment:** Rocky Linux 8.10 under WSL; Synopsys VCS/URG `V-2023.12-SP1_Full64`.

This is a clean-checkout replay of selected A10 suites at the pushed commit. It is not a replay of every A10 requirement and does not close V1–V5.

## Results

| Area | Result | Selected coverage / qualification |
|---|---|---|
| FP mixed-precision dot | `dot-core-test` PASS; UVM seeds `712345`, `987654`, `20261015` each scored 484/484 bit-exact transactions (430 numeric + 54 fault/reset/error-transition), UVM warning/error/fatal `0/0/0`; total 1,452 transactions | 215 numeric BF16 and 215 numeric FP16 vectors per seed; peak outstanding reads=2; merged selected numeric, latency, fault-format, odd-tail, and parity-two-outstanding groups=100%. Python reference model 19/19. URG: `/tmp/nmaforge_clean279f_fp/urg_report_merged`. |
| DMA block UVM | 16/16 tests PASS at seed `20261017`; each test passed its scoreboard or expected-abort checker and UVM warning/error/fatal gate `0/0/0` | `dma_cmd_cg`=100%. The AW-stall test held AWVALID for four full cycles with stable payload and checked all four written words. URG: `/tmp/nmaforge_clean279f_dma/urg_merged`; 12 assertions succeeded, 0 failed/incomplete, 2 UVM RAL no-attempts. A reported anonymous assertion instance was not mapped to a source property and is not claimed as a named property result. |
| Control block UVM | 9/9 tests PASS at seed `20261018`; per-test UVM warning/error/fatal `0/0/0` | `control_env_pkg::control_coverage::cg`=100%. URG: `/tmp/nmaforge_clean279f_control/urg_merged`; 8 DUT-facing assertions succeeded, 0 failed/incomplete, 2 UVM RAL no-attempts. |
| Top smoke | `ai_smoke` PASS; seeded `ai_run` with 20 random cases PASS; both print `TEST PASS` | This is the directed smoke/random smoke flow, not top-level UVM or board/DDR-PHY validation. Logs were generated inside the isolated worktree under `dv/subsystem/top_smoke/sim/`. |

## Reproduction commands

Run these from the repository root in the Rocky/WSL EDA environment. The `/tmp` directories below are run artifacts, not source inputs.

```sh
# FP core, mixed-dot UVM and independent reference model
make -C dv/block/compute/fp/sim dot-core-test VCS='vcs -licwait 1'
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_RANDOM_COUNT=200 \
  DOT_UVM_SEEDS='712345 987654 20261015' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_clean279f_fp \
  VCS='vcs -licwait 1'
(cd dv/block/compute/fp/model && python3.12 -m unittest -v test_fp_reference.py)

# DMA / Control compile; simulation was then run once per test listed in each Makefile TESTS variable,
# with the same seed and coverage metrics, writing a separate VDB and log for every test.
make -C dv/block/dma/sim uvm_compile \
  SIMV=/tmp/nmaforge_clean279f_dma/simv_dma \
  COV_DIR=/tmp/nmaforge_clean279f_dma/compile.vdb \
  VCS='vcs -licwait 1 -Mdir=/tmp/nmaforge_clean279f_dma/csrc'
make -C dv/block/control/sim uvm_compile \
  SIMV=/tmp/nmaforge_clean279f_control/simv_control \
  COV_DIR=/tmp/nmaforge_clean279f_control/compile.vdb \
  VCS='vcs -licwait 1 -Mdir=/tmp/nmaforge_clean279f_control/csrc'

# Each per-test run used:
#   simv -cm line+cond+fsm+tgl+branch+assert -cm_dir <test>.vdb -cm_name <test> \
#     +UVM_TESTNAME=<test> +ntb_random_seed=<seed> +UVM_VERBOSITY=UVM_MEDIUM -l <test>.log
# Then URG merged compile.vdb and all per-test VDBs with:
#   urg -full64 -dir <VDB list> -format text -report <urg_merged> -log <urg.log>

# Top-level directed smoke and 20-case seeded random smoke
make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261018 AI_RANDOM_CASES=4 AI_SEED=12345
make -C dv/subsystem/top_smoke/sim ai_run \
  SEED=20261018 AI_RANDOM_CASES=20 AI_SEED=12345
```

The DMA tests were `dma_load_ooo_smoke_test`, `dma_2d_load_test`, `dma_gather_load_test`, `dma_store_booo_test`, `dma_2d_store_test`, `dma_aw_stall_stability_test`, `dma_narrow_load_test`, `dma_4k_load_test`, `dma_abort_read_test`, `dma_read_slverr_test`, `dma_spad_error_drain_test`, `dma_write_slverr_test`, `dma_abort_write_test`, `dma_config_error_test`, `dma_backpressure_test`, and `dma_random_stress_test`. Control tests were `control_reset_version_test`, `control_register_file_test`, `control_protocol_test`, `control_channel_backpressure_test`, `control_inflight_reset_test`, `control_irq_error_test`, `control_busy_abort_test`, `control_random_rw_test`, and `control_ral_access_test`.

## Run notes and remaining verification work

- The WSL `make` environment emitted non-fatal future-mtime / clock-skew warnings during some incremental builds. VCS compile/link and test gates completed successfully; this run is not described as warning-free at the build-tool level.
- Two attempts to run SpyGlass from the CDC UVM working directory failed because the relative project path/script was wrong; the documented repository entry point is `cd dv/spyglass && ./run_spyglass_a8.sh {lint|cdc|rdc|all}`. No new SpyGlass result is claimed by this clean replay.
- V1 full-domain parity-error-to-writeback formal disposition remains open. V2 CP residual coverage/fault×abort×reset combinations remain open. V3 retains an unresolved anonymous DMA assertion in the DMA–SPAD subsystem report, along with long fairness and broader interaction coverage. V4 top-level mixed-precision UVM is not part of this clean-SHA replay. V5 global code/assertion coverage disposition and mutation/regression closure remain open.
- Therefore this replay proves reproducibility only for the named FP, DMA, Control, and top smoke slices at commit `279f7b6`; it is not signoff or full A10 acceptance.
