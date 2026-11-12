# Milestone 3 — Safe SFU Architecture Study

## Baseline attribution

The qualified H32 persistent decode window is 350,155–350,189 cycles depending
on the replay fixture. The current exclusive attribution is approximately
273,699 SFU cycles: 67,952 fetch issue, 134,144 fetch response, 29,456
arithmetic/control, 15,093 pipeline wait, 26,640 writeback and 448 completion.
These counters are mutually exclusive; overlapping Busy counters are not added.

## Candidate A: non-speculative scheduling

The profile identifies fetch response and scalar FSM sequencing as the largest
local opportunity. Any change must preserve every accepted read, authorization,
parity check, response owner, output prefix and intermediate INT32 tensor. The
current traces do not prove that a response wait is removable: the SFU has true
operand dependencies and the single SPAD admission point. No product SFU RTL was
changed.

## Candidate B: safe streaming

`tools/benchmark/phase4/sfu_protocol_model.py` was rerun and passed 196 bounded
immutable/disjoint cases plus 279 recovery cases. It still rejects unrestricted
speculation after the two architectural counterexamples:

- a Host write between scalar reads changes the serial observation;
- permission revoke between reads must fault the later access, while a prefetched
  response would incorrectly succeed.

Ordered retirement repairs output order but cannot repair these observations.
An immutable operand lease or software-visible ownership contract would be a
spec change, not an internal optimization. It must cover Host/DMA/Debug writes,
permission changes, parity, response ownership, abort/reset/watchdog drain and
exactly-once completion. No lease RTL is implemented.

Decision: **REJECT unrestricted streaming; REWORK non-speculative scheduling**.
The 20% H32 target is not demonstrated and no model-only speedup is claimed.
