# NMAForge-V1.2 Round 25 — GPT-2 Track Report

## Disposition

**Product Top: PASS. Model quality: PARTIAL.** The selected Round 25 INT8 package completes a four-layer Product Top forward pass and four host-feedback generation steps on one unreset Top instance. Every one of the four 256-element INT32 logit vectors matches the independent integer Golden exactly. The byte-level Tiny Shakespeare quality result is poor: mean INT8 accuracy is below the matched bigram baseline, so this package is a hardware execution candidate, not a language-quality-qualified model.

No product RTL was changed in this track.

## Frozen inputs and provenance

| Item | Value |
|---|---|
| Research branch/base | `research/nmaforge-v1.2-round25-gpt2` / `2f65208efad28783a8af18cf6598861e3b1d96b8` |
| Source FP32 checkpoint | `benchmark/gpt2_quality/results/round25/source_checkpoint/round23_product_qat_fp32.pt` |
| Source checkpoint SHA-256 | `fea7b0f819ad3cfe9d8ab3f5f12cab632ae005aabf444cd75611846acbf6bde3` |
| Corpus | Tiny Shakespeare byte-level corpus, 1,115,394 bytes |
| Corpus SHA-256 | `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed` |
| Product QAT source seed / steps | `20261123` / `1200` |
| QAT candidate seeds / steps | `20261125`, `20261126`, `20261127` / 500 each |
| Independent test sample | 512 windows, seed `20261128`, sample SHA-256 `e4af87d7432803547c727f0546c5d9715cc8a68e412f76fe3066925afd5d9e62` |
| Model/runtime profile | H64, 4 layers, byte vocabulary 256, product-aligned `round21_residual_gelu_aligned` |

The archived FP32 checkpoint was recovered from the local Round 23 experiment archive and its stored hash matches. The Round 23 manifest records the upstream FP32 model SHA as `1d59cf803c328149add9ddb004766e63043b3babdb56ea178bf96d7a51fda8df`. Candidate QAT was run from this checkpoint with the Product integer LayerNorm forward contract (Q3 input, truncating mean, floor variance, integer square root/Q30 reciprocal, Q5 gamma, integer beta and signed INT32 saturation), inherited Product projection/GELU/Softmax/Requant contracts, and STE gradients. Reproducibility was checked by rerunning seed `20261125` with the frozen command and environment: the regenerated checkpoint SHA is `73801ce5682759ecb37f581ba6423c1a06abda9dba4e4538461d9b524817b796`, and the regenerated `.npz` package is byte-identical to the archived candidate (`cmp` exit 0; SHA-256 `fa66d2ecd6709c0a49e5c23d6346de22adfbf2f0809f182e581fa63cbcb9a54b`). The exact command and comparison are archived in `benchmark/gpt2_quality/results/round25/reproducibility/package_replay_check.txt`; the replay manifest is alongside it.

## Multi-seed quality evaluation

Candidate selection used the fixed validation split only. Seed `20261125` had the highest INT8 validation accuracy and was selected for Product Top qualification before the independent test was evaluated. All three seeds used the same independently sampled 512-window test set. Metrics are byte next-token accuracy, cross entropy in nats and perplexity.

| Model | Accuracy | CE | PPL | FP32/INT8 top-1 agreement |
|---|---:|---:|---:|---:|
| Original FP32 | 23.24% | 2.6683 | 14.41 | — |
| QAT-updated Float, mean ± population SD | 22.72% ± 0.18 pp | 2.7168 ± 0.0066 | 15.13 ± 0.10 | — |
| QAT INT8, mean ± population SD | 12.37% ± 0.40 pp | 4.6663 ± 0.0087 | 106.31 ± 0.92 | 8.01% ± 0.48 pp |
| Bigram baseline, same targets | 27.54% | — | — | — |

Per-seed INT8 test accuracy was 12.89%, 11.91%, and 12.30%. QAT-updated Float itself is below the original FP32 result, and quantized inference loses a further 10.35 percentage points versus QAT Float. INT8 trails the same-window Bigram baseline by 15.17 percentage points. The original FP32 result also trails this particular Bigram sample; this indicates a weak/mismatched tiny byte-level model and a noisy small test sample, not a recovered language model. These results do not support a quality-closure claim.

The 512-window set is a bounded diagnostic, not a sufficiently powered language evaluation. The first serialization attempt for this 512-window report failed after scoring because of a metric-key mismatch; the script was corrected and the same frozen packages/sample were rerun successfully. Both attempts are retained under `eval_512.log` and `eval_512/`.

A 2,048-window follow-up over the same three seeds was started with sample seed `20261129`; it was interrupted after more than 20 minutes before emitting any completed result (controlled interrupt, exit 130). It is therefore **NOT_RUN/INCOMPLETE** and is not used in the table above.

## Product Top qualification

Selected package SHA-256: `fa66d2ecd6709c0a49e5c23d6346de22adfbf2f0809f182e581fa63cbcb9a54b` (candidate seed `20261125`). The package's Product model SHA in the generated Top manifest is `4f9bf1070ed14827ef99510d47eccde6f6dc218c2f7b9b677394f41437adf8fd`.

The real VCS Top run used seed `20261125`, prompt `[1, 7, 42, 3]`, 128 KiB SPAD (`8192` words per bank), four layers, and four generated steps. It reported:

- `H64_FOUR_LAYER_TOP_PASS layers=4 descriptors=933 post_layer_cycles=1049172 reset_events=0 host_hidden_words=0`.
- Four actual Product Top SPAD logit reads, each 256 signed INT32 values, were bit-exact against the independent Golden.
- Host Argmax uses signed INT32 comparisons, with the lowest token ID winning ties. Generated IDs were `[10, 10, 65, 82]`.
- `H64_AUTOREGRESSIVE_SEQUENCE_PASS generated_tokens=4 total_publications=4020 extension_cycles=4339422 reset_events=0 host_intermediate_words=0 mode=prefix_recompute`.
- The archived verifier was rerun from the copied evidence and exited 0: `H64_AUTOREGRESSIVE_GOLDEN_PASS`, four contexts, all logits bit-exact.

This is real feedback from RTL logits on one persistent, unreset Product Top instance, but it uses **prefix recomputation** for each next context; it is not query-only incremental decode. Host responsibilities are logit readback, Argmax and token embedding/position lookup. No host intermediate tensor words are written. The generated sequence is functional evidence only and does not imply language quality.

VCS version: `V-2023.12-SP1_Full64`. The archived full Make output, compile log, run log, generated plan, allocation and four logit dumps are under `benchmark/gpt2_quality/results/round25/product_top/`. Compile-log SHA-256: `fdb856bf929e1ac4cf66b7d2004e8e7220895e784fc9d8c71221b1be8487ccb8`; run-log SHA-256: `e83b16d218d77b3c955cfbc308d11f9ad4fda67350472af975e162624abdb201`; Make-output SHA-256: `e1d56ad3f7b44d241032a82e465fefb66d5aec241c2c12f00a0fa6ee90dd1354`.

The historical Make transcript ends after all recipe checks and the independent verifier's PASS. Its shell exit status was not captured by the original execution session. The archived verifier was separately rerun with exit code 0. No claim is made that this rerun recompiled RTL.

## Reproduction commands

Run from the repository root. The isolated VCS environment used VCS `V-2023.12-SP1_Full64` and Python 3.12 with the archived experiment environment.

```bash
python3.12 benchmark/gpt2_quality/train_round24_integer_qat.py \
  --fp32 benchmark/gpt2_quality/results/round25/source_checkpoint/round23_product_qat_fp32.pt \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --out-dir /tmp/round25_qat_seed_20261125 \
  --seed 20261125 --steps 500 --batch 16 --lr 2e-5 --validation-windows 512
```

Repeat with seeds `20261126` and `20261127`. Evaluate the frozen package set:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/evaluate_round25_seeds.py \
  --source-fp32 benchmark/gpt2_quality/results/round25/source_checkpoint/round23_product_qat_fp32.pt \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --seed-root benchmark/gpt2_quality/results/round25 \
  --seeds 20261125 20261126 20261127 \
  --out-dir benchmark/gpt2_quality/results/round25/eval_512 \
  --sample-seed 20261128 --windows 512 --cache-dir /tmp/round25_gpt2_eval_cache
```

The Top recipe is `make ai_h64_four_layer_top_argmax` in `dv/subsystem/top_smoke/sim/Makefile`, with `AI_H64_FOUR_LAYER_SEED=20261125`, `AI_H64_FOUR_LAYER_TOKENS=1,7,42,3`, `AI_H64_FOUR_LAYER_MODEL_NPZ=benchmark/gpt2_quality/results/round25/seed_20261125/round24_integer_qat_model.npz`, `AI_H64_NUMERIC_PROFILE=round21_residual_gelu_aligned`, and `AI_H64_AUTOREGRESSIVE=1`. The archived Make transcript is the exact evidence for the run directory and tool invocation. To independently check the archived logits and Golden without recompiling:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_compat/verify_h64_autoregressive.py \
  --run benchmark/gpt2_quality/results/round25/product_top
```

## Gate status

| Gate | Status | Evidence / limitation |
|---|---|---|
| A0 Reproducibility | PASS | Source checkpoint and corpus are archived with hashes; seed `20261125` replay reproduced the checkpoint hash and package byte-for-byte; three fixed QAT seeds and contracts are recorded. |
| A1 Robust quality | PARTIAL | Three seeds evaluated, but the 512-window independent test is small; INT8 is below Bigram and QAT Float is below source FP32. The planned 2,048-window follow-up was incomplete. |
| A2 Product Top | PASS | Four-layer forward, four RTL-logit feedback steps and independent 256-logit Golden checks all pass; archived verifier exit 0. |
| A3 Model quality closure | FAIL/PARTIAL | No candidate exceeds Bigram on the independent sample; do not call this a language-quality-ready model. |
