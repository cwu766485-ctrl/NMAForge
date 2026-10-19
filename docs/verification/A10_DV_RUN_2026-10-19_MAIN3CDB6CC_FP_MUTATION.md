# A10 V5 FP result-path mutation replay

Date: 2026-10-19
Fixed source SHA: `3cdb6cc8913d773b1a7d2bb899796ad53437e88f`
Environment: Rocky Linux 8.10, VCS/URG `V-2023.12-SP1_Full64`

## Goal and mutation

This is a targeted V5 checker-sensitivity test for the independent bit-exact
BF16/FP16 dot scoreboard. It does not modify the shared checkout, the UVM
checker, or the reference model.

In a detached clean worktree, the accumulator's product input was temporarily
mutated from `product_bits` to:

```systemverilog
product_bits ^ 32'h0000_0001
```

The isolated worktree was restored to the original RTL after the mutant run.
Baseline and restored RTL SHA-256 were identical:
`4754FBC6F3F7A545F3538AA96F38EC4EDEE4C9AC4CFD9C2A7784F2DD06000A5F`.
The mutant RTL SHA-256 was
`8464394F1A1EEF51A07A7C93E468B2EFD5C34C694FBA2DACDEFCA8D4119D2DEC`.

## Reproduction

For each stage, the focused regression command was:

```bash
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_RANDOM_COUNT=200 \
  DOT_UVM_SEEDS='712345 987654' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_v5_fp_mutation_20261019/<stage> \
  VCS='vcs -licwait 1' URG=urg
```

The three stages were `baseline`, `mutant`, and `restore`. Baseline and restore
each completed both seeds. The mutant was caught on the first seed, so the
Makefile correctly stopped before seed `987654`.

## Results

| Stage | Result | Evidence |
|---|---|---|
| Baseline | RC 0; seeds `712345` and `987654` each scored 484/484 bit-exact transactions; UVM warning/error/fatal `0/0/0`; all six selected FP functional groups 100% | `baseline/coverage_summary.txt`, `baseline/urg_report_merged/` |
| Mutant | RC 2 after simulation reached `TEST_DONE`; UVM `0/424/0`; scoreboard reported result mismatches beginning at transaction 0 (`expected=00000000`, observed result `00000001`) and ended `expected=484 compared=83` | `mutant/seed_712345/run.log`, `mutant/command.log` |
| Restore | RC 0; both seeds again scored 484/484; UVM `0/0/0`; selected FP functional groups 100% | `restore/coverage_summary.txt`, `restore/urg_report_merged/` |

Compile logs had no VCS `Warning-` or `Error-` diagnostics. The mutant's
nonzero result is from the real scoreboard and the Makefile's missing-pass
gate, not compile or license failure. Final audit recorded the detached
worktree clean at the fixed SHA; the shared checkout was unchanged.

## Evidence and limits

The full logs and VDBs are retained outside Git at
`/tmp/nmaforge_a10_v5_fp_mutation_20261019/` (Windows mapping:
`E:\tmp\nmaforge_a10_v5_fp_mutation_20261019\`). The isolated worktree and
temporary bridge configuration are under `E:\tmp\` as well.

This demonstrates that the selected FP UVM scoreboard detects a low-order
product-path corruption. It is one targeted mutation, not a complete mutation
campaign, full V1 proof/coverage closure, or A10/V5 sign-off. Historical bug
failure artifacts and immutable fix-SHA provenance remain outstanding.
