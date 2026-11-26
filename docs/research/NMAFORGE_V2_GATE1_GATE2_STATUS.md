# NMAForge v2.0 Gate 1/2 Status

This status is based on PR #8 product candidate
`0492c47d12cd11bcc22be1930da7af77ed870b6e` and the independent research
commit on top of it.

## Gate 1: GPT-2-compatible toolchain

The target shape is fixed at four decoder layers, hidden 64, four heads,
FFN 256, vocabulary 256, context 16. The new `benchmark/gpt2_compat` tools
provide:

- deterministic signed-INT8 weight export;
- independent integer LayerNorm, causal attention selection, residual, GELU
  and LM-head Golden;
- an operator lowering CSV and ABI manifest.

Observed result:

```text
fixture_golden=PASS
logits_sha256=a86a19495fa2dfd052e63d6324bad5babf35b01cce2970ac31c66c0c20ee45c8
state_sha256=ae28709b011f492bb0e5a83278e91a5bf5780a8b6bb3418e6dac5f6b30d454f2
descriptor_count=41 supported_primitive_count=37 blocked_count=4
```

The fixture uses deterministic pseudo-weights and is not a pretrained GPT-2
checkpoint. The plan is not executable CMDQ data. Causal softmax and
persistent decode are marked `BLOCKED_BY_PRODUCT_CONTRACT`; no host-side
computation is used to claim RTL execution. `RTL execution = NOT_RUN` for this
new target.

Reproduce:

```sh
cd /tmp/nmaforge-v2-product
mkdir -p /tmp/nmaforge_gpt2_review
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/gpt2_compat_golden.py \
  --out /tmp/nmaforge_gpt2_review/golden.json \
  --weights /tmp/nmaforge_gpt2_review/weights.npz
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/generate_descriptors.py \
  --out /tmp/nmaforge_gpt2_review/plan.csv \
  --manifest /tmp/nmaforge_gpt2_review/manifest.json
```

Gate disposition: `PARTIAL`. A pinned real checkpoint, quantization contract,
legal causal-softmax lowering, DMA placement and Top memory-image replay are
still required before claiming the requested end-to-end model.

## Gate 2: DAMS and SVSE prototypes

The isolated prototypes add no product ABI or top-level wiring:

- `ai_dams_scheduler.sv`: bounded dependency mask, four-bank reservation,
  atomic admission, ordered grant, epoch/fault flush and stable grant SVA.
- `ai_streaming_sfu.sv`: one-entry decoupled Residual/Requant pipeline with
  saturation, backpressure stability and epoch flush.

The independent testbench exercises two-bank admission, same-bank denial,
dependency release, backpressure, epoch flush and requant saturation:

```text
DAMS_SVSE_PASS accepted=3 denied=1
```

Reproduce:

```sh
cd /tmp/nmaforge-v2-product
make -C dv/research/dams_svse/sim VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

Gate disposition: `PROTOTYPE_PASS / PRODUCT_NOT_INTEGRATED`. The prototype
must not be interpreted as evidence of system speedup. A fair A/B requires
integration through the existing dispatcher, real SPAD ownership, legal
dependency descriptors, independent Golden checking, and the same workload
endpoint as the product baseline.

## Research guardrails

The following remain explicit `NOT_IMPLEMENTED` or `NOT_MEASURED`:

- four-layer H64 execution through product Top;
- pretrained GPT-2, DeiT-Tiny, and MobileViT-XS;
- product-integrated DAMS or SVSE;
- FPGA implementation timing/resource measurements;
- mapped ASIC area, Fmax, SRAM macro timing, and power.

No product branch or PR was merged. Behavioral SRAM and simulated clock
periods remain functional evidence only.
