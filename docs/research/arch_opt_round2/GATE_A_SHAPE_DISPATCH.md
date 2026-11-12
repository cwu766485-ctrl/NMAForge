# Gate A — Shape-aware dispatch candidate: RETAIN (bounded offline mapper)

## Actual implementation and boundary

Base: `d8883ed29723d3121e38ea1c89d717f47b8bb003` on `feat/arch-opt-m1`.
Candidate: `feat/arch-opt-round2-dispatch`, commit containing this report.
`sw/tools/shape_aware_dispatch.py` maps dense signed INT8 operands into existing
0x30/0x52 descriptors and their respective layouts. Legacy is default; explicit
`shape-aware` plus `isolated=True` enables selection only for the measured
M8/M16,N16,K16/32/64/128 domain. M1/M4 and unsupported/tail shapes retain 0x52.
This is a usable mapper callable, exercised through real Top descriptors, not a
new controller or a claim of automatic whole-model integration.

## Matched real Top A/B

VCS V-2023.12-SP1_Full64, Python 3.12.13, 128 KiB four-bank registered SPAD,
256 MAC, 4 ns simulation clock (not Fmax). Every pair uses identical mathematical
A/B values, exact common INT32 Golden SHA, one CMDQ descriptor and completion
commit. Trace response ledger drains exactly with 2-cycle responses. Inputs
are resident before the measured doorbell-to-completion interval.

| M | K | 0x52 cycles | 0x30 cycles | Selected | Selected cycle reduction |
|---:|---:|---:|---:|---|---:|
|4|16|123|126|0x52|0%|
|4|32|161|162|0x52|0%|
|4|64|237|234|0x52|0%|
|4|128|389|378|0x52|0%|
|8|16|157|146|0x30|7.01%|
|8|32|213|186|0x30|12.68%|
|8|64|325|266|0x30|18.15%|
|8|128|629|426|0x30|32.27%|
|16|16|225|186|0x30|17.33%|
|16|32|317|234|0x30|26.18%|
|16|64|501|330|0x30|34.13%|
|16|128|1109|522|0x30|52.93%|

M1 remains 108/143/213/353 cycles for K16/32/64/128. Actual selected mapper
runs also execute through Top; no regression among the 16 selected points.
`benchmark/research/arch_opt_round2/results.csv` reports each baseline, explicit
GEMM, selected candidate, traffic, operand wait, prefetch and B-cache counters.

## Why the difference exists

0x52 uses dense padded A rows and dense B K-rows. Each K-fold computes four
K elements across at most four output rows. M8/M16 replay the K loop for two/four
row groups. The command-local B cache saves first-64-element reads on later row
groups, but K>64 refetches uncached B lines. GEMM uses four-row/four-column packed
words and all sixteen array rows. M16 K128 uses 128 MAC cycles versus 128 for
K-fold, but the latter repeats preparation/operand wait per row group: wait
697 versus GEMM 221. Both commit 1024 output bytes. Identical descriptor size
and completion overhead do not explain the gap. At K128 GEMM reads 4096 B
versus 7168 B for M16; M8 reads 3072 B versus 4096 B.

## Layout, DMA and system limits

GEMM changes input representation. The returned A image is padded to 16 rows,
while GEMV pads each A row to a 16-byte stride. M8 K128 A images are 2048 versus
1024 B; B is 2048 B in both. M16 K128 images each have 2048 B A and B. Per-row
packed byte sizes and Python single-sample packing nanoseconds are in the CSV.
Packing is performed before upload, not by hidden RTL. No extra DMA input is
assumed free: actual DMA cycles are NOT_MEASURED in this CMDQ test. No system
speedup is calculated, and host wall time is never added to RTL cycles.

## Execution and fault contract

The caller deliberately creates a new descriptor with a new physical layout;
this does not replace an already-published legacy command. The isolated opt-in
requires completed load/fence, exclusive ownership of operands/output and stable
permissions until completion. This is a caller precondition, not a hardware
lease or newly proven system enforcement. Default legacy mapping remains for
uncontrolled Host/DMA/debug mutation or permission changes; requesting selection
without explicit isolation raises ValueError. The module does not claim to detect
concurrent agents. Dynamic use is outside the retained scope and must not be
silently dispatched.

Both opcodes retain actual SRAM authorization/parity checks, but read order,
padded addresses, cached-read count and first fault/output prefixes can differ.
Permission regions must cover the selected packed footprints including padding;
parity faults must be repaired before retry. No observational equivalence under
concurrent writes, permission revoke or injected fault is asserted. Fault safety
is selected-opcode behavior, verified with the existing three-seed Matrix
18 numerical/35 fault regression and 0x52/0x53 fault/recovery tests. Top smoke
passes including tail, protection and reset recovery. These are existing-path
regressions, not a proof of dynamic cross-opcode equivalence.

Hardware cost: zero new data/metadata flops, buffers, MACs, ports, muxes or RTL
critical paths. Cost is host packing, optional A padding and policy/descriptor
software; existing static/timing risks remain. Independent byte-decoder reference
passes 72 signed corner/tail layouts. No product RTL changed; no PPA claim.

Decision: RETAIN this explicit offline mapper candidate and its reproducible
CMDQ improvement. Automatic runtime dispatch or whole-graph adoption requires
additional ownership integration and same-endpoint DMA measurement. No merge.
