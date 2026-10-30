# Compute Cluster Matrix configuration benchmark — R89

**Run ID:** `R89-MATRIX-CONFIG-COMPARE-20261030-CE2E36D-20261026`  
**Result:** PASS for the stated Matrix block scope: eight configurations × five workloads = 40/40 Golden cases.  
**Checkout commit:** `c236b7ed93414a2a48590e7b587d56b359f1d30d` (documentation-only child of R88).  
**RTL/UVM test SHA:** `ce2e36d0d38a92d70e0bf2f64ff2523617c6dfec`; product RTL/SPEC baseline remains `9d4e9abdba1f745644a485960620fa6bbc4979db`.

## Reproduction

```sh
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_matrix_config_compare_r88_20261030
```

VCS was `V-2023.12-SP1_Full64`; all eight compile and simulation invocations completed. Each configuration reported the five expected `MATRIX_CORE_CASE_PASS` records and a `MATRIX_SIZE_BENCHMARK_PASS` record. The Make target exited 0. Compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

The run fixes the physical array at 16×16, uses one-cycle behavioral bank response and the testbench's 10 ns period. Seed `20261026` is held constant across all configurations. Workloads are 4×4×32, 8×8×32, 16×16×32, 16×32×32 and 32×32×64. The checked-in [CSV](compute_cluster_matrix_r89.csv) contains all eight configuration metrics for each workload; the complete compile/run logs remain under `/tmp/nmaforge_matrix_config_compare_r88_20261030` and are identified by SHA-256 below.

## Baseline and full-feature comparison

Baseline is Depth 2 / Prefetch OFF / A-Cache OFF (`d2_p0_c0`). Full-feature comparison is Depth 4 / Prefetch ON / A-Cache ON (`d4_p1_c1`). All cycle, traffic and stall counts are Matrix-core simulation observations under the stated behavioral memory model.

| Workload | Cycles baseline → full | Cycle reduction | SPAD read bytes baseline → full | Bank stalls baseline → full | Line stalls baseline → full | SPAD write bytes | Full MAC/cycle | Full array utilization |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99 → 76 | 23.23% | 256 → 256 | 4 → 3 | 1 → 0 | 64 | 6.737 | 2.63% |
| 8×8×32 | 135 → 116 | 14.07% | 512 → 512 | 11 → 12 | 2 → 3 | 256 | 17.655 | 6.90% |
| 16×16×32 | 265 → 233 | 12.08% | 1,024 → 1,024 | 25 → 24 | 22 → 28 | 1,024 | 35.159 | 13.73% |
| 16×32×32 | 504 → 417 | 17.26% | 2,048 → 1,536 | 53 → 38 | 22 → 65 | 2,048 | 39.290 | 15.35% |
| 32×32×64 | 1,698 → 1,187 | 30.09% | 8,192 → 6,144 | 156 → 136 | 74 → 72 | 4,096 | 55.211 | 21.57% |
| **Five-workload sum** | **2,701 → 2,029** | **24.92%** | **12,032 → 9,472** | **249 → 213** | **121 → 168** | **7,488 → 7,488** | — | — |

A-Cache/prefetch reduce bank reads for the two wider workloads; output bytes are unchanged. The counter movement is not uniformly favorable: combined bank-plus-Line stall observations rise from 370 to 381 because Line write stalls increase on the 16×16×32 and 16×32×32 cases. Despite this, the measured simulated core cycles fall on every workload. Depth 2/4 is functionally identical for several small cases and changes throughput mainly where overlapping reads are available.

## Evidence boundaries

- The five-workload cycle sum is only an aggregate of these independent Matrix cases, not an end-to-end application latency.
- `MAC/cycle` and utilization are derived from simulated Matrix-core cycles. Values labeled effective GOPS at 250 MHz in raw logs use a normalization assumption, not a measured clock.
- The one-cycle behavioral SPAD is not an SRAM timing model. This result is not ASIC PPA, silicon performance, or a TinyNPU head-to-head comparison.
- One seed establishes this R89 rerun; it does not replace R82's separate 3-seed 165/165 benchmark evidence.
- No product RTL, SPEC, or UVM source changed for this benchmark; no requirement disposition changes. `CL-DV-v1.0` remains HOLD.

## Compile/run SHA-256 manifest

Each row lists `compile.log`, then `run.log`, from the stated `/tmp` root.

| Configuration | Compile SHA-256 | Run SHA-256 |
|---|---|---|
| d2 / prefetch 0 / cache 0 | `911ebbff44a5d3f8ea154e0671aa41f7993c8e915d97f2462e657b0fbdb26cb8` | `1a9ea79d7740628fc92874cfddf8e4d21f0fcd650b9984bfbf7adaea4d28935e` |
| d2 / prefetch 0 / cache 1 | `a6689d01a0fde37149a2d9686d7a133593869e7b9a4f121ab3615cab99737178` | `61bbe4099905254e48b9101d2579aa70e418368152940abe1ea37de9a45bae32` |
| d2 / prefetch 1 / cache 0 | `db5fa259a4fbbfb1529245961761aa177baa1fe0a6de6d556e936a824d834435` | `2f279337a5e3bf30834306c9496ae201ce6831433715ef2953686524a31d0cdd` |
| d2 / prefetch 1 / cache 1 | `672df03ef476dd77232d52358316e3650f4fde57ce76ed8a87c86eb32296c201` | `cea3abb5b51d76b7099fe76296fb2181a6115f42607cccb964c2216c1ff6b3b4` |
| d4 / prefetch 0 / cache 0 | `028bf8968b6b1c434ab0aaed230b2b9c552bdfe66b7d4d117d9af41f94dcac3e` | `e61911ab9d1cd3b7b9cbb97bd3337e60a3dd003822b03e8bca6f89bfbaf1e365` |
| d4 / prefetch 0 / cache 1 | `4b7df5742f2ed282d11da744901020f2b1312ffc2dc5f59fe9d84c30fef65953` | `9b5efaeb7b43191715e76815cd7b3f1a84ca4e10e95a3d5c37c3d04874d506d7` |
| d4 / prefetch 1 / cache 0 | `fd43a46bf0e1ddce99dd0fb78eacb8c6b5ade27c331b7eb293b07411ab63100b` | `d56669fb56088dea89b0734c9a11497980339c1715fa422d40fb0dd4eeeca6eb` |
| d4 / prefetch 1 / cache 1 | `63e0e5d14fd503b1683c0d1f7fcb6a6888045567533c6d1a6e694f884473063b` | `2a1898bfbb31728ba106b10abca3d5587ca85b87ef719fae481e9819c3f137bf` |

CSV SHA-256: `0314a8df69aa9245e1335942c2ccb00a45b417d0caca23a1e6a4044355e40045`.
