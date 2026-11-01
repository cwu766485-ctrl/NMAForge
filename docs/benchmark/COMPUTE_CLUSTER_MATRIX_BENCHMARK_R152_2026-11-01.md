# Compute Cluster Matrix Benchmark — R152 — 2026-11-01

## Result

R152 reruns the Matrix array-size and microarchitecture ablation targets at the
R151 test source SHA `cc15b4841d2266f34ef8cacae7abd895890eb07a` (tree
`41ed9c384dd2ac70d65b06406ff399aca6c85bc1`). The same tree is published as
test-content commit `a49d3ffe7abd025cc54d384dc51eff1e6f583659`. Seeds
`20261025`, `20261026`, and `20261027` each pass 15 array-size cases and 40
ablation cases with independent full-output Golden checks: 165/165 points.

The benchmark RTL, testbench, and Makefile are byte-identical to the R82
three-seed benchmark sources. R152 adds a small checked-in log-to-CSV
summarizer so all current-candidate runs can be regenerated; see
[R82 report](COMPUTE_CLUSTER_MATRIX_BENCHMARK_R82_2026-10-30.md) for the prior
source-set evidence.

## Reproduction

Tool: Synopsys VCS `V-2023.12-SP1_Full64`. The behavioral SPAD returns bank
responses after one cycle. Simulation period is 10 ns.

```sh
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261025 BENCH_OUT_DIR=/tmp/nmaforge_r151_matrix_size_20261025
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261026 BENCH_OUT_DIR=/tmp/nmaforge_r151_matrix_size_20261031
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261027 BENCH_OUT_DIR=/tmp/nmaforge_r151_matrix_size_20261027

make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261025 MATRIX_CONFIG_OUT=/tmp/nmaforge_r151_matrix_config_20261025
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 MATRIX_CONFIG_OUT=/tmp/nmaforge_r151_matrix_config_20261031
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261027 MATRIX_CONFIG_OUT=/tmp/nmaforge_r151_matrix_config_20261027

python3 tools/summarize_matrix_r152_three_seed.py \
  --source-sha cc15b4841d2266f34ef8cacae7abd895890eb07a \
  --seed 20261025 --seed 20261026 --seed 20261027 \
  --size-root 20261025=/tmp/nmaforge_r151_matrix_size_20261025 \
  --size-root 20261026=/tmp/nmaforge_r151_matrix_size_20261031 \
  --size-root 20261027=/tmp/nmaforge_r151_matrix_size_20261027 \
  --config-root 20261025=/tmp/nmaforge_r151_matrix_config_20261025 \
  --config-root 20261026=/tmp/nmaforge_r151_matrix_config_20261031 \
  --config-root 20261027=/tmp/nmaforge_r151_matrix_config_20261027 \
  --out docs/benchmark/compute_cluster_matrix_r152.csv
```

Workloads in each sweep are `4×4×32`, `8×8×32`, `16×16×32`, `16×32×32`,
and `32×32×64`. Array sweep uses physical 4×4, 8×8, and 16×16 arrays. Ablation
keeps a 16×16 array and compares Outstanding Depth 2/4, Next-K Prefetch OFF/ON,
and A-Tile Cache OFF/ON. Each measured point checks the complete output image
against the independent signed INT8 Golden and verifies cycle/read-drain
accounting.

## Array-size sweep

Cycles at fixed Depth 4 / Prefetch ON / A-Tile Cache ON:

| Workload | 4×4 cycles | 8×8 cycles | 16×16 cycles | 16×16 MAC/cycle | 16×16 utilization |
|---|---:|---:|---:|---:|---:|
| 4×4×32 | 76 | 76 | 76 | 6.737 | 2.63% |
| 8×8×32 | 259 | 116 | 116 | 17.655 | 6.90% |
| 16×16×32 | 957 | 397 | 233 | 35.159 | 13.73% |
| 16×32×32 | 1,788 | 709 | 417 | 39.290 | 15.35% |
| 32×32×64 | 6,543 | 2,447 | 1,187 | 55.211 | 21.57% |

The small workload is setup and memory dominated: all three arrays take 76
cycles, and the 16×16 array is only 2.63% utilized. On `32×32×64`, the 16×16
array takes 5.51× fewer cycles than 4×4 under this fixed response model.

## Eight-configuration ablation

Baseline is Depth 2 / Prefetch OFF / A-Tile Cache OFF; comparison is Depth 4 /
Prefetch ON / A-Tile Cache ON:

| Workload | Baseline cycles | D4/P1/C1 cycles | Speedup | Bank-read bytes baseline → D4/P1/C1 | Bank stalls baseline → D4/P1/C1 | Line stalls baseline → D4/P1/C1 |
|---|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99 | 76 | 1.30× | 256 → 256 | 4 → 3 | 1 → 0 |
| 8×8×32 | 135 | 116 | 1.16× | 512 → 512 | 11 → 12 | 2 → 3 |
| 16×16×32 | 265 | 233 | 1.14× | 1,024 → 1,024 | 25 → 24 | 22 → 28 |
| 16×32×32 | 504 | 417 | 1.21× | 2,048 → 1,536 | 53 → 38 | 22 → 65 |
| 32×32×64 | 1,698 | 1,187 | 1.43× | 8,192 → 6,144 | 156 → 136 | 74 → 72 |

A-Tile reuse reduces operand reads by 25% on the two multi-macro-tile workloads.
The 16×32×32 and 32×32×64 end-to-end cycle counts fall by 17.3% and 30.1%,
respectively. The 16×32×32 case also incurs more Line stalls, so the read
savings do not translate one-for-one into elapsed cycles.

## Limits and open work

- This is Matrix-core RTL cycle/traffic evidence with a one-cycle behavioral
  SPAD model. It is not SRAM timing, ASIC PPA, or measured Fmax/power.
- `effective_gops_250mhz_assumption` is normalized to an assumed 250 MHz; it
  is not measured throughput on silicon.
- This is not a TinyNPU comparison or an integrated seven-engine benchmark.
  `REQ-CL-028` stays PARTIAL pending the remaining common-workload and
  system-level comparisons.
- The three seeds are all direct runs at the same candidate SHA and use the
  same 10 ns testbench clock and one-cycle behavioral SPAD response model.

## Evidence

- [Current-candidate detailed CSV](compute_cluster_matrix_r152.csv), 165 rows
  (15 array-size + 40 ablation points per seed); SHA-256
  `e3b46ea03915b146669b9f2209a9e4aaa66ef147a8a6b950395486edd32f2eb8`.
- Per-seed array logs: `/tmp/nmaforge_r151_matrix_size_{20261025,20261031,20261027}/`.
- Per-seed ablation CSV and logs:
  `/tmp/nmaforge_r151_matrix_config_{20261025,20261031,20261027}/`.
- Logs-only evidence archive: `/tmp/nmaforge_r152_matrix_evidence_3seed.tar.gz`,
  SHA-256 `01df4dda85702f49ea5717d2c53c11e45246448852ee4b53651e4e323c1b5541`;
  it includes compile/run logs and per-seed configuration CSVs, excludes
  simulator binaries and coverage databases.
- A full current-candidate R151 test/verification evidence bundle is documented
  in [R151 reset evidence](../verification/COMPUTE_CLUSTER_SCALAR_RESET_ACCEPTED_PREFIX_R151_2026-10-31.md).

R152 strengthens benchmark evidence for `REQ-CL-028`; it does not change the
38-row disposition (24 `PASS-SCOPED` / 14 `PARTIAL`) or the Compute Cluster
v1.0 **HOLD** decision.
