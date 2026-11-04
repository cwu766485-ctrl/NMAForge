# Shape-Adaptive GEMM/GEMV — First Product Integration Slice

**Status:** Product GEMV supports bounded dense shapes through 16×16 with N/K tail masking, A-line reuse, and bounded next-K prefetch/MAC overlap. The overlap is measured on three seeds per shape using a registered behavioral-SPAD model. Bank-aware issue scheduling, full fault/coverage closure, architecture-wide performance, and sign-off remain open.
**Frozen v2 base:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`.
**RTL integration commit:** `3db6cf76781e9c98ec1396315ccf4ab26af58214`.
**Profile/checker commits:** `c042fd3b5914fe616da5a12dd08a4f4a8b326cd4` and
`70c8aad94e9e8d16bf67d0e4667effb58977ccf7`.
**A-line reuse commit:** `cf6cd1e1e81e9b9372c13a44e3fc64e775b4ca6c`.
**Simulator:** Synopsys VCS `V-2023.12-SP1_Full64`.

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

## Open work

- Product shape tests do not yet enumerate every M/N/K combination, especially
  M8 and scalar N=1; descriptor randomization and a shape matrix remain open.
- Extend the bounded prefetch into bank-aware request issue/scheduling; the
  current one-request-per-cycle path does not reduce SPAD bytes and leaves
  repeated B fetches across row tiles.
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
