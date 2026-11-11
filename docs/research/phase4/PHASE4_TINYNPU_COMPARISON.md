# Phase 4 — benchmark boundaries and TinyNPU

NMA product base `c93ea144713d5fafe2e8a5509029927cd6859e75`, measured modified RTL
checkpoint `73ebc74f5e155c614d3eeb4f5bee12315ed7f633`. Both native128KiB/four-bank,
256INT8MAC;512KiB compatibility only. Leonui/tiny-npu pinned
`8216c22b762011aa20c05fc2768423fd12dda59d`, local source SHA rechecked.
Tiny results below are **archived fixed-source evidence**, not new Phase4 runs.
The changed NMA0x53 pack/commit mechanism is outside raw0x30common-adapter work;
no historical raw cycle number is silently relabeled a new candidate result.

| Boundary | Evidence | Permitted conclusion |
|---|---|---|
|Raw INT8 GEMM|Historical common-adapter signedINT8→INT32 exact sums|Raw math/adapter only|
|Same adapter QKV/FFN|H32 linear subgraphs exact raw sums|No LN/GELU/quantization/KV/dispatch included|
|Native controller|Different memory and DMA/layout services|No matched system ratio|
|Complete CNN|New NMA trained CNN Golden, Tiny native mapping not established|No complete-CNN speedup|
|Complete Transformer|New NMA H16/H32 strict Logits/KV/tensors, Tiny exact math unverified|No complete-Transformer speedup|

Historical common-adapter NMA/Tiny cycles:16×16×16 178/214;
32×32×64 2056/2584; H32Q/K/V580/716each; FFN up2320/2864,down1924/2444.
Allowed raw-adapter ratios1.20–1.27×. Both256MAC,128KiB modeled backing,
16Bservice,two response edges,one outstanding read,serialized service and
charged output commit. Adapter replaces native services and does not prove
native capacity/port efficiency. See Phase2 matched CSV/JSON and Phase3 contract.
No Phase4 result transforms those ratios into system-level victory.

Native Tiny geometry varies by wrapper: pinned onnx_sim_top data64KiB,
softmax scratch8KiB,ACC1KiB plus program/tensor memories; gpt2_block_top data
8KiB+4KiB,scratch8KiB,ACC1KiB,ucode16KiB at defaults. Separate dual-port
synchronous memories are not an interchangeable128KiB SPAD or native16Bport.
NMA has one scheduler admission/edge,4Bscalar/16Bline shared service,2-edge
response and separate Host port with conflict semantics,128bitAXI4DMA and
AXI-Lite/CMDQ/CPLQ. Actual error/permission contract is retained.

Tiny has native LN/GELU/softmax/KV/LLM blocks; do not call them absent. Its GELU
LUT x·sigmoid(1.702x),scale32, differs from NMA INT32Q8.8piecewise math. Exact
whole-graph quantization, memory/DMA/backpressure, host work and commit endpoints
must match before claiming native/full-system speedup.

Historical conv1x_mini same four-byte Golden `ad 7f 80 08`: NMA1874CMDQ plus
1080testbenchlayout excludes3456Bpreload; Tiny4742start→DDRoutput includes
1088Bload/4Bstore plus24configuration clocks outside. Neither4742/1874 nor
4742/2954 is a system-speedup comparison.

Phase4 actual trained NMA CNN570164usefulMAC:11376CMDQcycles,50.1199MAC/cycle,
19.5781% full-window useful utilization; compute64064/16640B. DMA3019cycles,
10944B, outputreadback4992cycles/3328B, queue setup54cycles. Compute+DMA partial
sum14395cycles, versus15370baseline; no continuous system timeline/host runtime
included. Host Im2col/layout/pack and final GAP/argmax outside CMDQ, historical
Python timings separate units. Full-system latency NOT_MEASURED.
H16/H32 same8tokens65771/350155cycles,8221.375/43769.375cycles/token;
read/write72448/42112B and546816/227840B. Strict Golden PASS; model quality scope
is documented in CNN ablation. No H32 system throughput or Fmax claim.

Fresh memory/accepted payload and exclusive cycle evidence is archived with
source/Golden hashes, VCSversion and boundaries. CNN gain7.8941% is a same-endpoint
NMA baseline/candidate comparison only. Tiny native matched controller/whole-model
benchmark and integrated host/DMA inference remain open design/freeze obstacles.
