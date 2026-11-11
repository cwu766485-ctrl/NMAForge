# Phase 4 — measured CNN ablation

Actual VCS RTL, same Phase1 trained CNN/weights/input/Golden, 128KiB four-bank,
256MAC,4ns simulation, behavioral SRAM with two-edge scheduler response.
Product baseline `c93ea144713d5fafe2e8a5509029927cd6859e75`; candidate source
SHA256 pinned in public manifest; candidate commit is Gate2 checkpoint.

| Metric | Baseline | Ping-pong RTL |
|---|---:|---:|
|570164 useful-MAC CNN, both-fused CMDQ cycles|12351|11376|
|Writeback cycles|5200|4225|
|Tile windows × cycles|65×80|65×65|
|Accepted line writes|1040|1040|
|Compute SPAD reads / writes B|64064 /16640|64064 /16640|
|Useful MAC/CMDQ cycle|46.1634|50.1199|
|Full-CMDQ useful MAC utilization /256|18.0326%|19.5781%|
|H16 persistent decode /8 tokens|65771|65771|
|Qualified H32 persistent decode /8tokens|350155|350155|
|H16 / H32 cycles/token|8221.375 /43769.375|8221.375 /43769.375|

Savings975cycles =7.8941% reduction,1.0857× same-CMDQ speedup, target≥5% PASS.
64pack edges+1final drain replace64pack+16serial commits per tile. Only15of16
commits can overlap: final drain preserved. Non-writeback exclusive7151cycles
unchanged; no arbitration stalls were present in CNN writeback. Phase3 prediction
is now confirmed by candidate RTL, not counted as a second independent gain.
First-fused CNN saves780cycles (22983→22203); legacy65429 unchanged. Fixed
GEMM/GEMV kernels unchanged. Full table: public `ablation.csv`.

Every accepted output line matches Golden address,128-bit payload,WSTRBffff and
order. Intermediate writes preserved. No larger MAC, new arithmetic lane or
SRAM port. New declared state197bits, not mapped flop area.

## Timing boundaries and quality

Both-fused DMA setup+transfer3019cycles (busy2879subset),10944payload bytes,
45bursts/684beats, unchanged. Queue setup54cycles; output3328B readback4992cycles.
Disjoint modeled hardware segments give baseline20416 versus optimized19441
cycles (DMA+configuration+CMDQ+readback); this is a **partial sum**, not measured
continuous full inference. Checker/poison setup is excluded. Initial host Im2col/
packing and final GAP/argmax are outside CMDQ; historical Python host timing is
not added to RTL clocks. Integrated full-system latency NOT_MEASURED.
Public boundaries.json and Top logs retain each segment; memory profile retains
compute traffic, separate from descriptor/CPL/DMA traffic.

CNN dataset quality unchanged: historical FP32 95.5556%,INT8 96.1111% on360held-out;
this RTL campaign verifies sample42/class1 and20800Golden words per mapping,
not a fresh dataset accuracy evaluation. H32 100% synthetic period3 blind task
also solved by lag3 rule, not pretrained GPT2/Qwen quality. No new training.
H32 SFU273699/350155=78.1651%, Matrix41360/350155=11.8119%; H16 SFU49595.
CNN SFU0; Matrix compute-active2704cycles, unchanged. Overlap counters are not
added to exclusive cycle buckets. Memory and Golden hashes in Phase1 manifest
are referenced by Phase4 manifest; no numeric contract changed.
