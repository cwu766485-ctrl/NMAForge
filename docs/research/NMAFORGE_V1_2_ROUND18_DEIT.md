# NMAForge-V1.2 Round 18 — DeiT-Tiny Integration Status

## Disposition

**Overall: PARTIAL.** Work was performed on the isolated `research/nmaforge-v1.2-round18` branch, based on Round 17 commit `72af7bf389da8e74d66702f43f4a11d3f2bae740`. Product RTL was unchanged. The 256 KiB Product Top smoke passed, and two bounded Top experiments passed: one patch-projection tile from the pinned DeiT-Tiny checkpoint and one full-length 197-element Softmax row. Neither is a complete Patch Embedding or Encoder Layer. G3 twelve-layer execution is therefore `NOT_RUN`.

Round 17's four-layer H64 synthetic GPT-2-like autoregressive regression was rerun and passed to preserve that baseline. It is not evidence of trained language-model quality.

## Gate Results

| Gate | Status | Evidence boundary |
|---|---|---|
| G0 — 256 KiB SPAD Top | **PASS** | Product Top smoke at 4 banks × 16,384 32-bit words; 256 KiB window and 512-entry queues. |
| G1 — Full Patch Embedding | **PARTIAL** | Product Top executed one of 196 image patches and the first 16 of 192 output channels; 256 physical output words checked. |
| G2 — Full 197-token Encoder | **PARTIAL** | Product Top executed opcode `0x32` on one 197-element row and checked 197 words. No QK-produced scores, three-head Attention, or complete Encoder was run. |
| G3 — Twelve layers + classifier | **NOT_RUN** | Correctly gated on full G2. Static scheduling estimates only. |
| Round 17 GPT-2 preservation | **PASS** | Existing four-layer H64 synthetic-weight autoregressive prefix-recompute test generated four tokens on Product Top without reset. |

Machine-readable gate data is in [`round18_gate_summary.csv`](../../benchmark/deit/round18/evidence/round18_gate_summary.csv) and [`round18_results.json`](../../benchmark/deit/round18/evidence/round18_results.json).

## G0 — Capacity and Queue Audit

The tested Top configuration uses 4 banks × 16,384 words/bank × 4 bytes = **262,144 bytes (256 KiB)**. The host-visible SPAD window is `[0x10000, 0x50000)`. The Top parameter accepts power-of-two bank depths from 2 through 32,768 words, and derives the row width and total byte capacity from `SPAD_WORDS_PER_BANK`.

For 512 queue entries, the queue reservation is not 16 KiB:

| Region | Bytes | 256 KiB SPAD offset | Host-visible address |
|---|---:|---:|---:|
| CMDQ, 512 × 64 B | 32,768 (32 KiB) | `0x36000` | `0x46000` |
| CPLQ, 512 × 16 B | 8,192 (8 KiB) | `0x3e000` | `0x4e000` |
| Total | 40,960 (40 KiB) | starts at `0x36000` | ends exclusively at `0x50000` |

This leaves a 216 KiB data arena below the queue regions. The 128 KiB profile reserves the same 40 KiB, leaving 88 KiB for data. The full Top smoke command was:

```sh
cd dv/subsystem/top_smoke/sim
make ai_smoke AI_SPAD_WORDS_PER_BANK=16384
```

Run ID `R18-G0-256K-TOP-SMOKE-20261116`; result marker `TEST PASS`. VCS was `V-2023.12-SP1_Full64`. Compile and run logs remain in the Round 18 worktree under `dv/subsystem/top_smoke/sim/ai_comp.log` and `ai_accel_smoke.log`; their SHA-256 values are listed in the evidence CSV/JSON.

## Static Lifetime Plan (not Top execution)

[`plan_deit_tiny_spad.py`](../../benchmark/deit/round18/plan_deit_tiny_spad.py) reserves the 40 KiB queue area and checks declared address/lifetime intervals. Its epochs are schedule abstractions, not hardware cycles, and its no-overlap result is **not** a formal proof of Product Top accesses.

- G1's bounded-tile plan has a 64,768-byte data high-water mark. It fits the 88 KiB 128 KiB-profile data arena and the 216 KiB 256 KiB-profile arena.
- G2's proposed one-layer plan does not fit the 128 KiB profile. At 256 KiB it has a 188,160-byte data high-water mark, leaving 33,024 bytes before the queue reservation.
- One layer's 197-token K/V allocation is 75,648 bytes. Keeping all 12 layers' K/V in SPAD would require **907,776 bytes**, so a 12-layer persistent-context implementation requires external/streamed KV backing or a different verified lifecycle. It cannot fit the current 256 KiB scratchpad alone.
- G2's plan uses a 16-query × 197-key score block (12,608 bytes) so Softmax can normalize across the whole key row. Independently normalizing key tiles and concatenating the results would be numerically wrong.

See [`deit_tiny_spad_allocation_static.json`](../../benchmark/deit/round18/evidence/deit_tiny_spad_allocation_static.json) for addresses, alignment, interval declarations, high-water marks, and queue geometry.

## G1 — Pinned Checkpoint Patch-Projection Tile

Checkpoint: `facebook/deit-tiny-patch16-224`, revision `b3428f18dcc7b543470d07f14b4a4157815d1880`; checkpoint SHA-256 `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c`. The checkpoint is kept outside Git. The input is a deterministic seeded random 224×224 RGB image passed through the checkpoint's official image processor; it is **not** an ImageNet sample and no classification accuracy is claimed.

The Top workload uses opcode `0x30`, M=16, N=16, K=768 (192 packed K words). Only row 0 represents the first patch and only the first 16 projection channels are useful; the remaining M rows and output channels are padding. The independent int64 scalar GEMM Golden is checked against all 256 physical output words; 16 are useful outputs. Quantized input/weight hashes and the limited FP32 comparison are recorded in [`patch_projection_tile_manifest.json`](../../benchmark/deit/round18/evidence/patch_projection_tile_manifest.json).

| Metric | Result |
|---|---:|
| Descriptors | 1 |
| Useful / executed MACs | 12,288 / 196,608 |
| Top command cycles | 2,442 |
| Testbench preload interval | 38,519 cycles |
| Reported end-to-end interval | 40,961 cycles |
| Testbench-preloaded SPAD bytes | 25,680 |
| DMA preload in this run | No |
| SPAD read / write bytes | 24,576 / 1,024 |
| Independent Golden | 256/256 physical words PASS |

The `end_to_end_cycles` value includes testbench AXI preload time, not a production DMA loading path. This experiment covers 1/196 patches and 1/12 output-channel tiles. Bias addition, requantization, CLS/position addition, and full embedding output are not covered. It is a real Top GEMM result but only a partial Patch Embedding result.

Run ID: `R18-G1-OFFICIAL-DEIT-PATCH-TILE-20261116`.

```sh
cd dv/subsystem/top_smoke/sim
make ai_deit_round18_patch_tile_256k \
  AI_DEIT_R18_RUN=/tmp/nmaforge_deit_round18_patch_20261116
```

VCS compilation completed with zero errors. The compile log contains the VCS `Warning-[LOOP-REROLL-ENABLED]` optimization notice; this is recorded as a tool warning rather than described as a warning-free compile. The Product Top emitted `REPRESENTATIVE_MODEL_PASS`. Compile/run log hashes and generated input/Golden hashes are captured in the manifest and [`round18_results.json`](../../benchmark/deit/round18/evidence/round18_results.json).

## G2 — Full-Key-Length Softmax Probe

The workload exercises one opcode `0x32` with a signed Q8.8 input row of length 197 and Q0.15 output. With seed `20261118`, the independent `softmax_q15` reference matched all 197 Product Top output words.

| Metric | Result |
|---|---:|
| Softmax command cycles | 7,969 |
| Descriptor total cycles | 8,036 |
| End-to-end test interval | 22,783 cycles |
| Pass 0 / Pass 1 / Pass 2 | 591 / 591 / 6,786 cycles |
| Divider busy | 5,407 cycles |
| Testbench-preloaded SPAD bytes / DMA preload | 9,832 bytes / No |
| SPAD read / write bytes | 2,364 / 788 |
| Golden | 197/197 PASS |

The 22,783-cycle test interval includes testbench AXI-Lite initialization, not a production DMA transfer.

This is a single synthetic score row, not a complete Attention workload: scores are not produced by the Product Top QK stage, and there is no three-head orchestration, AV, projection, Residual, or Encoder Layer. It demonstrates only the length-197 Softmax row path. The full run record is [`softmax197_manifest.json`](../../benchmark/deit/round18/evidence/softmax197_manifest.json), run ID `R18-G2-SOFTMAX-197-ROW-20261116`.

```sh
cd dv/subsystem/top_smoke/sim
make ai_deit_round18_softmax197_256k \
  AI_DEIT_R18_SM_RUN=/tmp/nmaforge_deit_round18_softmax197_pass_20261116
```

## G3 — Twelve-Layer Plan

Twelve-layer Product Top execution was not run because the complete single Encoder Layer gate did not pass. The checked-in plan is only a planning artifact. In addition to the 907,776-byte 12-layer KV requirement, a real implementation needs layer-wise weight DMA, verified layer-specific KV addresses, layer-to-layer activation handoff, temporary-buffer lifetime checks, Final LayerNorm, and the 1,000-class classifier. No 12-layer logits or ImageNet result is claimed.

## Preserved Round 17 GPT-2 Regression

Command:

```sh
cd dv/subsystem/top_smoke/sim
make ai_h64_four_layer_top_argmax AI_H64_AUTOREGRESSIVE=1 \
  AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_round18_h64_ar_20261116
```

The Product Top regression passed for four generated tokens, 4,020 descriptor publications, no reset events, and zero host intermediate words. It uses prefix recomputation and synthetic weights; it does not demonstrate trained language-model quality. Run ID `R18-PRESERVE-H64-AR-20261116`; full logs and hashes are cataloged in the evidence JSON/CSV.

## Reproduction Environment and Source Identity

- Isolated branch: `research/nmaforge-v1.2-round18`.
- Round 17 base/Product RTL SHA: `72af7bf389da8e74d66702f43f4a11d3f2bae740`.
- Product RTL files changed: none.
- TinyNPU reference SHA: `8216c22b762011aa20c05fc2768423fd12dda59d` (not run in this Round 18 work).
- VCS: `V-2023.12-SP1_Full64`.
- Python: 3.12; NumPy 2.5.4; PyTorch 2.6.0+cpu; Transformers 4.48.3.
- Checkpoint weights and generated VCS databases/logs remain outside Git or in ignored simulation outputs; no model weights or private EDA data are committed.
- Exact commands, Run IDs, output hashes, and log hashes are in `round18_results.json` and `round18_gate_summary.csv`.

## Remaining Work

1. Tile and execute all 196 patches × 192 projection outputs, then apply bias/requantization, CLS, and positional embedding; compare every output with an independent integer Golden.
2. Use Top-produced Q/K/V and QK scores to validate three-head Attention, whole-row 197-key Softmax, AV, projection, Residual, LayerNorm, and FFN on the real 197-token model.
3. Replace the static lifetime schedule with descriptor/access-backed checks and demonstrate the allocation in Product Top.
4. Only after G2 passes, execute and validate the 12-layer/classifier path. The 12-layer KV backing requirement exceeds 256 KiB SPAD and needs a measured storage design.
5. GPT-2 trained-weight import and full Host-to-Host timing remain separate open work.

**Final disposition: `PARTIAL`.** The evidence is a 256 KiB smoke PASS, a limited Product Top patch-projection tile PASS, a length-197 Softmax-row PASS, and the preserved H64 regression PASS. Full DeiT embedding, a full 197-token Encoder Layer, twelve layers, and classification are not claimed.
