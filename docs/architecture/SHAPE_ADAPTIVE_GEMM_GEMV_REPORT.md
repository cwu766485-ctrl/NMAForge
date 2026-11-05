# Shape-Adaptive GEMM/GEMV — First Product Integration Slice

**Status:** Product GEMV supports bounded dense shapes through 16×16 with N/K tail masking, A-line reuse, bounded next-K prefetch/MAC overlap, and command-local B-fold reuse for multi-row tiles. Prefetch and B-cache effects are measured with a registered behavioral-SPAD model. Bank-aware issue scheduling, full fault/coverage closure, architecture-wide performance, and sign-off remain open.
**Frozen v2 base:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`.
**RTL integration commit:** `3db6cf76781e9c98ec1396315ccf4ab26af58214`.
**Profile/checker commits:** `c042fd3b5914fe616da5a12dd08a4f4a8b326cd4` and
`70c8aad94e9e8d16bf67d0e4667effb58977ccf7`.
**A-line reuse commit:** `cf6cd1e1e81e9b9372c13a44e3fc64e775b4ca6c`.
**Simulator:** Synopsys VCS `V-2023.12-SP1_Full64`.

**License-restored replay update (2026-11-05):** the initial `BLOCKED_ENV / NOT_RUN`
attempts recorded later in this report have been superseded for the M8/M16
B-cache ablation, M8 real-CMDQ descriptor, and descriptor alias/range-validator
regression. All three targets now pass; exact commands, results, and archived
logs are in the [license-restored replay record](../verification/V2_LICENSE_RESTORED_REPLAY_2026-11-05.md).
The feature-specific fault/coverage matrix, all-shape sweep, PPA, and common-
resource TinyNPU comparison remain open.

## Implemented scope

The additive ABI-v7 opcode `0x52` is connected through the descriptor decoder,
validator, parallel dispatcher, Matrix controller, and software header. It
reuses the existing 16×16 / 256-MAC Matrix array and accumulator bank. The
controller accepts bounded dense shapes with `1<=M,N<=16`, `K>=1`, and
16-byte-aligned source addresses. A rows are padded to 16-byte strides and B
- Dense A is `[M,K]`; dense B is `[K,N]`, with each B row occupying 16 bytes.
- No transpose, nonzero strides, multi-batch, nonzero head count, or nonzero
  `aux0`; reserved `flags[7:1]` must be zero and `flags[0]` must match
  `bias_enable`. Unsupported descriptors are rejected before engine dispatch.
- Existing optional column bias, scale shift, activation, INT32 output, and
  ordered line writeback are exercised by the Matrix-core Golden case.

The shape extension and exact operand layout are specified in
[`NPU_ARCHITECTURE_V2_SPEC.md`](../spec/NPU_ARCHITECTURE_V2_SPEC.md). The
directed controller tests cover the original M4 workload, M1 with both an N
tail and a K tail, and M16 across four row tiles with a K tail. The real Top
Smoke path covers M1/N13/K17 through the command queue and completion path.
The implementation uses padded A rows, 16-byte B rows, K-lane zero masking,
and scalar output writes for partial or unaligned groups.

The Matrix controller test checks the complete 64-word output image against an
independent signed INT64 accumulation followed by bias, arithmetic shift, and
ReLU. The real-top test submits an ABI-v7 descriptor with bias enabled, shift
1, and ReLU through CMDQ/dispatcher, checks all 64 result words and the
completion, and checks that `K=20` is rejected as `ERR_DESC_INVALID` without
modifying the destination sentinel.

## Measured Matrix-core profile and A-line reuse

The matched workload is `M=4,N=16,K=32`, for 2,048 useful signed INT8 MACs.
The baseline and optimized controller runs use the same registered
behavioral-SPAD request/response model, workload data, Golden, and three Seeds.
The baseline is detached source `8cff28689838d432151d8130b17db4e8a27c7632`
with the A-tile cache disabled. The optimized source is
`cf6cd1e1e81e9b9372c13a44e3fc64e775b4ca6c`; generic A-cache tag matching is
disabled while opcode `0x52` uses its distinct dense layout. The 3.05% figure
in the earlier product-integration snapshot was measured before this change.
This A-line-only profile predates next-K prefetch; the zero prefetch/overlap
counters below describe that historical run, not the current controller.

| Metric | Baseline | A-line reuse | Change |
|---|---:|---:|---:|
| Matrix command cycles | 269 | 214 | −20.45% |
| MAC-active cycles | 8 | 8 | unchanged |
| Useful MAC/cycle | 7.61 | 9.57 | +25.7% |
| 16×16 array utilization over command | 2.97% | 3.74% | +0.77 pp |
| Accepted banked operand reads | 64 | 40 | −37.5% |
| Operand read bytes | 1,024 B | 640 B | −37.5% |
| Bias read + output writes | 64 B + 256 B | 64 B + 256 B | unchanged |
| Outstanding read high-water | 4 | 4 | unchanged |
| Prefetch completed / fetch-MAC overlap | 0 / 0 | 0 / 0 | unchanged |

The controller now retains each staged A line across its four K-fold uses,
reducing the K32 operand fetch from 32 A-line reads plus 32 B-line reads to 8
A-line reads plus 32 B-line reads. Thus operand-plus-output traffic is 960 B
(640 B reads, 64 B bias, 256 B output), excluding CMDQ descriptor fetch. The
cycle and byte changes are measured in this core-level model; they are not a
TinyNPU comparison, ASIC throughput, or a full-chip performance result.

The product test first runs a legacy GEMM at the same A base to populate the
generic A-tile cache, asserts that the cache tag is valid, then runs GEMV and
checks that the differently laid-out GEMV does not hit that cache. All 64
outputs remain bit-exact. A prior 262-cycle / 1,024-B profile predates this
optimization and is retained only as historical integration evidence.
GEMM-vs-GEMV common-workload and TinyNPU comparisons are **NOT_RUN**. Any
250 MHz normalization is a calculation, not measured frequency or ASIC
throughput. PPA is **NOT_RUN**.

The following profile counters are reported per run. Stall categories are
observational and can overlap; they must not be summed as disjoint cycles.

| State/counter | Value per seed |
|---|---:|
| A request / A response wait | 15 / 9 cycles |
| B request / B response wait | 41 / 33 cycles |
| Bias request / bias response wait | 25 / 51 cycles |
| Prepare / MAC / write / next | 8 / 8 / 22 / 1 cycles |
| Arbitrated request stall / response wait | 25 / 73 cycles |
| Writeback wait | 6 cycles |
| Error / error drain / prefetch wait | 0 / 0 / 0 cycles |

## Verification evidence

| Run ID | Exact command | Run / evidence path | Result |
|---|---|---|---|
| `V2-PRODUCT-GEMV-CORE-S3-20261104` | `make product-gemv-regress CORE_OUT_DIR=/tmp/nmaforge_v2_product_gemv_profile2_20261104 SEEDS='20261104 20261105 20261106'` | Source `70c8aad94e9e8d16bf67d0e4667effb58977ccf7`; logs `/tmp/nmaforge_v2_product_gemv_profile2_20261104/product_gemv_seed_20261104.log` through `...20261106.log` | PASS: 3/3 full-Golden output images, 3/3 request/response drain checks, and identical profile above. |
| `V2-PRODUCT-GEMV-TOP-SMOKE-20261104` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261104 SEED=20261104` | Source RTL `44b9fd792995da4695186746e2887fda0f26bb54`; `/tmp/nmaforge-architecture-v2/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | PASS: `TEST PASS`; descriptor marker confirms bias/shift/ReLU and all outputs; invalid K-tail rejection marker passes; existing top smoke checks pass. |
| `V2-PRODUCT-GEMV-CLEAN-CORE-S3-10aa2ed` | `make product-gemv-regress CORE_OUT_DIR=/tmp/nmaforge_v2_product_gemv_clean_10aa2ed SEEDS='20261104 20261105 20261106'` | Clean detached worktree at `10aa2ed903cb5298317617a1ca7c2c15819774e7`; logs `/tmp/nmaforge_v2_product_gemv_clean_10aa2ed/product_gemv_seed_20261104.log` through `...20261106.log` | PASS: all three seeds reproduce the exact Golden image and 262-cycle profile. |
| `V2-PRODUCT-GEMV-CLEAN-TOP-10aa2ed` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261104 SEED=20261104` | Same clean SHA; `/tmp/nmaforge-v2-gemv-clean-10aa2ed/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | PASS: `TEST PASS`, product descriptor success and `K=20` rejection both present. |
| `V2-GEMV-AREUSE-MATCHED-BASELINE-S3` | `make product-gemv-regress CORE_OUT_DIR=/tmp/nmaforge_v2_gemv_baseline_8cff286 SEEDS='20261104 20261105 20261106' A_TILE_CACHE_ENABLE=0` | Detached source `8cff28689838d432151d8130b17db4e8a27c7632`; measurement-only testbench copy under `/tmp/nmaforge-v2-gemv-baseline-8cff286`; logs in `/tmp/nmaforge_v2_gemv_baseline_8cff286/` | PASS: 3/3 Golden; each run 269 cycles, 64 reads / 1,024 B. |
| `V2-GEMV-AREUSE-CLEAN-CORE-S3-cf6cd1e` | `make core-random-regress CORE_OUT_DIR=/tmp/nmaforge_v2_gemv_clean_cf6cd1e_core SEEDS='20261104 20261105 20261106'` | Clean detached worktree SHA `cf6cd1e1e81e9b9372c13a44e3fc64e775b4ca6c`; per-seed logs `/tmp/nmaforge_v2_gemv_clean_cf6cd1e_core/{run_seed,product_gemv_seed}_*.log` | PASS: 3/3 random-core regression (18 directed/random cases and fault/recovery checks per seed); 3/3 GEMV Golden, 214 cycles, 40 reads / 640 B; collision precondition and zero GEMV cache hits checked. |
| `V2-GEMV-AREUSE-CLEAN-TOP-cf6cd1e` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261104 SEED=20261104` | Same clean SHA; `/tmp/nmaforge-v2-gemv-clean-cf6cd1e/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | PASS: `TEST PASS`; original opcode `0x52` descriptor Golden passed. This predates the shape extension. |

The original product-path test checks all 64 values and all 16 output line
writes. New runs and their detailed profile are recorded below. These tests do
not prove broad descriptor coverage or a full-chip memory scoreboard. The Top
Smoke compile retains its pre-existing Transformer fixture loop-reroll notice;
it is not introduced by opcode `0x52`.

## Dense shape and tail extension — 2026-11-04

The controller now accepts `1<=M,N<=16` and `K>=1` for opcode `0x52`. A rows
use a 16-byte-rounded physical stride, B uses one 16-byte row per K element,
K-tail lanes and N-tail columns are masked, and partial output groups use the
ordered scalar SPAD path. The descriptor validator admits the same shape
range while continuing to reject unsupported stride, transpose, batch, head,
and reserved-field modes. No legacy `0x30` or `0x53` behavior changed.

VCS `V-2023.12-SP1_Full64` profile with a registered behavioral-SPAD model:

| Shape | Command cycles | MAC-active cycles | Operand reads | Read bytes | Output writes | Golden |
|---|---:|---:|---:|---:|---|---|
| M1/N13/K17 | 71 | 5 | 19 | 304 B | 3 full lines + 1 scalar word | Bit-exact, all 13 outputs; N-tail sentinel preserved |
| M16/N16/K19 | 404 | 20 | 108 | 1,728 B | 64 full lines | Bit-exact, all 256 outputs |

For M16/N16/K19, 32 accepted reads fetch A (two padded lines per output
row); B is reread for each of the four 4-row tiles, accounting for 76 of the
108 reads. This is a measured remaining traffic opportunity, not an optimized
result. All three Seeds produced identical cycles, reads, write counts, and
Golden results.

| Run ID | Exact command | Evidence path | Result |
|---|---|---|---|
| `V2-GEMV-SHAPE-CORE-S3-20261104` | `make product-gemv-regress CORE_OUT_DIR=/tmp/nmaforge_v2_gemv_shape_core_20261104 SEEDS='20261104 20261105 20261106'` | `/tmp/nmaforge_v2_gemv_shape_core_20261104/product_gemv_seed_*.log` | PASS: 3/3 seeds; original M4 case, M1/N13/K17 and M16/N16/K19 full Golden and drain checks. |
| `V2-GEMV-SHAPE-RANDOM-CORE-S3-20261104` | `make core-random-regress CORE_OUT_DIR=/tmp/nmaforge_v2_gemv_tail_random_20261104 SEEDS='20261104 20261105 20261106'` | `/tmp/nmaforge_v2_gemv_tail_random_20261104/{run_seed,product_gemv_seed}_*.log` | PASS: existing 18-case/fault core regression and all three product GEMV Goldens on each seed. |
| `V2-GEMV-SHAPE-TOP-SMOKE-20261104` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261104 SEED=20261104` | `dv/subsystem/top_smoke/sim/ai_accel_smoke.log` in this worktree | PASS: Top Smoke `TEST PASS`; legacy M4 descriptor and M1/N13/K17 descriptor both match independent Golden; tail sentinels and 13-word completion count pass. |

## Next-K prefetch / MAC overlap — 2026-11-05

Opcode `0x52` now requests the next legal B K-group into the inactive local
operand buffer while the current K-group is executing. When the next A group
maps to the same aligned 16-byte A line already retained locally, the controller
reuses that line rather than issuing another read. Existing response-owner,
destination-buffer, FIFO ordering, and outstanding limits remain in force.
This adds control logic but no new SRAM or operand-buffer bits; area impact is
**NOT_RUN** because this change has not been synthesized.

The paired ablation used the same workload, Golden, registered four-bank
behavioral-SPAD responder, VCS version, and three independent responder seeds
with prefetch enabled and disabled. The testbench LFSR is seeded from `+SEED`,
so each seed selects a different Ready/latency trace. All runs matched the
independent signed Golden and drained accepted requests.

| Shape | Prefetch OFF cycles (seeds 20261104/05/06) | Prefetch ON cycles (same seeds) | Mean reduction | Useful MAC/cycle OFF → ON | Accepted reads / bytes OFF → ON | ON prefetch completed / overlap |
|---|---:|---:|---:|---:|---:|---:|
| M4/N16/K32 | 214 / 213 / 220 (215.67 mean) | 206 / 208 / 216 (210.00 mean) | 2.63% | 9.50 → 9.75 | 40 / 640 B → 40 / 640 B | 7 / 7 |
| M1/N13/K17 | 78 / 74 / 73 (75.00 mean) | 75 / 74 / 69 (72.67 mean) | 3.11% | 2.95 → 3.04 | 19 / 304 B → 19 / 304 B | 4 / 4 |
| M16/N16/K19 | 407 / 403 / 394 (401.33 mean) | 385 / 381 / 387 (384.33 mean) | 4.24% | 12.12 → 12.66 | 108 / 1,728 B → 108 / 1,728 B | 16 / 16 |

The counters show latency hiding, not traffic reduction: operand read bytes are
unchanged. M16/N16/K19 still spends 76 of 108 reads fetching B again across
four row tiles. This is bounded overlap in the current controller, not a
bank-aware multi-request scheduler or a full-chip speedup claim. These cycles
are from the core-level behavioral model and are not TinyNPU measurements,
silicon results, or ASIC PPA.

| Run ID | Exact command | Evidence path | Result |
|---|---|---|---|
| `V2-GEMV-PREFETCH-ON-ABLATION-S3-20261105` | `make product-gemv-prefetch-ablation CORE_OUT_DIR=/tmp/nmaforge_v2_gemv_prefetch_seeded_on_20261104 SEEDS='20261104 20261105 20261106' NEXT_K_PREFETCH_ENABLE=1` | `/tmp/nmaforge_v2_gemv_prefetch_seeded_on_20261104/ablation_{M4,M1,M16}_SHAPE_*.log` | PASS: all 9 shape/seed runs Golden and drain checks; ON cycles and overlap counters as above. |
| `V2-GEMV-PREFETCH-OFF-ABLATION-S3-20261105` | `make product-gemv-prefetch-ablation CORE_OUT_DIR=/tmp/nmaforge_v2_gemv_prefetch_seeded_off_20261104 SEEDS='20261104 20261105 20261106' NEXT_K_PREFETCH_ENABLE=0` | `/tmp/nmaforge_v2_gemv_prefetch_seeded_off_20261104/ablation_{M4,M1,M16}_SHAPE_*.log` | PASS: all 9 paired runs Golden and drain checks; no prefetch requests. |
| `V2-GEMV-PREFETCH-RANDOM-CORE-S3-20261105` | `make core-random-regress CORE_OUT_DIR=/tmp/nmaforge_v2_gemv_prefetch_seeded_random_20261104 SEEDS='20261104 20261105 20261106' NEXT_K_PREFETCH_ENABLE=1` | `/tmp/nmaforge_v2_gemv_prefetch_seeded_random_20261104/{run_seed,product_gemv_seed}_*.log` | PASS: 3/3 seeds; 18 cases and 35 fault/recovery checks per seed, with product GEMV Goldens. |
| `V2-GEMV-PREFETCH-TOP-SMOKE-20261104` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261104 SEED=20261104` | `/tmp/nmaforge-architecture-v2/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | PASS: Top Smoke, including M4 and M1/N13/K17 product descriptors. The top smoke predates the testbench-only LFSR seed correction. |

## B-fold reuse across row tiles — 2026-11-05

The M16 K-fold mapping reread B for each four-row output tile. Opcode `0x52`
now reuses the existing 1 KiB local reuse array as a command-exclusive cache
for the first 16 K-fold groups (64 logical K values), while the current B tile
is staged in the existing ping-pong operand banks. This adds no operand data
array; it adds a 16-bit group-valid map and cache control. The cache is used
only when `M>4`, and K groups above 64 bypass it. If the B physical span
overlaps the destination span, the reuse path is disabled. Software must keep
operands stable throughout the command and prevent another engine from
modifying them; no cross-engine coherence or source snapshot is provided. The
descriptor validator now computes A/B/output/enabled-bias spans for `0x52`,
rejects output overlap and 32-bit end-address wrap. Focused checker cases were
added, but remain unverified until VCS runs the validator regression.

Paired VCS runs used the same shape, Golden, behavioral four-bank registered
SPAD responder, simulator version, prefetch setting, and seed values with the
B cache compiled off and on. Each run checked all 256 INT32 outputs against an
independent signed Golden and verified request drain. The reported effective
MAC/cycle and command-window array utilization are derived as useful
`M*N*K` MACs divided by command cycles, and by `256 * command cycles`,
respectively; they are not a separate hardware occupancy counter.

| Shape | B cache OFF cycles (3 seeds) | B cache ON cycles (same seeds) | Mean cycle change | Read traffic OFF → ON | Useful MAC/cycle OFF → ON | Derived command-window array utilization OFF → ON |
|---|---:|---:|---:|---:|---:|---:|
| M16/N16/K19 | 381 / 387 / 395 (387.67 mean) | 266 / 264 / 255 (261.67 mean) | −32.50% | 108 / 1,728 B → 51 / 816 B (−52.78%) | 12.55 → 18.59 | 4.90% → 7.26% |
| M16/N16/K65 | 1,006 / 1,056 / 1,046 (1,036 mean) | 609 / 642 / 629 (626.67 mean) | −39.51% | 340 / 5,440 B → 148 / 2,368 B (−56.47%) | 16.06 → 26.55 | 6.27% → 10.37% |

For K19, the cache avoids 57 16-byte B-row reads across the three repeated row
tiles; for K65, it avoids 192 reads for the first 64 K values and fetches the
final K group normally. Output writes stay at 1,024 B / 64 lines for each run. A
single-seed, prefetch-disabled check also passes: K19 cycles 403→273 and K65
cycles 1,074→617, with the same read reduction and bit-exact outputs. These
results isolate B reuse with `ENABLE_NEXT_K_PREFETCH=1` for the three-seed
table; they do not isolate it from all controller interactions or demonstrate
TinyNPU performance.

No synthesis or PPA run was performed. The 16 valid bits and cache-control
logic have not been mapped to area or timing; no extra operand data bits were
introduced. The table's utilization is a derived command-window ratio, not an
ASIC or measured active-array occupancy result. Per-state and aggregate stall
counters below are observed testbench profile counters; categories can
overlap, so they must not be summed as disjoint cycles. The RTL source is
`2e61ff71e1f67b85f68229026d6468036122e9c8`; the profile test source is
`20d393c5e0e1a32388cce1112a4a20a32e05b5a5`. Raw per-seed values are in
[`shape_adaptive_gemv_b_cache_ablation.csv`](../../benchmark/shape_adaptive_gemv_b_cache_ablation.csv).

| Shape | Profile counter mean, B cache OFF → ON (cycles) |
|---|---|
| M16/N16/K19 | B request 20.67→4.00; B response wait 16.67→5.00; prefetch wait 183.67→84.67; arbiter stall 61.00→41.00; response wait 31.33→18.00; writeback wait 21.67→22.33; Bank Stall 39.33→18.67; line stall 21.67→22.33 |
| M16/N16/K65 | B request 20.33→6.00; B response wait 16.67→3.67; prefetch wait 734.67→357.67; arbiter stall 148.33→72.00; response wait 33.00→20.67; writeback wait 21.67→16.67; Bank Stall 126.67→55.33; line stall 21.67→16.67 |

| Run ID | Exact command | Evidence path | Result |
|---|---|---|---|
| `V2-GEMV-B-CACHE-ABLATION-S3-20261105` | `make product-gemv-b-cache-ablation SEEDS='20261105 20261106 20261107' CORE_OUT_DIR=/tmp/nmaforge_gemv_b_cache_profile_final_20261105` | `/tmp/nmaforge_gemv_b_cache_profile_final_20261105/b_cache_{0,1}/m16_seed_*.log` | PASS: six paired K19/K65 runs; Golden, full outputs, read count, cache hits/saved reads, stall profiles, and drain checks pass. |
| `V2-GEMV-B-CACHE-NO-PREFETCH-20261105` | `make product-gemv-b-cache-ablation SEEDS='20261105' CORE_OUT_DIR=/tmp/nmaforge_gemv_b_cache_no_prefetch_final_20261105 NEXT_K_PREFETCH_ENABLE=0` | `/tmp/nmaforge_gemv_b_cache_no_prefetch_final_20261105/b_cache_{0,1}/m16_seed_20261105.log` | PASS: K19 and K65 with prefetch disabled, cache off/on, full Golden and drain checks. |
| `V2-GEMV-B-CACHE-RANDOM-CORE-S3-20261105` | `make core-random-regress SEEDS='20261105 20261106 20261107' CORE_OUT_DIR=/tmp/nmaforge_gemv_b_cache_core_regress_final_20261105` | `/tmp/nmaforge_gemv_b_cache_core_regress_final_20261105/{run_seed,product_gemv_seed}_*.log` | PASS: 18 core cases and 35 fault/recovery checks per seed; product M4, M1-tail, M16/K19, and M16/K65 Golden/drain checks pass on all three seeds. |
| `V2-GEMV-B-CACHE-TOP-SMOKE-20261105` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105` | `dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | PASS: `TEST PASS`; existing opcode `0x52` M4 and M1 tail descriptor checks pass. Existing `LOOP-REROLL-ENABLED` notice remains. |

## Same-seed B-fold-cache × next-K-prefetch ablation — 2026-11-05

Published evidence/summary commit: `d4d09ad58f882a5e2d59091073fd447bbb3dfaca`.

The existing cache-off/on and prefetch-off/on runs provide a matched 2×2
controller ablation for `M=16,N=16`, with the same RTL SHA
`2e61ff71e1f67b85f68229026d6468036122e9c8`, profile/test SHA
`20d393c5e0e1a32388cce1112a4a20a32e05b5a5`, Seed `20261105`, workload,
registered four-bank behavioral SPAD, and VCS version. All eight cells
reported bit-exact Golden output and completed the self-checking output/drain
checks in the Matrix-core testbench.

| K | Cache off / prefetch off | Cache off / prefetch on | Cache on / prefetch off | Cache on / prefetch on | Combined cycle change | Read traffic, base → combined |
|---:|---:|---:|---:|---:|---:|---:|
| 19 | 403 cycles, 108 reads | 381, 108 | 273, 51 | 266, 51 | −34.0% | 1,728 B → 816 B (−52.8%) |
| 65 | 1,074 cycles, 340 reads | 1,006, 340 | 617, 148 | 609, 148 | −43.3% | 5,440 B → 2,368 B (−56.5%) |

In this one-seed run, prefetch alone changes cycles by −5.5% (K19) and −6.3%
(K65) without changing read bytes. B-fold reuse alone changes cycles by −32.3%
and −42.5%, while removing 57 and 192 B-row reads respectively. Combining
both saves another 7 cycles at K19 and 8 cycles at K65 relative to cache-only.
Each configuration writes the same 1,024 output bytes through 64 lines.

This is a sub-ablation inside the product `0x52` K-fold implementation. It is
not a matched `0x30` GEMM-vs-GEMV baseline, a multi-seed confidence result, or a
TinyNPU comparison. The prefetch-off logs do not include the detailed state
stall profile emitted by the instrumented prefetch-on build, so a complete
four-way stall decomposition remains open. The eight raw measurements and
configuration checks are summarized by
[`summarize_gemv_four_way_ablation.py`](../../tools/summarize_gemv_four_way_ablation.py)
into [`shape_adaptive_gemv_four_way_ablation.csv`](../../benchmark/shape_adaptive_gemv_four_way_ablation.csv).

The summary command used the four logged runs with `--seed 20261105`, RTL SHA
`2e61ff71e1f67b85f68229026d6468036122e9c8`, and test SHA
`20d393c5e0e1a32388cce1112a4a20a32e05b5a5`. It verified the compile-time
cache/prefetch defines, array size, outstanding depth, run seed, both K-shape
PASS markers, Golden status, read/line counts, and feature counters before
writing the CSV. This evidence is tied to those earlier source/test SHAs; it
does not validate the later descriptor-validator or M8-test changes.

## M8 multi-row case expansion — initial attempt BLOCKED_ENV, replay PASS

The Matrix-core testbench and ablation target now include M8/N16/K19 and
M8/N16/K65 alongside the existing M16 cases. The test expansion compares B-cache off/on, verifies the complete output
image and drain, and checks the expected 54→35 operand reads for K19 and
170→106 for K65. Those counts were initially analytical expectations; the
license-restored three-seed run later measured and confirmed them (see the
replay evidence linked above).

Attempted command:
`make product-gemv-b-cache-ablation SEEDS='20261105' CORE_OUT_DIR=/tmp/nmaforge_gemv_b_cache_m8_first_20261105`.
VCS reported `Cannot connect to the license server` and queued for a
`VCS-BASE-COMPILE/VCSCompiler_Net` license before source compilation. The run
was interrupted after the queue wait; no M8 or new M16 simulation ran. Status
was initially **BLOCKED_ENV / NOT_RUN**. That result was superseded by the
three-seed replay recorded in the license-restored report. The test expansion is committed as
`0a500d17d997dd96dad5cd797849e5a71dfcc6e6`.

A bounded retry of `make product-gemv-b-cache-ablation SEEDS='20261105'
CORE_OUT_DIR=/tmp/nmaforge_gemv_b_cache_m8_retry_20261105` was stopped after
50 seconds. VCS again could not connect to the license server and produced no
simulator image.

## M8 real-CMDQ descriptor case — initial attempt BLOCKED_ENV, replay PASS

Test addition commit: `f4d77afe55c1869cb53c5d8fa9356b449595d9a4`.

Top Smoke now also submits `M=8,N=16,K=19` through the ABI-v7 CMDQ,
descriptor validator, dispatcher, product Matrix controller and SPAD. It
poisons the padded A lane, checks all 128 INT32 outputs against an independent
signed scalar Golden, verifies the 32 aligned output line writes, and checks
completion byte count and result. This complements the existing real-top M4
and M1/N-tail/K-tail descriptors; it is new test coverage, not evidence that
M8 passed.

Attempted command:
`timeout -k 3s 50s make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105`.
The mapper/code-generation precheck passed, then VCS failed to check out
`VCS-BASE-COMPILE/VCSCompiler_Net` before compiling the SystemVerilog source.
No simulator image or RTL run was produced by this initial attempt. The result
was superseded by the license-restored Top Smoke replay, which passes the M8
Golden, line-write count, and completion checks; see the linked replay record.

## Open work

- Product shape tests do not yet enumerate every M/N/K combination. M8/K19
  and M8/K65 B-cache ablations and the M8 real-CMDQ K19 case now pass the
  named checks; Scalar N=1 and a broader shape matrix remain open.
- Extend the bounded prefetch into bank-aware request issue/scheduling; the
  current B-fold cache is limited to the first 64 K values and depends on
  cross-engine operand immutability. Larger K values still reread B beyond
  the cached prefix.
- The `0x52` alias/range validator and focused regression now pass the named
  descriptor boundary checks. Broader product fault/phase coverage remains
  open.
- Add fault/phase coverage for parity, protection, Abort, reset, output
  backpressure, and response ownership for opcode `0x52`.
- Add descriptor mutation and coverage disposition; mutation is **NOT_RUN**.
- Add real top multi-engine contention and independent full-SPAD scoreboard.
- Run the eight-configuration benchmark for the new opcode only after its
  shape contract supports a meaningful same-workload comparison.
- TinyNPU common-resource comparison and ASIC PPA remain **NOT_RUN**.

This change does not alter the v1.0 Compute Cluster disposition (**HOLD**) and
does not close the broader v2 architecture target. Next work should improve
bank-aware issue and B reuse across M tiles while preserving response ownership
and Abort/Reset behavior.

## `0x52` descriptor range enforcement — initial attempt BLOCKED_ENV, replay PASS

RTL/test commit: `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

The validator now derives byte spans for padded dense A, dense B, contiguous
INT32 output, and enabled bias. Opcode `0x52` descriptors are rejected when
the output intersects any read span or when a span end wraps the 32-bit byte
address space. The descriptor test adds four rejected cases (A, B, bias
overlap and B-range overflow) plus an accepted exact-adjacency case. The
Top Smoke's existing M4 shape places B immediately before output; that legal
adjacency is deliberately accepted by the half-open interval rule.

The result-count marker is updated to 33 invalid-rule checks and 43 accepted
boundaries. The initial focused `make descriptor-validator-regress
DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_descriptor_validator_gemv_alias_20261105`
attempt failed before compilation because VCS could not obtain
`VCS-BASE-COMPILE/VCSCompiler_Net`. The required same-change Top Smoke command
`timeout -k 3s 50s make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105`
also failed at the same license checkout point after mapper generation.
Neither initial attempt produced a simulator image or runtime result. Both were
superseded after license restoration: the descriptor validator passed 33
invalid-rule checks, 43/43 accepted boundaries, 26/26 rejected boundaries, and
3/3 tile-forward descriptor cases; Top Smoke passed at the tested tree. See the
[replay evidence](../verification/V2_LICENSE_RESTORED_REPLAY_2026-11-05.md).
