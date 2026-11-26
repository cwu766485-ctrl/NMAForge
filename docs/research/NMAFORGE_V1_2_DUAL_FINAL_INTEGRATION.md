# NMAForge-V1.2 Dual-Model Final Integration — Round 27 Evidence

**Overall disposition: PARTIAL.** The two isolated research tracks retain their own source histories and Product Top evidence. GPT-2 has a fresh four-layer logits/feedback Product Top pass, but its model quality is not closed. DeiT has fresh Product Top passes for all valid-row Q/K/V projection and one three-head 16-query attention block, but projection-to-attention still crosses a host readback/repack boundary; full 197-query attention and Encoder Layer 0 have not passed. No unified model-deployment branch is justified yet.

## Frozen track baselines

| Track | Branch | Source SHA used for fresh evidence | Product RTL tree | Model identity |
|---|---|---|---|---|
| GPT-2 | `research/nmaforge-v1.2-dual-final-gpt2` | `901dd1d287413a4b8c51bd4f99c403842d6c30db` | `8798decc60fe257ef685a0b1c7e8814816e1d4de` | H64, 4-layer byte-level Tiny-Shakespeare-derived INT8 model; package SHA `fa66d2ecd6709c0a49e5c23d6346de22adfbf2f0809f182e581fa63cbcb9a54b` |
| DeiT-Tiny | `research/nmaforge-v1.2-dual-final-deit` | `19254b4e6a756ca8bf54ced5b287311214e5e99c` | `76975cd7bf554ea127f1c9abcb649664e228587c` | Official non-distilled `facebook/deit-tiny-patch16-224`; checkpoint SHA `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c` |

These source SHAs precede the Round 27 evidence/report commits. Product RTL is unchanged by this round. The tracks remain isolated; no changes were merged into `main` or into a common product branch.

## Gate summary

| Requirement | Status | Evidence |
|---|---|---|
| GPT-2 four-layer Product Top forward and 256 logits | PASS | Fresh VCS, four contexts, every signed INT32 logit matched independent integer Golden |
| GPT-2 four-token feedback on same unreset Top | PASS | RTL logits → host Argmax → next embedding/position input; 4 tokens generated, zero host intermediate tensor writes |
| GPT-2 model quality / corpus-disjoint evaluation | PARTIAL | Fixed Round 26 sample puts Product-contract INT8 at 29.362% mean vs Bigram 27.539%; FP32 and QAT Float are below Bigram; validation split overlaps development corpus |
| DeiT 197 valid-row Q/K/V Product projection | PASS, staged | 468 descriptors, 29,952 packed words checked; LN input came from archived prior Product Top run |
| DeiT 3-head 16-query × 197-key Attention | PASS, staged | 735 descriptors, 25,536 Golden words; QK, non-causal Softmax, pack and AV run in Product Top |
| DeiT single-session QKV → Attention with no host tensor bridge | NOT PASS | Q/K/V read back and host-repacked before a separate Top invocation |
| DeiT all 197 queries / full Encoder Layer 0 | PARTIAL / NOT RUN | Remaining query blocks, head merge, projection, residuals, LN2, FFN/GELU absent |
| DeiT 12 layers and classifier | NOT RUN | Depends on continuous Encoder Layer 0 and bounded queue refill/retirement runtime |
| Shared 12-layer integration and sign-off | NOT RUN | No complete model has reached the required deployment gate; this round is not full DV/sign-off |

## Measured evidence and limits

| Run | Useful MACs | Command cycles | DMA payload | SPAD read/write | Boundary / result |
|---|---:|---:|---:|---:|---|
| GPT-2 prompt + feedback, 4-layer contexts | Not exported by this regression | 5,389,962 summed context cycles | Not exported as a production-only aggregate | Not exported | Prefix recompute; four logits contexts bit-exact; 10 ns testbench clock; full sim-time cycles include TB setup |
| DeiT Q/K/V, 197 valid rows | 21,786,624 | 402,889 | 112,896 B late DMA | 2,905,344 B / 119,808 B | Product projection; LN input was prior-run readback; 94.71% useful array utilization |
| DeiT attention, 3 heads × 16 queries × 197 keys | 1,210,368 | 594,012 | 82,944 B late DMA | 914,304 B / 102,144 B | Product QK→Softmax(197)→AV; QKV fixture was host repacked; 37.88% useful utilization |

DeiT’s measured queue setups are staged fixtures, not the production runtime’s total traffic. Testbench fixture writes and poison initialization are listed separately in the track report/manifests and are not treated as model payload. Its 768-entry queue handles the single 735-descriptor query-block case; it does not prove streaming/refill for 13 blocks or 12 layers.

No cross-model Speedup is calculated. GPT-2 and DeiT are different workloads; the measured DeiT runs are staged, while the GPT-2 run includes prefix recomputation. There is also no same-model TinyNPU run with aligned controller, memory and end-to-end timing boundaries in this round.

## Reproduction and evidence

- GPT-2 run, command and hashes: [`NMAFORGE_V1_2_DUAL_FINAL_GPT2_REPORT.md`](NMAFORGE_V1_2_DUAL_FINAL_GPT2_REPORT.md) and `benchmark/gpt2_quality/results/round27/product_top/`.
- DeiT runs, manifests and hashes: [`NMAFORGE_V1_2_DUAL_FINAL_DEIT_REPORT.md`](NMAFORGE_V1_2_DUAL_FINAL_DEIT_REPORT.md) and `benchmark/deit/round27/evidence/`.
- Machine-readable rows: `benchmark/dual_model/round27/dual_model_evidence.csv` and `dual_model_status.json`.
- GPT-2 VCS: `V-2023.12-SP1_Full64`, target `ai_h64_four_layer_top_argmax`, exit status 0, 10 ns testbench period, seed `20261116`.
- DeiT VCS: `V-2023.12-SP1_Full64`, seed `20261117`, four banks × 16,384 words (256 KiB), queue setting 768 for the focused attention block.

## Disposition and next integration boundary

The runs establish strong block-to-Top evidence for the existing GPT-2 functional loop and DeiT QKV/attention pieces. They do not establish both deployable models. GPT-2 needs a clean corpus-level split, stronger FP32 baseline and model-quality evaluation before declaring a language model candidate. DeiT needs a producer-consumer-compatible Q/K/V layout and one Top instance with bounded descriptor publication/retirement, followed by the remaining 181 queries and full Encoder Layer 0. Do not claim full model deployment or begin the shared final DV gate until those conditions are met.
