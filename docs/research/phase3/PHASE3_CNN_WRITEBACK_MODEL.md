# Phase 3 Gate 2 — trained CNN writeback model

**FEASIBLE_MODEL_ONLY_NO_RTL_THIS_ROUND.** Prefer overlapping the existing
four postprocess lanes with a second ordered 128-bit buffer. Model predicts
12,351 → 11,376 CMDQ cycles (975 saved, 7.8941% cycle reduction; 1.0857×).
No modified product RTL, measured candidate cycle result or freeze claim.
Baseline merge `c93ea144713d5fafe2e8a5509029927cd6859e75`.

## What the 5,200 cycles actually do

Source: `rtl/compute/matrix/ai_tensor_matrix_core.v`, especially ST_WRITE,
`fused_word_current`, `fused_line_buffer_r`, `fused_commit_pending_r`,
`fused_linearized_full_row` and `output_write_accepted`.
Fixed 570,164 useful-MAC trained CNN, current both-fused 0x53 row-major mode;
independent model Golden and original bias/shift/ReLU/saturation/requant retained.

The real Top trace contains 65 writeback windows. Each is 80 cycles:
64 packing edges and 16 **already coalesced** accepted 16 B line writes.
Four existing postprocess functions generate four quantized bytes/a packed
32-bit word each edge. Four packing edges fill the 128-bit register, then the
FSM spends an edge committing that line. Accepted write offsets are exactly
4,9,14,...,79 in every tile. There are zero write-arbitration waits in these
windows. Thus 5,200 = 4,160 **real arithmetic/packing work** + 1,040 accepted
commits. The 4,160 must not be called wholly removable control bubbles.

All line writes use the same 16 B-aligned address, bank mask15, WSTRBffff,
order and data as the original. [cnn_transactions.csv](../../../benchmark/research/phase3/model/cnn_transactions.csv)
records 1,040 original and retimed transactions with independently checked
Golden 128-bit payloads. Output traffic remains 16,640 B. The actual Top
independent CNN verifier checks the materialized intermediates and outputs;
the timing model retimes that Golden, not a newly implemented arithmetic engine.

## Minimal overlap and ablation

Use two 128-bit output registers as an ordered ping-pong FIFO. Keep the older
completed line stable until its protected write admission. While it commits,
pack the next line into the other register using the same four arithmetic lanes.
Do not mutate the offered address/data/mask under backpressure. Drain both before
ST_NEXT, any array clear or accumulator overwrite. This phase assumes no overlap
with a subsequent tile and does not require an accumulator snapshot.

One tile becomes 64 packing cycles + one final drain cycle = 65, saving 15.
Across 65 tiles: 5,200 → 4,225, saving 975, **not** 1,040. The 65 final drains
cannot be overlapped with future work under the chosen lifetime barrier.
All non-writeback cycles remain 7,151 in the projection. Existing 0x53 fusion,
requant math, row-major layout and 16 B coalescing are reused, not reinvented.

| Postprocess lanes | Line buffers | Modeled writeback | Projected full CMDQ | Saved | Reduction | Added arithmetic lanes / data bits |
|---:|---:|---:|---:|---:|---:|---|
|4 current|1 current|5,200|12,351|0|0%|0 / 0|
|4|2 preferred|4,225|11,376|975|7.8941%|0 / 128|
|8|1|3,120|10,271|2,080|16.8407%|4 / 0|
|8|2|2,145|9,296|3,055|24.7348%|4 / 128|
|16|1|2,080|9,231|3,120|25.2611%|12 / 0|
|16|2|1,105|8,256|4,095|33.1552%|12 / 128|

Wider variants pay replicated bias/add/shift/clamp/quantization and accumulator
selection; these are not free and are not recommended by default. All rows are
transaction-model results, without closed-loop changed Top arbitration or
candidate RTL Golden. The 4-lane baseline model exactly matches all 65 real
writeback windows. No change to Matrix's 256 MAC or any SRAM port is proposed.

## Bounded state and fault obligations

Preferred new data storage is exactly one extra 128-bit line register (16 B),
not a new SRAM. Example metadata allocation: two addresses64, two enables2,
two 3-bit progress counters6, read/write selectors2, count2, shared epoch16,
and 16 bits of flags/control = 108 metadata bits; some replace existing counters.
Total illustrative new budget ≤236 bits before implementation choices, separate
from combinational address increment and a registered 2:1 line-data selection.
This is not a netlist flop count. No new arithmetic lane is required. A finite
epoch alone is not sufficient: pending requests must drain before reuse.

Model checks 1,560 deterministic stall/fault/abort/reset cases: eight seeded
backpressure patterns, each with 17 protection-at-line cases (including no fault),
89 abort cut points and 89 reset cut points. It preserves ordered offered lines,
stable stalled payload identity, committed prefix, and suppresses younger writes
on a denied head. Abort/reset discard uncommitted entries and stop old commits.
Time-based abort at equal wall-clock offsets may cut different prefixes after
optimization; no false same-wall-clock-prefix equivalence is claimed.

These are abstract FIFO invariants, **not** validation of product RTL fault,
reset/watchdog priority or exactly-once descriptor completion. A later RTL change
must retain authorization at original write admission, preserve accepted writes
on fault, drain/suppress old epoch responses as applicable, maintain `result`/
`element_count` and row/column pointer semantics, and enter completion only after
the last accepted write. It must test legal boundary rows, partial tiles,
line/scalar fallback, denied first/middle/final line, random backpressure,
abort/reset/watchdog and full CNN/H16/H32 regressions. No read is cancelled, so
there is no A3/B2 parity-bypass mechanism, but that fact does not prove lifecycle
correctness by itself.

## Timing, prior art and decision

Existing accumulator select → postprocess → 32-bit word register remains a
potential path. Add a registered head selection for the line port; avoid coupling
SPAD ready/protection through FIFO occupancy into the entire postprocess chain.
Packing/committing simultaneously must not increase the response critical path.
No mapped synthesis, SRAM macro timing, 400 MHz or area result was obtained.

Ping-pong buffering and decoupled write queues are established techniques. This
would be a measured implementation improvement if verified, not yet evidence
of independent research novelty. The current work establishes removable work
and a small candidate for the next decision; the user's stop-after-Gates0–2
instruction takes precedence over automatically starting that implementation.
