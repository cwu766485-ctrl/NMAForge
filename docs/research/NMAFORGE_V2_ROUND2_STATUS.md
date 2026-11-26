# NMAForge v2.0 Round 2 Status

## Fixed checkpoints

| Item | SHA / status |
|---|---|
| Product baseline PR #8 | `0492c47d12cd11bcc22be1930da7af77ed870b6e` |
| Research baseline | `2d85b11e42b45a8fbdb73398c3bc884fbc69f3bf` |
| Round 2 branch | `research/nmaforge-v2-product-baseline` |

No product branch or PR was merged.

## Gate 1: GPT-2 reference and graph

The previous pseudo-reference was corrected. The new implementation contains
token plus position embedding, GPT-2-compatible Pre-LN block ordering,
scaled causal softmax, GELU, residuals, final LayerNorm, tied-shape LM head,
and an independent INT8 reference with Q15 softmax, fixed-point rounding and
saturation. It emits per-tensor shape, dtype, quantization and producer/
consumer metadata.

```text
FP32 Golden: PASS
INT8 Golden: PASS
FP32 logits SHA: 32eeca1a87c39532a35737954fe7501b2ab432afe5bb2e0fbf72e41d6bf5a4ff
INT8 logits SHA: 8161db0e717c913313e9ae8c82ce79be24cfef4e7fadda5cd4a1e4b71de4d15f
Graph nodes: 62
```

The four-layer H64 plan is not executable product CMDQ. All 62 nodes are
marked `BLOCKED` because the current Matrix/SFU descriptor legality and
ownership contracts do not provide a legal H64 lowering. RTL execution is
`NOT_RUN`; there is no Host fallback or fabricated RTL pass. The deterministic
weights remain a bring-up fixture, not a pretrained GPT-2 checkpoint.

The existing product H16 path remains the only real Transformer RTL baseline:
four-token prefill and four persistent decode stages passed at the fixed PR #8
candidate and averaged 8183.50 simulated cycles per decode token.

## Gate 2: H64 RTL status

`NOT_RUN`. The existing mapper has H16-specific contracts and the product
representative harness requires the legal descriptor/memory-image contract.
The next required implementation is a real 16x16-tile H64 single projection,
then an attention block, before attempting four-layer decode. No H64 tensor is
copied from Python into memory and called hardware-executed.

## Gate 3/4: DAMS and SVSE

The independent DAMS scheduler prototype still passes:

```text
DAMS_SVSE_PASS accepted=3 denied=1
```

The SVSE research pipeline now has a single-word registered-SPAD adapter. It
was compared against `ai_tensor_sfu_math` for nonzero signed operations:

```text
SVSE_PRODUCT_ADAPTER_PASS residual=140 requant=127
```

This closes arithmetic and request/response adapter evidence only. Real Top /
Dispatcher integration is `BLOCKED_BY_CONTROL_CONTRACT`: the adapter has no
legal command ID, completion slot, descriptor allocation, protection owner,
or response mux connection. Connecting it directly would change Legacy
ownership semantics, so no product RTL/ABI change was made.

## Reproduction

```sh
cd /tmp/nmaforge-v2-product
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/gpt2_compat_golden.py \
  --out /tmp/nmaforge_gpt2_round2/golden.json \
  --weights /tmp/nmaforge_gpt2_round2/weights.npz
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/generate_descriptors.py \
  --out /tmp/nmaforge_gpt2_round2/plan.csv \
  --manifest /tmp/nmaforge_gpt2_round2/manifest.json
make -C dv/research/dams_svse/sim all
make -C dv/research/dams_svse/sim adapter
```

The VCS version is `V-2023.12-SP1_Full64`. The adapter rerun is warning-free
after explicit-width TB constants. Behavioral SPAD and simulated clocks are
functional evidence, not ASIC timing or PPA.

## Decisions

| Candidate | Decision | Reason |
|---|---|---|
| Correct FP32/INT8 reference | RETAIN | Required for valid model comparison |
| H64 product execution | REWORK | Legal descriptor and tile lowering are still missing |
| DAMS prototype | REWORK | Needs real command/tensor ownership before product A/B |
| SVSE arithmetic adapter | RETAIN_FOR_RESEARCH | Bit-exact adapter passes; Top integration remains blocked |
