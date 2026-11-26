# NMAForge v2 consolidated front-end microarchitecture

Candidate: `feat/nmaforge-rtl-finalize`, based on `800c5b0`; implementation identity and raw evidence are in `benchmark/representative/round28/manifest.json`. Authoritative detailed ABI remains `docs/spec/SPEC_ZH.md`, additive v2 subset `docs/spec/NPU_ARCHITECTURE_V2_SPEC.md`, and numeric equations `docs/spec/SFU_NUMERIC_CONTRACT_ZH.md`. This document records implemented behavior inspected in RTL, not all targets in those documents.

## Configuration and protocols

One 16×16 INT8 Matrix array provides 256 MACs; product GEMM and 0x52 share it. Four 32-bit SPAD banks use `SPAD_WORDS_PER_BANK=8192` for 128 KiB research and default 32768 for 512 KiB compatibility. H16, trained CNN and matched mini CNN were run at 128 KiB; smoke at default capacity. No default capacity or ABI change was made.

AXI-Lite is 32-bit register control. DMA uses 128-bit AXI4 data, 64-bit addresses and tagged requests. Existing ABI-v7.4 CMDQ descriptors are 64 bytes; CPLQ records are 16 bytes. Fields include task/opcode, src0/src1/bias/dst, M/N, extent, flags, aux0, shifts/activation, strides, batch/head, events and version. Software publishes CMDQ_TAIL and consumes CPLQ_HEAD. Parallel dispatcher owns ordinary multi-engine command slots and ordered retirement; command processor owns compatibility direct/tile/macro paths. Completion writer commits all four words before tail publication.

## Engine contracts

| Engine | Layout and descriptor contract | Request/response and latency |
|---|---|---|
| Matrix 0x30/0x31 | 4×4 tile-major signed INT8 operands, 64-bit accumulation, existing bias/shift/activation/sat32; M/N multiples of four | Ordered bank requests and metadata FIFO, default depth 4; ping-pong operand buffers; variable latency with fabric stalls |
| Product GEMV 0x52 | 1<=M,N<=16, K>=1; A rows padded to round_up(K,16), B physical row 16 bytes, INT32 row-major output; only dense supported subset | Same array in K-fold reduction; masked tails; first 64 K values may use command-local B cache; no second engine |
| Fused GEMM 0x53 | Matrix arithmetic/clamp followed by aux0[4:0] requant shift; packed INT8 tile-A output or aux0[7] bounded row-major output | Existing SPAD write commit; aux0[5:6] optional tagged local tile capture/consume; producer still writes all SPAD outputs |
| SFU 0x32..0x39 | Signed word inputs; Q15 gamma, INT32 beta; explicit fixed-point equations and saturation; requant supports packed output | Scalar valid/ready request, registered response; serial FSM, divider/sqrt; no fixed end-to-end latency under stalls |
| KV 0x43/0x44 | Descriptor head/token/stride addressing and existing ring-cache mapper | Scalar/line movement through fabric; no cache coherence |
| CNN / scalar / CNM | Existing native convolution and bank-local dot paths; trained CNN uses Mapper im2col plus product Matrix fusion | Shared fabric admission and registered responses; host im2col remains outside device compute |

0x52 rejects transpose, nonzero strides, multiple batches, nonzero head/aux/reserved flags, misalignment and output overlap/range wrap as specified by current validator. It does not implement arbitrary N>16 or general strided GEMV. 0x53 row-major output is restricted to supported M/N subsets, alignment and single-instance rules; it does not expose the intermediate INT32 tensor. Legacy 0x30 plus SFU remains available when that tensor is required. Forwarding requires immutable software-owned operands; tag match is not coherence.

## Ownership, timing and recovery

`ai_spad_arbiter` is the sole scheduler admission point. Descriptor/completion control traffic has priority; data clients use existing round robin. Response routing uses client ownership plus Matrix ordered metadata, not inferred current request address. Each engine latches command context; software must express dependencies and prevent overlapping writes to another engine's live operands. Registered SPAD response is an interface requirement; controller throughput depends on ready/response timing and arbitration.

Reset clears active state and invalidates reuse/forward tags. Abort stops new useful work and follows existing engine/fabric drain and error completion behavior; it is not permission to drop already accepted responses. SFU's added accelerate select affects only reciprocal start, never SPAD acceptance, abort, writeback or reset logic. Tests cover selected fault/reset states, not arbitrary asynchronous macro reset interactions.

LayerNorm length<=16 fills an existing 16×32-bit cache during sum input reads, reuses it for variance and affine input, and length=16 uses exact shifts for mean magnitude and variance. The reciprocal remains floor(2^30/root). New logic enables existing divider leading-zero skipping only for LayerNorm reciprocal; no new register or buffer. Pipeline busy and command retirement are distinct intervals; measured length-16 SFU busy is 362→332 cycles while descriptor interval is 373→343.

## Supported application scope

Trained CNN: host upsample/coordinate/im2col, two fused Matrix descriptors, host pooling/argmax. H16: trained synthetic-task GELU16 INT8 model, 2 heads/1 layer, four-token prefill and eight persistent teacher-forced decode steps, KV ring and all intermediate/logit Golden checks. These are bounded model flows, not arbitrary framework graph compilation or natural-language pretrained GPT-2 support.
