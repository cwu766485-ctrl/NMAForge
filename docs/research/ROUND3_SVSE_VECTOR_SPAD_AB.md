# Round 3 SVSE Vector SPAD A/B

## Baseline and boundary

Product baseline SHA: `0492c47d12cd11bcc22be1930da7af77ed870b6e`.
Research branch is based on Round 2 closeout `6596779d`. No product RTL,
dispatcher, or ABI was modified.

The A/B test instantiates the actual `ai_tensor_sfu_core` using product
opcodes `0x34` (Residual I32) and `0x36` (Requant I8), alongside the parameterized
research `ai_streaming_sfu_spad_adapter` (`MAX_LEN=16`). Both use separate
behavioral memory images initialized from identical operands, the same
single-word registered response latency, and the same deterministic ready
stall pattern. Completion is measured from shared start until each DUT's done
event. The test compares every output SPAD word and counts accepted read/write
transactions.

This is an engine-level common-SPAD-model comparison, not a Top/Dispatcher
integration or product workload speedup. Both paths serialize operand reads;
SVSE buffers the full result vector and then writes it back in order.

## Vector behavior

The adapter now supports a parameterized vector length and maximum buffer
depth. For each element it reads A and, for Residual, B; passes the operands
through the one-entry streaming datapath; stores the result in the output
buffer; then begins ordered writeback after all elements compute. It tracks
per-command cycles, accepted reads/writes, request stalls and response waits.
The SPAD request stability assertion remains enabled.

Abort or epoch bump during an accepted read waits for the registered response
and discards it before completion. Abort during writeback preserves the
accepted write prefix. A write accepted on the same edge as abort is counted
and retained because an accepted memory handshake cannot be revoked.

## Results

VCS `V-2023.12-SP1_Full64`, 10 ns clock, 4-element signed vector:

| Opcode | Product cycles | SVSE cycles | Product reads/writes | SVSE reads/writes | SVSE stalls |
|---|---:|---:|---:|---:|---:|
| Residual I32 | 40 | 46 | 8 / 4 | 8 / 4 | 1 request, 16 response-wait cycles |
| Requant I8, shift 5 | 22 | 30 | 4 / 4 | 4 / 4 | 1 request, 8 response-wait cycles |

Both final memory images match word-for-word. Residual signed addition and
Requant arithmetic shift/saturation also match the product SFU arithmetic
implementation exactly. With this buffered architecture, SVSE is 15.0% slower
for Residual and 36.4% slower for Requant on this vector. The additional
buffered phase is not offset by computation overlap in the present prototype.

Fault/lifecycle tests reached nonempty transactions:

```text
SVSE_ABORT_READ_DRAIN_PASS accepted_reads=1 committed_writes=0
SVSE_ABORT_WRITE_PREFIX_PASS committed_prefix=2
SVSE_EPOCH_READ_DRAIN_PASS accepted_reads=1
```

## Reproduction

```sh
cd /tmp/nmaforge-v2-round3-svse
make -C dv/research/dams_svse/sim adapter
make -C dv/research/dams_svse/sim all
```

The adapter test emits `SVSE_VECTOR_AB_PASS`; the standalone scheduler test
emits `DAMS_SVSE_PASS accepted=3 denied=1`.

## Decision and remaining boundary

`SVSE = REWORK_FOR_PRODUCT`. This implementation demonstrates correct
vector read/compute/buffered-write behavior and fault prefix handling, but
does not improve cycles and is not connected to the command processor,
completion writer, compute SPAD mux, real protection bank, or product
scoreboard. The next viable experiment should add legal producer-consumer
forwarding and/or overlap only after its ownership/completion contract is
specified; the current measurements do not justify product integration.

DAMS retains the previously recorded `BLOCKED_BY_CONTROL_CONTRACT` system
boundary. These results do not change the earlier BPF-TE `REJECT_FOR_PRODUCT`
decision and do not claim system-level A/B.
