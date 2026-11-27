# Project update log

## NMAForge V1.4 Round 39 — Matrix GEMM read pipeline, VCS scratchpad fix, GPTQ INT4 (2026-11-27)

- **Result.** GPT-2 small, 12 layers, prompt + 8 decode, bit-exact on Product
  Top:
  - Round 38 program on the new RTL: 181,354,731 cycles (−18.1% vs 221.5M);
  - GPTQ INT4 for all weights: 164,124,531 cycles (−25.9%);
  - against the Round 36 baseline these are −50.6% and −55.3%.
  - GPT-2 1-layer final configuration: 10.42M (−19.0%).
  - DeiT layer 0: 2.85M (−13.9%).
- **RTL (ABI unchanged).** In `ai_tensor_matrix_core`:
  - bias tiles read as banked lines;
  - GEMM operand staging with self-timed per-buffer prefetch
    (`ENABLE_GEMM_OPERAND_STAGE`), so a decode K group takes about 5 cycles
    instead of 8.5.
- **Bug fix.** In the `+define+VCS` scratchpad model, line reads now have
  two register stages, matching XPM `READ_LATENCY=2`. With one stage, a line
  access in the next cycle overwrote the data the arbiter returns two cycles
  after the request. The faster Matrix exposed this: a queued DMA store wrote
  old ACC data into the DDR K cache. The defect predates this round.
- **Compiler.** GPTQ error propagation for INT4 block-exponent weights
  (`--no-gptq` disables it). Integer PPL on 10×256 windows, INT8 51.25:
  - INT4 MLP: 58.14 → 54.60;
  - INT4 everywhere: 64.14 → 58.35 at 0.53× weight bytes.
- **Not adopted.** `0x52` GEMV for decode: measured, not faster.
  `DMA_MAX_BURST_BEATS=32`: passes, but the near-zero-latency AXI model cannot
  show its gain; the default stays 16.
- **Verification.**
  - Top: smoke, `ai_run 20/12345`, qdma+INT4 self-test, DMA block TB,
    `uvm_compile`.
  - Block: matrix regressions (bias-line faults added, 38 → 40 faults),
    4×4 handoff build, DMA/SPAD subsystem.
  - UVM: control (9 tests) and DMA (19 tests).
  - NOT RUN: SpyGlass, formal, DC. Staging flops and the bias-line path are
    open PPA items.
  - The 4×4 `core-random-test` `run_outstanding_abort` failure reproduces on
    the Round 38 HEAD.

See the [report](benchmark/NMAFORGE_V1_4_ROUND39_MATRIX_DECODE_GPTQ.md).

## NMAForge V1.4 Rounds 37–38 — queued DMA overlap, GEMM accumulate, INT4 weights, LN fast path (2026-11-27)

- **Result.** GPT-2 small, 12 layers, prompt + 8 decode steps, bit-exact on
  Product Top: 221,473,132 cycles end to end. Round 36 was 366.9M (compute +
  fenced DMA), so this is −39.6%. DeiT-Tiny 12 layers: 39,211,913 cycles,
  against 45.7M in Round 35 (−14.1%).
- **RTL.** Four changes:
  - queued DMA `0x60` as dispatcher engine 7 (`CAP2[8]`);
  - GEMM accumulate epilogue, `0x30/0x31 flags[7]` (`CAP2[9]`);
  - INT4 block-exponent expansion on DMA load, `0x60 flags[1]` (`CAP2[10]`);
  - SFU stream row cache of 1024 entries, so LayerNorm with D ≤ 1024 uses the
    fast path.
  `CAP2=0x7ff`.
- **Accuracy.** Integer GPT-2 PPL on 10×256 windows: INT8 51.25; INT4 for the
  MLP only 58.20 (0.69× weight bytes); INT4 everywhere 64.14 (0.53×). The
  reported final configuration uses INT4 for the MLP only.
- **Verification.**
  - Top: smoke and `ai_run 20/12345`.
  - Block: qdma+INT4 self-test, matrix regressions with new accumulate
    cases, descriptor validator, SFU stream equivalence (3 seeds × 2 latency
    modes) plus act-modes, DMA block TB.
  - UVM: control (9 tests) and DMA (19 tests).
  - NOT RUN: SpyGlass, formal, DC. The SFU cache area is an open disposition
    item.
- **Bank lanes.** Dropped from the innovation list (2026-11-27). The measured
  SFU share (7–16%) caps the gain.

See the [report](benchmark/NMAFORGE_V1_4_ROUND37_38_MODEL_OPTIMIZATION.md).

## NMAForge V1.3 Round 36 — official GPT-2 small prefill + KV-cache decode on Product Top (2026-11-26)

- **Result.** The new `sw/compiler/gpt2_compile.py` runs official `gpt2`
  (124M) on Product Top at 512 KiB SPAD, bit-exact against the integer Golden:
  - **12-layer prefill.** 32 WikiText-2 tokens: 11,860 descriptors, 319,488
    checkpoint words and 24,576 final words. Compute window 106.6M cycles,
    fenced DMA 16.9M.
  - **Prefill + KV-cache decode.** 1 layer with debug checkpoints: 32-token
    prefill plus 4 decode steps, with 120 DMA stores. The 12-layer prompt +
    8-step decode run also passes: 43,473 descriptors, 2,592 DMA stores,
    399,360 checkpoint words; compute window 212.2M cycles (prefill 32.7M,
    about 22.4M per decode token), fenced DMA 154.7M; VCS wall 100.9 min.
- **Decode schedule.** Each step recomputes the 4-token row group, so no hidden
  state is kept. Per-head K/V caches live in DDR, and Vᵀ columns go there via
  a 2D DMA store.
- **Accuracy.** Integer model, WikiText-2 40×256: gpt2 PPL 55.94 (FP32 50.56);
  distilgpt2 83.43 (FP32 75.22). The contract is the Round 35 one plus
  SmoothQuant folded into LN/V, per-head and per-64-chunk power-of-two scales,
  and exact accumulator doublings for coarse product grids.
- **Runtime.** Program format v2 adds 1D/2D DMA loads and stores; the TB still
  accepts v1, and the DeiT layer-0 program replays with identical cycles. New
  `AI_COMPILED_AXI_WORDS` and `+AI_COMPILED_SEG_TIMING`. Long RESIDUALs are
  chunked to stay under the dispatcher's 65,535-cycle dependency-wait limit.
- **Verification.** `make ai_smoke` passes after the TB changes.
- **Bottlenecks.** Partial-sum RESIDUALs (about 50% of prefill), M=4 GEMMs
  and the fenced weight DMA in decode (about 40M cycles per token). Next:
  DMA/compute overlap, a GEMM accumulate epilogue and INT4 GEMV.

See the [report](benchmark/NMAFORGE_V1_3_ROUND36_GPT2_ON_PRODUCT_TOP.md).

## NMAForge V1.3 Round 35 — official DeiT-Tiny 12-layer encoder on Product Top (2026-11-26)

- **Result.** The new compiler (`sw/compiler`) and the TB `+AI_COMPILED_PROGRAM`
  runtime run all 12 DeiT-Tiny encoder layers (official weights, an ImageNet
  validation image) bit-exact on Product Top at 512 KiB SPAD: 16,128
  descriptors, 491,712 checkpoint words and 37,824 final words. The
  classification is correct.
- **Cost.** The compute window is 37.5M cycles (150 ms at 250 MHz). Fenced DMA
  is 6.6M cycles on the stress AXI model.
- **Accuracy.** The integer accuracy model reaches 75.6% top-1 vs FP32 78.0%
  on 500 images.
- **Host-side stages.** The embedding and classifier head stay on the host.

See the [report](benchmark/NMAFORGE_V1_3_ROUND35_DEIT_ON_PRODUCT_TOP.md).

## NMAForge V1.3 Round 35 — official GPT-2/DeiT numerics and SFU flag[7] modes (2026-11-25)

- **Numerics study.** The current contract fails on official models (GPT-2
  small PPL 212, DeiT-Tiny 32.4%). Root causes are floor rounding,
  truncated Q7 probabilities and the PWL GELU. With an LN rounding offset,
  SmoothQuant folded into LN, rounded probabilities and a GELU LUT, the models
  reach GPT-2 PPL 56.4 (FP32 50.6) and DeiT 77.2% (FP32 78.0%). See the
  [report](benchmark/NMAFORGE_V1_3_ROUND35_DEPLOYMENT_NUMERICS.md).
- **RTL.** SFU `flags[7]` adds a programmable 256-entry LUT activation on
  0x35 (rounded INT32→INT8 code, LUT at src1, REQUANT layouts including
  Matrix-A tile packing) and round-to-nearest on 0x36. Unsupported placements
  return ERR_CONFIG. The validator rejects packing on plain GELU.
- **Verification.**
  - `act-modes-regress`: 3 seeds × 108 Golden cases, legacy-reject and
    packed-GELU-reject checks, and 2/2 mutations detected.
  - SFU stream equivalence, legacy SFU random, `ai_smoke` and the 20-case
    seeded regression pass.
  - Cluster UVM 128/512 KiB × 3 seeds: ERROR/FATAL=0.
  - GPT-2 H64: bit-exact, 384,617 cycles.

## NMAForge V1.3 Round 35 step 1 — integration, 512 KiB SPAD, DMA bandwidth (2026-11-25)

- **Integration line.** `integration/nmaforge-v1.3` merges Round 34 and the
  active working branch, and is a superset of `main` and
  `candidate/frontend-closeout`. Smoke, seeded, SFU equivalence, GPT-2 and
  cluster UVM at 128/256/512 KiB all pass.
- **SPAD default.** It is now 512 KiB in both RTL and SPEC.
- **DMA beat counters.** They are now parameterized, so 32- and 64-beat bursts
  work.
- **DMA bandwidth.** A new performance memory model shows the 16-beat product
  reaching 76% of peak at 50-cycle latency and 48% at 100 cycles. 32/64-beat
  bursts reach 98%/96%.
- **Burst default.** It stays at 16 per SPEC pending approval.
- **Next step.** System gains are dominated by small host-fenced DMAs; the
  next step is DMA-in-CMDQ overlap.

See the [Round 35 report](benchmark/NMAFORGE_V1_3_ROUND35_INTEGRATION_AND_BANDWIDTH.md).

## NMAForge V1.3 Round 34 — Transformer operators, GPT-2 runtime and SFU fast path (2026-11-25)

Isolated branch `research/nmaforge-v1.3-round34-transformer-sfu` (base Round 33
`49221642`, uncommitted working tree; delta hash in the run manifest).

- **Operator comparison.** A matched start-to-done comparison against pinned
  TinyNPU first showed the legacy SFU at 1.5–4.8× more cycles. The new
  streaming fast path is 1.98× faster on GELU, 2.11× on Softmax(197) and 1.08×
  on LayerNorm(197), and ties on Residual. It is bit-exact; TinyNPU's INT8
  LayerNorm is numerically invalid on these inputs.
- **GPT-2 H64 decode.** Active-row SFU mapping, batch resident publication
  and zero-time checkpoints give 7.65×. Adding the SFU fast path gives 10.9×:
  4,190,904 → 384,617 cycles for three tokens, with every logit bit-exact.
- **DeiT.** The Round 31 attention+Wo 16-query slice drops from 811,476 to
  418,662 cycles.
- **Regressions.** SFU legacy-vs-fast differential (3 seeds × 2 timing modes),
  legacy SFU random, `ai_smoke`, the 20-case seeded Top regression and
  Compute Cluster UVM at 128/256/512 KiB all pass.
- **Not run.** DC/PPA, SpyGlass and formal on the new module.

See the [Round 34 report](benchmark/NMAFORGE_V1_3_ROUND34_TRANSFORMER_SFU.md).

## NMAForge V1.3 Round 32 — TinyNPU performance catch-up (2026-11-24)

Implemented and measured a bounded Product RTL optimization on isolated branch
`research/nmaforge-v1.3-round32-tinynpu-catchup`, based on
`8f2ed82c7d7a58885bc19f0b263490f7817a5f51`. The 64×64×64 GEMM B-panel cache
reduces fixed-memory cycles from 3,413 to 2,768 and SPAD reads from 20,480 B
to 8,192 B; all three seeded runs are below the 3,800-cycle minimum. The
minimum GEMV 1×64×64 target passes at 358 fixed cycles and 433/467/479 seeded
cycles after packing the wide operation into one descriptor. The GEMM challenge
cycle limit remains open; no TinyNPU cross-system ratio or PPA result is
claimed. The existing 256-MAC array and default 128 KiB SPAD are preserved.

`ai_smoke` (four random cases), seeded Top 20-case regression, descriptor
validator, Compute Cluster UVM at 128/256/512 KiB, four-shape GEMM and GEMV
Golden suites, TinyNPU direct-array cases, TinyNPU CNN Golden, and NMAForge
Product Top ONNX Golden pass. Matrix FSM formal passes 5 assertions / 2 covers;
GEMV request-stability formal timed out at 360 s without a result. PPA remains
`BLOCKED_ENV` because `dc_shell` and `TSMC28_STDCELL_DB` are unavailable. Exact
target disposition and source/log identities are in
[`Round 32 report`](benchmark/NMAFORGE_V1_3_ROUND32_TINYNPU_CATCHUP.md),
[`evidence manifest`](../benchmark/performance_dominance/round32/evidence/run_manifest.json),
and the active [`execution frontier`](exec-plans/active/execution-frontier.md).

## NMAForge V1.2 integrated continuation — 2026-11-24

Work is isolated on `research/nmaforge-v1.2-integrated-model-dv` from base
`ad58507fa5052ccec61e05428c4e36e493796b8b`; `main` and Product RTL are
unchanged. P0 replays reproduced the Compute Cluster VDOT fixture failure:
reserved ABI flag bit 6 was set (`0x76`), causing the `CLUSTER_MEMORY_EMPTY`
secondary symptom after the sequence fatal. The fixture now uses `0xb6`; the
compact SPAD map checks `SPAD_INFO` and rejects out-of-capacity accesses without
changing Protection. UVM passes 128/256/512 KiB × seeds 20261025/26/27 (9/9),
and `ai_smoke` plus `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` pass. Exact
commands/log hashes are in
[`P0 manifest`](../benchmark/verification/v1_2_integrated_p0/run_manifest.json).

The selected GPT-2 QAT package
`d9ff47c56a4ddc335a34d601d2083cfa2967d179b6aa617fdb25e484a9af3bb4` now has a
paired four-layer Product Top prefix-recompute vs persistent incremental-KV
run. All four 256-logit contexts are bit-exact; persistent KV saves 131,040
command-path cycles (3.0195%) and 480 descriptor publications (15.5491%) on
the measured contexts. This does not change the below-Bigram model-quality
result or claim application latency. See
[`GPT-2 closure`](benchmark/NMAFORGE_V1_2_ROUND31_GPT2_QUALITY_CLOSURE.md).

DeiT Round 31 now passes one 16-query block through Product Top Attention, AV
requantization, official Wo DMA and final projection: 72,384 intermediate/final
Golden words, including 768 output words; 48 DMA events/37,632 bytes; 821,466
Product Top command-path cycles; zero host activation transfers. A first
software layout attempt treated the four AV panels as row-major and failed at
`0x3004`; row-group panel requantization fixed the producer/consumer layout and
the rerun passed. This is only 16/197 queries; the rest of Layer 0 and all
image-accuracy work remain open. The exact command, generated workload,
Golden, raw compressed logs and CSV are under
[`Round 31 DeiT evidence`](../benchmark/deit/round31/evidence/attention_output_projection_16q/).

The full RTM mapping, all-engine unified profiler, CNN fusion A/B and matched
TinyNPU comparison remain open. Current work and next tasks are in the
[`execution frontier`](exec-plans/active/execution-frontier.md).

## NMAForge v2.0 Round 3 — integrated research evidence (2026-11-15)

Combined Gate evidence on isolated branch `research/nmaforge-v2-round3-integration`, based on Round 2 SHA `6596779de2ec4f502a0253dedd4695129b775b05` and product PR #8 baseline `0492c47d12cd11bcc22be1930da7af77ed870b6e`. H64 Q projection through product Top passed with four legal tiled descriptors, 1,024/1,024 INT32 Golden words, 1,188 cycles, 65,536 useful MACs, 8,192 B reads and 4,096 B writes. Product Top smoke passed seed 20261115/four random cases. SVSE vector SPAD A/B passed numerical, abort, epoch and commit-prefix checks but was slower with unchanged traffic (Residual 46 vs 40 cycles; Requant 30 vs 22), so decision is `REWORK_FOR_PRODUCT`. DAMS remains unintegrated because the current prototype does not track transaction/address/response ownership and did not prove a scheduling opportunity beyond the product dispatcher. Full H64 decoder and A0-A3 remain NOT_RUN. See `docs/research/NMAFORGE_V2_ROUND3_FINAL.md` and focused reports.

## NMAForge v2.0 Round 3 — H64 projection Top bring-up (2026-11-15)

On product baseline `0492c47d12cd11bcc22be1930da7af77ed870b6e`, a nonzero H64 layer-0 Q projection now runs through the real Top. Four legal ABI-v7.4 Matrix commands each compute `M=16,N=16,K=64` (`k_words=16`) for one output-column tile. With four live input tokens and twelve zero-padded physical rows, the independent INT8 memory Golden checked all 1,024 INT32 output words. VCS `V-2023.12-SP1_Full64`, 128 KiB/4-bank behavioral SPAD, 10 ns simulated period: 1,188 command cycles, 65,536 useful MACs, 8,192 B SPAD read and 4,096 B SPAD write. Reproduce via `make -C dv/subsystem/top_smoke/sim ai_h64_projection_top AI_H64_PROJECTION_RUN=/tmp/nmaforge_h64_projection_replay AI_H64_PROJECTION_SEED=20261114` with NumPy in `AI_H64_PROJECTION_PYTHON`. This is only one H64 projection; full attention, decoder block, four layers, persistent decode, and pretrained weights remain NOT_RUN. See `docs/research/NMAFORGE_V2_ROUND3_H64_PROJECTION.md`.

## NMAForge v2.0 Round 3 SVSE vector SPAD A/B — 2026-11-15

On isolated branch `research/nmaforge-v2-round3-svse` based on `6596779d`, expanded the one-element SVSE adapter into parameterized vector read/compute/output-buffer/ordered-writeback behavior. Actual product `ai_tensor_sfu_core` opcode `0x34` and `0x36` were compared under the same deterministic registered-SPAD latency and backpressure model. Four-element Golden memory images matched; Residual measured product/SVSE 40/46 cycles and 8/8 reads + 4/4 writes; Requant measured 22/30 cycles and 4/4 reads + 4/4 writes. SVSE request stalls/response waits were nonzero. Abort read drain, accepted-write prefix, and epoch read drain all passed. Product integration remains blocked; current SVSE is slower because buffering is not overlapped with computation. See `docs/research/ROUND3_SVSE_VECTOR_SPAD_AB.md`.

## NMAForge v2.0 Round 2 — 2026-11-14

Corrected GPT-2-compatible reference on the PR #8 baseline: true Pre-LN FP32 and independent INT8 fixed-point references now pass, with 62-node H64 graph metadata; all H64 nodes remain BLOCKED/RTL NOT_RUN because current descriptor legality and ownership contracts do not support a legal lowering. Added registered-SPAD SVSE product adapter and fixed unary Requant stale-operand behavior. DAMS/SVSE standalone remains `DAMS_SVSE_PASS accepted=3 denied=1`; product arithmetic adapter is `SVSE_PRODUCT_ADAPTER_PASS residual=140 requant=127`. Real Top/Dispatcher integration is explicitly `BLOCKED_BY_CONTROL_CONTRACT`. See `docs/research/NMAFORGE_V2_ROUND2_STATUS.md`.

## NMAForge v2.0 Round 2 Gate 3/4 adapter — 2026-11-14

On research branch `research/nmaforge-v2-round2-dams` (product baseline `0492c47d`, research baseline `2d85b11e`), added a one-element registered-SPAD adapter for the SVSE prototype and a product arithmetic comparison test. VCS passed `DAMS_SVSE_PASS accepted=3 denied=1` and `SVSE_PRODUCT_ADAPTER_PASS residual=140 requant=127`; Requant was corrected to unary operand-A semantics after the first adapter run exposed stale operand-B use. Top/Dispatcher integration remains `BLOCKED_BY_CONTROL_CONTRACT` because the product command ID, completion, protection ownership and sole compute-SPAD mux contracts are not connected to the research adapter. No product RTL or ABI changed. See `docs/research/ROUND2_DAMS_SVSE_PRODUCT_ADAPTER.md`.

## NMAForge v2.0 Gate 0-2 — 2026-11-14

Research baseline fixed to PR #8 candidate `0492c47d12cd11bcc22be1930da7af77ed870b6e` in isolated branch `research/nmaforge-v2-product-baseline`. The existing Top Transformer fixture passed with 86 descriptors and full intermediate/KV/completion checks; the existing H16 incremental path passed four decode stages with independent Golden comparison and average 8,183.50 simulated cycles/token. New Gate 1 tooling generated the requested 4-layer/Hidden-64/4-head/FFN-256/vocabulary-256/context-16 deterministic INT8 fixture and 41-node lowering plan; Golden passed, but the fixture is explicitly pseudo-weight and RTL execution is NOT_RUN. New Gate 2 DAMS/SVSE synthesizable research prototypes passed an independent VCS testbench (`DAMS_SVSE_PASS accepted=3 denied=1`) without product ABI integration. See `docs/research/NMAFORGE_V2_GATE0_BASELINE.md` and `docs/research/NMAFORGE_V2_GATE1_GATE2_STATUS.md`. Reproduction uses VCS `V-2023.12-SP1_Full64`, Python environment `/tmp/nmaforge_round10_venv`, and the commands in those reports. No product branch or PR was merged.

## Round 27 — incomplete session

Prepared historical baseline extracts and an incomplete review at `docs/benchmark/NMAFORGE_V2_ROUND27_ARCHITECTURE_FREEZE_REVIEW.md`. Withdrew unsupported LayerNorm phase allocations; phases remain unmeasured. Corrected large GEMM historical read traffic to 6,144 B. No RTL experiment, simulation, synthesis, freeze decision, commit or push completed. Historical extraction uses `git show 800c5b0:<artifact-path>`. Git metadata writes failed with read-only `.git/index.lock`; escalation was aborted.

## GEMM / LN scheduling optimization — published candidate

Branch renamed to `nmaforge`; old remote `nmaforege` removed after verifying the
new remote. RTL/test SHA `b2b3b0b5942f9218ed574a04e946104109dc2c99`. Two bounded
changes overlap GEMM A/B prefetch and LN Gamma arithmetic/Beta fetch, with no new
data state or SPAD ports. Same H16 decode: 66,931 → 65,771 cycles / 8 tokens;
trained CNN CMDQ: 12,947 → 12,351, unchanged independent Golden and traffic.
Three-seed Matrix/SFU, depth-2/fallback, Top Smoke, 20-case seeded Top and paired
trained QKV pass. Tiny timing now distinguishes array phases and unmeasured
transfer/commit; no unequal-boundary system speedup. Basic lint warning counts
remain inherited; no physical Fmax claim. Status DESIGN_PARTIAL. Exact commands,
raw artifacts, timing boundaries and risks: [review](design/schedule_optimization/REVIEW.md)
and [reproduction](design/schedule_optimization/REPRODUCTION.md).

## 2026-11-10 — Final roadmap Stage A: fair benchmark and candidate review

Branch `nmaforge`, reviewed `da5a6691c7582d54c7a2da643e01d296f8da2d68`;
product RTL unchanged (`rtl` tree479f24f33af0ccfa87fd7458ac9c43f94aae7398).
Added passive DV phase/address/AXI observation, portable benchmark runners,
public hashed evidence and `docs/research/` architecture/proposal/freeze reports.
H16 persistent Golden65,771/8=8,221.375 cycles/token; CNN same-weight mappings
65,429/22,983/12,351 CMDQ cycles,20,800 Golden words each. New exclusive profiles
close to total cycles/accepted bytes. Tiny pinned native graph4,742 measured/
modeled cycles (old4781 includes39 prestart),64 KiB byte-wide data SRAM;
no system speedup from unmatched boundaries. Same-boundary array18/34/264 versus
54/102/792 is a harness compute-only comparison, not system or PPA evidence.

Replayed `make -C dv/subsystem/top_smoke/sim ai_smoke` and
`make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345`: PASS.
`core-tile-forward-ablation`,128 KiB common CNN, trained CNN/H16 Golden,
independent held-out reference, pairedQ/K/V and Tiny seven array cases/six engine
tests PASS. `python3.12 tools/benchmark/stage_a/validate.py`: PASS hashes,
cycle/byte closure, budgets and invalid-ratio rejection. Exact commands and tool
versions in `docs/research/REPRODUCTION.md`; no current-source synthesis/Fmax claim.
400 MHz is2.5 ns;4 ns is250 MHz. H32 allocation fits but untrained/unmapped;
H64 resident128 KiB allocation does not fit. A3 deferred for partial-sum/live-set
proof; B2 proposed128 B Matrix→Requant cache requires all-writer coherence and
parity/protection review. **DESIGN_PARTIAL; Stage A stops for architecture review,
no Stage B/C product edits or next stage automatically started.**

## 2026-11-10 — Stage B Matrix→Requant contract/model: REJECT

Baseline1b455b355c8604272cbc49a81f5564db9a4e4f05; independent candidate Worktree
`/tmp/nmaforge-stage-b-candidate`, branch`experiment/stage-b-matrix-requant`.
No product RTL/ABI/model/Golden edits. Gate0 real memory fabric+SFU VCS test
reproduces silent post-commit SRAM upset → ERR_PARITY/no outputs, write-allowed/
read-denied → ERR_PROTECTION, and ready-but-denied Line → no commit. A coherent
cached copy cannot observe unsignaled SRAM corruption; transparent read removal
is rejected. No Gate2 candidate RTL or B2-enabled measurement was fabricated.

Independent transaction suite7 tests PASS; replay64 dependency-proven leases/
2,048 reads/8,192 B,512 packed Golden words;47 latency/hit/invalidation model
cases. Ideal unapproved1-clock cache+2 clocks/lease estimates6.033% cycle saving;
strict per-read checking saves0 reads and proves no latency gain. New relaxed
fault-observation mode described for architecture review only; no bit allocated.

Fresh B1 persistentH16=65,771/8=8,221.375 cycles/token,72,448 read/42,112 write B;
all8 token metrics and9 full stage Golden snapshots identical to Stage A.
CNN three mappings65,429/22,983/12,351 cycles Golden PASS; focused SFU64+9 and
Matrix18+35 cases seed20261110 PASS; Top Smoke PASS. Exact commands, public hashes,
limitations and no-RTL ASIC disposition in
`docs/research/STAGE_B_TRANSFORMER_FORWARDING_REPORT.md` and
`benchmark/research/stage_b/manifest.json`. Actual added hardware state0; no
synthesis/Fmax/energy claim. **REJECT**; no A3 or next-stage implementation started.


## 2026-11-10 — Stage C architecture feasibility and H32 expansion

Status **PARTIAL** at unchanged product RTL tree
`479f24f33af0ccfa87fd7458ac9c43f94aae7398`, baseline `4e65a2ac`.
A3 transparent bypass REJECT: current SRAM parity/protection cannot be replaced
by a committed cached copy; Stage B fault contract VCS replay passes. K64 exact
four-part model matches3328 CNN outputs but512B does not establish a profitable
same-array continuation schedule; no product RTL experiment admitted.
H32/L2/heads2/context16/FFN128/vocab32 trained and mapped to existing ABI:
4full-prefill +8persistent-decode tokens,92928word strict Golden PASS,367788decode
cycles/8=45973.5/token,546816read/227840write B,79872B SPAD high water. Final
model's disjoint-trajectory test accuracy3.19% is explicitly a research limitation;
overlapping initial-seed metrics are withdrawn as generalization evidence.
H16 stays65771/8, CNN best12351cycles and independent20800wordGolden passes.
VCS Top smoke, seeded20,40Matrix config cases,16productGEMV ablations and9common
Tiny memory-service kernels pass. Native Tiny conv1x_mini4742cycles has unmatched
DMA/endpoints; no system speedup or frontend freeze/PPA claim. Reproduce with
`tools/benchmark/stage_c/run_top.sh`, `run_bench.sh`, `validate.py` and the exact
commands in `docs/research/STAGE_C_ARCHITECTURE_DECISION.md`. Evidence and SHA
inventory: `benchmark/research/stage_c/`. Stage C stops; no automatic Stage D.

## 2026-11-11 Asia/Singapore — SPAD128 Gate 0/1 candidate

Dedicated branch `feat/spad-128k-closure`, based on nmaforge `95c4387bb0ac57ff4fa427fd3c1202320ad0940b`: defaults aligned to8192words/bank (128KiB), optional32768 retained, constant geometry rejection, capacity-derived Digits/MiniCNN fixtures and concurrent smoke placements. Full smoke now checks final TEST PASS; original128KiB fixture failure (23 errors) retained. Isolated VCS replay: `SPAD128_OUT=<fresh-absolute-dir> SPAD128_PYTHON=<python3.12-with-model-dependencies> SPAD128_DATASET=1 bash tools/benchmark/spad128/run.sh`. Mandatory Golden, boundary, parity/protection and512KiB compatibility evidence is in `benchmark/research/spad128`; validate with `python3.12 tools/benchmark/spad128/validate.py`. H16=65771/8decodecycles, H32=367788/8, CNN bothfused=12351CMDQ cycles preserved. Verilator warnings match same-capacity baseline but remain unresolved, no signoff/PPA/Fmax claim. See `docs/design/SPAD_CONFIG_REGRESSION.md`. Stop for architecture review before Gate2/performance RTL; no product-branch merge.

## Phase 1 — architecture and benchmark closure review

Approved baseline `48790076b351cb9d49e1785247d32a1f51b8286d`, isolated branch
`feat/phase1-architecture-benchmark`; no product RTL changes. Passive monitor
closes every exclusive CMDQ window and scheduler read-response ledger. Fixed
Top GEMM4×4×32/16×16×16/32×32×64:126/186/986cycles; product0x52M1/4/8:
143/161/213cycles. TrainedCNN both-fused remains12,351 and H16Decode65,771/8,
strict Golden PASS. Qualified synthetic H32period3model:367,051/8Decode,
79.17%SFU; FP32/INT8blind accuracy100%, lag3ruleoracle100% (no language claim).
12common-adapter Tiny raw kernels PASS; no native/fullsystem speedup.
Verilator5.052 warning counts reproduced, temporary default diagnostic only;
all product warnings retain explicit dispositions. Recommend one next RTL
experiment: exactlength32LNmean/variance division specialization, analytical
≤4.60%H32cycle reduction; no implemented improvement claimed. Second candidate
prefetch scheduling deferred without incremental evidence. DESIGN_PARTIAL.

Reproduce with `tools/benchmark/phase1/README.md`; public proof:
`python3 tools/benchmark/phase1/validate.py`. VCSV-2023.12-SP1Top directed workloads,
independent Golden and20randomcases/seed12345 PASS; existingMatrix8config×5shape
ablation PASS. Main, product and other worktrees preserved. Six linked reports
under `docs/performance/`, `docs/research/` and `docs/design/` document boundaries,
model limitations, numeric/fault obligations and remaining freeze risks.

## Phase 2 — exact LN32 RTL candidate and streaming feasibility

Reviewed Phase1 `ae7fd31eced13dcb9dbd70533da60559511d0a90` (no product RTL
changes); merged and published `nmaforge` at
`cb08797e612355b404f9eb697a34f99628deebfd`. Dedicated candidate branch
`feat/phase2-exact-sfu` extends only exact length32 LN mean/variance division.
Measured fixed H32 eight-token decode367051 ->350155cycles (4.603175%);
H16=65771 and trainedCNN both-fused=12351 unchanged. Strict integer arithmetic,
mandatory SRAM address/order/traffic, Logits/KV/intermediate Golden, protection/
parity, reset/abort/watchdog, three-seed SFU and Top smoke/seeded20 PASS.
No new flops/ports/MAC or ABI change. No new focused lint warnings; inherited
Top issues remain and no area/Fmax/signoff claim is made. Gate2 requant model
projects conditional incremental43504cycles/12.4242% but does not prove dynamic
fault timing or closed-loop arbitration. No streaming RTL admitted/implemented.
Decision RETAIN_LN32 / DESIGN_PARTIAL. Five reports in `docs/research/phase2/`;
commands in `tools/benchmark/phase2/README.md`; public archive validated with
`python3 tools/benchmark/phase2/validate.py`. Stop after Gates1/2.

## Frontend closeout Gate2–5 candidate

Created isolated `candidate/frontend-closeout` from remote product c93ea14. Tested RTL fc60f95; retained protected ping-pong, bounded offline mapper, existing output DMA scheduling and source-fault response drain fix. Fixed mux combinational temporary and split return dependencies; Verilator LATCH10→0/UNOPTFLAT3→0. CNN11376cycles; delivery19507→15437; H16/H32 65771/350155. Scoped Golden/fault tests pass. Seven-engine UVM128KiB fails old0x7d000fixture; global DV HOLD. ASIC mapping blocked by absent configured libraries/macros/wrappers. No merge or PPA/signoff claim. See NMAFORGE_FRONTEND_CLOSEOUT.md and reproducible run.sh; evidence manifest pins RTL/workloads. Original worktrees and PR#5 preserved.

Descriptor-validator old reserved-bit vector corrected to bit8 (bit7 is existing Row-Major). Re-run PASS29legal/33invalid/43accepted/26rejected; failing-before log retained. SpyGlass single-clock depth256 CDC0errors/2warnings; final lint0errors/467warnings. No broad static waiver.

## 2026-11-13 — Compact SPAD line-stalled CNM Golden closure

On branch `experiment/compact-spad-dv`, preserved the existing uncommitted
fixture/monitor work. Reproduced seed `20261025` mismatch at cycle 39390:
CNM Golden[8] expected `0x12c8`, actual `0x109b`, address `0x14020`. A trace
replay with the original destination captured first corruption at cycle 34660:
CNM tag 5 wrote row 0 output `0x0a58` to `0x14000`, overwriting row 8/K0/lane0
in the live B image `[0x13000,0x15000)`. At cycle 35463 CNM read that location
and returned the overwritten value. Root cause is fixture allocation/lifetime;
no DUT RTL change.

Moved the line-stall CNM output to `[0x16000,0x16040)`, retained workload,
Golden, overlap and stall checks, and corrected compact fixture ranges/lifetimes
found by the full regression. Added a hard 128 KiB bound to `spad_write()`,
restored the original Matrix/CNM input images before parameter-latch tests, and
used parity-consistent descriptor backdoor mutation while scheduler traffic is
active. Full allocation map and transaction evidence:
`docs/verification/COMPUTE_CLUSTER_LINE_STALLED_CNM_FIX_2026-11-13.md`.

VCS `V-2023.12-SP1_Full64`: full Compute Cluster UVM seeds 20261025,
20261026, 20261027 PASS with 0 UVM warnings/errors/fatals per seed; line-stall
checks=92, violations=0, overlap=1840 cycles, seven-engine pair coverage=21/21.
`make ai_smoke` PASS; `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` PASS.
SpyGlass lint completed with 0 errors/467 warnings/5 infos; CDC setup 0 errors,
1 warning/9 infos; CDC structure 0 errors, 2 warnings/38 infos. RDC was
interrupted after remaining at `Ar_resetcross01` (385/478) with about 6.6 GB
RSS; it has no result. This is a DV bugfix closure, not static-analysis or
ASIC sign-off. Logs, coverage databases and URG report remain under `/tmp`.
# 2026-11-13 Compute Cluster DV Closure Round 2 baseline

- Reviewed `bugfix/compact-spad-line-stalled-cnm` (`76805a45d8914ecdc998d98b419c8a19053b1daa`) against `candidate/frontend-closeout` (`f919bb787dab1a4e3bef44b5308ead56d6e77b72`): two commits ahead, no product RTL changes.
- Recompiled exact source and passed Compute Cluster UVM seeds `20261025/26/27`; each line-stall test observed 92 stability checks, zero violations, and 1840 overlap cycles. UVM severity counts were zero.
- Rebuilt DUT-only Top Smoke coverage from one VCS compile and merged three seeds under `/tmp/nmaforge_round2_dutcov_sha76805a45_20261113`: line 85.74%, condition 76.97%, FSM 43.74%, branch 82.09%. Kept full UVM coverage (69.46/67.13/43.47/66.26%, assertions 72%, groups 83.94%) as a separate database because it contains verification environment hierarchy.
- Existing AXI stall directed test on the same compiled UVM image hit AR/AW/W stall-to-accept covers 14/5/12 times. The main compute-cluster regression had zero AR/AW matches, proving those tests are peripheral DMA stimulus gaps for that test, not unreachable cover properties.
- Added `dv/uvm/tests/check_compact_spad_alloc.py` for compact concurrent live-range bounds/overlap and the row-8 CNM B lane calculation; wired it into the Compute Cluster UVM compile target.
- Initial uncovered-bin triage, compact interval table, SVA disposition, scoped RTM and remaining work are in `docs/verification/COMPUTE_CLUSTER_DV_CLOSURE_ROUND2_2026-11-13.md`. DV remains OPEN; full bin-by-bin disposition, SpyGlass/RDC closure and ASIC readiness remain.
- Reproduction: `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_round2_uvm_sha76805a45_20261113`; `make -C dv/subsystem/top_smoke/sim ai_compute_cluster_cov AI_CLUSTER_COV_RUN=/tmp/nmaforge_round2_dutcov_sha76805a45_20261113 AI_CLUSTER_COV_SEEDS='20261025 20261026 20261027'`.

## 2026-11-15 — v2.0 Round 6 H64 FFN Product Top

Isolated `/tmp/nmaforge-v2-round6`, branch `research/nmaforge-v2-round6`, from
`7744ad95d0ddd3eb191c5b5431aeebe01d8faefa`; no product branch or PR was
modified. Expanded the H64 FFN workload to all 16 Up tiles and added sixteen
K=16 Down GEMMs, ordered INT32 partial accumulation using the existing SFU
Residual opcode, and Residual 2. Product Top with VCS V-2023.12-SP1_Full64
passed 80 ordered completions and 12,288 independent Golden words. AXI4 DMA
loaded 43,008 bytes before command issue. Command/end-to-end time was
165,028/176,987 cycles, including DMA; useful/executed/padding MACs were
131,072/524,288/393,216 and SPAD high-water was 103,424 bytes. The manifest
checks allocation bounds, alignment, live alias, and initialized reads. The
standalone FFN uses fixture input, so full Attention-to-FFN H64 Decoder is not
closed. H64 Attention replay, H16 persistent decode replay, SFU `0x3A` A/B and
`make ai_smoke` passed. Round 6 scope, limits, logs and reproduction commands:
`docs/research/NMAFORGE_V2_ROUND6_H64_DECODER_STATUS.md`; raw runs are under
`/tmp/nmaforge_round6_*_20261115*`. No synthesis or formal run was done; SVSE
fault closure and full model integration remain open.

## 2026-11-15 — v2.0 Round 7 unified H64 decoder block

On isolated branch `research/nmaforge-v2-round7`, based on Round 6
`fcb1b72969771b9b5fca504e5f7b6d389b74ffc2`, added a unified seeded H64 graph
using one canonical model package for embedding, LN1/LN2, Q/K/V/O and FFN
weights. Lifetime allocation relocates 158 tensors inside 128 KiB, checks
live-range overlap/initialization/bounds, and reserves 256 CMDQ/CPLQ slots for
189 published descriptors. The Product Top executed Attention through
Residual 1, LN2, packed Matrix-A handoff, 16 FFN Up/GELU tiles, 16 Down K tiles
with INT32 partial accumulation, and Residual 2 in one Top instance without
reset.

VCS `V-2023.12-SP1_Full64`: `FULL_H64_DECODER_BLOCK_RTL_PASS`; 189/189
ordered completions and 5,056 final-image Golden words bit-exact. Command
cycles 259,661; useful/executed/padding MACs 215,040/884,736/669,696;
SPAD reads/writes 348,160/221,184 B. Existing H64 Attention (108 descriptors,
12,288 words, 91,351 cycles), FFN standalone DMA (80 descriptors, 43,008 B
DMA preload) and `make ai_smoke` also pass. Full H64 model uses deterministic
seed weights and testbench SPAD initialization; full-decoder AXI4 weight
streaming, transient per-descriptor readback, KV persistence, four-layer
decode, SVSE fault closure, synthesis and physical implementation remain open.
No product RTL or PR was changed. Detailed map, logs and commands:
`docs/research/NMAFORGE_V2_ROUND7_FULL_H64_DECODER.md`; raw run:
`/tmp/nmaforge_round7_final`.

## 2026-11-15 — v2.0 Round 8 H64 weight DMA and transient checkpoints

On the isolated `research/nmaforge-v2-round8` worktree at exact Round 7 parent
`ba4c6697fcb12245b1141df27938e3aa406d4dd1`, added a DMA-enabled replay of the
existing 189-descriptor one-layer H64 graph. Matrix weight ranges are omitted
from the initial SPAD image; 49 Product-Top AXI4 DMA transactions transfer
53,248 bytes from modeled external memory. All 13,312 destination words are
checked after each DMA completion, before CMDQ publication. Eleven transient
Tensor checkpoints are compared at producer retirement through read-only
behavioral SRAM backdoor access. Final Golden is 5,056/5,056 and completions
189/189. VCS `V-2023.12-SP1_Full64` reports 48,791 host fixture cycles, 15,749
DMA cycles, 259,667 compute cycles, 324,207 total session cycles. Same-seed
host-preload comparison is 128,663 + 259,667 = 388,330 cycles; compute work
is unchanged, so this is setup-path measurement, not operator acceleration.

Gate 2 remains NOT_RUN: the H64 graph contains no KV `0x43/0x44` descriptors
and reports `kv_busy=0`. No H64 incremental planner feeds projected K/V through
the Product KV engine and back into subsequent causal attention. Four-layer,
LM head, real checkpoint, and model-quality gates are also NOT_RUN. No product
RTL was modified. Full details and hashes:
`docs/research/NMAFORGE_V2_ROUND8_GATE1_GATE2_STATUS.md`; reproducible VCS
artifacts are under `/tmp/nmaforge_round8_h64_dma_e2e` and
`/tmp/nmaforge_round8_h64_host_e2e`.

## 2026-11-25 — V1.3 Round 33 overlapped execution and performance closure

Implemented on isolated branch
`research/nmaforge-v1.3-round33-overlapped-execution`, based on verified
Round 32 HEAD `651c32db216c34e653575dbeaddaefd4787a5c91`. The Matrix Core now
overlaps full-tile writeback with next-tile compute using a 1 KiB output
ownership buffer, directly kicks operand prefetch to remove controller
bubbles, and overlaps GEMV K-group fill with valid MAC work. The 16×16 array,
256 MAC count, default 128 KiB SPAD, read limit, ABI, and queue/SPAD ownership
contracts remain unchanged.

With VCS `V-2023.12-SP1_Full64`, fixed-memory GEMM measures 115/159/564/1606
cycles for 16×16×16, 16×16×32, 32×32×64 and 64×64×64. The two large shapes
meet the Round33 stretch targets; the small shapes miss by 10 and 14 cycles.
The three seeded 64×64×64 results are 2205/2209/2204 cycles and meet stretch.
Fixed GEMV measures 130/313/1249/2005 cycles for the four target shapes; the
1×64×256 case misses its 2000-cycle minimum by 5 cycles. Every NMAForge
wide-GEMV INT32 Golden passes. The 64×64 GEMM input traffic remains 8192 B.

A fresh harness runs pinned TinyNPU `8216c22b762011aa20c05fc2768423fd12dda59d`
through its native GEMM controller, array and actual banked SRAM. For the four
matched INT8 L1 GEMMs, NMAForge wins every workload with a 3.503× geometric
mean Tiny/NMA cycle ratio at matched effective 1 B/cycle service. This closes
the specified ≥1.05× GEMM objective only. TinyNPU's 1×64×256 controller fails
its independent Golden because a 4-bit K-tile count truncates 16 to zero;
output precision also differs on other native GEMV cases. Its Product Top
does not instantiate `graph_top`, so TinyNPU GEMV and shared-CNN ratios remain
open or `NOT_COMPARABLE`. No overall TinyNPU superiority claim is made.

Verification: full matrix regression passed 18 numerical and 35 fault cases;
output-overlap stress passed 158 overlap cycles and 132 stalled-line checks;
`make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261122`,
`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`, Compute Cluster UVM at
128/256/512 KiB, representative CNN (20,480 Golden words) and the existing
partial DeiT path passed. GEMV request-stability Formal passed one
non-vacuous property and a cover; the new overlap proof closed 2/4 properties
and the FSM guard closed 1/5 before 360 s timeouts. PPA is `BLOCKED_ENV`:
`dc_shell` is unavailable and `TSMC28_STDCELL_DB` is unset. Overall status is
`PERFORMANCE_CLOSURE_PARTIAL`.

The Round33 report, comparison/ablation/resource/verification CSVs, source
hashes, exact command manifest, and compressed raw-log archive are under
`docs/benchmark/NMAFORGE_V1_3_ROUND33_PERFORMANCE_CLOSURE.md` and
`benchmark/performance_dominance/round33/`. GPT-2 retraining and 12-layer DeiT
development were not started.

## NMAForge V1.2 P0 — 2026-11-24

On research branch `feat/shape-adaptive-gemv-v2`, committed capacity-aware Compute Cluster UVM fixture allocation at source SHA `c668479570e182e833146fd4a5f1d15bd06daf6c`. Reproduced the historical 128 KiB `CLUSTER_MEMORY_EMPTY` cause at SHA `f919bb787dab1a4e3bef44b5308ead56d6e77b72` (fixture write `0x7d000` returned SLVERR before an engine transaction). Read `SPAD_INFO`, allocated 46 bounded/disjoint regions and passed three seeds at each 128/256/512 KiB configuration, with 5,368 compared words per seed and zero mismatch/unknown/stale/orphan responses. The exact capacity commands and log hashes are in the P0 manifest. Also ran `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=12345 SEED=20261124` and `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`; both exited 0. Historical 64×64×64 GEMM and 1×64×64 GEMV cycle-profile replay is SHA-bound to `49441dfafa130731c822c43bf2e500023e58423c`; it is not current Product Top timing. See [P0 run report](verification/NMAFORGE_V1_2_P0_RUN_REPORT.md), [run manifest](../benchmark/representative/v1_2/p0/run_manifest.json), and the addendum in the [Compute Cluster RTM](verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). Full V1.2 remains open.
