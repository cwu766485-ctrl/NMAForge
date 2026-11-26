# NMAForge v2.0 Round 5 Performance Profile

All values below are from real Product Top VCS runs or the fixed Round 4
evidence. Padding MACs are excluded from useful MACs.

| workload | descriptors | DMA bytes | command cycles | end-to-end cycles | useful MACs | executed MACs | padding MACs | result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| H64 attention, 4 tokens | 108 | 0 | 91,351 | 91,351 | Round 4 manifest | Round 4 manifest | Round 4 manifest | PASS |
| H64 FFN up/down tile, 4 useful rows | 5 | 3,648 | 4,684 | 5,789 | 5,120 | 20,480 | 15,360 | PASS |

The FFN tile profile decomposes as follows:

| component | cycles |
|---|---:|
| Matrix MAC | 80 |
| Matrix request wait | 18 |
| Matrix response wait | 14 |
| Matrix writeback | 128 |
| Matrix other | 166 |
| SFU (GELU, Requant, Residual 2) | 4,167 |
| no-engine dispatch remainder | 111 |
| DMA preload window | 1,105 |
| end-to-end | 5,789 |

The SFU dominates this tile. The DMA interval is measured separately and is
included only in the end-to-end number. A model-level speedup cannot be
inferred from this tile or from the earlier local `0x3A` microbenchmark.

## Raw evidence

- FFN tile: `/tmp/nmaforge_round5_ffn_tile_rtl_20261115_v2/run.log`
- Round 4 attention: `/tmp/nmaforge_round4_final_attention_20261115/run.log`
- Round 4 SVSE A/B: `/tmp/nmaforge_round4_sfu_fusion_verified_20261115/`

Context-16, four-layer, final LM head, and persistent multi-token decode are
`NOT_RUN` in this round.
