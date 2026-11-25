# NMAForge V1.3 Round 35 — Deployment Numeric Contract for Official GPT-2 and DeiT

**Disposition: `NUMERICS_GATE_PASS_WITH_TWO_SFU_CHANGES`.**

This round tests whether the NMAForge integer contract can carry real,
pretrained models. The models are official `gpt2` (124M), `distilgpt2` (82M)
and `facebook/deit-tiny-patch16-224`.

The current contract does not work: GPT-2 PPL rises from 50.6 to 212 and DeiT
top-1 falls from 78.0% to 32.4%. Three software encodings plus two small SFU
changes bring both models to near-FP32 quality:

- GPT-2 small: PPL 56.4 (+11%).
- DeiT-Tiny: top-1 77.2% (−0.8 pt).

This is a software emulation with bit-exact contract functions. It is not yet
an RTL run.

## Method

- **GPT-2 harness.**
  [`benchmark/gpt2_official/ptq_contract_study.py`](../../benchmark/gpt2_official/ptq_contract_study.py)
  writes the forward pass out explicitly. It matches Hugging Face within
  1e-3 logits.
  - Evaluation: WikiText-2 test, non-overlapping 256-token windows.
  - GPT-2 small uses 40 windows (10,240 tokens). distilgpt2 uses 20 windows
    for the diagnostics.
  - Static activation scales are calibrated on 8 disjoint tail windows.
- **DeiT harness.**
  [`benchmark/deit_official/deit_contract_study.py`](../../benchmark/deit_official/deit_contract_study.py)
  matches HF ViT within 9e-6.
  - The pinned checkpoint is `e1a51b0c…`.
  - Evaluation: top-1 over all 1000 classes on 500 Imagenette validation
    images. These are ILSVRC2012 validation images, 50 per class.
  - Calibration uses 20 disjoint images. At 500 images, ±1.9 pt is the
    binomial standard error.
- **Contract functions.** These are vectorized ports of `ai_a3_reference`:
  LAYERNORM_Q15 (integer mean, variance, isqrt and 2^30 reciprocal), exp2 PWL
  Softmax Q15, the Q8.8 PWL GELU, and arithmetic-shift requant.
- **Weights.** INT8 with a power-of-two scale per 16-output-channel group,
  which the existing per-tile GEMM descriptor plus REQUANT shift can express.
- **Activations.** Per-tensor INT8 with power-of-two scales.
- **Residual stream.** A Q.8 INT32 grid.

## Results

GPT-2 small, perplexity (FP32 = 50.56):

| Contract | PPL |
|---|---:|
| W8A8, power-of-two scales, float LN/Softmax/GELU | 80.99 |
| **Current full contract** (floor LN, Q7 probabilities, PWL GELU) | **212.4** |
| LN with rounding offset, Q15 probabilities, GELU LUT8 | 81.02 |
| Same, with Q7 probabilities rounded | 80.50 |
| Same, with unsigned Q8 probabilities rounded | 79.92 |
| **+ SmoothQuant α=0.5 folded into LN gamma/beta** | **56.37** |
| + SmoothQuant, unsigned Q8 probabilities | 56.59 |
| + per-channel float epilogue scales | 60.51 (no gain) |

distilgpt2 isolates each contract piece (FP32 = 71.35):

| Step | PPL |
|---|---:|
| W8A8 power-of-two | 91.25 |
| + integer LN, floor | 1938 |
| + integer LN with rounding offset | **91.33** |
| Softmax probabilities: Q7 floor / Q15 | 124.0 / 90.55 |
| GELU: PWL / LUT8 | 239.3 / 93.46 |
| + SmoothQuant | **78.56** |

The post-gamma INT32 saturation count was 0 in all LN runs, so the integer LN
contract itself is lossless once rounding is fixed.

DeiT-Tiny top-1 (FP32 = 78.0%):

| Contract | Top-1 |
|---|---:|
| W8A8 power-of-two | 77.0% |
| **Current full contract** | **32.4%** |
| LN rounding, Q7 floor, PWL GELU | 21.2% |
| LN rounding, Q15, PWL GELU | 38.2% |
| LN rounding, Q7 floor, LUT8 GELU | 67.2% |
| **LN rounding, Q15, LUT8 GELU** | **77.2%** |
| LN rounding, Q7 rounded, LUT8 GELU | 76.4% |
| LN rounding, unsigned Q8 rounded, LUT8 GELU | 76.6% |
| Per-channel float epilogue scales | 76.4% |

## Root causes and dispositions

| Finding | Evidence | Disposition |
|---|---|---|
| Floor rounding in LN/REQUANT gives a −0.5 LSB bias on every INT8 activation | LN floor 1938 vs rounded 91.3 (distilgpt2) | Round-to-nearest. Software: fold +2^(k−1) into beta/bias and shift by k. Hardware (small): a REQUANT round flag |
| PWL GELU (x(x+2)/4 inside \|x\|<2) is too coarse | GPT-2 239 vs 93; DeiT 38.2% vs 77.2% | **SFU GELU LUT mode** (INT8 code → 256-entry LUT), fused with input requant and Matrix-A packing |
| Q7 probabilities fail only because of truncation | Rounded Q7 ≈ Q15 on both models | **No Matrix change.** Rounding at the probability requant |
| GPT-2 activation outliers make W8A8 cost +60% | SmoothQuant brings 81.0 → 56.4 | Software. Factors fold into the LN gamma/beta encoding (c_attn/c_fc) and the V columns (attention c_proj) |
| Per-channel requant multipliers | No quality gain after SmoothQuant | GEMM epilogue fusion is justified by performance only |

## Hardware changes required (Gate 5 inputs)

1. **SFU LUT activation.** INT32 accumulator → rounded shift → INT8 code →
   programmable 256-entry LUT → INT8, optionally Matrix-A tile-packed. The LUT
   is loaded from SPAD. This replaces two SFU passes (GELU + REQUANT-pack) with
   one, and also supports SiLU and other monotone activations.
2. **REQUANT round-to-nearest flag.**

## Limits

- **Emulation only.** These are emulations; Product Top bit-exactness of the
  new modes must be shown after RTL.
- **Unmodeled numerics.** Weight-only quantization of embeddings and LM head
  (FP in this study), the final LN contract on GPT-2, and INT4 weights are not
  yet modeled.
- **Evaluation scope.** A 10,240-token PPL subset at ctx 256 and a 500-image
  Imagenette subset, not full ImageNet.
- **Gamma encoding.** It assumes per-channel `gamma_q15` up to 2^31; this was
  checked for overflow (0 saturations).
