# Stage C — Matched TinyNPU benchmark

Scope: **matched adapter-model advantage; no demonstrated end-to-end advantage**.
NMA baseline commit `4e65a2ac2fc176acc5621aebec000874f2c5ab24`, unchanged product
RTL tree `479f24f33af0ccfa87fd7458ac9c43f94aae7398`.
TinyNPU is pinned to `8216c22b762011aa20c05fc2768423fd12dda59d`; source checkout
is clean. Final Stage C source hashes and final Git commit identify all harnesses.

## Common clocked memory service

`prepare_bench.py` generates SV/C++ harnesses around each actual256-MAC array.
Both use identical serialized INT8 operands and independent exact INT32 Golden.
Inputs pass through explicit serviced operand arrays: each128-bit operand line
costs one issue + two response clocks, one outstanding, no read/compute overlap.
Each output tile commits64×128-bit lines to the testbench output memory at one
line/clock. Output files come from committed values, not an earlier accumulator
snapshot. Service capacity is modeled128KiB; padding zero lanes and full tile
write traffic are charged identically. Reset/fixture preload are outside timing;
first read issue through last output commit, including array clear/feed/drain,
is inside. Exact phase sums and output Golden pass9/9 shared cases.

This is a common **testbench service adapter**, not either production memory
controller. It has no bank conflicts, permission/parity faults, DMA, descriptors,
AXI backpressure, native controller scheduling or finite physical macro timing.
SRAM interface request/response constraints are implemented as fixed cycle-level
harness phases, not a proposed replacement RTL interface. Neither design is
charged native graph overhead in these rows. The Tiny tiled wavefront schedule is
the existing conservative48cycles/K16 harness, not a proven optimal Tiny schedule;
NMA uses its native load/MAC alternation. Thus ratios describe **these schedules
under this service model**, not architecture upper bounds or implementation Fmax.

| M×N×K / operation | NMA cycles | Tiny cycles | Tiny/NMA adapter ratio |
|---|---:|---:|---:|
|16×16×16|178|214|1.2022|
|16×16×32|290|358|1.2345|
|32×32×64|2,056|2,584|1.2568|
|1×16×32|290|358|1.2345|
|H32 Q/K/V each4×32×32|580|716|1.2345|
|H32 FFN Up4×128×32|2,320|2,864|1.2345|
|H32 FFN Down4×32×128|1,924|2,444|1.2703|

H32 rows use final trained Layer0 weights and independent first-token live-row
operands, plus three zero padding rows. They compare raw GEMM only: original
model shifts, saturation, LayerNorm, Softmax and GELU remain outside these rows.
The first token's Q/K/V input is identical; FFN operands come from the independent
integer reference. This demonstrates executable larger shared Transformer linear
subgraphs, **not an entire matched Transformer**. Shared hashes, exact Golden,
read/write bytes and read/compute/write clocks are in `matched/matched.csv/json`.
All `system_speedup` fields are null.

Native NMA data SPAD128KiB/four32-bit banks; compatibility512KiB remains. Tiny
native data SRAM64KiB/8-bit synchronous readA/writeB; separate8KiB scratch,
1KiB accumulator,16KiB program and8KiB tensor descriptors are not pooled data SRAM.
The common modeled service is intentionally wider and larger than Tiny native
memory; it isolates arrays and must not be presented as Tiny's actual system.

## Native conv1x_mini replay

Same pinned ONNX/input/quantization/bias-order contract; four output bytes
`ad 7f 80 08` (−83,127,−128,8) match exactly on both implementations.

| Measurement | NMA | Tiny |
|---|---:|---:|
|Measured native compute/graph window|1,874 CMDQ|4,742 start→DDR-output commit|
|Additional testbench layout service|1,080 cycles|included in native graph|
|Configuration|outside CMDQ|24 cycles before start|
|Compute SRAM read/write B|3,360 /1,600|1,596 /1,528 native SRAM accesses|
|Layout read/write B|144 /576|included above|
|Initial NMA host SPAD preload|3,456 B, outside timer|DMA model below|
|Tiny C++ DMA load/store|NA|1,088 /4 B|

Tiny phase sum: DMA emulation1,103, Matrix fetch2,304, wavefront264,
store212, Matrix control40, graph other818,start/finish1 =4,742.
C++ byte-serial DMA costs one tick/load byte and two/store byte plus completion;
there is no common external AXI/DRAM latency. NMA layout/preload, descriptors and
output-memory endpoints differ, so **no native CNN or system speedup is computed**.
The trained570,164-MAC NMA CNN separately remains12,351CMDQ cycles,64,064 read B,
16,640 write B and20,800Golden words; it is not the same graph as conv1x_mini.

## Evidence classes and limits

- Array-only: fresh18/34/264 versus54/102/792 clocks on the three fixed shapes,
  plus192raw H16QKV words/design match; pinned Tiny engine regression passes. Native
  array clear/feed/drain endpoints are comparable, but exclude all memory.
- Controller + memory: NMA block randomized-response ablation is fresh; there
  is no matched Tiny production-controller counterpart. Ratios are forbidden.
- Common adapter model: the9rows above have identical service phases and outputs.
- Native graph: conv1x_mini outputs match; endpoint/DMA/memory differences remain.
- End-to-end Transformer: no matched Tiny two-layer fixed-point nonlinear/KV
  graph is available. No end-to-end speedup claim.

Signed INT8×INT8 exact accumulation has no overflow in fixtures, bias/shift and
nonlinear quantization are disabled in common raw rows. Native CNN uses its
compiler's per-stage integer rounding and bias order; full NMA Transformer uses
NMA's SFU contract. Output equality of one CNN alone does not make these entire
hardware numeric contracts equivalent. Equal cycle clocks do not establish equal
physical frequency.400MHz/2.5ns remains an unverified implementation target.
