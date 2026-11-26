# Stage C — Safe scheduling review

Decision: **NO_RTL_EXPERIMENT_ADMITTED**. Product RTL and ABI are unchanged;
added data flops, buffers, muxes, metadata bits and SRAM ports are all zero.
Stage C introduces a completed-batch lifetime allocator in the H32 mapper and
retains existing outstanding-read/prefetch FSM behavior. No new performance
speedup is credited to an unimplemented RTL schedule.

## Evidence and bottleneck

Fresh VCS Matrix block ablation uses the existing randomized-response harness,
seed20261110, same fixture operands per configuration, depth2/4 × prefetch0/1 ×
A-cache0/1.40/40 exact Golden cases pass. This is **controller + its behavioral
memory model**, not an SRAM macro or common Tiny controller environment.

| Shape M×N×K |d2/p0/c0 cycles / line reads|d4/p1/c1 cycles / line reads|
|---|---:|---:|
|4×4×32|108 /16|77 /16|
|8×8×32|142 /32|101 /32|
|16×16×32|265 /64|218 /64|
|16×32×32|516 /128|393 /96|
|32×32×64|1,711 /512|1,172 /384|

Product0x52 GEMV four-way B-cache/prefetch replay adds16 exact Golden rows,
M8/M16,N16,K19/K65. With B-cache/prefetch both off versus both on:
M8K19 207→158cycles (54→35reads), M8K65 562→383 (170→106),
M16K19 407→275 (108→51), M16K65 1092→660 (340→148).
However M16K65 with B-cache on **prefetch off is625cycles**, faster than660
with prefetch on in this responder trace. Thus enabling more overlap is not
universally faster; no blanket prefetch improvement claim is made. Existing
B-cache/prefetch effects are scoped to this block responder and operands.

These are existing parameter effects, not new RTL changes. Archived CSV includes
all eight settings and admission stalls. A-cache reduces repeated A reads for
multiple N tiles; next-K prefetch overlaps normal authorized SRAM responses with
compute. The existing intra-command operand retention policy is unchanged.
It is not permission to introduce new cross-descriptor bypasses.

Final H32 decode exclusive cycles sum367,788: Matrix41,360, SFU291,332,
KV20,224, control14,872. Accepted reads546,816B/writes227,840B. Banked admission
stall2,464, scalar admission stall1,568 and line admission stall0; these sampled
stall counters may overlap busy buckets and must **not** be added as exclusive
cycles. An aligned four-bank line accesses all four banks: admission stalls alone
do not prove a physical bank conflict or benefit from shifting a tensor base.

SFU opcode-exclusive clocks: Residual43,248; GELU49,200; Requant82,144;
LayerNorm104,064; causal Softmax12,676. These sum291,332. Length32 LayerNorm
uses ordinary multiple SRAM passes; the existing16-word fast cache does not cover
it. It must not be split into two16feature norms because that changes mathematics.
Per-state exclusive LN breakdown is in `benchmark/research/stage_c/scheduling.json`;
shared arithmetic states serve both variance and affine operations, so the report
labels them shared instead of pretending they measure only one arithmetic stage.

## Candidates and admission

1. Existing Matrix next-K prefetch: it already removes waits in the ablation.
   Advancing issue further requires inactive-buffer availability, ordered response
   tags and fault drain proof. A specific additional safe wait reduction was not
   established. No FIFO enlargement or second MAC array is justified.
2. Gamma/Beta/Residual cached read bypass: rejected under the strict fresh-SRAM
   observation requirement. Copy parity checks cannot check current SRAM parity.
3. Bank-aware placement: no measured bank-level conflict trace supports a new
   placement policy. Physical SRAM port/latency assumptions remain open.
4. Descriptor overlap: current one-bit ordered dependencies preserve production,
   consumption and fault order. Relaxing an edge without independent dependencies
   and fault-completion proof is not admitted. No reordered completion is assumed.
5. Completed-stage memory reuse: implemented in software. Retire the entire queue,
   inspect all outputs/KV, then reuse28,928B workspace next token. This reduces
   live allocation versus an unbounded per-token allocator; it is not a measured
   latency optimization or a removal of mandated intermediate materialization.

Any future legal read prefetch must use normal arbiter admission and permissions,
check returned parity, retain fault ownership and drain accepted responses on
abort/watchdog. Success/output cannot precede required fault checks. An earlier
clean read is not proof that a later architecturally required read is clean.
Software scheduling must preserve accesses whose error order is externally
observable, even where numerical dependence alone permits overlap.

Stage C therefore spends **zero of the allowed one RTL experiments**. Useful
next research topics are single-live-row lowering, exact scalar-control arithmetic
latency, and a reviewed length32 normalization strategy preserving required read
observations. These are future work, not automatically started Stage D.
