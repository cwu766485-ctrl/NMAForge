# Architecture Innovation A–E Final Review

## Common baseline

Product evidence is bound to `candidate/frontend-closeout`
(`f919bb787dab1a4e3bef44b5308ead56d6e77b72`) and its published R250 replay
source identities. Research evidence is bound separately to
`feat/shape-adaptive-gemv-v2` (`c43cfde3b2d4040467c63737148a08241672b374`).
No research RTL was merged into the product candidate, and no ABI or SPAD
geometry was changed.

## Decisions

| Direction | Evidence | Stage 4 |
|---|---|---|
| A Scheduler | No legal bank-disjoint co-issue; compute/DMA gate prevents overlap; existing parallel speedup is not scheduler attribution. | **DEFER** |
| B Shape Adaptive | 27 real-SPAD paired cases, `1.0290x` geometric mean; model-only prefetch overstates benefit; no held-out/double-buffer/product endpoint. | **DEFER** |
| C SFU | Research wait profile is non-product; candidate already has accelerate/special-length paths; product phase attribution missing. | **REWORK** |
| D Sparsity | Frozen trained CNN: 1.39% FC weight zeros, 0% all-zero 4/8/16 blocks; activation 4-block zeros 9.33%; metadata cost not justified. | **REJECT** |
| E Precision | Existing INT8 and BF16/FP16 paths are separately specified and verified; no shared-MAC demand or legal PPA evidence. | **DEFER** |

No direction qualifies for product RTL promotion. C is the only direction with
a justified next experiment, and that experiment starts with product-candidate
profiling rather than new hardware.

## Residual implementation and DV boundary

The latest candidate replay passes its declared seven-engine functional groups,
Top Smoke, mixed E2E, and named mutation checks, but raw hierarchy coverage is
not complete and the RTM remains `24 PASS-SCOPED / 14 PARTIAL`; `CL-DV-v1.0`
is **HOLD**. Open items include broader fault/phase/reset/backpressure crosses,
external-fabric qualification, residual FSM/code coverage, advanced CDC/RDC,
and legal SRAM-macro implementation evidence.

The next work item is therefore Compute Cluster DV Closure on the product
candidate, with no innovation RTL. Closure must preserve the existing UVM
agents/reference models and add only the missing monitors, crosses, mutation
checks, and exact-SHA evidence needed to resolve the RTM partial rows.
