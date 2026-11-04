# NMAForge v2.0 Architecture-First Baseline Audit

**Audit date:** 2026-11-04
**Frozen product baseline:** `origin/main` at `3041355528dffe856e2d5384027c6ee5df5d1b42` (R250)
**Development branch:** `feature/npu-architecture-v2`, created from that exact commit
**Scope:** Phase 0 inventory and reproducible pre-optimization measurements. This is not a v1.0 sign-off promotion.

## 1. Repository and branch audit

The original shared checkout was on `feat/shape-adaptive-gemv-v2` at
`c290eba7697138a4fcf2cbbac9262264849f0aeb`, with only the user-owned untracked
`novas.conf` and `novas.rc`. Those files were left untouched. The v2 work is in
an isolated worktree at `/tmp/nmaforge-architecture-v2` so it does not alter
that checkout.

The selected product base is published `main` R250, matching the supplied
plan. The separate closeout-audit branch is at R316 and has substantially
newer sign-off evidence. Its only RTL path differing from R250 is
`rtl/memory/ai_spad_arbiter.v`, which adds alternating priority between Matrix
banked reads and CNM lane requests. That change is intentionally not mixed
into this R250 architecture baseline; its fairness behavior must be reviewed
and replayed before it becomes a v2 product dependency.

The local and published Shape-Adaptive GEMV branches are highly divergent from
R250 (the remote branch is 64 commits ahead and 345 behind). No branch merge
was made. The two research RTL modules and their testbench already exist in
R250 with identical blob IDs to the research branch:

- `rtl/research/ai_shape_adaptive_gemv.sv`
- `rtl/research/ai_shape_adaptive_gemv_spad.sv`
- `dv/research/shape_adaptive/tb_shape_adaptive_gemv.sv`
- `dv/research/shape_adaptive/tb_shape_adaptive_gemv_spad.sv`

This avoids reimplementing or wholesale-importing the research branch's
unrelated RTL, verification, benchmark, and documentation changes.

## 2. Current top architecture and data flow

```text
Host CPU
  ├─ AXI4-Lite, 32-bit register access
  └─ AXI4 DMA, 128-bit data / 64-bit address
       │
       ├─ CMDQ descriptors → command processor / parallel dispatcher
       │                      → seven compute engines
       │                      → ordered completion writer → CPLQ
       │
       └─ DMA data movement ───────────────────────────────┐
                                                          ▼
                    compute engines → sole SPAD arbiter → four-bank SPAD
                         32-bit word / 128-bit line        4 × 32K × 32-bit
                                                          = 512 KiB
```

`ai_accel_top` is the integration top. `ai_accel_compute_cluster` is a
structural wrapper; it does not own DMA, CMDQ/CPLQ, or the scheduler-side SPAD
arbiter. `ai_spad_arbiter` remains the sole scheduler-side SPAD admission
point. The four-bank behavioral/XPM SPAD has a 32-bit core word path, a
128-bit line path, and dedicated four-lane CNM/banked interfaces. The product
Matrix controller uses both banked reads and 128-bit line output when aligned.

Normal CMDQ dispatch permits different engines to overlap, with at most one
active command per engine and in-order completion retirement. This is engine
concurrency, not unrestricted same-cycle access to each SPAD bank; all traffic
still passes through the common arbiter and its current response ownership
rules.

## 3. Seven-engine RTL inventory

The widths below are source-level RTL interface widths. They are not claims
about inferred SRAM macro ports or post-synthesis physical resources.

| Engine | Main RTL | Local request/response interface | Datatype and arithmetic |
|---|---|---|---|
| Scalar INT8 | `rtl/compute/int8/ai_int8_compute_core.v`, `ai_int8_datapath.v` | 32-bit byte address, 32-bit packed read/write data, `valid/ready` plus registered 32-bit response | Four signed INT8 lanes per 32-bit word; signed 64-bit running sum; arithmetic shift, activation, then signed INT32 saturation |
| Mixed FP dot | `rtl/compute/fp/ai_mixed_precision_dot_fp32_core.v` and FP helpers | 32-bit word request/response; two-entry A/B pair buffering; one 32-bit FP32 result write | Two FP16 or BF16 values per word; ordered, non-fused FP32 accumulation |
| Banked CNM | `rtl/compute/cnm/ai_banked_cnm_core.v`, `ai_bank_local_controller.v`, `ai_bank_pe.v` | Four request-valid bits and four 32-bit byte addresses; four 32-bit response words with per-bank valid/parity | Four signed INT8 products per 32-bit operand word, bank-local dot4 partials and global reduction |
| Tensor Matrix | `rtl/compute/matrix/ai_tensor_matrix_core.v`, `ai_tensor_matrix_array.sv`, `ai_tensor_matrix_datapath.v` | Four-bank 32-bit read data, banked 32-bit address, scalar 32-bit SPAD port, 128-bit line write and 16-bit WSTRB | 16×16 signed INT8 array (256 MACs); 16-bit products; signed 64-bit PE accumulators; bias/arith-shift/activation/signed-INT32 saturation |
| SFU | `rtl/compute/sfu/ai_tensor_sfu_core.v`, `ai_tensor_sfu_math.v` | 32-bit scalar SPAD request/response and 32-bit writeback | Fixed-point word operations per `docs/spec/SFU_NUMERIC_CONTRACT_ZH.md`; includes requant/packing, softmax, norms and activations |
| Conv line buffer | `rtl/compute/cnn/ai_conv3x3_linebuffer_core.v` | 32-bit scalar SPAD request/response and 32-bit output | Signed INT8 input in the low byte of each word; 3×3 accumulation and INT32 output |
| KV cache | `rtl/compute/kv/ai_kv_cache_engine.v` | 32-bit scalar SPAD request/response; 32-bit source/destination byte addresses and strides | 32-bit word copy with token/head address generation; it is not an attention MAC engine |

The cluster's common per-engine completion/data vectors are seven bits and
224 bits respectively (seven 32-bit results). Opcode selection and descriptor
validation remain in the control path, outside the cluster wrapper.

### Existing Matrix resource budget visible in RTL

At `ARRAY_SIZE=16`, the Matrix core currently declares:

- 256 signed 8×8 multipliers and 256 signed 64-bit accumulators (2 KiB of
  accumulator state, excluding implementation overhead).
- Two A operand banks and two B operand banks, each 16 × 32-bit words: 256 B
  total for these staging registers.
- An A-tile reuse cache of 16 K-words × 16 × 32 bits: 1 KiB, plus valid/group
  tags. It is bounded; larger K spans bypass this cache.
- A four-entry ordered read-response metadata FIFO. Each entry stores 53 bits
  of operand/group/K/address information; the read interface has no response
  ID, so order is part of the contract.
- A 128-bit line write path with full 16-bit WSTRB for aligned Matrix output;
  unaligned-to-line but 32-bit-aligned output falls back to ordered word writes.

These are RTL register/array declarations, not an area estimate. The current
Matrix descriptor uses four-element K words and requires Matrix M/N tile
alignment; it cannot issue the research kernel's true M=1 descriptor through
the production Matrix path.

## 4. Existing feature comparison against pinned TinyNPU

TinyNPU is pinned for this audit to
[`8216c22b762011aa20c05fc2768423fd12dda59d`](https://github.com/harishsg993010/tiny-NPU/tree/8216c22b762011aa20c05fc2768423fd12dda59d).
The feature facts below come from that revision's README and the checked-in
NMAForge benchmark harness. The two projects' engine counts describe different
abstractions and should not be compared as if they were equivalent blocks.

| Area | NMAForge R250 | TinyNPU pinned revision | Comparison boundary |
|---|---|---|---|
| INT8 matrix core | 16×16 output-stationary array, 256 signed INT8 MACs | 16×16 weight-stationary systolic array; dual INT8/FP16 MAC datapath | Same nominal INT8 MAC count; dataflow and controller timing differ |
| Floating point | FP16/BF16 dot-to-FP32 exists; no FP16 Matrix GEMM path | FP16 GEMM and FP16 math/softmax/layernorm paths | Matrix-level FP16 GEMM is a clear NMAForge gap |
| On-chip storage | Four-bank SPAD, 512 KiB configured capacity, shared across seven engine classes | SRAM0 64 KiB plus SRAM1 8 KiB in the pinned README | Capacity and port bandwidth are not equal; raw cycle ratios are invalid |
| Scheduling | CMDQ/dispatcher with ordered completion and up to seven active engine classes | LLM microcode scoreboard/barriers and Graph-mode pipeline; 13 graph engine categories | Different command/control overhead and graph coverage |
| Memory interface | AXI4 128-bit DMA and arbiter-owned SPAD | On-chip SRAM / DMA system; the paired NPU array wrapper used by the current harness exposes no matching SPAD request/response port | TinyNPU common-memory values require a separately labeled adapter model |
| Model evidence | Trained INT8 Digits MLP runs on product top; current synthetic Transformer fixture is not pretrained inference | Pinned README reports real-weight GPT-2/LLaMA/Mistral/Qwen2 paths and ONNX Graph mode | Model claims require exact model/source/test reproduction, not engine-feature count |

The existing paired GEMM report uses an older NMAForge SHA and a modeled,
serialized TinyNPU memory service. It is useful historical evidence only; it
does not establish a same-SHA v2 performance result. Phase 5 must pin both
source trees and compare matching endpoints, memory traffic, and Golden data.

## 5. Reproducible R250 baseline runs

All runs below were executed from the clean v2 worktree at source SHA
`3041355528dffe856e2d5384027c6ee5df5d1b42` with Synopsys VCS
`V-2023.12-SP1_Full64`.

| Run ID | Command | Result |
|---|---|---|
| `V2-R250-ARRAY-SIZE-S20261025` | `make matrix-size-benchmark SEED=20261025 OUTSTANDING_DEPTH=2 NEXT_K_PREFETCH_ENABLE=0 A_TILE_CACHE_ENABLE=0 BENCH_OUT_DIR=/tmp/nmaforge_v2_baseline_matrix_r250` | PASS: five Golden-checked shapes each on 4×4, 8×8, and 16×16 arrays (15 cases) |
| `V2-R250-MATRIX-CONFIG-S20261026` | `make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=20261026 MATRIX_CONFIG_OUT=/tmp/nmaforge_v2_r250_matrix_config_seed20261026` | PASS: all eight depth/prefetch/cache configurations × five shapes (40 Golden points) |
| `V2-R250-GEMV-KERNEL-3S` | `make shape-adaptive-regress RUN_DIR=/tmp/nmaforge_v2_shape_r250 SEEDS='20261025 20261026 20261027' SOURCE_SHA=3041355528dffe856e2d5384027c6ee5df5d1b42` | PASS: 144 signed INT8 kernel comparisons across 12 shapes and four mappings; this is packed-operand kernel evidence, not product Matrix GEMV |
| `V2-R250-GEMV-SPAD-3S` | `make shape-adaptive-spad-regress RUN_DIR=/tmp/nmaforge_v2_shape_spad_r250 SEEDS='20261025 20261026 20261027' SOURCE_SHA=3041355528dffe856e2d5384027c6ee5df5d1b42 PYTHON=python3.12` | PASS: 12 workloads on real arbiter + four-bank behavioral SPAD; per seed includes 3 abort phases and reset with an accepted read. Still a research wrapper, not production Matrix command integration. |
| `V2-R250-TOP-SMOKE` | `make ai_smoke` from `dv/subsystem/top_smoke/sim` | PASS: product top ends `TEST PASS`, including the checked-in 86-descriptor fixture and random GEMV/GEMM/Conv checks. Existing fixture `[LOOP-REROLL-ENABLED]` warning remains. |
| `V2-R250-DIGITS-360` | `make -C dv/subsystem/top_smoke/sim ai_digits_inference AI_DIGITS_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python AI_DIGITS_RUN=/tmp/nmaforge_v2_digits_r250_20261104` | PASS: 360 samples, 352 correct (97.78%), 69 descriptors, 110,155 command cycles; independent integer Golden PASS. |

The Digits run used Python 3.12, NumPy 2.4.6, scikit-learn 1.9.1 and seed
`20261029`. Model SHA-256 is
`e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`; Golden
logit SHA-256 is
`8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc`.
Measured RTL layout work is 76,613 SFU busy cycles and 117,760 accepted SPAD
bytes; total Matrix/SFU work is 1,884,160 MACs (`mac=1884160`), 17.1046
MAC/cycle and 6.68% array utilization. The 250 MHz
normalization in Matrix logs is a reference calculation only, not measured
Fmax, ASIC throughput, area or power.

Raw VCS logs and model artifacts remain under the `/tmp/nmaforge_v2_*` paths
above and are not checked in. The reproducible Matrix configuration CSV and
Shape-Adaptive result CSV/JSON are checked in alongside this report.

## 6. Baseline conclusions and implementation boundary

1. The measured Digits bottleneck was the `REQUANT_I8` Matrix-A tile layout
   step: 76,613 of 110,155 command cycles were SFU busy in tile packing. The
   first follow-up implementation is now available as additive opcode `0x53`;
   on the matched 360-image workload it preserves every hidden word and logit,
   reduces command cycles to 34,761, and reduces hidden-activation movement by
   80%. See [Tensor Layout Optimization Report](TENSOR_LAYOUT_OPTIMIZATION_REPORT.md).
2. The current Matrix controller already has four-entry metadata capacity,
   next-K prefetch and bounded A-tile reuse. In the best eight-way measured
   configuration, 32×32×64 is 1,187 cycles and 384 bank reads versus 1,698
   cycles and 512 reads at depth-2/no-prefetch/no-cache (30.1% fewer cycles,
   25% fewer reads). On 16×32×32, the best combined configuration has 65 line
   stall cycles versus 22 at baseline, so output service remains a separate
   bottleneck.
3. Even with `MAX_OUTSTANDING_READS=4`, the current measured Matrix profile
   reaches an outstanding high-water mark of only 2 on the tested shapes.
   The 4-entry setting is capacity, not proof that four independent requests
   are continuously issued. Investigate this during the prefetch redesign.
4. Shape-Adaptive GEMV has functionally passing compute and real-SPAD research
   wrappers, but the wrapper serially loads operands before compute and has no
   product Matrix descriptor/controller integration. Its kernel's static
   policy uses an assumed input bandwidth and is not a production cycle model.
5. The v1.0 Compute Cluster state stays **HOLD**: R250 records 24
   `PASS-SCOPED` and 14 `PARTIAL`; the v2 branch does not promote v1 sign-off.
6. No ASIC PPA is run in this baseline. The behavioral SPAD has registered
   responses; 10 ns/250 MHz values are simulation parameters, not silicon
   timing or power evidence.

The fused-path evidence is a functional/performance experiment only. Its
new-op-specific Abort/Reset/fault and broader shape coverage remains open; it
does not change the v1.0 HOLD or imply v2 verification closure.

## 7. Minimum v2 feature verification

For every new v2 datapath change, retain and run the existing `ai_smoke` plus
an independent signed-INT8 Python Golden. The minimum focused suite is:

1. Legacy Matrix GEMM 16×16 and multi-tile GEMM, bit-exact against current
   output and Memory Image.
2. GEMV M=1,4,8,16 with non-multiple-of-16 K tails and masked N tails.
3. Shift, signed saturation, ReLU/ReLU6, and packed/native tile output layout.
4. SPAD same-bank contention and randomized ready/response latency with
   explicit response owner checks.
5. Backpressure while an output line is held, followed by Abort and Reset
   recovery with no stale writeback.
6. Full 360-image Digits Golden, accuracy, total cycles and SPAD byte counts.

Full v2 UVM/coverage closure remains a later phase, but these functional
checkers cannot be removed or weakened.

## 8. v2 progress — 2026-11-04

**Shared-array K-fold operand primitive** is committed at
`30e3ba81c675fe1612db1a393a8d3879aa80ba89`. The 16×16 array can select a
per-PE B operand view while reusing its existing 256 signed multipliers and
64-bit accumulators. A self-checking TB maps physical rows as
`(output_row, K-fold lane)` and checks signed reduction against a scalar
INT64 Golden, including a K=19 tail. This isolated primitive does not load
operands from SPAD and is not integrated into the product Matrix controller;
the controller ties K-fold mode low, so it is not product GEMV evidence.

| Run ID | Command / source | Result |
|---|---|---|
| `V2-KFOLD-ARRAY-S3-30e3ba8` | `make array-random-regress ARRAY_OUT_DIR=/tmp/nmaforge_v2_kfold_array_30e3ba8 SEEDS='20261101 20261102 20261103' ARRAY_SEEDS='20261101 20261102 20261103'` from `dv/block/compute/matrix/sim` | PASS: legacy GEMM array tests plus four K-fold shapes on each seed; ARRAY_SIZE 8 and 16; M=1/4/8/16 where legal; K=19 Golden reduction. Logs: `/tmp/nmaforge_v2_kfold_array_30e3ba8/` |
| `V2-KFOLD-TOP-SMOKE-30e3ba8` | `make ai_smoke` from `dv/subsystem/top_smoke/sim` | PASS `TEST PASS`; legacy product Matrix command path remains on GEMM mode. Existing Transformer fixture loop-reroll warning remains. |
| `SHAPE-ADAPTIVE-20261104-30e3ba81` | `make shape-adaptive-regress RUN_DIR=/tmp/nmaforge_v2_shape_30e3ba8 SEEDS='20261101 20261102 20261103' SOURCE_SHA=30e3ba81c675fe1612db1a393a8d3879aa80ba89 PYTHON=python3.12` from `dv/research/shape_adaptive/sim` | PASS: 144 signed-INT8 kernel comparisons. Cycle savings still use the explicitly labeled fixed-bandwidth analytical schedule, not integrated product timing. |
| `SHAPE-SPAD-30e3ba81c675fe1612db1a393a8d3879aa80ba89-20261104` | `make shape-adaptive-spad-regress RUN_DIR=/tmp/nmaforge_v2_shape_spad_30e3ba8 SEEDS='20261101 20261102 20261103' SOURCE_SHA=30e3ba81c675fe1612db1a393a8d3879aa80ba89 PYTHON=python3.12 SPAD_CSV=benchmark/shape_adaptive_spad_ablation.csv SPAD_JSON=benchmark/shape_adaptive_spad_summary.json` from `dv/research/shape_adaptive/sim` | PASS: 12 workloads across three seeds through the research wrapper, real arbiter/four-bank behavioral SPAD, contention, three abort phases and accepted-read reset recovery. This wrapper is still separate from product Matrix command dispatch. |

The new B matrix view declares 512 B across its two banks, within the 1 KiB
incremental v2 staging budget. Product controller integration, M/N/K
descriptor tails, SPAD request overlap, response ownership, and measured
controller-plus-SPAD GEMV cycles remain open; no GEMV product performance
claim is made from these primitive or research-wrapper runs.

## 9. Product GEMV integration follow-up — 2026-11-04

The first product controller slice is now implemented at opcode `0x52` for
dense ABI-v7 `M=4,N=16,K>=16` with K divisible by 16. The real Matrix
controller performs K-fold reduction using the shared 256-MAC array; the
descriptor validator rejects the unsupported `K=20` tail before dispatch.
The feature and exact supported-field boundary are documented in the [v2
specification](../spec/NPU_ARCHITECTURE_V2_SPEC.md) and the [GEMV
implementation report](SHAPE_ADAPTIVE_GEMM_GEMV_REPORT.md).

VCS `V-2023.12-SP1_Full64` three-seed regression on implementation/test
snapshot `70c8aad94e9e8d16bf67d0e4667effb58977ccf7` passes all 64 output words
against the independent Golden on each seed. The `M=4,N=16,K=32` controller
profile is 262 cycles, 8 MAC-active cycles, 64 accepted banked reads (1,024 B),
and 16 output line writes (256 B). Observed read outstanding high-water is 4;
fetch does not overlap MAC. The A operand lines are reread across four K-fold
uses, so this run provides functional integration evidence and exposes the
first throughput/traffic bottleneck; it is not a speedup claim. A real top
smoke passes a CMDQ descriptor with bias, shift and ReLU enabled, then rejects
K=20 without a destination write.

The implementation was clean-replayed from detached worktree SHA
`10aa2ed903cb5298317617a1ca7c2c15819774e7`: the product GEMV three-seed target
and `ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261104` both pass. Raw logs are under
`/tmp/nmaforge_v2_product_gemv_clean_10aa2ed/` and
`/tmp/nmaforge-v2-gemv-clean-10aa2ed/`.

This section records the initial M4/K32-only integration snapshot. Its then-
current K20-rejected boundary and profile are historical and were expanded by
the shape/tail follow-up below. Striding, batching, fault/Abort/Reset,
mutation, broad coverage, same-workload GEMM comparison, TinyNPU fairness,
and ASIC PPA remain open or `NOT_RUN`. The v1.0 Compute Cluster sign-off
remains **HOLD**.

## 10. Product GEMV A-line reuse — 2026-11-04

Commit `cf6cd1e1e81e9b9372c13a44e3fc64e775b4ca6` retains each staged A line
through the four K-fold uses in the supported dense `M=4,N=16,K=32` product
descriptor. GEMV explicitly bypasses the generic GEMM A-tile cache, whose
address tag alone does not encode the operand layout. Its directed test first
populates that cache with a legacy GEMM using the same A base, asserts that
the cache entry is valid, then checks the GEMV result remains bit-exact with
zero GEMV cache hits.

A matched three-seed VCS `V-2023.12-SP1_Full64` core comparison reports 269 →
214 Matrix command cycles (20.45% fewer) and 1,024 → 640 B banked operand
reads (37.5% fewer). Both runs use the registered behavioral-SPAD model,
`M=4,N=16,K=32`, the same workload/Golden, and seeds `20261104`–`20261106`.
Baseline source is detached SHA `8cff28689838d432151d8130b17db4e8a27c7632`
with A-tile cache disabled; optimized source is clean detached SHA
`cf6cd1e1e81e9b9372c13a44e3fc64e775b4ca6c`, where GEMV bypasses that cache.
Optimized logs are under `/tmp/nmaforge_v2_gemv_clean_cf6cd1e_core/`; baseline
logs are under `/tmp/nmaforge_v2_gemv_baseline_8cff286/`. Top Smoke passes on
the optimized clean SHA. These are Matrix-core behavioral-model results, not
TinyNPU results, full-chip speedup, or ASIC PPA. Fetch/MAC overlap, broader
shapes, fault/reset closure, and full v1/v2 sign-off remain open.

## 11. Product GEMV dense shapes and tails — 2026-11-04

The product controller and descriptor validator now support `1<=M,N<=16` and
`1<=K<=65535` for dense opcode `0x52`. Core VCS Golden checks cover M1/N13/K17
and M16/N16/K19 in addition to the original M4/N16/K32 case. The Top Smoke
CMDQ path validates M1/N13/K17 end-to-end, including the exact 13-word
completion count and untouched N-tail sentinels. See
[`SHAPE_ADAPTIVE_GEMM_GEMV_REPORT.md`](SHAPE_ADAPTIVE_GEMM_GEMV_REPORT.md) for
commands, Run IDs, profile, and evidence paths. Fetch/compute overlap, repeated
B traffic across row tiles, descriptor-wide shape coverage, and opcode-specific
error recovery remain open; sign-off remains **HOLD**.
