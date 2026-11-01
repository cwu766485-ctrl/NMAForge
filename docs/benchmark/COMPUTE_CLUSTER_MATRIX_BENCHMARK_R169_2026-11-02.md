# Compute Cluster Matrix size and configuration benchmark — R169

**Run ID:** `R169-MATRIX-3S-20261102`  
**Result:** PASS, 165/165 independent Golden points.  
**Measured source checkout:** `4253bbe695482ddb11275673013e27eab3a76d7a`, tree `b4bb3fafa47e778176ccacfb3c426b26a9768860`.  
**Tool/model:** Synopsys VCS `V-2023.12-SP1_Full64`, 10 ns test period, behavioral SPAD with one-cycle bank response. The Matrix benchmark RTL and testbench are unchanged from the previously reviewed R152 source set.

## Array-size sweep

Each array ran the five listed workloads on seeds `20261025`, `20261026`, and `20261027`. The cycle counts were identical across all three seeds.

| Workload | 4×4 cycles | 8×8 cycles | 16×16 cycles | 16×16 MAC/cycle | 16×16 array utilization | 16×16 SPAD bytes |
|---|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 76 | 76 | 76 | 6.737 | 2.63% | 320 |
| 8×8×32 | 259 | 116 | 116 | 17.655 | 6.90% | 768 |
| 16×16×32 | 957 | 397 | 233 | 35.159 | 13.73% | 2,048 |
| 16×32×32 | 1,788 | 709 | 417 | 39.290 | 15.35% | 3,584 |
| 32×32×64 | 6,543 | 2,447 | 1,187 | 55.211 | 21.57% | 10,240 |

The smallest workload is setup and memory dominated: all three array sizes take 76 cycles. For 32×32×64, 16×16 takes 5.51× fewer cycles than 4×4. Even at that largest workload, measured 16×16 utilization is 21.57%, so this sweep does not establish a high sustained utilization target.

## Eight-configuration ablation

Each workload ran all configurations of Outstanding Depth 2/4 × Next-K Prefetch OFF/ON × A-Tile Cache OFF/ON. The table compares the baseline `D2/P0/C0` with `D4/P1/C1`; all eight configuration rows per seed are in the CSV.

| Workload | Baseline → D4/P1/C1 cycles | Speedup | SPAD read bytes | Bank stalls | Line stalls |
|---|---:|---:|---:|---:|---:|
| 4×4×32 | 99 → 76 | 1.30× | 256 → 256 | 4 → 3 | 1 → 0 |
| 8×8×32 | 135 → 116 | 1.16× | 512 → 512 | 11 → 12 | 2 → 3 |
| 16×16×32 | 265 → 233 | 1.14× | 1,024 → 1,024 | 25 → 24 | 22 → 28 |
| 16×32×32 | 504 → 417 | 1.21× | 2,048 → 1,536 | 53 → 38 | 22 → 65 |
| 32×32×64 | 1,698 → 1,187 | 1.43× | 8,192 → 6,144 | 156 → 136 | 74 → 72 |

A-Tile Cache reduces bank-read traffic by 25% for the two workloads spanning multiple A macro tiles. The `16×32×32` result also has higher Line stall count (22 → 65), so its traffic reduction does not translate one-for-one into cycle reduction. Cache and prefetch are not uniformly beneficial on the smaller shapes; use per-shape results when selecting defaults.

## Reproduction

From repository root:

```sh
make -C dv/block/compute/matrix/sim matrix-size-benchmark SEED=20261025 BENCH_OUT_DIR=/tmp/nmaforge_r168_matrix_size_20261102/seed_20261025
make -C dv/block/compute/matrix/sim matrix-size-benchmark SEED=20261026 BENCH_OUT_DIR=/tmp/nmaforge_r168_matrix_size_20261102/seed_20261026
make -C dv/block/compute/matrix/sim matrix-size-benchmark SEED=20261027 BENCH_OUT_DIR=/tmp/nmaforge_r168_matrix_size_20261102/seed_20261027

make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=20261025 MATRIX_CONFIG_OUT=/tmp/nmaforge_r168_matrix_config_20261102/seed_20261025
make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=20261026 MATRIX_CONFIG_OUT=/tmp/nmaforge_r168_matrix_config_20261102/seed_20261026
make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=20261027 MATRIX_CONFIG_OUT=/tmp/nmaforge_r168_matrix_config_20261102/seed_20261027

python3 tools/summarize_matrix_r152_three_seed.py \
  --source-sha 4253bbe695482ddb11275673013e27eab3a76d7a \
  --run-label R169 --run-date 20261102 \
  --seed 20261025 --seed 20261026 --seed 20261027 \
  --size-root 20261025=/tmp/nmaforge_r168_matrix_size_20261102/seed_20261025 \
  --size-root 20261026=/tmp/nmaforge_r168_matrix_size_20261102/seed_20261026 \
  --size-root 20261027=/tmp/nmaforge_r168_matrix_size_20261102/seed_20261027 \
  --config-root 20261025=/tmp/nmaforge_r168_matrix_config_20261102/seed_20261025 \
  --config-root 20261026=/tmp/nmaforge_r168_matrix_config_20261102/seed_20261026 \
  --config-root 20261027=/tmp/nmaforge_r168_matrix_config_20261102/seed_20261027 \
  --out docs/benchmark/compute_cluster_matrix_r169.csv
```

The summarizer's optional `--run-label` and `--run-date` preserve the historical R152 defaults while allowing a replay to receive its actual Run ID. All 33 VCS compile logs have zero `Warning-`, `Error-`, and `[TFIPC]` markers.

## Evidence and limits

- [R169 CSV](compute_cluster_matrix_r169.csv): 165 rows, all Golden `PASS`; SHA-256 `e66f2c5867eb54aa2e734f63d6e63f45a78398a1c0d2f9bba05fa5051e2fc44c`.
- Logs-only evidence archive: `/tmp/nmaforge_r169_matrix_evidence_20261102.tar.gz`; SHA-256 `1781f044542aa71e6713bb33b05ce7bebe57b4774b6c64693d7778da534d017c`. It contains VCS compile/run logs, per-seed configuration CSVs, the aggregate CSV and checksums; simulator binaries and coverage databases are excluded.

These are Matrix-core RTL cycle and behavioral-SPAD traffic results, not full Compute Cluster throughput or TinyNPU common-memory measurements. `effective_gops_250mhz_assumption` is normalized to a 250 MHz assumption, not measured Fmax or silicon throughput. SRAM timing, ASIC area/power, GEMV/decode, and integrated multi-engine benchmarks remain separate work; `REQ-CL-028` remains PARTIAL and `CL-DV-v1.0` remains HOLD.
