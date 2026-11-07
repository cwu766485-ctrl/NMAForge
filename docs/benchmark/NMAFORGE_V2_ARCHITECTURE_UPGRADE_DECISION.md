# NMAForge v2 Round 8 — Architecture Upgrade Decision

**Status: `RESEARCH_BASELINE_PARTIAL`**  
**Review base:** `e0c210685cb5eac463308c76d5ce22e03b6add72`  
**Work branch:** `feature/npu-architecture-v2` (isolated worktree during this round)  
**TinyNPU reference:** `8216c22b762011aa20c05fc2768423fd12dda59d`  
**VCS:** `V-2023.12-SP1_Full64`; Python `3.12.13`; seed `20261107`

This round stopped DC/PPA, SRAM macro integration, and full DV closure as
requested. The only RTL-adjacent edit is a testbench-only performance profiler;
product RTL, ABI-v7, the 16×16 INT8 array, and the 128 KiB four-bank candidate
were not changed. This report distinguishes new Round 8 measurements from
prior snapshots instead of presenting old results as measurements at `e0c2106`.

## Decision

The H=4 trained toy Transformer profile shows that single-token Decode is not
Matrix limited: SFU busy states take 4,537/5,715 cycles (79.4%), while Matrix
MAC-active state takes 32 cycles (0.56% of the doorbell-to-completion
interval). GEMV is not a useful M=1 optimization for the measured H=4 path:
the fixed-weight comparison recorded the same 5,715 Decode cycles and moved
144 B from writes to reads. Keep the default GEMM mapping for M=1. Batched
M=8/16 GEMV cache gains remain valid command-level results, not model Decode
speedups.

The trained ten-class CNN has a prior three-mode result: fused requant reduced
per-image CMDQ cycles 3,193→2,712, and Linear-Row removed a further
1,080-cycle **testbench-emulated** layout phase. The 396 samples produced
1,083,456 aggregate useful MACs, but each image is only 2,736 MACs; this does
not establish a single high-compute inference or a large-CNN utilization
result. Those CNN numbers are bound to the earlier Round 7 RTL snapshot and
are not represented as a fresh run on `e0c2106`.

The existing ping-pong VDOT scenario passes with 37 overlap cycles. A directed
Matrix-GEMM pipeline probe observed overlap but failed four output Golden
words. Therefore Matrix/DMA overlap is **not closed**. No full-system TinyNPU
speedup is proven because the available NMAForge and TinyNPU CNN endpoints
remain different.

## Phase 0 — Workload coverage and current profile

### Transformer profile (measured at the Round 8 source snapshot)

The reproducible model is a deterministically trained H=4, one-layer,
one-head INT8 toy network for a four-symbol cyclic next-token task. It is not
a pretrained language model. The Top CMDQ executes 46 prefill and 40 one-token
Decode descriptors, with no Host fallback in the model manifest. All 300
emitted tensor/final/KV comparisons and six completion-record checks passed.

| Phase | Useful MACs | Cycles | Matrix MAC-active | SFU busy | KV busy | No-engine remainder | SPAD read/write |
|---|---:|---:|---:|---:|---:|---:|---:|
| Prefill, 4 tokens | 512 | 5,682 | 32 | 4,136 | 96 | 1,290 | 1,936 / 1,072 B |
| Single-token Decode | 128 | 5,715 | 32 | 4,537 | 60 | 958 | 1,880 / 1,048 B |
| Total | 640 | 11,397 | 64 | 8,673 | 156 | 2,248 | 3,816 / 2,120 B |

Each phase’s exclusive categories sum exactly to its cycle count. DMA busy
event cycles are zero. The no-engine remainder includes command/control gaps
and dispatch; it is not a direct measurement of one dispatcher state. The
Matrix MAC number is a cycle count, not lane-level PE utilization. Useful MAC
rates are 0.0900 MAC/cycle in Prefill and 0.0224 in Decode; cycle-level
Matrix MAC duty in Decode is 0.56%. These are behavioral-SPAD Top cycles at a
10 ns simulation clock, not silicon latency.

The Decode Q/K/V projection plus packing commands account for 354 cycles
(6.2% of Decode): 99 projection cycles and 255 pack cycles. Even an
unrealistic zero-cost replacement of that entire group would cap end-to-end
Decode speedup at about 1.066×. Input sharing alone cannot remove the required
projection MACs, so a QKV fusion prototype needs evidence of real read/command
cost savings before RTL work.

### Workload representativeness

| Workload | Round 8 disposition | Evidence / limit |
|---|---|---|
| Trained ten-class CNN | Historical functional/performance baseline | 396 samples; 2,736 MAC/image; 1,083,456 MAC aggregate across serial samples; 96.97% classification accuracy; not a >100K-MAC single inference |
| H=4 Transformer | PASS for trained toy task | 86 descriptors; prefill 4/4 and Decode 1/1 task predictions; held-out 690/1008 (68.45%) on the synthetic cyclic task |
| >100K-MAC single-inference multi-layer CNN | NOT_RUN | No such model/mapper workload was added; do not treat dataset aggregate as one inference |
| H=16/32, two-head Transformer | NOT_RUN | Current trainer/Mapper is fixed to H=4/one head; this round did not expand it |

## Phase 1 — Shape-Adaptive GEMV decision

For the same fixed H=4 Transformer fixture, the earlier GEMM/GEMV comparison
recorded 5,715 Decode cycles for each policy. GEMV changed Decode traffic
from 1,880/1,048 B reads/writes to 2,024/904 B: +144 B reads, −144 B writes,
and no cycle reduction. The Round 8 trained-model run uses GEMM; the exact
trained weights were not also run through GEMV in this round. Therefore the
trained-model GEMV effect is **NOT_RUN**, and no single-token speedup is
claimed.

The existing standalone Matrix-core cache/prefetch ablation found B-fold
Cache ON reduced cycles for M=8/16, K=19/65, with shape-dependent prefetch
results (including a 2-cycle regression at 16×16×65 versus cache-only).
Those measurements use one Matrix command and behavioral SPAD; they are not
full Decoder measurements. No automatic Shape Policy, QKV fusion, or command
grouping RTL/software change was made. Current evidence supports leaving M=1
on GEMM and evaluating bounded reuse only on eligible batched shapes.

Machine data: [Round 6 cache/prefetch CSV](../../benchmark/v2_round6_gemv_four_way_20261106.csv),
[Decode mapping CSV](../../benchmark/v2_round6_transformer_decode_mapping_20261106.csv),
and the new [per-command Round 8 profile](../../benchmark/v2_round8_transformer_command_profile_20261107.csv).

## Phase 2 — CNN fused dataflow

The three-rung ten-class CNN experiment is retained as prior evidence at
product RTL SHA `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, testbench blob
`7e64344fbb9bdaed0fd4ce14e8cddb19231827f7`, seed `20261107`, VCS
`V-2023.12-SP1_Full64`. It is not a fresh `e0c2106` replay.

| Mode | CMDQ cycles/image | Testbench host-layout cycles | Recorded phase cycles | SPAD read/write B/image | Golden / accuracy |
|---|---:|---:|---:|---:|---|
| Legacy | 3,193 | 1,080 | 4,273 | 6,192 / 2,496 | 396/396 exact; 384/396 correct |
| Fused requant, native layout | 2,712 | 1,080 | 3,792 | 5,616 / 1,920 | 396/396 exact; 384/396 correct |
| Fused requant + Linear-Row | 2,712 | 0 | 2,712 | 5,472 / 1,776 | 396/396 exact; 384/396 correct |

Legacy→fused requant improves the CMDQ interval by 1.177× (15.1% fewer
cycles). Linear-Row removes the recorded 1,080-cycle layout phase; the
combined Legacy-to-Linear-Row interval ratio is 1.576× (36.5% fewer cycles). The
layout phase represents explicit testbench AXI transactions, **not measured
host CPU execution**. These modes do not establish results for the requested
larger CNN, and Linear-Row does not imply arbitrary layout conversion.

The same fixed `conv1x_mini.onnx` experiment has NMAForge 1,985 CMDQ + 1,080
emulated layout cycles for Legacy, 1,504 CMDQ cycles for Linear-Row, and 4,781
TinyNPU graph cycles. Golden passes on both. NMAForge excludes preload,
descriptor programming, and final host read; TinyNPU includes graph dispatch
and its DMA/SRAM shim. Do not divide these endpoints into a system speedup.
See [Round 7 CNN ablation CSV](../../benchmark/v2_round7_cnn_fused_modes_20261107.csv)
and [paired TinyNPU CNN CSV](../../benchmark/v2_tinynpu_current_d1867da_cnn.csv).

## Phase 3 — DMA / Matrix overlap

The current `ai_smoke` run passes the existing three-tile VDOT ping-pong
test: outputs 10, 8, 12; completed tiles 3; overlap counter 37 cycles. This
demonstrates overlap for VDOT only.

A separate exploratory 3-tile Matrix GEMM probe measured total 145, DMA 109,
Matrix compute-active 60, overlap 31, stall 7 cycles, but four destination
words (first tile `[12:15]`) were X. A readback of the corresponding SPAD row
returned `0xffffffff`, so the Matrix result existed in SPAD while the tested
external output image did not match. The probe was removed from the default
smoke so the regression remains green. The raw probe log was not retained;
the observation is recorded as **FAIL / non-reproducible exploratory data**,
not as a performance result. Root cause was not proven and no product RTL was
changed. This is within the two-attempt bound; do not expand it in this round.

Machine disposition: [overlap evidence CSV](../../benchmark/v2_round8_dma_compute_overlap_20261107.csv).

## Phase 4 — TinyNPU comparison

The reference remains pinned to
`8216c22b762011aa20c05fc2768423fd12dda59d`. The fixed mini CNN uses identical
ONNX model/input/Golden hashes in the earlier paired test, but the endpoints
are not equivalent, so there is no cross-system speedup. Existing GEMM/GEMV
records separate NMAForge Matrix/controller + behavioral SPAD, TinyNPU direct
array RTL, and any common-memory service estimate; modeled memory is not
TinyNPU system RTL. These are prior baseline results at the source SHAs stored
in their CSVs, not new measurements at the Round 8 source.

This round did not rerun the 3-GEMM/4-GEMV TinyNPU matrix, mini CNN, or a
shared Transformer subgraph against `e0c2106`; those remain open. The local
rerun precheck found no `verilator` executable, and Python 3.12.13 lacks the
required `onnx` and `numpy` packages, so the TinyNPU replay is
**BLOCKED_ENV** in this container. Prior fixed-SHA data remains usable only
at the source SHAs and endpoints recorded in its existing CSVs. Current data
supports architectural diagnostics, not a claim that NMAForge is faster
overall.

## Phase 5 — overlap with Figure 8 architecture directions

| Direction | Round 8 outcome |
|---|---|
| P0 Single-token Transformer Decode | Profiled; bottleneck is SFU plus no-engine/control interval, not Matrix MAC. GEMV M=1 is cycle-neutral in prior comparison. No QKV fusion added. |
| P1 CNN high-utilization dataflow | Existing fused/Linear-Row gains retained; no >100K-MAC single-image workload or new tiling optimization. |
| P2 DMA/Compute overlap and scheduling | VDOT overlap passes (37 cycles); Matrix GEMM probe fails Golden and is not accepted. No scheduler RTL change. |
| P3 TinyNPU matched benchmark | Fixed reference and prior matched workload retained; no new current-source full-system speedup. |

## Reproduction and evidence

New R8 profile run:

```bash
cd dv/subsystem/top_smoke/sim
make ai_transformer_trained \
  PYTHON=python3.12 \
  AI_TRANSFORMER_TRAINED_MODEL=/tmp/nmaforge_r8_transformer_h4_seed20261107.json \
  AI_TRANSFORMER_SEED=20261107 AI_TRANSFORMER_STEPS=20000 \
  AI_TRANSFORMER_MANIFEST=/tmp/nmaforge_r8_transformer_h4_manifest.json \
  AI_TRANSFORMER_MAPPING_POLICY=gemm SEED=20261107
```

It produced model SHA-256 `001550dbadb816e66f737f5f6cba0819f51821c71a78d84861d62dc80dd8511f`,
input-token canonical SHA-256
`e934acc71fa990307b01a99a2767523e496d94cc2301a98fedaef58b17463310`,
expected final/KV canonical SHA-256
`b20103c75ccd1ad15f57c82a3f664889b9fb127bf6af8b55d8a72b25b935c2f3`, and
manifest SHA-256 `177390884b5de4335d88424452c1b90e671c5abe1588769002ddde34d5602ee6`.
The raw VCS log remains at the local generated path
`dv/subsystem/top_smoke/sim/ai_transformer_trained.log`; generated VCS files
are not committed.

Final smoke command:

```bash
cd dv/subsystem/top_smoke/sim
make ai_smoke AI_RANDOM_CASES=0 AI_SEED=20261107 SEED=20261107
```

Result: `TEST PASS`, including the existing `0x52`, `0x53`, Matrix/SFU
forwarding, and three-tile VDOT checks. It is a directed smoke, not full DV
closure. The profiler source is included in the Round 8 branch snapshot; its
testbench content is identified by blob hash
`a9df17f58195ded79b1ff53f90764529edd7c8c9`.

The phase profile is in
[`v2_round8_transformer_phase_profile_20261107.csv`](../../benchmark/v2_round8_transformer_phase_profile_20261107.csv);
all 86 descriptor intervals are in the per-command CSV linked above.
The inherited CNN, GEMV, and TinyNPU measurements link to their source-bound
prior CSVs. No synthesis, ASIC PPA, macro integration, or full DV closure was
run in this round.

## RTL module map and learning path

The current architecture remains the existing shared-array design:

| Layer | RTL / software | Responsibility | Useful entry point |
|---|---|---|---|
| ABI mapping | `sw/tools/cimforge_mapper.py` | H=4 Transformer descriptor/tensor layout, 0x30/0x52/0x53 descriptors, independent integer Golden | `make ai_transformer_trained` |
| Queue/lifecycle | `rtl/control/queue/ai_command_processor.v`, `rtl/control/descriptor/ai_descriptor_validator.v` | Fetch, validate, dispatch, wait, completion ownership | Top smoke |
| Scheduling | `rtl/control/queue/ai_parallel_compute_dispatcher.v` | Dependency and engine dispatch; no new scheduler in R8 | Top smoke / tile pipeline |
| Matrix controller | `rtl/compute/matrix/ai_tensor_matrix_core.v` | GEMM, K-fold GEMV, prefetch/cache, epilogue and writeback | Matrix block tests; Top GEMV/GEMM cases |
| Shared compute array | `rtl/compute/matrix/ai_tensor_matrix_array.sv` | One 16×16 INT8 MAC array with local accumulation | Matrix array / core tests |
| SFU / Transformer ops | `rtl/compute/sfu/ai_tensor_sfu_core.v` | Softmax, LayerNorm, GELU, pack/requant and residual operations | 86-descriptor Top run |
| Elastic tile pipeline | `rtl/compute/pipeline/ai_tile_pipeline.v` | Two tile buffers and DMA/compute scheduling | A2 ping-pong smoke (VDOT) |
| External data movement | `rtl/dma/ai_axi128_dma.v` | AXI bursts, SPAD transfers and response drain | DMA UVM / Top smoke |
| SPAD admission | `rtl/memory/ai_spad_arbiter.v`, `rtl/memory/ai_scratchpad.v` | Four-bank arbitration, registered reads and storage | Top / Matrix focused tests |

For a first source walkthrough, follow descriptor construction in the Mapper,
then command ownership in `ai_command_processor`, then the Matrix controller
and array for `0x30`/`0x52`/`0x53`, then the SFU and SPAD response mux. The
existing [Architecture Walkthrough](../architecture/NMAFORGE_V2_ARCHITECTURE_WALKTHROUGH.md)
has the block diagram and command/data flow. It now links this R8 profile as
the measured performance example.

## Open issues and final state

| Item | State |
|---|---|
| Transformer bottleneck profile, trained H=4 toy weights | PASS |
| H=16/32, two-head trained Transformer | NOT_RUN |
| M=1 GEMV model-level gain | No gain in historical H=4 comparison; trained-model GEMV replay NOT_RUN |
| >100K useful MAC per single CNN inference | NOT_RUN |
| Fused/Linear-Row ten-class CNN | Historical PASS at Round 7 source SHA; not a new e0 replay |
| Matrix GEMM + DMA overlap | FAIL exploratory Golden; not retained as a regression |
| TinyNPU system-level speedup | NOT_PROVEN; endpoints differ |
| 128 KiB SRAM physical cost / ASIC PPA | NOT_RUN this round by scope |
| Full DV / Coverage closure | OUT OF SCOPE |

The project remains **`RESEARCH_BASELINE_PARTIAL`**. This round adds a useful
cycle-closed Transformer profile and preserves truthful performance limits;
it does not complete every Figure 8 direction or establish TinyNPU
superiority. No next-round implementation is started here.
