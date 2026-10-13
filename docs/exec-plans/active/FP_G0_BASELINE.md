# FP Extension G0 Baseline Record

Read-only baseline rerun recorded 2026-10-13 (Asia/Singapore).

- HEAD: `fbaa525512b527e4d8c87bbdda683208f9f757b0`.
- Worktree: not clean; existing modified and untracked files were present. No source files were edited for these checks.
- DMA: `make -C dv/block/dma/sim uvm_regress` — exit 1. VCS failed during compile for the first test (`dma_load_ooo_smoke_test`) because it could not connect to the license server. 0/11 tests ran.
- Control: `make -C dv/block/control/sim uvm_regress` — exit 1. VCS failed during `uvm_compile` because it could not connect to the license server. 0/6 tests ran.
- Top smoke: `make -C dv/subsystem/top_smoke/sim ai_smoke` — exit 1. The mapper reported `TRANSFORMER_MAPPER_PASS`; VCS `ai_comp` then failed to connect to the license server, so the smoke simulation did not run.
- Result classification: no RTL test passed or failed; all three regression runs were blocked before simulation by VCS license-server connectivity.
- Tools: VCS V-2023.12-SP1_Full64 (`vcs -ID` script V-2023.12); GNU Make 4.2.1; Python 3.6.8. Verdi version was not obtained. VCS installation and license configuration are local environment settings.
- Logs: `/tmp/nmaforge_g0_dma.log`, `/tmp/nmaforge_g0_control.log`, `/tmp/nmaforge_g0_top_smoke.log` (Rocky WSL).

Next rerun in the configured Rocky WSL environment after restoring VCS license-server connectivity:

```bash
make -C dv/block/dma/sim uvm_regress
make -C dv/block/control/sim uvm_regress
make -C dv/subsystem/top_smoke/sim ai_smoke
```

## License-restored rerun — 2026-10-13

The earlier license-blocked attempt above is retained as history. On this rerun,
the repository root was the working directory, HEAD was
still `fbaa525512b527e4d8c87bbdda683208f9f757b0`, and the worktree remained
non-clean. No RTL/source files were changed for the rerun.

- `make -C dv/block/dma/sim uvm_regress` — exit 0; all 11 configured tests ran
  and completed. Each of the 11 UVM report summaries had 0 errors, 0 fatals,
  and 0 warnings. Tests: `dma_load_ooo_smoke_test`, `dma_2d_load_test`,
  `dma_gather_load_test`, `dma_store_booo_test`, `dma_2d_store_test`,
  `dma_narrow_load_test`, `dma_4k_load_test`, `dma_abort_read_test`,
  `dma_config_error_test`, `dma_backpressure_test`, `dma_random_stress_test`.
- `make -C dv/block/control/sim uvm_regress` — exit 0; all 6 configured tests
  ran and completed. Each of the 6 UVM report summaries had 0 errors, 0 fatals,
  and 0 warnings. Tests: `control_reset_version_test`, `control_protocol_test`,
  `control_irq_error_test`, `control_busy_abort_test`, `control_random_rw_test`,
  `control_ral_access_test`.
- `make -C dv/subsystem/top_smoke/sim ai_smoke` — exit 0; terminal marker
  `TEST PASS`, 333 `PASS:` checks, and 0 `FAIL:` checks. The mapper also reported
  `TRANSFORMER_MAPPER_PASS`. VCS emitted one `Warning-[TFIPC] Too few instance
  port connections` at `rtl/top/fabric/compute/ai_accel_compute_cluster.v:163`;
  this warning is recorded and is not represented as a warning-free compile.
- Classification: these three legacy regression gates passed on this rerun;
  this does not claim that all remaining G0 specification/review deliverables
  are complete.
- Tools: VCS V-2023.12-SP1_Full64 (`vcs -ID` script V-2023.12), GNU Make 4.2.1,
  Python 3.12.13.
- Logs: `/tmp/nmaforge_g0_dma_rerun.log`,
  `/tmp/nmaforge_g0_control_rerun.log`,
  `/tmp/nmaforge_g0_top_smoke_rerun.log` (Rocky WSL).

## G0 specification and raw-bit check

- Frozen implementation contract: `docs/spec/FP_EXTENSION_SPEC_ZH.md`.
- First operation: `0x50 BF16_DOT_ACC_FP32`; descriptor v7, ABI 7.3 and A9
  `VERSION=0x10000009` on delivery; `CAP2[6]` advertises support. Existing A8
  remains ABI 7.2, `VERSION=0x10000008`, `CAP2=0x3f`.
- Added independent Python raw-bit model at `dv/block/compute/fp/model/`.
  Finite arithmetic uses `Fraction` and integer RNE. Command:
  `cd dv/block/compute/fp/model && PYTHONDONTWRITEBYTECODE=1 python3.12 -m unittest -v`.
  Result: 16 tests passed, including all five specification sanity vectors,
  NaN/Inf/signed-zero cases, gradual underflow, RNE ties, overflow midpoints,
  stepwise FP32 dot rounding, and deterministic finite random vectors.
- G0 is closed for entry into G1. Legacy regressions were run at the recorded
  HEAD with a non-clean worktree; this is not evidence that a clean GitHub
  `main` checkout alone passed. The smoke compile warning remains recorded.
- Existing DMA functional coverage in this run was 67.86%; the functional
  regression passed, but this does not claim DMA coverage closure.
