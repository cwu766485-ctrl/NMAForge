# Phase 1.2 Joint Memory-Aware Cost Model

This is an offline prototype only. It scores existing Matrix controller configurations using shape, useful MAC count and measured cycles. It does not change the ABI or product RTL and does not claim a new tiling mechanism.

## Variables and constraints

The prototype enumerates existing `(outstanding_depth, next_K_prefetch, A_tile_cache)` choices. The intended next version will add legal tile shape, buffer placement, bank mapping, DMA layout, padding and schedule. Every candidate must satisfy 128 KiB capacity, four-bank address mapping, existing arbiter admission, dependency/lifetime intervals, RAW/WAR/WAW ordering, visible completion/fault semantics and no unauthorized alias.

## Calibration split

Only `4x4x32`, `8x8x32` and `16x16x32` are used for calibration. `16x32x32` and `32x32x64` are held out. The three seed CSVs contain 15 rows per configuration and 120 Golden points; raw hashes and logs are in `benchmark/research/phase0_1_compute_cluster/raw/`. The prototype selects B2 on all five shapes because B2 is already the fastest measured existing configuration. Held-out selection is therefore a reproduction of known controller behavior, not evidence of a new mapper.

| Shape | Train/held-out | Measured B0/B1/B2 mean cycles | Model selected |
|---|---|---:|---|
| 4x4x32 | TRAIN | 103.7 / 103.7 / 70.3 | B2 |
| 8x8x32 | TRAIN | 138.7 / 138.7 / 108.7 | B2 |
| 16x16x32 | TRAIN | 246.7 / 246.7 / 208.3 | B2 |
| 16x32x32 | HELD_OUT | 516.3 / 452.0 / 366.3 | B2 |
| 32x32x64 | HELD_OUT | 1,718.3 / 1,476.7 / 1,131.0 | B2 |

The model output is `benchmark/research/phase1_1_a1_a2/raw/joint_cost_model.csv`. Its simple cycles-per-MAC calibration is intentionally insufficient for a publication claim: it does not yet model bank mapping, DMA overlap, padding or live range. A2 remains REWORK until those terms are calibrated on candidate-bound traces and the mapper is tested on held-out workloads beyond the existing controller settings.

Reproduce:

```bash
python3.12 tools/benchmark/phase0_1/joint_cost_model.py \
  --csv benchmark/research/phase0_1_compute_cluster/raw/matrix_seed_20261025.csv \
        benchmark/research/phase0_1_compute_cluster/raw/matrix_seed_20261026.csv \
        benchmark/research/phase0_1_compute_cluster/raw/matrix_seed_20261027.csv \
  --out /tmp/nmaforge_phase11_cost_model.csv
```
