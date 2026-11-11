# Phase 1 — TinyNPU comparison contract

Status: **12/12 common-adapter raw-GEMM checks PASS; native/full-system comparison
PARTIAL**. NMA RTL `48790076b351cb9d49e1785247d32a1f51b8286d`;
Tiny pinned clean source `8216c22b762011aa20c05fc2768423fd12dda59d`.
Tools: VCS V-2023.12-SP1_Full64 for NMA; Verilator5.052/C++ for Tiny;
Python3.12.13 reference. Both arrays256INT8MAC. SHA256pins for A/B/Golden,
service harnesses, trained model and results:
[manifest](../../benchmark/research/phase1/manifest.json),
[CSV](../../benchmark/research/phase1/matched/matched.csv),
[JSON](../../benchmark/research/phase1/matched/matched.json).
[Exact reproduction](../../tools/benchmark/phase1/README.md).

## Evidence classes

| Class | Included boundary | Current comparison / permitted claim |
|---|---|---|
|Array-only|Array clear/load/feed/compute/drain to stable raw results; excludes memory/controller|Earlier pinned StageA/C array evidence retained. Newly separated adapter array clocks below are harness-residual clocks, not a new native run|
|Common Memory Adapter|Preloaded common backing store→clocked operand service→array→raw output commit|Fresh12cases; same service and raw Golden; adapter cycle ratios only|
|Native Controller|Each design's actual controller, native SRAM/DMA/layout/completion boundary|Prior conv1x_mini has matching values but mismatched endpoints; no speedup|
|Full System|Input availability through same final output/host postprocess, matched memory timing|NOT_MEASURED for trainedCNN or completeTransformer; no system speedup|

Matching output is necessary but not sufficient for fair timing. Different
controllers/memory ports, preload/layout cost, quantization and commit boundaries
must remain explicit. A faster raw array is not proof of a faster application.
No host seconds are converted to RTL cycles or mixed with simulated clocks.

## Common clocked service model

Both unchanged source arrays receive identical signed INT8 A/B and exact INT32
unsaturated sums (all vectors stay within range), no model shift/saturation,
bias/activation/nonlinearity. Timed service uses16B/clock,1outstanding read,
1issue+2responseclocks/line and1clock/outputline, with reads, array work and
writes serialized. Full padded16×16output commits are charged on partial tiles;
only live rows/columns are compared. NMA's tile-major raw output is canonicalized
to the same row-major Golden before comparison. No direct uncharged operand
injection replaces service: harnesses fill serviced operand buffers and commit
output lines on the charged edges.

Common backing store128KiB is a **model**, not Tiny's native SRAM. Native NMA
128KiB/four32bitbanks; Tiny64KiB byte-wide synchronous data SRAM plus distinct
8KiB scratch,1KiBaccumulator,16KiBprogram and8KiBtensordescriptors; those distinct
memories cannot be presented as one interchangeable data capacity. Common wider
service hides Tiny's native bandwidth limit and intentionally isolates array
organization. No physical memory energy/area/400MHz result is measured.

| Shape / subgraph | NMA adapter cycles | Tiny adapter cycles | Tiny/NMA adapter ratio | Read/write B each |
|---|---:|---:|---:|---:|
|4×4×32|290|358|1.2345|1,024 /1,024|
|16×16×16|178|214|1.2022|512 /1,024|
|16×16×32|290|358|1.2345|1,024 /1,024|
|32×32×64|2,056|2,584|1.2568|8,192 /4,096|
|M1,N16,K32|290|358|1.2345|1,024 /1,024|
|M4,N16,K32|290|358|1.2345|1,024 /1,024|
|M8,N16,K32|290|358|1.2345|1,024 /1,024|
|H32 Q / K / V each4×32×32|580|716|1.2345|2,048 /2,048|
|H32 FFN Up4×128×32|2,320|2,864|1.2345|8,192 /8,192|
|H32 FFN Down4×32×128|1,924|2,444|1.2703|8,192 /2,048|

All12 Golden checks PASS, `system_speedup:null` for every row. Adapter read and
write cycle/byte columns reconcile both designs. Example32×32×64:
readservice1,536+write256+array264/792=2,056/2,584. NMA's broadcast preload differs
from Tiny's systolic feed/drain, so the residual reflects array/harness behavior,
not optimized native controller performance. Different clock generators express
cycle counts; their nanoseconds are not a matched physical-frequency claim.

H32 rows use the newly qualified model
`fc9c8a9fbcccf556e7a8281b06ee0e75827ca9264424f57ff66f5d82b7c6de78`,
Layer0first-token live input/INT8 activation and trained weights, with3zero rows.
They cover only linear raw sums; model-scale requant, residual, LN, softmax,
GELU and KV scheduling remain outside. GEMV-shaped adapter rows use raw padded
arrays and **are not NMA product0x52 versus a Tiny native GEMV engine**.

## CNN/native boundary retained, not relabeled

Historical pinned common conv1x_mini produces identical fourbytes
`ad 7f 80 08`. Source/fixtures remain in StageA/C archived evidence. This phase
reviews that evidence, not a fresh native graph replay:
NMA1,874CMDQ +1,080testbenchlayoutcycles excludes3,456Binitialhostpreload;
Tiny4,742start→DDRoutputcommit includes byte-serial emulatedDMA1,088Bload/4Bstore
and native layout, with24configurationclocks before start. NMAcompute read/write
3,360/1,600B plus layout144/576B; Tiny native SRAM1,596/1,528B.
There is no common DRAM timing. Computing4,742/1,874or4,742/2,954as a system
speedup is forbidden. The trained570,164MACCNN is a separate larger graph and
has no corresponding Tiny trained full inference in this phase.

## Objective strengths, weaknesses and remaining work

NMA wins these raw adapter cases by1.20–1.27× with the same imposed service;
its flexible broadcast output-stationary array avoids some systolic feed/drain.
That is a valid limited claim. NMA has more native data SRAM and wider service,
so native throughput advantages may partly be resource differences. Tiny has a
working compact native CNN controller and lower native memory width; NMA's
full H32graph is dominated by scalar SFU/control and uses113descriptors/token.
Neither common-adapter results nor asymmetric native graphs establish an
application-level winner.

Before a system claim: replay same CNN graph including both preprocess/layout/
DMA/output endpoints, and same quantized QKV/FFN plus required SFU/KV graph;
match memory response/backpressure, capacity/ports or explicitly normalize them;
charge allmaterialized intermediate and output commits; preserve each fault
contract. Native unsupported math must be reported, not replaced by free host
work. Full-system CNN/Transformer speedup remains **NOT_COMPARABLE**.
