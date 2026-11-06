# NMAForge v2 Performance Comparison

**As of:** 2026-11-06
**Product baseline:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Latest replay source/test SHA:** `36d4b9b4bbafe769b452afc003033d2a222a682f` (tree `a92a302ce78ef541aa0a76bb99dfeb0a413ad0c4`; 8-configuration Matrix rerun)

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

### Real Compute Cluster serial / parallel workload

The production-top UVM performance sequence was replayed at fixed source/test
SHA `17b09e068e988ca35480ffd638d865872e9ba564`, on three Seeds. The command
was:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_cluster_bench_17b09e0 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The full Compute Cluster UVM regression and merged URG gate pass on all three
Seeds. For the same queued four-task workload (Matrix + CNM + two SFU commands),
serial doorbell-to-completion intervals total 1,696 cycles; one parallel
CMDQ submission completes in 1,137 cycles, a measured ratio of
`serial_cycles / parallel_cycles = 1.492` (32.96% fewer cycles). Read and write
traffic remain 4,352 B and 2,688 B in both modes, with parallel completion
order `0600,0601,0602,0603`. These are VCS cycle counts, not wall-clock or ASIC
performance.

A separate three-task staged workload (Matrix+CNM together, then SFU) takes
1,070 cycles versus its three-command serial reference of 1,239 cycles; the
ratio is 1.158 (13.64% fewer cycles). The staged run reports 4,032 B read,
2,416 B written, 32 Matrix/CNM pair-contention cycles, and ordered completions
`0700,0701,0702`. Its traffic is reported independently; the test does not emit
a matching three-task serial byte total.

The shared-Arbiter probes show 333 Matrix/CNM banked collision-observation
cycles, including 320 admitted collisions and 320 Matrix wait cycles. All 320
held-payload checks pass; Matrix and CNM response counts are 768 and 1,120,
with zero owner, hold-stability, or route-mismatch errors. A separate Matrix
line-writeback stall test observes 1,837 overlap cycles and 84 payload-stability
checks with zero violations. These are event counters and test-window counts,
not extra cycles to add to benchmark totals.

Machine outputs: [serial/parallel CSV](../../benchmark/v2_p2_cluster_serial_parallel_17b09e0.csv),
[contention CSV](../../benchmark/v2_p2_cluster_contention_17b09e0.csv),
[summary JSON](../../benchmark/v2_p2_cluster_serial_parallel_17b09e0_summary.json),
and [cycle chart](../../benchmark/v2_p2_cluster_serial_parallel_17b09e0.svg).
Logs-only archive `/tmp/nmaforge_v2_cluster_bench_17b09e0_logs.tar.gz`,
SHA-256 `a2c2daa85ba57c1617239498c60636763584707f43bb93c345f5e01f7c6d8fbe`.

This confirms legal queued overlap and actual banked-client contention under
the current scheduler. It does not compare an alternate Bank-Aware Issue
policy or isolate its area/timing cost, so no scheduling RTL change is
justified. DMA/DDR timing and a wider workload matrix remain open.

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

## Current candidate replay at `410b81d`

The current candidate reran the registered four-bank behavioral-SPAD product
GEMV comparison on Seeds 20261105/06/07. VCS was
`V-2023.12-SP1_Full64`; array 16×16 (256 INT8 MAC), read depth 4, A-Tile Cache
enabled, and four B-fold Cache × Next-K Prefetch combinations. All 48 complete
output images passed the independent Golden; exclusive Matrix state cycles
equal command cycles for all points. Stall/event counters can overlap and are
not summed as an exclusive partition.

| Shape | Cache OFF / Prefetch OFF | Cache ON / Prefetch OFF | Cache OFF / Prefetch ON | Cache ON / Prefetch ON |
|---|---:|---:|---:|---:|
| M8×16×19 cycles / read B | 200.7 / 864 | 156.0 / 560 | 195.7 / 864 | 152.3 / 560 |
| M8×16×65 cycles / read B | 544.3 / 2,720 | 391.0 / 1,696 | 520.0 / 2,720 | 383.0 / 1,696 |
| M16×16×19 cycles / read B | 393.7 / 1,728 | 261.0 / 816 | 382.7 / 1,728 | 262.7 / 816 |
| M16×16×65 cycles / read B | 1,075.0 / 5,440 | 627.3 / 2,368 | 1,029.7 / 5,440 | 632.3 / 2,368 |

B-fold Cache without Prefetch reduces cycles 22.3–41.6% and reads 35.2–56.5%
for these four shapes. Prefetch without Cache reduces cycles 2.5–4.5%. With
Cache enabled, Prefetch helps the two M8 cases by about 2.1–2.4% but regresses
the M16 cases by about 0.6–0.8%. With Cache and Prefetch both enabled, useful
throughput is 15.97–26.32 MAC/cycle (6.24–10.28% of 256-MAC peak) across the
four shapes. The best point across all four configurations is 26.53 MAC/cycle
(10.36%) on M16×16×65 with Cache ON and Prefetch OFF. These are workload-window
simulation metrics, not silicon utilization.

Exact run: `V2-GEMV-FOUR-WAY-3SEED-410B81D`; merged artifacts are
[CSV](../../benchmark/v2_p2_gemv_cache_prefetch_4way_410b81d.csv),
[summary JSON](../../benchmark/v2_p2_gemv_cache_prefetch_4way_410b81d_summary.json)
and [SVG](../../benchmark/v2_p2_gemv_cache_prefetch_4way_410b81d.svg). The
run logs and per-seed summaries are outside Git at
`/tmp/nmaforge_v2_current_410b81_gemv4`; combined GEMV/Digits evidence archive
SHA-256 is
`26b751910afa296181c1e85aab39910b71f0cdd49e196f493a5cdf1a22f9d5fa`.

Reproduction command (run from the repository root):

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  PYTHON=python3.12 SEEDS='20261105 20261106 20261107' \
  OUTSTANDING_DEPTH=4 A_TILE_CACHE_ENABLE=1 PHYSICAL_ARRAY_SIZE=16 \
  GEMV_FOUR_WAY_OUT=/tmp/nmaforge_v2_current_410b81_gemv4
python3.12 tools/merge_gemv_four_way_ablation.py \
  --output-prefix benchmark/v2_p2_gemv_cache_prefetch_4way_410b81d \
  /tmp/nmaforge_v2_current_410b81_gemv4/summary_seed_20261105.csv \
  /tmp/nmaforge_v2_current_410b81_gemv4/summary_seed_20261106.csv \
  /tmp/nmaforge_v2_current_410b81_gemv4/summary_seed_20261107.csv
```

### Seven-engine shared-SPAD workload

The real Compute Cluster top, shared arbiter, and checked-in behavioral
four-bank SPAD passed the same deterministic serial/parallel workload on three
Seeds. Descriptor programming and external DDR timing are excluded.

| Case | Cycles | Read / write traffic | Result |
|---|---:|---:|---|
| Four tasks serial: Matrix + CNM + SFU + SFU | 1,696 | 4,352 / 2,688 B | Golden PASS |
| Same four tasks queued/parallel | 1,137 | 4,352 / 2,688 B | 1.492× vs serial, ordered completion |
| Three tasks serial: Matrix + CNM + SFU | 1,239 | 4,032 / 2,416 B | Golden PASS |
| Matrix + CNM overlap, then SFU | 1,070 | 4,032 / 2,416 B | 1.158× vs serial |

Observed Matrix/CNM contention is 320 admitted bank collisions and 320 Matrix
wait cycles, with zero response-owner, held-payload, or route mismatches. This
demonstrates current-policy contention; no alternative Bank-Aware Issue policy
was A/B tested, so it is not evidence to add scheduler RTL. See the
[contention CSV](../../benchmark/v2_p2_cluster_contention_410b81d.csv),
[serial/parallel CSV](../../benchmark/v2_p2_cluster_serial_parallel_410b81d.csv),
[summary JSON](../../benchmark/v2_p2_cluster_serial_parallel_410b81d_summary.json)
and [chart](../../benchmark/v2_p2_cluster_serial_parallel_410b81d.svg).
Detailed logs are in `/tmp/nmaforge_v2_current_410b81_cluster_uvm` and the
combined archive `/tmp/nmaforge_v2_current_410b81_signoff_logs.tar.gz`,
SHA-256 `c9f88930f24c3ca74140ba48e06d91f3fdbd0d37585fff0f9dac3ded15404ce5`.

These are RTL simulation results with behavioral SPAD. They are not SRAM
timing, measured Fmax, ASIC area, power, or energy measurements.

## Current-candidate TinyNPU GEMM replay — `d1867da`

The current NMAForge source/test candidate was rerun against the three
deterministic GEMM vectors used by the pinned TinyNPU reference. The executed
Git HEAD was `d1867da79a84b17451d63e919f9ce1e8ef4df098`; the v2 RTL/test
candidate is `410b81dfd37992a760b28258bb7e8c6b6f5017d7`. The intervening tree
changes are reports and benchmark records; no RTL or testbench source changed
from `410b81d` to `d1867da`.

| Shape | NMAForge controller + behavioral SPAD | TinyNPU direct RTL array | TinyNPU serialized memory endpoint estimate | NMAForge / estimated TinyNPU |
|---|---:|---:|---:|---:|
| 16×16×16 | 172 cycles | 52 cycles | 151 cycles | 1.1391 |
| 16×16×32 | 263 cycles | 100 cycles | 231 cycles | 1.1385 |
| 32×32×64 | 1,391 cycles | 790 cycles | 1,305 cycles | 1.0659 |

All three current NMAForge output images pass the independent INT32 Golden.
NMAForge uses a measured 16×16 Matrix controller with a one-cycle behavioral
four-bank SPAD. TinyNPU's direct-array cycles were measured at its pinned SHA
in the earlier `TINY-COMPARE-V2C3A59-S20261029` replay; its memory endpoint is
an explicit serialized model, not TinyNPU memory RTL. Ratios above 1 mean the
NMAForge measured interval is longer than the modeled TinyNPU endpoint. This
is a useful negative result, not a product-level performance win or a uniform
memory-service comparison. The current environment has no Verilator binary,
so TinyNPU itself was not rebuilt in this replay.

Run ID: `V2-TINYNPU-REPLAY-CURRENT-D1867DA-S20261029`. Exact current NMAForge
commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim core-random-compile \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  PHYSICAL_ARRAY_SIZE=16 OUTSTANDING_DEPTH=4 A_TILE_CACHE_ENABLE=1 \
  NEXT_K_PREFETCH_ENABLE=1 GEMV_B_TILE_CACHE_ENABLE=1 \
  CORE_OUT_DIR=/tmp/nmaforge_v2_tinynpu_current_d1867da
/tmp/nmaforge_v2_tinynpu_current_d1867da/simv +SEED=20261029 \
  +TINY_NPU_MATCH_MULTI \
  -l /tmp/nmaforge_v2_tinynpu_current_d1867da/run.log
```

The same replay also checked the pinned `conv1x_mini.onnx` graph through the
current top-level CMDQ path: all intermediate tensors and four outputs were
bit-exact. Machine records are the [GEMM CSV](../../benchmark/v2_tinynpu_current_d1867da_gemm.csv),
[CNN CSV](../../benchmark/v2_tinynpu_current_d1867da_cnn.csv), and
[summary JSON](../../benchmark/v2_tinynpu_current_d1867da_summary.json). VCS
compile/run logs and generated CNN input/expected memory images are archived
outside Git at `/tmp/nmaforge_v2_tinynpu_current_d1867da_logs.tar.gz`,
SHA-256 `018d11dc90159192f0fb13c5e5901269b66be7ff8013bf4891cfd26b1e9e7885`.

## Verification-only update — 2026-11-06

The current testbench/build candidate is `380f96114dba022300db09fb217264c3a606a2fd`
(tree `79aaf0782aba0da18d7109b74ae2bd343a473181`); product RTL is unchanged.
The new runs add functional coverage for GEMV shapes and Tile Forwarding but
do not rerun the performance suites. Cycle, traffic, utilization, and TinyNPU
comparisons above remain tied to their individually listed source/test SHAs
and timing endpoints. No new PPA or system-level performance result is
inferred from the coverage replay. See the [DV report](../verification/NMAFORGE_V2_DV_CLOSURE.md)
for exact run IDs and the evidence archive.


## Current-candidate Matrix eight-configuration replay — 2026-11-06

Run ID `V2-MATRIX-EIGHT-CONFIG-3SEED-36D4B9B` ran the existing Matrix
controller benchmark on source/test SHA
`36d4b9b4bbafe769b452afc003033d2a222a682f` (tree
`a92a302ce78ef541aa0a76bb99dfeb0a413ad0c4`). It used the same five GEMM
workloads, a physical 16×16 array (256 INT8 MACs), fixed one-cycle behavioral
bank response, and three fixed Seeds. Each Seed completed all eight combinations
of outstanding depth 2/4, Next-K Prefetch OFF/ON, and A-Tile Cache OFF/ON.
Every point passed its independent output Golden: 120/120 total.

Mean measurements across the five workloads (three-seed mean per workload,
then summed) are:

| Depth / Prefetch / A-Tile Cache | Cycles | Change vs baseline | SPAD read bytes | SPAD write bytes | Total SPAD bytes | Weighted MAC/cycle | Weighted array utilization |
|---|---:|---:|---:|---:|---:|---:|---:|
| 2 / OFF / OFF (baseline) | 2,720.00 | — | 12,032 | 7,488 | 19,520 | 34.07 | 13.31% |
| 2 / OFF / ON | 2,455.67 | −9.72% | 9,472 | 7,488 | 16,960 | 37.74 | 14.74% |
| 2 / ON / OFF | 2,447.00 | −10.04% | 12,032 | 7,488 | 19,520 | 37.87 | 14.79% |
| 2 / ON / ON | 2,133.00 | −21.58% | 9,472 | 7,488 | 16,960 | 43.45 | 16.97% |
| 4 / OFF / OFF | 2,602.00 | −4.34% | 12,032 | 7,488 | 19,520 | 35.62 | 13.91% |
| 4 / OFF / ON | 2,346.00 | −13.75% | 9,472 | 7,488 | 16,960 | 39.50 | 15.43% |
| 4 / ON / OFF | 2,316.00 | −14.85% | 12,032 | 7,488 | 19,520 | 40.01 | 15.63% |
| 4 / ON / ON | 2,038.33 | −25.06% | 9,472 | 7,488 | 16,960 | 45.46 | 17.76% |

The A-Tile Cache reduces aggregate read traffic by 21.28% for this workload
set while write traffic is unchanged. The effect is concentrated in shapes
that reuse A across column tiles. Prefetch-only reduces cycles by 10.04% at
depth 2 and 14.85% at depth 4 without changing the recorded SPAD bytes. Depth
4 alone improves cycles by 4.34%; the combined result is not a simple sum of
independent gains.

Per-workload best configurations vary: Prefetch-only is best on 4×4×32 and
8×8×32; depth 4 with Prefetch and Cache is best on 16×32×32 and 32×32×64;
16×16×32 is best at depth 4 with Prefetch and Cache OFF. Against each
workload's baseline mean, these best points reduce cycles by 22.11%, 13.40%,
14.88%, 22.85%, and 28.39%, respectively. This is controller-level evidence
under the stated memory model; it does not establish a universal configuration
winner or a TinyNPU advantage.

The CSV includes per-Seed cycles, MAC/cycle, array utilization, SPAD read/write
bytes, bank stalls, response waits, arbiter stalls, writeback waits, Prefetch
waits, outstanding high-water, FIFO-full observations, and cache-hit counts.
These event/stall counters can overlap; they are diagnostics and must not be
added to command wall cycles. SPAD bytes are the measured behavioral-model
bank-read bytes plus line-write bytes. The 250 MHz number remains only a
normalization assumption; no ASIC clock, PPA, power, or energy is measured.

Machine outputs: [120-point CSV](v2_matrix_config_closure_36d4b9b_3seed.csv),
[summary JSON](v2_matrix_config_closure_36d4b9b_3seed.json), and
[cycle-reduction chart](v2_matrix_config_closure_36d4b9b_3seed.svg). The
reproducible [summarizer](../../tools/summarize_matrix_config_closure.py)
validates all expected Seeds/configurations/cases and emits these artifacts.
The 54-file logs/archive bundle is outside Git at
`/tmp/nmaforge_v2_matrix_config_closure_36d4b9b_evidence.tar.gz`, SHA-256
`003c1dedc0de9d3b9875dec63a218fade601e1a09d9b928b791bb250599741fd`.

Exact simulation command, repeated for each Seed:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=$seed \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_v2_matrix_config_current_$seed \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10'
```

Seeds were 20261117, 20261118, and 20261119. Simulator version was Synopsys
VCS `V-2023.12-SP1_Full64`; the aggregator ran with Python 3.12.13. The
summarizer command is embedded in the evidence archive manifest and recorded in
the [execution frontier](../exec-plans/active/execution-frontier.md).
