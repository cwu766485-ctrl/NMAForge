# NMAForge-V1.2 Dual-Model Final Integration — DeiT Track

**Disposition: PARTIAL.** The fresh Round 27 replay confirms full valid-row Q/K/V projection and one complete three-head attention query block on Product Top. These are two staged Top invocations with host readback/repacking and DMA between them. Continuous embedding-to-encoder execution, all 197 queries, and a complete Encoder Layer 0 have not passed.

## Frozen source and model

| Item | Value |
|---|---|
| Research source SHA used for both fresh runs | `19254b4e6a756ca8bf54ced5b287311214e5e99c` |
| Product RTL tree at source | `76975cd7bf554ea127f1c9abcb649664e228587c` (unchanged in this round) |
| Branch | `research/nmaforge-v1.2-dual-final-deit` |
| DeiT checkpoint | `facebook/deit-tiny-patch16-224`, non-distilled local snapshot |
| Checkpoint weights SHA-256 | `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c` |
| VCS | `V-2023.12-SP1_Full64` |
| Python environment | Python 3.12.13, NumPy 2.5.4, PyTorch 2.6.0+cpu, Transformers 4.48.3 |
| SPAD configuration | 4 banks × 16,384 words/bank = 256 KiB |
| Seed | `20261117` |

The official checkpoint remains in the local model cache and is not copied into this repository. Workload manifests record the checkpoint and generated-artifact hashes.

## Fresh Product Top evidence

### Q/K/V for all 197 valid tokens — PASS

Command from repository root:

```bash
benchmark/deit/round26/replay_qkv197.sh /tmp/nmaforge_dualfinal_deit_qkv_20261118
```

The LN input is the archived Round 24 Product Top output, read back and used as this workload's source. This fresh run computes Q, K, and V in Product RTL for 197 valid rows and 11 zero-padded physical rows. It does not freshly execute patch embedding or LayerNorm in this session.

| Metric | Result |
|---|---:|
| Descriptors / packed Golden words | 468 / 29,952 PASS |
| Useful MACs | 21,786,624 |
| Command cycles | 402,889 |
| Late-DMA session cycles (includes readback interval) | 1,083,365 |
| Late-DMA events / payload | 144 / 112,896 B |
| Late-DMA setup and transfer window | 35,058 cycles |
| SPAD read / write | 2,905,344 B / 119,808 B |
| Useful MAC / command cycle | 54.076 |
| Useful array utilization | 94.71% |
| Q/K/V Product readback SHA-256 | `6709046be52a7bb6ba409b8dbb9724251bd7f7577aadb49e27ba18d88eb876ba` |
| Independent projection Golden SHA-256 | `b0f0d3085fbbfae560d7f506dac07f81b0205413f55bee09f17d1134c3698f85` |

The memory/late-DMA profile also reports 210,240 B of host fixture input and 140,352 B of test-only poison initialization. Those are testbench setup bytes, not production-model payload claims.

### Three-head 16-query × 197-key attention — PASS

Command from repository root:

```bash
DEIT_QKV_EVIDENCE=/tmp/nmaforge_dualfinal_deit_qkv_20261118 \
  benchmark/deit/round26/replay_attention3_qblock.sh \
  /tmp/nmaforge_dualfinal_deit_attn_20261118
```

The generator checks the Q/K/V Product readback against the independent projection Golden, then performs host layout conversion and supplies the attention workload to a second Product Top invocation. Within that invocation, Product RTL executes QK, non-causal opcode `0x32` Softmax over all 197 valid keys, probability packing, and AV for all three heads and queries 0–15. Physical padded key rows are excluded from the Softmax denominator. This remains a staged handoff, not a continuous QKV-to-attention Product Top session.

| Metric | Result |
|---|---:|
| Descriptors / Golden words | 735 / 25,536 PASS |
| Useful MACs (QK + AV) | 1,210,368 |
| Command cycles | 594,012 |
| Late-DMA session cycles (includes readback interval) | 1,291,324 |
| Late-DMA events / payload | 90 / 82,944 B |
| Late-DMA setup and transfer window | 25,074 cycles |
| SPAD read / write | 914,304 B / 102,144 B |
| Useful MAC / command cycle | 2.0376 |
| Useful array utilization | 37.88% |
| Overlapping SFU busy counter | 403,361 cycles (not additive) |
| Attention Golden SHA-256 | `4d75908811bdd47d5db5ead20f1d67d392b08b5f8971039005e28992f60eb3d9` |

The profile also contains 254,656 B of testbench host fixture input and 206,592 B of test-only poison initialization. They are separated from the 82,944 B late-DMA payload above.

## Integration gates

| Gate | Status | Evidence / remaining work |
|---|---|---|
| B0 — 256 KiB SPAD | PASS for staged workload | Both focused runs use four 16,384-word banks. They do not establish a streaming, multi-batch runtime. |
| B0 — one-session QKV→Attention, no host intermediate tensor | **NOT PASS / OPEN** | Q/K/V are read back and host-repacked before a second Top run. The two workloads use incompatible physical layouts. |
| B1 — full 197-row Q/K/V | PASS | All 197 valid rows checked; 11 padded physical rows are zero. |
| B1 — full 197-query attention | PARTIAL | Only Query 0–15 is executed. Remaining 181 queries and final 5-row block are not run. |
| B2 — continuous full Encoder Layer 0 | NOT RUN | Head merge, output projection, Residual1, LN2, FFN/GELU, Residual2 and full `[197,192]` output remain unintegrated. |
| B3 — 12 layers + classification | NOT RUN | Blocked on full, continuous Layer 0 and a refill/retirement runtime. |

### Runtime and layout boundary

The QKV test writes Matrix-A tile output. Attention consumes Q as GEMV-A, K as a transposed key-major operand, and V in Matrix-B packing. Existing DMA transfers bytes but does not perform the required cross-tile byte permutation. The current test therefore reads Q/K/V back, converts layouts on the host, and starts a second Top session. This is the exact continuous-integration blocker; it is not an AV arithmetic failure.

Additionally, a static 768-entry descriptor queue only holds one 735-descriptor query-block workload. Thirteen blocks would need 9,555 descriptors if fully resident. A continuous model runtime needs bounded descriptor publication, completion retirement/refill, producer-consumer fences, and scratch reuse; the present runs do not validate those behaviors.

The minimal next hardware/software investigation is a producer-visible destination layout that can generate the consumer's Q/K/V formats, followed by an external-descriptor or queue-refill runtime. Do not call that feature implemented until a single Top instance passes the complete data dependency without host tensor readback/repacking.

## Reproduction and archived evidence

The fresh source for these runs is the Round 26 branch HEAD shown above; this Round 27 report does not change product RTL. Exact raw VCS logs are archived losslessly as `.log.gz` under `benchmark/deit/round27/evidence/`. Hashes below are of the uncompressed original files.

| Artifact | SHA-256 |
|---|---|
| QKV compile log | `43d69f2db2605bf715d15c3c24dff6a5f36a32fb8a6052296d50c4aaa60a1aa0` |
| QKV run log | `5970ee17a42f14ecfb8b8d283b01387c2f7a9d280bc6b4a94b7f67c1741c291` |
| QKV generated manifest | `4a2d6c47851e392a29f8804f75e45aa5a84e473eef5940e2a999ae7edb076538` |
| QKV Product readback | `6709046be52a7bb6ba409b8dbb9724251bd7f7577aadb49e27ba18d88eb876ba` |
| Attention compile log | `261ef8832850c22e5903619369cb2f22b2225a43e505dd1e338cbee15b51399d` |
| Attention run log | `3e6a5aaa4f11a5311485864329bb8cc9dfe39988526e06d7f7797ac8712a27d6` |
| Attention generated manifest | `8725d5db173db7a5ae0cc91ff14aafe20061d8cc4de1b9c8023f85b8f8d2c6cb` |

The VCS compile log contains the pre-existing `Warning-[LOOP-REROLL-ENABLED]`. No product RTL was modified, and this focused replay is not a lint/sign-off claim.

## Final assessment

The current evidence supports **Product Top PASS for full Q/K/V projection and one 16-query, three-head attention block**, not full DeiT deployment. No 12-layer or classification claim is made. The next integration must first eliminate the host-mediated QKV layout bridge, then stream query blocks through a real queue runtime and complete the rest of Encoder Layer 0.
