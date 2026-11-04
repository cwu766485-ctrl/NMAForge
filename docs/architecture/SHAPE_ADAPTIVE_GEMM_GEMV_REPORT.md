# Shape-Adaptive GEMM/GEMV — First Product Integration Slice

**Status:** Functional product-path slice demonstrated; no performance win claimed.
**Frozen v2 base:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`.
**RTL integration commit:** `3db6cf76781e9c98ec1396315ccf4ab26af58214`.
**Profile/checker commits:** `c042fd3b5914fe616da5a12dd08a4f4a8b326cd4` and
`70c8aad94e9e8d16bf67d0e4667effb58977ccf7`.
**Simulator:** Synopsys VCS `V-2023.12-SP1_Full64`.

## Implemented scope

The additive ABI-v7 opcode `0x52` is connected through the descriptor decoder,
validator, parallel dispatcher, Matrix controller, and software header. It
reuses the existing 16×16 / 256-MAC Matrix array and accumulator bank. The
controller accepts one bounded descriptor class:

- Dense row-major signed INT8 A `[4, K]` and B `[K, 16]`.
- `K >= 16` and divisible by 16; source addresses are 16-byte aligned.
- No transpose, nonzero strides, multi-batch, nonzero head count, or nonzero
  `aux0`; reserved `flags[7:1]` must be zero and `flags[0]` must match
  `bias_enable`. Unsupported descriptors are rejected before engine dispatch.
- Existing optional column bias, scale shift, activation, INT32 output, and
  ordered line writeback are exercised by the Matrix-core Golden case.

The Matrix controller test checks the complete 64-word output image against an
independent signed INT64 accumulation followed by bias, arithmetic shift, and
ReLU. The real-top test submits an ABI-v7 descriptor with bias enabled, shift
1, and ReLU through CMDQ/dispatcher, checks all 64 result words and the
completion, and checks that `K=20` is rejected as `ERR_DESC_INVALID` without
modifying the destination sentinel.

## Measured Matrix-core profile

The matched workload is `M=4,N=16,K=32`, for 2,048 useful signed INT8 MACs.
The three seed runs produced identical results under the testbench's registered
behavioral-SPAD request/response model:

| Metric | Result |
|---|---:|
| Matrix command cycles | 262 |
| MAC-active cycles | 8 |
| Useful MAC/cycle | 7.817 |
| 16×16 array utilization over command | 3.05% |
| Accepted banked reads | 64 requests |
| Operand read bytes | 1,024 B (16 B/request) |
| Output line writes | 16 × 16 B = 256 B |
| Outstanding read high-water | 4 |
| Extra K-reduction cycles | 0 (combinational reduction) |
| Prefetch completed / fetch-MAC overlap | 0 / 0 |

Unique logical operands occupy 128 B for A and 512 B for B. The measured
1,024 B of banked operand reads therefore includes four fetches of each A
16-byte line across the four K-fold lanes. The core also reads 64 B of bias
and writes 256 B of results, for 1,344 B of operand-plus-output traffic; CMDQ
descriptor fetch is excluded. This redundant A traffic and the lack of
fetch/MAC overlap explain why the new mapping is not yet shown to beat
existing GEMM. A common-workload
GEMM-vs-GEMV cycle comparison and any TinyNPU comparison are **NOT_RUN** for
this slice. Any 250 MHz normalization would be a calculation, not measured
frequency or ASIC throughput. PPA is **NOT_RUN**.

The following profile counters are reported per run. Stall categories are
observational and can overlap; they must not be summed as disjoint cycles.

| State/counter | Value per seed |
|---|---:|
| A request / A response wait | 41 / 32 cycles |
| B request / B response wait | 39 / 34 cycles |
| Bias request / bias response wait | 20 / 50 cycles |
| Prepare / MAC / write / next | 8 / 8 / 28 / 1 cycles |
| Arbitrated request stall / response wait | 32 / 97 cycles |
| Writeback wait | 12 cycles |
| Error / error drain / prefetch wait | 0 / 0 / 0 cycles |

## Verification evidence

| Run ID | Exact command | Run / evidence path | Result |
|---|---|---|---|
| `V2-PRODUCT-GEMV-CORE-S3-20261104` | `make product-gemv-regress CORE_OUT_DIR=/tmp/nmaforge_v2_product_gemv_profile2_20261104 SEEDS='20261104 20261105 20261106'` | Source `70c8aad94e9e8d16bf67d0e4667effb58977ccf7`; logs `/tmp/nmaforge_v2_product_gemv_profile2_20261104/product_gemv_seed_20261104.log` through `...20261106.log` | PASS: 3/3 full-Golden output images, 3/3 request/response drain checks, and identical profile above. |
| `V2-PRODUCT-GEMV-TOP-SMOKE-20261104` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261104 SEED=20261104` | Source RTL `44b9fd792995da4695186746e2887fda0f26bb54`; `/tmp/nmaforge-architecture-v2/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | PASS: `TEST PASS`; descriptor marker confirms bias/shift/ReLU and all outputs; invalid K-tail rejection marker passes; existing top smoke checks pass. |
| `V2-PRODUCT-GEMV-CLEAN-CORE-S3-10aa2ed` | `make product-gemv-regress CORE_OUT_DIR=/tmp/nmaforge_v2_product_gemv_clean_10aa2ed SEEDS='20261104 20261105 20261106'` | Clean detached worktree at `10aa2ed903cb5298317617a1ca7c2c15819774e7`; logs `/tmp/nmaforge_v2_product_gemv_clean_10aa2ed/product_gemv_seed_20261104.log` through `...20261106.log` | PASS: all three seeds reproduce the exact Golden image and 262-cycle profile. |
| `V2-PRODUCT-GEMV-CLEAN-TOP-10aa2ed` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261104 SEED=20261104` | Same clean SHA; `/tmp/nmaforge-v2-gemv-clean-10aa2ed/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | PASS: `TEST PASS`, product descriptor success and `K=20` rejection both present. |

The product-path test checks all 64 values and all 16 output line writes. The
focused test does not prove a full-chip memory scoreboard or broad descriptor
coverage. The Top Smoke compile retains its pre-existing Transformer fixture
loop-reroll notice; it is not introduced by opcode `0x52`.

## Open work

- Product shapes `M=1/8/16`, N tails, and K tails are not implemented. The
  validator rejects them; there is no tail masking yet.
- Add a matched GEMM mapping run using the same logical data and memory timing,
  then optimize A-line reuse and measure whether K folding is beneficial.
- Add fault/phase coverage for parity, protection, Abort, reset, output
  backpressure, and response ownership for opcode `0x52`.
- Add descriptor mutation and coverage disposition; mutation is **NOT_RUN**.
- Add real top multi-engine contention and independent full-SPAD scoreboard.
- Run the eight-configuration benchmark for the new opcode only after its
  shape contract supports a meaningful same-workload comparison.
- TinyNPU common-resource comparison and ASIC PPA remain **NOT_RUN**.

This change does not alter the v1.0 Compute Cluster disposition (**HOLD**) and
does not close the broader v2 architecture target. The first next optimization
is to retain each A line across its four K-fold uses, then overlap the next
legal fetch phase with current compute without weakening response ownership or
Abort/Reset behavior.
