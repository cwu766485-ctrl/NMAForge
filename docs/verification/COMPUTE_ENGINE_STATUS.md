# Compute-engine verification status

Status date: 2026-10-25. The current worktree completed the expanded
multi-engine regression, an SFU transition-closure sweep, a focused
Dispatcher/SPAD-MUX UVM test, and the first parameterized Matrix MAC-array
milestone. This is targeted functional and raw DUT code-coverage evidence;
it is not full signoff.

The group/compute aggregate figures below remain the 2026-10-23/24 merge and
were not recomputed with the new Matrix array RTL. Current Matrix 4×4
integration and standalone 8×8/16×16 evidence are reported separately here:
[Compute Cluster upgrade roadmap](COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md).

## 2026-10-25 P0 Matrix array milestone

`ai_tensor_matrix_core` now uses `ai_tensor_matrix_array` at `ARRAY_SIZE=4`;
the existing descriptor-facing 4×4 data layout remains in place. Three core
seeds (`20261021/20261022/20261023`) pass the existing six arithmetic/layout
cases, twelve faults/interactions, late-tile parity, abort/reset combinations,
and recovery. The current core-scoped URG report is
88.05% line / 87.30% condition / 64.10% FSM transitions / 87.50% branch for
`ai_tensor_matrix_core`; the embedded array's exercised 4×4 code bins are
82.35% line / 20.00% condition / 58.82% branch.

Direct array tests elaborate the same RTL at 8×8 and 16×16, with seeds
`20261025/20261026/20261027` for each size. Every seed passes four K lengths,
four pre-packed A/B transpose layouts, all N×N accumulator checks, 25
ping-pong load/MAC overlaps, and positive/negative INT32 saturation. Each
size reports 100.00% line, 100.00% condition, 94.12% branch, FSM N/A, and
100.00% functional group coverage. This is an array-block result: 8×8/16×16
address generation, SPAD prefetch/arbitration, descriptor control and top
integration are still open. Exact source-to-test trace is in the roadmap.

## Five compute groups

| Group | Multi-seed functional evidence | Historical group aggregate line / condition / FSM / branch | Current disposition |
|---|---|---|---|
| **CNM** | Per seed: 8 signed INT8 oracle lengths plus recovery; 6 isolated fault exits. Follow-up adds parity/protection + abort priority, reset with faults asserted, and parity after 128 accepted request slots in a length-256 task. A2.2/GEMV and 10-seed DMA–SPAD–CNM UVM also pass. | **97.06% / 90.54% / 68.29% / 85.71%** across core, controllers, and bank PE | Selected interaction paths pass. Other multi-fault/abort/reset orders and independent per-bank ready stalls remain open. |
| **CNN/KV** | Per seed: 25 convolution cases across 3–6 row/column shapes, including 12 depthwise opcodes; 27 KV round-trip/address cases. Full 512 KiB model, KV lengths 1–128, aligned strides 0–1020, address-boundary placement, late faults, abort+SPAD error, and reset under active fault inputs. | **100.00% / 90.37% / 68.18% / 97.10%** across convolution and KV engines | Selected address/lifecycle combinations pass. Exhaustive stride/configuration cross-products and every long-transaction error/reset case remain open. |
| **FP** | Three mixed-format UVM seeds: 212/212 bit-exact transactions each; parity+abort same-response and reset while abort/parity active pass in direct tests. BF16 wrapper and FP16/BF16 add/sub reference sweeps pass. Full-length BF16/FP16 max-parity simulation passes; isolated full-domain `ST_WRITE` exclusion proves non-vacuously with 2/2 parity covers. | **96.90% / 95.13% / 85.71% / 92.51%** across FP arithmetic and both add/sub parameterizations | Full-domain parity-to-writeback exclusion is proven for every nonzero 16-bit length under the documented legal-input contract. The full-domain progress-bound property remains open. |
| **Matrix** | Each of 3 seeds: 10,072 datapath vectors, 6 core arithmetic/layout cases, and 12 fault/interaction checks. Multi-fault + abort priority, reset with faults active, and late parity after 20 completed output lines pass. A3 core benchmark passes. | **88.02% / 89.39% / 66.67% / 88.49%** across matrix core and datapath | Selected combinations pass. Other fault permutations and late faults at every tile boundary remain open. |
| **SFU** | Per seed: 64 vectors across all 8 opcodes and lengths 1/2/3/4/7/8/15/16; 8 error/interactions. The 2026-10-24 sweep adds all 39 encoded state reset probes, all 39 state-to-ERR_ABORT probes, and RMSNorm gamma bypass. Late parity after response 8/16 and existing fault/reset interactions pass. | **86.45% / 88.30% / 100.00% / 82.81%** group line/condition/FSM/branch; only FSM is refreshed in the new merge. Core `state_r` is **139/139 transitions**. | All SFU FSM transitions reached in the three-seed updated regression. Other line/condition/branch bins, numeric-error reachability, and fault/reset combinations remain open. |

The group percentages are weighted by hit/total bins over each group's RTL
modules and elaborated parameter variants. They are VCS/URG code-bin coverage,
not feature pass rates. Other `rtl/compute` helpers (INT8 and the tile pipeline)
are included in the overall figure below.

## Parallel CMDQ dispatch

`ai_parallel_compute_dispatcher` now supports one in-flight command per compute
engine. Different engines may overlap; descriptor issue and completion
retirement stay in CMDQ order. Macro descriptors hand off to the serial
command processor after prior work drains. Software owns inter-command SPAD
hazard avoidance. A directed top smoke observes Matrix and SFU busy together,
queues a second SFU command without same-engine overlap, checks all three
completion IDs and both SFU results through the shared-SPAD response mux, then
aborts two active engines and checks both `ERR_ABORT` completions plus
idle-after-drain. The run passed with
VCS `V-2023.12-SP1_Full64` using
`make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=0 AI_SEED=20261023`
and `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=20261023`.

The five-seed top DUT-only coverage run includes a directed sweep of all 21
unordered engine pairs. Each pair was observed busy concurrently, then aborted;
the test checked two ordered completions, valid abort status, and full idle
drain. The focused formal run proves 5/5 dispatcher assertions and reaches all
23 covers: 21 pairs, all seven engines busy, and abort with active engines.
Four assertions with antecedents are non-vacuous; completion backpressure
remains open.

## Complete `rtl/compute` module coverage

The coverage merge contains 29 test instances: five top DUT seeds and three
seeds each for CNM, CNN/KV, Matrix datapath, Matrix core, SFU, the BF16
compatibility wrapper, FP16/BF16 add/sub, and mixed-format FP UVM. URG
`-flex_merge modules` merges matching RTL definitions across those benches.
Focused scopes select DUT instances only. The top-only compute slice filters the
five-seed DUT report to source files under `rtl/compute`; dispatcher and shared
SPAD mux results are separate because those modules live outside that tree.

All 23 source definitions under `rtl/compute` appear in the merged report.
Twenty source modules have executable code bins; three wiring-only wrappers
(`ai_bf16_dot_fp32_core`, `ai_bf16_addsub`, and `ai_fp16_addsub`) have no
applicable line/condition/FSM/branch bins. The add/sub core is elaborated twice
with FP16 and BF16 parameters, and both variants contribute to the merged
counts. The overall percentages below are weighted hit/total bin ratios, not an
average of module percentages.

| Coverage view | Line | Condition | FSM transitions | Branch |
|---|---:|---:|---:|---:|
| **All `rtl/compute` bins, focused tests plus five top seeds (2026-10-23 merge)** | **92.69%** | **90.00%** | **54.67%** | **87.31%** |
| Five-seed top DUT-only `rtl/compute` slice | 83.79% | 66.39% | 41.60% | 69.19% |

The 2026-10-24 overlay replaces the SFU input database with three refreshed
seeds and recomputes the transition total over the nine stateful
`rtl/compute` module definitions: 258/339 = **76.11%**, up from 185/339 =
54.57% on the same parsed scope. This compute-only FSM value is a targeted
overlay and does not recalculate line/condition/branch or the historical
five-seed top-only slice above. The two FSM views differ in module scope and
weighting; do not mix them as one dashboard.

Merged totals are 2,002/2,160 line bins, 1,449/1,610 condition bins,
205/375 FSM transitions, and 681/780 branch bins. Top-only totals are
1,639/1,956, 956/1,440, 156/375, and 494/714 respectively.

Per-module raw coverage:

| Group | RTL module | Line | Condition | FSM | Branch |
|---|---|---:|---:|---:|---:|
| CNM | `ai_banked_cnm_core` | 97.22% | 87.76% | 72.22% | 83.87% |
| CNM | `ai_bank_local_controller` | 96.88% | 94.12% | 65.22% | 81.08% |
| CNM | `ai_bank_pe` | N/A | 100.00% | N/A | 100.00% |
| CNN/KV | `ai_conv3x3_linebuffer_core` | 100.00% | 84.42% | 62.07% | 97.62% |
| CNN/KV | `ai_kv_cache_engine` | 100.00% | 98.28% | 80.00% | 96.30% |
| FP | `ai_mixed_precision_dot_fp32_core` | 97.97% | 95.61% | 85.71% | 91.23% |
| FP | `ai_bf16_mul_fp32` | 98.61% | 97.22% | N/A | 94.12% |
| FP | `ai_fp16_mul_fp32` | 100.00% | 96.77% | N/A | 100.00% |
| FP | `ai_fp32_add` | 88.68% | 88.51% | N/A | 82.35% |
| FP | `ai_fp32_accumulator` | 100.00% | N/A | N/A | 100.00% |
| FP | `ai_fp16_bf16_addsub_core` (FP16 parameters) | 99.02% | 95.29% | N/A | 96.97% |
| FP | `ai_fp16_bf16_addsub_core` (BF16 parameters) | 99.02% | 97.65% | N/A | 96.97% |
| FP | `ai_bf16_dot_fp32_core` | N/A | N/A | N/A | N/A |
| FP | `ai_bf16_addsub` | N/A | N/A | N/A | N/A |
| FP | `ai_fp16_addsub` | N/A | N/A | N/A | N/A |
| Matrix | `ai_tensor_matrix_core` | 87.19% | 88.03% | 66.67% | 84.31% |
| Matrix | `ai_tensor_matrix_datapath` | 100.00% | 100.00% | N/A | 100.00% |
| SFU | `ai_tensor_sfu_core` | 84.47% | 88.62% | 100.00% | 81.21% |
| SFU | `ai_tensor_sfu_math` | 100.00% | 100.00% | N/A | 100.00% |
| SFU helper | `ai_unsigned_divider` | 91.43% | 88.89% | N/A | 87.50% |
| SFU helper | `ai_integer_sqrt` | 96.55% | 83.33% | N/A | 90.00% |
| INT8 helper | `ai_int8_compute_core` | 92.94% | 79.47% | 52.78% | 74.58% |
| INT8 helper | `ai_int8_datapath` | N/A | 88.89% | N/A | 77.78% |
| Pipeline helper | `ai_tile_pipeline` | 92.35% | 80.00% | 25.00% | 87.80% |

The two new top-fabric modules are outside `rtl/compute`: the dispatcher has
91.70% / 66.91% / 75.00% / 71.43% line/condition/FSM/branch coverage; the
shared-SPAD mux has 100.00% / 75.00% / N/A / 100.00%. VCS is
`V-2023.12-SP1_Full64`, URG is `V-2023.12-SP1`. URG reports the expected
missing-FSM-shape warning for combinational modules; those shapes are N/A, not
zero-coverage failures. The uncovered bins remain in the report.

## Reproduction and artifacts

```sh
env -u VCS_ARCH_OVERRIDE make -C dv/subsystem/tensor_datapath/sim cluster_regress \
  CLUSTER_TAG=parallel_final_20261023 \
  CLUSTER_OUT=/tmp/nmaforge_compute_cluster_parallel_final_20261023 \
  CLUSTER_FORMAL_OUT=/tmp/nmaforge_compute_cluster_parallel_final_20261023/serial_formal \
  CLUSTER_COV_OUT=/tmp/nmaforge_compute_cluster_parallel_final_20261023/dut_coverage \
  COMPUTE_SEEDS='20261021 20261022 20261023' \
  COMPUTE_COV_SEEDS='20261021 20261022 20261023 20261024 20261025' \
  FP_SEEDS='712345 987654 20261020' \
  AI_RANDOM_CASES=20 AI_SEED=20261023 \
  VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

VCS was `V-2023.12-SP1_Full64`; VC Formal was `V-2023.12-SP2`. All five
top-only seed logs contain `TEST PASS`, and the top seed `20261023` log records
all 21 pair-overlap and ordered abort-drain checks. The ten DMA–SPAD–CNM UVM
seeds passed with warning/error/fatal counts of 0/0/0. The serial-cluster
formal setup was clean, with 3/3 assertions proven and 7/7 engine covers
reached. The merged and top-only URG reports are under
`/tmp/nmaforge_compute_cluster_parallel_final_20261023/dut_coverage/urg/` and
`/tmp/nmaforge_compute_cluster_parallel_final_20261023/dut_coverage/top_only_urg/`.

This evidence does not close all raw code bins, every multi-fault × abort ×
reset permutation, FP progress-bound proof and aggregate lifecycle closure, or
project-wide UVM/formal/LEC/DFT signoff. Exact commands and remaining limits
are recorded separately. See the
[verification plan](VPLAN.md) and [A10 RTM](A10_DV_RTM.md) for the project-wide
frontier.

### Parallel dispatcher formal

```sh
make -C dv/subsystem/tensor_datapath/formal dispatcher-pairs \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_parallel_dispatcher_formal_fullproof_20261023 TIMEOUT=360
```

VC Formal `V-2023.12-SP2` reported clean setup, 5/5 assertions proven, and
23/23 covers reached. Assertions cover launch ownership, completion payload
matching the retirement head, engine-done ownership, no launch after abort,
and bounded abort drain. Four properties with antecedents are non-vacuous;
engine-done ownership is an unconditional implication. The abort-drain proof
converged at safe depth 130 in about 305 seconds. The formal harness uses seven
representative descriptors and an abstract engine-done choice to check the
dispatcher queue and retirement logic. The 21-pair top smoke separately checks
the integrated engines and shared-SPAD mux. Completion backpressure and
project-wide formal closure remain open.

### FP full-domain parity lifecycle disposition

The six-property production-arithmetic lifecycle run remains 3/6 proven. The
isolated full-domain `ap_writeback_excludes_pending_parity` proof is 1/1
non-vacuous with 2/2 reachability covers. The progress-bound assertion was
retried with production arithmetic and with control-only arithmetic stubs; the
control-only run used independently proven request-frontier and cutoff-bound
assumptions. Both 300-second runs remained `checking` without a counterexample.
The parity-response cutoff lemma was retried with control-only arithmetic for
600 seconds and also timed out while `checking`, without a counterexample. The
run command was:

```sh
make -C dv/block/compute/fp/formal parity-full-event-cutoff-control-abstract \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_fp_event_cutoff_control_abstract_600_20261023 \
  FORMAL_PROBE_TIMEOUT=600
```

This is inconclusive, not a pass. Since the lemma is not independently proven,
the dependent compositional progress target was not run and is not used to
claim closure.
