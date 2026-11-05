# NMAForge NPU Architecture v2.0 Specification

**Status:** In-progress implementation contract; fused Matrix opcode `0x53` is Golden-checked, with opt-in bounded tile forwarding passing a paired core ablation and tag-miss/reset/abort checks. Product opcode `0x52` accepts dense `1<=M,N<=16`, `K>=1` descriptors, passes directed core plus Top Smoke Golden checks for N/K tails, and has bounded next-K prefetch/MAC overlap. A command-local GEMV B-fold cache now reuses the existing 1 KiB local reuse array for `M>4`, with three-seed K=19 and K=65 ablations. Bank-aware issue, complete shape/fault closure, architecture-wide performance, and full v2 sign-off remain open.
**Frozen starting point:** NMAForge R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`.
**Version boundary:** Existing ABI v7 descriptors and opcodes retain their behavior. v2 additions are additive and must be rejected by older RTL as unsupported descriptors.
**Related audit:** [NPU v2 Phase 0 baseline](../architecture/NPU_ARCHITECTURE_V2_PHASE0_BASELINE.md).

## 1. Purpose and scope

v2 develops the existing Compute Cluster into a higher-throughput INT8
GEMM/GEMV subsystem and then uses it for real model inference. The 16×16,
256-INT8-MAC Matrix array remains the shared arithmetic resource. v2 does not
add a second GEMV MAC array or change legacy opcode behavior.

The intended product path is:

```text
Host CPU
  ├─ AXI4-Lite register programming
  ├─ ABI-v7 CMDQ / ordered CPLQ
  └─ AXI4 DMA (128-bit data, 64-bit address)
             │
             ▼
  Command Processor / Parallel Dispatcher
             │
  Compute Cluster (existing seven engine classes)
   ├─ Scalar INT8       ├─ Matrix INT8 GEMM/GEMV (shared 256 MAC)
   ├─ CNM               ├─ SFU / fused Matrix epilogue
   ├─ Mixed FP dot      ├─ Conv line buffer
   └─ KV cache
             │
             ▼
  ai_spad_arbiter ── four-bank SPAD (4 × 32K × 32-bit = 512 KiB)
             │
             └────────────────────────────── AXI4 DMA / DDR
```

The Matrix v2 datapath target is:

```text
Descriptor + shape policy
       ↓
Bank-aware fetch + response-owner metadata
       ↓
Two 16×16 INT8 operand tile sets (ping-pong)
       ↓
Shared 16×16 / 256-MAC array
       ↓
64-bit accumulation / K-fold reduction
       ↓
Existing bias → arithmetic shift → activation → INT32 saturation
       └─ optional fused INT8 requant + native tile writeback
       ↓
128-bit aligned SPAD line write, or legal 32-bit fallback
       ↓
Ordered completion
```

The diagram shows the target structure. The fused `0x53` epilogue is active in
the product Matrix command path. Opcode `0x52` activates the shared array's
K-fold mode for bounded dense shapes through M/N=16, including N/K tails, and
can prefetch the next B K-group while current MAC work runs. This is a
functional integration slice with measured controller-level latency hiding,
not the complete descriptor contract or an architecture-wide performance win.
See the current-subset table below and the
[GEMV implementation report](../architecture/SHAPE_ADAPTIVE_GEMM_GEMV_REPORT.md).
Current v1.0 sign-off remains **HOLD** with 24 `PASS-SCOPED` and 14
`PARTIAL`; v2 work does not change those dispositions. The seven-engine
inventory, current ports, and measured resource declarations are maintained
in the Phase 0 baseline report.

## 2. Invariants and compatibility

1. Keep exactly one 16×16 INT8 MAC array: 256 signed 8×8 multipliers. GEMM and
   GEMV are alternative mappings of that array, not separate engines.
2. Keep `ai_spad_arbiter` as the only scheduler-side SPAD admission point.
   Matrix, CNM, SFU, and DMA must not add a bypass path.
3. Preserve AXI4-Lite, AXI4, CMDQ/CPLQ ordering, existing ABI-v7 descriptor
   layout, and all legacy opcodes (`0x10`–`0x51`). Legacy Matrix GEMM must
   remain bit-exact.
4. Existing Matrix opcodes `0x30/0x31` retain four-element K-word and tile
   layout semantics. v2 GEMV uses a new additive opcode `0x52` in an ABI-v7
   64-byte descriptor; it does not reinterpret the K field for old opcodes.
   Its first supported shape subset is narrower than the target contract
   below. Decoder, validator, dispatcher, software header, and tests must
   agree on every supported and rejected field.
5. Opcode `0x53` is reserved for fused GEMM → INT8 Matrix-A-layout writeback.
   It uses the existing GEMM fields for INT32 post-processing, `aux0[4:0]`
   for the subsequent SFU-compatible requant shift, `aux0[5]` to capture the
   completed output tile, and `aux0[6]` to consume a matching prior tile as A.
   `aux0[31:7]` must be zero. The capture/consume bits are v2-only and leave
   legacy opcodes `0x30/0x31` unchanged. Opcode `0x53` writes packed signed
   INT8 values and is therefore not compatible with the legacy INT32 GEMM
   output contract. Older hardware rejects `0x53` as unsupported.
6. Existing opcode behavior is the compatibility default. Fused requant is
   enabled only by the explicit v2 opcode `0x53`; do not silently fuse the
   legacy `0x30/0x31` result path.
7. Unknown opcode/version, illegal dimensions, misalignment, address overflow,
   and protection failure must be rejected or reported according to the
   descriptor and fabric contracts. Tail masking must never read or write
   beyond the declared tensor span.
7. Reset and Abort stop new Matrix requests, drain accepted responses according
   to the fabric epoch contract, suppress stale output commits, and preserve
   the exact already-accepted output prefix.
8. A cycle estimate, 250 MHz normalization, behavioral SRAM result, and
   pre-layout synthesis estimate are distinct evidence classes. None may be
   described as measured ASIC PPA.

## 3. v2 descriptor contract

The v2 GEMV instruction is an additive ABI-v7 opcode `0x52` using the existing
16-word / 64-byte descriptor layout. Descriptor fields keep their existing
word locations; their meanings for this opcode are:

| ABI-v7 word/field | v2 GEMV meaning |
|---|---|
| `task/opcode` | task ID plus `0x52` |
| `src0` | A base, dense row-major signed INT8 `[M,K]` |
| `src1` | B base, dense row-major signed INT8 `[K,N]` |
| `dst` | signed INT32 output `[M,N]`, row-major |
| `bias_base`, `flags[0]` | optional signed INT32 bias per output column |
| `shape` | exact scalar `M` and `N`, not rounded to four-element tiles |
| `extent` | exact scalar K element count, not Matrix K words |
| `flags[1:2]` | transpose A/B; the same logical transpose contract as Matrix |
| `postprocess` | existing scale shift and activation encoding |
| `src*_stride`, `dst_stride` | byte strides; zero means dense default stride |
| `ABI/clear` | ABI version 7; existing dependency/event semantics |

The descriptor supports `1 <= M,N,K <= 65535`, subject to SPAD bounds,
watchdog policy, and legal byte strides. The first integration milestone
requires M=`1/4/8/16`, N=`8/13/16`, then tiled N=`64/128`; N is processed in
macro-tiles of at most 16 columns. K streams in 16-element array steps. The
test and implementation must not require the whole matrix to fit in a packed
operand bus.

### Current product RTL subset for opcode `0x52`

The controller and ABI-v7 descriptor validator accept dense row-major
`1<=M<=16`, `1<=N<=16`, and `1<=K<=65535` shapes. Transpose, nonzero source or
destination stride, multiple batches, nonzero head count, nonzero `aux0`, and
nonzero reserved `flags[7:1]` are rejected; `flags[0]` must equal
`bias_enable`. Source bases must be 16-byte aligned; the destination follows
the existing word-alignment rule. The shared 16×16 array performs four-way K
reduction. The existing optional bias, arithmetic shift, activation, INT32
result, and output path remain in use.

For this product opcode, dense A is `[M,K]` signed INT8 with each row padded
to `round_up(K,16)` bytes. Dense B is `[K,N]` signed INT8 with one 16-byte
physical row per logical K element; N columns above the descriptor N are
masked before MAC. K-fold groups beyond K are zero-masked and never issued as
SPAD requests. N-tail outputs use ordered scalar writes; complete aligned
four-word groups use full-WSTRB 128-bit writes. This layout is specific to
opcode `0x52`; it does not change legacy Matrix GEMM layouts.

For `M>4`, the implementation may reuse the existing 1 KiB local reuse array
as a command-local B-fold cache for the first 64 logical K values. The array is
exclusive to either the existing GEMM A-line cache or the GEMV B-fold cache
for a command; no additional operand data array is added. K groups above the
first 64 values bypass this cache. The cache is disabled if the B physical
span overlaps the INT32 destination span. Software must keep A and B operands
stable for the full command and must use source/destination spans that do not
alias. The current descriptor validator does not enforce these alias rules;
that validation remains open. This reuse does not add a cross-engine
coherence or snapshot mechanism.

The current implementation does not support N greater than 16, transpose,
strides, multi-batch operation, head-aware operation, or fused `0x53` mode
through this opcode. Core Golden evidence includes `M=1,N=13,K=17` and
`M=16,N=16,K=19` plus `K=65`; M8/K19 and M8/K65 checks have been added to the
testbench but are **NOT_RUN** because VCS could not check out its compile
license. Top Smoke exercises `M=1,N=13,K=17` through CMDQ, validation,
dispatch, Matrix, SPAD and completion. A new `M=8,N=16,K=19` real-CMDQ
descriptor case checks the multi-row K-tail path, but is **NOT_RUN** because
the VCS compile license is unreachable. Bounded next-K
prefetch/MAC overlap and B-fold reuse are measured in core-level ablations,
but opcode-specific fault/Abort/Reset closure, full shape coverage, alias
validation, mutation, bank-aware issue, architecture-wide performance, and
sign-off remain open. Decoder acceptance alone is not evidence that
unsupported fields are implemented; they remain explicitly rejected.

Opcode `0x53` is the optional fused-output form of Matrix GEMM. It keeps the
same source, shape, K-word, bias, Matrix shift, activation, and transpose
fields as `0x30`; `aux0[4:0]` supplies the SFU `REQUANT_I8` shift applied after
the signed INT32 Matrix result is formed. The Matrix post-processing and INT32
clamp occur before requant, exactly as in the two-command legacy sequence.
The destination is packed INT8 in the Matrix A tile order
`[row_group][N/4 group][row_lane]`, with each word containing four consecutive
columns. M and N must remain multiples of four, the base must be 16-byte
aligned, and a nonzero destination instance stride must be 16-byte aligned.
The default instance stride is `M*N` bytes. No INT32 intermediate is written.
This opcode is v2-only and is not a replacement for `0x30`.

### 3.1 Bounded fused-tile forwarding subset

The initial local forwarding implementation uses `0x53 aux0[5]` to capture a
producer tile and `0x53 aux0[6]` to request the preceding tile as Matrix A.
`aux0[4:0]` remains the requant shift. The implementation supports only a
16×16 producer, a 16-row consumer with exactly four K words, no transpose-A,
and a single instance. Capture additionally requires a 16×16 output. Other
shapes are rejected when they set the new bits; old `0x30/0x31` descriptors
are unchanged.

The core stores two 16-line × 128-bit banks (512 bytes total). A producer
still commits every output line to SPAD. A bank becomes valid only after all
16 output lines have been accepted with no protection error. The next opted-in
`0x53` consumer reads a tile only when `src0_base` exactly matches the saved
destination base; on a tag miss, the request falls back to the normal SPAD
path. When both bits are set, the command reads its input from the old bank,
then captures its result into the other bank during writeback; the old bank
remains intact until the command finishes. Line back-pressure holds the
existing write transaction and prevents capture from getting ahead of SPAD
acceptance.
Abort/error and reset invalidate the local tag; reset starts a new local
validity epoch.

This is a bounded, explicitly ordered Matrix-to-Matrix handoff, not a coherent
SPAD cache. Software must keep the tagged source tile immutable between the
producer and opted-in consumer. DMA or another engine must not overwrite it in
that interval. No cross-engine forwarding or cache-coherence protocol is
implemented. The consumer still writes its own result to SPAD, so the feature
avoids the prior tile's 256-byte A read; it does not suppress producer or
consumer writeback.

## 4. INT8 arithmetic and layout contract

### 4.1 Product and accumulation

- Each product is signed INT8 × signed INT8, producing a signed 16-bit value.
- The shared Matrix array retains signed 64-bit accumulation per PE. GEMV K
  folds produce signed 64-bit partial sums and reduce them in a deterministic
  row/lane order into the same signed 64-bit result as the unfurled dot.
- Bias is sign-extended and added before shifting.
- `scale_shift` is an arithmetic right shift; no round-to-nearest is inserted.
- Activation follows the shift: identity, ReLU, or ReLU6, using the existing
  Matrix encoding.
- The legacy Matrix result saturates to signed INT32 after activation.
- The fused INT8 output must use the exact existing `SFU REQUANT_I8`
  equations, signed saturation, and packing/layout rules. It must compare
  bit-for-bit with the current Matrix INT32 output followed by SFU requant.

The full formulas remain owned by `ai_tensor_matrix_array.sv`,
`ai_tensor_matrix_datapath.v`, and
`docs/spec/SFU_NUMERIC_CONTRACT_ZH.md`. This document does not replace their
numeric edge-case tests.

### 4.2 Shape policy and K folding

GEMM remains the existing output-stationary mapping. GEMV is allowed to fold
independent K values across physical rows: for M in `{1,4,8,16}`, the maximum
candidate K parallelism is `16/M`. Invalid M/N/K lanes are masked. After each
folded compute step, reduction produces the same output as a scalar INT64
Golden. The scheduler selects GEMV mapping only when legal and when a
measured controller+SPAD cost model predicts lower cycles; it must retain the
GEMM mapping when GEMV setup, reduction, traffic, or conflicts would lose.

The current research selector's assumed 32-byte/cycle supply model is not a
valid product decision signal. The product policy may use shape constants,
but its cost must include actual request count, bank conflicts, response
latency, K-tail handling, reduction, writeback, and selected ping-pong depth.

### 4.3 Fused epilogue and output layout

The v2 fused path computes:

```text
Matrix INT64 accumulate → existing bias/shift/activation → existing INT32
requant semantics → native output layout → SPAD commit
```

It removes the intermediate INT32 tensor and the following SFU scalar
read/pack/write round trip. Existing SFU remains available for standalone
operators. Fused mode may not change the old opcode's output width, memory
image, write prefix, parity/protection response, or Abort/Reset semantics.
The Digits acceptance run must compare every intermediate tensor and final
logit, not accuracy alone.

For opcode `0x53`, “every intermediate tensor” includes the packed hidden INT8
tile produced directly by the Matrix engine. Its full SPAD image must match an
independent Golden generated from the legacy Matrix INT32 + SFU sequence.

## 5. Physical storage and request budget

The following are initial RTL budget ceilings for the v2 design. Synthesis may
map them to registers, BRAM, or SRAM only when the target flow supports that
mapping; the final inferred resources must be recorded.

| Resource | v1 R250 | v2 initial target |
|---|---:|---:|
| INT8 MAC array | 16×16 = 256 MAC | unchanged, shared by GEMM/GEMV |
| 64-bit accumulator state | 16×16×64 bits = 2 KiB | reuse the same array accumulator; reduction may not add a second full accumulator bank |
| Current operand staging | 256 B A/B staging + 1 KiB bounded A cache | retain; up to 1 KiB incremental budget; K-fold per-PE B view uses two 256 B banks and is active for the current `0x52` shape subset |
| Optional fused-tile forwarding | none | two 16×128-bit banks = 512 B plus valid/tag/mask control; together with the 512 B K-fold B view this consumes the 1 KiB incremental data-storage budget |
| Matrix read metadata | up to four 53-bit FIFO entries | at most four accepted reads; each response must carry an explicit destination buffer, operand, K tile, bank group, and reset epoch |
| SPAD capacity | four banks × 32K × 32-bit = 512 KiB | unchanged |
| SPAD word/line ports | 32-bit word; 128-bit line + 16-bit WSTRB | unchanged; no new bypass port |
| DMA external port | 128-bit AXI4 data, 64-bit address | unchanged |

The two GEMV/GEMM tile sets target one 16×16 INT8 tile for A and one for B
per set. The K-fold operand primitive adds two 16×16-byte B banks (512 B total)
to `ai_tensor_matrix_array`; opcode `0x52` uses this view and reuses the
existing 64-bit accumulator bank. K folding must stream successive K tiles
and must not allocate full M×K/K×N tensors in flops. The 1 KiB target is
incremental staging capacity and
includes valid/owner tags only by accounting them separately in synthesis.
If implementation requires more storage, report the exact increase and
demonstrate the throughput need before changing this ceiling.

Outstanding depth is configurable at 2 or 4, with 4 as the v2 candidate
default. Responses are FIFO ordered because the existing SPAD core interface
does not expose a transaction ID. Reset increments or invalidates the local
epoch; a response from an older epoch can never write an active tile buffer.
The R250 Matrix profile only reached outstanding high-water 2, so the new
design must report achieved high-water and not infer it from a parameter. The
current `0x52` controller can reach high-water 4 within an operand fetch
phase. It issues a bounded next-K B prefetch into the inactive buffer while
the current K-fold MAC executes, retains/reuses matching aligned A lines, and
uses the existing 1 KiB local reuse array as a bounded B-fold cache for
multi-row GEMV. Three-seed B-cache ablations reduced M16/N16/K19 cycles from
387.67 to 261.67 and read traffic from 1,728 B to 816 B; for K65, cycles
decreased from 1,036 to 626.67 and reads from 5,440 B to 2,368 B. The detailed
evidence identifies the enabled prefetch setting and B-cache capacity. The
earlier three-seed prefetch-only ablation reduced cycles by 2.63% for
M4/N16/K32, 3.11% for M1/N13/K17, and 4.24% for M16/N16/K19; accepted reads
and bytes were unchanged. This hides response latency and repeated B-fold
traffic but is not yet a bank-aware multi-request scheduler. The earlier K32 A-line-only profile was
214 cycles and 640 B versus 269 cycles and 1,024 B before A-line reuse; it is
a separate historical comparison. GEMV bypasses the generic GEMM A-tile cache
to avoid layout-tag aliasing; a directed same-base GEMM-cache collision test
checks that the cache is populated, GEMV has no cache hit, and all outputs
remain bit-exact. See the [implementation
report](../architecture/SHAPE_ADAPTIVE_GEMM_GEMV_REPORT.md) for source SHAs,
seeds, run logs, and the behavioral-SPAD comparison boundary.

## 6. Performance counters and acceptance boundary

Every performance result must include source SHA, workload/seed, Run ID,
simulator/version, memory timing model and the measured interval. Required
Matrix counters:

- command cycles and useful signed MAC count;
- MAC active cycles and physical-array utilization;
- accepted SPAD read/write bytes and banked request count;
- bank arbitration stall and response wait cycles;
- outstanding-full cycles and observed outstanding high-water;
- prefetch request/drain/wait/overlap cycles;
- A-tile cache hits;
- line/word writeback stall cycles;
- GEMV reduction cycles and selected execution mode.

Behavioral SPAD cycle comparisons are valid within the declared model. A
250 MHz normalized GOPS figure is only a frequency-normalized calculation.
ASIC area/Fmax/power remain `NOT_RUN` until the exact RTL is synthesized with
valid constraints, standard-cell libraries, SRAM views, and licensed tools.

## 7. Implementation and verification gates

The minimum test list for every Matrix v2 RTL candidate is:

1. Legacy 16×16 GEMM and multi-tile GEMM against the independent signed INT32
   Golden and full SPAD memory image.
2. GEMV M=1/4/8/16, K values with and without a 16-element tail, and N values
   with and without a 16-column tail.
3. Negative/positive INT8 extremes, 64-bit accumulation, bias, arithmetic
   shifts, ReLU/ReLU6, saturation, and fused versus unfused result equality.
4. Ready/latency backpressure, same-bank contention, two/four outstanding
   response ownership, and prefetch-to-compute overlap.
5. Abort and asynchronous reset at fetch, compute, reduction, and held
   writeback phases; check no stale write and exact accepted prefix.
6. Full Digits 360-image inference with 97.78% accuracy baseline, exact hidden
   and logits Golden, end-to-end cycles, SPAD traffic, and utilization.
7. `make ai_smoke` after each product RTL change. For source-list or top-level
   routing changes also run the seeded top regression when the EDA environment
   is available.

Only existing and newly declared v2 requirements are covered. Full UVM
coverage closure is a later phase, but no existing checker, assertion,
scoreboard, or failure condition may be removed or weakened. The v2 RTM must
link each requirement to a test, checker, coverage bin, Run ID, seed, source
SHA, and evidence path before v2 sign-off.

## 8. Out-of-scope for the first INT8 integration

- Adding more than 256 INT8 MACs or a separate full-width GEMV array.
- Changing existing ABI-v7 opcodes or the 64-byte legacy descriptor layout.
- Calling the 86-descriptor synthetic-weight Transformer fixture a pretrained
  model deployment.
- Claiming TinyNPU superiority from an array-only or modeled-memory endpoint.
- Claiming ASIC PPA from behavioral SRAM timing or 250 MHz normalization.
- Promoting the current v1.0 sign-off HOLD or treating v1 coverage as v2
  coverage.
