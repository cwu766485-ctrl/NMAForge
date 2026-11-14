# GPT-2-compatible Gate 1 artifact

This directory defines the fixed, reproducible target shape used by the v2
research plan: four decoder layers, hidden 64, four heads, FFN 256, vocabulary
256 and context 16. `gpt2_compat_golden.py` creates deterministic signed INT8
weights and an independent integer Golden for a token sequence. The generated
state and logits hashes are the numerical contract for later RTL replay.

`generate_descriptors.py` emits ABI-v7.4-shaped descriptor records. Primitive
GEMM, LayerNorm and KV records are legal candidates for the existing engines;
causal attention is explicitly marked `BLOCKED_BY_PRODUCT_CONTRACT` because the
current product has no single descriptor that represents the complete
producer/consumer ownership and softmax schedule. This is a truthful lowering
boundary, not a host-computed result.

Run:

```sh
python3 benchmark/gpt2_compat/gpt2_compat_golden.py \
  --out /tmp/nmaforge_gpt2/golden.json --weights /tmp/nmaforge_gpt2/weights.npz
python3 benchmark/gpt2_compat/generate_descriptors.py \
  --out /tmp/nmaforge_gpt2/descriptors.csv \
  --manifest /tmp/nmaforge_gpt2/manifest.json
```

The current RTL execution field remains `NOT_RUN` until a legal Transformer
macro lowering and matching top-level descriptor test are added.
