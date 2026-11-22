# Round 3 — Phase 2: GEMV and Compute-Engine Dataflow A/B

**Disposition: PARTIAL.** The GEMV cache/prefetch experiment and standalone Matrix/CNM measurements completed. They support retaining B-fold reuse for the tested GEMV shapes, with shape-dependent prefetch. The requested Mini CNN host-layout A/B has not been rerun at this source SHA; no layout optimization is claimed.

## GEMV four-way ablation

| Item | Value |
|---|---|
| RTL/test source SHA | `c4c2970ad8e66c93e00e854ef3befff4ccc9188b` |
| Run | 48 cases; seeds `20261122`, `20261123`, `20261124` |
| Physical array / outstanding reads | 16×16 / 4 |
| SPAD | Registered four-bank behavioral model with seeded ready/latency variation |
| Golden | All 48 cases bit-exact |
| Command | `make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation SEEDS='20261122 20261123 20261124' PHYSICAL_ARRAY_SIZE=16 OUTSTANDING_DEPTH=4 A_TILE_CACHE_ENABLE=1 GEMV_FOUR_WAY_OUT=/tmp/nmaforge_round3_gemv_ablation_20261122` |

The checked-in raw CSV removes only local absolute log-path columns; per-run seed, configuration, timing, traffic and profile fields remain. Summary values are arithmetic means over three paired seeds. `paired_cycle_reduction_vs_off_off_pct` compares a configuration against the same shape with cache off and prefetch off.

| M×N×K | Cache | Prefetch | Mean cycles | Mean read B | Reduction vs off/off |
|---|---:|---:|---:|---:|---:|
| 8×16×19 | 0 | 0 | 197.00 | 864 | 0.00% |
| 8×16×19 | 0 | 1 | 190.00 | 864 | 3.55% |
| 8×16×19 | 1 | 0 | 151.33 | 560 | 23.19% |
| 8×16×19 | 1 | 1 | 151.00 | 560 | 23.35% |
| 8×16×65 | 0 | 0 | 537.00 | 2,720 | 0.00% |
| 8×16×65 | 0 | 1 | 512.00 | 2,720 | 4.66% |
| 8×16×65 | 1 | 0 | 388.67 | 1,696 | 27.62% |
| 8×16×65 | 1 | 1 | 376.33 | 1,696 | 29.92% |
| 16×16×19 | 0 | 0 | 393.33 | 1,728 | 0.00% |
| 16×16×19 | 0 | 1 | 385.00 | 1,728 | 2.12% |
| 16×16×19 | 1 | 0 | 258.67 | 816 | 34.24% |
| 16×16×19 | 1 | 1 | 260.00 | 816 | 33.90% |
| 16×16×65 | 0 | 0 | 1,079.33 | 5,440 | 0.00% |
| 16×16×65 | 0 | 1 | 1,031.33 | 5,440 | 4.45% |
| 16×16×65 | 1 | 0 | 630.00 | 2,368 | 41.63% |
| 16×16×65 | 1 | 1 | 617.00 | 2,368 | 42.83% |

Cache is the consistent traffic and latency contributor in this matrix: it saves 304–3,072 bytes of reads per command versus cache off, depending on shape. Prefetch without cache reduces cycles by about 2.1–4.7% and does not reduce bytes. With cache enabled, prefetch is neutral/slightly negative for 16×16×19 (260 vs 258.67 mean cycles), and positive for the other three shapes. This argues for a shape-aware software policy, not a blanket RTL change. Overlap and stall counters are event counters and are not added to exclusive command-state cycles.

## Standalone Matrix and CNM microbench

The `ai_cnm_compare` and `ai_tensor_a3_gemm_bench` targets both passed using all-+1 INT8 inputs and their local directed checks. These are standalone compute-engine tests; they do not traverse Product Top, shared SPAD arbitration, or a matched Matrix `0x52` GEMV path.

| Length | Useful MACs | CNM GEMV cycles | Matrix A3 GEMM cycles | Matrix cycle change |
|---:|---:|---:|---:|---:|
| 16 | 1,024 | 153 | 90 | −41.2% |
| 64 | 4,096 | 537 | 330 | −38.5% |
| 256 | 16,384 | 2,073 | 1,290 | −37.8% |

The result only compares those two standalone operators and their differing output shapes. It is not a system-level Matrix-GEMV claim. No area, timing, power or synthesis comparison was run.

VCS run log SHA-256: CNM compile `127be430d71e0829e932dda53fdd7ea4aa415aba89f19ee8e20cb89d8adf8b21`; CNM run `41d109f30865cf560000a25acb7958d04a97e3b57e1a06db98af0e67ec84269f`; Matrix compile `24d865258558f10f54d8d9236e26c3e96297971e5567a0ba445e2fc71664bb0e`; Matrix run `c882e29aaa418d34814d8435ad7005ae7fb0c72a1cbc9edc4c61e39a63ee7995`. Local logs: `dv/subsystem/top_smoke/sim/ai_cnm_a2_gemv_bench_{comp,run}.log` and `ai_tensor_a3_gemm_bench_{comp,run}.log`.

## Reproduction and data

Aggregate the three raw seed summaries with:

```bash
python3 benchmark/representative/round3/summarize_gemv_four_way.py \
  --input-dir /tmp/nmaforge_round3_gemv_ablation_20261122 \
  --raw-out benchmark/representative/round3/round3_gemv_four_way_3seed.csv \
  --summary-out benchmark/representative/round3/round3_gemv_four_way_3seed_summary.csv
```

Raw aggregate: [`round3_gemv_four_way_3seed.csv`](../../benchmark/representative/round3/round3_gemv_four_way_3seed.csv). Paired mean summary: [`round3_gemv_four_way_3seed_summary.csv`](../../benchmark/representative/round3/round3_gemv_four_way_3seed_summary.csv). Original per-seed logs remain under `/tmp/nmaforge_round3_gemv_ablation_20261122`; simulator databases and local absolute log paths are not committed.

## Open items

- The Mini CNN 1,080-cycle host-layout cost is not remeasured in a current-source A/B against DMA/Repack or fused-consumer layout; CNN layout optimization remains open.
- Matrix A3 vs banked CNM GEMV comparisons are not equal-shape full-path comparisons and do not establish a Product Top winner.
- No RTL was changed. Any future RTL optimization must start from a reproducible bottleneck and be followed by focused functional checks.
