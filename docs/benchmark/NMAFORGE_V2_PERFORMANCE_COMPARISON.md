# NMAForge v2 Performance Comparison

**As of:** 2026-11-05  
**Product baseline:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Latest replay source/test SHA:** `17b09e068e988ca35480ffd638d865872e9ba564`

## Comparison boundary

The results below are separate Golden-checked RTL experiments. Each comparison
holds its workload and Seed fixed within the experiment. The Matrix size suite
uses a one-cycle behavioral SPAD; the product GEMV Cache×Prefetch suite uses a
registered four-bank behavioral SPAD with seeded ready/response latency; the
tile-forwarding ablation uses the Matrix-core directed responder. Their cycle
counts are not combined into one headline score.

All reported cycles are VCS RTL simulation. They are not measured SRAM access
time, silicon latency, ASIC frequency, area, power, or energy. The legacy
250 MHz conversion is only a normalization assumption. See the raw data in
the linked CSV/JSON files for every per-Seed record.

## Existing Matrix array and controller sweeps

Run `MATRIX-PERF-20261105-20261106-20261107-550ef39` used VCS
`V-2023.12-SP1_Full64`, 3 Seeds, and the same five Golden-checked shapes on
4×4, 8×8, and 16×16 physical array configurations. It passed 45/45 size
points. At 16×16, selected workload means are:

| Shape | Cycles | MAC/cycle | Array utilization | SPAD read/write |
|---|---:|---:|---:|---:|
| 16×16×32 | 229.7 | 35.728 | 14.0% | 1,024 / 1,024 B |
| 16×32×32 | 385.7 | 42.512 | 16.6% | 1,536 / 2,048 B |
| 32×32×64 | 1,177.7 | 55.652 | 21.7% | 6,144 / 4,096 B |

The associated 16×16-array ablation passed 120/120 points across depth 2/4,
Next-K Prefetch OFF/ON, A-Tile Cache OFF/ON, five shapes, and 3 Seeds. Compared
with depth 2/prefetch OFF/cache OFF, depth 4/prefetch ON/cache ON reduced
cycles by 21.4%, 8.8%, 9.1%, 24.4%, and 30.5% across the five shapes. For the
two shapes that reuse A across column tiles, A-cache reduced read traffic by
25%; the smaller shapes did not reduce traffic. Stall counters are reported
according to their individual semantics; overlapping wait/event counters are
not summed into an artificial partition.

Evidence: [P1 report](NMAFORGE_V2_P1_MATRIX_BENCHMARK.md),
[per-point CSV](../../benchmark/v2_p1_matrix_performance_550ef39.csv), and
[summary JSON](../../benchmark/v2_p1_matrix_performance_550ef39_summary.json).

## Product Shape-Adaptive GEMV Cache × Prefetch

Run `V2-GEMV-CACHE-PREFETCH-FOURWAY-20261105-07` used one 16×16 array (256
INT8 MACs), four outstanding reads, the registered four-bank behavioral SPAD,
four shapes (M8/M16, N16, K19/K65), four Cache×Prefetch configurations, and
three Seeds. All 48 complete output images passed the independent signed
INT8/INT32 Golden. The full per-command stage and stall data is in the
[ablation report](NMAFORGE_V2_GEMV_CACHE_PREFETCH_ABLATION.md),
[CSV](../../benchmark/v2_p2_gemv_cache_prefetch_4way.csv), and
[summary JSON](../../benchmark/v2_p2_gemv_cache_prefetch_4way_summary.json).

With Prefetch OFF, turning on the existing B-fold Cache produced:

| Shape | Cycles OFF→ON | Cycle change | Read bytes OFF→ON | Read change |
|---|---:|---:|---:|---:|
| M8×16×19 | 200.7→156.0 | −22.3% | 864→560 B | −35.2% |
| M8×16×65 | 544.3→391.0 | −28.2% | 2,720→1,696 B | −37.6% |
| M16×16×19 | 393.7→261.0 | −33.7% | 1,728→816 B | −52.8% |
| M16×16×65 | 1,075.0→627.3 | −41.6% | 5,440→2,368 B | −56.5% |

With Cache OFF, Prefetch reduced cycles by 2.5–4.5% in these tests without
reducing reads. With Cache ON, Prefetch changed cycles by −2.4%, −2.0%, +0.6%,
and +0.8% respectively. The last two are small regressions in this model.
The B-fold reuse result supports keeping the bounded reuse path; these results
do not justify a new bank-reordering scheduler without a conflict-focused
experiment and hardware cost evaluation.

### Fixed-candidate replay with cycle-partition closure

At source/test SHA `17b09e068e988ca35480ffd638d865872e9ba564`, the four-way
ablation was rerun with the same three Seeds and VCS `V-2023.12-SP1_Full64`.
The physical array is 16×16 (256 INT8 MACs), read outstanding depth is 4,
A-Tile Cache is enabled, and the Matrix controller is connected to a registered
four-bank behavioral SPAD model with seed-controlled ready/response latency.
This is Matrix-controller RTL evidence, not a full Compute Cluster contention
measurement.

The successful command was:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation \
  SEEDS='20261105 20261106 20261107' OUTSTANDING_DEPTH=4 \
  A_TILE_CACHE_ENABLE=1 PHYSICAL_ARRAY_SIZE=16 \
  GEMV_FOUR_WAY_OUT=/tmp/nmaforge_v2_gemv_four_way_17b09e0 \
  PYTHON=python3.12
```

All 48 shape/configuration/Seed points matched the independent Golden. Means
for each 3-Seed set:

| Shape | Cache OFF/PF OFF cycles → Cache ON/PF OFF | Read bytes OFF → ON | Cache ON/PF OFF → Cache ON/PF ON | Useful MAC/cycle, both ON | Array utilization, both ON |
|---|---:|---:|---:|---:|---:|
| 8×16×19 | 200.67 → 156.00 (−22.26%) | 864 → 560 (−35.19%) | 156.00 → 152.33 (−2.35%) | 15.97 | 6.24% |
| 8×16×65 | 544.33 → 391.00 (−28.17%) | 2,720 → 1,696 (−37.65%) | 391.00 → 383.00 (−2.05%) | 21.73 | 8.49% |
| 16×16×19 | 393.67 → 261.00 (−33.70%) | 1,728 → 816 (−52.78%) | 261.00 → 262.67 (+0.64%) | 18.52 | 7.23% |
| 16×16×65 | 1,075.00 → 627.33 (−41.64%) | 5,440 → 2,368 (−56.47%) | 627.33 → 632.33 (+0.80%) | 26.32 | 10.28% |

Output write traffic is unchanged by Cache/Prefetch (512 B for M=8,
1,024 B for M=16). Prefetch without B-fold Cache reduces cycles 2.49–4.47%
without reducing read bytes. With Cache enabled it helps the two M=8 cases by
2.05–2.35%, and regresses the M=16 cases by 0.64–0.80% in this model. The
bounded B-fold reuse accounts for the larger measured gain; the prefetch gain
is shape-dependent.

The summarizer now checks that mutually exclusive A/B/bias request and wait,
prep, MAC, write, next, done, error, error-drain and prefetch-wait state cycles
sum exactly to command cycles (48/48). MAC-active, arbiter, response,
writeback, bank/line stall, prefetch-overlap, occupancy and FIFO-full counters
are overlapping event/observer metrics and must not be added to that
partition. The both-enabled M16×16×65 means include 74.0 arbiter-stall,
20.0 response-wait, 47.7 bank-stall and 26.3 writeback-wait observations per
command; these values are diagnostic and overlap.

Machine outputs: [48-point CSV](../../benchmark/v2_p2_gemv_cache_prefetch_4way_17b09e0.csv),
[summary JSON](../../benchmark/v2_p2_gemv_cache_prefetch_4way_17b09e0_summary.json),
and [ablation chart](../../benchmark/v2_p2_gemv_cache_prefetch_4way_17b09e0.svg).
Logs-only archive `/tmp/nmaforge_v2_gemv_four_way_17b09e0_logs.tar.gz`,
SHA-256 `c22d07de2b86de467e8fe05d6426cfd5cb6bf8fada4260b4535a5badc6a24681`.

This single-client controller run does not exercise competing Matrix/CNM/SFU
traffic through the system SPAD Arbiter, nor does it isolate Bank-Aware Issue
benefit or its logic/timing cost. No scheduling RTL change is justified from
this result alone; the controlled Top contention experiment remains open.

## Fused output tile forwarding

At fixed candidate `33e85287fbf37187fccb76e97be6effe888670e9`, a three-Seed
Matrix-core OFF/ON ablation passed bit-exact Golden checks and a three-Seed
real Top CMDQ differential passed all output/completion checks. The core test's
mean consumer cycles are 141→118 (−16.31%); the two-command mean is 290→267
(−7.93%). The selected source-A line reads are 32→16 (512→256 B) per consumer.
Producer/consumer output writes remain present in both runs. The top-level
differential observes 16 baseline versus 0 forwarded source-A bank reads.

This is a bounded 16×16×16 chain. Core-cycle and selected-source traffic
results use different scopes from the full top run and are not an ASIC or
whole-model speedup. Details and machine data: [three-Seed replay](../verification/V2_P2_TILE_FORWARD_MULTISEED_REPLAY_2026-11-05.md)
and [raw CSV](../../benchmark/v2_p2_tile_forward_3seed.csv).

## TinyNPU comparison status

TinyNPU reference remains pinned at
`8216c22b762011aa20c05fc2768423fd12dda59d`. Current replay
`TINY-COMPARE-V2C3A59-S20261029` ran on NMAForge source SHA
`c3a59f08d8c07a8da973010d0f23d5d6d7eed61b`, VCS
`V-2023.12-SP1_Full64`, Verilator `5.052` revision
`ea338be98e1e838d3518809ce8899f85a009963c`, Python `3.12.13`, NumPy `2.4.6`,
and ONNX `1.17.0`. Three paired GEMM cases pass independent INT32 Golden on
both designs. NMAForge used 172/263/1,391 cycles with a measured behavioral
SPAD controller; TinyNPU direct array used 52/100/790 cycles. The explicitly
serialized common-memory estimate for TinyNPU is 151/231/1,305 cycles. The
ratio is NMAForge measured RTL cycles divided by TinyNPU normalized modeled
cycles: **1.1391 / 1.1385 / 1.0659**. Values above 1 mean NMAForge took more
cycles under this mixed measured/modeled endpoint; this is not a silicon or
uniform-memory winner claim. TinyNPU has no scratchpad port in the tested
wrapper, so its memory portion remains modeled.

The same pinned `conv1x_mini.onnx` graph passes on both sides with the same
model and input hashes. NMAForge checked every intermediate tensor and all
four outputs; its measured windows are 1,985 compute cycles plus 1,080 host
layout cycles. TinyNPU graph execution is 4,781 cycles through its graph
dispatcher and testbench DMA/SRAM shim. The different execution/memory
boundaries preclude a CNN speedup ratio. TinyNPU's reference engine regression
passes 6/6, and the NMAForge matrix-size sweep passes 15/15 points for five
workloads across 4×4/8×8/16×16 physical-array configurations at this seed.

The exact replay command, per-run artifacts, model hashes, and raw-log archive
checksum are in the [current replay record](NMAFORGE_V2_TINYNPU_REPLAY_2026-11-05.md).
Machine-readable data is in [`gemm_results.csv`](../../benchmark/tinynpu/gemm_results.csv),
[`cnn_results.csv`](../../benchmark/tinynpu/cnn_results.csv), and the two
summary JSON files. The benchmark ratio convention remains
`NMAForge cycles / TinyNPU normalized cycles`; values above 1 mean NMAForge
used more cycles under the stated normalization. Prior BLOCKED_ENV entries
are superseded for these tested GEMM/CNN/GEMV points only; the full TinyNPU/model
benchmark task is not closed.

### Small-M GEMV reference comparison

At NMAForge SHA `0b1d33704f4895cf48b0f5e1d3f452d61b3df535`, run
`GEMV-MATCH-V2-S20261029` passed signed INT8/INT32 Golden for `1×13×17` and
`8×16×19` on opcode `0x52`. NMAForge's measured Matrix-controller plus
behavioral-SPAD intervals were 76 and 158 cycles, with 304/560 B read and
52/512 B written. The pinned TinyNPU SHA has no equivalent tested GEMV
descriptor or SPAD port: its 16×16 direct-array RTL took 100 cycles for each
zero-padded shape. Adding the explicitly serialized memory model yields 126
and 170 cycles. The resulting ratios are 0.6032 and 0.9294, where
`NMAForge measured command cycles / TinyNPU modeled endpoint cycles`; ratios
below one favor NMAForge on this mixed endpoint arithmetic only and are not a
system-level speedup claim.

The NMAForge event profile closes to 76/158 total cycles when exclusive
controller-stage counts and prefetch-wait cycles are combined. Arbiter,
response, writeback, and prefetch wait/event counters can overlap and are not
summed as independent stalls. Golden, raw rows, tool versions, command, and
log archive checksum are in the [Small-M GEMV replay record](NMAFORGE_V2_SMALL_GEMV_TINYNPU_2026-11-05.md),
[`gemv_results.csv`](../../benchmark/tinynpu/gemv_results.csv), and
[`gemv_summary.json`](../../benchmark/tinynpu/gemv_summary.json). This adds
two bounded shapes only; broad M/N/K tails, common RTL memory service, and
product-level TinyNPU equivalence remain open.

## Trained Digits model result

The same trained INT8 model, seed `20261029`, 360 test inputs, independent
integer Golden and exact RTL logits CSV were replayed on R250 and the v2
candidate. The R250 CMDQ interval is 110,155 cycles; the `0x53` v2 interval is
34,761 cycles, a 68.44% reduction for this model workload. Both runs classify
352/360 images (97.78%) and the two RTL logit files have the same SHA-256.
The v2 run executes 46 CMDQ descriptors versus 69 on R250 while retaining the
same 1,884,160 padded MAC count. Its reported 54.2033 MAC/cycle and 21.17%
utilization are simulation-derived over the full doorbell-to-completion-tail
interval.

This result compares two NMAForge RTL revisions, not TinyNPU. R250's SFU
tile-pack counter and v2's fused Matrix counter are different event classes;
their byte fields are also defined differently and are not ratioed. The
timing excludes SPAD preload and post-run reads/Golden comparison. See the
[matched model report](NMAFORGE_V2_MODEL_BENCHMARK.md), [CSV](../../benchmark/v2_digits_model_comparison.csv)
and [JSON](../../benchmark/v2_digits_model_comparison.json).

## Current conclusion

The controlled NMAForge RTL results support the existing B-fold Cache and
bounded tile forwarding for their measured workloads. Prefetch is beneficial
for some points and neutral or slightly negative for others. Low utilization
on small shapes and TinyNPU's missing RTL memory adapter remain open. No
bank-aware scheduler RTL, second MAC array, or PPA claim is introduced by this
report.
