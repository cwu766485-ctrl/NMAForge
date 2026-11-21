# GPT-2-compatible Gate 1 artifact

This directory defines the fixed target shape used by the v2 research plan:
four decoder layers, hidden 64, four heads, FFN 256, vocabulary 256 and context
16. `gpt2_compat_golden.py` currently creates deterministic pseudo-weights and
an independent integer Golden for arithmetic/toolchain bring-up. These are not
exported or pretrained GPT-2 weights and do not demonstrate language-model
quality. The hashes are only the numerical contract for replaying this fixture.

`generate_descriptors.py` emits an operator lowering plan, not executable ABI
descriptors. Causal attention is explicitly marked
`BLOCKED_BY_PRODUCT_CONTRACT`: the current product requires multiple commands
and an explicit ownership/dependency schedule. The plan does not claim those
commands have been packed, allocated, DMA-loaded, or run on RTL.

Run:

```sh
python3 benchmark/gpt2_compat/gpt2_compat_golden.py \
  --out /tmp/nmaforge_gpt2/golden.json --weights /tmp/nmaforge_gpt2/weights.npz
python3 benchmark/gpt2_compat/generate_descriptors.py \
  --out /tmp/nmaforge_gpt2/descriptors.csv \
  --manifest /tmp/nmaforge_gpt2/manifest.json
```

The RTL execution field remains `NOT_RUN`. Completing the model-import and
quantization pipeline requires a pinned source checkpoint and a separately
validated quantization contract. A legal Transformer lowering, top-level
descriptor replay, and final-memory Golden comparison are also still required.
