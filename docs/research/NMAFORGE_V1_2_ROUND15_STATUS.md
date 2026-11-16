# NMAForge v1.2 Round 15 — Persistent Decode Status

## Decision

**Overall disposition: `PARTIAL`.** The bounded two-token and multi-stage persistent Top runs pass. They demonstrate that Product Top writes K/V, preserves it across token stages without reset, and that all four attention heads depend on their K/V cache. This is a teacher-forced verification workload with causal-prefix recomputation; it is not autonomous language generation or an optimized one-query-per-token decoder. Four-layer GPT-2 Product Top execution remains unrun.

| Gate | Status | Evidence |
|---|---|---|
| G0 — token/runtime planning | **PASS, testbench scope** | Reusable `TokenPlanner`/`TensorMemoryPlanner`, descriptor generation, AXI-Lite publication, completion retirement, queue wrap, and DMA fences are exercised by the Top testbench runtime. This is not a production host runtime API. |
| G1 — two-token persistent decode | **PASS** | One Top instance, 201 prefill + 193 decode descriptors, no reset, all 512 K/V words read back before Stage 1, 31 Stage 1 checkpoint records and 6,912 final Golden words. |
| G2 — Token 0–5 and 4+2 | **PASS** | Both sequences pass on the same source SHA; 1,194 and 639 total descriptor publications respectively, CMDQ/CPLQ wrap, no reset, and per-stage Golden checks. |
| G3 — four-layer execution readiness | **PARTIAL** | Static four-layer memory/weight/lifetime plan is generated. No four-layer Descriptor stream or Product Top run exists. |

## Version and environment

- Research branch: `research/nmaforge-v1.2-round15`, based on Round 14 `a75eb55a08415732ee981ad12f343cbd92ce3ebe`.
- Tested planner/testbench source commit: `2663a7a1e3f5585fd660195edb785e1ab7711908`.
- Product RTL last-change commit: `1458a062cf8e5a30ffca940440573694ea28c658`; no Product RTL changed in Round 15.
- Seed: `20261116`; model/reference SHA-256: `67a89c411254039bab22a7dffc49c64b69233575368503f544ee9f3ec4ab00fc`.
- VCS: `/usr/local/bin/vcs`, `V-2023.12-SP1_Full64`. Python: `/tmp/nmaforge_round10_venv/bin/python`, 3.12.13; NumPy 2.4.6.
- VCS compile and nominal simulations completed successfully after the user restored the license. The cause of the earlier license-server connection failure was not established; no license endpoint/configuration is included here.
- No Product RTL or operator was added. Changes are limited to the planner, Top testbench runtime, Make target, mutation helper, and static plan/evidence artifacts.

## G1: Product-generated K/V and four-head dependency

G1 physically initializes a two-row tile containing token 0 plus a placeholder row; only token 0 is semantically valid, so this is not a one-row optimized decode. All 512 words across the initial K/V cache ranges are `0xa55aa55a` (`0xe000..0xe3fc` and `0xe400..0xe7fc`), so the cache image does not contain host-precomputed K/V. The per-head region bases are K=`0xe000/0xe100/0xe200/0xe300`, V=`0xe400/0xe500/0xe600/0xe700`. Stage 0 executes the prefill graph on Product Top. Before any Stage 1 token inputs are written, the testbench reads all 512 K/V cache words over the Top AXI-Lite aperture and compares them with the independent expected cache image. The readback passes, showing that the prefill commands replaced the initial sentinels. Stage 1 publishes no host intermediate or host K/V words (`host_intermediate_words=0`, `host_kv_words=0`).

For each head, the generated descriptor contract orders a real K/V append, Product KV readback, then consumption by QK/AV:

| Head | K append → K read → QK | V append → V read → AV |
|---:|---|---|
| 0 | 33 → 34 → 37 | 35 → 36 → 74 |
| 1 | 44 → 45 → 48 | 46 → 47 → 79 |
| 2 | 55 → 56 → 59 | 57 → 58 → 84 |
| 3 | 66 → 67 → 70 | 68 → 69 → 89 |

The normal Top run checks all 31 intermediate checkpoint records, including per-head cache readback, QK, Softmax, AV, and later tensors; it then compares 6,912 final words. The eight directed cache mutations flip one bit at each head’s K and V base. All eight are detected by the corresponding Product readback checkpoint before any terminal PASS marker:

| Corrupted cache | First Golden checker detecting it |
|---|---|
| H0 K / V | descriptor 34 / 36 |
| H1 K / V | descriptor 45 / 47 |
| H2 K / V | descriptor 56 / 58 |
| H3 K / V | descriptor 67 / 69 |

This demonstrates four-head cache-path sensitivity. Because the mutation is caught at the K/V readback checkpoint, it does not claim that a corrupted value was propagated through and separately observed at the downstream QK/AV output.

G1 run metrics: Stage 0 has 201 descriptors, 259,568 command cycles, and 327,400 cycles including initial preload. Stage 1 publishes 193 descriptors and takes 353,214 command-window cycles. The Stage 1 figure excludes host input publication and the 45 weight-DMA fence transactions, so it is not full per-token end-to-end latency.

## G2: continuous sequence evidence

| Run | Prefill / Decode | Descriptor counts | Decode command cycles | Notes |
|---|---:|---|---:|---|
| `G2_prefill4_decode2` | 4 + 2 | 225 / 205 / 209 | 359,370 + 361,632 = **721,002** | Appends token positions 4 and 5; 639 total publications. |
| `G2_token0_to5` | 1 + 5 | 189 / 193 / 197 / 201 / 205 / 209 | **1,786,548** total; 353,214 / 355,134 / 357,198 / 359,370 / 361,632 | Appends positions 1–5; 1,194 total publications. |

Each appended stage retains the same Product Top, checks all 512 K/V words before publishing the new input, reloads the model weights through 45 fenced DMA transactions, waits for and retires each completion, checks 31 intermediate records and 6,912 final Golden words, and reports zero reset events. The 256-entry CMDQ/CPLQ rings wrap during both runs.

**Semantic/performance limit:** Decode inputs are teacher-forced by the host. The planner appends only the new token’s K/V and consumes the persistent Product cache, but it regenerates a causal-prefix graph at each stage (`decode_prefix_recompute`). Therefore these cycle counts include repeated prefix work and exclude between-stage host input writes and weight-DMA setup. They prove persistent cache correctness, not optimized incremental Decode latency or autonomous token generation.

## G3: four-layer execution plan

`benchmark/gpt2_compat/plan_h64_four_layer_execution.py` generates a static four-layer H64 reference plan with per-tensor hashes, proposed layer-specific K/V regions, liveness/reuse notes, layer-by-layer weight-streaming order, and final LayerNorm/LM Head placement.

- Serialized parameter image: 233,280 bytes.
- Context-16 layer-specific K/V: 2,048 bytes/layer; 8,192 bytes total. Proposed ranges are `0x10000..0x12000`, subject to address/protection contract review.
- Existing one-layer Top high-water: 130,576 bytes. Adding the extra persistent K/V without temporary-lifetime compaction gives a **naive estimate** of 136,720 bytes, above the 128 KiB SPAD capacity by 5,648 bytes. This estimate is not a proven lower bound; four-layer allocation feasibility remains open.
- Weight streaming is a static one-layer-at-a-time proposal. No DMA descriptor/burst plan, four-layer Product Top graph, Final LN/256-logit Golden, or model-quality result is present.
- Weights are deterministic synthetic reference weights, not pretrained GPT-2 weights; model quality is not measured.

Plan status is `STATIC_EXECUTION_PLAN_NOT_RTL_RUN`. DeiT-Tiny and four-layer RTL integration were not started.

## Reproduction and evidence

Run from `dv/subsystem/top_smoke/sim`:

```bash
make ai_h64_persistent_two_token \
  AI_H64_PERSISTENT_RUN=/tmp/nmaforge_v12_r15_g1_mutation_base

make ai_h64_persistent_sequence \
  AI_H64_PERSISTENT_RUN=/tmp/nmaforge_v12_r15_4plus2_final \
  AI_H64_PERSISTENT_TOKENS=1,7,42,3,5,8 \
  AI_H64_PERSISTENT_PREFILL_TOKENS=4

make ai_h64_persistent_sequence \
  AI_H64_PERSISTENT_RUN=/tmp/nmaforge_v12_r15_0to5_final \
  AI_H64_PERSISTENT_TOKENS=1,7,42,3,5,8 \
  AI_H64_PERSISTENT_PREFILL_TOKENS=1
```

After the G1 compile, run all K/V cache mutation controls from the repository root:

```bash
/tmp/nmaforge_round10_venv/bin/python \
  benchmark/gpt2_compat/run_h64_cache_mutations.py \
  --run-log /tmp/nmaforge_v12_r15_g1_mutation_base/run.log \
  --out /tmp/nmaforge_v12_r15_cache_mutations_retry
```

The generated logs are retained locally (not committed): each run directory contains complete `compile.log` and `run.log`; the eight mutation logs are under `/tmp/nmaforge_v12_r15_cache_mutations_retry/`. Their byte counts and SHA-256 values, per-stage results, and per-head dependencies are recorded in [`round15_persistent_decode_evidence.json`](../../benchmark/gpt2_compat/results/round15_persistent_decode_evidence.json). A compact stage table is in [`round15_persistent_decode_stages.csv`](../../benchmark/gpt2_compat/results/round15_persistent_decode_stages.csv). The static four-layer plan is in [`round15_four_layer_execution_plan.json`](../../benchmark/gpt2_compat/results/round15_four_layer_execution_plan.json). Recreate it with `/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/plan_h64_four_layer_execution.py --seed 20261116 --out benchmark/gpt2_compat/results/round15_four_layer_execution_plan.json`.

## Remaining work

1. Replace prefix recomputation with a genuine query-only incremental schedule before treating these command windows as optimized per-token Decode latency.
2. Produce autoregressive feedback (or keep `teacher-forced` as the explicit mode) and add end-to-end timing that includes token input, between-stage DMA, Host work, and output readback.
3. Prove that the four-layer SPAD allocation fits after actual lifetime reuse, then generate and run the four-layer Top graph with layer-specific KV, weight streaming, Final LN, and LM Head Golden.
4. The earlier license-server connection outage’s root cause remains unidentified even though the current licensed VCS runs pass.

No PR was merged and no main or other worktree was modified.
