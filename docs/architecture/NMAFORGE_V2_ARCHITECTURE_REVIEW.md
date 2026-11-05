# NMAForge v2 Architecture Review

**Review date:** 2026-11-05  
**R250 baseline:** `main` `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Review starting commit:** `eb158880d11bf7f8baf13ece4a888107877356fd`  
**Current reviewed candidate:** `feature/npu-architecture-v2` `6b7d6462393ab25ce409c0491037ea8458055741`
**Candidate tree:** `d4059a2cf499d4eed2d9b90d059ff0f5f7b58267`

## Executive disposition

The v2 branch is based on the requested R250 `main` SHA. It adds product-path
Shape-Adaptive GEMV (`0x52`) and fused GEMM requant/tile forwarding (`0x53`)
using the existing Matrix controller and 16×16/256-MAC array. The branch does
not add a second MAC array or change the 64-byte ABI-v7 descriptor layout.
The named Matrix performance and tile-forwarding experiments have reproducible
Golden-checked VCS evidence.

This is a **bounded v2 functional/performance candidate**, not a v1.0 Compute
Cluster sign-off, full v2 verification closure, ASIC sign-off, or a TinyNPU
performance win. Keep the overall Compute Cluster disposition at **HOLD**.

## Baseline and source audit

The published `main` ref resolves to the requested R250 SHA. The merge base of
the current candidate and R250 is exactly that SHA. The review starting commit
`eb158880` is an ancestor of the current feature branch. The remote R250 ref
was not modified. The full candidate delta from R250 contains 73 tracked paths:
6 RTL, 12 DV, 3 software, 33 benchmark, 18 documentation, and 1 tool path (21
paths under `rtl/`, `dv/`, and `sw/`). Since source/test candidate `33e8528`,
the product RTL has not changed; later additions are a focused Matrix
testbench profile, SpyGlass project/triage updates, and benchmark/report
artifacts. Each replay below retains its own source identity rather than
attributing old runs to the current documentation HEAD.

The active integration top remains `rtl/top/ai_accel_top.v`. The v2 product
changes are concentrated in:

| Path | Role |
|---|---|
| `rtl/compute/matrix/ai_tensor_matrix_core.v` | Adds `0x52` K-fold GEMV, reuse/prefetch controls, fused `0x53` requantization, and bounded tile capture/consume. |
| `rtl/compute/matrix/ai_tensor_matrix_array.sv` | Maps GEMV output rows and K-fold lanes onto the existing array. |
| `rtl/control/descriptor/ai_accel_opcode_decode.v` | Classifies `0x52` and `0x53` as Matrix operations. |
| `rtl/control/descriptor/ai_descriptor_validator.v` | Validates the added opcode contracts, dimensions, addresses, spans, and alias restrictions. |
| `rtl/control/queue/ai_parallel_compute_dispatcher.v` | Routes both opcodes to the existing Matrix engine slot. |
| `rtl/top/fabric/compute/ai_accel_compute_cluster.v` | Wires the existing Matrix path; no new compute engine is instantiated. |
| `sw/include/cimforge_regs.h`, `sw/tools/cimforge_mapper.py` | Defines opcodes/flags and validates supported descriptor fields. |
| Matrix and top testbenches | Directed Golden, descriptor, output-image, completion, reset/Abort, and feature-ablation checks. |

The code paths preserve the existing AXI4/AXI4-Lite, CMDQ/CPLQ, four-bank
SPAD arbiter, and ABI-v7 descriptor layout. Opcode-level opt-in keeps the
legacy `0x30/0x31` Matrix contract separate. The current tests provide useful
legacy regression points, but they are not a complete proof of every legacy
opcode under every interaction.

## Opcode implementation audit

| Opcode | Implemented behavior | Descriptor constraints in current RTL | Verified subset |
|---|---|---|---|
| `0x52` | Signed INT8 GEMV mapped as K-fold work on the shared 16×16 Matrix array, with partial-sum reduction. Uses the existing 1 KiB reuse array for bounded B-fold caching, A-line reuse, and optional next-K prefetch. | ABI v7; exact `1≤M,N≤16`, `K≥1`; dense padded A rows and dense B rows; contiguous INT32 output; optional bias. Current product gate rejects transpose, nonzero strides, extra aux/flags, unsupported batch/head fields, address-span overflow, and output overlap with A/B/enabled bias. | Real Top CMDQ Golden for M4×16×32, M1×13×17, M8×16×19; Matrix-core 48/48 four-way Cache×Prefetch Golden checks for M8/M16 × K19/K65 over three Seeds. Descriptor range/alias replay is archived separately. |
| `0x53` | Matrix GEMM INT32 post-processing followed by signed INT8 requantization and native Matrix-A-layout output. `aux0[4:0]` is shift; `aux0[5]` opts into capture; `aux0[6]` opts into matching-tag consume. | ABI v7; upper aux bits zero; capture is bounded to M=N=16 and one tile; consume is bounded to M=16, K=4, no A transpose, and one tile. Exact source tag is required. A miss uses the regular SPAD path. Both producer and consumer retain SPAD writeback. | Three-Seed Matrix-core OFF/ON Golden ablation with capture backpressure, final-line commit, exact-tag hit/miss, ping-pong bank flip, reset invalidation, Abort invalidation, and drain. Three-Seed product Top CMDQ differential compares all output words/completions and source-A reads. |

The `0x52` validator computes half-open byte spans for padded A, dense B,
contiguous INT32 output, and enabled bias. It rejects output/input overlap and
wrapped spans; exact adjacent spans remain legal. The `0x53` local forwarding
storage is two banks × 16 lines × 128 bits = 512 B plus control state. These
are architectural RTL declarations, not synthesized area.

Detailed normative contract: [v2 architecture spec](../spec/NPU_ARCHITECTURE_V2_SPEC.md).
The inherited R250 system hierarchy and constraints are summarized in the
[Phase 0 baseline](NPU_ARCHITECTURE_V2_PHASE0_BASELINE.md).

## Reproduced evidence at named source identities

| Evidence | Source/test identity | Result | Boundary |
|---|---|---|---|
| 4×4/8×8/16×16 Matrix size and depth/prefetch/A-cache sweep | `550ef39f22c22c39eb3bfd7f38dbc574b630e163` | 165/165 Golden points pass across three Seeds. | Four-bank behavioral SPAD with one-cycle read latency; not ASIC timing. |
| Product GEMV B-fold cache × next-K prefetch | RTL/test `b9d593e5f55869ff4a47748013a4b15dcd60f83f` | 48/48 full output images pass; four shapes × four feature settings × three Seeds. | Seeded behavioral SPAD ready/response model; stall counters may overlap and are not summed. |
| Current-SHA product GEMV shape regression | `33e85287fbf37187fccb76e97be6effe888670e9` | 15/15 Golden shape/Seed points pass: M4, M1/N-tail/K-tail, M8, M16 K19/K65 over three Seeds. | Directed Matrix-core run; profiles are in `benchmark/v2_p2_product_gemv_3seed.csv`. |
| Current-SHA Matrix core functional/fault regression | `33e85287fbf37187fccb76e97be6effe888670e9` | Three Seeds each pass 18 functional cases, 35 fault cases, and the line contract checks. | Shared Matrix core lifecycle evidence; not a full feature-specific 0x52/0x53 fault matrix. |
| Tile-forward core OFF/ON | `33e85287fbf37187fccb76e97be6effe888670e9` | 6/6 feature/Seed runs bit-exact. Mean consumer cycles 141→118; selected source-A reads 32→16 (512→256 B). | Matrix-core directed responder; no ASIC or whole-system inference. |
| Top CMDQ `0x52` + `0x53` smoke | `33e85287fbf37187fccb76e97be6effe888670e9`, clean detached worktree | 3/3 Seeds `TEST PASS`; each checks `0x52` N/K tails and `0x53` image/completion differential. | Top behavioral SPAD; VCS `LOOP-REROLL-ENABLED` notice remains. |
| Descriptor boundary/alias suite | `33e85287fbf37187fccb76e97be6effe888670e9` | 29 opcode legal cases; 33 invalid rules; accepted boundaries 43/43; rejected boundaries 26/26; tile-forward descriptors 3/3. | Current-SHA validator replay. |
| Trained Digits MLP, R250 vs v2 | R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`; v2 `33e85287fbf37187fccb76e97be6effe888670e9` | Same model, seed and Golden; 352/360 correct and byte-identical RTL logits. CMDQ interval 110,155→34,761 cycles (−68.44%). | Real top RTL with testbench-preloaded behavioral SPAD; timing and byte counters are scoped in the model report. |
| Paired TinyNPU GEMM/CNN | NMAForge `c3a59f08d8c07a8da973010d0f23d5d6d7eed61b`; TinyNPU `8216c22b762011aa20c05fc2768423fd12dda59d` | Three paired GEMM shapes pass Golden; Tiny engine regression 6/6; same ONNX mini CNN passes Golden on both. GEMM NMA/Tiny-modeled ratios are 1.1391/1.1385/1.0659. | VCS + Verilator RTL simulation; Tiny memory endpoint is modeled, CNN timing windows differ; no general speedup claim. |
| Paired small-M GEMV | NMAForge `0b1d33704f4895cf48b0f5e1d3f452d61b3df535`; TinyNPU `8216c22b762011aa20c05fc2768423fd12dda59d` | `1×13×17` and `8×16×19` pass Golden. NMA measured cycles 76/158; Tiny direct array 100/100 and serialized modeled endpoint 126/170. | TinyNPU uses padded direct-array mapping and has no tested product GEMV/SPAD path; ratios 0.6032/0.9294 are mixed-boundary only. |
| Static analysis and Matrix FSM guards | RTL/test `145363ddff5141177421ee7429fc65f78834830d` | SpyGlass lint 0 errors/465 warnings; CDC 0 unsynchronized crossings/2 warnings; targeted Matrix formal 5/5 non-vacuous assertions and 2/2 covers. RDC timed out; PPA not run. | Scope and exact commands are in the [ASIC readiness report](../verification/NMAFORGE_V2_ASIC_READINESS.md). |

Exact Top/core commands and raw evidence locations are in the [multi-Seed
replay record](../verification/V2_P2_TILE_FORWARD_MULTISEED_REPLAY_2026-11-05.md).
Current-SHA GEMV, descriptor, and Matrix core fault run identities are in the
[v2 DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).
The Matrix size sweep and GEMV ablation details are in the [P1 benchmark
report](../benchmark/NMAFORGE_V2_P1_MATRIX_BENCHMARK.md) and [GEMV
ablation](../benchmark/NMAFORGE_V2_GEMV_CACHE_PREFETCH_ABLATION.md).

## Review findings and open work

- No RTL evidence justifies a second array. The measured B-fold cache is the
  dominant tested GEMV improvement; next-K prefetch provides smaller,
  workload-dependent gains. A new bank-aware issue scheduler has not been
  justified by a controlled bank-conflict experiment and remains unimplemented.
- `0x52` still needs broader M/N/K tails, address alias/range/fault/reset and
  backpressure coverage tied to the current candidate; operand immutability
  under concurrent engines must be specified and checked.
- `0x53` still needs held-response, parity/protection, broader Abort/Reset,
  repeated consumers, and cross-engine coherence coverage. Its 512 B local
  storage has no current-candidate DC area/Fmax/power result.
- VCS functional Golden checks are not coverage closure. A merged current-SHA
  requirement RTM, functional/code coverage disposition, non-vacuity audit,
  and mutation report for every new checker are not complete.
- The TinyNPU tools are now available and the named GEMM/CNN and small-M GEMV
  replays have passed at the source identities above. A true TinyNPU memory
  adapter, broader GEMV shapes, trained CNN/Transformer comparisons, and
  phase-aligned system endpoints remain open; mixed modeled results are not a
  product-level win claim.
- DC, formal/LEC, CDC/RDC, SRAM mapping, DFT readiness, power and physical PPA
  are not closed by these VCS runs. ASIC readiness remains `NOT_RUN` or
  `BLOCKED_ENV` by individual tool/input; do not claim Tapeout Ready.
- v1.0 Compute Cluster stays **HOLD**. This branch's scoped v2 tests do not
  resolve the inherited 38-requirement sign-off record.
- The matched trained Digits MLP replay is a scoped model result, not a
  TinyNPU comparison. Separate Host/DMA/Compute/Writeback/Graph phase counters
  are still missing; trained CNN and Transformer deployment remain `NOT_RUN`.

## Current decision

Continue v2 on this isolated feature branch with reproducible benchmark and
verification increments. Preserve R250 `main` untouched. The next useful
closure is a current-SHA v2 RTM/fault matrix and controlled Top-level
memory-contention experiment, followed by independent DC/PPA readiness when
the licensed libraries and constraints are available.
