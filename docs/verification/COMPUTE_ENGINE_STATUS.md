# Compute-engine verification status

Status date: 2026-10-26. The current worktree completed the expanded
multi-engine regression, an SFU transition-closure sweep, a focused
Dispatcher/SPAD-MUX UVM test, Matrix 16×16 dataflow updates, a three-seed
real-top seven-engine UVM slice, and a focused Matrix FSM convergence run.
This is targeted functional and raw code-coverage evidence; it is not full
signoff.

The group/compute aggregate figures below remain the 2026-10-23/24 merge and
were not recomputed with the current Matrix controller RTL. Matrix's updated
16×16 controller, focused code coverage, benchmark, and remaining dataflow/PPA
work are reported separately in the
[Compute Cluster upgrade roadmap](COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md).

## 2026-10-25 P0 Matrix array milestone (historical baseline)

`ai_tensor_matrix_core` now defaults to `ai_tensor_matrix_array` at
`ARRAY_SIZE=16`; the descriptor and 4×4 tile-major SPAD layout remain
unchanged. Three core seeds (`20261021/20261022/20261023`) each pass eight
numerical/layout cases, twelve fault/recovery cases, a 16×16 GEMM, and a 32×16
cross-macro-tile GEMM. The core-scoped URG report is 96.17% line / 90.83%
condition / 65.85% FSM transitions / 93.52% branch for
`ai_tensor_matrix_core`; the embedded array reports 82.35% line / 20.00%
condition / 58.82% branch. These are partial DUT code coverage.

The 2026-10-25 unified VCS benchmark sweeps physical arrays 4×4/8×8/16×16
against 4×4/8×8/16×16 workloads at K=32. With one-cycle modeled bank response,
seeded operand generation and fixed LFSR ready/stall pattern, the 16×16 array
runs 16×16×K32 in 357 cycles: 22.947 useful MAC/cycle, 8.96% command-wide
array utilization, and 11.473 GOPS normalized to 250 MHz. This is VCS cycle
throughput, not SRAM timing or PPA. DC V-2023.12-SP1 is installed and now starts
successfully, but this checkout has no current Matrix/Top synthesis runner or
SDC, and private TSMC standard-cell/SRAM libraries are unset, so
area/Fmax/power remain unmeasured. The
C0-P suite still uses behavioral Engines/SPAD. A separate real-top C1 slice
now passes three VCS seeds for Matrix/SFU GEMM, overlapping dispatch,
shared-arbiter traffic, ordered completion, active abort/reset, and reset
recovery. The exact command was
`make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_final_20261025`
with VCS `V-2023.12-SP1_Full64`; seeds `20261025/20261026/20261027` each
reported `COMPUTE_CLUSTER_REAL_UVM_PASS`, zero UVM warnings/errors/fatals, zero
orphan SPAD responses, two reset-dropped outstanding reads, and an empty
pending-read ledger. The directed UVM covergroup reports 55.5%.

The merged URG report has three tests. Its whole-top totals are
45.93% line / 39.46% condition / 8.99% FSM / 35.46% branch / 60.00% assertion
/ 17.88% group; module-definition totals are 47.09% / 38.97% / 10.35% /
35.87%. Those totals include the whole instantiated top, checker, testbench,
and UVM definitions; they are not DUT-only or Compute Cluster closure metrics.
The compile log has one `Warning-[TFIPC]` for omitted ports on the top-level
protocol SVA instance; elaboration reports zero errors. **This paragraph is
the initial 2026-10-25 UVM status and is superseded by the later closeout and
fixed-SHA replay below.** Broader fault/backpressure combinations and full C1
closure remain open. Exact source-to-test trace is in the roadmap and
[Compute Cluster UVM Testplan](COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md).

The same replay also reran
`make -C dv/subsystem/top_smoke/sim ai_smoke` (`TEST PASS`) and the Matrix
three-seed core regression for seeds `20261021/20261022/20261023` (each seed:
8 numeric/layout cases, 12 fault cases, one late-tile-fault case, and recovery).
The refreshed Matrix-core/array URG is 96.17% / 90.83% / 65.85% / 93.52% and
82.35% / 20.00% / N/A / 58.82% respectively (line/condition/FSM/branch).
Artifacts are under `/tmp/nmaforge_matrix16_core_regress_vcs_20261025/`.

## 2026-10-26 Matrix FSM and real-top seven-engine update

The Matrix core FSM-focused depth-4 three-seed regression and 4×4
prefetch-handoff run were merged with URG. `ai_tensor_matrix_core` reports
96.45% line / 88.52% condition / 49 of 53 FSM transitions (92.45%) / 95.02%
branch; all 15 states and all 9 prefetch-FSM transitions were hit. The four
remaining core transitions are individually classified in the
[upgrade roadmap](COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md#37-2026-10-26-all-engine-uvm-matrix-fsm-and-decoder-follow-up)
as guarded error paths or compile-time-disabled fallback behavior. The child
`matrix_tile_array` remains partial at 82.35% line / 20.00% condition /
58.82% branch. This is focused code-coverage closure, not 100% Matrix closure.

The real `ai_accel_top` UVM test now runs INT8 VDOT, BF16 dot, CNM, Matrix, SFU,
Conv3x3, and KV write, plus a separate KV readback/stride check. Three seeds
(`20261025/20261026/20261027`) pass with each engine's Golden/result and
completion checked. Each seed reports focused functional covergroup 97.9%,
UVM warning/error/fatal `0/0/0`, request backpressure over 236 cycles, and
Matrix/SFU concurrent Abort coverage. The scoreboard summary per seed is
`2594/2343/827/16/2/1152/1150/0/2` for
observations/busy/overlap/done/errors/reads/responses/orphan/reset-dropped;
all four CNM lane accepted/response counts are 64 and pending ledgers drain to
zero. `errors=2` are expected Abort completions. The merged whole-top URG
includes DUT, SVA, testbench, and UVM, so it is not a DUT-only coverage number.

This remains a directed slice. A later 2026-10-26 closeout extended the same
three-seed test with a byte-addressed reference-memory scoreboard and a
14-case seeded parity cross; see the exact testpoint/bin/result table in the
[Compute Cluster UVM testplan](COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md). Broader
opcode/shape crosses, protection × phase combinations, complete REQ coverage,
and a broad mutation campaign remain open. The compile retains an
existing `Warning-[TFIPC]` for unconnected optional top protocol-SVA inputs.

The closeout run `/tmp/nmaforge_cluster_closeout_multiseed_20261026/` passes
seeds `20261025/20261026/20261027`, each with 14/14 parity cases, 3,584
reference-memory writes, 3,536 compared words, zero mismatches/unknown reads,
zero orphan responses, empty pending queues, and UVM warning/error/fatal
`0/0/0`. Focused functional coverage is 97.92% (28/30 bins); `dma` and
`completion` response-client bins are unhit because those requesters are not
part of this directed compute sequence. The merged whole-top URG still mixes
DUT, assertions, testbench and UVM and is not a DUT-only coverage claim.

The tested source SHA `827c0052cf589fde676e93e34bf459188956182f` was replayed
in a detached clean worktree. The three-seed UVM, eight-configuration Matrix
benchmark, separate prefetch-off fallback run, 86-descriptor fixed-weight
Transformer, top smoke, and 20-case seeded top run all passed. A temporary
bank-0 registered read-data bit flip was caught by 192 memory-scoreboard
mismatches plus a Matrix Golden fatal; restoring the RTL returned the same
seed to zero mismatches and zero UVM errors/fatals. This is one targeted
mutation sensitivity check, not a broad mutation campaign. Exact artifacts
and the coverage audit are in the
[clean-SHA evidence record](COMPUTE_CLUSTER_CLEAN_REPLAY_2026-10-26.md).

The Matrix core's prefetch-enabled profile remains at 49/53 FSM transitions;
the four raw misses and a separate prefetch-disabled fallback benchmark are
reviewed in the roadmap. One `ST_MAC→ST_A_REQ` fallback is now dynamically
covered with prefetch disabled, but no cross-macro URG percentage is reported
because the compile-time condition shapes differ.

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
