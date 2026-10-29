# NMAForge verification plan

Status: 2026-10-28 · Product baseline: A10 / ABI v7.4 · Top:
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

**2026-10-28 exact-candidate status:** candidate
`c0832e5c822de1a03f82751d5ff8f831d0addb98` passed detached clean-worktree
real-top seven-engine UVM on seeds `20261025/20261026/20261027`. Each seed
checked 5,256 memory words with zero mismatch, unknown read, stale epoch or
orphan response; focused coverage was 29/30 (`98.96%`), and UVM severity was
`0/0/0`. Supplemental exact-SHA runs passed 25/25 passive-monitor checker
mutations, 45/45 Matrix size cases, and 120/120 Matrix configuration/workload
cases over three seeds. A 16-seed DMA/FP E2E campaign also passed; all five
AXI AR/AW/W payload/burst assertions had real successes and all three
stall-to-accept cover properties matched. The merged top URG contains DUT,
SVA, testbench and UVM, so it is not a DUT-only closure metric.

Matrix FSM remains 15/15 states and 49/53 transitions. The no-prefetch profile
separately hits `ST_MAC→ST_A_REQ`; the two guard/invariant paths still lack
formal unreachable proof. Partial Line WSTRB semantics, broad legal fault ×
phase × engine × Abort/Reset crosses, and approved P0 error/reset contracts
remain open. The 38-row RTM is still 23 PASS-SCOPED, 13 PARTIAL, 2 BLOCKED_SPEC;
CL-DV-v1.0 remains on hold. See the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md),
[Readiness Report](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md), and
[Compute Cluster testplan](COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md).

The exact-candidate Matrix benchmark assumes one-cycle behavioral SPAD and
250 MHz only for normalized GOPS arithmetic; it is not SRAM timing or PPA.
Serial/staged Cluster workload remains 1,239→1,070 cycles (1.158×), and
four-task queued execution remains 1,696→1,137 cycles (1.492×). The report does
not claim direct TinyNPU speedup because workload and memory/timer boundaries
are not matched.

The 2026-10-21 [compute run record](COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-21.md)
and [clean replay record](COMPUTE_CLUSTER_CLEAN_REPLAY_2026-10-26.md) remain
historical evidence. The 86-descriptor Transformer is a fixed-weight functional
test, not a pretrained-model accuracy comparison. Current RTL ASIC PPA remains
unmeasured.

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
combinations, complete Cluster REQ coverage, full LEC/DFT closure, and
post-layout/board evidence. The selected Compute Cluster fixed-SHA manifest has
passed; it does not cover the full A10 workstream.

## Canonical entry points

| Scope | Command |
|---|---|
| Selected five-engine cluster regression | `make -C dv/subsystem/tensor_datapath/sim cluster_regress` |
| Real-top seven-engine Cluster UVM (three seeds) | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_cluster_closeout_multiseed_20261026` |
| Matrix depth/prefetch/cache comparison | `make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=20261025 MATRIX_CONFIG_OUT=/tmp/nmaforge_matrix_config_c0832e5_20261025` (repeat for `20261026/20261027`; see candidate RTM) |
| Transformer top workload | `make -C dv/subsystem/top_smoke/sim ai_transformer` |
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
