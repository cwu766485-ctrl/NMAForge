# NMAForge v2.0 Gate 0 Product Baseline

## Scope

This baseline is measured from the PR #8 product candidate:

| Item | Value |
|---|---|
| Product candidate | `0492c47d12cd11bcc22be1930da7af77ed870b6e` |
| PRs | #7 `candidate/frontend-closeout`; #8 `dv/compute-cluster-closure-round2` |
| SPAD | 4 banks, 8192 32-bit words/bank, 128 KiB default |
| Compute array | 256 INT8 MACs (`ARRAY_SIZE=16`) |
| DMA | 128-bit AXI4 behavioral testbench memory |
| Clock used here | 10 ns simulation period; not an ASIC Fmax claim |
| VCS | `V-2023.12-SP1_Full64` |

The source is isolated on `research/nmaforge-v2-product-baseline`. PR #7/#8
were not merged or modified.

## Existing Product Evidence

The native Top transformer fixture passed with 86 descriptors and checked the
intermediate tensors, KV words, completion ordering, and final completion:

```text
TRANSFORMER_MAPPER_PASS descriptors=86 tensors=60 dataflow=closed poison=enabled
TEST PASS
```

The measured command was:

```sh
cd /tmp/nmaforge-v2-product
make inference-transformer TRANSFORMER_SEED=20261114
```

The fixture is deterministic functional data, not a trained or pretrained
language model. It proves the currently supported operator/dataflow path only.

## Incremental Decode Replay

The current candidate also passed the existing H16 persistent KV path. The
independent generator produced a four-token prefill and four decode stages;
each stage compared the observed SPAD image and logits against the scalar INT8
reference.

| Stage | Descriptors | Cycles | Useful MACs | SPAD read/write |
|---|---:|---:|---:|---:|
| Prefill | 40 | 2728 | 3072 | 2560 / 1536 B |
| Decode t4 | 53 | 8138 | 1696 | 9056 / 5264 B |
| Decode t5 | 53 | 8216 | 1728 | 9056 / 5264 B |
| Decode t6 | 53 | 8237 | 1760 | 9056 / 5264 B |
| Decode t7 | 53 | 8143 | 1792 | 9056 / 5264 B |

```text
H16_INCREMENTAL_TOP_PASS
H16_INCREMENTAL_OBSERVATION_VERIFY_PASS stages=5 decode_steps=4 average_decode_cycles=8183.50
```

Reproduction:

```sh
cd /tmp/nmaforge-v2-product/dv/subsystem/top_smoke/sim
/tmp/nmaforge_round10_venv/bin/python ../../../../sw/tools/generate_h16_incremental_decode.py \
  --model ../../../../benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json \
  --out /tmp/nmaforge_v2_gate0_h16/workload
/tmp/nmaforge_v2_gate0_h16/simv +ntb_random_seed=20261114 +AI_RANDOM_CASES=0 \
  +AI_SEED=20261114 +ACLK_PERIOD_NS=10.0 +AI_H16_INCREMENTAL_DECODE \
  +AI_H16_INCREMENTAL_DIR=/tmp/nmaforge_v2_gate0_h16/workload \
  -l /tmp/nmaforge_v2_gate0_h16/run.log
/tmp/nmaforge_round10_venv/bin/python \
  ../../../../sw/tools/summarize_h16_incremental_decode.py \
  --run-dir /tmp/nmaforge_v2_gate0_h16
```

## Architecture Bottleneck

The decode profile is SFU dominated: LayerNorm, Requant, residual and
softmax are serialized through the existing shared compute/SPAD contract.
The product contract still routes ordinary compute traffic through one shared
SPAD admission point and does not expose a new multi-port SRAM contract.
Therefore DAMS and SVSE must be evaluated as independent A/B candidates; the
baseline does not assume bank parallelism or fused operators that are absent
from the product RTL.

## Gate 0 Disposition

`PASS_SCOPED`: product SHA, geometry, Golden rules, tool versions, and an
existing Transformer/H16 execution path are reproducible. The requested
4-layer / Hidden-64 / 4-head / FFN-256 / vocabulary-256 / context-16 model is
`NOT_IMPLEMENTED` in the current product path and remains a research target.
No accuracy, cycle, ASIC PPA, FPGA frequency, or pretrained-model claim is
made for that target.
