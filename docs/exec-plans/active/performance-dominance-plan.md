# NMAForge V1.3 — Performance Dominance Execution Plan

## Round 32 measured catch-up disposition — 2026-11-24

This latest supplement supersedes the earlier Matrix baseline rows below for
Round 32. Work was isolated from base `8f2ed82c7d7a58885bc19f0b263490f7817a5f51`
on `research/nmaforge-v1.3-round32-tinynpu-catchup`; ABI v7.4, one 16×16
256-MAC array, and default 128 KiB SPAD are preserved.

| Gate | Round 32 result |
|---|---|
| GEMM 64×64×64 | Fixed cycles 3413→2768; seeds 20261122/24/25: 4783/4758/4745→3550/3529/3546; reads 20480→8192 B. All minimum goals and read-traffic challenge pass. Cycle challenges 2600 fixed / 3200 seeded remain unmet. |
| GEMV 1×64×64 | One opcode `0x52` descriptor: 358 fixed cycles, 433/467/479 at seeds 20261122/24/25, 4352 B reads and 64/64 Golden. Fixed challenge 400 and seeded minimum 500 pass. The previous four-descriptor route measures 584 fixed and 818/841/845 seeded. |
| GEMV fixed regression suite | `1×16×64`, `1×64×64`, `1×256×64`, and `1×64×256` each pass independent signed INT32 Golden at fixed memory and three random seeds. |
| TinyNPU | Rebuilt at `8216c22b762011aa20c05fc2768423fd12dda59d`; L0 direct-array datapoints are fresh. NMAForge Matrix+SPAD L1 and TinyNPU direct-array L0 are NOT_COMPARABLE. The shared `conv1x_mini.onnx` passes both sides, but timing windows differ and no speedup is claimed. |
| CNN | Current Product Top legacy/first/both fusion: 60930/34324/7708 command cycles; each matches its independent 20480-word Golden. Shared ONNX graph passes TinyNPU and NMAForge Goldens. |
| Regression/formal/PPA | `ai_smoke`, 20-case seed 12345, and Cluster UVM 128/256/512 KiB pass. Matrix FSM formal is 5/5 assertions and 2/2 covers. GEMV request stability times out at 360 s. PPA is BLOCKED_ENV: private TSMC28 library unset and `dc_shell` unavailable. |
| Overall | **CATCH_UP_PARTIAL**. Do not promote to PASS until common-boundary TinyNPU ratios and all challenge gates have evidence. |

The full run manifest, before/after/TinyNPU table, exclusive-cycle breakdown,
ablations, guardrail, and exact commands/logs are in
[`benchmark/performance_dominance/round32/`](../../../benchmark/performance_dominance/round32/)
and [`NMAFORGE_V1_3_ROUND32_TINYNPU_CATCHUP.md`](../../benchmark/NMAFORGE_V1_3_ROUND32_TINYNPU_CATCHUP.md).

Status is tracked from isolated research branch
`research/nmaforge-v1.2-integrated-model-dv`, baseline commit
`8737fa1c7c6d08a894913a904a8a52aff4fb5840`. The objective is
Hardware–Software Co-design: restore reproducible software/runtime/DV evidence
first, then change RTL only when a measured bottleneck requires it.

## Fixed baseline and constraints

- Product source, ABI v7.4, version register, source filelists, and default
  configuration are frozen in
  [`v1_3_source_freeze.json`](../../../benchmark/performance_dominance/v1_3_source_freeze.json).
- The baseline has one Product Top (`rtl/top/ai_accel_top.v`), one 16×16
  Matrix array, four SPAD banks, and existing compute engines. Do not add a
  duplicate array or a second Product Top.
- Allocate model-development effort equally: 50% to GPT-2 and 50% to
  DeiT-Tiny. Keep both tracks active through the shared runtime/profile work.
- Every run binds its exact source SHA, model/checkpoint hash, ABI, parameters,
  input set, timing window, independent Golden, raw logs, exit code, and
  performance CSV. When an exact exit code was not retained, record that gap.
- Do not add cycles from counters whose intervals overlap. Publish exclusive
  stall time separately from overlapping active/stall events.
- A historical PASS is reusable only for the source files/configuration that
  the run actually exercised. It is not a fresh pass for a different source or
  endpoint.
- Do not make an NMAForge/TinyNPU speedup claim until both run the same model,
  input, precision, memory service, and timing boundary. Product-level timing
  must include the corresponding controller/queue/memory work on both sides.
- Change RTL only for a measured bottleneck. Preserve the ABI, SPAD protection, arbiter
  ownership, registered-read behavior, AXI protocol, reset, abort, and ordered
  completion contracts.

## Pre-Round-32 gate disposition (historical baseline)

| Gate | Status | Exit criterion |
|---|---|---|
| Baseline source/ABI/configuration | FROZEN | All campaigns derive run identities from the source-freeze file; any changed source/configuration gets a new immutable identity. |
| Product Top baseline and DV recovery | PARTIAL — current-source smoke/UVM/mutation revalidated | At frozen source `8737fa1c`, `ai_smoke` (seed 20261124) and `ai_run` (20 cases, seed 12345) pass. Real Compute Cluster UVM passes again at 128/256/512 KiB with seed 20261124 (3/3); each capacity reports `compact_map_required_end=0x00020000` and `access_bounds_checked=1`. A separate current-source RTL mutation campaign catches 7/7 mutants. Historical 9/9 evidence remains separate. Full RTM and cluster sign-off remain open. |
| Gate 1 exact GEMM/GEMV | PARTIAL — current-source baseline replay PASS | Rebuilt the saved Round 27 harness against frozen source `8737fa1c`. Same-seed 64×64×64 GEMM replay reproduces 4,822 cycles with seeded back-pressure and 3,413 cycles with fixed one-cycle memory. GEMV 1×64×64 reproduces 632/584 cycles with prefetch OFF/ON. All outputs match the harness's independent INT32 Golden. Exclusive stall accounting and matched TinyNPU endpoints remain open. |
| TinyNPU paired comparison | NOT COMPARABLE | Rebuild/run the pinned TinyNPU source with a matched memory/controller endpoint, or explicitly restrict the result to direct-array reference data without a speedup claim. |
| Track A: GPT-2 | PARTIAL — independent software evaluation is negative | On 64 fixed windows from an independent Pride and Prejudice byte corpus, the selected Product-contract INT8 package scores 11.23% next-byte accuracy / PPL 216.50, below the paired FP32 checkpoint (30.76% / 15.13) and same-window byte Bigram (27.64%). This is software-only; independent-data Product Top logits were not run. Per-operator diagnosis, quality recovery, capacity/residency, and final Product Top qualification remain open. |
| Track B: DeiT-Tiny | PARTIAL | Three-head attention already covers all 197 query rows, including the final five-row tail. Wo projection covers only 16 rows; extend projection and remaining Layer 0 ops, then 1/2/4/12 layers, final LayerNorm/classifier, and real-image accuracy. Keep every activation device-side. |
| Capacity and weight residency | NOT RUN for the V1.3 models | Run identical model/checkpoint/input workloads at 128/256/512 KiB, reporting liveness, resident weights, DMA bytes per token, KV traffic, and end-to-end latency. UVM capacity runs and static address maps do not satisfy this gate. |
| Performance co-design | PARTIAL — current-source CNN fusion A/B PASS | The same fixed-seed Product Top pointwise CNN fixture passes the independent 20,480-word Golden in legacy/first/both fusion modes at 60,930/34,324/7,708 command cycles. This is an untrained synthetic 1×1 fixture, not a TinyNPU comparison or model accuracy result. A unified Matrix/CNM/GEMV/SFU/DMA/SPAD profile and matched TinyNPU endpoint remain open. |
| Full Compute Cluster DV | PARTIAL | Current UVM capacity replays pass. Separate VC Formal runs pass the serial set (3 properties/7 covers) and dispatcher-pairs set (5 properties, 4 non-vacuous, 23 covers). A real-RTL mutation campaign catches 7/7 injected mutants; individual native simulator exit codes were not retained by the target harness. Full RTM, seven independent engine scoreboards, and complete coverage/assertion closure remain open. |
| Physical closure | NOT RUN | Start synthesis/STA/area/power only after model and functional gates identify a viable candidate. Report tool, library, constraints, environment, and pre-layout/signoff boundary. |

## Gate 1 — exact Matrix baseline and comparison contract

The recovered NMAForge evidence is in
[`v1_3_gate1_baseline/`](../../../benchmark/performance_dominance/v1_3_gate1_baseline/).
The saved Round 27 harness was rebuilt with VCS V-2023.12-SP1 against the
frozen RTL at `8737fa1c7c6d08a894913a904a8a52aff4fb5840`; compile and current
replay exit codes are zero. Raw logs and checksums are in
`evidence/current_replay_8737fa1c/`. The same seeded GEMM run reproduces the
historical 4,822-cycle result exactly. The fixed-memory run is 3,413 cycles;
it removes bank/line stalls, explaining the 1,409-cycle difference. A second
seed (20261124) gives 4,746 cycles, showing expected sensitivity to behavioral
readiness. Profile events overlap and are not an exclusive cycle partition.

| Workload | NMAForge result | Memory and endpoint |
|---|---|---|
| GEMM 64×64×64, seed 20261122 | 4,822 cycles; 54.364 useful MAC/cycle; 20,480 B read / 16,384 B write; 538 bank stalls / 371 line stalls; 4096-output Golden PASS | Current-source replay with registered behavioral SPAD and variable readiness/back-pressure; Matrix start through final SPAD write and done. Profile records 1,928 prefetch-wait, 909 arbiter-stall, 83 response-wait and 371 writeback-wait events; they are not summed as exclusive cycles. |
| GEMM 64×64×64, fixed memory | 3,413 cycles; 76.808 useful MAC/cycle; same traffic; zero bank/line stalls; Golden PASS | Forced one-cycle bank response and always-ready bank/line; same standalone Matrix endpoint. This explains the 1,409-cycle difference from the seeded result. |
| GEMM 64×64×64, seed 20261124 | 4,746 cycles; 55.235 useful MAC/cycle; same traffic; 472 bank stalls / 328 line stalls; Golden PASS | Same harness and RTL, different deterministic readiness seed. |
| GEMV 1×64×64, prefetch OFF/ON | 632 / 584 cycles; 6.481 / 7.014 useful MAC/cycle; 4,352 B read / 256 B write; 64/64 Golden PASS each | Four legal opcode `0x52` descriptors, 16×16 array, B-cache disabled, one-cycle/always-ready behavioral SPAD. Prefetch ON reduces this scoped cycle count by 7.59%. |
| TinyNPU historical direct array | 3,166 GEMM cycles; 790 GEMV cycles; Golden PASS | Output-stable direct-array boundary excludes controller and memory service. Not comparable to NMAForge rows above. Raw TinyNPU logs are absent from the retained package. |

These Matrix results have no Product Top DMA, CMDQ/CPLQ, descriptor-fetch,
host, or system latency. Current DMA bytes are therefore not applicable;
descriptor/completion and host overhead are not measured. The existing
bank/line counters are event counters, not an exclusive stall partition.

Remaining Gate 1 deliverables:

1. Add cycle-level exclusive-stall accounting without weakening existing
   assertions or back-pressure behavior. Current bank/line/profile values are
   overlapping events, not a disjoint cycle classification.
2. Establish both a resource-matched direct-array comparison and a
   Product-level common-memory/controller comparison against pinned TinyNPU.
   Historical TinyNPU rows remain direct-array-only and are not comparable to
   this Product Matrix endpoint.

## Track A — GPT-2 (50% model investment)

Existing evidence establishes a four-layer Product Top persistent-KV versus
prefix-recompute comparison: outputs match bit-exactly for four 256-logit
contexts; the measured command path falls by 3.0195% and descriptor
publications by 15.5491%. This is a fixture-level command-path result, not
host-to-host application latency. The selected QAT package still scores below
Bigram, and it has already been evaluated on its reported final test split;
that split is no longer an untouched confirmation set.

A reproducible derivation over the existing per-context CSVs finds that KV
saves exactly 8,736 Product Top cycles and 32 descriptor publications per
previously computed prefix token in each of the three measured contexts. For
the four-layer model this is 2,184 cycles and 8 descriptors per layer per
avoided prefix row. This scaling is consistent with eliminating old-prefix
recomputation; it does not show which engine dominates within a token. The
analysis is explicitly not a new simulation and its inputs, source hash,
command, and exit code are recorded in
[`v1_3_gpt2_persistent_kv_analysis_manifest.json`](../../../benchmark/performance_dominance/v1_3_gpt2_persistent_kv_analysis_manifest.json).

The available software diagnosis points to cumulative error: final aligned
Product INT8 software CE/PPL is 3.2707 / 26.33 versus FP32 2.2053 / 9.07 and
Bigram 2.5372 / 12.64 on the same 2,048 validation targets. Attention
probability cosine falls to 0.8288, FFN down-projection cosine to 0.3751,
Layer 3 Residual2 cosine to 0.3042, and the progressive integerized-prefix
diagnostic falls from 28.03% after one layer to 24.37% after four. These
observations localize sensitivity but do not isolate causality or establish
an RTL arithmetic defect.

Remaining execution:

1. Freeze a new FP32 checkpoint, independent train/validation/test split, and
   package hash before tuning. Preserve the current run as historical
   diagnosis.
2. Report FP32 reference → quantized software → bit-accurate hardware Golden
   → operator RTL → full Product Top for the same tensors and logits.
3. Ablate Residual, LayerNorm, Softmax, FFN/GELU, and requantization one at a
   time; include NLL, perplexity, tensor errors/cosine, saturation and rail
   occupancy. Compare INT8, selective INT16/INT32, and multiplier-plus-shift
   contracts with independent Goldens.
4. Compare persistent KV against prefix recompute at matched prompts, token
   counts, contexts, and timing boundaries. Attribute the 3.0195% delta to
   Matrix, memory, descriptor, completion, and setup intervals.
5. Measure model live-set and 128/256/512 KiB capacity/weight-residency
   effects before considering a buffer or arithmetic RTL change.

## Track B — DeiT-Tiny (50% model investment)

The historical Round 30 Product Top path covers QKV/repack, attention, and AV
for all 197 query rows and three heads, including the final five valid rows.
Round 31 extends only one 16-query block through head merge/Wo projection and
checks 72,384 Golden words; 181 rows remain unprojected. The final five rows
have attention/AV evidence but no Wo projection Golden. Layer 0 is incomplete.
There is no safe existing target for full-query projection: the generator fixes
`QUERY_ROWS=16`, and the testbench explicitly rejects `output_projection_enabled`
when `query_blocks != 1`.

Execution order:

1. Generalize the generator and testbench to 13 query blocks, emit Wo
   projection Goldens for all rows, and check the final five valid rows. Retire
   each block's AV before reusing its bounded SPAD window.
2. Add Residual1, LN2, FFN up/GELU/down, and Residual2 with liveness-based
   scratch reuse in one unreset Product Top session.
3. Compare the full `197×192` Layer 0 output and required intermediate tensors
   against independent Goldens, with no Host intermediate-activation writes.
4. After Layer 0 passes, extend the same device-side execution to 1/2/4/12
   layers, final LayerNorm and classifier; evaluate labeled real images using
   official weights.
5. Use 256 KiB and report high-water at each tensor lifetime. Do not infer
   full-layer fit from the existing 16-query attention high-water.

No new RTL is justified by the current partial layer. Continue with descriptor
fusion, tiling, tensor lifetime reuse, bank-aware layout and prefetch on the
existing Product Top.

## Performance co-design and acceptance targets

Unify per-run counters for Matrix/CNM/GEMV/SFU/DMA/SPAD arbitration. Capture
useful MACs, reads/writes, operand fetches, queue publication/retirement,
prefetch overlap, arbiter ownership/waits, exclusive stalls, overlapping
events, host staging, and total timing window. Reproduce CNN fusion A/B on the
same workload and source before using it to guide the V1.3 bottleneck choice.
The fixed-seed 1×1 Product Top A/B is now reproduced for all three modes; use
its descriptor/cycle deltas as a bounded dataflow datapoint, then profile the
other engines before selecting the next bottleneck.

Targets are goals, not measured results: GPT-2 decode 2.0×, prefill 1.3×,
full DeiT-Tiny 1.5×, GEMM geometric mean 1.3×, representative GEMV 2.0×,
external traffic reduction 30% where applicable, better area/energy-normalized
throughput, and 400 MHz ASIC frequency. Reject an RTL candidate without
independent correctness, focused DV, Product Top regressions, and acceptable
synthesis/timing evidence.

## Compute Cluster DV and physical closure

Maintain the existing single-SPAD-arbiter and ordered-retirement ownership
rules. Extend the RTM to every requirement/testpoint, and establish a separate
Golden and Scoreboard for each of the seven engines. Cover legal concurrency,
SPAD ownership, dependencies, ordered retirement, reset/abort drain,
backpressure, parity and protection. Keep functional coverage, assertion,
formal, and mutation results independent. A missing Formal license/tool is
`BLOCKED_ENV`, never PASS.

Current capacity UVM evidence passes at 128/256/512 KiB for one seed each;
previous 9/9 capacity results remain separately identified. Seven current
source RTL mutants are detected by their expected scoreboard/checker. Current
VC Formal serialization results pass 3 assertions and 7 reachability covers.
The dispatcher-pairs target passes 5 properties, 4 non-vacuous checks, and 23
covers. Its first 300-second attempt timed out and is preserved; a separate
retry passed with a 900-second timeout. Individual native simulator return
codes for the mutation cases were not retained by the target harness. These
results are not full Compute Cluster sign-off. Begin DC, SpyGlass, LEC, DFT,
and physical work only after the functional model gates pass and a measured
candidate exists.

## Current blocker and resumption point

The earlier current-source compile attempt was blocked by license-server
connectivity and is retained as failed-environment provenance. VCS is now
available; Gate 1 and Top smoke/seeded runs were rebuilt and replayed at the
frozen source identity with zero exit codes. No RTL changed. Continue the
GPT-2/DeiT accuracy and model-level capacity work at their frozen model and
configuration identities; the current Matrix baseline alone does not establish
TinyNPU dominance or authorize Design Freeze.
