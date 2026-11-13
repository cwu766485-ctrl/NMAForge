# Bank-Parallel, Fault-Precise Tensor Execution (BPF-TE)

Status: research RTL prototype, isolated from the product integration path  
Base candidate: `f919bb787dab1a4e3bef44b5308ead56d6e77b72` (PR #7 head)

## Contract

BPF-TE presents four independently decoded bank request slots to a single
clocked fabric. At most one slot is admitted per physical bank per cycle. Two
slots targeting different banks may therefore be accepted in the same cycle;
two slots targeting one bank are resolved by a rotating round-robin pointer.
The request payload is held by the requester until its per-slot `req_ready`
is observed.

Each accepted read creates a bank-local, two-stage response tag containing
owner, tile, and epoch. The bank port returns data and error for the accepted
read after the same two cycles. A response is visible only when the returned
bank valid is asserted and its epoch matches the current epoch. Writes have no
response. `epoch_bump` flushes all in-flight tags, increments the epoch, and
prevents stale data or errors from reaching a new transaction.

`req_accept`, `req_denied`, `req_backpressure`, bank request valid, response
owner, response bank, and response epoch are observable for a passive monitor.
Protection and parity errors are carried as a single response error bit; the
prototype does not bypass the existing protection checker.

## Boundaries

The prototype owns admission, bank decode, fairness, response tagging, and
epoch filtering. A real SRAM implementation remains responsible for one
Port-B operation per bank and for returning `bank_rsp_*` exactly two cycles
after an accepted read. This explicit per-bank interface is required; wiring
the arbiter back into the legacy single global SPAD transaction would not be a
bank-parallel implementation.

Matrix line and CNM four-lane operations are legal only when their lane
addresses decode to the intended distinct banks. The prototype's four request
slots are the primitive used to test those transactions; a future adapter must
atomically reserve all required lanes and expose one tile ownership token.
The current product ABI, opcodes, protection regions, and completion queue are
unchanged. DMA/compute overlap mode is not implemented.

## Invariants

1. `req_ready[s]` is asserted only for the selected slot and its bank.
2. A bank has no more than one accepted request in a cycle.
3. A read response preserves the accepted slot's owner, bank, tile, and epoch.
4. An old epoch cannot generate a response after `epoch_bump`.
5. Fairness pointer advances after each admitted request, including writes.
6. Requesters retain a denied payload; no internal requester state is mutated.

The prototype is not yet a product replacement. H0/H1 measurements and PPA
evidence are required before a product integration proposal.
