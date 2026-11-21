# NMAForge v2.0 Round 4 Status

This report records the reproducible Round 4 worktree based on
`17af528cdcf4cbd32895d66a05a8da1e96992853`. Product branches and PR #7/#8
were not merged. The worktree is `/tmp/nmaforge-v2-round4`, branch
`research/nmaforge-v2-round4`, and the simulation tool is VCS
`V-2023.12-SP1_Full64` with a 10 ns clock.

## Gate 0: corrected H64 accounting

The four `M=16,N=16,K=64` projection descriptors execute 65,536 physical
MACs. Only four of the sixteen physical rows carry model tokens:

| quantity | value |
|---|---:|
| physical tile rows | 16 |
| useful token rows | 4 |
| executed MACs | 65,536 |
| useful model MACs | 16,384 |
| padding MACs | 49,152 |
| useful output elements | 256 |
| physical output elements | 1,024 |
| command/end-to-end cycles | 1,188 |
| DMA preload included | 0 |

The Product Top checked 1,024 output words and completions. Evidence:
`/tmp/nmaforge_round4_final_projection_20261115/run.log`.

Reproduce:

```sh
cd /tmp/nmaforge-v2-round4/dv/subsystem/top_smoke/sim
make ai_h64_projection_top \
  AI_H64_PROJECTION_RUN=/tmp/nmaforge_round4_final_projection_20261115
```

## Gates 1 and 2: H64 RTL evidence

The executable H64 generator emits real ABI-v7.4 descriptors, a SPAD image,
poison values, and independent Golden data. The Pre-LN/QKV chain passed with
30 descriptors, 5,376 Golden words, and 36,914 command cycles. It includes
fixture-loaded token embedding rows, position residual, 64-wide LayerNorm,
INT32-to-INT8 layout conversion, and Q/K/V projections.

The four-token/four-head attention workload passed in the Product Top with
108 descriptors and 12,288 Golden words. It covers QK^T, causal Q15 softmax,
attention times V, output projection, Residual 1, and LayerNorm 2. Its result
was 91,351 command cycles and a SPAD high-water address of 116,416 bytes.
The output projection uses a legal `N=64` descriptor and its final memory image
is checked by the testbench. Evidence:
`/tmp/nmaforge_round4_final_attention_20261115/run.log`.

Reproduce:

```sh
cd /tmp/nmaforge-v2-round4/dv/subsystem/top_smoke/sim
make ai_h64_preln_qkv_top AI_H64_PRELN_QKV_RUN=/tmp/nmaforge_preln_qkv_round4
make ai_h64_attention_top AI_H64_ATTENTION_RUN=/tmp/nmaforge_attention_round4
```

## Gate 3: exact boundary

FFN Up/GELU/FFN Down, Residual 2, KV Cache lifetime, final LayerNorm, LM Head,
four-layer execution, and persistent decode are `NOT_RUN`. The completed
attention allocation reaches `0x15a00`; queue reservation starts at `0x1a000`.
Retaining all live inputs, outputs, and weights leaves no legal static room for
both 256-wide FFN weight matrices. A correct implementation requires DMA
streaming and lifetime-aware weight reuse. No address masking or aliasing was
introduced. This is the first blocking point for a complete Decoder Block.

## Gate 4: SVSE direct forwarding

The research-only opcode `0x3a` (`Residual -> packed INT8 Requant`) was added
to the isolated branch. It reuses existing residual arithmetic, INT8
saturation, and packed writeback; legacy opcodes are unchanged. The validator
requires ABI v7, `flags[4]=1`, a nonzero length divisible by four, and aligned
operands. The dispatcher routes `0x3a` to the SFU engine.

The Product Top A/B uses identical 64-element signed INT32 inputs, shift 3,
independent Golden, and the same 128 KiB SPAD:

| configuration | descriptors | cycles | SPAD reads | SPAD writes | result |
|---|---:|---:|---:|---:|---|
| Residual then Requant | 2 | 740 | 768 B | 320 B | PASS |
| Direct `0x3a` | 1 | 468 | 512 B | 64 B | PASS |

The direct path uses 36.76% fewer command cycles, 33.3% fewer reads, and 80%
fewer writes for this workload. Raw logs and memory images are under
`/tmp/nmaforge_round4_sfu_fusion_verified_20261115/`.

Reproduce:

```sh
cd /tmp/nmaforge-v2-round4/dv/subsystem/top_smoke/sim
make ai_sfu_residual_requant_ab \
  AI_SFU_FUSION_RUN=/tmp/nmaforge_round4_sfu_fusion_verified_20261115
```

This is a directed prototype result. Backpressure, parity/protection fault,
abort during a partial packed word, reset with an outstanding response, and
multi-shape coverage remain open. Decision: `RETAIN_AS_RESEARCH /
REWORK_FOR_PRODUCT`.

## Gate 5: DAMS opportunity

The passive monitor records issue, SPAD accept and response owner, line
accepts, completion retirement, fault, abort, reset, and engine transitions.
Existing Top Smoke observed 360 multi-engine busy cycles, 206 issues, 161
retires, 198 resource stalls, 24 aborts, 71 fault transitions, and 2 resets.
The current dispatcher already schedules these cross-engine pairs and retires
them in order.

H16 QKV, H64 QKV/attention, and CNN traces each had zero cycles with two engines
busy. No trace showed a legal descriptor window left unused by the current
dispatcher. Decision: `NO_INCREMENTAL_OPPORTUNITY` and
`REJECT_FOR_PRODUCT` for further DAMS scheduler RTL in this round.

## Regression

`make ai_smoke` passed after the opcode routing change (seed 12345, 4 random
cases), with `TEST PASS` and no test failures. After the license was restored,
the latest focused runs also passed:

- H64 Attention: `/tmp/nmaforge_round4_license_attention_20261115/run.log`
- SVSE A/B: `/tmp/nmaforge_round4_license_fusion_20261115/baseline/run.log`
- SVSE fused: `/tmp/nmaforge_round4_license_fusion_20261115/fused/run.log`

H64 Projection, H64 Attention, and direct forwarding A/B all pass with real VCS
execution. No product branch was changed or merged.

## Remaining work

1. Implement DMA-streamed FFN weights and explicit live-range reuse before
   claiming a complete H64 Decoder Block.
2. Add direct-forwarding fault, abort, reset, and backpressure tests plus SVA.
3. Re-run DUT-only coverage after those tests; this is not a DV closure claim.
4. Keep opcode `0x3a` out of product ABI until its contracts and multi-shape
   A/B are reviewed.
