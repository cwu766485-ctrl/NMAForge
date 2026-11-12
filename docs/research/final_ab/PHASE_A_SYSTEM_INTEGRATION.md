# Phase A — RETAIN isolated offline shape-aware mapping

Base source: `56adb1245ecd7de740c4c90c48844f6b88fdd24c`. Candidate is the
commit containing this report on `feat/final-arch-ab-system`. Product RTL tree
is unchanged. VCS V-2023.12-SP1_Full64, Python3.12.13, 128KiB/four banks,
256MAC,128-bit DMA,4ns behavioral simulation clock (not implementation Fmax).

## Integration change

`sw/tools/shape_aware_dispatch.py` now packs GEMM A using its actual physical
row count (M8 uses8 rows), instead of adding eight unused rows. The first actual
system experiment showed the previous16-row padding made M8 3–7% slower in the
full interval despite its CMDQ win. That run is retained as `initial` evidence.
Revised packing uses existing legal four-row tile layouts, not new hardware.
M1/M4 keep0x52. M8/M16 select0x30 only in the measured N16,K16/32/64/128 domain.

## Same-endpoint measurement

`tools/benchmark/final_ab/run.py` creates the same dense mathematical inputs and
independent INT32 Golden, packs each path, generates real input DMA segments,
and executes the real Top. Hardware timestamps cover initial DMA configuration,
input load (including descriptors and padding), CMDQ/CPLQ configuration, doorbell,
completion publication, completion record reads, output DMA configuration/store,
status read/clear, and output availability in external memory at0x3000. Each path
has identical output location/format/byte count. Unused global DMA configuration
registers are initialized inside the interval. CPLQ_HEAD release/queue teardown
is after delivery and excluded equally (single inference experiment).

| M | K | Legacy total cycles | Candidate total cycles | Reduction |
|---:|---:|---:|---:|---:|
|1|16|478|478|0%|
|1|32|584|584|0%|
|1|64|796|796|0%|
|1|128|1220|1220|0%|
|4|16|553|553|0%|
|4|32|674|674|0%|
|4|64|916|916|0%|
|4|128|1403|1403|0%|
|8|16|671|660|1.64%|
|8|32|826|799|3.27%|
|8|64|1139|1080|5.18%|
|8|128|1845|1642|11.00%|
|16|16|907|868|4.30%|
|16|32|1133|1050|7.33%|
|16|64|1585|1414|10.79%|
|16|128|2729|2142|21.51%|

These are **serialized modeled hardware delivery** results, with all measured
load/queue/consumer costs. No DMA/compute overlap is claimed. Both revised paths
upload the same payload byte count at every shape (see results.csv); packing
still changes representation. Python packing wall nanoseconds are recorded
separately and never added to simulation cycles. Input data already exists in
external memory when the interval starts; CPU preprocessing, initial host upload,
real caches/driver/scheduling and actual silicon execution time are not modeled.
Consequently this is not a host-to-host application latency claim.

Strict output endpoint Golden plus full SPAD Golden scans pass for all32 runs;
the32-run backpressure suite is additional validation. Protocol assertions remain
active. Seventy-two independent byte-level signed/tail layouts pass. No new
opcode/ABI,MAC,port,buffer,hardware mux or critical path is introduced. Software
cost is packing and a bounded dispatch policy; actual-row packing removes wasted
DMA bytes from the earlier candidate.

## Ownership and fault boundary

This remains an explicit prepublication offline mapper API with isolated opt-in,
not automatic command rewriting. The caller supplies completed DMA load/fence,
exclusive operands/output and stable permissions until completion. The serialized
runner enforces this by issuing no conflicting writes/revokes; it is a verified
restricted test protocol, not a hardware lease for arbitrary host software.
Default policy remains legacy; dynamic mutation/revoke use is outside the selected
contract and no access-order or first-fault equivalence is asserted. Every
selected0x30/0x52 request still uses the original authorization/parity/abort/reset
machinery. Packed footprints must have appropriate permissions. Existing fault
regressions validate selected-opcode safety, not dynamic cross-opcode equivalence.

RETAIN as research integration candidate, with no automatic product merge.
