# NMAForge v2.0 Round 5 Architecture Decision

## Gate status

| gate | status | evidence |
|---|---|---|
| DMA and lifetime tile | PASS | Real Top, 4 DMA segments, 3,648 bytes, 1,088 Golden words |
| FFN up/down tile | PASS | GEMM -> GELU -> Requant -> GEMM -> Residual 2 |
| complete one-block Decoder | NOT_RUN | First blocker is per-tile 256-wide FFN DMA/compute scheduling |
| four-layer/persistent decode | NOT_RUN | Depends on complete block and KV lifetime |
| SVSE normal shape sweep | PASS | 4/8/16/32/64/128 real Product Top runs |
| SVSE fault/reset closure | NOT_RUN | No non-vacuous fault/abort/reset run in this round |
| DAMS incremental product work | REJECT_FOR_PRODUCT | Round 4 trace found no unused legal window |

## Decision

- **SVSE `0x3A`: `REWORK_FOR_PRODUCT`**. The traffic and cycle reduction is
  reproducible, but the safety contract is incomplete and no legal full-model
  match has been demonstrated.
- **DMA lifetime work: `RETAIN_AS_RESEARCH`**. The real tile proves a safe
  allocation and DMA-to-compute ordering method without changing the product
  ABI. It is not yet a complete decoder implementation.
- **Full H64 Decoder: `REWORK`**. The final missing mechanism is bounded
  per-tile weight streaming with explicit completion/dependency ownership. No
  hidden host arithmetic or aliasing workaround is acceptable.

## Product integration boundary

Product branches, PR #7/#8, and the fixed baseline SHA were not modified or
merged. The only changes on this branch are the research workload generator,
its Makefile target, and these reports. A product integration proposal must
follow a new descriptor/dependency contract review and the missing
fault/backpressure/reset regression.
