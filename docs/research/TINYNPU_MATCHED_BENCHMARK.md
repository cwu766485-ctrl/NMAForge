# Stage A fair benchmark and measured bottlenecks

Status: **DESIGN_PARTIAL**. No system-level TinyNPU superiority is established.
Pinned TinyNPU `8216c22b762011aa20c05fc2768423fd12dda59d`; NMA product pins,
hashes, arithmetic, ports, latency and classifications are machine-readable in
[manifest](../../benchmark/research/stage_a/manifest.json). All newly reported
results below have public compressed logs/CSV traces in that archive.

## Comparison eligibility

| Class | Result / boundary | Eligible ratio |
|---|---|---|
| MATCHED_COMPUTE | Same INT8 input → stable raw accumulator; inclusive clear/feed/drain, no SRAM or memory commit | Array-only cycles, equal-frequency assumption |
| MATCHED_CONTROLLER_MEMORY | No common clocked memory/commit adapter yet | NOT_RUN |
| NATIVE_END_TO_END | Complete host preprocessing through output/postprocess on both designs absent | NOT_MEASURED |
| MIXED_MEASURED_MODELED | Tiny native graph with byte-serial C++ DMA; NMA separate native CMDQ/layout measurement | No system ratio |
| NOT_COMPARABLE | Full trained CNN / full Post-LN H16 across designs not jointly mapped | No ratio |

Cycle counts are primary. H16/trained CNN use 4 ns simulation clocks, common CNN
10 ns; these are harness settings, not Fmax. **400 MHz means 2.5 ns**;
4 ns means250 MHz. Tiny Verilator ticks do not demonstrate silicon frequency.
Area, power, energy and achieved timing are unmeasured.

## Matched compute, including limitations

Both arrays use the identical signed-byte fixtures and independently computed
raw integer sum, tolerance0, no overflow on these fixtures. NMA accumulators are
64-bit internally, Tiny32-bit. Trained Q/K/V additionally compare every raw word
against the shared Python reference; quantization is common host work excluded
from both timers. No clocked output-memory drain is included on either design.

| M×N×K | NMA clear/preload/execute | NMA cycles | Tiny clear/feed/drain | Tiny cycles | Tiny/NMA array ratio |
|---|---|---:|---|---:|---:|
| 16×16×16 | 1/1/16 | 18 | 2/48/4 | 54 | 3.000 |
| 16×16×32 | 1/1/32 | 34 | 2/96/4 | 102 | 3.000 |
| 32×32×64 | 4/4/256 | 264 | 8/768/16 | 792 | 3.000 |
| Trained Q, K, V each4×16×16 | 1/1/16 | 18 | 2/48/4 | 54 | 3.000 |

Useful MAC/cycle for the three GEMMs: NMA227.56/240.94/248.24;
Tiny75.85/80.31/82.75. QKV validates192 words/design. This ratio describes the
**checked-in driving schedules**, not a lower bound on Tiny's array latency or
proof of an optimal Tiny schedule. Tiny's harness explicitly inserts a 48-clock
wavefront per K16 block and four final drain clocks; further pipelining could
improve it. NMA broadcasts 16 A+16 B bytes/clock after preload; physical fanout,
64-bit accumulation and resulting area/frequency costs are not normalized.
Array performance is not a new forwarding contribution.

Product `0x52` is a separate k-fold controller path. Tiny's four fresh padded
GEMV array cases (1×13×17,8×16×19,16×16×19,16×16×65) all pass Golden at
102/102/102/246 inclusive cycles. Existing NMA product tests and smoke pass;
these endpoints are **NOT_COMPARABLE**, so no product GEMV ratio is derived.
Historical NMA fixed-controller919 vs Tiny array792 for32×32×64 is similarly
unequal and is not evidence of either system winning.

## Trained CNN: full NMA accounting

Same model, deployed weights, dataset, held-out sample42 and output hash across
all mappings. Independent integer Golden20,800 words/mapping; exact same832-word
output snapshot and correct class1. Three newly replayed mappings:

| Mapping | CMDQ cycles | Useful MAC/cycle | Compute SPAD read/write B | Input/weight/descriptor DMA window / busy cycles | AXI DMA payload B |
|---|---:|---:|---|---|---:|
| Legacy A0 | 65,429 | 8.7142 | 130,624 / 83,200 | 3,051 / 2,911 | 11,072 |
| First fused | 22,983 | 24.8081 | 77,376 / 29,952 | 3,035 / 2,895 | 11,008 |
| Both-fused row-major A1 | 12,351 | 46.1634 | 64,064 / 16,640 | 3,019 / 2,879 | 10,944 |

Internal NMA mapping ratios are5.2975× legacy/both-fused and1.8608×
first-fused/both-fused; these are not TinyNPU comparisons and not new RTL changes.
Useful570,164 versus padded692,224 MACs must not be interchanged.

Host preprocessing resize/planes/Im2col/quantization takes0.551–0.765 ms in this
single-run set; subsequent binary packing and descriptor generation are not in
that timer and remain NA. Queue configuration is54 cycles /9 AXI-Lite writes;
descriptor bytes are already in the DMA payload, not a second payload charge.
CMDQ starts at the existing queue-run window and ends at all output/completion
commits; includes dispatch and materialization, excludes initial DMA and host.
DMA payload includes initial sparse touched regions and descriptors, not all
zero-filled memory-image holes. Busy cycles are contained within the DMA window.
Output-only AXI-Lite readback832 words=3,328 B takes4,992 cycles; debug Golden
reads20,800 words are excluded. Host GAP+argmax median5.99–6.53 μs over100 timed
repetitions after warmup, separate CPU wall time. Do not convert host seconds
into RTL cycles or label a sum of partial segments complete native latency.
External DRAM wire bytes/DRAM-controller timing remain unmodeled.

Exclusive both-fused CMDQ partition sums12,351:

| Phase | Cycles |
|---|---:|
| Initial matrix fetch | 589 |
| Matrix prepare/execute | 3,380 |
| Matrix prefetch wait | 3,037 |
| Matrix writeback state | 5,200 |
| Matrix lifecycle | 67 |
| No-engine descriptor / completion request | 16 / 8 |
| No-engine control/response/dispatch remainder | 54 |

Actual MAC-active clocks2,704 produce692,224 padded MACs. Prepare/execute is a
larger state bucket, not all useful compute. Writeback5,200 includes packing and
control; line-valid clocks1,040 alone miss most of this state cost. Only12
banked-admission stall clocks are observed; that does not prove physical bank
conflicts. ACT1 remains13,312 B/832 accepted line reads for every mapping.
A cache cannot be credited with eliminating all writeback clocks.

## Common conv1x_mini: actual native graph audit

Pinned model hash and compiler-generated program/tdesc/DDR/golden hashes are
archived. Both designs match all four output bytes `ad 7f 80 08` (signed
−83,127,−128,8). NMA executes8 descriptors,1,874 CMDQ cycles; separate testbench
layout service is1,080 clocks /144 B reads+576 B writes. Its compute traffic is
3,360 B reads+1,600 B writes,1,872 useful MACs. Initial SPAD image writes3,456 B
are outside that timer and have not been assigned a matched DMA latency.

Tiny's actual `onnx_sim_top` graph runs **4,742 start→DDR-output-committed cycles**,
plus24 clocks program/descriptor configuration before start. Old “DONE at4781”
is an absolute clock: reset/release15+program13+tensor-descriptor11=39 clocks
precede start. Upstream replay and the passive new harness agree4781−39=4742.
The wrapper data SRAM is65,536×8 = **64 KiB**, not256 KiB; separate scratch8 KiB,
accumulator1 KiB, program16 KiB and tensor table8 KiB must not be conflated.
NMA native comparison uses128 KiB data SPAD.

Tiny exclusive graph partition:
DMA emulation1,103; matrix fetch2,304; array wavefront264; matrix store212;
matrix control40; other graph818; start/finish1; sum4,742. Seven modeled DMA
commands load1,088 B and store4 B. Data SRAM port-enable reads1,596 B,
writes1,528 B include DMA service; scratch/accumulator traffic is not counted.
Native arithmetic/control is RTL; external byte-serial DMA is C++, not AXI4 RTL.
Thus this is MIXED_MEASURED_MODELED, and **no 4742/1874 or 4742/2954 system
speedup is reported**. Largest jointly validated graph here is conv1x_mini;
matched memory timing remains open. The trained570,164-MAC graph has no Tiny
full mapping in this stage.

## H16: exclusive cycles and actual traffic

One persistent simulation, one reset/model load, eight teacher-forced decode
tokens. Total65,771 = **8,221.375 cycles/token**, read72,448 B/write42,112 B.
Useful18,240 MACs total =0.2773 useful MAC/cycle. Four-token QKV/KV-only prefill
2,728 cycles,3,072 MACs; this must not be called full prefill. Each token keeps
required INT32 tensors and bit-exact logits/KV. See architecture spec for quality
and host-embedding boundaries.

| Exclusive decode phase | Cycles |
|---|---:|
| Matrix initial fetch | 1,152 |
| Matrix prepare/execute | 2,080 |
| Matrix prefetch wait | 1,416 |
| Matrix writeback | 1,696 |
| Matrix lifecycle | 256 |
| SFU fetch states | 34,888 |
| SFU arithmetic/cache/control | 10,259 |
| SFU writeback | 4,232 |
| SFU lifecycle | 216 |
| KV busy | 3,152 |
| Other engine | 0 |
| No-engine completion request | 1,824 |
| No-engine descriptor request | 592 |
| No-engine control/response/dispatch remainder | 4,008 |
| **Total** | **65,771** |

Matrix MAC-active1,664 clocks is distinct from2,080 prepare/execute. Exclusive
priority is Matrix→SFU→KV→other→no-engine requests→remainder, appropriate for
this serialized dependency flow; it is not a causal attribution scheme for all
parallel workloads. Scalar688/banked776/line288 admission stall clocks overlap
these buckets and must not be added. DMA busy0 refers only to the timed
resident decode window, not initial loading. Physical bank conflicts were not
separately measured; dispatch-only causal stall attribution remains unresolved.

Closed descriptor intervals attribute inter-command gaps to the next descriptor:
Residual+LN30,752; QKV9,136; attention-score/Softmax/AV8,547; FFN6,256;
KV materialization5,152; output projection/merge4,720; LM head1,208.
These sum65,771; they are an alternative grouping, not extra costs.
LN19,776 + Requant14,832 + Residual11,136 =69.55% of decode intervals.

Current length16 cache has already eliminated variance/affine X reads.
Each LN still accepts16 X+16 Gamma+16 Beta reads and16 INT32 writes.
It has no coherent Gamma/Beta lifetime contract across descriptors. Prior B1
scheduling already overlaps Gamma multiply/Beta fetch; repeating that proposal
would double-count an implemented optimization.

## Scaling conclusions and negative results

Large GEMM controller evidence in the existing scheduling archive has fixed
response-model32×32×64 exclusive initial38, prepare/execute320, writeback256,
prefetch300, lifecycle5 =919 cycles. This is historical same-RTL controller
analysis, distinct from new array264; response assumptions differ from actual
top SPAD. Read scheduling reduces wait, but Tiny controllers are still unmatched.
Trained CNN shows large writeback/packing and prefetch costs as output tiles
increase. H16 shows the opposite priority: only6,600 Matrix busy clocks versus
49,595 SFU busy clocks. A GEMM-only improvement cannot explain away SFU traffic.

For longer context, score/AV arithmetic, KV copying and Softmax length scale;
for H/layers, projection/FFN weights scale approximately L·H² and KV L·C·H.
Only context visibility5,6,7,8 then ring8 is actually measured; no empirical
large-model extrapolation is claimed. H32/H64 allocation budgets precede any
larger-model execution. No full matched CNN or Transformer system result yet
qualifies the >1.10× stretch targets. All observed negative/unequal cases remain
visible rather than being excluded from a ranking.
