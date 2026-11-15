# NMAForge v2.0 Round 5 Status

Base: `974eff43632bb7ec6e82a0b8470064de11dff3d7` (`research/nmaforge-v2-round4`).
Round 5 branch: `research/nmaforge-v2-round5`.

## Completed

- Generated and ran a real H64 FFN up/down 16-channel tile through
  `ai_accel_top`.
- Loaded descriptors, input, residual source, and both weight tiles through
  the AXI4 DMA payload before compute.
- Checked 1,088 independent Golden words and all five completion records.
- Ran research opcode `0x3A` at lengths 4, 8, 16, 32, 64, and 128.
- Kept useful, executed, and padding MAC accounting separate.

## Not completed

The complete 256-wide FFN and full Decoder Block are not claimed. The first
unimplemented node is per-16-channel weight DMA/compute sequencing with an
explicit product dependency/ownership contract. KV cache, four layers, final
LM head, and persistent decode remain `NOT_RUN`. SVSE fault/backpressure/reset
closure remains open.

## Commands

```sh
cd /tmp/nmaforge-v2-round5/dv/subsystem/top_smoke/sim
make ai_h64_ffn_tile_dma \
  AI_H64_FFN_TILE_RUN=/tmp/nmaforge_round5_ffn_tile_rtl_20261115_v2
```

The six SVSE runs use the compiled Product Top at
`/tmp/nmaforge_round5_ffn_tile_rtl_20261115_v2/simv` and the generator
`benchmark/gpt2_compat/generate_sfu_residual_requant_ab.py --fused --length N`.

VCS: `V-2023.12-SP1_Full64`; clock: 10 ns; SPAD: 128 KiB / four banks.
`git diff --check` passes. No product branch or PR was merged.
