# NMAForge v1.2 Round 10 — H64 KV Decode Status

## Scope and Baseline

Research branch: `research/nmaforge-v1.2-round10`, based on Round 9 commit
`45da53aa339a6265870b51dfbf8a782bb2113b1b`. Product RTL, product ABI, and
existing product branches were not changed. Work is in the isolated worktree
`/tmp/nmaforge-v1.2-round10`.

**Gate status: G0 PASS. Persistent Decode acceptance NOT MET.** The successful
Round 10 Product Top workload is a cache-backed six-token batch with K in the
Matrix-A tile layout. The requested `KV_WRITE flags=1` Matrix-B append has a
real Product Top failure at QK. No online token-by-token execution, ring-batch
publication, or persistent decode claim is made.

## Round 9 Evidence Review

The reviewed Round 9 source is exact commit `45da53aa339a6265870b51dfbf8a782bb2113b1b`.
Its VCS run log, manifest, and checkpoint file report 31 Golden checkpoints;
the logged `REPRESENTATIVE_CHECKPOINT_PASS` count is also 31. Descriptor 47's
QK reads the Product `KV_READ` K buffer; the AV Matrix operand reads the
Product `KV_READ` V buffer. Round 9 still used a complete K tile write and did
not establish sequential decode. See
[`NMAFORGE_V1_2_ROUND9_STATUS.md`](NMAFORGE_V1_2_ROUND9_STATUS.md).

Round 9 G1 run log SHA-256: `2aabb0236f85077ddee40f6e8d46f5ac600db846811dee513a3b9f69acaf0505`.

## G0 Reproduction

Tool: Synopsys VCS `V-2023.12-SP1_Full64`; 10 ns clock; behavioral 128 KiB,
four-bank SPAD; seed `20261115`.

| Regression | Result | Measurements |
|---|---|---|
| H64 Decoder with AXI DMA weights | PASS | 189 descriptors; 49 DMA transfers / 53,248 bytes; 23 checkpoints; 259,667 command cycles; 324,207 end-to-end cycles |
| H64 Product KV roundtrip | PASS | 253 descriptors; 55 checkpoints; 264,913 command cycles; 337,133 end-to-end cycles; this remains roundtrip-only evidence |
| Product Top/CNN smoke | PASS | `make ai_smoke`; generic CMDQ/CPLQ wrap and Abort checks pass; existing VCS `LOOP-REROLL-ENABLED` warning remains |

Reproduction:

```sh
cd /tmp/nmaforge-v1.2-round10/dv/subsystem/top_smoke/sim
make ai_h64_decoder_dma_top AI_H64_DMA_RUN=/tmp/nmaforge_round10_g0_dma_final_20261115 AI_H64_DMA_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_DMA_SEED=20261115
make ai_h64_kv_roundtrip_top AI_H64_KV_RUN=/tmp/nmaforge_round10_g0_kv_roundtrip_20261115 AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_KV_SEED=20261115
make ai_smoke
```

The smoke test's generic ring-wrap/Abort scenarios do not prove H64 KV
multi-batch retirement or reset with outstanding KV transactions.

After the Round 10 generator and Makefile edits, the three hardware gates were
rerun on this worktree. All passed with the same counts above: DMA Decoder
189 descriptors, KV Roundtrip 253 descriptors, Matrix-A Tile cache workload
229 descriptors and 31/31 intermediate checkpoints, plus `make ai_smoke`
(`TEST PASS`). The existing VCS `LOOP-REROLL-ENABLED` fixture warning remains.
Reproduction commands:

```sh
cd /tmp/nmaforge-v1.2-round10/dv/subsystem/top_smoke/sim
make ai_h64_decoder_dma_top AI_H64_DMA_RUN=/tmp/nmaforge_round10_g0_dma_final2_20261115 AI_H64_DMA_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_DMA_SEED=20261115
make ai_h64_kv_roundtrip_top AI_H64_KV_RUN=/tmp/nmaforge_round10_g0_kv_roundtrip_final2_20261115 AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_KV_SEED=20261115 AI_H64_KV_GENERATOR_FLAGS=--kv-roundtrip
make ai_h64_kv_roundtrip_top AI_H64_KV_RUN=/tmp/nmaforge_round10_tile_final3_20261115 AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_KV_SEED=20261115 'AI_H64_KV_GENERATOR_FLAGS=--kv-attention --tokens 1,7,42,3,5,8 --kv-k-write-mode matrix-a-tile'
make ai_smoke
```

Retest log SHA-256: DMA `d0d2014ab7853ea36fb2d9f83c8262f57b1c4b2fcce5375cf7d26245bafee1c2`;
KV Roundtrip `1d39c710d5cffaf87392eaf660c4435d372b3bb6cdf42f03aaa8f9cddc5240f0`;
Matrix-A Tile Product Top `ff95b499f48a321d4990a1db59e93b0f26334e8f49701c3dddd34a34ca5a1c52`;
Top Smoke `439b5f0ba6ee0cbef89a7e9c41d584c9b73610740f6294653d2cbd99552a5f8a`.

## K Cache Layout Comparison

The generator now supports three K layouts. All use the same nonzero H64 model,
six tokens `[1,7,42,3,5,8]`, four heads, Product KV engine, and independent
integer reference.

| K mapping | K write descriptors | Whole model descriptors | Product Top |
|---|---:|---:|---|
| `matrix-a-tile` | 4 (one 64-word tile/head) | 229 | PASS; 31/31 Golden checkpoints |
| `token-append` (`0x43`, `flags=1`) | 24 (one append/token/head) | 249 | FAIL at descriptor 47 QK; K/V cache readback checkpoints pass |
| `matrix-a-word` (`0x43`, `flags=0`) | 96 (four word writes/token/head) | 321 | Not run: exceeds 256-slot ring; generator rejects before simulation |

The append path reduces K write descriptors by 4x versus the 96 one-word writes and fits
the single batch. Its readback bytes match the cache-layout Golden, but the
existing Product Matrix core cannot consume that Matrix-B append layout as the
QK B operand while preserving the current result contract. With QK
`transpose_b=0`, the first result is `0x00000187`; independent expected is
`0xfffffdc7`. `transpose_b=1` was also tried and returned `0xfffffa77`. The
working `matrix-a-tile` mapping returns the independent expected value. The
per-word fallback preserves this Matrix-A layout but requires 321 total
descriptors, greater than the 256-entry CMDQ configuration used here.

This is a concrete format/consumer mismatch, not evidence that `0x43` itself
failed its write/read protocol. The Product K/V cache reads pass; the first
failure is Matrix QK descriptor 47, address `0x4100`, before causal softmax.
No Product RTL/ABI change was made. A future minimum-change proposal should
first define a verified Matrix B layout contract between `KV_READ` and Matrix,
then add a focused adapter/transpose test; alternatively implement host
CMDQ/CPLQ batch draining to run the 321-descriptor Matrix-A word fallback.

## Independent Full Recompute Comparison

The new
[`compare_h64_kv_recompute.py`](../../benchmark/gpt2_compat/compare_h64_kv_recompute.py)
compares same-seed, same-token independent integer checkpoints for both cache
layout models. It checks valid causal score cells only (`row < token_count`,
`col <= row`), all active-row probability/AV words, and active rows for
Residual1, LN2, FFN down accumulation, and Residual2. All 16 named tensors
match for both K layouts. The generator also checks all valid projected K/V
rows against the decoded expected cache state. This is model-Golden equivalence;
the Matrix-B append RTL test still fails as described above.

```sh
cd /tmp/nmaforge-v1.2-round10
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/compare_h64_kv_recompute.py --seed 20261115 --tokens 1,7,42,3,5,8 --kv-k-write-mode token-append
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/compare_h64_kv_recompute.py --seed 20261115 --tokens 1,7,42,3,5,8 --kv-k-write-mode matrix-a-tile
```

Both report `H64_CACHE_RECOMPUTE_GOLDEN_PASS`, 16 tensors, and respectively
249 / 229 candidate descriptors versus 197 for the reference graph.

## Measurements and Per-Token Status

Passing `matrix-a-tile` Product Top batch: 229 descriptors; 266,858 command
cycles; 338,050 cycles including weight DMA preload; 45 DMA transfers /
49,152 bytes; 1,408 logical KV write bytes (1,024 K tile + 384 V append);
2,048 KV read bytes; 297,600 useful / 819,200 executed / 521,600 padding MACs;
SPAD traffic 346,496 read / 222,208 write bytes; peak live allocation 68,608
bytes; high-water address 130,640 bytes. These are batch totals, not per-token
decode measurements.

The token-by-token measurements for token IDs 1, 7, 42, 3, 5, and 8 are all
`NOT_MEASURED`: no online decode planner exists in this candidate. The result
CSV is [`round10_h64_kv_decode.csv`](../../benchmark/gpt2_compat/results/round10_h64_kv_decode.csv).

## Queue, Fault and Lifecycle Closure

The per-word mapping produces 321 descriptors. The current representative
runner publishes one fixed descriptor batch and cannot drain/publish another
batch while preserving completion ownership. A streaming CMDQ/CPLQ producer,
ring-wrap continuation, and no-overwrite check have not been implemented.
`make ai_smoke` passes pre-existing generic CMDQ/CPLQ wrap and Abort tests, but
these do not exercise the H64 KV stream. New directed queue-full, KV abort,
reset-with-outstanding-response, and recovery tests are not complete. These
are open gates, not waived tests.

No multi-token Product Top run has interleaved each token's append, historical
read, causal QK/softmax/AV, and subsequent FFN retirement. Therefore the
acceptance **“same Product Top, no reset, continuous Tokens 0–5, cache decode
equals full recompute” is NOT MET**. Do not describe this as GPT-2 autoregressive
inference.

## Artifacts

| Artifact | Path | SHA-256 |
|---|---|---|
| G0 DMA VCS log | `/tmp/nmaforge_round10_g0_dma_final_20261115/run.log` | `d0fefc5c420b51f0e76a9af8139b56f49b68f621c39e78bbe616944be562be8d` |
| G0 DMA compile log | `/tmp/nmaforge_round10_g0_dma_final_20261115/compile.log` | `b47d2b0f366d2d8e24222b3bc2ac2dd9a0dc5e24457e8cfaf3891c6e00a64aac` |
| G0 KV VCS log | `/tmp/nmaforge_round10_g0_kv_roundtrip_20261115/run.log` | `1e287821a6320268af9d2f08afb194c988d16758ed5f7e8c90feaa59ae79ff78` |
| G0 KV compile log | `/tmp/nmaforge_round10_g0_kv_roundtrip_20261115/compile.log` | `fe64189e4e0833ac8a4ed72446d52d81e4f346567e991c31a24a13141eeee505` |
| Tile-layout Product Top PASS | `/tmp/nmaforge_round10_tile_final3_20261115/run.log` | `ff95b499f48a321d4990a1db59e93b0f26334e8f49701c3dddd34a34ca5a1c52` |
| Tile-layout compile | `/tmp/nmaforge_round10_tile_final3_20261115/compile.log` | `406766da46c8fc3831c035eb380cba1b08e4ea003bdf07acca94339f997b46ea` |
| Tile-layout manifest | `/tmp/nmaforge_round10_tile_final3_20261115/workload/manifest.json` | `afbf72085be15ca11c3be8084a558b512e6246c9d9d46767220cae4767e528c2` |
| Tile-layout Golden | `/tmp/nmaforge_round10_tile_final3_20261115/workload/model_golden.memh` | `b113ed442213db558029630c4ae8977b978b5f6b49f9421447c7f156302282c9` |
| Append QK negative run | `/tmp/nmaforge_round10_append_final_20261115/run.log` | `165523d5e3c847145b98728fe90a56ca4829e25ba9f45544d27f0eafdef4f982` |
| Append compile | `/tmp/nmaforge_round10_append_final_20261115/compile.log` | `90c2b43ffd3045847d8f5a9fb04f73216937a1718577278276734823fbae7d80` |
| Product Top smoke log | `dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | `0d1e7a306c09a9cb08310f1df1e5510f80ef06eb313030f52dfe3dca4a496b96` |

## Next Decision

Keep the existing product RTL/ABI unchanged. Before calling Round 10 closed,
either establish an RTL-supported Matrix-B consume convention for append cache
and pass the descriptor-47 independent Golden, or use the Matrix-A word path
with a tested host batch publisher that respects CMDQ/CPLQ ownership and
completion retirement. Then run tokens serially without reset, check each
token's K/V cache state and causal output, exercise wrap/full/backpressure,
Abort/reset recovery, and report actual per-token cycles. Until then, status is
**REWORK / NOT CLOSED**.
