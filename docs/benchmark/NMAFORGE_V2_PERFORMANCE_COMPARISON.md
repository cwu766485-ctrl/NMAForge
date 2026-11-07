Warning: truncated output (original token count: 20268)
Total output lines: 1403

# NMAForge v2 Performance Comparison

## Round 5 current-source update — 2026-11-07

The fixed current-source matrix and model comparisons are in
[`Round 5 final comparison`](NMAFORGE_V2_ROUND5_FINAL_COMPARISON.md),
[`matrix CSV`](../../benchmark/v2_round5_tinynpu_matrix_20261107.csv),
[`model CSV`](../../benchmark/v2_round5_model_summary_20261107.csv), and
[`run manifest`](../../benchmark/v2_round5_run_manifest_20261107.json).
NMAForge source/test SHA is `73caef0f32140d1635816f1eb4ea28372523e80c`;
TinyNPU is fixed at `8216c22b762011aa20c05fc2768423fd12dda59d`.

At that NMAForge SHA, the 3 GEMM + 4 GEMV matrix passed all independent
Goldens with VCS `V-2023.12-SP1_Full64`, seed `20261107`, a 16×16 array, and
one-cycle behavioral four-bank SPAD. TinyNPU Verilator array results also
passed all seven Golden cases. TinyNPU's timed path is the Direct Array only;
there is no Tiny controller/SPAD timing in those cycles. The separate
16-byte/cycle common-memory rows are estimates. Consequently, report raw
cycle ratios and model assumptions only; do not call them cross-system
speedups.

For the same NMAForge mini-CNN Top case, the Legacy→Linear-Row measured
interval is 1,985→1,504 cycles, a 1.320× within-system speedup. The trained
ten-class CNN has 3,193→2,712 Top CMDQ cycles (1.177×) and 4,273→2,712 cycles
when including its testbench-emulated Host Layout (1.576×); both paths pass
all 396 sample Goldens and retain 384/396 classifications. The 1,080 Host
Layout cycles are simulator transactions, not measured host CPU time.
Fused Requant and Linear-Row effects are not isolated by this paired model
run. Historical Digits epilogue and directed Tile Forwarding evidence remain
separate experiments as described below.

The optional Transformer `0x52` Q/K/V Decode mapping preserves the default
`0x30` path, but its current H4 Top integration fails 175 Golden checks. Its
cycle counters are not valid performance evidence. No Cache/Prefetch model
gain is established for Transformer Decode.

## Focused Research Round 3 — 2026-11-06

Candidate: `4dab73646989615c5479de0bac76d1488a102758`, parent/reviewed
remote: `240ed4106a1b31078cce15e2406d437ca0cde987`. TinyNPU reference remains
`8216c22b762011aa20c05fc2768423fd12dda59d`. All new values below are
behavioral VCS Top results with the four-bank SPAD model.

### Innovation 1 — Shape-Adaptive GEMM/GEMV

The fixed Cache × Prefetch GEMV ablation remains the evidence from the
earlier, SHA-bound four-way experiment below: B-fold cache gave 22.3–41.6%
fewer cycles and 35.2–56.5% fewer reads across the four measured GEMV shapes
with prefetch off; prefetch had small shape-dependent effects. No new
model-level Cache/Prefetch ablation was run in this round. The trained toy
Transformer uses opcode `0x30` GEMM descriptors, not a representative
opcode-`0x52` GEMV-heavy decode path; applying the GEMV toggles would require a
different model mapping. Thus no model-level gain is attributed to Innovation
1 here. This round adds no scheduler or cache RTL.

### Innovation 2 — Fused epilogue and output handoff

The ten-class CNN was rerun at the fixed candidate with `0x53 aux0[7]` off
(Legacy) and on (linear-row output). The same 396 images passed exact
intermediate/final Goldens and both modes classified 384/396. Per sample:

| Measure | Legacy | Fused linear-row | Change |
|---|---:|---:|---:|
| Top CMDQ cycles | 3,193 | 2,712 | −15.1% |
| Testbench Host layout | 1,080 cycles; 144 B read + 576 B write | 0 cycles / 0 B | eliminated |
| End-to-end measured interval | 4,273 cycles | 2,712 cycles | −36.5% |
| Compute SPAD R/W | 6,048 / 1,920 B | 5,472 / 1,776 B | −576 / −144 B |
| Total SPAD traffic including Host layout | 8,688 B | 7,248 B | −16.6% |
| Useful MACs / effective MAC per interval cycle | 2,736 / 0.640 | 2,736 / 1.009 | derived |
| Golden / classification | 396/396 exact; 96.97% | 396/396 exact; 96.97% | unchanged |

The Host-layout interval is a 10 ns simulation-clock estimate for 36 AXI
reads plus 144 AXI word writes, not software wall time. Input preload and
post-run Golden inspection are excluded on both sides. The legacy-to-fused
CNN comparison combines epilogue fusion and direct consumer layout, so its
36.5% total-cycle gain must not be attributed to either feature alone. The
existing Digits MLP fusion result (110,155→34,761 cycles) and the separate
directed Tile Forwarding result (23 cycles saved, about 8%) remain distinct
experiments; they are not mixed into this CNN ratio. The bounded linear-row
mode is a separate output-layout option, not the 512 B elastic tile cache.

### Transformer workload and comparison limits

The trained cyclic toy Transformer ran 4-token Prefill in 5,682 cycles and
one Decode token in 5,715 cycles (11,397 combined), using 3,816 SPAD read and
2,120 write bytes and 640 useful MACs. It validates Mapper-loaded training
weights, operator composition, and KV-cache Golden behavior. It does not
exercise opcode `0x52`, so it is not a Cache × Prefetch model-level result.

TinyNPU's pinned direct-array and modeled common-memory GEMM/GEMV matrix is
preserved at its original source/test SHA. The new CNN and Transformer have
not been run on TinyNPU with a matching memory service, clock boundary,
weights, and outputs. The results do not establish a cross-system speedup or
performance victory. DC/ASIC area, Fmax, power, and energy remain
**BLOCKED_ENV**; no frequency is inferred from the 10 ns simulation clock.

## Finalization addendum — models and compact SPAD, 2026-11-06

The fixed GEMM/GEMV and innovation-ablation results below remain bound to
their listed historical source/test SHAs; product RTL is unchanged at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. This addendum records new Top RTL
capacity runs at source/test SHA `9576e539c21fe6312763c4745a90dc032c6457e0`
with VCS `V-2023.12-SP1_Full64`, seed `20261029`, and a behavioral SPAD. It
does not convert the TinyNPU direct-array comparison into a full-system
comparison.

| Workload | SPAD | Top RTL compute cycles | Host layout cycles | Compute SPAD R/W bytes | Golden / result |
|---|---:|---:|---:|---:|---|
| `conv1x_mini.onnx`, fixed deterministic input | 128 / 512 KiB | 1,985 / 1,985 | 1,080 / 1,080 | 3,360 / 1,600 | Bit-exact with pinned TinyNPU compiler Golden |
| Trained 10-class Digits CNN, 396 held-out images | 128 / 512 KiB | 3,193 / 3,193 per image | 1,080 / 1,080 per image | 6,048 / 1,920 per image | 396/396 Top runs exact; 384/396 classified correctly (96.97%) |

The two tested workloads have **0% cycle change** and identical measured
per-workload traffic between the compact 128 KiB and 512 KiB behavioral-SPAD
profiles. This is a valid result for these compact maps, not evidence that
all models fit or that physical SRAM timing/area is unchanged. Both profiles
keep four banks, 128-bit lines, and the same 256-MAC array. Host-layout cycles
are reported separately from RTL compute cycles.

For `conv1x_mini.onnx`, the pinned TinyNPU ONNX compiler Golden and the
NMAForge Top Golden have SHA-256
`94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c`.
TinyNPU's Verilator graph runtime was not rerun for this capacity study, so
there is no paired CNN cycle/speedup claim. TinyNPU reference SHA remains
`8216c22b762011aa20c05fc2768423fd12dda59d`.

The ten-class CNN model SHA-256 is
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`; the
held-out test-set SHA-256 is
`cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`. The
fixed split is 1,401 train / 396 test (stratified, seed 29); RTL outputs match
the independent integer Golden at every checked intermediate. Full per-image
records are in
[`128 KiB CSV`](../../benchmark/v2_trained_cnn_tenclass_top_128k_9576e53.csv)
and [`512 KiB CSV`](../../benchmark/v2_trained_cnn_tenclass_top_512k_9576e53.csv).
Machine-readable capacity rows and commands are in
[`capacity JSON`](../../benchmark/v2_spad_capacity_study_20261106.json) and
[`capacity CSV`](../../benchmark/v2_spad_capacity_study_20261106.csv). A
single fixed-run matrix normalizing these model rows with the historical
GEMM/GEMV rows and the fixed Transformer fixture is available as
[`unified CSV`](../../benchmark/v2_research_benchmark_matrix_20261106.csv)
and [`JSON manifest`](../../benchmark/v2_research_benchmark_matrix_20261106.json).

The fixed TinyNPU GEMM/GEMV table below is the measured/modeled matrix at
NMAForge source `219c9f26a85b9661185cd78ab6308ae3f13e3ea7`, seed `20261106`.
Its TinyNPU numbers are direct-array cycles; the common-memory endpoint is an
estimate. Under that mixed boundary NMAForge used 1.06–1.15× the estimated
TinyNPU endpoint for the listed GEMMs, 0.54× for 1×13×17 GEMV, 0.90× for
8×16×19, 1.29× for 16×16×19, and 1.44× for 16×16×65. These ratios do not
establish a system-level TinyNPU win; small-M occupancy is poor and the
estimated endpoint is not TinyNPU memory RTL.

## Current fixed TinyNPU matrix — 2026-11-06

This section supersedes prior NMAForge cycle rows for the listed fixed shapes.
It does not replace or rewrite historical runs. NMAForge used current source
SHA `219c9f26a85b9661185cd78ab6308ae3f13e3ea7`, product RTL SHA
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, seed `20261106`, VCS
`V-2023.12-SP1_Full64`, 16×16 array, depth 4, B-fold cache and prefetch on.
TinyNPU source is pinned to `8216c22b762011aa20c05fc2768423fd12dda59d`;
its already-compiled RTL was generated with Verilator 5.052 and the focused
driver was run with g++ 8.5.0. Both sides use matching deterministic INT8
operands and independent INT32 Golden checks.

TinyNPU exposes only direct array cycles in this experiment. The separate
common-memory estimate serializes logical INT8 input reads and INT32 output
writes through one 16-byte/cycle port, adds one read-response cycle and two
initial accumulator-clear cycles. It is an estimate, not a TinyNPU controller
or memory measurement. The ratio column is explicitly
`NMAForge cycles / TinyNPU estimated endpoint`; values above 1 indicate more
NMAForge cycles under this mixed measured/estimated boundary.

### GEMM

| Shape M×N×K | NMA cycles | NMA MAC/cycle | NMA array utilization | NMA SPAD read/write B | Tiny array cycles | Tiny common endpoint estimate | NMA / estimated Tiny | Golden |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 16×16×16 | 173 | 23.676 | 9.25% | 512 / 1,024 | 52 | 151 | 1.1457 | PASS both |
| 16×16×32 | 259 | 31.629 | 12.36% | 1,024 / 1,024 | 100 | 231 | 1.1212 | PASS both |
| 32×32×64 | 1,380 | 47.490 | 18.55% | 6,144 / 4,096 | 790 | 1,305 | 1.0575 | PASS both |

### GEMV / padded TinyNPU array mapping

TinyNPU does not execute these through a native GEMV descriptor/controller;
the reference test drives its 16×16 array with padded operands and checks the
logical output image. Its direct-array timing excludes memory service.

| Shape M×N×K | NMA cycles | NMA MAC/cycle | NMA utilization | NMA SPAD read/write B | Tiny array cycles | Tiny common endpoint estimate | NMA / estimated Tiny | Golden |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 1×13×17 | 66 | 3.348 | 1.31% | 304 / 52 | 100 | 122 | 0.5410 | PASS both |
| 8×16×19 | 148 | 16.432 | 6.42% | 560 / 512 | 100 | 164 | 0.9024 | PASS both |
| 16×16×19 | 264 | 18.424 | 7.20% | 816 / 1,024 | 100 | 205 | 1.2878 | PASS both |
| 16×16×65 | 634 | 26.246 | 10.25% | 2,368 / 1,024 | 244 | 441 | 1.4376 | PASS both |

NMA stall observations (cycles; overlapping categories must not be summed):

| Workload | Shape | Bank / line | Prefetch wait | Arbiter / response / writeback |
|---|---|---:|---:|---:|
| GEMM | 16×16×16 | 9 / 21 | 47 | 30 / 8 / 21 |
| GEMM | 16×16×32 | 24 / 21 | 111 | 45 / 10 / 21 |
| GEMM | 32×32×64 | 134 / 77 | 664 | 211 / 23 / 77 |
| GEMV | 1×13×17 | 6 / 1 | 36 | 7 / 5 / 2 |
| GEMV | 8×16×19 | 12 / 3 | 63 | 15 / 11 / 3 |
| GEMV | 16×16×19 | 18 / 23 | 85 | 41 / 20 / 23 |
| GEMV | 16×16×65 | 49 / 18 | 363 | 67 / 22 / 18 |

The large-GEMM evidence points to memory/controller service rather than a lack
of MAC capacity alone: NMA utilization is 9.25–18.55%; the 32×32×64 case has
134 bank-stall, 77 line-stall, 211 arbiter-stall and 77 writeback-wait
observations, with category overlap. Small-M GEMV retains poor utilization
(1.31% at M=1). NMA is below the modeled Tiny endpoint for M=1 and M=8, but
above it for both M=16 tail cases. Because TinyNPU memory/controller timing
is not measured, none of these ratios establish a system-level TinyNPU win.

Machine outputs:
[GEMM CSV](../../benchmark/v2_tinynpu_gemm_current_20261106.csv),
[GEMM JSON](../../benchmark/v2_tinynpu_gemm_current_20261106.json),
[GEMV CSV](../../benchmark/v2_tinynpu_gemv_current_20261106.csv), and
[GEMV JSON](../../benchmark/v2_tinynpu_gemv_current_20261106.json).
Raw logs and the exact run manifest are archived outside the repository at
`/tmp/nmaforge_v2_tinynpu_evidence_20261106.tar.gz` (SHA-256
`3cf83dea684002740ead224ac1fec60e4710c44b2fa887c718082699b51debb9`).

## Innovation ablations and model-level evidence

The fixed 48-point Cache×Prefetch matrix continues to show B-fold Cache
reducing cycles by 22.3–41.6% and read traffic by 35.2–56.5% versus Cache OFF
/ Prefetch OFF. Prefetch with Cache ON helps the M8 shapes about 2%, while
regressing the M16 shapes 0.6–0.8%; this does not justify a new scheduler.
For fused Digits, the matched RTL run reduces doorbell-to-completion cycles
from 110,155 to 34,761 (68.44%), with byte-identical logits and 352/360
classification accuracy in both runs. The 0x53 Tile Forwarding directed
Matrix-core test saves 23 cycles (about 8%) and halves source-A bank reads;
that test is not a full CMDQ producer/consumer Top benchmark.

The paired mini-CNN remains Golden-correct on both systems. NMAForge reports
1,985 compute + 1,080 host-layout cycles; TinyNPU reports 4,781 graph cycles
under a different endpoint. No CNN speedup ratio is valid. See the [model
report](NMAFORGE_V2_MODEL_BENCHMARK.md).

**As of:** 2026-11-06
**Product baseline:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Latest fixed Matrix benchmark source/test SHA:** `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (clean-worktree three-seed Cache × Prefetch GEMV ablation; VCS V-2023.12-SP1_Full64). **Latest Top contention workload SHA:** `c93d020880710a2804685fd85bb98c2e9c56f290` (tree `24180541c76b1ad4d27b2e97313e7d97a5df2016`; three-seed 16×16 Top Matrix/CNM contention profile, replayed at clean candidate `839b9af`). Product RTL in both remains `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.
**Latest matched Cluster serial/parallel replay:** `f19e92934cd6273d327621c43cb17291cf1a9aa5` (three-seed real-Top Compute Cluster UVM replay of the same 3-task and 4-task workloads; product RTL unchanged).

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

### Current-source replay at SHA `a4dcc6b`

Run `V2-GEMV-FOUR-WAY-A4DCC6B-S20261105-07` repeats the same four Cache ×
Prefetch configurations at fixed source/test SHA
`a4dcc6b609878811fcd48a0310401609d4952c62` (tree
`430f9ce0c794f6e6a059d56ade7d9112b8a3079f`). It uses the same 16×16 array,
256 INT8 MACs, four outstanding reads, enabled A-Tile Cache, registered
four-bank behavioral SPAD, seed-controlled Ready/response latency, and Seeds
20261105/06/07 as the `85e7db2` replay. All 48 shape/configuration/Seed points
pass the independent signed INT8/INT32 Golden. The exclusive state partition
closes to command cycles on 48/48 points. For the matched 48 rows, all 33
compared measured fields (cycles, traffic, utilization, MAC activity, state
and stall counters, occupancy, and Golden) are identical to `85e7db2`; the
documentation-only candidate update did not alter the benchmark result.

The four-way response remains shape-dependent. With B-fold Cache ON, Cache
reduces cycles by 22.3–41.6% and read traffic by 35.2–56.5% versus Cache OFF
with Prefetch OFF. Adding Prefetch to Cache ON improves M8×16×19/65 by 2.35%/
2.05%, while M16×16×19/65 regresses by 0.64%/0.80%. These are Matrix-core RTL
cycles with behavioral memory, not Top-contention gains or ASIC metrics.

Exact clean-worktree command (VCS `V-2023.12-SP1_Full64`):

```sh
git worktree add --detach /tmp/nmaforge-v2-gemv-ablation-a4dcc6b \
  a4dcc6b609878811fcd48a0310401609d4952c62
VCS_ARCH_OVERRIDE=linux \
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C /tmp/nmaforge-v2-gemv-ablation-a4dcc6b/dv/block/compute/matrix/sim \
  product-gemv-four-way-ablation \
  SEEDS='20261105 20261106 20261107' OUTSTANDING_DEPTH=4 \
  A_TILE_CACHE_ENABLE=1 PHYSICAL_ARRAY_SIZE=16 \
  GEMV_FOUR_WAY_OUT=/tmp/nmaforge_v2_gemv_four_way_a4dcc6b \
  PYTHON=python3.12
```

Machine outputs: [48-point CSV](../../benchmark/v2_p2_gemv_cache_prefetch_4way_a4dcc6b.csv)
and [summary JSON](../../be…8268 tokens truncated…es
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

## Latest verification-only provenance — 2026-11-06

The latest real-Top opcode `0x52` CMDQ boundary replay is fixed at test/source
SHA `92874788fb2cb2a2b15657a3621e5a275a9d5990`; it adds 16×16×16 maximum-tile
coverage after the previously recorded 1×1×1 point and changes UVM/testbench
code only. It does not change product RTL. No performance suite was rerun on
this SHA. All cycle, traffic, utilization, and TinyNPU comparison values above
remain bound to their individually listed benchmark SHAs and memory models.
Ratio directions were audited: `NMAForge cycles / TinyNPU normalized cycles`
above 1 means NMAForge used more cycles; `speedup_vs_cache0_prefetch0` is
baseline cycles divided by configured cycles, so above 1 means fewer cycles.
The replay adds no new performance, ASIC frequency, area, power, or energy
evidence. It confirms maximum-shape functional execution only; it is not a
performance measurement.

## Fixed-candidate Cluster serial/parallel replay — `f19e929`

The complete three-seed Compute Cluster UVM run at fixed testbench SHA
`f19e92934cd6273d327621c43cb17291cf1a9aa5` re-executes the existing matched
serial/staged/parallel Top workload. All three seeds report identical cycle
and byte counts and pass the full UVM checker set. For Matrix + CNM + SFU,
serial takes 1,239 cycles and staged parallel takes 1,070 cycles (1.158×,
13.64% fewer cycles); both read 4,032 B and write 2,416 B. For the same four
tasks Matrix + CNM + SFU + SFU, serial takes 1,696 cycles and queued parallel
takes 1,137 (1.492×, 32.96% fewer); both read 4,352 B and write 2,688 B.
Completion order matches the submitted CMDQ order.

Each seed also observes a separate legal Matrix/CNM contention scenario:
333 collision cycles, 320 admitted collisions and Matrix wait cycles, 320
held-payload checks, and zero ownership or stability violations. The Matrix
line-stall check observes 84 stable-payload samples and zero violations. The
Memory Scoreboard checks 99,783 words with zero mismatch, unknown, or stale
reads; response ledger is 5,015 accepted / 4,995 checked / 20 reset-dropped,
with no pending or routing/data/error mismatches. These counters are event
diagnostics and are not added to the measured cycle totals. This UVM benchmark
does not provide a full per-command exclusive stall-state timeline; that
remains open for the matched serial/parallel cluster operations. A later
instrumentation update adds an exclusive FSM/stall profile for the standalone
Top Matrix baseline only; it does not yet profile every command in those
multi-engine workloads.

The machine-readable results are [CSV](../../benchmark/v2_p2_cluster_serial_parallel_f19e929.csv)
and [JSON](../../benchmark/v2_p2_cluster_serial_parallel_f19e929.json). Run ID
`V2-CLUSTER-SERIAL-PARALLEL-UVM-3SEED-F19E929`; the compile/run logs and URG
text are in `/tmp/nmaforge_v2_gemv_ab_alias_f19e929_logs.tar.gz`, SHA-256
`18e664689077d9608924af2b9ec08eb912d4979edc9e0cf36b816cbe936447ae`.
Exact command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_gemv_alias_f19e929 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261106 20261107 20261108'
```

The memory is the checked-in behavioral four-bank SPAD; descriptor setup and
preload are outside the interval. This is matched NMAForge RTL evidence only,
not a TinyNPU comparison, SRAM timing, ASIC PPA, or a scheduler-policy A/B
test. No Bank-Aware Issue RTL change is justified by this replay.

## Current fixed-candidate eight-configuration replay — `f9f32f7`

Run ID `V2-MATRIX-EIGHT-CONFIG-CLEAN-F9F32F7-3SEED` uses source/test SHA
`f9f32f71e7168350d74a75ede0a4a4b222844cc9` (tree
`0b20e98298852d2648f83d10723c55aabe3a9149`), VCS
`V-2023.12-SP1_Full64`, a physical 16×16 array (256 INT8 MACs), the same five
GEMM workloads, and a fixed one-cycle behavioral four-bank response model.
Seeds 20261106/07/08 each ran all depth 2/4 × Prefetch OFF/ON × A-Tile Cache
OFF/ON combinations. The summarizer validated all 120/120 output Golden
points.

The table sums the three-seed mean for each of the five workloads. Weighted
MAC/cycle and utilization use 92,672 logical MACs divided by total command
cycles and 256 physical MAC lanes. Cycle reduction compares each row with
Depth 2 / Prefetch OFF / Cache OFF.

| Depth / Prefetch / A-Cache | Sum cycles | Fewer cycles vs baseline | Read / write bytes | Weighted MAC/cycle | Utilization |
|---|---:|---:|---:|---:|---:|
| 2 / OFF / OFF | 2,702.00 | — | 12,032 / 7,488 | 34.30 | 13.40% |
| 2 / OFF / ON | 2,400.33 | 11.16% | 9,472 / 7,488 | 38.61 | 15.08% |
| 2 / ON / OFF | 2,410.00 | 10.81% | 12,032 / 7,488 | 38.45 | 15.02% |
| 2 / ON / ON | 2,091.33 | 22.60% | 9,472 / 7,488 | 44.31 | 17.31% |
| 4 / OFF / OFF | 2,565.67 | 5.05% | 12,032 / 7,488 | 36.12 | 14.11% |
| 4 / OFF / ON | 2,312.33 | 14.42% | 9,472 / 7,488 | 40.08 | 15.66% |
| 4 / ON / OFF | 2,278.33 | 15.68% | 12,032 / 7,488 | 40.68 | 15.89% |
| 4 / ON / ON | 1,987.00 | 26.46% | 9,472 / 7,488 | 46.64 | 18.22% |

A-Tile Cache reduces aggregate read traffic by 21.28% for this workload set;
write traffic is unchanged. The best combined setting is 26.46% fewer cycles
than baseline in this controller model. Stall/event counters can overlap and
are not added to command cycles. This is a single Matrix-controller benchmark,
not multi-engine Top contention or a TinyNPU comparison. The behavior-level
memory timing does not represent SRAM timing, and 250 MHz remains a reference
conversion only; no ASIC Fmax, area, power, or energy result was measured.

Machine artifacts are [CSV](../../benchmark/v2_matrix_config_closure_f9f32f7_3seed.csv),
[JSON](../../benchmark/v2_matrix_config_closure_f9f32f7_3seed.json), and
[SVG](../../benchmark/v2_matrix_config_closure_f9f32f7_3seed.svg). Logs-only
evidence archive `/tmp/nmaforge_v2_matrix_config_f9f32f7_logs.tar.gz`, SHA-256
`517ca1efaa704aea8bdafe39785d0521cbd461ae8b36feeefbd81010a94d6aaf`.
The archive contains driver, compile, run, and CSV/JSON/SVG text evidence only;
no simulator executable, VDB, or compiled database.

Reproduction (the first command ran once per listed Seed, with a separate
output directory):

```sh
for seed in 20261106 20261107 20261108; do
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
  PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
  make -C dv/block/compute/matrix/sim matrix-config-comparison \
    SEED=$seed \
    MATRIX_CONFIG_OUT=/tmp/nmaforge_v2_matrix_config_f9f32f7_3seed/seed_$seed \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10'
done
python3.12 tools/summarize_matrix_config_closure.py \
  --seed-root 20261106=/tmp/nmaforge_v2_matrix_config_f9f32f7_3seed/seed_20261106 \
  --seed-root 20261107=/tmp/nmaforge_v2_matrix_config_f9f32f7_3seed/seed_20261107 \
  --seed-root 20261108=/tmp/nmaforge_v2_matrix_config_f9f32f7_3seed/seed_20261108 \
  --source-sha f9f32f71e7168350d74a75ede0a4a4b222844cc9 \
  --tree-sha 0b20e98298852d2648f83d10723c55aabe3a9149 \
  --run-id V2-MATRIX-EIGHT-CONFIG-CLEAN-F9F32F7-3SEED \
  --output-dir /tmp/nmaforge_v2_matrix_config_f9f32f7_3seed/summary \
  --tag f9f32f7
```

## Real-Top per-command Matrix profile — `8adf916`

The Top UVM baseline now samples the Matrix controller's passive per-command
counters and separately counts accepted Matrix banked reads and line writes.
At test/source SHA `8adf916e4e8a0e3b2f2e01acc85bacb59fbb8f47` (tree
`a8c232664436c5b1d1f2888eff34439edb40430d`), the standalone `16×32×64`
CMDQ workload passes on three Seeds. The 15 exclusive FSM state counters sum
to the DUT's 490-cycle `cycle_count` on every Seed. The top-level doorbell to
completion interval is 565 cycles. Each run checks all 512 INT32 output words
against the independent Golden and observes 16 A-tile cache hits.

| Measure | Result per Seed |
|---|---:|
| Matrix internal cycles | 490 |
| Doorbell-to-completion cycles | 565 |
| Exclusive MAC-state cycles | 128 |
| Effective MAC/cycle, Matrix internal window | 66.87 |
| Effective array utilization, Matrix internal window | 26.12% |
| Matrix SPAD reads / writes | 3,072 B / 2,048 B |
| A req / A wait; B req / B wait state cycles | 5 / 2; 8 / 4 |
| Prefetch wait / MAC overlap | 180 / 120 cycles |
| Response wait / arbitration stall / writeback wait | 3 / 0 / 0 cycles |
| Outstanding-read high-water / FIFO-full cycles | 2 / 0 |

The `66.87 MAC/cycle` and `26.12%` utilization are workload-average values
over the controller's internal command cycles; during the 128 MAC states the
workload issues 256 INT8 MACs per cycle. The 565-cycle top interval includes
AXI-Lite doorbell and completion polling. Stall and prefetch counters are
diagnostic events and can overlap; they are not added to either cycle total.
This is an isolated single-engine run under the four-bank behavioral SPAD's
registered one-cycle response model. It is not a multi-engine comparison,
TinyNPU win, or ASIC PPA result.

Run ID `V2-TOP-MATRIX-PERF-PROFILE-8ADF916-3SEED`; Seeds
20261125/20261126/20261127 each pass with UVM Warning/Error/Fatal `0/0/0`.
The machine records are [CSV](../../benchmark/v2_top_matrix_profile_8adf916_3seed.csv)
and [JSON](../../benchmark/v2_top_matrix_profile_8adf916_3seed.json). The
reproducible [summarizer](../../tools/summarize_top_matrix_profile.py) validates
the three Seed directories, Golden/pass markers, zero UVM severity counts,
and the FSM-cycle sum. Text-only compile, run and URG evidence is archived at
`/tmp/nmaforge_v2_top_matrix_profile_8adf916_3seed_text.tar.gz`, SHA-256
`9061e496ec0ab9cd317e0768715b9209328c13a8296ecbfc9d72bf5520fcdbda`;
simulator binaries and coverage databases are excluded.

Exact regression command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_matrix_profile_ac6b83_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261125 20261126 20261127'
```

Exact aggregation command:

```sh
python3 tools/summarize_top_matrix_profile.py \
  --run-root /tmp/nmaforge_v2_matrix_profile_ac6b83_3seed \
  --source-sha 8adf916e4e8a0e3b2f2e01acc85bacb59fbb8f47 \
  --tree-sha a8c232664436c5b1d1f2888eff34439edb40430d \
  --run-id V2-TOP-MATRIX-PERF-PROFILE-8ADF916-3SEED \
  --csv benchmark/v2_top_matrix_profile_8adf916_3seed.csv \
  --json benchmark/v2_top_matrix_profile_8adf916_3seed.json
```

VCS is `V-2023.12-SP1_Full64`; aggregation used Python 3.6.8. The broader
matched serial/parallel task benchmark still lacks the same per-command state
profile, and the eight-configuration and TinyNPU results remain tied to their
own source SHAs and memory endpoints.

## Real-Top Matrix profiles under shared-SPAD contention — `f530fe2`

Extended the passive Matrix profile to three existing Top CMDQ workloads at
fixed test/source SHA `f530fe2c4c98204312b7ed16616cb9d9747670b2` (tree
`919ebb411a7b47e0e0b3dfd2084852a83a2a5034`). The same `16×32×64` Matrix
command was sampled alone, staged with a CNM GEMV, and during a dedicated
Matrix-writeback/CNM contention test. Three Seeds (20261128/29/30) produced
identical values. Every profile's 15 exclusive state buckets equal its Matrix
`cycle_count`; the test also passes the 512-word Matrix Golden and the full
Compute Cluster UVM checks with UVM Warning/Error/Fatal `0/0/0` per Seed.

| Matrix profile | Matrix internal cycles | Full CMDQ doorbell-to-completion cycles | Effective MAC/cycle | Array utilization | Matrix SPAD read/write | Arbiter stall | Response wait | Writeback wait | Prefetch wait / MAC overlap |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Standalone | 490 | 565 | 66.87 | 26.12% | 3,072 / 2,048 B | 0 | 3 | 0 | 180 / 120 |
| Matrix + CNM staged | 533 | 613 | 61.48 | 24.02% | 3,072 / 2,048 B | 43 | 6 | 0 | 219 / 120 |
| Matrix writeback stalled by CNM | 844 | 1,837 | 38.82 | 15.17% | 3,072 / 2,048 B | 354 | 9 | 84 | 440 / 120 |

The three windows have different meanings: standalone completion is Matrix;
the staged case retires Matrix and CNM; the writeback case waits for both
Matrix and CNM completions. Matrix SPAD bytes exclude CNM's bank traffic. The
line-stall profile's 84 `writeback_wait` cycles are included in the 844 Matrix
internal cycles; request-arbiter and response wait counters are diagnostic
events and can overlap state/event counts. These results show measurable
contention cost in the existing legal workloads, but do not compare an
alternate arbitration policy or justify Bank-Aware Issue RTL changes.

Machine data is [CSV](../../benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.csv)
and [JSON](../../benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.json).
Text-only logs and URG summaries are archived at
`/tmp/nmaforge_v2_top_matrix_cluster_profile_f530fe2_3seed_text.tar.gz`,
SHA-256 `64f70be1d60805c9898711cfe77f584329e2bd1c285df5b0e99bd5ea8019d542`;
VDBs and simulator binaries are excluded. Exact UVM command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_matrix_cluster_profile_25873ac_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261128 20261129 20261130'
```

Exact aggregation command:

```sh
python3 tools/summarize_top_matrix_profile.py \
  --run-root /tmp/nmaforge_v2_matrix_cluster_profile_25873ac_3seed \
  --source-sha f530fe2c4c98204312b7ed16616cb9d9747670b2 \
  --tree-sha 919ebb411a7b47e0e0b3dfd2084852a83a2a5034 \
  --run-id V2-TOP-MATRIX-CLUSTER-PROFILE-F530FE2-3SEED \
  --expected-seeds 20261128,20261129,20261130 \
  --required-profiles standalone,staged_matrix_cnm,line_stall_matrix_cnm \
  --csv benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.csv \
  --json benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.json
```

The VCS release is `V-2023.12-SP1_Full64`; the checked-in parser runs on Python
3.6.8. CNM, SFU and other engine-internal per-command stalls are not captured
by this Matrix-specific interface, and the broader serial/parallel workload
still lacks a full all-engine timeline. No functional RTM state or product
RTL changed.

### Clean-candidate replay at `839b9af`

The same three-seed Compute Cluster regression and all three profile scenarios
were replayed from a detached clean worktree at source/test SHA
`839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`) using VCS
`V-2023.12-SP1_Full64`. All 3 seeds pass with UVM Warning/Error/Fatal `0/0/0`;
all 9 profile FSM partitions close exactly, and the values are identical to
the `f530fe2` run. This is a clean-candidate reproducibility check, not a new
workload or a different memory model.

The URG aggregate bounds confidence in this replay: functional group score is
83.94% (the declared `cluster_cg` alone is 100%), line/condition/FSM/branch is
70.74/68.33/46.17/67.70%, and assertions have 17/22 real successes with zero
failures/incomplete; two assertions have no attempts and only 1/3 cover
properties matches. The complete three-seed URG disposition is in the [DV
report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

Machine data: [CSV](../../benchmark/v2_top_matrix_cluster_profile_839b9af_3seed.csv),
[profile JSON](../../benchmark/v2_top_matrix_cluster_profile_839b9af_3seed.json),
and [run metadata](../../benchmark/v2_clean_cluster_uvm_839b9af.json). Text-only
logs/URG archive `/tmp/nmaforge_v2_clean_839b9af_cluster_3seed_text.tar.gz`,
SHA-256 `4d036d428c8e72a10490bb7eaf9534158a8df185d46722453e49038a374993f9`.
The 256-MAC behavioral-SPAD profile remains an RTL simulation result; it is
not ASIC timing, power, or TinyNPU comparison evidence.

## Clean-candidate Cache × Prefetch replay — `839b9af`

The four product-GEMV configurations were rerun from a detached clean worktree
at source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`) on Seeds
`20261128/20261129/20261130`. The physical array is 16×16 (256 INT8 MACs),
read outstanding depth is 4, A-Tile Cache is enabled, and the registered
four-bank behavioral SPAD uses seed-controlled randomized ready/response
latency. Four shapes × four Cache/Prefetch configurations × three Seeds
produced 48/48 bit-exact Golden points. All 48 exclusive state partitions
equal command cycles.

| Shape (M×N×K) | B-fold Cache OFF / Prefetch OFF | Cache ON / Prefetch OFF | Cache OFF / Prefetch ON | Cache ON / Prefetch ON | Read bytes OFF→ON |
|---|---:|---:|---:|---:|---:|
| 8×16×19 | 198.3 | 155.0 | 192.3 | 151.3 | 864→560 (−35.2%) |
| 8×16×65 | 541.3 | 388.0 | 522.0 | 379.7 | 2,720→1,696 (−37.6%) |
| 16×16×19 | 407.7 | 266.0 | 394.0 | 257.7 | 1,728→816 (−52.8%) |
| 16×16×65 | 1,077.0 | 639.0 | 1,027.0 | 641.3 | 5,440→2,368 (−56.5%) |

Cycles are means over the three Seeds. At these tested shapes, B-fold Cache
alone reduces command cycles by 21.9–40.7%; Cache ON reduces read traffic by
35.2–56.5%. With Cache ON, Prefetch improves the first three shapes by
2.4%, 2.2%, and 3.1%, while the 16×16×65 result is 0.4% slower. Prefetch
does not reduce read bytes; its measured overlap is 8/32/16/64 cycles for
the four shapes with Cache ON. Command-window utilization is 4.7–10.2% and
useful MAC rate is 11.9–26.0 MAC/cycle, so these small-M cases still leave
substantial array capacity unused. This data supports bounded B-fold reuse
for the measured workload; it does not establish a scheduler RTL change,
full-Top throughput, silicon benefit, or TinyNPU win.

Machine data: [48-point CSV](../../benchmark/v2_gemv_four_way_clean_839b9af_3seed.csv),
[summary JSON](../../benchmark/v2_gemv_four_way_clean_839b9af_3seed_summary.json),
and [configuration chart](../../benchmark/v2_gemv_four_way_clean_839b9af_3seed.svg).
The simulator is Synopsys VCS `V-2023.12-SP1_Full64`; aggregation used Python
`3.12.13`.
Text-only compile/run logs and per-Seed summaries are archived outside Git at
`/tmp/nmaforge_v2_clean_839b9af_gemv_four_way_text.tar.gz`, SHA-256
`4210b6af9cc45212732fa23ae69df1fbfe5ec3ae6d3335f76815fd4b5d9afa58`;
coverage databases and simulator executables are excluded.

Exact replay and aggregation commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation \
  SEEDS='20261128 20261129 20261130' \
  GEMV_FOUR_WAY_OUT=/tmp/nmaforge_v2_clean_839b9af_gemv_four_way

python3.12 tools/merge_gemv_four_way_ablation.py \
  --output-prefix benchmark/v2_gemv_four_way_clean_839b9af_3seed \
  /tmp/nmaforge_v2_clean_839b9af_gemv_four_way/summary_seed_20261128.csv \
  /tmp/nmaforge_v2_clean_839b9af_gemv_four_way/summary_seed_20261129.csv \
  /tmp/nmaforge_v2_clean_839b9af_gemv_four_way/summary_seed_20261130.csv
```

The Matrix-core experiment is isolated from the TinyNPU and full-CMDQ
measurement boundaries. The existing same-workload TinyNPU comparison and a
Top-level all-engine performance decomposition remain open.

## Research closure round 2 addendum — model-level boundaries

The bounded 128/512 KiB Digits MLP rerun is on test/source commit
`acfaec281f5414c0e357c1dc7985b79a829c8c30`; product RTL is unchanged. Both
compact-map runs use VCS `V-2023.12-SP1_Full64`, seed `20261029`, four-bank
behavioral SPAD and 16×16/256-MAC Matrix. They produce 34,761 doorbell-to-CPLQ
cycles, 23,552 fused native tile-write bytes, 1,884,160 useful MACs, 54.2033
MAC/cycle, and 21.17% derived array utilization. Output CSV SHA-256 is
`7980fb678505ae0590d13c2f590b9523a98bedee7c3037936ccacb9b10360e9c` for both
capacities; independent integer Golden recheck passes all 360 samples at
97.78% classification accuracy. The compact map high-water is 93,184 B.

The existing trained Digits MLP legacy/fused comparison remains model-level
evidence for Innovation 2: 110,155 versus 34,761 doorbell-to-completion cycles
(68.44% lower in the fused run), exact logits and matching 352/360 accuracy.
The runs have different layout-counter definitions, so their layout-byte
fields are not compared. The 48-point Cache×Prefetch GEMV ablation remains
controlled fixed-shape evidence for Innovation 1; a trained/model-level GEMV
ablation is **NOT_RUN**.

The mini CNN's 1,080 Host Layout cycles are 180 AXI-Lite transfers at six
cycles each: each of 36 convolution feature groups is read once and written
four times to form the flattened FC operand (144 B read, 576 B write). The
current consumer needs a flat K=144 vector, whereas `0x53` writes native
Matrix-A tile layout. Direct forwarding does not preserve that tensor shape;
the same CNN Legacy/Fused comparison is therefore **NOT_RUN** and no speedup
is claimed. Existing mini-CNN cycle values (NMAForge 1,985 compute + 1,080
host layout; TinyNPU 4,781 graph cycles) have different boundaries and remain
unratioed.

The 128 KiB MLP/Transformer records and fixture limitations are listed in the
[round-2 matrix](../../benchmark/v2_round2_research_closure_20261106.json).
No capacity result establishes streamed execution for a >128 KiB live set;
no current checked-in workload with such a live set was identified.
