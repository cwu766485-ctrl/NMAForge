# NMAForge-V1.2 Round 19 — Track A: GPT-2-derived H64 Deployment

## Result

**Track disposition: `PARTIAL`.** A fixed-source GPT-2 checkpoint was imported into the existing H64/four-layer NMAForge package, and the Product Top completed four logits-to-Argmax feedback outputs with bit-exact independent NMAForge INT8 Golden checks. The path is prefix-recompute in one unreset Top simulation. It is not a quality-qualified language model and is not an arithmetic-matched TinyNPU comparison.

## Frozen sources and model

- Research branch base: `research/nmaforge-v1.2-round19-gpt2`, based on Round 18 `0e54224510a24e316674df7fa50262ccf2b46429`.
- Tested implementation source commit: `ad48fc94727b7b8c1a5267a1b4508d9d6bee50c2`.
- TinyNPU source: `8216c22b762011aa20c05fc2768423fd12dda59d`.
- Source checkpoint: `openai-community/gpt2`, resolved revision `607a30d783dfa663caf39e06633721c8d4cfcd7e`; checkpoint SHA-256 `248dfc3911869ec493c76e65bf2fcf7f615828b0254c12b473182f0f81d3a707`.
- NMAForge package: `/tmp/nmaforge_r19_gpt2_import/canonical_h64_model.npz`; SHA-256 `99cbc583af22c409b9c7d2b8d99c180695b112ccaf01a61113be6da31c7065dd`.
- H64 workload canonical model SHA-256: `107408c88c123a5c61d4568d56ac721cfd36dca105b81b46f717b7d5fe91bc08`.
- Shape: Hidden 64, 4 heads × 16, 4 layers, FFN 256, vocabulary 256, context 16. The import starts from public GPT-2 weights but truncates dimensions and blocks, omits projection biases, and applies NMAForge's own fixed-point LayerNorm/attention/GELU contracts. It is therefore a GPT-2-derived functional workload, not the original GPT-2 graph or a retrained H64 model.

## Gate results

| Gate | Status | Evidence |
|---|---|---|
| A1 — checkpoint import/package | **PASS** | Import manifest records source revision/hash, tensor mapping, quantization and package hash. Q/K/V head panels are reassembled into NMAForge `[K,N]`; LM head is transposed. |
| A2 — Product Top forward + feedback | **PASS** | VCS ran 4 layers and Final LN/LM Head, dumped 256 logits from Product Top SPAD at four contexts, and matched every dump bit-exactly against the independent NMAForge INT8 reference. Host Argmax outputs: `[145,113,113,113]`. No reset and no host-written hidden/intermediate words. |
| A3 — language quality and TinyNPU model benchmark | **PARTIAL** | No held-out language metric is claimed. TinyNPU and NMAForge arithmetic and graph contracts differ, so the run is not a paired TinyNPU speed comparison. |

The closed-loop run marker is `H64_AUTOREGRESSIVE_SEQUENCE_PASS generated_tokens=4 total_publications=4020 extension_cycles=4341096 reset_events=0 host_intermediate_words=0 mode=prefix_recompute`. Golden verification reports `all_logits_bit_exact=true`, 4 contexts and the same 4 generated tokens. The output Token IDs are a functional result only; they are not evidence of GPT-2 language quality.

The extension-cycle counter is a measured Product command-cycle accumulation for three later prefix-recompute contexts. It excludes host software/model preparation and is **not** an end-to-end application latency or a persistent-KV decode measurement. Each context rebuilds the valid prefix; query-only KV decode remains unmeasured.

## Preserved synthetic regression

The original deterministic/synthetic H64 package was also run through the same four-step autoregressive target. It passed all four independent logits checks and produced `[114,162,193,193]`. Run ID `R19-A-SYNTH-AR-20261117`; it is compatibility evidence only and has no model-quality meaning.

## Reproduction

Run from `dv/subsystem/top_smoke/sim` in this branch. Python environment: Python 3.12.13, NumPy 2.5.4, PyTorch 2.6.0+cpu, Transformers 4.48.3. Simulator: Synopsys VCS `V-2023.12-SP1_Full64`.

The pinned TinyNPU checkout exports the public GPT-2 checkpoint to FP32 tensors; the new importer then maps those tensors to the NMAForge H64 model package:

```bash
cd /tmp/nmaforge-v1.2-round19-tiny-npu
DEMO_OUTDIR=/tmp/nmaforge-v1.2-round19-gpt2-model \
  /tmp/nmaforge_deit_round17_venv/bin/python python/tools/export_gpt2_weights.py
cd /tmp/nmaforge-v1.2-round19-gpt2
/tmp/nmaforge_deit_round17_venv/bin/python \
  benchmark/gpt2_compat/round19/import_tinynpu_gpt2_weights.py \
  --source-fp32-npz /tmp/nmaforge-v1.2-round19-gpt2-model/gpt2_tiny_fp32.npz \
  --out /tmp/nmaforge_r19_gpt2_import
```

The importer was rerun from the saved FP32 export and reproduced package SHA-256 `99cbc583af22c409b9c7d2b8d99c180695b112ccaf01a61113be6da31c7065dd`.

```bash
make ai_h64_four_layer_top_argmax \
  AI_H64_AUTOREGRESSIVE=1 \
  AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_r19_gpt2_ar_vcs \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  AI_H64_FOUR_LAYER_MODEL_NPZ=/tmp/nmaforge_r19_gpt2_import/canonical_h64_model.npz \
  AI_H64_FOUR_LAYER_SEED=20261116 \
  AI_H64_FOUR_LAYER_TOKENS=1,7,42,3
```

Synthetic compatibility rerun:

```bash
make ai_h64_four_layer_top_argmax \
  AI_H64_AUTOREGRESSIVE=1 \
  AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_r19_gpt2_synth_ar \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  AI_H64_FOUR_LAYER_SEED=20261116 \
  AI_H64_FOUR_LAYER_TOKENS=1,7,42,3
```

Run IDs and raw logs:

| Run ID | Compile log | Run log | SHA-256 (compile / run) |
|---|---|---|---|
| `R19-A-REAL-GPT2-DERIVED-AR-20261117` | `/tmp/nmaforge_r19_gpt2_ar_vcs/compile.log` | `/tmp/nmaforge_r19_gpt2_ar_vcs/run.log` | `77d97a72b9ae2ba835736579341f04a973ece7d95267a89084e7328038e1c9f6` / `d55e750844327caa15c1ca8ff999cd5d168472a8106fd16c229a0736a8f9ac49` |
| `R19-A-SYNTH-AR-20261117` | `/tmp/nmaforge_r19_gpt2_synth_ar/compile.log` | `/tmp/nmaforge_r19_gpt2_synth_ar/run.log` | `5986a083a28e1599b4b9c9c39f2b74f0e36f3bf9ab2db16eff518e5a0cf084d0` / `2181aaa2f4969a14ca08a2ab46127a50caa0469b8d863c11fd799ab77f70481a` |

Raw runs and source checkpoint files remain outside Git; only source scripts, manifests, report and hashes are committed. Product RTL was not changed in this track.

## Changes

- Added a strict TinyNPU-derived checkpoint importer with explicit tensor mapping, quantization, source hashes and limitations.
- Added optional `--model-npz` support to the H64 generator, liveness planner, autoregressive generator and Top Make target. Default synthetic behavior remains the default.

## Remaining work

Train or otherwise qualify an H64 model on held-out language data, reconcile the mathematical contracts before a paired TinyNPU comparison, and implement/measure query-only persistent-cache decode before making model-performance claims.
