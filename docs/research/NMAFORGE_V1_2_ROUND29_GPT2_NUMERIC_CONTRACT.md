# NMAForge-V1.2 Round 29 — GPT-2 Integer-Forward Audit

## Scope and disposition

- Research branch: `research/nmaforge-v1.2-round29b-gpt2`
- Audited base commit: `745e8c0643e55d1ec5a6a5df46b6cd8da8f49532`
- Worktree diff SHA-256: `1cb37a4744a48f4151ac27f2fddbce049a033ed19b62eb0dafd72e8ab11d4b95`
- Disposition: **PARTIAL**. The QAT hard-forward was aligned with the matching independent Product integer reference and passed an 8,192-target held-out audit. No new training, Product Top replay, or model-quality closure was performed.

This is a bounded numerical-contract correction, not evidence that the language model is useful or that the modified package has passed Product RTL.

## Changes

`benchmark/gpt2_quality/train_round23_product_qat.py` now uses an integer-contract forward value with an STE gradient for quantized linear operations, attention score accumulation, probability conversion, AV, residual additions, FFN down partials, GELU, and logits. The Q15 softmax probability conversion now includes the Product INT8 signed saturation after `>> 8` (`128` saturates to `127`). The existing Power-of-Two scaling and legacy model dimensions remain unchanged.

`benchmark/gpt2_quality/round29_fake_integer_audit.py` compares named stage tensors from one frozen QAT state against the independent integer inference package on the same clean-split test windows. It also replays the missing-saturation negative control.

## Evidence

Command:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/round29_fake_integer_audit.py \
  --evidence benchmark/gpt2_quality/results/round27_extended_train \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --out benchmark/gpt2_quality/results/round29/fake_integer_audit.json
```

Tool versions: Python 3.12.13, PyTorch 2.6.0+cpu, NumPy 2.5.4. Syntax check passed with:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python -m py_compile \
  benchmark/gpt2_quality/train_round23_product_qat.py \
  benchmark/gpt2_quality/round29_fake_integer_audit.py
```

The machine-readable result is `benchmark/gpt2_quality/results/round29/fake_integer_audit.json` (SHA-256 `39246093d018e73d57622f845e10d02d906777724417e485740f3a7fc68586ac`). It reports:

- 512 held-out windows × 16 targets = 8,192 targets.
- Fake Quant and independent integer outputs: 0 stage mismatches and 0 logit mismatches.
- Both paths: accuracy 27.9053%, cross entropy 2.60427 nats, perplexity 13.5213.
- Negative control without the Product probability saturation: 11,289 Q7 codes out of signed INT8 range; first observed case was Q15 `32768`, `>>8 = 128`, Product result `127`.

Frozen input identities from the audit:

| Artifact | SHA-256 |
|---|---|
| Source FP32 checkpoint | `6d71d0a4649f276a74d42834f94f01812c4cf1e6d64bc6562f1ab017361c0021` |
| QAT checkpoint | `8674782e974cdbb1f43743b00762d854d37e3808b3a2426d3180b36bd99d3130` |
| Product INT8 package | `9e330e56226d76aaf5c639975b30ae2612a1a965ec4c942cb9f93db86dc5a803` |
| Corpus | `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed` |
| Split manifest | `78c4a0b3c3f67e693725bcc7e30caedca8d6b24cec7a6c685365c1ff04a6cd00` |
| Seed manifest | `c4c4ed38ec1ae4307dfc91a856c5b8b07e4bed9b25ab102da9a7746a738dc181` |

The Round 28 7.69% comparison was not an apples-to-apples fake-forward comparison: it paired a pre-QAT FP32 checkpoint for the fake path with an updated QAT Product package. Separately, the earlier fake forward omitted the probability saturation. Both defects are now isolated by comparing a single QAT checkpoint/package pair and a negative control. This explains the numerical discrepancy; it does not establish a quality gain over a matched bigram baseline.

## Gate status

| Gate | Status | Evidence / remaining work |
|---|---|---|
| QAT hard forward vs independent INT reference | **PASS** | Exact named-stage and logit match on the fixed 8,192 targets. |
| Root-cause audit of prior fake-quant discrepancy | **PASS, bounded** | Mismatched model states plus omitted Q15-to-INT8 saturation identified. |
| Model quality recovery | **PARTIAL** | 27.9053% is the matched integer evaluation result; this run did not recompute Bigram, FP32, or QAT-Float metrics on the same sample manifest, so no quality improvement is claimed. |
| New-model Product Top forward/logits/autoregressive replay | **NOT_RUN** | No newly qualified package was deployed to Product Top in this round. |
| New training/multi-seed QAT | **NOT_RUN** | The frozen package was audited; training steps and checkpoint selection were not changed. |
