# NMAForge verification plan

Status: 2026-10-23 · Product baseline: A10 / ABI v7.4 · Top:
`rtl/top/ai_accel_top.v`

This document defines the verification layers and acceptance rules. The
[A10 RTM](A10_DV_RTM.md) owns current A10 workstream status and requirement
evidence; the [verification matrix](../../dv/VERIFICATION_MATRIX.md) owns
block/subsystem acceptance rows. Do not copy dated run logs into this plan.

## Acceptance rules

- Verify externally visible behavior against [SPEC_ZH.md](../spec/SPEC_ZH.md)
  and module ownership against [ARCHITECTURE.md](../architecture/ARCHITECTURE.md).
- Each result records command, source identity, tool/version, seed, exit status,
  log/coverage location, and whether it is dirty-worktree, clean-SHA,
  pre-layout, post-route, or board evidence.
- A test pass closes only its tested cases. Functional coverage, assertions,
  code coverage, formal proof, LEC, DFT, and PPA are separate evidence types.
- Keep uncovered bins visible. Disposition requires a justified test, proof, or
  documented waiver; tool/license failure is not a pass or an RTL failure.
- After RTL changes, run the focused target and `ai_smoke`. Queue, DMA,
  scratchpad, top, and source-list changes also require the seeded top run when
  the EDA environment is available.

## Verification layers

| Layer | Scope | Exit evidence |
|---|---|---|
| Specification and baseline | ABI, descriptor validation, source lists, fixed-point and floating-point contracts | SPEC/header consistency, traceability rows, reproducible baseline |
| Block | AXI-Lite, DMA, command processor, SPAD arbiter and compute engines | Independent scoreboard, protocol assertions, boundary/error cases, selected functional coverage |
| Subsystem | DMA–SPAD–compute contention, queues/completion, tile pipeline | Shared-resource ownership, back-pressure, error drain and recovery |
| Top | `ai_accel_top`, AXI-Lite software model, DDR model, command/completion path | Observable result/status/completion, reset/abort behavior, seeded workload |
| Sign-off support | Formal, lint/CDC/RDC, LEC, DFT, synthesis, STA/PPA and board | Tool-specific constraints, reviewed warnings/residuals, reproducible artifacts |

## Current status and next closure work

The five compute verification groups have selected passing functional suites.
Their raw DUT code coverage is partial; per-engine figures and gaps are in the
[compute-engine status page](COMPUTE_ENGINE_STATUS.md). The 2026-10-21
[compute run record](COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-21.md) contains
commands and detailed evidence.

The A10 workstreams G0/V1–V5 remain tracked separately in the RTM. Full-domain
FP parity-to-`ST_WRITE` exclusion is now proven for all nonzero 16-bit lengths
under the documented legal-input contract. Cutoff validity is separately
proven under the response-index bound; the progress-bound proof and the
unassisted combined lifecycle aggregate remain open. The top now allows one active
command per compute engine, with CMDQ-order completion retirement. Directed
Matrix+SFU overlap, same-engine serialization, response routing, ordered
completion, and abort/drain pass; exhaustive engine-pair coverage and formal
properties for the new dispatcher remain open. Other open items include
residual DUT condition/toggle/code coverage, broader fault × abort × reset
combinations, one fixed-SHA replay manifest, full LEC/DFT closure, and
post-layout/board evidence.

## Canonical entry points

| Scope | Command |
|---|---|
| Selected five-engine cluster regression | `make -C dv/subsystem/tensor_datapath/sim cluster_regress` |
| Top smoke | `make -C dv/subsystem/top_smoke/sim ai_smoke` |
| Seeded top regression | `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345` |
| Command processor UVM | `make -C dv/block/command_processor/uvm regress` |
| Control UVM | `make -C dv/block/control/sim uvm_regress` |
| DMA UVM | `make -C dv/block/dma/sim uvm_regress` |
| SpyGlass | `cd dv/spyglass && ./run_spyglass_a8.sh {lint|cdc|rdc|all}` |
| VC Formal compute-cluster serial dispatch | `make -C dv/subsystem/tensor_datapath/formal run` |

Use private PDK/SRAM inputs only from the approved EDA environment. Keep
generated simulator, coverage, and implementation output outside the public
source tree. The A10 RTM and owning reports document the exact status and
limitations for each flow.

## Status terminology

- **Pass:** the named target completed and its checked expectations matched.
- **Partial:** selected checks passed, with listed requirements or coverage
  still open.
- **Blocked:** the required tool or environment did not permit a result.
- **Closed:** all stated acceptance criteria have reproducible evidence and
  residuals are dispositioned. A green smoke test alone never means closed.

The A10 RTM also has G0/V1–V5 workstream labels. Those are not the verification
layer names used above.
