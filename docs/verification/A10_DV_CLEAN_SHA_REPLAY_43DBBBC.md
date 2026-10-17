# A10 Clean-SHA Replay — `43dbbbc` (2026-10-17)

## Purpose and baseline

This replay checks whether the A10 verification subset already present in the
pushed GitHub `main` commit can be reproduced without relying on the later dirty
worktree. The tested baseline was `43dbbbc498377d852667c4e3eb5880ecf4aaf8f7`
(`test: close DMA subsystem AW stability coverage`), checked out in a detached
worktree before running the tests.

**Environment:** Rocky Linux 8.10, Synopsys VCS/URG
`V-2023.12-SP1_Full64`. The license was available for the suites listed below;
a later V4 top-UVM replay attempt is separately recorded as incomplete because
the license server became unreachable. Test outputs are under `/tmp`.

## Results

| A10 area | Command / campaign | Result |
|---|---|---|
| V1 FP dot | `make -C dv/block/compute/fp/sim dot-core-test VCS='vcs -licwait 1'`; then `dot-uvm-regress DOT_RANDOM_COUNT=200 DOT_UVM_SEEDS='712345 987654 20261015'` | Directed test passed; all three UVM seeds passed 484/484 bit-exact transactions per seed (430 numeric + 54 fault/reset/error-transition), peak outstanding reads=2, UVM warning/error/fatal=`0/0/0`; independent Python reference model 19/19 tests passed. Selected functional groups reached 100%. |
| V3 DMA block | Sixteen named DMA UVM tests, each run with scoreboard/expected-abort and zero-severity gates; URG merged | 16/16 passed, including 20/20 random stress cases; UVM warning/error/fatal=`0/0/0`; `dma_cmd_cg`=100%. URG assertion report: 12 successes, zero failure/incomplete, two UVM RAL internal no-attempts. |
| V2 Control block | Nine named Control UVM tests; URG merged | 9/9 passed; UVM warning/error/fatal=`0/0/0`; `control_env_pkg::control_coverage::cg`=100%. Eight DUT-facing assertions succeeded, zero failure/incomplete; two UVM RAL internal no-attempts. |
| V3 DMA–SPAD subsystem | `dma_spad_subsystem_test`, seeds `20261110..20261119`; URG merged | 10/10 passed with UVM warning/error/fatal=`0/0/0`; all selected functional groups=100%. The labeled `ap_dma_aw_payload_stable` assertion had 50 real successes, zero failures. URG total: 31 assertions, 29 successes, zero failure/incomplete, two UVM RAL internal no-attempts. |
| V4 top smoke | `make -C dv/subsystem/top_smoke/sim ai_smoke SEED=20261018 AI_RANDOM_CASES=4 AI_SEED=12345` | `TEST PASS`; make exited 0. |
| V4 seeded top run | `make -C dv/subsystem/top_smoke/sim ai_run SEED=20261018 AI_RANDOM_CASES=20 AI_SEED=12345` | `TEST PASS`; make exited 0 for 20 seeded random cases. |
| V4 top mixed-precision DDR E2E UVM | `make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_clean43_v4_random_20261017` | **Incomplete; not a pass.** VCS compile succeeded and seeds `20261101..20261191` have 91/91 E2E, coverage and UVM severity gates. Seed `20261192` did not complete; no URG merge or aggregate 100% coverage gate was produced. A retry could not obtain a VCS license; `lmstat` returned 241 and reported the server unreachable. |

The isolated output directories are `/tmp/nmaforge_clean43_fp`,
`/tmp/nmaforge_clean43_dma`, `/tmp/nmaforge_clean43_control_retry`,
`/tmp/nmaforge_clean43_v3`, and `/tmp/nmaforge_clean43_top`. The V3 URG report is
`/tmp/nmaforge_clean43_v3/urg_merged`; the Control and DMA URG reports are in
their respective `urg_merged` directories.

## Reproduction commands

Start from the repository root in the Rocky/WSL EDA environment. To reproduce
from the recorded baseline, create a fresh detached worktree first:

```sh
git worktree add --detach tmp/a10_clean_43dbbbc_replay 43dbbbc498377d852667c4e3eb5880ecf4aaf8f7
cd tmp/a10_clean_43dbbbc_replay
```

The exact FP and top commands were:

```sh
make -C dv/block/compute/fp/sim dot-core-test VCS='vcs -licwait 1'
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_RANDOM_COUNT=200 \
  DOT_UVM_SEEDS='712345 987654 20261015' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_clean43_fp \
  VCS='vcs -licwait 1'
(cd dv/block/compute/fp/model && python3.12 -m unittest -v test_fp_reference.py)

make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261018 AI_RANDOM_CASES=4 AI_SEED=12345
make -C dv/subsystem/top_smoke/sim ai_run \
  SEED=20261018 AI_RANDOM_CASES=20 AI_SEED=12345
```

DMA, Control, and DMA–SPAD were compiled once into their isolated `/tmp`
directories with the repository's `uvm_compile` / `subsystem_compile` targets.
Each named UVM test was then run separately with
`-cm line+cond+fsm+tgl+branch+assert`, its own VDB and log, and
`+UVM_TESTNAME=<test> +ntb_random_seed=<seed> +UVM_VERBOSITY=UVM_MEDIUM`;
zero-severity and scoreboard/expected-abort markers were checked per run before
the VDBs were merged using `urg -full64 -dir <VDB list> -format text -report
<urg_merged>`. DMA used seed `20261017`; Control used `20261018`; the subsystem
used seeds `20261110..20261119`.

The recorded compile commands were:

```sh
mkdir -p /tmp/nmaforge_clean43_dma/csrc
make -C dv/block/dma/sim uvm_compile \
  SIMV=/tmp/nmaforge_clean43_dma/simv_dma \
  COV_DIR=/tmp/nmaforge_clean43_dma/compile.vdb \
  VCS='vcs -licwait 1 -Mdir=/tmp/nmaforge_clean43_dma/csrc'

mkdir -p /tmp/nmaforge_clean43_control_retry/csrc
make -C dv/block/control/sim uvm_compile \
  SIMV=/tmp/nmaforge_clean43_control_retry/simv_control \
  COV_DIR=/tmp/nmaforge_clean43_control_retry/compile.vdb \
  VCS='vcs -licwait 1 -Mdir=/tmp/nmaforge_clean43_control_retry/csrc'

mkdir -p /tmp/nmaforge_clean43_v3/csrc
make -C dv/subsystem/dma_spad/sim subsystem_compile \
  SIMV=/tmp/nmaforge_clean43_v3/simv_dma_spad \
  COV_DIR=/tmp/nmaforge_clean43_v3/compile.vdb \
  COMPILE_LOG=/tmp/nmaforge_clean43_v3/compile.log \
  VCS='vcs -licwait 1 -Mdir=/tmp/nmaforge_clean43_v3/csrc'
```

For each seed, the DMA–SPAD test was invoked as:

```sh
simv_dma_spad +UVM_TESTNAME=dma_spad_subsystem_test \
  +ntb_random_seed=<seed> +UVM_VERBOSITY=UVM_MEDIUM \
  -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir <seed-output>/coverage.vdb -l <seed-output>/run.log
```

Use fresh `/tmp` output paths when repeating these commands; paths above name
the original recorded run.

The incomplete clean-SHA top-UVM attempt used this target from the detached
worktree:

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress \
  MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_clean43_v4_random_20261017
```

The Makefile's default random seed range is `20261101..20261292` (192 runs).
The first 91 logs were independently checked for `[MIXED_E2E_PASS]`,
`[MIXED_E2E_COVERAGE]`, UVM report summaries, and zero nonzero UVM
warning/error/fatal counts. The target stopped before its URG merge and its
full-run coverage gate; the partial 91-seed result must not be used as V4
acceptance evidence.

DMA test names: `dma_load_ooo_smoke_test`, `dma_2d_load_test`,
`dma_gather_load_test`, `dma_store_booo_test`, `dma_2d_store_test`,
`dma_aw_stall_stability_test`, `dma_narrow_load_test`, `dma_4k_load_test`,
`dma_abort_read_test`, `dma_read_slverr_test`, `dma_spad_error_drain_test`,
`dma_write_slverr_test`, `dma_abort_write_test`, `dma_config_error_test`,
`dma_backpressure_test`, `dma_random_stress_test`.

Control test names: `control_reset_version_test`,
`control_register_file_test`, `control_protocol_test`,
`control_channel_backpressure_test`, `control_inflight_reset_test`,
`control_irq_error_test`, `control_busy_abort_test`,
`control_random_rw_test`, `control_ral_access_test`.

## Scope and limits

This is reproducibility evidence for the listed committed subset, not A10
verification closure. It does not replace the expanded, post-commit V1–V5
campaigns, close the remaining FP parity/writeback formal question, disposition
all CP or DUT code-coverage residuals, or prove complete V3/V4 fault × abort ×
reset behavior. The top smoke flow generated changes to three tracked
workload/Verdi files in the temporary detached worktree; those changes were not
copied to the main worktree or committed. No product RTL was changed by this
replay.

The test commands, seeds, result gates, and report summaries are also indexed in
the [A10 RTM](A10_DV_RTM.md) and [verification matrix](../../dv/VERIFICATION_MATRIX.md).
