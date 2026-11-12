# Architecture-first optimization — Gate 0 baseline and bottlenecks

## Status

**GATE0_PASS / PRODUCT_RTL_UNCHANGED.** This Gate fixes two references without
merging or modifying either product branch:

- approved product baseline: `nmaforge` at
  `c93ea144713d5fafe2e8a5509029927cd6859e75`;
- Phase 4 candidate configuration: `feat/phase4-cnn-writeback` at
  `b1dd75b8d1b6bb0465bdb3452df556a7919f7c4d`.

PR #5 remains open and is not treated as merged. The Gate 0 branch is
`feat/arch-opt-gate0`, based on the Phase 4 candidate so the existing reports and
validation evidence remain available. The local user worktree
`feat/shape-adaptive-gemv-v2` and all existing worktrees are untouched.

The product candidate changes only `rtl/compute/matrix/ai_tensor_matrix_core.v`
relative to the approved baseline. Its Phase 4 two-buffer writeback result is
retained as a measured candidate configuration; this Gate adds no RTL.

## Reproduction and measurement contract

Run from the repository root with VCS `V-2023.12-SP1_Full64`, Verilator 5.052,
Python 3.12.13, default 128 KiB four-bank behavioral SPAD, 256 INT8 MACs and a
4 ns simulation clock. The 4 ns value is a simulator clock, not an ASIC Fmax or
250/400 MHz claim.

```bash
python3.12 tools/benchmark/phase4/validate.py
python3.12 tools/benchmark/arch_opt/generate_gate0.py
```

The first command rechecks Phase 4 source/artifact hashes, all 1,040 CNN output
transactions, strict H16/H32 Golden data, fault logs and baseline/candidate lint
ablation. The second creates the CSV inventory and ranking from checked-in
artifacts. Phase 4 Top replays use the same trained CNN, H16/H32 fixture, Golden,
DMA plan, memory image and passive cycle monitor for both configurations. Matrix
and GEMV rows from the dedicated seeded campaign retain their own source/log
provenance; they are not relabeled as the Phase 4 Top replay.

A mutually exclusive state counter is the authoritative timing partition for
completed descriptor-to-completion CMDQ windows. Busy, response, arbitration,
bank, overlap and high-water counters are observers and are not summed into the
window. DMA preload and output readback are separate windows. Host preprocessing,
layout/packing and postprocessing are outside these RTL windows, so no end-to-end
CPU time is synthesized from unrelated clocks.

## Measured baseline inventory

The complete machine-readable inventory is
[`baseline_bottlenecks.csv`](../../../benchmark/research/arch_opt/baseline_bottlenecks.csv).
Selected authoritative rows are:

| Workload | Cycles | Useful MAC/cycle | Matrix operand wait | Writeback | SFU exclusive | Read/Write bytes |
|---|---:|---:|---:|---:|---:|---:|
|CNN both-fused, approved|12,351|46.1634|3,219|5,200|0|64,064 / 16,640|
|CNN both-fused, Phase4 candidate|11,376|50.1199|3,219|4,225|0|64,064 / 16,640|
|CNN first-fused, approved|22,983|24.8081|3,227|4,992|10,817|77,376 / 29,952|
|CNN legacy, approved|65,429|8.7142|3,227|4,160|54,084|130,624 / 83,200|
|H16 persistent decode, 8 tokens|65,771|0.2773|1,928|1,696|49,595|72,448 / 42,112|
|H32 persistent decode, 8 tokens|350,155|0.6097|14,600|6,400|273,699|546,816 / 227,840|
|4×4×32 GEMM|126|4.0635|11|4|0|256 / 64|
|16×16×16 GEMM|186|22.0215|25|64|0|512 / 1,024|
|32×32×64 GEMM|986|66.4665|312|256|0|6,144 / 4,096|
|M1 0x52 K32|143|3.5804|49|4|0|544 / 64|
|M4 0x52 K32|161|12.7205|52|16|0|640 / 256|
|M8 0x52 K32|213|19.2300|67|32|0|768 / 512|

The Phase 4 CNN candidate reduces only the measured writeback partition. Its
operand fetch/wait, MAC, traffic and control counters remain unchanged. The
approved H32 window is SFU-dominated: 273,699 exclusive SFU cycles (78.1651%),
including 134,144 fetch-response cycles, 29,456 arithmetic/control cycles and
15,059 pipeline-wait cycles. Matrix contributes 41,360 exclusive cycles, with
14,600 operand-wait cycles. These are the strongest measured opportunities, not
proof that all wait states are removable.

The seeded product Matrix campaign additionally measured `M1 1×13×17` at 75
cycles/221 useful MACs/304 read bytes, `M4 4×16×32` at 202 cycles/2,048 MACs,
`M8 8×16×19` at 154 cycles and `M16 16×16×65` at 630 cycles. Those logs use a
seeded Matrix-core responder and independent Golden; they are separate from the
Phase 4 Top replay and do not provide exact K=128 evidence.

## Explicit coverage gaps

The inventory marks exact product-Top rows as `NOT_RUN` where no checked-in,
source-pinned result exists: requested GEMV M=1/4/8/16 at K=32/64/128 combinations
not already represented, and requested 4×4/16×16/32×32 K=128 GEMM rows. The
research shape-adaptive SPAD wrapper is useful feasibility evidence: its M1/M4
rows measured 530→474 and 770→738 cycles, while M8/M16 selected baseline. It is
not product Matrix-controller integration and assumes a deliberately serialized
wrapper path; its gains cannot be used as Top speedups.

The 128 KiB capacity and four-bank service model are fixed in every measured
row. No row assumes an extra SRAM port, free bank parallelism, a second MAC
array, or an uncharged DMA/host stage. No Phase 4 evidence measures full host to
host inference latency.

## Bottleneck interpretation

1. **SFU scheduling and arithmetic control** is the largest H32 opportunity, but
   the Phase 4 fault-safe study rejected unrestricted speculative reads: ordered
   retirement alone changes Host-write and permission-revoke observations. A
   non-speculative Candidate A (internal FSM/arithmetic scheduling) needs a
   closed-loop model before RTL; an immutable-operand Candidate B needs a
   hardware-enforced lease/spec change before any implementation.
2. **Matrix operand wait/prefetch** is the next bounded opportunity. H32 has
   14,600 wait cycles; 32×32×64 has 312. Existing A-cache, next-K prefetch,
   elastic forwarding and outstanding depth must be ablated under the real
   arbiter. Logical prefetch wait is not automatically a physical bank conflict.
3. **Shape-adaptive GEMV** has measured small-M evidence but no unified product
   Top shape sweep. Existing 0x52 K-fold/cache path is already effective for
   selected M and K. The isolated kernel's ideal fold model predicts regressions
   at M=8/16; a static selector is required and must not replace the current
   path without Top integration.
4. **CNN writeback** is already a bounded candidate: 7.8941% same-CMDQ reduction
   and exact payload/fault preservation. Repeating ping-pong writeback is unlikely
to yield another independent gain near its measured 65-cycle/tile schedule.
5. **CNN transfer boundary** has DMA setup+transfer 3,019 cycles and 4,992
   output-readback cycles, but a continuous host timeline is not available. Moving
   output handling between interfaces cannot be called a system speedup without
   charging the same observable endpoint.

## Opportunity ranking and Gate 0 decision

See [`architecture_opportunity_ranking.csv`](../../../benchmark/research/arch_opt/architecture_opportunity_ranking.csv)
for source, cost, risk and decision fields. The current recommendations are:

| Candidate | Decision | Evidence-backed next action |
|---|---|---|
|CNN ping-pong writeback|RETAIN_AS_PR_CANDIDATE|Review PR #5; do not duplicate this optimization|
|SFU non-speculative scheduling|REWORK|Build cycle-closed model of actual scalar FSM/arbiter; no RTL yet|
|SFU immutable operand lease|REWORK / SPEC PROPOSAL|Define ownership/fence semantics before any implementation|
|Matrix prefetch/operand scheduling|REWORK|Ablate existing switches and bank service under identical seeds|
|Shape-adaptive GEMV|REWORK|Run paired product Top M/K sweep; keep 0x52 fallback for M8/M16 unless measured otherwise|
|CNN DMA/output transfer|REWORK|Instrument a complete same-endpoint timeline before changing transfer path|

Gate 0 therefore passes **measurement and provenance**, but does not authorize
new Product RTL. Gate 1/2/3 must each start with a candidate model and paired
baseline before implementation. The next highest-value experiment is a
non-speculative Matrix/SFU schedule model using the existing arbiter, followed by
the missing product Top GEMV sweep; no architecture freeze or signoff is claimed.
