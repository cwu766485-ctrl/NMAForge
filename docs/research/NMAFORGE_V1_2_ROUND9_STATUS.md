# NMAForge v1.2 Round 9 Status

## Scope and Baseline

This work is isolated in `/tmp/nmaforge-v1.2-round9`, branch
`research/nmaforge-v1.2-round9`, based on Round 8 SHA
`ab040447b99c112edc57bfb734861f0931351a59`. Product RTL and ABI were not
modified. Scope was limited to G0 replay and G1 H64 cache-backed decode
feasibility; four-layer GPT-2, LM Head, and DeiT were not started.

## G0 Reproduction

Tool: Synopsys VCS `V-2023.12-SP1_Full64`; behavioral 128 KiB/four-bank SPAD;
10 ns clock; seed `20261115`.

| Check | Result | Evidence |
|---|---|---|
| Round 8 DMA Decoder | PASS | 189 descriptors; command cycles 259,667; end-to-end 324,207 cycles including DMA; 49 DMA transfers / 53,248 bytes; 11 checkpoints |
| H64 KV roundtrip | PASS | 253 descriptors; command cycles 264,913; end-to-end 337,133 cycles including DMA; K/V cache write/read roundtrip only |
| Product Top smoke | PASS | `make ai_smoke`; existing VCS `LOOP-REROLL-ENABLED` fixture warning remains |

Reproduction commands:

```sh
cd /tmp/nmaforge-v1.2-round9/dv/subsystem/top_smoke/sim
make ai_h64_decoder_dma_top AI_H64_DMA_RUN=/tmp/nmaforge_round9_g0_dma_final_20261115 AI_H64_DMA_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_DMA_SEED=20261115
make ai_h64_kv_roundtrip_top AI_H64_KV_RUN=/tmp/nmaforge_round9_g0_kv_final_20261115 AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_KV_SEED=20261115 AI_H64_KV_GENERATOR_FLAGS=--kv-roundtrip
make ai_smoke
```

The roundtrip is not evidence of Persistent Decode.

## G1 Cache-Backed Attention Experiment

The experimental generator executes six nonzero token rows
`[1, 7, 42, 3, 5, 8]` through the real Product Top. Q/K/V projections are
computed by RTL; Product `KV_WRITE` writes K and V; Product `KV_READ` readback
buffers are the actual QK and AV Matrix operands. The independent fixed-point
Golden checks 31 intermediate memory checkpoints, including both cache
readbacks, attention scores/probabilities/value, FFN outputs, and Residual 2.
All passed.

This is **cache-backed six-token prefill/attention**, not token-by-token decode.
K is currently written as one complete packed 64-word tile per head to
preserve Matrix-A tile order (4 descriptors total). V uses the Product scatter
append path per token (24 descriptors). K/V readback takes 8 descriptors. A
single Product KV command does not gather one token's four K feature groups
from the Matrix-A interleaved projection layout. A legal microsequence can
write those four words with four one-word `KV_WRITE` descriptors per token,
using explicit source and destination word offsets. Replacing the current four
whole-head writes with 96 word writes raises the batch from 229 to 321
descriptors, beyond the 256-entry ring. The next step is a per-token planner
with CMDQ/CPLQ batch draining and
republication, then checking those writes and completion ownership against the
Product Top. No RTL/ABI change is required by the evidence so far.

| Metric | Result |
|---|---:|
| CMDQ descriptors | 229 / 256 |
| Command cycles | 266,858 |
| End-to-end cycles including DMA preload | 338,050 |
| AXI DMA weight traffic | 45 transfers / 49,152 bytes |
| Product KV traffic | 2,560 bytes write + 2,048 bytes read |
| Useful / executed / padding MAC | 297,600 / 819,200 / 521,600 |
| SPAD read / write traffic | 346,496 / 222,208 bytes |
| Peak simultaneously live allocation | 68,608 bytes |
| Highest allocated address | 130,640 bytes (below 128 KiB capacity) |
| Result | Product Top and all Golden checkpoints PASS for this cache-backed workload |
| Per-token decode cycles | NOT_MEASURED; this run submits a prefill batch, not sequential token decode |

Run command:

```sh
cd /tmp/nmaforge-v1.2-round9/dv/subsystem/top_smoke/sim
make ai_h64_kv_attention_top AI_H64_KV_RUN=/tmp/nmaforge_round9_g1_kv_attention_final4_20261115 AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_KV_SEED=20261115
```

The run log contains `REPRESENTATIVE_MODEL_PASS desc=229` and 31
`REPRESENTATIVE_CHECKPOINT_PASS` records. Its DMA payload is checked against
the generated manifest rather than a hard-coded Round 8 transaction count.

## G1 Exit Decision

G0 is closed. G1 is **PARTIAL / NOT CLOSED**: Product KV readback participates
in real attention and matches independent Golden, but the required
token-by-token causal planner, Cache Decode versus Full Recompute comparison,
per-token cycle accounting, token 4/5 online append, cache-boundary stress,
backpressure stress, and completion-order stress are not yet implemented as a
sequential decode test. The six-token batch result must not be called
Persistent Decode PASS.

Next step: develop a planner that emits K cache writes in Matrix-A-compatible
tile order with a legal per-token command sequence, or prove that existing
Product opcodes cannot express this without an unacceptable descriptor/queue
cost. Keep the host out of K/V payload generation. Then execute token 0..5
sequentially without reset; each token's QK must consume the preceding
Product KV_READ result, and compare Cache Decode against an independent
Full-Recompute INT8 Golden. Add cache pollution/bounds, backpressure, and
completion-order checks before claiming G1 PASS.

## Artifact Digests

| Artifact | SHA-256 |
|---|---|
| G0 DMA run log | `01ef6d5c0db676c0b4fc1167ac779aa5235b81c467c8aa053c019a1470713e5b` |
| G0 DMA compile log | `2bfd9225b255f1f10b6e3e7623f8d5e8c2349814be9faa0b53a9a10261440f06` |
| G0 KV run log | `a6cead45f44ab87d7d89163efcbb01878ab0a2769247c485711a8911e7d18d44` |
| G0 KV compile log | `a3f266b3fb2f526dad96ea09567e668ae129f83607eb925aa846160e78ab8d59` |
| G0 Top smoke log | `1e9df44867d91daff69fa1ffffb46055459623e757ed289caa84f18ee32b11e7` |
| G1 run log | `2aabb0236f85077ddee40f6e8d46f5ac600db846811dee513a3b9f69acaf0505` |
| G1 compile log | `4e4206835d7e604e8a450612dc35608a4b1258085315e69f313992129e2fb111` |
| G1 manifest | `9bb42476d2c81e35904212350643cf42a385a188b4a8315e92e2568870aeef91` |
| G1 independent Golden | `b113ed442213db558029630c4ae8977b978b5f6b49f9421447c7f156302282c9` |

The Round 9 research commit is the branch tip reported with this handoff.
