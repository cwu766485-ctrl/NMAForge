# NMAForge-V1.2 Round 30 — GPT-2 QAT and Product Top Evidence

## Disposition

**QAT numerical contract: PASS on sampled traces. Selected package Product Top functional replay: PASS. Language-model quality: PARTIAL. Context 128 upgrade: NOT JUSTIFIED by the software pilot.**

The INT8 candidate remains below the same-window Bigram baseline. This is not a quality closure.

## Frozen data and training contract

- Corpus SHA-256: `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed`.
- Disjoint split manifest SHA-256: `78c4a0b3c3f67e693725bcc7e30caedca8d6b24cec7a6c685365c1ff04a6cd00`.
- Half-open corpus ranges: Train `[0,780758)`, Validation `[780792,948067)`, Test `[948101,1115394)`; 17 guard bytes at boundaries.
- Context 16; each QAT evaluation uses 128 validation windows and 512 test windows (8,192 test targets per seed). Test starts SHA-256: `c45940574e2c014f319bada52b16e13021fe5f17088486ed29b153734981fbec`.
- QAT used 200 steps, batch 8, AdamW learning rate `1e-5`; fixed source/QAT seed pairs: `20261221/20263021`, `20261222/20263022`, `20261223/20263023`.
- Reproduction: `python benchmark/gpt2_quality/round30_fixed_checkpoint_qat.py --steps 200 --out benchmark/gpt2_quality/results/round30_qat` (Python 3.12.13, NumPy 2.5.4, PyTorch 2.6.0+cpu). Source FP32 checkpoints are the already tracked Round 27 files; their SHA-256 values are recorded in per-candidate manifests.

The new aligned forward preserves the Product integer arithmetic contract through Fake Quant. The sampled trace audit compares 60 activation/logit nodes across 8 held-out windows and reports exact values against the independent integer implementation. This validates the sampled arithmetic path, not full-test activation saturation statistics.

## Held-out model results

All rows below use the same frozen 8,192-target test set. Accuracy is next-byte top-1. Values are means across three fixed source/QAT seed pairs; standard deviation is across the three runs.

| Metric | FP32 | QAT Float | Product-aligned INT8 | Legacy-contract INT8 | Bigram |
|---|---:|---:|---:|---:|---:|
| Accuracy mean | 35.55% | 35.28% | 22.43% | 10.30% | 26.51% |
| Accuracy SD | 0.14 pp | 0.07 pp | 1.38 pp | 2.03 pp | 0.00 pp |
| Cross entropy (nats) mean | 2.1996 | 2.2208 | 3.1595 | 5.1307 | 2.5198 |
| Perplexity mean | 9.02 | 9.22 | 23.66 | 170.45 | 12.43 |

The aligned contract improves mean INT8 accuracy by **12.13 percentage points** over the old contract and substantially reduces CE/PPL, but remains **4.08 points below Bigram**. The selected validation candidate is source seed 20261223 / QAT seed 20263023; its product INT8 test accuracy is 23.62%, CE 3.067, PPL 21.48. Selection used validation only. Its package SHA-256 is `58263935f5da626c53d5ba4c373396eee9f0f556a6f305a5b820c066625c2bcd`; QAT checkpoint SHA-256 is `1fef5f8f47e5ba6017fe6b38c3dd8fe3fa6165bfbd526a72c7867e9b896b7c83`.

The three runs use distinct fixed FP32 source checkpoints as well as distinct QAT seeds; the reported spread therefore captures both sources of variation. The selected INT8 Fake Quant trace and Independent INT outputs were bit-exact in the 8-window/60-node audit (`round30_saturation_audit.json`, `round30_saturation_by_tensor.csv`). Do not generalize that sampled result to a full-test saturation rate.

## Product Top replay

- Tested RTL/Test source commit: `efa37a949976d5ef9347fb42698f1de8adad757c` (no RTL changes in this experiment).
- VCS: `V-2023.12-SP1_Full64`; compile and run exit status 0.
- Exact command is preserved in `benchmark/gpt2_quality/results/round30_product_top/run_manifest.json`.
- Four-layer Product Top generated and read 256 INT32 logits at each of four contexts; each context matched its independent integer Golden bit-exact.
- Prompt `[1,7,42,3]`; generated tokens `[73,78,111,114]`; zero reset events and zero host-written intermediate tensor words.
- Simulation reported 933 descriptors, 1,048,920 post-layer cycles and 4,338,018 autoregressive extension cycles over 4,020 publications.

This mode is **prefix recompute in the same Top instance**, not incremental persistent-KV decode. The run used 512 KiB SPAD (`AI_SPAD_WORDS_PER_BANK=8192`), so it does not qualify the package at the 256 KiB configuration. The cycle count is a Product Top simulation measurement; it is not complete host-to-host application latency.

Full compile/run logs, all four RTL logits dumps, autoregressive result/plan, stage-3 descriptor and Golden payloads, allocation map and four-layer manifest are archived under `benchmark/gpt2_quality/results/round30_product_top/`; large text artifacts are gzip-compressed. `sha256.json` lists hashes.

## Context-128 pilot

A software-only 100-step fine-tune from the fixed H64 checkpoint, with 128-position embeddings initialized by interpolation, produced checkpoint SHA-256 `dc1acaee44017dcbd84c473e8106e2150bfa0b15afb95653c61c27f86af04a95`. It has 222,336 parameters, estimated INT8 weights 225,792 bytes, and theoretical INT8 KV bytes 65,536 at context 128. Product RTL execution, descriptor support, live-SPAD allocation and latency were **not run/estimated**.

On the pilot validation subset, context 128 scored 27.83% vs context 16 at 37.89%; on the once-frozen test subset (2,048 targets), context 128 scored 29.10% vs 37.21% for context 16 and 27.59% Bigram. This is exploratory and much smaller than the QAT evaluation; it does not support RTL context expansion.

## Reproduction evidence

Machine-readable results, checkpoint/package hashes, commands, and raw VCS logs are under `benchmark/gpt2_quality/results/round30_qat/`, `round30_context128/`, and `round30_product_top/`. Failed first-attempt logger output is intentionally excluded; no source/test result is derived from it.
