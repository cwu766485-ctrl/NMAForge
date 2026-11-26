# NMAForge v2.0 Round 6 H64 Decoder Status

Research worktree: `/tmp/nmaforge-v2-round6`, branch
`research/nmaforge-v2-round6`, based on Round 5 SHA
`7744ad95d0ddd3eb191c5b5431aeebe01d8faefa`. The fixed Product Baseline is
`0492c47d12cd11bcc22be1930da7af77ed870b6e`. No product branch or PR #7/#8
was modified or merged. VCS was `V-2023.12-SP1_Full64`; the workload clock
was 10 ns.

## Gate 0 — Manifest and numeric contract

`benchmark/gpt2_compat/generate_h64_ffn_tile.py` now allocates each runtime
tensor through the existing `Mapper`, derives half-open ranges and descriptor
lifetimes, and checks 16-byte tensor alignment, 64-byte CMDQ alignment,
bounds, live-range overlap and initialized-before-read status. The checker
exposed and corrected a CMDQ/CPLQ overlap after the FFN descriptor count grew:
CMDQ is `[0x1000,0x2400)`, CPLQ is `[0x2400,0x2900)`, and Tensor allocations
start at or above `0x4000`. The run manifest has 87 ranges, a high-water byte
address of 103,424, and PASS for bounds, alignment, live alias and initialized
reads. Planned tensors are no longer included as if executed.

The reference uses signed INT8 operands, exact signed INT32 partial products,
16 ordered K=16 Down partials accumulated by the existing INT32 Residual
opcode, GELU Q8.8, and packed Requant with arithmetic shift then signed INT8
saturation. There is no host-side arithmetic inserted into the DUT datapath.
The residual source in this standalone FFN test is a deterministic fixture
promoted to INT32; it is not the actual Round 4 Attention + LayerNorm 2 result.

## Gates 1 and 2 — Product Top FFN execution

The Product Top run executes all 16 FFN-Up output tiles. Each tile has a real
GEMM, GELU and packed Requant descriptor. The Down projection executes sixteen
K=16 partial GEMMs for `256 -> 64`; the existing SFU Residual opcode accumulates
each later partial into the INT32 accumulator, followed by Residual 2. Each
Down weight tile is loaded into SPAD through the real AXI4 DMA before the CMDQ
doorbell. The current test uses a bulk DMA-completion barrier before compute;
it does not overlap per-tile DMA and compute or reuse a single weight buffer.

| Measurement | Result |
|---|---:|
| Descriptor count | 80 |
| Golden words | 12,288 |
| DMA transactions / bytes | 19 / 43,008 |
| Product Top command cycles | 165,028 |
| End-to-end cycles including DMA preload | 176,987 |
| Useful / executed / padding MACs | 131,072 / 524,288 / 393,216 |
| Useful / physical Matrix output elements (Up + Down; excludes SFU vectors) | 1,280 / 5,120 |
| Matrix profile: MAC / request wait / response wait / writeback / other | 2,048 / 288 / 224 / 5,120 / 3,664 cycles |
| SFU busy cycles | 152,748 |
| SPAD reads / writes | 217,088 / 167,936 bytes |
| SPAD allocation high-water | 103,424 bytes of 131,072 |

Product Top checked the final SPAD image and all 80 ordered completions against
independent Golden data. Log and generated images:
`/tmp/nmaforge_round6_ffn_full_rtl_20261115_v3/`.

Reproduce:

```sh
cd /tmp/nmaforge-v2-round6/dv/subsystem/top_smoke/sim
make ai_h64_ffn_tile_dma \
  AI_H64_FFN_TILE_RUN=/tmp/nmaforge_round6_ffn_full_rtl_20261115_v3
```

## Gate 3 — Full Decoder boundary

`FULL_H64_DECODER_BLOCK_RTL_PASS` is **NOT ACHIEVED**. The first remaining
integration boundary is data handoff from the verified Attention + LayerNorm 2
workload into the FFN in the same Product Top execution. Round 4 Attention ends
with a memory high-water address of 116,416 bytes; this FFN fixture alone has
103,424 bytes of statically allocated ranges. A disjoint composition would
require 219,840 bytes before queue overhead, so fitting the graph requires
proven lifetime reuse and address handoff. The current generators are separate
full-memory-image jobs and do not share that allocator or a single ordered
CMDQ/CPLQ session. No address masking, host-generated Attention result, or
forced alias was used to bypass this boundary.

KV Cache for H64, four-layer execution, Final LayerNorm, LM Head, and persistent
H64 Decode remain `NOT_RUN`. The existing H16 persistent decode replay remains
valid but is not evidence for H64.

## Gate 4 — SFU `0x3A`

The existing same-condition Product Top A/B was replayed:

| Mode | Descriptors | Cycles | SPAD read | SPAD write | Golden |
|---|---:|---:|---:|---:|---|
| Residual + Requant | 2 | 740 | 768 B | 320 B | PASS |
| Research `0x3A` | 1 | 468 | 512 B | 64 B | PASS |

The measured case saves 272 cycles and 512 read bytes / 256 write bytes. This
does not close the requested `0x3A` protocol DV: parity/protection faults,
partial-write abort/reset, request stability, SVA non-vacuity, coverage, and a
legal H16/H64 model-graph fusion point were not newly exercised. Keep `0x3A`
research-only; no product opcode PR is recommended from this round.

Reproduce:

```sh
cd /tmp/nmaforge-v2-round6/dv/subsystem/top_smoke/sim
make ai_sfu_residual_requant_ab \
  AI_SFU_FUSION_RUN=/tmp/nmaforge_round6_sfu_fusion_20261115
```

## Regressions and remaining gates

- `make ai_smoke`: PASS; `TEST PASS`, seed 12345, four random cases.
- H64 Attention Product Top replay: PASS, 108 descriptors, 12,288 Golden
  words, 91,351 command cycles, log under
  `/tmp/nmaforge_round6_attention_replay_20261115/`.
- H16 persistent incremental decode: PASS, one persistent session, four
  decode tokens; average 8,085.25 cycles/token, log under
  `/tmp/nmaforge_round6_h16_replay_20261115/`.
- No new fault matrix, coverage database, or formal run was produced. Broad
  Round 6 Fault/Abort/Reset and `0x3A` coverage remains open.
- Gate 5's requested operator-by-operator H64 profile is partial: aggregate
  Matrix/SFU counters are present above; per-attention/FFN operator wall-cycle
  attribution and per-stage DMA wait are `NOT_MEASURED`.
- Gate 6 broad CNN/GEMM/GEMV/fault/UVM matrix was not rerun; `ai_smoke` and H16
  incremental replay are scoped regressions only.
- No synthesis, FPGA or ASIC feasibility run was performed.

Current decision: **REWORK / CONTINUE** for full H64 Decoder integration. The
existing Product Top supports the tested FFN arithmetic and weight DMA path,
but the unified Attention-to-FFN live-range allocation and session remain the
next required implementation. No architecture or ABI change is proposed.
