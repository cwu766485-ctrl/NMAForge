# A10 V1 FP directed core and reference-model replay

**Date:** 2026-10-19

**Source:** pushed `main` commit `9e497a558fae1af5bc78e03f3628c01d4b5d08cd`

**Environment:** Rocky Linux 8.10, Synopsys VCS `V-2023.12-SP1_Full64`, Python 3.12

**Scope:** FP mixed-precision dot directed/core regression, maximum-length parity
cutoffs and no-reset recovery, plus the independent FP reference-model tests. No
RTL or testbench changes.

## Reproduction

The commands ran from an initially clean detached worktree at the exact pushed
SHA. Generated files were kept outside the worktree.

```sh
make -C dv/block/compute/fp/sim dot-core-test \
  DOT_CORE_OUT_DIR=/tmp/nmaforge_a10_main9e497a5_v1fp_core_20261019/dot_core \
  DOT_CORE_PARITY_MAX_OUT_DIR=/tmp/nmaforge_a10_main9e497a5_v1fp_core_20261019/max_parity

(cd dv/block/compute/fp/model && python3.12 -m unittest -v test_fp_reference.py)
```

Detached worktree: `/tmp/nmaforge_clean_9e497a5_v1fp_20261019`

Artifact root: `/tmp/nmaforge_a10_main9e497a5_v1fp_core_20261019`

## Results

- `dot-core-test` passed the directed BF16 dot-core test and the maximum-length
  mixed-precision parity test.
- The parity stress passed BF16 and FP16, final packed word A and B. Each case
  accepted and drained 65,536 ordered reads, reached peak outstanding=2,
  reported the parity error after the 65,534-element prefix, and suppressed
  destination writeback.
- Each parity case was followed without reset by a recovery dot operation; all
  four recovery checks wrote FP32 `1.0` (`0x3f800000`) with two reads and one
  write.
- The independent Python reference model passed all 19 tests, including
  canonical NaNs, signed zero, subnormals, rounding boundaries, and sequential
  per-product/per-accumulation rounding rules.
- The detached worktree was clean before and after. No VCS, simulator, or URG
  process remained at final audit.

## Evidence boundary

This is directed simulation plus software reference-model evidence. It is not a
full-domain formal proof. V1-FP-04, full RTL raw-coverage disposition, and the
broader A10/V1–V5 acceptance remain open; see the [A10 RTM](A10_DV_RTM.md).
