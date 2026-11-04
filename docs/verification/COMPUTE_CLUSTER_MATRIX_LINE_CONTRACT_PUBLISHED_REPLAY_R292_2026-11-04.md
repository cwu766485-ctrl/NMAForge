# Matrix Line contract published-head replay — R292

## Identity and result

| Item | Evidence |
|---|---|
| Run ID | `R292-MATRIX-LINE-CONTRACT-PUBLISHED-3S-20261104` |
| Exact source/test SHA | `e1fcde57c70936f2eb2cd8ed9aea14303a61c717` |
| Tree | `b353adf9035d5a45a1575cdbde827773051b5c1e` |
| Tool | Synopsys VCS `V-2023.12-SP1_Full64` |
| Configuration | 16×16 physical array, outstanding depth 4, prefetch ON, A-tile cache ON |
| Result | PASS, seeds `20261025/26/27`; each has 18 numerical/layout and 35 fault/recovery cases |
| Evidence archive | `/tmp/nmaforge_r292_matrixline_published_logs.tar.gz`, SHA-256 `f4ea9ba6fae0a88123b9f374e779a299092aeb2dc647b743db4eb9ae0efc6ab6` |

This replay used a detached clean worktree at the exact published source/test SHA. It did not modify RTL or tests.

## Reproduction

```sh
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261025 20261026 20261027' \
  CORE_OUT_DIR=/tmp/nmaforge_r292_matrixline_published \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1'
```

Each seed emits:

```text
MATRIX_LINE_CONTRACT_PASS full_wstrb=1 aligned=1 stalled_stability=312 unaligned_scalar_fallback=1 protection_error=1 partial_zero_wstrb=unsupported
MATRIX_CORE_RANDOM_PASS cases=18 faults=35 ...
```

The checker confirms Line writes use `WSTRB=16'hffff` and 16-byte aligned addresses; the valid 4-byte-aligned, non-Line-aligned output uses the ordered 32-bit scalar fallback; Line address/data/strobe remain stable while stalled; and a Protection-denied Line request is rejected. Each seed records 312 payload-stability observations. The same run also passes its numerical/layout and directed fault/recovery suites.

The VCS compile log contains no `Warning-`, `Error-`, `[TFIPC]`, or `Fatal` diagnostics. Compile and per-seed log checksums are in the archive manifest.

## Contract interpretation and disposition

SPEC v1.5 explicitly says partial and zero WSTRB are unsupported. They are not legal input behaviors and must not be generated to fill coverage. The legal Line contract is therefore covered for this Matrix block slice; the prior RTM wording that listed partial/zero WSTRB as an open legal test gap was inaccurate and has been corrected.

This does not close all of `REQ-CL-010`, `REQ-CL-022`, or `REQ-PC-006`: whole-cluster accepted-write Memory Image coverage, legal cross-engine/fault/phase/reset interactions, and other memory/fault scenarios remain open. No requirement status is promoted; `CL-DV-v1.0` remains **HOLD**.
