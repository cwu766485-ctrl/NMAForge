# NMAForge V1.2 Round 22 — GPT-2 Candidate Top Qualification

## Disposition

**Product Top candidate execution: PASS. Model-quality closure: PARTIAL.** A candidate made from the existing trained H64 checkpoint completed a four-logit autoregressive Product Top run, and the four 256-element INT32 logits were independently compared bit-for-bit. Its held-out next-byte accuracy remains below the same-window bigram baseline, so this is numeric-contract/Product Top evidence rather than a successful language-quality recovery.

The work was performed in the isolated `research/nmaforge-v1.2-round21-gpt2` worktree. The frozen analysis base was `540a3fb465f6997c29b24ab72489d4095aa7c5ea`; no product RTL, `main`, or other worktree was changed. The candidate profile is opt-in and leaves the `frozen` mapper default intact.

## Candidate and model-quality evidence

| Item | Value |
|---|---|
| Model | H64, 4 layers, 4 heads, FFN 256, byte vocabulary 256, context 16 |
| Source FP32 checkpoint SHA-256 | `1d59cf803c328149add9ddb004766e63043b3babdb56ea178bf96d7a51fda8df` |
| Canonical INT8 package SHA-256 | `2132835994c2ecce03dc1d8e7345474eeddb271d86e34de9cc1f5ccdf2fecfc2` |
| Product candidate package SHA-256 | `765bfa29f545716f774c6d3ddbb7dc80106b75a5ebc40801075331d6040d3e3e` |
| Numeric profile | `round21_residual_gelu_aligned` |
| Candidate held-out targets | 1,024 fixed Round 21 targets, seed `20261121` |
| Candidate INT8 accuracy / CE / PPL | 16.31% / 4.099 nats / 60.27 |
| Frozen INT8 accuracy / CE / PPL | 11.52% / 6.774 nats / 874.97 |
| FP32 accuracy on the same targets | 37.40% |
| Candidate FP32/INT8 top-1 agreement | 26.95% |
| Same-window bigram accuracy | 29.20% |

The software candidate improves accuracy by 4.79 percentage points, reduces CE by 2.675 nats, and reduces PPL from 874.97 to 60.27. It remains 12.89 points below bigram and 21.09 points below FP32. Round 22 did not claim quality closure or change the evaluation targets. The existing Round 21 analysis contains the controlled quantization-contract comparison and diagnosis.

## Product Top execution

The candidate ran through the four-layer Product Top with host feedback from actual Product Top SPAD logits. The same Product Top simulation had zero reset events and no host-written hidden/intermediate tensors. It used **prefix recomputation**, not query-only incremental Decode. Host duties were reading the 256 logits, lowest-token-ID tie-broken argmax, and writing the next token's embedding/position input.

Prompt `[1, 7, 42, 3]` produced tokens `[32, 66, 117, 107]`. For each step, all 256 signed INT32 logits from the Top were compared against `round21_contract_ablation.py::infer` on the exact prefix. All four comparisons were bit-exact; independent and RTL argmax values matched. Per-step hashes and source dump hashes are recorded in `benchmark/gpt2_quality/results/round22/product_top_independent_logits.json`.

The testbench reported 4,020 descriptor publications and 4,338,360 extension cycles for the three feedback prefix replays. The initial prompt run was reported separately as 263,007 command cycles / 354,847 stage end-to-end cycles; the following three layer cycles were 1,049,028. These counters do **not** include all host-side feedback/AXI writes as a single session latency, so no full host-to-host latency is claimed. Measured context counters were 1,413,684, 2,859,744, and 4,338,360 cumulative for feedback contexts 1–3.

### Commands

Candidate export (using the locally available Round 20 checkpoint):

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/export_round22_product_candidate.py \
  --package benchmark/gpt2_quality/models/canonical_h64_byte_lm_int8.npz \
  --fp32 /tmp/nmaforge_v12_r20_gpt2_quality_corrected/h64_byte_lm_fp32.pt \
  --out /tmp/round22_gpt2_candidate/model.npz
```

Product Top run, from `dv/subsystem/top_smoke/sim`:

```bash
make ai_h64_four_layer_top_argmax AI_H64_AUTOREGRESSIVE=1 \
  AI_H64_FOUR_LAYER_MODEL_NPZ=/tmp/round22_gpt2_candidate/model.npz \
  AI_H64_NUMERIC_PROFILE=round21_residual_gelu_aligned \
  AI_H64_FOUR_LAYER_RUN=/tmp/round22_gpt2_candidate/autoreg \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  AI_H64_FOUR_LAYER_SEED=20261121 AI_H64_FOUR_LAYER_TOKENS=1,7,42,3 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

Independent logits check, from repository root:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/verify_round22_product_logits.py \
  --candidate /tmp/round22_gpt2_candidate/model.npz \
  --fp32-checkpoint /tmp/nmaforge_v12_r20_gpt2_quality_corrected/h64_byte_lm_fp32.pt \
  --rtl-dir /tmp/round22_gpt2_candidate/autoreg --prompt 1,7,42,3 --steps 4 \
  --out benchmark/gpt2_quality/results/round22/product_top_independent_logits.json
```

The changed Makefile also passed the independent default smoke:

```bash
cd dv/subsystem/top_smoke/sim
make ai_smoke VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

The smoke used four random cases and seed `12345`; its run log ends in `TEST PASS`. VCS was `V-2023.12-SP1_Full64`; KDB elaboration reported zero errors and zero warnings. Existing `LOOP-REROLL-ENABLED` simulator diagnostic is retained in the raw log.

## Round 22 changes and evidence

- `benchmark/gpt2_compat/generate_h64_preln_qkv.py`, `prepare_h64_four_layer.py`, and `prepare_h64_autoregressive.py`: added an explicit, opt-in numeric profile for the tested projection/GELU shifts and LayerNorm beta handling.
- `dv/subsystem/top_smoke/sim/Makefile`: added `AI_H64_NUMERIC_PROFILE`, defaulting to `frozen`.
- `benchmark/gpt2_quality/export_round22_product_candidate.py`: reproducibly exports the separate Product Top candidate package without replacing the canonical package.
- `benchmark/gpt2_quality/verify_round22_product_logits.py`: independently checks each RTL logit vector and argmax.
- Candidate package, manifest, result JSON, four raw Top logit CSVs and compressed full compile/run/smoke logs are under `benchmark/gpt2_quality/results/round22/`.

The old frozen/synthetic autoregressive evidence was not altered. The round's Product Top candidate qualification does not establish language quality above the bigram baseline, and it is not a persistent KV query-only Decode measurement.
