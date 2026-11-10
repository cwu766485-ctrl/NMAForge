# Innovation A proposal: bounded tensor-lifetime dataflow

Decision: **A3 DEFERRED pending mapper/partial-sum feasibility review**.
Novelty: **NOT_ESTABLISHED**. This stage proposes a mechanism; it does not add RTL
or claim a new measured CNN speedup. Keep A1 as the current product mapping.

## Baseline and independent ablation

Same trained570,164 useful-MAC CNN, exact weights/input/Golden:
A0 legacy65,429 CMDQ cycles,130,624 read/83,200 write B;
A1 both-fused row-major12,351,64,064/16,640 B. First-fused22,983 is an additional
mapping control. This new replay isolates mapper/opcode choices on unchanged
product RTL; it does not assign all gains to forwarding.

A2 existing elastic forwarding is separately measured on its legal16×16 chain:
producer147 cycles both settings; consumer135→118; consumer SPAD reads512→256 B;
one hit saves16 line reads. Golden, repeated-consumer fallback, tag miss and
abort/reset checks pass. Data state already exists:2×16×128 bits=512 B.
This is **not the full CNN A2 ablation**: trained producer208×64 and consumer
208×16,K64 do not satisfy current fixed16×16 eligibility. Current A2 therefore
cannot be credited with the trained CNN result.

## Hypothesis and trace-derived opportunity

Adaptive tile lifetime/ownership, selected by mapper shape/dependency knowledge,
could retain just-produced quantized activation tiles and deliver the next
Matrix consumer's A operands without a redundant SPAD read. Preserve all required
producer writes and exact fused shift/ReLU/sat8 order.

The actual ACT1 region is208×64=13,312 B, with832 accepted16-byte consumer reads
in every measured mapping. Maximum removable traffic is13,312 B, **20.78% of
current64,064 read B**;16,640 write B remains. This is a whole-tensor ideal bound,
not a 512 B cache prediction. Zero extra-cycle ideal cache access is unproven;
writeback5,200 clocks includes control and cannot all be removed.

## Proposed ownership contract

A3 would require a registered tile lease:
`{producer command epoch, tensor base, logical/padded extents, layout,
row tile, channel tile, quantization format, committed-line mask, consumer}`.
Producer writes remain ordinary SPAD commits. A lease becomes eligible only
when the entire required tile has committed and the explicit dependency has
completed. Consumer owns one immutable lease until its A copy is acknowledged;
no producer may overwrite that bank. Hit data is registered into existing operand
buffers; misses use ordinary arbiter reads. Duplicated or delayed responses must
never satisfy a different lease/epoch. No SPAD admission bypass or new SRAM port.

Mapper selects only exact shape/layout/quantization matches, nonaliasing tensor
lifetimes and a producer→consumer event schedule. Existing command format remains
unchanged unless a later review explicitly allocates a backward-compatible
opt-in contract. It must reject in-place output/input collision, external writers,
partial tiles without full masks and unsupported parallel consumers. Completion
still follows visible writes. Reset, abort, fault, watchdog and partial capture
clear all validity; a capture is never reconstructed from an incomplete mask.
All overlapping host/DMA/other-engine writes invalidate or disqualify a lease.

Bank capacity/collision policy is bounded two-bank ping-pong: at most two256 B
16×16 INT8 tiles, never evict a consumed bank; drop speculative capture on
collision and fall back to SPAD. This policy covers only the scheduled tile
working set. It cannot retain all four K16 tiles of a CNN64-channel producer at
once. Retaining all four would require1 KiB for one row tile and is a separate
cost proposal, not a free extension of the current cache.

## Critical unresolved partial-sum problem

Splitting the two trained GEMMs into ordinary tiny descriptors is not a legal
streaming transformation by itself: each consumer descriptor clears its array
accumulators. The64-channel consumer needs four K16 contributions in the same
accumulator lifetime before final shift/saturation. Applying postprocess to each
partial sum changes the integer result. A legal implementation needs internal
consumer K-loop continuation/accumulator ownership, or a proven alternative
schedule/storage contract. It must also handle producer63 useful+padding channel
and consumer10 useful+padding classes exactly.

Therefore first build a mapper-level schedule/lifetime trace with existing
hardware limits and prove all partial sums and visible intermediate tensors.
Only if that predicts a concrete full-CNN benefit beyond A1/A2 should hardware
A3 be reviewed. If512 B cannot deliver the needed live set without throughput
loss, reject A3 for this graph. Do not silently increase cache capacity or ports.

## Expected cost and validation before implementation

Initial cost envelope: reuse512 B data state, add two base/epoch/extent/layout
lease records and32 line-valid bits, small row/channel counters, indexed128-bit
registered data selection and ownership FSM. Rough metadata envelope≤256 bits,
subject to bit allocation review; zero new MACs/SRAM ports. This is not a cell,
area or timing estimate. Increasing to1 KiB or adding general dependency search
is outside this proposal.

Required later ablation: A0/A1/A2/A3 on eligible microchains and the complete
trained CNN, same model/Golden, CMDQ and all accepted bytes, occupancy and hit/miss
rate, actual MAC active, control/preload/readback boundaries. A3 must improve
full CNN latency after additional descriptors/control, or be rejected. Verify
unaligned/partial tile fallback, all writers, repeated consumers, reset/abort/
parity/protection/backpressure and accumulator continuation. Independent full
memory-image Golden stays unchanged; no dropped INT32 legacy outputs.

Synthesis/STA must assess tag/decode→mux→operand-register paths and fanout at
400 MHz/2.5 ns. No current A3 RTL, synthesis, PPA or functional evidence exists.
[Prior-art comparison](PRIOR_ART_COMPARISON.md) explains why tiling, forwarding
and lifetime-based reuse are not by themselves a novel contribution.
