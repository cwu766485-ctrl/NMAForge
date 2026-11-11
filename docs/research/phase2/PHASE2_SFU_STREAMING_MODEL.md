# Phase 2 — protection-preserving vectorized SFU scheduling model

Decision: **MODEL_BENEFIT_SHOWN_NOT_RTL_ADMITTED_PENDING_FAULT_TIMING_REVIEW**.
This is Gate 2's standalone transaction model. No second product RTL change
has been implemented. Gains below are conditional estimates, not simulation
measurements of a streaming engine.

## Evidence and scope

The model consumes paired Phase 1/LN32 candidate H32 cycle and accepted-memory
traces, plus the same descriptor and Golden images. It pairs every accepted
read with its actual response, by owner and FIFO order, and checks the sampled
response is exactly two edges later. Replaying the current scalar requant FSM
under actual other-client service slots reproduces every one of the 224
persistent-decode requant descriptor busy windows exactly. All earlier
prefill, other SFU operations, Matrix, KV and dispatch cycles stay fixed in
this incremental estimate.

Within these descriptors consecutive accepted read deltas are 3 cycles
(16,896 occurrences), 4 (7,168), or 5 (288). Two edges are real registered SRAM
latency; subsequent issue gaps also reflect scalar sequencing, packed-word
writeback and actual port arbitration. They are not evidence of physical SRAM
bank conflicts. `descriptors.csv` separates observed blocked service slots
from modeled no-contention operation; other clients retain their recorded
slot schedule. This is not a closed-loop model of a changed round-robin arbiter.

## One bounded schedule

Use two groups of four raw INT32 words, two packed output words, at most four
read ownership tags, group valid/fault masks and epoch/control metadata.
Issue the next input when its group has space, the existing scalar4B port is
available, and tag capacity permits. Every input still traverses the normal
SPAD authorization/parity path. Responses identify their command/group/word;
a register separates response capture/selection from requant arithmetic.
Commit complete groups in original order through the same scalar write port.
Writes have priority when the head group is ready. No word is forwarded from
Matrix and the required producer INT32 tensor remains written to SRAM.

At the observed two-edge response latency, this schedule needs at most two
outstanding reads, within a conservative four-tag budget. There are at most
two active groups. Packed layout address generation follows the original
linear/tile-A contract; unpacked mode uses single-element groups. The model
recomputes signed shift, saturation and packing from original INT32 producer
Golden and checks every modeled output. Input/output alias requires fallback;
no shortening of intermediate tensor lifetime is assumed.

Dependencies that cannot be overlapped include data readiness after read
response, per-element arithmetic, all-four-byte readiness before packed
write, and ordered output/fault retirement. Independent groups permit
read/compute overlap. The read response latency is retained, not erased.
LN mean/variance reductions, gamma/beta dependencies and inverse sqrt are
outside this one-candidate requant model.

## Lower bounds and prediction

| Packed descriptor | Current / modeled busy cycles | Mandatory scalar service lower bound | No-contention model |
|---|---:|---:|---:|
| 64 elements, representative descriptor with 16 blocked slots | 211 / 100 | 64 reads +16 writes =80 | 84 |
| 128 elements | Per-descriptor values in CSV | 128 reads +32 writes =160 | 164 |

The extra four cycles in the uncontended models retain dependency/pipeline
fill, drain and DONE overhead. Across224 descriptors the mandatory read/write
service lower bound is32,256 cycles. Current requant busy is82,144; modeled
busy is38,640, saving43,504 cycles with the trace's competing service slots.

| H32 eight-token window | Measured starting cycles | Modeled resulting cycles | Predicted reduction |
|---|---:|---:|---:|
| Phase 1, before LN32 | 367,051 | 323,547 | 11.8523% |
| Incremental after implemented LN32 | 350,155 | 306,651 | 12.4242% |

The latter is38,331.375 predicted cycles/token. It must not be added to a
measured speedup claim or presented as current product performance.

Sensitivity for128 packed elements without competing service:

| Outstanding budget | 2-edge response | 3-edge response | 4-edge response |
|---|---:|---:|---:|
| 1 | 291 | 388 | 516 |
| 2 | 164 | 228 | 261 |
| 4 | 164 | 164 | 180 |

These are model sensitivities; current SRAM stays at its observed geometry
and latency. An enlarged budget alone is not proposed as a product change.

## Bounded cost and correctness admission

Estimated additional state: raw groups256bits + packed outputs64 + four
20-bit read tags80 + group metadata54 + epoch/control64 = **518bits**.
Muxes comprise registered raw-word selection, group-output selection, byte
packing enables and existing requant arithmetic reuse. This excludes synthesis
mapping/retiming and has no measured area/Fmax basis. No new SRAM port, MAC,
large buffer or generalized engine is modeled. Any eventual implementation
must keep response selection off a direct SPAD-response-to-arithmetic path.

The abstract fault-invariant model covers358 read-parity, write-protection,
reset and abort cases, checks ordered accepted prefixes, drains/discards owned
tags, produces one terminal event except reset, and preserves original writes.
It is deliberately separate from the timing simulator and does **not** prove
product fault equivalence, watchdog timing, physical protection races or RTL
completion correctness.

Remaining architecture obligations prevent RTL admission:

- Earlier reads can observe a different Host/DMA write, parity mutation or
  permission state. Retaining all checks does not by itself establish the
  existing fault-observation contract under the changed schedule.
- An explicit ownership/epoch contract is required for permissions and source
  writes during a command; no relaxed fault mode is assumed or authorized.
- Prefetched errors must retire in original order; no younger output may
  escape after an older fault. Reset/abort/fault must drain/discard old tags
  and preserve exactly-once completion under late responses.
- The trace-conditioned blocked slots need replacement by closed-loop
  arbitration and producer/consumer/backpressure replay before a gain claim.
- Alias detection/fallback and hardware cost/path checks remain to be proved.

Therefore the model demonstrates sufficient throughput potential for an
architecture discussion, but is **not permission to implement** streaming.
The rejected A3/B2 transparent cache bypass remains rejected. No software ABI,
protection mode or SRAM checking behavior was changed.

Reproduce with `streaming_model.py` commands in the linked tools README.
Source/workload hashes, raw paired traces, per-descriptor results, sample cycle
schedule, sensitivity and fault-model cases are archived under
`benchmark/research/phase2/`. Stop after Gate2.
