# Gate B — Address-level attribution (no cache RTL implementation)

## Confirmed source

Source RTL is unchanged from `d8883ed29723d3121e38ea1c89d717f47b8bb003`.
`A_TILE_CACHE_K_WORDS=16` bounds the shared 16×16×32-bit local array (8192 data
bits / 1024 B). `gemv_b_cache_hit` and `gemv_b_prefetch_hit` require K-group<16
and the valid bit; four K elements/group gives coverage through K=64. The
M8/M16 row groups reuse this region and refetch uncached B on each later group.
`perf_gemv_b_cache_reads_saved` counts saved 16-byte line requests, not bytes.
For M16 K128 it reports 192 saved reads, 48 cache-copy hits.

The passive monitor captures every accepted client-3 16-byte Matrix read with
its address. `b_addresses.csv.gz` reports multiplicity per B line; the raw
`profile_memory.csv.gz` preserves ordering and two-cycle response ownership.
All success runs have no orphan or undrained responses and no parity error.

| M | K | B unique B | B total B | Repeated B |
|---:|---:|---:|---:|---:|
|8|63|1008|1008|0|
|8|64|1024|1024|0|
|8|65|1040|1056|16|
|8|96|1536|2048|512|
|8|127|2032|3040|1008|
|8|128|2048|3072|1024|
|8|129|2064|3104|1040|
|16|63|1008|1008|0|
|16|64|1024|1024|0|
|16|65|1040|1088|48|
|16|96|1536|3072|1536|
|16|127|2032|5056|3024|
|16|128|2048|5120|3072|
|16|129|2064|5184|3120|

For N16 these excess bytes equal `max(K-64,0)*16*(M/4-1)` exactly. Addresses
below B+1024 are read once; later valid B rows are read twice for M8/four times
for M16. M1/M4 do not have later row groups and show no B duplication. K tails
can still require padded A-line traffic; unique mathematical bytes are not the
same as legal 16-byte transaction bytes.

## Candidate disposition for review

B1 K-blocking: REWORK. Changing row/K loop order needs persistent sums across
row groups. Existing active array accumulator lifetime ends at each row tile;
retaining multiple groups is not a free FSM reorder. No new sum storage or
changed fault-prefix behavior was implemented.

B2 capacity extension: REWORK / not implemented. Extending the shared array
from 16 to 32 K-groups would add at least 8192 data bits, plus validity, index
width and mux/control changes. More importantly, avoiding later reads changes
fault/Host-write/permission observations. No relaxed legacy contract is allowed;
capacity cost alone does not admit the change.

B3 hybrid dispatch: RETAIN bounded Gate A candidate. At M16 K128, actual Top
CMDQ 1109→522 (-52.93%), accepted reads 7168→4096 B; M8 K128 629→426
(-32.27%), accepted reads 4096→3072 B. There is no new RTL buffer or port.
This is a different selected legacy execution path under explicit offline
ownership; it is not a transparent optimization to legacy 0x52. See Gate A for
layout upload and fault-semantic restrictions. M1/M4 keep their original path.

## Scope and reproducibility

`tools/benchmark/arch_opt_round2/README.md` gives exact build/run/archive commands.
The CSV, packed images, common Golden hashes, complete address/cycle traces,
per-command invocations and fault/smoke text logs are checked in under
`benchmark/research/arch_opt_round2/`. VCS V-2023.12-SP1_Full64; 4 ns behavioral
simulation, 128 KiB/4 banks, 256 MAC, single scheduler admission, no new ports.
Basic Python/packing reference and existing RTL fault regressions pass. No new
cache RTL was requested by the Immediate Action and none is added. Stop for
review after Gate A implementation and Gate B attribution; Gate C/D not started.
