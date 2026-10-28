# Compute Cluster Performance Benchmark and TinyNPU Reference — 2026-10-28

## Scope and comparison rule

The controlling NMAForge measurements in this report were replayed on source SHA `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9` from a detached clean worktree. They include three-seed Matrix scaling, three-seed eight-way controller ablation, and real-top Compute Cluster serial/staged/parallel measurements. Older TinyNPU matched-workload results are retained as a separately bounded comparison on the earlier product RTL SHA `c0832e5c822de1a03f82751d5ff8f831d0addb98`. The TinyNPU reference is pinned to `Atharva-Paranjpe/TinyNPU` commit `f965fe9462464fc8c9f944c491c3b81d45af1165`; the selected project documents an 8×8/64-DSP INT8 systolic array and a 16×16 logical GEMM.

The Matrix results are core-cycle measurements with a one-cycle behavioral SPAD response, not SRAM timing, ASIC PPA, or a speed grade. The TinyNPU comparison uses a matched 8×8 physical array and workload but different storage/output behavior; it does not support an implementation-level speedup claim. No theoretical TOPS or 250 MHz normalized throughput is presented as measured Fmax.

## Current-source replay summary

The selected source SHA `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9` was tested in `/tmp/nmaforge_closure_9d9e0f_clean` with VCS `V-2023.12-SP1_Full64`:

| Benchmark | Seeded result | Workload and model |
|---|---|---|
| Matrix physical-array scaling | 45/45 PASS | 4×4, 8×8 and 16×16 arrays × 5 GEMM shapes × seeds `20261025/26/27`; fixed depth 4, prefetch/cache enabled, one-cycle behavioral SPAD |
| Matrix controller ablation | 120/120 PASS | Depth 2/4 × Prefetch OFF/ON × A-Cache OFF/ON × 5 GEMM shapes × seeds `20261025/26/27`; 16×16 physical array |
| Real Compute Cluster serial/staged/parallel | 3 seeds PASS, deterministic counts | Production Matrix/CNM/SFU/SFU tasks, real seven-engine top and SPAD owner path; exact per-seed logs below |

For the 16×16 physical array, the largest workload `32×32×64` completes in 1,187 cycles with 55.211 MAC/cycle, 21.57% array utilization, 6,144 read bytes, 4,096 write bytes, and 136 bank / 72 line stalls. Against the same configuration's depth-2/no-prefetch/no-cache baseline, the eight-way ablation reduces cycles from 1,698 to 1,187 (30.1%) and banked read traffic from 512 to 384 requests (25%). These values use the behavioral bank model; the 250 MHz column is normalization only.

The real-top task set reports serial Matrix→CNM→SFU = 1,239 cycles; staged Matrix+CNM then dependent SFU = 1,070 cycles (1.158×); and four queued Matrix/CNM/SFU/SFU tasks = 1,137 cycles versus 1,696 serial (1.492×). Completion order was preserved. Shared-SPAD contention was 32 cycles in the staged case and 38 cycles in the four-task case. These mixed-engine cycles do not have a meaningful single MAC/cycle or array-utilization figure.

## 1. Exact-candidate Matrix size sweep: 4×4, 8×8, 16×16

Current-source command/log checksums are in the [9d9e0f0 replay manifest](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md), run `R29`.

Command recorded in the project roadmap:

```sh
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261025 BENCH_OUT_DIR=/tmp/nmaforge_final_9d9e0f_matrix_size_20261025
# Repeat with SEED=20261026 and 20261027, writing to matching output directories.
```

The three exact-candidate seeds each swept physical arrays 4×4, 8×8, and 16×16 across five GEMM shapes (45/45 cases total). All runs use one-cycle behavioral bank responses. `MAC/cycle = M×N×K / cycles`; utilization divides MAC/cycle by the physical array's MAC count. Read bytes are observed bank reads × 16 bytes; write bytes are the 32-bit output image size. These remain behavioral core-cycle measurements.

| GEMM (M×N×K), physical 16×16 | Cycles | MAC/cycle | Array utilization | SPAD read/write bytes | Bank / line stalls |
|---|---:|---:|---:|---:|---:|
| 4×4×32 | 76 | 6.737 | 2.63% | 256 / 64 | 3 / 0 |
| 8×8×32 | 116 | 17.655 | 6.90% | 512 / 256 | 12 / 3 |
| 16×16×32 | 233 | 35.159 | 13.73% | 1,024 / 1,024 | 24 / 28 |
| 16×32×32 | 417 | 39.290 | 15.35% | 1,536 / 2,048 | 38 / 65 |
| 32×32×64 | 1,187 | 55.211 | 21.57% | 6,144 / 4,096 | 136 / 72 |

Physical-array scaling for the fixed 16×16×32 workload is:

| Physical array on 16×16×32 | Cycles | MAC/cycle | Array utilization | SPAD read/write bytes | Bank / line stalls |
|---|---:|---:|---:|---:|---:|
| 4×4 | 957 | 8.560 | 53.50% | 2,560 / 1,024 | 63 / 17 |
| 8×8 | 397 | 20.635 | 32.24% | 1,536 / 1,024 | 27 / 31 |
| 16×16 | 233 | 35.159 | 13.73% | 1,024 / 1,024 | 24 / 28 |

The larger physical array reduces cycles and operand reads for this workload. Its utilization percentage is lower because the denominator rises from 16 to 64 to 256 MAC lanes. These are measured testbench cycles and memory transactions, not SRAM timing or ASIC/FPGA PPA.

Every seed produced the same deterministic cycle/event values. Raw log paths:

- `/tmp/nmaforge_final_9d9e0f_matrix_size_20261025/array_{4,8,16}/run.log`
- `/tmp/nmaforge_final_9d9e0f_matrix_size/array_{4,8,16}/run.log` (seed `20261026`)
- `/tmp/nmaforge_final_9d9e0f_matrix_size_20261027/array_{4,8,16}/run.log`

The historical `c0832e5` size sweep was indexed as RTM run `R17`. The current-source run uses the same workload and is indexed as `R29`; exact commands and checksums are in the replay manifest.

## 2. Exact-candidate eight-way outstanding/prefetch/cache ablation

Command and run ID:

```sh
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261025 MATRIX_CONFIG_OUT=/tmp/nmaforge_final_9d9e0f_matrix_config_20261025
# Repeat with SEED=20261026 and 20261027, writing to matching output directories.
```

All eight configurations ran all five workloads over three seeds (120/120 PASS) with a fixed 16×16 physical array and one-cycle behavioral bank response. `dX/pY/cZ` means outstanding read depth X, next-K prefetch Y, and A-tile cache Z. Cells list `cycles / bank reads / bank stalls`. The results were deterministic and identical across the three seeds.

| Workload | d2/p0/c0 | d2/p0/c1 | d2/p1/c0 | d2/p1/c1 | d4/p0/c0 | d4/p0/c1 | d4/p1/c0 | d4/p1/c1 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99/16/4 | 99/16/4 | 76/16/3 | 76/16/3 | 99/16/4 | 99/16/4 | 76/16/3 | 76/16/3 |
| 8×8×32 | 135/32/11 | 135/32/11 | 116/32/12 | 116/32/12 | 135/32/11 | 135/32/11 | 116/32/12 | 116/32/12 |
| 16×16×32 | 265/64/25 | 265/64/25 | 248/64/21 | 248/64/21 | 242/64/21 | 242/64/21 | 233/64/24 | 233/64/24 |
| 16×32×32 | 504/128/53 | 445/96/38 | 483/128/50 | 424/96/36 | 486/128/59 | 442/96/46 | 469/128/51 | 417/96/38 |
| 32×32×64 | 1698/512/156 | 1471/384/123 | 1555/512/165 | 1294/384/117 | 1636/512/194 | 1411/384/134 | 1443/512/200 | 1187/384/136 |

The following table compares baseline `d2/p0/c0` with `d4/p1/c1`. SPAD bytes are `bank_reads×16` read bytes plus `M×N×4` output-write bytes. Speedup is baseline cycles divided by enabled-configuration cycles. Array utilization uses 256 physical MAC lanes.

| Workload | Baseline → d4/p1/c1 cycles | MAC/cycle | Utilization | SPAD read/write bytes | Bank stalls | Speedup |
|---|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99 → 76 | 5.172 → 6.737 | 2.02% → 2.63% | 256/64 → 256/64 | 4 → 3 | 1.303× |
| 8×8×32 | 135 → 116 | 15.170 → 17.655 | 5.93% → 6.90% | 512/256 → 512/256 | 11 → 12 | 1.164× |
| 16×16×32 | 265 → 233 | 30.913 → 35.159 | 12.08% → 13.73% | 1,024/1,024 → 1,024/1,024 | 25 → 24 | 1.137× |
| 16×32×32 | 504 → 417 | 32.508 → 39.290 | 12.70% → 15.35% | 2,048/2,048 → 1,536/2,048 | 53 → 38 | 1.209× |
| 32×32×64 | 1,698 → 1,187 | 38.596 → 55.211 | 15.08% → 21.57% | 8,192/4,096 → 6,144/4,096 | 156 → 136 | 1.430× |

Observed effects:

- Prefetch reduces cycles on every shape in this run. Its benefit is largest when the workload has enough K work to overlap; the 4×4×32 and 8×8×32 cases gain cycles without reducing bank reads.
- A-tile cache changes no read count for the single-N-tile shapes. It reduces bank-read bytes by 25% for 16×32×32 and 32×32×64, with corresponding cycle reductions.
- Depth 4 has modest additional gains over depth 2 in this workload set. Bank-stall counts are not monotonically lower: more outstanding requests can increase counted stalls while total latency falls.

Raw CSVs: `/tmp/nmaforge_final_9d9e0f_matrix_config_20261025/matrix_config_comparison.csv`, `/tmp/nmaforge_final_9d9e0f_matrix_config/matrix_config_comparison.csv` (seed `20261026`) and `/tmp/nmaforge_final_9d9e0f_matrix_config_20261027/matrix_config_comparison.csv`; per-configuration logs are in sibling directories. Current-SHA commands and results are RTM run `R29`. This closes repeatability for the local Matrix ablation; it remains a one-cycle behavioral SPAD model, not real SRAM timing or ASIC PPA.

## 3. Real Compute Cluster serial and parallel execution

Current-source clean run `CLUSTER-S2-CLEAN-3S-9D9E0F` measured identical descriptor sets in seeds `20261025/20261026/20261027`. The counter interval starts at the doorbell write and ends at the observed CPLQ tail update; descriptor programming is excluded, while AXI-Lite issue/poll cycles are included. All seeds produced the same deterministic cycle values.

| Mode | Work | Cycles | Speedup | Observed shared-memory stall |
|---|---|---:|---:|---:|
| Serial | Matrix → CNM → SFU | 565 + 217 + 457 = 1,239 | 1.000× | baseline |
| Staged | Matrix + CNM overlap, then dependent SFU | 613 + 457 = 1,070 | 1.158× | 32 shared-admission contention cycles |
| Four-task queued | Matrix, CNM, SFU, SFU; same-engine SFU tasks serialize | 1,696 → 1,137 | 1.492× | 38 shared-SPAD contention cycles |
| Active reset recovery | Reset active Matrix/SFU tasks, then run a recovery SFU | 307 cycles to recovery completion | — | 2 accepted reads dropped from reset epoch |

Completion IDs remained ordered (`0700,0701,0702` and `0600–0603`). This is real-top task sequencing with the production compute engines and SPAD owner path. These mixed workloads combine Matrix/CNM/SFU, so a single MAC/cycle or array-utilization number is not meaningful; per-mode SPAD byte totals were not separately captured. The current-candidate per-seed logs are `/tmp/nmaforge_final_9d9e0f_uvm/seed_{20261025,20261026,20261027}/run.log`.

## 4. Matched TinyNPU INT8 GEMM

The external reference is pinned to `Atharva-Paranjpe/TinyNPU` commit `f965fe9462464fc8c9f944c491c3b81d45af1165`. Its README describes signed INT8 input/weights, INT32 accumulation, an 8×8/64-DSP physical array, and a tiled logical 16×16 GEMM. It reports 1,800 cycles through `done` at a 100 MHz testbench target. See the [pinned project](https://github.com/Atharva-Paranjpe/TinyNPU/tree/f965fe9462464fc8c9f944c491c3b81d45af1165) and [published GEMM result](https://github.com/Atharva-Paranjpe/TinyNPU/blob/f965fe9462464fc8c9f944c491c3b81d45af1165/README.md).

On 2026-10-28, both RTL testbenches ran the same deterministic signed INT8 `16×16×16` A/B matrices and independently checked all INT32 outputs against the same integer GEMM formula. Both used an 8×8 physical array. Inputs were resident before the timer; the NMAForge test uses one-cycle behavioral bank responses.

| Metric | NMAForge Matrix core | TinyNPU tiled GEMM |
|---|---:|---:|
| Logical operation / physical array | 16×16×16 / 8×8 | 16×16×16 / 8×8 |
| Useful MACs | 4,096 | 4,096 |
| Cycles to `done` | 298 | 1,800 |
| Cycles through final output | `done` follows complete SPAD writeback | 2,056 (256 result words streamed at 1/cycle) |
| MAC/cycle to `done` | 13.745 | 2.276 |
| MAC/cycle to final output | 13.745 | 1.992 |
| Array occupancy estimate | 21.48% | 3.56% to `done`; 3.11% through final output |
| Memory traffic observed in timed interval | 768 B reads + 1,024 B writes | Internal matrix buffers; no external memory port in this test |
| Stalls observed | 18 bank stalls + 21 line-write stalls | No output backpressure model |

NMAForge’s 298-cycle window includes operand reads and 64 128-bit line writes. TinyNPU’s documented `done` precedes its 256-word result stream, so the 2,056-cycle row is the closer output-complete endpoint. TinyNPU loads both 256-element matrices before the counter starts; those 512 single-element buffer-load cycles are excluded, just as NMAForge’s preloaded SPAD initialization is excluded. These are cycle measurements for the stated RTL testbenches and storage models, not an implementation-level speedup claim.

### TinyNPU simulation environment

VCS `V-2023.12-SP1_Full64` reproduced the 1,800-cycle `done`, 1,801 first output, and 2,056 last output, with 256/256 results matching its software Golden and zero index errors. The local VCS installation has no Xilinx UNISIM `DSP48E1` model; the original source also has variables written from multiple `always_ff` blocks, which VCS rejects under its single-writer check. For this functional run only, a `/tmp` copy changed `always_ff` to `always`, and a `/tmp` functional model supplied the configured combinational signed multiply (`MREG=PREG=0`). No TinyNPU source or NMAForge product RTL was changed. This surrogate establishes functional results and the RTL controller cycle count; it does not validate the vendor primitive model or FPGA timing.

## 5. Matched simple CNN workload

TinyNPU has a GEMM/ReLU path and no native 3×3 convolution opcode in the pinned revision. We therefore represented one `3×3` single-channel image and one `3×3` INT8 filter as a padded 16×16×16 GEMM (`im2col` row by filter column); only `C[0,0]` is a useful output. The same nine pixel bytes and nine weight bytes were loaded into NMAForge’s native Conv engine. Both independent checks produced INT32 `-30`.

| Metric | NMAForge native Conv | TinyNPU GEMM lowering |
|---|---:|---:|
| Useful convolution MACs | 9 | 9 of 4,096 padded GEMM positions |
| Physical array / operation | Dedicated 3×3 line-buffer engine | 8×8 array; padded 16×16 GEMM |
| Cycles to `done` | 66 | 1,800 |
| Cycles through last output | 66; one word written before `done` | 2,056; 256 words streamed |
| SPAD traffic in timed interval | 72 B read + 4 B write, one-cycle model | Internal tile buffers; no external memory port |
| Data setup / transform | Inputs preloaded; excluded | Zero-padded matrix data preloaded; 512 interface load cycles excluded |

This is an operator-lowering comparison, not a native-convolution comparison. TinyNPU’s data transform and storage assumptions differ, and its fixed-size wrapper computes/streams the full padded matrix. The cycle difference documents the cost of that mapping; it is not presented as a portable speedup factor.

Run IDs and artifacts for both matched workloads are `R19` in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). NMAForge logs are under `/tmp/nmaforge_matrix_tinynpu_match_c0832e5_20261028/` and `/tmp/nmaforge_cnn_tinynpu_match_c0832e5_20261028/`; the TinyNPU compile and run logs, temporary primitive model and testbench shims are under `/tmp/nmaforge_tinynpu_match_f965fe9/`. Exact source identities, commands, and SHA-256 checksums are in the [R19 benchmark manifest](COMPUTE_CLUSTER_BENCHMARK_R19_MANIFEST_2026-10-28.md).

## 6. Benchmark limits

The local Matrix size sweep and eight-way ablation remain core-cycle measurements using one-cycle behavioral SPAD. The common TinyNPU GEMM uses the same 8×8 array dimension, operand values, K, INT8/INT32 types and start-to-completion observation, but the storage interface/output bandwidth differ. The CNN case is software lowering because TinyNPU has no native convolution engine. TinyNPU’s Artix-7 implementation timing/resources and NMAForge’s cycle counters are different evidence classes; there is no candidate-specific matched ASIC/FPGA PPA in this report. The 250 MHz conversion in the Matrix logs is a normalization point, not measured Fmax, and no theoretical TOPS is described as measured throughput.
