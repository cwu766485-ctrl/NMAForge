# Phase C — one combination: Matrix INT32 → Requant

Boundary review only, as required by this plan's execution stop rule. Candidate
is a producer Matrix INT32 tensor consumed by Requant; the existing0x53 fused
epilogue is prior functionality and must not be presented as a new innovation.

Legacy materializes INT32, then consumer performs actual authorized/parity-checked
reads before requantizing with existing rounding/saturation. Transparent forwarding
would eliminate those reads and potentially hide corruption or permission revoke.
A correct cached value cannot replace an architectural check. Retaining the writes
alone does not retain fault prefix or Host/DMA read-time observations.

For a32-element row the naive opportunity is128B of consumer reads and associated
scalar issue/response overhead, not a proven full-H32 cycle saving. The single
scheduler admission and producer/consumer descriptor barriers still apply. Keeping
all original checks forfeits most traffic gain. No arithmetic reordering or removal
of INT32 output is admitted.

An explicit ownership/fence mode would need enforceable blocks for Host,Debug,DMA
and other engines plus permission updates, precise lease acquisition/release,
read-time parity/error handling,ordered retirement,epoch drain and exactly-once
completion. It changes software-visible access/fault timing and needs a separate
SPEC review; a boolean software promise cannot enforce it. No new mode/ABI or
SFU RTL is introduced. Prior real parity-prefix/cross-region tests were rerun via
phase3/run_review.sh, and independent LN32 directed checks remain available.

Decision: REJECT transparent Matrix→Requant fusion under Legacy. No ≥5% H32
claim. Stop here rather than implement an unreviewed mode; existing H16/CNN/SFU
algorithms are untouched. This does not establish originality beyond known operator
fusion/compiler mapping prior art.
