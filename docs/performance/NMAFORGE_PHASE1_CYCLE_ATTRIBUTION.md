# Phase 1 — exact cycle attribution

Status: **PASS_SCOPED / DESIGN_PARTIAL**. No product RTL was changed. The approved
RTL commit is `48790076b351cb9d49e1785247d32a1f51b8286d`, RTL tree
`c86d2cfda7cde900482f38a3b48b620bc69f67cb`. This report supersedes coarse historical
phase estimates only for the freshly replayed workloads below.

## Measurement contract and evidence

128 KiB = four banks×8,192×32bits; optional512 KiB remains elaboration-only.
One16×16 INT8/256-MAC array. VCS V-2023.12-SP1_Full64, Python3.12.13. Top clock
4ns, behavioral SRAM, two sampled rising edges from scheduler read admission to
valid response. This is neither physical SRAM timing nor Fmax evidence. Block
configuration ablation uses its original10ns randomized-memory testbench.

The passive monitor is
`dv/subsystem/top_smoke/fixtures/phase1_profile.svh`; a single TB include enables
it. No force, new product counter, parameter change or handshake modification.
Windows start with the existing CMDQ doorbell timing flag and end with the final
committed completion captured by the existing checker. Initial preload, queue
configuration, interbatch host time, output/Golden readback are outside them.

[Public manifest](../../benchmark/research/phase1/manifest.json) pins the RTL,
model/input/Golden/source hashes, tool versions and every evidence file. Actual
commands accompany the logs. [Reproduction](../../tools/benchmark/phase1/README.md)
contains the complete commands, including public-package validation.

All three GEMMs, three product0x52 GEMVs, three same-weight CNN mappings,
H16, historical H32 and qualified H32 passed Top checks. H32 additionally has a
byte-for-byte observed versus Golden check for all12×7,744words; no Golden was
relaxed. Seeded Top20cases/seed12345 PASS. The Matrix8configuration×5shape
ablation passes its independent sums. This is scoped functional evidence, not DV
closure.

## Exclusive accounting

Each measured edge has exactly one bucket, priority Matrix, SFU, other engine,
completion, descriptor, dispatch/control. Thus concurrent engine busy clocks are
not additive service demand. All buckets, including zero-valued ones, sum exactly
to each complete existing measurement window; analyzer asserts equality and
accepted read/write-byte reconciliation. Busy, prefetch overlap, contention and
request-wait counts are separate overlapping observations.

| Exclusive class | State/meaning |
|---|---|
| Matrix tile setup |7 PREP_MAC,10 NEXT; includes tile-boundary control |
| Matrix operand fetch |1/3/5 request states; not every clock accepts a read |
| Matrix operand wait |2/4/6 response drain plus14 PREFETCH_WAIT |
| Matrix compute active |8; padded/disabled lanes accounted separately |
| Matrix writeback |9, includes packing/address/control and accepted stores |
| Matrix completion |remaining busy states, including DONE/ERROR/drain |
| SFU fetch issue |1/3/5/10/18/20/23/25/32/36/39; includes command-local cache selection when enabled |
| SFU fetch response |2/4/6/11/19/21/24/26/33/37/40 |
| SFU arithmetic/control |other busy states including22,30,31, start states |
| SFU pipeline wait |8/13/15/17/35 iterative divide/sqrt waits |
| SFU writeback / completion |9/27 and28/29 respectively |
| Other / control |other engine; then no-engine CPL, DESC, remaining dispatch |

State classifications describe controller residence, not imaginary SRAM traffic.
SFU descriptor overhead includes its completion state plus shared fetch/dispatch/
completion; the shared control remainder is not falsely assigned to a single SFU.
The exact per-window tables are `analysis/exclusive.csv`, `sfu_states.csv` and
`sfu_opcodes.csv` in the evidence package.

## Same-condition product Top results

Reads/writes below are accepted compute-side SPAD bytes, excluding descriptors,
completion and initial DMA. Utilization is useful MAC/(256×full-window cycles).

| Shape/opcode | CMDQ cycles | Useful MAC | Useful MAC/cycle | Full-window utilization | MAC-active lane utilization | Read / write B |
|---|---:|---:|---:|---:|---:|---:|
|4×4×32 /0x30|126|512|4.0635|1.5873%|6.25%|256 /64|
|16×16×16 /0x30|186|4,096|22.0215|8.6022%|100%|512 /1,024|
|32×32×64 /0x30|986|65,536|66.4665|25.9635%|100%|6,144 /4,096|
|M1,N16,K32 /0x52|143|512|3.5804|1.3986%|25%|544 /64|
|M4,N16,K32 /0x52|161|2,048|12.7205|4.9689%|100%|640 /256|
|M8,N16,K32 /0x52|213|4,096|19.2300|7.5120%|100%|768 /512|
|Trained CNN, both fused row-major|12,351|570,164|46.1634|18.0326%|82.37% useful/padded|64,064 /16,640|
|H16 eight decode tokens|65,771|18,240|0.2773|0.1083%|logical useful work only|72,448 /42,112|
|Qualified H32 eight decode tokens|367,051|213,504|0.5817|0.2272%|logical useful work only|546,816 /227,840|

GEMV uses the real product0x52 dense-layout path. Its comparison with padded0x30
is not a standalone research wrapper result. These different mappings have
different bytes/control and cannot be used to claim a same-layout optimization.
Transformer logical counts use only live token rows and visible attention
positions; padded computation remains charged in cycles/traffic. H32's historical
log marker has `useful_macs=0`; this is missing instrumentation, corrected in the
new analysis using the explicitly stated per-token formula:
`2*(4*32*32+2*32*128+2*32*(position+1))+32*32`.

| Exclusive cycles | CNN both fused | H16 decode8 | H32 decode8 |
|---|---:|---:|---:|
|Matrix setup|741|544|3,856|
|Matrix operand fetch|407|640|2,448|
|Matrix operand wait|3,219|1,928|14,600|
|Matrix compute|2,704|1,664|13,824|
|Matrix writeback|5,200|1,696|6,400|
|Matrix completion|2|128|232|
|SFU fetch issue/cache selection|0|12,616|67,952|
|SFU fetch response|0|22,272|134,144|
|SFU arithmetic/control|0|4,468|29,456|
|SFU iterative wait|0|5,791|31,955|
|SFU writeback|0|4,232|26,640|
|SFU completion|0|216|448|
|Other engine (KV in these Transformer runs)|0|3,152|20,224|
|No-engine completion|8|1,824|3,872|
|No-engine descriptor|16|592|1,664|
|Dispatch/control remainder|54|4,008|9,336|
|**Sum**|**12,351**|**65,771**|**367,051**|

Overlapping prefetch/compute counts are2,444/1,152/12,224 respectively; they are
already included above. H16 prefill is2,728cycles of QKV/KV population only.
H32 full-graph prefill4tokens is181,329cycles; full12stage session548,380cycles.
H16 and H32 prefill definitions differ and must not be compared as equivalent work.

## SPAD admission, response and contention

`analysis/spad.csv` records each request form's admissions, wait clocks and
pairwise simultaneous requests. `clients.csv` separates DESC/CPL/compute/
banked/DMA/CNM byte and transaction counts. `responses.csv` records every tagged
accepted read and response, including window−1 activity, with no orphan response
or undrained read. All sampled response latencies equal2edges. No observed data
response error remains after selecting the actual banked parity channel.

The observer initially sampled the generic scalar `arb_rsp_error` for banked
reads; that unused scalar error mux can contain X while the banked parity/data
are valid. Correct observation uses `banked_parity` for client3, CNM parity for5,
and generic response error otherwise. All Transformer fixtures were replayed
unchanged after that observer-only correction. It is not a product fault fix.
Accepted-request error field is a placeholder0, so this passive ledger is not a
complete authorization/fault checker; existing RTL Golden/fault tests retain that
responsibility. CNM's conservative16B/all-bank reporting is not validated for
partial masks; none of the measured windows admits CNM requests.

Simultaneous request clocks / summed request-form wait clocks:
CNN12/12, H16 1,880/1,880, H32 4,288/4,288; isolated GEMMs/GEMVs0/0.
Wait clocks overlap engine states and cannot be added to exclusive totals.
The shared scalar compute client collapses sub-engine owners; per-engine scalar
stall visibility remains in the existing Stage A monitor. Observed maximum
Matrix outstanding depth is2 in all fixed Top kernels, despite configured4.
This does not establish that more buffering would help.

The sole arbiter admits one scheduler request class per edge. A16B line/banked
read occupies all four banks; scalar bank selection is address[3:2]. The address
trace includes bank masks for replay, but there is no independent physical SRAM
bank-ready/stall signal or physical macro collision timing in this model.
Consequently **physical bank conflicts are NOT_MEASURED**, not equated to logical
arbitration waits and not inferred to be zero on hardware.

## Bottleneck ranking and existing-switch ablation

1. H32 SFU fetch-state sum is **202,096cycles (55.06%)**; total SFU
   **290,595 (79.17%)**. LN104,064; requant82,144; GELU49,200; residual43,248;
   causal softmax11,939. Most latency is scalar service/control, not MAC count.
2. CNN Matrix writeback5,200 (42.10%) includes4,160 non-admission packing/control
   edges and1,040 accepted16Bstores. Operand wait3,219 (26.06%) is next. Only12
   admission-wait edges: a bank-aware placement claim is unsupported.
3. Large GEMM operand wait312 (31.64%), of which300 PREFETCH_WAIT; compute256 and
   writeback256 each25.96%. Zero arbitration wait. Prefetch bandwidth, metadata
   readiness and kick/drain control deserve a transaction model before new RTL.
4. Short GEMMs/GEMVs have67 no-engine control edges per command. For M1 GEMV,
   this is46.85% of143cycles; adding MACs cannot remove that overhead.

The existing configuration ablation uses the same deterministic operands per
shape across depth2/4, prefetch0/1, A-cache0/1. Its randomized-ready/ordered queued
response model differs from Top's fixed two-edge SRAM; compare configurations
within that table, never subtract its cycles from Top cycles.

| Block shape |d2/P0/C0|d4/P0/C0|d4/P0/C1|d4/P1/C1|
|---|---:|---:|---:|---:|
|4×4×32|98|98|98|64|
|16×16×32|263|254|254|221|
|32×32×64|1,711|1,624|1,414|1,161|

Last shape read admissions512→384 with A-cache. Prefetch and cache already
provide real benefits under this model; these are **existing mechanisms**, not new
Phase1 optimization. No measured physical bank conflict or new incremental
schedule improvement admits candidate C yet. See
[ranking](../research/INNOVATION_CANDIDATE_RANKING.md).
