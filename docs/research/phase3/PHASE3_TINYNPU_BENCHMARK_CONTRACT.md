# Phase 3 — pinned TinyNPU comparison contract (desk review)

NMA product source: `c93ea144713d5fafe2e8a5509029927cd6859e75`, RTL tree
`fe0e999fa187c4ed52a512d27509d5922e6137eb`, identical to reviewed Phase 2.
Leonui/tiny-npu source: `8216c22b762011aa20c05fc2768423fd12dda59d`, clean local
checkout verified. This phase stops after Gates0–2: it reviews existing matched
evidence and actual source, **does not claim a new Gate 3 benchmark campaign**.

| Boundary | Actual evidence | Allowed conclusion |
|---|---|---|
|Array only|Earlier Stage A/C raw array experiments|Array/harness scope only; no new Phase 3 measurement|
|Common memory adapter raw GEMM|12 Phase 2 archived identical-Golden checks; source remains identical|Raw adapter latency ratio only|
|Same QKV/FFN|H32 Q/K/V and FFN Up/Down raw sums in those 12 checks|Linear subgraphs only; excludes requant/LN/GELU/KV/dispatch|
|Same CNN graph|Historical conv1x_mini matches output four bytes|Native endpoints differ; no system ratio|
|Native controller|Different DMA/layout/controller services|No matched cycle comparison yet|
|Whole model|NMA H16/H32/CNN Golden; Tiny has other native model testbenches|Identical full graph/math/endpoint not demonstrated|

The archived [matched CSV](../../../benchmark/research/phase2/matched/matched.csv)
and [JSON](../../../benchmark/research/phase2/matched/matched.json) retain source,
fixture/Golden hashes, PASS and `system_speedup:null`. Public validation checks
that no raw-adapter result has become a system-speedup claim.

Common adapter uses signed INT8 inputs, unsaturated INT32 raw sums within range,
256 MACs each, 128 KiB modeled backing, 16 B service, two response edges, one
outstanding read, serialized memory/array service and charged raw output commit.
Output live regions are canonicalized; partial tiles still pay padded service.
No free DMA/preprocess/host stage is counted as completed. This adapter replaces
native memory services and cannot establish physical bandwidth/area or a native
controller winner. Examples retained from Phase 2 (NMA/Tiny adapter cycles):
16×16×16 178/214; 32×32×64 2,056/2,584; H32 Q/K/V each 580/716;
FFN Up 2,320/2,864 and Down 1,924/2,444. Permitted adapter ratios are 1.20–1.27×.
These are historical fixed-source results, not fresh Phase 3 native graph runs.
Product GEMV0x52 measurements143/161/213 are a different boundary.

## Capacity, ports and numeric audit

NMA native top defaults128KiB, four32bitbanks, one scheduler admission/edge;
scalar4B or alignedline16B, registered response. Its separate AXI4 DMA is128bit;
AXI-Lite publishes CMDQ/CPLQ ABI. Existing0x52/0x53, signed integer fixed-point
requant/normalization/nonlinear functions and all materialized intermediates
remain charged and Golden-checked. CMDQ execution excludes initial fixture host
preload; simulation clock4ns is not implementation Fmax.

Tiny capacity must be named **per top/elaboration**, not assigned one global
number from a README. At this pinned source, `sim/verilator/onnx_sim_top.sv`
defaults data SRAM0 to65,536×8bits (64KiB), scratch4096×16bits (8KiB),
ACC256×32bits (1KiB), plus separately addressed program/tensor memories.
`gpt2_block_top.sv` defaults SRAM0=8192×8bits (8KiB), SRAM1=4096×8bits (4KiB),
scratch4096×16bits (8KiB), ACC256×32bits, ucode1024×128bits (16KiB),
and its build can override parameters. SRAM1 and softmax scratch are distinct;
a claim that every Tiny test has64KiB data plus the same8KiB SRAM1 is incorrect.
The earlier generic capacity list is superseded by this per-wrapper inventory.
These independent memories are not one interchangeable SPAD. Native scalar
`sram_dp` ports are synchronous and dual-port with caller-specific ownership;
the imposed common16Bservice is not evidence of a native16Bport. No new native
latency or DMA/backpressure measurement was performed here.

Tiny actually contains LayerNorm, GELU, softmax, KV and LLM-oriented datapaths;
these must not be listed as absent. Reviewed `layernorm_engine.sv` supports
INT8/FP16 paths with source/Gamma on one port and Beta on another.
`gelu_lut.sv` uses an 8-bit LUT approximation to x·sigmoid(1.702x), scale32;
NMA uses a different piecewise Q8.8 INT32 contract. The native
`gpt2_block_top.sv`/C++ testbench connects real GEMM/SFU and a C++ DMA shim.
Existence of these engines is not proof of exact NMA Golden compatibility.
NMA's qualified H32 is a synthetic period-3 model, not pretrained GPT-2/Qwen.
Numeric conversion or unsupported exact graph mapping must be labeled
NOT_VERIFIED, not replaced by uncharged host work or declared impossible.

Historical conv1x_mini Golden is `ad 7f 80 08`: NMA1,874CMDQ+1,080testbenchlayout
excludes3,456Bpreload; Tiny4,742start→DDRoutput includes1,088Bload/4Bstore, plus
24configurationclocks outside. NMA compute traffic3,360/1,600B and layout144/576B;
Tiny native SRAM1,596/1,528B. No common DRAM timing: neither4,742/1,874 nor
4,742/2,954 is a valid system speedup.

A future full-system comparison needs the same graph, weights/input/output,
quantization/LN/GELU/softmax algorithms, memory latency/backpressure and commit
endpoint, with all DMA/layout/host work separately measured. Both projects'
source SHA and exact elaboration parameters must accompany results. Model
accuracy, exact Golden and fault-contract scope are necessary, but do not make
an asymmetric timing boundary fair. No complete CNN/Transformer winner or
TinyNPU system-speedup claim is made in Phase 3.
