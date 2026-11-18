# NMAForge-V1.2 Round 26 — GPT-2 Track Report

## Disposition

**Product Top execution: historical PASS retained. Model-quality closure: PARTIAL.** This round re-evaluates the three frozen Round 25 INT8 candidates with the exact Product integer reference contract on one fixed test sample. All three exceed the same-sample Bigram baseline by 1.37–1.75 percentage points, but the source FP32 and QAT Float models are themselves below Bigram. The result does not establish useful language-model quality or close the generalization gap. No RTL was changed and no new Product Top simulation was run in Round 26.

## Frozen inputs and evaluation contract

| Item | Value |
|---|---|
| Research base | `research/nmaforge-v1.2-round24-gpt2`, `1fad61c6c15b6f4ce7fc7e34ecdab5fd5a840562` |
| Round 25 product-qualified model package | `fa66d2ecd6709c0a49e5c23d6346de22adfbf2f0809f182e581fa63cbcb9a54b` (seed `20261125`) |
| Source FP32 checkpoint SHA-256 | `fea7b0f819ad3cfe9d8ab3f5f12cab632ae005aabf444cd75611846acbf6bde3` |
| Corpus SHA-256 | `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed` |
| Test sample | 512 windows, context 16, seed `20261128` |
| Test target/sample SHA-256 | `e4af87d7432803547c727f0546c5d9715cc8a68e412f76fe3066925afd5d9e62` |
| Integer contract | `round21_contract_ablation.CONTRACTS['residual_gelu_aligned']`; Round 25 Product profile |
| Environment | Python 3.12.13, NumPy 2.5.4, PyTorch 2.6.0+cpu |

The 512 targets and input windows are identical for all three INT8 seeds, QAT Float, source FP32, and Bigram. `evaluate_round26_product_contract.py` calls the Product-aligned integer reference; it does not use RTL outputs. The generated audit explicitly records that the final held-out byte partition was not used to train, while the validation windows were sampled inside the training/development partition. This validation overlap weakens the prior model-selection claim.

## Fixed-sample quality results

| Candidate | Next-byte accuracy | CE (nats) | PPL | FP32 top-1 agreement |
|---|---:|---:|---:|---:|
| Source FP32 | 23.242% | 2.6683 | 14.41 | — |
| QAT Float, mean of 3 seeds | 22.721% | 2.7168 | 15.13 | — |
| Product-contract INT8, mean ± population SD | 29.362% ± 0.332 pp | 2.4862 | 12.02 ± 0.23 | 32.487% ± 1.42 pp |
| Bigram, same targets | 27.539% | — | — | — |

The per-seed Product-contract INT8 accuracy is 29.492%, 29.688%, and 28.906% (seeds `20261125`–`20261127`). INT8 exceeds Bigram by 1.82 pp on the mean, but the FP32 model is 4.30 pp below Bigram and QAT Float is 4.82 pp below it. Thus this run provides a quantization/evaluator diagnostic, not evidence that training produced a generally capable language model. The small fixed sample also limits precision of the quality estimate.

The Round 25 report recorded 12.37% mean INT8 accuracy on these same targets. That number is not reproduced by the Product-aligned reference used here. It is superseded for comparisons against the Product Top model because the evaluation path did not match the Product integer contract. This does not alter the archived bit-exact Top result; it corrects the software metric used to describe the candidate.

## Product Top evidence retained from Round 25

The selected seed `20261125` package remains the package used by the historical Product Top regression. Its Round 25 report records four-layer logits (256 signed INT32 values per context) matching the independent integer Golden, then four host Argmax feedback steps on one unreset Product Top instance. It also records 933 descriptors for the four-layer pass, 4,020 total publications, and `mode=prefix_recompute`. Prompt: `[1,7,42,3]`; generated tokens: `[10,10,65,82]`. Host work was logits readback, Argmax and token embedding/position lookup; no hidden intermediate tensor words were host-written.

This is **historical Top PASS evidence**, not a fresh Round 26 replay. It is a functional demonstration with prefix recomputation, not query-only incremental decode, and generated tokens are not a language-quality metric.

## Gate status

| Gate | Status | Evidence |
|---|---|---|
| Fixed-package / same-sample software audit | PASS | Three frozen seeds, same 512 targets, package and checkpoint hashes; CSV/JSON and run log below. |
| Candidate model quality | PARTIAL | INT8 mean is modestly above same-sample Bigram; FP32 and QAT Float remain below it, validation overlaps training partition, and only 512 held-out windows were scored. |
| Four-layer Product Top and four-token feedback | PASS, historical | Round 25 exact-logit and autoregressive evidence retained; no new simulation in this round. |
| Full GPT-2 deployment closure | PARTIAL | No quality-qualified language model claim; no fresh RTL replay of a newly selected package was needed or performed because the Product-qualified package remains unchanged. |

## Reproduction

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/evaluate_round26_product_contract.py \
  --source-fp32 benchmark/gpt2_quality/results/round25/source_checkpoint/round23_product_qat_fp32.pt \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --seed-root benchmark/gpt2_quality/results/round25 \
  --seeds 20261125 20261126 20261127 \
  --sample-seed 20261128 --windows 512 \
  --out-dir benchmark/gpt2_quality/results/round26/contract_eval
```

The evaluation log reports progress through all `3 × 512` windows. Evidence files:

- `benchmark/gpt2_quality/results/round26/contract_eval/round26_gpt2_quality_audit.json`
- `benchmark/gpt2_quality/results/round26/contract_eval/round26_gpt2_quality_by_seed.csv`
- `benchmark/gpt2_quality/results/round26/contract_eval/run.log`

The audit JSON SHA-256 is `97a8eb4762e12a4d03f589ed63c72b8defbb79f6f201180728514a40318ad543`. Round 25 Product Top raw compile/run logs and hashes remain in `benchmark/gpt2_quality/results/round25/product_top/`; see the Round 25 report for exact original make invocation and log hashes.

## Next disposition

Do not call GPT-2 quality closed. The next useful quality experiment is a corpus-disjoint train/validation/test protocol and a stronger FP32 H64 baseline before more RTL or requant changes. Preserve the selected Product Top package and its bit-exact regression while separating model-quality research from hardware correctness.
