# NMAForge v2.0 Round 7 — Full H64 Decoder Block

## Result

`FULL_H64_DECODER_BLOCK_RTL_PASS` for the deterministic four-token, one-layer
H64 workload on the Product Top. The complete chain ran in one `ai_accel_top`
instance without an intervening reset. All 189 descriptors retired in order,
all completion task IDs/statuses matched, and the final SPAD image matched
5,056 independently generated Golden words.

This is a synthetic seeded H64 model, not a pretrained GPT-2 checkpoint. The
run verifies a single decoder block, not four layers, final LayerNorm/LM head,
or persistent multi-token KV decode. Full-model weight DMA streaming was not
part of this run; initial model tensors and descriptors were installed by the
testbench memory image path. Do not interpret `dma_preload_included=0` as DMA
coverage.

## Fixed Inputs and Numeric Contract

- Research parent: `fcb1b72969771b9b5fca504e5f7b6d389b74ffc2`.
- Product baseline: `0492c47d12cd11bcc22be1930da7af77ed870b6e`.
- Model seed: `20261114`; tokens `[1, 7, 42, 3]`; physical tile rows: 16.
- One `make_model(seed)` package supplies embedding, position, LN1/LN2,
  Q/K/V/O, and FFN Up/Down weights. The package is emitted as
  `canonical_h64_model.npz`; SHA-256
  `730e8034787477095503747f95bb914e9840261759d156b8c23a73d3cb094de7`.
- Golden SHA-256:
  `9f419de49d325e8653060e94e00b891b8230a0fd8ea7b0587004398b82f73b98`.
- Initial memory image SHA-256:
  `bd82254e2125e9f82645a79ebc41681af304cbd469daaeddcee7be1005b5d856`.
- LN gamma is signed INT8 model gamma scaled by 1024 to Q0.15; beta is INT32.
- Matrix accumulation is signed INT32 in descriptor/K-tile order. Requant uses
  arithmetic right shift followed by signed INT8 saturation, with no rounding
  bias. GELU uses the product Q8.8 quadratic reference.
- Historical Attention-only generator behavior remains unchanged and is still
  checked by its existing target.

## Allocation and Execution

The full graph allocator derives producer/consumer descriptor intervals, checks
initialized reads, alignment, bounds, and live overlap, then relocates every
descriptor address. Transient tensors may reuse physical storage only after
their last consumer. Detailed tensor IDs, shapes, formats, lifetimes, owners,
producer/consumer names, ranges and reuse points are emitted in
`workload/manifest.json`.

The 128 KiB address map is:

| Region | Address range | Notes |
|---|---:|---|
| Tensor and fixture storage | `[0x1000, 0x12400)` | 64-byte aligned allocations; allocator tensor high-water 74,752 B; peak live tensor storage 70,656 B |
| CMDQ reservation | `[0x1b000, 0x1f000)` | 256 slots; 189 descriptors published |
| CPLQ reservation | `[0x1f000, 0x20000)` | 256 slots; one ring slot remains available |

The address map is generated, not maintained separately. The first attempt used
a queue size of 189 and stalled after 188 completions because the ring reserves
one slot to distinguish full from empty. The final harness uses size 256 and
publishes only 189 descriptors.

The allocator emits 158 logical tensor records. Descriptor flow includes
Attention, Residual 1, Product Top LayerNorm 2,
Requant/Matrix-A packing, all 16 FFN Up tiles, GELU/Requant, all 16 FFN Down
K tiles with ordered INT32 partial accumulation, and Residual 2. Residual 2's
second operand is the produced Residual 1 tensor. No LN2 or FFN activation
Golden value is injected as an input.

The final memory image is `0x20000` bytes. Tensor live peak is not inferred
from the highest address. Testbench SPAD image installation took 128,663
cycles, excluded from the measured command window.

## Measured Result

Tool: Synopsys VCS `V-2023.12-SP1_Full64`; clock period 10 ns; behavioral
scratchpad, 128 KiB / four banks.

| Metric | Result |
|---|---:|
| Descriptor / completion count | 189 / 189 |
| Final Golden words | 5,056, all bit-exact |
| Command / end-to-end cycles | 259,661 / 259,661 |
| DMA preload included | No |
| Useful / executed / padding MACs | 215,040 / 884,736 / 669,696 |
| Useful / physical output elements | 2,048 / 8,192 |
| Matrix MAC / request wait / response wait | 3,456 / 513 / 399 cycles |
| Matrix writeback / other | 6,912 / 6,378 cycles |
| SFU busy | 239,868 cycles |
| SPAD reads / writes | 348,160 B / 221,184 B |
| Useful MACs per command cycle | 0.8282 |

These are behavioral RTL measurements for the testbench fixture and product
configuration, not ASIC or FPGA timing/power evidence. The large SFU busy share
is dominated by Softmax/LayerNorm/GELU/Residual/Requant work.

## Reproduction

```sh
make -C dv/subsystem/top_smoke/sim ai_h64_decoder_block_top \
  AI_H64_DECODER_RUN=/tmp/nmaforge_round7_final
make -C dv/subsystem/top_smoke/sim ai_h64_attention_top \
  AI_H64_ATTENTION_RUN=/tmp/nmaforge_round7_attention_regress3
make -C dv/subsystem/top_smoke/sim ai_h64_ffn_tile_dma \
  AI_H64_FFN_TILE_RUN=/tmp/nmaforge_round7_ffn_regress
make -C dv/subsystem/top_smoke/sim ai_smoke
```

Full-decoder raw compile/run logs, generated model package, memory image and
manifest are under `/tmp/nmaforge_round7_final`. Attention-only regression
reported 91,351 command cycles and retained its historical 12,288-word Golden.
FFN standalone reported 165,028 command cycles and passed its existing 43,008 B
AXI4 DMA preload regression.

## Remaining Work

- Per-descriptor transient tensor snapshots are not independently read back;
  the full-block run checks the final physical memory image. Golden references
  are generated for graph outputs, while reused intermediate values are
  overwritten before final readback.
- Full-decoder tile-by-tile AXI4 weight streaming and DMA/compute ownership
  handoff remain unverified.
- SVSE `0x3A` fault/backpressure closure, KV-cache persistence, four-layer
  execution, final LN/LM head, and model-quality validation remain open.
- No product RTL was changed. No synthesis, formal, FPGA, or ASIC claim is made.
