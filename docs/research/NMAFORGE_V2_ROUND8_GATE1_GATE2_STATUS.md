# NMAForge v2.0 Round 8 Gate 1/2 Status

## Result

Gate 1 is **PASS for the DMA-loaded single H64 decoder replay**. The exact
Round 7 parent is `ba4c6697fcb12245b1141df27938e3aa406d4dd1`, on isolated
branch `research/nmaforge-v2-round8`; product baseline
`0492c47d12cd11bcc22be1930da7af77ed870b6e` was not changed. The verified
Gate 1 implementation is committed as
`e78ade66d3c31cb65a95a411a3a8076f494820a2` on the research branch. No product
RTL was modified.

The run uses the existing one-layer, four-token deterministic H64 graph. It is
not a pretrained GPT-2 checkpoint, four-layer execution, persistent decode, or
model-quality result. The full-decoder image remains 189 descriptors in a
256-entry queue and 5,056 final Golden words. Eleven transient checkpoints
(Residual 1, LN2, packed FFN input, first/last Up/GELU/Requant tiles, Down
accumulator, and Residual 2) are checked at the retirement of their producing
descriptor by read-only VCS behavioral SRAM backdoor. The reads do not use the
AXI host port or add cycles.

## DMA and A/B Evidence

Weights are removed from the initial SPAD image and loaded from the behavioral
external AXI memory by 49 real Product-Top DMA transactions. Each DMA status
completion is checked before the next transaction and before CMDQ publication.
At every transfer completion, all 13,312 destination words are compared
against the external memory source. The AXI monitor reports matching
53,248 read bytes, 208 AR bursts, and 3,328 R beats. Tensor allocation records
identify streamed weights as `external_axi4_dma` owned and mark the DMA
completion fence before their first consumer.

Tool: Synopsys VCS `V-2023.12-SP1_Full64`, 10 ns clock, behavioral 128 KiB / 4
bank scratchpad. Both runs used seed `20261115`, identical model files,
descriptors, Golden, and RTL.

| Metric | Host SPAD image | Weight DMA |
|---|---:|---:|
| Host fixture install cycles | 128,663 | 48,791 |
| Weight DMA cycles | 0 | 15,749 |
| Compute descriptor cycles | 259,667 | 259,667 |
| Total measured session cycles | 388,330 | 324,207 |
| Weight bytes moved through DMA | 0 | 53,248 |
| Final Golden | 5,056 / 5,056 pass | 5,056 / 5,056 pass |
| Completion | 189 / 189 ordered | 189 / 189 ordered |
| Intermediate checkpoints | not enabled | 11 / 11 pass |

The session-cycle difference is setup-path cost only; compute cycles are equal.
This is not an operator speedup. Session timing includes host fixture image
installation, DMA weight preload, and command execution. It excludes simulator
compile time and non-modeled host software overhead. DMA integrity checks and
intermediate checkpoint comparisons are non-intrusive behavioral SRAM
backdoor reads.

Other unchanged workload metrics: useful/executed/padding MACs are
215,040/884,736/669,696; SPAD reads/writes are 348,160/221,184 bytes. The
allocator reports tensor high-water 74,752 bytes and peak simultaneous live
storage 70,656 bytes. The highest populated address in the full memory image is
130,000 bytes; that is not a tensor-usage or peak-live metric. The model uses
synthetic seeded weights.

## Gate 2 — H64 KV Product-Engine Roundtrip

The H64 KV integration subtest passes at seed `20261115`. After the complete
one-layer H64 batch, the same Product Top instance issues 32 `KV_WRITE` and 32
`KV_READ` descriptors. Their inputs are the K/V projection words produced by
the preceding Product Top matrix commands; no reset or host arithmetic is
inserted between model execution and KV transactions. Four token rows and all
four 16-feature heads are written to separate K/V cache tensors using a
64-byte token stride and 1,024-byte head stride. All 32 read commands have
nonempty retirement checkpoints (16 words each); the final memory Golden
contains 6,848 words and passes. The VCS profile reports `kv_busy=4538`.

This is a real H64 Product KV-engine write/read integration result, **not** a
persistent decoder. The fixed four-token causal Attention still reads its
batch tensors rather than the returned KV read data. The test has no token-by-
token causal update, KV-vs-recompute comparison, reset/abort recovery on live
H64 decode state, or fifth-token decode. Gate 2 is therefore **PARTIAL**. The
next missing node is a per-token execution planner that fences each K/V
projection, appends that token to cache, reads past K/V through Product Top,
and feeds those values into the next token's Attention before advancing.
Existing persistent decode remains H16 / 2 heads / head_dim 8 and cannot be
cited as H64 evidence.

The extended run uses 253 descriptors in the existing 256-entry queue and
keeps the queue unchanged. There are 43 non-vacuous memory checkpoints: the
existing 11 model checkpoints plus 32 KV readbacks. Command cycles are
264,913 and end-to-end cycles including DMA preload are 337,133. These figures
are test profile data, not a speedup claim.

## Later Gates

Four-layer execution, final LayerNorm/LM head, greedy output tokens, real
checkpoint import, and model-quality comparison are **NOT_RUN**. No failure
transaction is claimed because these stages were not issued. SVSE `0x3A`
remains Research-only. No ASIC, FPGA, synthesis, or PPA claim is made.

## Reproduction

Run from the exact Round 8 worktree:

```sh
make -C dv/subsystem/top_smoke/sim ai_h64_decoder_dma_top \
  AI_H64_DMA_RUN=/tmp/nmaforge_round8_h64_dma_e2e
make -C dv/subsystem/top_smoke/sim ai_h64_decoder_block_top \
  AI_H64_DECODER_RUN=/tmp/nmaforge_round8_h64_host_e2e \
  AI_H64_DECODER_PYTHON=/tmp/nmaforge_round10_venv/bin/python \
  AI_H64_DECODER_SEED=20261115
```

Raw compile/run logs, generated workload, SPAD Golden, DMA plan and payload:

- `/tmp/nmaforge_round8_h64_dma_e2e/compile.log`
- `/tmp/nmaforge_round8_h64_dma_e2e/run.log`
- `/tmp/nmaforge_round8_h64_dma_e2e/workload/manifest.json`
- `/tmp/nmaforge_round8_h64_dma_e2e/workload/model_golden.memh`
- `/tmp/nmaforge_round8_h64_dma_e2e/workload/dma_plan.memh`
- `/tmp/nmaforge_round8_h64_dma_e2e/workload/dma_payload.memh`
- `/tmp/nmaforge_round8_h64_host_e2e/run.log`

DMA run SHA-256 values: run log
`5a1d2b1a72f2d8a4cf4c96c6e220bceb5f19235ffbd0be61f4d46d01b9bcdbfc`, compile
log `9ea4e5c40af6ffaab71182af2d238aa51831280e3ef8eae28c3d7ec66829b3df`,
manifest `c8e2dc6f3635c70d3cc106ac44e5baf97f7ce618f7fb597b09f1199c985c6e1a`,
Golden `e228a3223dcce0e6b7a0c2c5dc4e6ebf57f5266013b4baa99e9237f12b12cc28`,
DMA plan `727a7d84ef8fa58e58be5d6a48e1801c93faaf4040f10265f6f0715a9fb32463`,
and payload `9badf046f18173b6c8895859421d8cc0a8ed5bb19d7ddcf3283caa0e0f6411e0`.

The H64 KV roundtrip replay is:

```sh
make -C dv/subsystem/top_smoke/sim ai_h64_kv_roundtrip_top \
  AI_H64_KV_RUN=/tmp/nmaforge_round8_h64_kv_roundtrip_20261115_v2 \
  AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python \
  AI_H64_KV_SEED=20261115
make -C dv/subsystem/top_smoke/sim ai_h64_decoder_dma_top \
  AI_H64_DMA_RUN=/tmp/nmaforge_round8_h64_dma_recheck_20261115 \
  AI_H64_DMA_PYTHON=/tmp/nmaforge_round10_venv/bin/python \
  AI_H64_DMA_SEED=20261115
make -C dv/subsystem/top_smoke/sim ai_smoke
```

The KV run uses VCS `V-2023.12-SP1_Full64`, a 10 ns clock and behavioral
128 KiB / four-bank SPAD. Its run log SHA-256 is
`2291c9355ce411c5212d9401c21b15c2c2e7f6f90b2526a3b93057f370e41f7f`, compile
log `570331a2be9c1f62e1ba81ac1aa94194898548c79a59ab5f198473b8dd9c8fe3`,
manifest `32593b33df457ec2773838d2c37e25b454b763f386290422dcf4258eab258ae1`,
final Golden `20573a91727f8a2ed649e1b8067c8af01e55b56032441dfb95d61384474b4288`,
and checkpoint file `5b47a727119bbe6e5e6ad997015b1f052a0a913e0419c9b9e748b47b15a4f053`.
The fresh baseline DMA run log SHA-256 is
`78674b50331d53476aa278a9adf15d42be2779ab7b4b4f30bc180840a21ae10a`.
