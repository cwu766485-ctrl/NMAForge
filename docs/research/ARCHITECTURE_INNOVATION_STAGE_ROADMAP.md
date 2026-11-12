# NMAForge Architecture Innovation Stage Roadmap

## Execution order

Run one innovation through Stage 1, Stage 2, Stage 3 and its Stage 4 decision
before starting the next innovation. The order is A, B, C, D, E. Do not develop
multiple RTL candidates in parallel. A Stage 4 decision may stop or defer a
direction; later directions still proceed in the listed order.

The five directions are research candidates, not approved product changes:

| Order | Direction | Initial disposition |
|---|---|---|
| A | Bank-Aware + Dependency-Aware Scheduler | First priority; measure current bottleneck before proposing RTL. |
| B | Shape-Adaptive Dataflow + Cost Model | Existing isolated kernel and real-SPAD wrapper are evidence inputs; product-top integration remains open. |
| C | SFU Iterative Arithmetic Optimization | Optimize only cycles proven to be arithmetic-bound; preserve fixed-point results. |
| D | Structured Sparsity / Zero-Skipping | Conditional on representative model sparsity and metadata-inclusive benefit. |
| E | Reconfigurable Precision MAC | Deferred until precision needs and legal area/timing resources are defined. |

## Stage definitions

| Stage | Required work | Exit gate |
|---|---|---|
| 1. Baseline and bottleneck | Freeze SHA, test inputs, tool profile and endpoints. Collect per-requester grants, bank/address distribution, grant wait, response wait, engine idle, traffic bytes and end-to-end cycles. Separate measured RTL results from analytical estimates. | Every claimed bottleneck is tied to a reproducible counter or waveform interval; missing scenarios are named. |
| 2. Candidate comparison | Compare the unchanged baseline with at least two executable models or controlled configurations. Keep work, memory geometry, seeds and correctness oracle matched. Include control, metadata and traffic overhead in the cost model. | Candidate ranking is repeatable and has an explicit predicted mechanism; no candidate is selected from peak MAC rate alone. |
| 3. RTL prototype and DV | Implement one candidate only in an isolated branch/profile. Run focused Golden, request/response owner, output-prefix, Fault, Reset, Abort and recovery tests, followed by the applicable smoke/regression. | Correctness and protocol checks pass; measured end-to-end benefit is separated from model prediction; area/timing impact is measured where legal libraries and constraints exist. |
| 4. Decision | Compare measured results with the predeclared target, regressions, resource cost and verification cost. Record keep, revise, defer or drop. | Promote only with at least 10% geometric-mean end-to-end cycle improvement on the predeclared representative suite, no unexplained material regression, preserved ABI/fault/completion contracts, and resource cost within an approved budget. Otherwise retain the existing implementation. |

The 10% target is a research continuation threshold, not a product guarantee.
For Stage 4, report every workload, the geometric mean, worst regression,
variance across seeds, traffic bytes and the measurement endpoint. Do not claim
ASIC area, frequency or power without legal libraries, a compatible SRAM macro
view and project timing constraints.

## A. Bank-Aware + Dependency-Aware Scheduler

| Stage | Work and evidence |
|---|---|
| 1 | Measure the current RR/priority arbiter under CNM×DMA, Matrix×CNM, Matrix×DMA, SFU×DMA and legal multi-engine traffic. Record per-class accepted grants, bank histogram, grant-wait distribution, response-wait distribution, engine idle cycles and DMA stalls. Keep descriptor/completion priority visible. |
| 2 | Compare current policy, bank-aware arbitration, and bank-aware plus resource-credit/dependency scheduling in an executable model. Preserve request acceptance, protection checks and FIFO completion retirement. Treat software-owned address hazards as illegal inputs unless a dependency is explicit. |
| 3 | Prototype the single winning arbitration/scheduling change behind an isolated profile. Check Matrix and CNM response tags/lanes, DMA fairness, ordered retirement, accepted-write prefix, and all relevant Fault/Reset/Abort paths. |
| 4 | Keep only if Stage 4's system-level target is met without starvation, reordered side effects, changed fault visibility or completion ABI. Otherwise retain current RR/priority. |

### Stage 1 A baseline replay

**Status: COMPLETE for the currently legal request classes.** Exact source SHA
`a4fb84c` on branch `feat/shape-adaptive-gemv-v2`; VCS
`V-2023.12-SP1_Full64`. The DMA/SPAD subsystem run used seed `20261113`; the
real-top Compute Cluster UVM run used seeds `20261113/20261114/20261115`.
Both passed with UVM warning/error/fatal `0/0/0`. DMA functional coverage was
100%; each real-top run passed its independent memory scoreboard with 5,368
checked words and zero mismatch, unknown or stale response.

Observed measurements from `/tmp/nmaforge_stage1_a_subsystem/run.log`:

| Scenario | Accepted traffic / wait observation | What it establishes |
|---|---|---|
| CNM×DMA primary overlap | CNM/DMA grants `7/4`; 4 CNM stall cycles; max consecutive stall streak 1; four grants after a stall; 16 accepted and returned requests per CNM lane. | Pairwise CNM/DMA shared-port progress and bounded observed stall for this directed case. |
| FP×DMA | Two overlapping runs each observed FP/DMA contended grants `5/6`; each had 64 FP reads/responses, peak FP outstanding 2 and one output write. Other runs were isolated. | Pairwise FP/DMA contention; not SFU/DMA. |
| Aggregate core/DMA monitor | Core reads/responses `192/192`; isolated/contended core grants `490/17`; isolated/contended DMA grants `149/55`. | Existing harness requester counters; not a per-bank histogram or compute-cycle attribution. |
| Real-top Matrix×CNM | Each of three seeds: Matrix tag3 responses `576`, CNM tag5 responses `96`, all four CNM lanes seen, engine overlap `316` cycles, shared banked grants `60`. | Confirms the currently legal pairwise compute contention and distinct response ownership. |
| Real-top queued work | Each seed: serial Matrix/CNM/SFU `1239` cycles; staged Matrix+CNM then SFU `1070` cycles (`1.158x`); four-task parallel sequence `1137` versus serial `1696` (`1.492x`), with 38 shared-SPAD contention cycles. | Existing fixed-workload cycle baseline; not proof of a scheduler optimization. |
| Compute×DMA launch | Register logic starts `DMA_CTRL` only when `!processor_busy && !dma_busy`; the real-top test observes DMA after the compute workloads. | Matrix×DMA and SFU×DMA overlap is not a legal software-reachable case in this baseline; do not synthesize it by forcing internal controls. |

The subsystem harness has no Matrix requester and does not isolate SFU. The
real-top run closes Matrix×CNM, while the register gate classifies compute×DMA
overlap as unsupported under the current control contract. The checked-in top
sequence includes a DMA response-client read, but issues it outside compute
busy time. There is no product-path arbiter evidence for simultaneous DMA and
compute until that gate or descriptor behavior changes under an approved SPEC
revision. Older Stage A results in
[`COMPUTE_CLUSTER_STAGE_A_AND_BENCHMARKS_2026-10-26.md`](../verification/COMPUTE_CLUSTER_STAGE_A_AND_BENCHMARKS_2026-10-26.md)
are historical SHA evidence and are not mixed into this exact-SHA replay's
numbers. For current legal behavior, A Stage 1 is complete. The real-top run
shows the data-plane classes and the currently legal compute pair contention;
compute×DMA remains excluded by the control ABI.

Reproduction used the subsystem Makefile compile target and then invoked the
compiled image directly because `subsystem_run` prepends `./` to an absolute
`SIMV` path:

```sh
cd dv/subsystem/dma_spad/sim
make subsystem_compile SEED=20261113 COV_TAG=stage1_a_baseline \
  SIMV=/tmp/nmaforge_stage1_a_subsystem/simv \
  COV_DIR=/tmp/nmaforge_stage1_a_subsystem/coverage.vdb \
  COMPILE_LOG=/tmp/nmaforge_stage1_a_subsystem/compile.log
/tmp/nmaforge_stage1_a_subsystem/simv \
  +UVM_TESTNAME=dma_spad_subsystem_test +ntb_random_seed=20261113 \
  +UVM_VERBOSITY=UVM_MEDIUM \
  -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir /tmp/nmaforge_stage1_a_subsystem/coverage.vdb \
  -l /tmp/nmaforge_stage1_a_subsystem/run.log

cd ../../../uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261113 20261114 20261115' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_stage1_a_cluster_current
```

## A. Stage 2–4 candidate decision

**Stage 2 result: no candidate has a measured benefit in the current legal
workloads. Stage 3: no product RTL prototype. Stage 4: defer A.** This is a
no-go based on the exercised request set, not a claim that bank-aware
arbitration cannot help a different legal workload.

| Candidate | Measured opportunity | Limitation / result |
|---|---|---|
| Bank-disjoint per-bank co-issue | Passive monitor compares scalar address bank `[3:2]` with live CNM lane mask. Three real-top seeds reported zero disjoint and zero conflicting scalar/CNM overlap cycles. | No co-issue opportunity appeared in this traffic. Matrix banked reads use all four banks in one request; the staged Matrix/CNM sequence observed 32 competing cycles, all conflicting with Matrix's four-bank mask. |
| Compute×DMA co-issue | None. | `DMA_CTRL` cannot start while `processor_busy`; no legal workload can exploit this without an approved control/SPEC change. |
| Dependency/credit launch scheduling | Existing four-task parallel work was 1,137 cycles versus 1,696 serial cycles. | This measures existing engine parallelism, not credits or a new issue policy. The speedup cannot be attributed to a scheduler candidate. |

The bank-mask counters are passive testbench instrumentation. They do not
model simultaneous macro-port collision rules or authorize co-issuing
requests. No candidate meets the 10% system-level gate in the current legal
workload, so no arbiter, port, dependency or ABI behavior was changed. Revisit
A only if a representative legal workload shows scalar/CNM disjoint-bank
overlap or a separately approved contract permits compute/DMA overlap.

Reproduce the real-top candidate measurements from product RTL SHA `a4fb84c`
with the checked-in passive monitor:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261113 20261114 20261115' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_stage2_a_bankmask
```

## B. Shape-Adaptive Dataflow + Cost Model

| Stage | Work and evidence |
|---|---|
| 1 | Freeze production GEMM cases, SPAD geometry, inputs and Goldens. Re-run baseline/folded paths through the existing real-SPAD wrapper and record cycles, reads/writes, bank conflicts, stalls and output commits. Calibrate each model term against observed intervals. |
| 2 | Compare GEMM, GEMV-fold, prefetch and double-buffer choices over identical shapes. Count all padding, reload and output traffic. Validate the cost model on held-out shapes. |
| 3 | Integrate one policy in an isolated Matrix profile; preserve existing descriptors and INT8 results. Exercise non-power-of-two dimensions, tails, backpressure, parity/protection, Abort and Reset. |
| 4 | Promote only if the selected policy predicts and achieves the Stage 4 target on the representative suite without unexplained GEMM regressions. Keep research-only policy if product-top integration does not reproduce the result. |

### B Stage 1 research-wrapper baseline

**Status: research-wrapper baseline complete; product Matrix calibration remains
open.** At base commit `773a747a841afaff8c68ce194a9b1c0558a82d27`, VCS
`V-2023.12-SP1_Full64` passed three seeds (`20261113/20261114/20261115`),
each covering the nine shapes `1x8x64`, `4x8x64`, `8x8x64`, `16x8x64`,
`1x13x17`, `1x13x64`, `4x13x64`, `8x16x64`, `16x16x64`. All 27 workload
instances passed an independent INT32 GEMM oracle, full 32-bit SPAD output
image comparison, and sentinel checks. Each seed also passed abort during
read/compute/writeback and reset with an accepted read outstanding.

Equal-weight geometric mean baseline/adaptive cycle ratio over 27 instances
was `1.0290` (2.9% improvement). Shape means were `1.1181` for `1x8x64`,
`1.0434` for `4x8x64`, `1.0763` for `1x13x64`, and `1.0302` for `4x13x64`;
the remaining five shapes were `1.0000`. The adaptive policy selected GEMV
for M=1/4 cases and GEMM for M=8/16. Baseline and adaptive arbiter wait
counts matched for every paired run, so the observed savings came from the
kernel schedule in this wrapper, not reduced arbitration. The tested workload
uses the real four-bank `ai_spad_arbiter` and behavioral `ai_scratchpad`, but
the adaptive kernel is not connected to the production Matrix command path;
this does not calibrate product GEMM cost terms or establish ASIC PPA.

The result is below the roadmap's 10% continuation threshold across the full
shape suite. Do not integrate this policy into product Matrix RTL. Stage 2 may
continue as a research-only model comparison; Stage 3 product integration is
deferred unless a representative held-out suite changes the Stage 4 decision.
The exact rows and tool metadata are in
[`shape_adaptive_spad_ablation.csv`](../../benchmark/shape_adaptive_spad_ablation.csv)
and [`shape_adaptive_spad_summary.json`](../../benchmark/shape_adaptive_spad_summary.json).

Reproduce the measured wrapper baseline with:

```sh
make -C dv/research/shape_adaptive/sim shape-adaptive-spad-regress \
  RUN_DIR=/tmp/nmaforge_stage1_shape_spad_20261113 \
  PYTHON=/usr/bin/python3.11 \
  SEEDS='20261113 20261114 20261115' \
  SOURCE_SHA=773a747a841afaff8c68ce194a9b1c0558a82d27
```

The existing evidence boundary and analytical prefetch schedule are recorded
in [`SHAPE_ADAPTIVE_TENSOR_ENGINE.md`](SHAPE_ADAPTIVE_TENSOR_ENGINE.md); the
analytical schedule is not measured product-top evidence.

## C. SFU Iterative Arithmetic Optimization

| Stage | Work and evidence |
|---|---|
| 1 | For each opcode, partition cycle count into memory request/response, arithmetic iteration, writeback and controller overhead. Start with Softmax, RMSNorm and LayerNorm; identify actual divider/sqrt iteration contribution. |
| 2 | Compare early termination and iteration-latency variants using the exact fixed-point Golden, signed boundaries and worst-case iteration count. Exclude speculative behavior that changes memory or fault ordering. |
| 3 | Implement one arithmetic change at a time. Verify bit-exact output, `ERR_NUMERIC`, watchdog, protection/parity, Abort/Reset and next-task recovery. Run SFU block and top smoke. |
| 4 | Retain only if arithmetic cycles are a measured end-to-end bottleneck and the Stage 4 target is met without changing the numeric/error contract or violating timing/area budget. |

## D. Structured Sparsity / Zero-Skipping

| Stage | Work and evidence |
|---|---|
| 1 | Profile representative trained weights and activations. Report block sparsity by candidate block size, metadata bytes, skipped MAC count, SPAD traffic and accuracy against dense Golden. |
| 2 | Compare dense execution, structured block skipping and dense fallback thresholds. Include metadata fetch/decode, partial blocks, bank layout and all-zero cases. |
| 3 | Prototype one encoding/skip path without changing the public ABI unless separately reviewed. Test sparse/dense crossover, malformed metadata, bounds/protection, Fault/Abort/Reset and exact output image. |
| 4 | Continue only when representative workload end-to-end results meet Stage 4 and sparsity metadata is stable, compact and verifiable. Otherwise defer. |

## E. Reconfigurable Precision MAC

| Stage | Work and evidence |
|---|---|
| 1 | Define supported operand/accumulator precisions and actual workload demand. Establish INT8 reference area, timing assumptions, lane utilization and SRAM packing costs with the available legal tool inputs. |
| 2 | Compare shared-MAC, lane-sliced and static-parameterized candidates in an arithmetic/mapping model. Quantify precision-switch overhead, accumulator width, throughput and expected area. |
| 3 | Prototype one precision extension in an isolated configuration. Preserve the INT8 path bit-for-bit; test signed extremes, overflow, rounding, packed layout, reset and runtime configuration legality. |
| 4 | Promote only with measured system benefit and implementation resources sufficient for meaningful synthesis/timing evidence. Without legal libraries, macro views and SDC, this stage can decide only behavior-level research continuation, not ASIC feasibility. |

## Change control and reporting

- Keep the product ABI, output prefix, fault priority, reset/fabric contract and
  completion ordering fixed unless a separately reviewed SPEC change is approved.
- Use isolated branches or compile-time research profiles for RTL candidates;
  never combine two candidate changes in one result.
- Keep generated simulations, coverage databases and waveforms outside Git.
- Record SHA, tool versions, seed, command, raw logs, correctness oracle,
  measurement endpoint and unclosed cases for every stage.
- Update this document at each gate. Push each committed report or RTL change
  to its corresponding GitHub branch after checks pass.
