# Phase 2 — fixed-model performance and benchmark boundaries

**Measured LN32 result: 367,051 -> 350,155 CMDQ cycles / eight persistent H32
decode tokens; 45,881.375 -> 43,769.375 cycles/token, 4.603175% fewer cycles.**
Same fixed weights, inputs and independent Golden; no retraining or numerical
contract change. H16 and CNN cycle counts remain identical.

## Reproducibility contract

RTL baseline/Phase1 merge/candidate source identities are recorded in
[the implementation report](PHASE2_LN32_IMPLEMENTATION.md). Tools:
VCS V-2023.12-SP1_Full64, Verilator5.052, Python3.12.13; quality evaluation uses
torch2.7.1+cpu. Top uses128KiB four-bank SPAD (8192words/bank),256INT8MACs,
4ns simulation clock and behavioral registered reads with a measured two-edge
scheduler response. AXI DMA is128bit. These are simulation model conditions;
no area/Fmax or400MHz implementation claim follows.

Public raw paired traces, execution commands, response ledgers, source/workload
SHA256 and Golden hashes are in `benchmark/research/phase2/`. Immutable Phase1
fixture payloads and trained model/checkpoint remain in
`benchmark/research/phase1/`; no duplicate training was required.

Qualified H32 model SHA256:
`fc9c8a9fbcccf556e7a8281b06ee0e75827ca9264424f57ff66f5d82b7c6de78`.
H16 model SHA256:
`e7a521c762b66e5754d6d95c411c163452e0c9b01088cb11631202338cd28225`.
The manifest pins CNN weights, fixture and independent Golden too.

## Boundary A — accelerator command execution

The passive monitor assigns one exclusive bucket per CMDQ window cycle; sums
match measured command-start-to-completion windows. DMA preload, software
Im2col/layout, AXI-Lite output readback and host GAP/argmax are excluded.
Overlapping counters such as prefetch/compute overlap and arbitration wait are
reported separately and never added to exclusive totals.

| Fixed workload | Before cycles | After cycles | Compute SPAD read / write B after | Golden |
|---|---:|---:|---:|---|
| Qualified H32 decode8 | 367,051 | 350,155 | 546,816 /227,840 | PASS |
| Qualified H32 prefill4 | 181,329 | 172,881 | Per-window clients.csv | PASS |
| Historical H32 decode8 | 367,788 | 350,892 | 546,816 /227,840 | PASS |
| H16 persistent decode8 | 65,771 | 65,771 | 72,448 /42,112 | PASS |
| CNN both fused row-major | 12,351 | 12,351 | 64,064 /16,640 | PASS |
| CNN first fused | 22,983 | 22,983 | 77,376 /29,952 | PASS |
| CNN legacy | 65,429 | 65,429 | 130,624 /83,200 | PASS |

All accepted SRAM client/address/read-write/byte/bank-mask sequences match
between each pair, including control-plane traffic in measured windows.
The table's byte totals count data clients; per-client CSV separately records
CMDQ reads, completions, DMA and checker accesses outside timed windows.
No traffic reduction is claimed for LN32.

### Exclusive H32 decode attribution

| Mutually exclusive category | Baseline | LN32 candidate |
|---|---:|---:|
| Matrix setup | 3,856 | 3,856 |
| Matrix operand fetch | 2,448 | 2,448 |
| Matrix operand wait | 14,600 | 14,600 |
| Matrix compute | 13,824 | 13,824 |
| Matrix writeback | 6,400 | 6,400 |
| Matrix completion | 232 | 232 |
| SFU fetch issue | 67,952 | 67,952 |
| SFU response wait | 134,144 | 134,144 |
| SFU arithmetic/control | 29,456 | 29,456 |
| SFU pipeline wait | 31,955 | 15,059 |
| SFU writeback | 26,640 | 26,640 |
| SFU completion | 448 | 448 |
| KV/other engine | 20,224 | 20,224 |
| Completion without engine | 3,872 | 3,872 |
| Descriptor without engine | 1,664 | 1,664 |
| Dispatch/control | 9,336 | 9,336 |
| **Total** | **367,051** | **350,155** |

Matrix remains41,360cycles; SFU falls290,595 ->273,699; LN32 alone
104,064 ->87,168 (128descriptors,813 ->681each). Thus the analytical16,896
bound is realized exactly for this fixed decode. SFU response-wait is now the
largest exclusive bucket. Prefetch/compute overlap12,224 and arbiter wait4,288
are unchanged overlapping observations, not extra elapsed cycles or proof of
physical bank conflicts. H32 uses213,504 useful MAC/8tokens,0.609741MAC/cycle
and0.238180% useful utilization across the full candidate CMDQ window; low
end-to-end array utilization reflects scalar SFU/graph overhead.

### Matrix/GEMV and CNN

| Native command shape | Cycles unchanged | Useful MAC/cycle | Useful MAC/(256 × full cycles) |
|---|---:|---:|---:|
| GEMM4×4×32 | 126 | 4.06349 | 1.58730% |
| GEMM16×16×16 | 186 | 22.02151 | 8.60215% |
| GEMM32×32×64 | 986 | 66.46653 | 25.96349% |
| Product0x52 GEMV1×16×32 | 143 | 3.58042 | 1.39860% |
| Product0x52 GEMV4×16×32 | 161 | 12.72050 | 4.96894% |
| Product0x52 GEMV8×16×32 | 213 | 19.23005 | 7.51174% |

Trained CNN useful MACs570,164 /12,351cycles =46.163388useful MAC/cycle,
18.032573% over full CMDQ. The existing82.37% compute-active counter uses a
different denominator and is not full-window utilization. H16 remains
8,221.375cycles/token. Per-window active-compute utilization is retained in
`workloads.csv` rather than conflated with these full-window numbers.

## Boundary B — system inference

**Full system inference latency: NOT_MEASURED.** The testbench includes
functional checking/poisoning and software stages with separate clocks. Do not
add host wall seconds to RTL cycles or treat checker overhead as inference.

Fresh CNN both-fused components, identical before/after:

| Component | Separate measurement |
|---|---|
| DMA preload | 10,944payload/AXI-read B;45AR bursts,684128bitbeats |
| DMA setup + transfer | 3,019cycles; DMA busy2,879cycles (overlapping subset) |
| AXI-Lite queue configuration | 54cycles |
| CMDQ execution | 12,351cycles |
| Output handling | 832words/3,328B AXI-Lite readback,4,992cycles |
| Layout | Host Im2col/operand packing;0x53 row-major output inside CMDQ |
| CPU postprocess | Host GAP/argmax, separate CPU timing |

Historical Phase1 host evidence: preprocessing0.000332701s and GAP/argmax
median10,341ns for the both-fused fixture; these were not remeasured as
candidate system latency. Test-only poison setup83,232B is excluded from
algorithmic DMA payload. Native H32 Top golden/checker sessions are not a
production host runtime; their total simulator duration is not system inference.
These Transformer fixtures preload/check tensors through the testbench AXI-Lite
path, not a measured production AXI4 DMA tensor pipeline; DMA byte/time totals
for a native H16/H32 system inference are NOT_MEASURED. Accepted scheduler
traffic outside command windows includes preload/checker traffic and must not
be relabeled as compute or algorithmic DMA traffic.

## Numeric and model quality checks

CNN keeps the trained570,164-MAC model, fixed image and independent20,800word
Golden in all three modes; original held-out INT8 accuracy96.1111% is retained
model metadata, not a new Phase2 dataset evaluation. Phase2 reruns the fixed
RTL sample plus independent tensor/output verification and preserves prediction.

H32 hidden32/layers2/heads2/context16/FFN128/vocab32 remains the qualified
synthetic period3memory task. A fresh replay of the fixed FP32 checkpoint and
INT8 weights uses128 disjoint-triple blind sequences,seed20261114,1,536next-token
predictions (positions4..15). FP32 accuracy100%, CE0.000295329;
INT8 accuracy100%, CE0.000684143, perplexity1.000684377. Unigram2.6042%,
trained bigram2.0833%, copy-current0%, lag3rule oracle100%. No train/validation
rotation overlap; the task is simple and this is not natural-language quality,
GPT-2/Qwen support or general unseen-task evidence.

All12stages (prefill4 +persistentdecode8) check Logits/KV/intermediates with
an independent integer reference. Qualified and historical models both pass;
92,928words/model are byte-identical between baseline, candidate and Golden.

## TinyNPU: only same-endpoint adapter claims

TinyNPU pinned source: `8216c22b762011aa20c05fc2768423fd12dda59d`.
Twelve fresh paired raw-accumulator workloads pass identical input/INT32 Golden.
Common adapter:16B service,2-cycle read response,one outstanding request,
128KiB backing; both arrays256MAC. Native SRAM is NMA128KiB vs Tiny64KiB.
Its endpoint is preloaded backing store -> clocked operand service -> raw
accumulator output commit, excluding native controllers/DMA/SFU/graph.

| Common adapter example | NMA cycles | Tiny cycles | Adapter cycle ratio Tiny/NMA |
|---|---:|---:|---:|
| GEMM4×4×32 | 290 | 358 | 1.23448 |
| GEMM16×16×16 | 178 | 214 | 1.20225 |
| GEMM32×32×64 | 2,056 | 2,584 | 1.25681 |
| H32 Q/K/V each | 580 | 716 | 1.23448 |
| H32 FFN up | 2,320 | 2,864 | 1.23448 |
| H32 FFN down | 1,924 | 2,444 | 1.27027 |

These are existing array behavior under a common service model; LN32 does not
participate. Adapter results cannot be compared directly to the native CMDQ
cycles above. Native CNN/Transformer/full-system endpoints remain unmatched;
`system_speedup` is null in every record. There is no system-level victory
claim. The independent Lane/pack/layout/SFU/Host differences still limit a
whole-network TinyNPU comparison.
