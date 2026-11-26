# Round 3 DAMS Product Contract Audit

Date: 2026-11-15  
Research RTL: `6596779de2ec4f502a0253dedd4695129b775b05`  
Product contract reviewed: `docs/spec/COMPUTE_CLUSTER_SPEC_ZH.md` v1.8 in this tree

## Decision

Do not replace or bypass the product dispatcher, shared SPAD admission, or
Matrix/CNM atomic interfaces with the current `ai_dams_scheduler` prototype.
The product already supports real cross-engine overlap. A DAMS candidate can
proceed only as a bounded, non-ABI-changing ownership/dependency observer and
then as an A/B scheduler policy evaluated on legal workloads. It must show
incremental benefit over the existing dispatcher before product RTL work is
proposed.

## Existing Product Contract

| Contract | RTL / SPEC evidence | Consequence for DAMS |
|---|---|---|
| Different engines may overlap; one active slot per engine | `rtl/control/queue/ai_parallel_compute_dispatcher.v:136-145, 395-447`; `COMPUTE_CLUSTER_SPEC_ZH.md` REQ-PC-001/002 | DAMS cannot claim the first cross-engine overlap as its gain. |
| Descriptors are fetched and considered in CMDQ order; a busy target engine blocks the head descriptor | `ai_parallel_compute_dispatcher.v:205-229, 513-536`; REQ-PC-003 | An alternative policy must preserve head order and cannot skip a blocked descriptor. |
| Results may complete out of order but are retained by FIFO slot and retire in CMDQ order | `ai_parallel_compute_dispatcher.v:137-145, 395-447`; REQ-PC-004/005 | Any added transaction identity must map to the existing FIFO slot/task ID, and must preserve ordered retirement. |
| The seven ordinary compute requesters share one CORE admission and owner response path | `rtl/top/fabric/compute/ai_compute_spad_mux.v:42-119`; REQ-PC-006 | There is one accepted ordinary scalar operation at a time; a bank-mask model does not represent this interface. |
| Matrix banked/line and CNM four-lane paths remain distinct | `rtl/memory/ai_spad_arbiter.v:67-105`; REQ-PC-007 | Never fold Matrix/CNM requests into the ordinary scalar mux for an A/B comparison. Preserve their atomic admission and response tags. |
| Cross-descriptor address hazards are software-owned | `COMPUTE_CLUSTER_SPEC_ZH.md` REQ-PC-008 | Hardware cannot infer legal dependencies from engine/bank masks alone. A legal workload must provide valid regions/lifetimes or an explicit dependency contract. |
| Abort drains accepted work; reset coordination is epoch/fabric-scoped | REQ-PC-009/010 and OPEN-CL-003 | An observer must track accepted requests/responses and commit prefix through abort/reset; it cannot free ownership merely because a local epoch counter advanced. |

Dispatcher startup is gated by `parallel_scheduler_ready` in the top, but that
does not serialize descriptors after the parallel queue is active. Once active,
`desc_engine_ready` controls dispatch, allowing already-running work on a
different engine to continue while the next CMDQ descriptor is considered.

## Current Research Prototype Boundary

`rtl/research/ai_dams_scheduler.sv` is a bounded reservation model, not a
product scheduler adapter:

- `issue_dep_mask` is checked against an engine-level `complete_r` bitmap; it
  does not name a producer transaction or consumer edge.
- `issue_bank_mask` reserves whole banks from issue acceptance until `done_tag`;
  it has no byte-address range, read/write intent, stride/shape, live range,
  accepted SPAD event, or response-owner record.
- `done_tag` matching does not enforce uniqueness, transaction epoch, dispatch
  state, or exactly one completion.
- `epoch_bump`/`fault_abort` immediately clear all reservations and dependency
  state; this is not an accepted-request drain protocol.
- `denied_count` increments on every valid cycle without `issue_ready`, so it
  combines resource conflict, dependency wait, and ordinary backpressure.
- The prototype's disjoint-bank admission may reject legal same-bank
  arbitration or claim admission that the product interface cannot provide.

The isolated run `make -C dv/research/dams_svse/sim all` passes with Synopsys
VCS `V-2023.12-SP1_Full64` (`DAMS_SVSE_PASS accepted=3 denied=1`). This is
prototype-level compile/simulation evidence only. It does not test a real
Compute Engine, product SPAD, descriptor lifecycle, numerical output image,
fault/abort drain, or product-level performance.

## Required Ownership Record for a Valid Candidate

An observer or later policy prototype must correlate, at minimum:

1. CMDQ sequence/index, task ID, opcode, engine, descriptor source/destination
   regions, shape/stride, and explicit wait/signal/clear dependencies.
2. Existing engine active slot and dispatcher FIFO slot; accepted launch,
   engine completion, completion record, and ordered retirement sequence.
3. For each actual SPAD interface, accepted request owner, address, read/write,
   bank/lane or line/WSTRB type, returned response owner/tag, parity/protection
   result, and any outstanding count.
4. For writes, the accepted/committed prefix before error, abort, or reset.
5. Reset/abort epoch and the condition proving the prior epoch has drained.

The observer must not alter request timing or change the legacy descriptor,
completion, protection, parity, or error-priority behavior.

## Next Gate 4 Experiment

Use one legal two-descriptor schedule on the real product top and preserve the
existing dispatcher as baseline. Select two different engines that are already
supported to overlap, use disjoint write regions, and retain the exact same
CMDQ order, descriptor bytes, Golden, SPAD image, and completion endpoint.
Capture passive traces first; only then compare an alternative issue policy.

Report these separately:

- time with multiple engines busy;
- time with two or more simultaneously eligible, dependency-ready descriptors;
- cycles blocked by engine occupancy, shared scalar SPAD admission, Matrix/CNM
  atomic bank admission, descriptor dependencies, and CPLQ retirement;
- accepted requests and responses by interface/owner, plus write commit prefix;
- total cycles and exact Golden/completion match.

Do not count a bank-mask-only test as system overlap. If no additional legal
issue opportunity remains beyond current CMDQ scheduling, record DAMS as
`NO_INCREMENTAL_OPPORTUNITY` and stop scheduler RTL work. Any new dependency
ABI, cross-descriptor address lock, relaxed CMDQ ordering, or changed Matrix/CNM
admission is a separate SPEC/design review, outside this Gate 4 prototype.

## Evidence Status

| Item | Status |
|---|---|
| Product dispatcher and ownership contract audited | PASS, source review |
| Existing DAMS/SVSE isolated smoke | PASS, VCS prototype scope only |
| Transaction-causality graph connected to product CMDQ/SPAD | NOT_IMPLEMENTED |
| Passive product-top DAMS trace | NOT_RUN |
| Product A/B versus current dispatcher | NOT_RUN |
| Product RTL or ABI change | NONE |
