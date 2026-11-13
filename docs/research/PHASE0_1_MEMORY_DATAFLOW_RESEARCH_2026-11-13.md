# Phase 0/1 Memory and Dataflow Research

Date: 2026-11-13
Status: Phase 0/1 scoped baseline and feasibility study; no product RTL change.
Product RTL candidate: `fc60f95d72c0cfb7dfa9df895a30a701c842d21e` (`candidate/frontend-closeout`).
Research checkout: `0492c47d12cd11bcc22be1930da7af77ed870b6e` (`dv/compute-cluster-closure-round2` before this documentation branch).
PR #7 remains OPEN/DRAFT (`candidate/frontend-closeout` → `nmaforge`, head `f919bb787dab1a4e3bef44b5308ead56d6e77b72`); PR #8 remains OPEN/DRAFT (`dv/compute-cluster-closure-round2` → `candidate/frontend-closeout`, head `0492c47d12cd11bcc22be1930da7af77ed870b6e`). Neither is merged.
Configuration: 128 KiB, four banks, 16x16 INT8 array / 256 MAC, VCS behavioral registered SPAD. The closeout profile reports a 4 ns functional clock; this is not a physical timing claim.

## Decisions

| Item | Result | Evidence boundary |
|---|---|---|
| A1, lifetime-aware placement | **REWORK / model-only** | The idea is feasible as an offline dependency/lifetime allocator. This turn did not produce a candidate-SHA accepted-transaction lifetime trace or allocator A/B. Do not use the older 79,872 B H32 high-water as current evidence. |
| A2, memory-aware tiling | **REWORK / no new mapper claim** | Existing shape-aware M1/M4/M8/M16 measurements and Matrix controller configuration ablation are useful baselines. They do not demonstrate a new joint shape/bank/DMA/padding/lifetime cost model. |
| Product RTL | **RETAIN unchanged** | No candidate mechanism has a complete safety proof, end-to-end A/B, or physical cost result. No conditional RTL candidate is justified now. |
| Next experiment | Offline A1/A2 scheduler/allocator model on candidate-bound traces; then replay unchanged workloads and Golden on the real 128 KiB DUT. | Stop before RTL unless predicted and measured end-to-end gains agree and live-range legality is proven. |

## Related work comparison

This is a scoped comparison, not a novelty search. DOI titles and abstracts below were checked through Semantic Scholar metadata. Full papers were not reviewed where not openly available.

| Work | Established result relevant here | NMAForge implementation / candidate distinction | Research status |
|---|---|---|---|
| Li et al., “An 800-MHz 8.17-TOPS/W 0.63-TOPS/mm2 Memory-Utilization-Aware CNN Accelerator Featuring a Memory Stationary Dataflow,” JSSC 2025, [10.1109/JSSC.2025.3532544](https://doi.org/10.1109/JSSC.2025.3532544) | Memory-stationary CNN dataflow combines input/output feature storage and reduces feature movement; paper also uses quantization and channel gating. | NMAForge has a shared four-bank SPAD and explicit command materialization. A1 proposes lifetime-safe placement and A2 a cost model, neither implemented here. | It is prior art for memory utilization/data movement. No comparable energy or silicon claim is made here. Abstract-level check only. |
| MediaTek Tiny NPU, ISSCC 2025 (user-supplied reference: depth-first fusion/local reuse) | The cited design direction is operator fusion and local reuse to reduce intermediate movement. | NMAForge's existing fused CNN mapper and cross-command engine schedule are already baseline behavior. A new allocator/model must beat that baseline and preserve required visible writes. | Exact paper title/session metadata was not independently confirmed in this run; treat the supplied label as a research lead, not a verified citation. |
| Moon et al., “T-REX: Hardware-Software Co-Optimized Transformer Accelerator With Reduced External Memory Access and Enhanced Hardware Utilization,” JSSC 2026, [10.1109/JSSC.2025.3603187](https://doi.org/10.1109/JSSC.2025.3603187) | Transformer parameter compression, dynamic batching, and a two-directionally accessible register file/dataflow target external-memory movement and utilization. | NMAForge is a fixed 16x16 INT8 cluster with 128 KiB SPAD, explicit descriptors, and no equivalent dynamic batching or TRF. | Useful comparison for data reuse, not a direct scale/technology or performance comparator. Abstract-level check. |
| Maji et al., “An Energy-Efficient Neural Network Accelerator With Improved Resilience Against Fault Attacks,” JSSC 2024, [10.1109/JSSC.2024.3374638](https://doi.org/10.1109/JSSC.2024.3374638) | On-chip cryptographic checks detect model/result corruption caused by fault attacks. | Phase 2 proposal is verification-side causal ownership/epoch/commit checking for shared-SPAD traffic, not an equivalent fault sensor or security claim. | Motivates fault-aware evidence; not part of Phase 0/1 experiments. Abstract-level check. |
| DVCon 2025, “Transaction Sequence Modeling / Coverage-Driven Verification” (user-supplied topic) | Transaction models can guide sequence generation and coverage closure. | The proposed Phase 2 V1 needs a controlled V0/V1 comparison with identical DUT, mutation set, and simulation budget. No methodology result exists yet. | Exact paper title/authors/session were not confirmed. Do not present this phrase as a verified bibliographic citation or contribution. |
| Existing NMAForge implementation and prior reports | Shape-aware dispatch, CNN fusion, Matrix A-tile cache, next-K prefetch, outstanding reads, and cross-engine forwarding already exist in the product candidate. | They are the baseline, not innovations of this study. See `NMAFORGE_FRONTEND_CLOSEOUT.md`, `docs/research/INNOVATION_A_HYPOTHESIS.md`, `docs/research/INNOVATION_B_HYPOTHESIS.md`. | Prior artifact source hashes must be checked before reuse; legacy Stage A allocation results are not rebound to this candidate by this report. |

## Exact-candidate baseline

The immutable closeout manifest at `benchmark/verification/frontend_closeout/manifest.json` pins RTL SHA `fc60f95d72c0cfb7dfa9df895a30a701c842d21e`, default geometry, VCS `V-2023.12-SP1_Full64`, and hashes for the Matrix core, DMA, compute SPAD mux, mapper and workload inputs. Its report and archived evidence provide the following candidate-bound baseline:

| Workload | Cycles | SPAD read/write bytes | Result |
|---|---:|---:|---|
| Trained CNN, CMDQ | 11,376 | 64,064 / 16,640 | Independent Golden PASS |
| H16, persistent 8 tokens | 65,771 total; 8,221.375/token | 72,448 / 42,112 | Independent Golden PASS |
| H32, persistent 8 tokens | 350,155 total; 43,769.375/token | 546,816 / 227,840 | Independent Golden PASS |
| Shape-aware M1/M4/M8/M16, K16/32/64/128 | See `benchmark/verification/frontend_closeout/system.csv` | Per-run payload is recorded there | Golden PASS; M1/M4 keep legacy policy, larger shapes can select the existing shape-aware path |

The closeout report records the normal-model CNN input preload as 10,944 B / 3,019 cycles, and output payload 3,328 B with 4,992 Lite cycles versus 922 DMA cycles. This is a hardware delivery interval, not whole-application latency. The candidate has a 128 KiB behavioral SPAD with a registered two-cycle response contract; no SRAM-macro or Fmax inference follows from these simulations.

The older `benchmark/research/stage_a/analysis/current_memory.json` and H32 report high-water are historical inputs from another reviewed source snapshot. They are deliberately excluded from candidate-SHA memory-lifetime conclusions below.

## Matrix configuration ablation

The VCS test ran five deterministic shapes for each of three seeds (20261025, 20261026, 20261027) under all eight combinations of outstanding depth 2/4, next-K prefetch 0/1, and A-tile cache 0/1. Physical array and Golden checks were fixed. The recorded CSVs and compile/run logs are in `benchmark/research/phase0_1_compute_cluster/raw/`.

| Label | Existing parameters | Mean cycles across 15 shape-seed samples | Range | Change vs B0 |
|---|---|---:|---:|---:|
| B0 | depth 2, prefetch off, A-cache off | 544.7 | 103–1,732 | baseline |
| B1 | depth 2, prefetch off, A-cache on | 483.5 | 103–1,493 | -11.23% |
| B2 | depth 4, prefetch on, A-cache on | 376.9 | 68–1,146 | -30.80% |

These means are an equal-weight mean across five unlike shapes and are descriptive, not a workload-weighted product score. Every configuration/seed contains five `MATRIX_CORE_CASE_PASS` cases; total 120/120 Golden points pass. B1 vs B0 isolates the A-tile-cache toggle at depth 2 with prefetch disabled. B2 vs B0 changes three controls, so it is a bundled controller-configuration comparison, not a causal estimate for any single feature and not a new tiling algorithm.

| Shape MxNxK | B0 mean | B1 mean | B2 mean | B0/B1 A-read count per run |
|---|---:|---:|---:|---:|
| 4x4x32 | 103.7 | 103.7 | 70.3 | 16 / 16 |
| 8x8x32 | 138.7 | 138.7 | 108.7 | 32 / 32 |
| 16x16x32 | 246.7 | 246.7 | 208.3 | 64 / 64 |
| 16x32x32 | 516.3 | 452.0 | 366.3 | 128 / 96 |
| 32x32x64 | 1,718.3 | 1,476.7 | 1,131.0 | 512 / 384 |

The A-cache reduces these two larger cases' observed A bank-read count by 25%; the first three shapes have no read-count change. `bank_stalls` is an engine/controller stall counter and does not prove a physical per-bank conflict or bank utilization. Array utilization columns in these microbench logs are scoped to the Matrix benchmark's internal active-MAC denominator, not whole-workload utilization. Energy, macro timing, actual bank busy cycles, peak simultaneous SPAD allocation, and DMA/compute contention were not measured here.

## Memory lifetime and bottlenecks

Candidate-bound evidence shows substantial traffic and a specific Matrix read-reuse opportunity: the CNN issues 64,064 B reads / 16,640 B writes; H32 issues 546,816 B / 227,840 B; Matrix A-cache lowers repeated A reads for multi-N-tile shapes in the isolated test. The CNN fixture provides these exact known ranges in `benchmark/research/phase0_1_compute_cluster/cnn_known_ranges.csv`:

| Range `[start,end)` | Size | Live phase | Boundary evidence |
|---|---:|---|---|
| `[0,7488)` | 7,488 B | preload through compute | DMA segment 0 |
| `[8192,10496)` | 2,304 B | preload through compute | DMA segment 1 |
| `[81920,82944)` | 1,024 B | preload through compute | DMA segment 2 |
| `[102400,105728)` | 3,328 B | compute commit through host readback | 832 output words |
| `[106496,106624)` | 128 B | preload through command fetch | two descriptors; DMA segment 3 is the same descriptor object |
| `[107008,107040)` | 32 B | completion through host consume | completion reservation / candidate manifest high-water |

All listed ranges are inside `[0,131072)`. The descriptor/DMA overlap is an exact alias of the same 128-byte object, not a competing allocation. The listed regions are pairwise disjoint apart from that explicit identity alias. This is a bounded fixture map, not a complete tensor map: it does not expose every weight/intermediate object's live interval, nor does it prove the map can be compacted further.

| Requested measurement | Status | Why / next evidence |
|---|---|---|
| Known CNN input/output/descriptor/CPLQ bounds | MEASURED, PARTIAL | See `cnn_known_ranges.csv`; ranges are in bounds and the only overlay is descriptor preload into its own descriptor storage. |
| Full tensor live ranges and legal alias graph | NOT_MEASURED | Extend the exact candidate workload manifest with command dependency/accepted transaction trace; include write completion and fault/abort lifetime endpoints. |
| Peak SPAD allocation, by active interval | NOT_MEASURED | Recompute from all candidate-bound object allocations and prove each simultaneously live range is disjoint and within `[0, 131072)`. |
| Per-bank utilization / physical conflicts | NOT_MEASURED | Current banked read and stall counts are not per-bank occupancy or conflict attribution. Add passive bank accept/response counters to the benchmark monitor. |
| Operand wait / arbitration stall split | PARTIAL | Matrix benchmark reports controller stalls; no candidate-wide mutually exclusive wait taxonomy was collected in this study. |
| DMA and compute concurrent throughput/competition | NOT_MEASURED | The closeout includes DMA delivery and concurrent AXI gaps, but not a controlled overlapping DMA payload plus engine-SPAD benchmark with both traffic sources independently counted. |
| Golden / fault / reset | PARTIAL | Baseline Golden PASS is available for CNN/H16/H32 and Matrix configurations. This ablation is not a new fault/reset stress experiment. |

The CNM compact-SPAD address-overlap bug remains a required negative regression for A1: construct two simultaneously live ranges with the original collision, require allocator rejection, and keep the existing line-stalled CNM Golden unchanged. Do not truncate/mask addresses or shorten lifetimes before producer completion and in-flight response drain.

## A1/A2 feasibility and go/no-go

**A1 lifetime-aware allocation: REWORK.** Offline graph construction and static interval placement are plausible and do not require RTL. Feasibility is not established until the source-SHA-matched command graph carries explicit producer commit, consumer read completion, abort/reset epoch, and fault termination edges. Run a legal allocation against the current 128 KiB boundary, compare against the existing mapper with unchanged descriptors/Golden, and include the CNM collision negative fixture. Only retain if the actual live high-water falls or a fixed model gains capacity without adding illegal aliasing or materializing a required output differently.

**A2 memory-aware tiling: REWORK.** Existing shape-aware output routing shows no M1/M4 gain and useful M8/M16 K128 delivery gains of 11.00% and 21.51% in the frontend closeout. This is already implemented policy, not evidence for a new model. New A2 must train/calibrate a cost model over shape, bank mapping, input/output DMA transfer, padding and intermediate live ranges, then choose among legal schedules. Compare prediction and real end-to-end execution on the same Golden, input image, memory model and simulation setup. B0/B1/B2 only establishes sensitivity to current Matrix controls.

**Conditional RTL candidate: NO-GO.** No new RTL or ABI change is admitted. First complete candidate-bound transaction/lifetime traces and the offline allocator/cost model. Reject the architecture candidate if improvements disappear after DMA, writeback, command, padding and conflict costs, or if its benefit requires changing visible commit/ownership semantics.

## Reproduction

Run from the repository root in the licensed VCS environment. Use a fresh output root for each seed:

```bash
for seed in 20261025 20261026 20261027; do
  make -C dv/block/compute/matrix/sim matrix-config-comparison \
    SEED=$seed MATRIX_CONFIG_OUT=/tmp/nmaforge-phase1-matrix-$seed
done
```

Tool recorded: `VCS V-2023.12-SP1_Full64`. The checked-in `Makefile` target runs all eight existing configurations and the independent testbench Golden. It emits `matrix_config_comparison.csv`; preserve each `compile.log` and `run.log`. To inspect this report's exact archive, verify the three CSV SHA256 values against `raw/SHA256SUMS`, then list/extract `raw/matrix_vcs_logs.tar.gz`. For candidate baseline reproduction, follow `NMAFORGE_FRONTEND_CLOSEOUT.md` and its manifest-pinned command. Do not combine old Stage A allocation measurements with this SHA.

## Phase 1 exit

Phase 0 scoped prior-art matrix and candidate baseline are documented. B0/B1/B2 ran on candidate-matched Matrix RTL and all checked Golden points passed. A1/A2 are feasible as **offline research models**, but the present evidence is insufficient to admit either as a product architecture feature or to claim a research contribution. Candidate-bound lifetimes, peak usage, bank occupancy/conflict attribution, and controlled DMA/compute contention remain open before Phase 1 closure.
