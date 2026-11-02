# Compute Cluster Matrix size and configuration benchmark — R191

**Run ID:** `R191-MATRIX-SIZE-CONFIG-3S-20261102`  
**Result:** PASS, 165/165 independent Golden points; three seeds produce identical cycle counts.  
**Clean source checkout:** commit `c95ab5e1446d4afbfdbb945d748124e551e2bd55`, tree `8762e7f7e7e933b480e9beaad3c9fb286c4c5c2b`.  
**Tool/model:** Synopsys VCS `V-2023.12-SP1_Full64`; 10 ns test period; behavioral SPAD with one-cycle bank response.

## Array size

Five GEMM workloads run on 4×4, 8×8, and 16×16 arrays with fixed seeds `20261025`, `20261026`, and `20261027`. All 45 points pass the independent Golden check on each seed; the cycle counts are identical across seeds.

| Workload | 4×4 cycles | 8×8 cycles | 16×16 cycles | 16×16 MAC/cycle | 16×16 utilization | 16×16 SPAD bytes |
|---|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 76 | 76 | 76 | 6.737 | 2.63% | 320 |
| 8×8×32 | 259 | 116 | 116 | 17.655 | 6.90% | 768 |
| 16×16×32 | 957 | 397 | 233 | 35.159 | 13.73% | 2,048 |
| 16×32×32 | 1,788 | 709 | 417 | 39.290 | 15.35% | 3,584 |
| 32×32×64 | 6,543 | 2,447 | 1,187 | 55.211 | 21.57% | 10,240 |

The 4×4×32 case is setup dominated and takes 76 cycles at every array size. For 32×32×64, the 16×16 array takes 5.51× fewer cycles than 4×4. The 16×16 array utilization reaches 21.57% for that workload; this does not establish sustained system utilization.

## Eight-configuration ablation

Each of the five workloads runs all Depth 2/4 × Prefetch OFF/ON × A-Tile Cache OFF/ON configurations on the fixed 16×16 array. The table compares `D2/P0/C0` with `D4/P1/C1`; the CSV retains all 120 configuration points across three seeds.

| Workload | Baseline → D4/P1/C1 cycles | Speedup | Bank-read bytes | Bank stalls | Line stalls |
|---|---:|---:|---:|---:|---:|
| 4×4×32 | 99 → 76 | 1.30× | 256 → 256 | 4 → 3 | 1 → 0 |
| 8×8×32 | 135 → 116 | 1.16× | 512 → 512 | 11 → 12 | 2 → 3 |
| 16×16×32 | 265 → 233 | 1.14× | 1,024 → 1,024 | 25 → 24 | 22 → 28 |
| 16×32×32 | 504 → 417 | 1.21× | 2,048 → 1,536 | 53 → 38 | 22 → 65 |
| 32×32×64 | 1,698 → 1,187 | 1.43× | 8,192 → 6,144 | 156 → 136 | 74 → 72 |

Across these five workloads, the cycle sum falls from 2,701 to 2,029 (24.88%). For the two workloads spanning multiple A macro tiles, A-Tile Cache reduces bank-read bytes by 25%. The 16×32×32 Line-stall count rises from 22 to 65, so the cache traffic reduction does not translate proportionally into cycle savings. Benefits depend on shape.

## Reproduction

All simulator runs were launched from detached clean worktree `/tmp/nmaforge_r191_clean` at the source commit above.

```sh
for seed in 20261025 20261026 20261027; do
  VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
    make -C dv/block/compute/matrix/sim matrix-size-benchmark \
      SEED="$seed" BENCH_OUT_DIR="/tmp/nmaforge_r191_matrix_size/seed_$seed"
done

for seed in 20261025 20261026 20261027; do
  VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
    make -C dv/block/compute/matrix/sim matrix-config-comparison \
      SEED="$seed" MATRIX_CONFIG_OUT="/tmp/nmaforge_r191_matrix_config/seed_$seed"
done

python3 tools/summarize_matrix_r152_three_seed.py \
  --source-sha c95ab5e1446d4afbfdbb945d748124e551e2bd55 \
  --run-label R191 --run-date 20261102 \
  --seed 20261025 --seed 20261026 --seed 20261027 \
  --size-root 20261025=/tmp/nmaforge_r191_matrix_size/seed_20261025 \
  --size-root 20261026=/tmp/nmaforge_r191_matrix_size/seed_20261026 \
  --size-root 20261027=/tmp/nmaforge_r191_matrix_size/seed_20261027 \
  --config-root 20261025=/tmp/nmaforge_r191_matrix_config/seed_20261025 \
  --config-root 20261026=/tmp/nmaforge_r191_matrix_config/seed_20261026 \
  --config-root 20261027=/tmp/nmaforge_r191_matrix_config/seed_20261027 \
  --out docs/benchmark/compute_cluster_matrix_r191.csv
```

## Evidence and limits

- [R191 CSV](compute_cluster_matrix_r191.csv): 165 rows; every Golden result is `PASS`; SHA-256 `6fd8aedd2d903d048697c697e9da9c932416be90854140808693ae17d9d824c7`.
- Logs-only archive: `/tmp/nmaforge_r191_matrix_evidence.tar.gz`, SHA-256 `367cba2dcf75d6c652e97fceb33a9ae896128d01130b3a155122e97949776e4c`.
- Archive manifest: `/tmp/nmaforge_r191_matrix_evidence_manifest.txt`, SHA-256 `dde1b74dab96a81aa858939a3faa5d42762cafb69eb4958ea45a882c47e660df`; 70 entries include simulator compile/run logs, per-seed configuration CSVs, and the aggregate CSV.
- Thirty-three VCS compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostic. Every run logs the `MATRIX_SIZE_BENCHMARK_PASS` marker.

These are Matrix-core RTL cycle and behavioral-SPAD traffic measurements. The 250 MHz GOPS column is a normalization assumption, not measured Fmax or silicon throughput. SRAM timing, system-level throughput, TinyNPU common-memory comparison, and ASIC area/power remain outside this run. This evidence does not close integrated/system `REQ-CL-028`; Compute Cluster v1.0 remains **HOLD**.
