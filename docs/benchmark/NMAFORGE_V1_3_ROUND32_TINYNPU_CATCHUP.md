# NMAForge V1.3 Round 32 — TinyNPU Performance Catch-up

**Disposition: CATCH_UP_PARTIAL.** The GEMM cycle and SPAD-read minimums pass. The GEMM challenge cycle target remains open. The 1×64×64 GEMV minimum passes all checked seeds, while its challenge threshold passes only with fixed-latency memory. Product behavior and byte-exact INT8 results pass the listed checks. ASIC area and timing are unmeasured because the private TSMC28 synthesis environment is unavailable.

## Scope and baseline

The isolated branch `research/nmaforge-v1.3-round32-tinynpu-catchup` starts at product commit `8f2ed82c7d7a58885bc19f0b263490f7817a5f51`. Baseline and candidate GEMM measurements use the same VCS harness, 16×16 Matrix array, 128 KiB behavioral SPAD, fixed one-cycle memory mode or seeded SPAD back-pressure, and independent INT32 Golden. The baseline compile explicitly sets eight outstanding reads to match the candidate; its B-tile cache is disabled. Random seeds are 20261122, 20261124, and 20261125.

The freshly rerun TinyNPU source is pinned to `8216c22b762011aa20c05fc2768423fd12dda59d`. The older historical 3,166/790-cycle CSV belongs to `38a2498af81f78b9dd8f81144026cf45e2b8328c`; it is not mixed with the fresh runs. TinyNPU reports direct-array input-to-stable cycles. NMAForge reports Product Matrix command cycles including behavioral SPAD and controller activity. These boundaries are different, so no TinyNPU/NMAForge speed ratio is claimed.

## Round 32 targets

| Workload / metric | Before | Round 32 | Minimum | Challenge | Result |
|---|---:|---:|---:|---:|---|
| GEMM 64×64×64, fixed memory | 3,413 cycles | 2,768 cycles | ≤3,000 | ≤2,600 | Minimum pass; challenge miss |
| GEMM 64×64×64, seeded memory | 4,783 / 4,758 / 4,745 | 3,550 / 3,529 / 3,546 | ≤3,800 | ≤3,200 | Minimum passes all seeds; challenge miss |
| GEMV 1×64×64, fixed memory | 584 cycles, four descriptors | 358 cycles, one descriptor | ≤500 | ≤400 | Minimum and challenge pass |
| GEMV 1×64×64, seeded memory | 818 / 841 / 845, four descriptors | 433 / 467 / 479, one descriptor | ≤500 | ≤400 | Minimum passes all seeds; challenge misses seeded cases |
| GEMM SPAD read bytes, 64×64×64 | 20,480 B | 8,192 B | ≤16,384 B | ≤12,288 B | Minimum and challenge pass |
| GEMM fixed array utilization | 30.0% | 37.0% | ≥34% | ≥39% | Minimum pass; challenge miss |
| Matrix MAC count / default SPAD | 256 / 128 KiB | 256 / 128 KiB | Preserve | Preserve | Preserved |

All four checked GEMM shapes (16×16×16, 16×16×32, 32×32×64, 64×64×64) pass their Golden at fixed memory and all three seeded runs. Candidate cycles for the 32×32×64 workload improve from 919 to 804 at fixed memory; its input read traffic drops from 6,144 B to 4,096 B. The small single-tile GEMM shapes retain their prior cycle counts.

## RTL changes

1. **Reuse GEMM B tiles.** `ai_tensor_matrix_core` has a command-local 4 KiB B-panel cache for eligible non-transposed GEMM shapes. It retains four N panels of sixteen K words across the four M tiles of a 64×64×64 operation. The 64×64×64 read traffic changes from 20,480 B to 8,192 B, while output writes remain 16,384 B. The measured fixed-memory cycle improvement is 18.9%; seeded improvements are about 25%.
2. **Widen the 0x52 GEMV path.** The descriptor validator now accepts supported N widths through 256 in 16-column multiples. The Matrix core executes wide outputs in panels and keeps the shared 16×16 MAC array. A single 1×64×64 descriptor replaces four 16-column descriptors; fixed cycles drop 38.7%, and the three seeded runs improve by 47.1%, 44.5%, and 43.3% respectively.
3. **Increase Matrix read issue capacity.** The default outstanding read limit is eight. A depth-four ablation shows little and mixed cycle impact on this fixture; the measured B-tile reuse accounts for the dominant GEMM gain.
4. **Keep product contracts.** The default 128 KiB SPAD and 256 MACs are unchanged. The command/completion ABI size is unchanged. SPEC text documents the legal wide-GEMV shape and dense-row stride. Tests check one-descriptor Product Top execution and signed INT32 Golden output.

The evidence profile separates exclusive controller-state cycle counts from event counters such as arbiter stalls, response waits, writeback waits, and prefetch overlap. Event counters can overlap and must not be added to total cycles. `cycle_breakdown.csv` checks that each exclusive-state sum equals the measured total.

## Ablations and comparison limits

The checked B-cache-off build reproduces the pre-Round-32 64×64×64 cycles and read bytes at every selected seed. With the cache on, the fixed run saves 645 cycles and 12,288 read bytes; the seeded runs save 1,199–1,233 cycles and the same 12,288 read bytes. This isolates B-panel reuse as the main gain.

Outstanding-read depth 4 versus 8 changes fixed cycles by zero. Across random seeds the difference is small and mixed, so the result does not support attributing the large gain to the issue-depth change.

TinyNPU direct-array GEMM at the pinned revision measures 3,166 cycles for 64×64×64, and direct-array GEMV measures 790 cycles for 1×64×64. These are useful same-shape reference points, not matched Product Top comparisons. The evidence also contains a fresh TinyNPU CNN graph run and a separate NMAForge Product Top ONNX run; they have different graph setup, preload, and completion boundaries and are not ratio-comparable.

The separate synthetic two-layer Product Top fusion fixture remains Golden-clean: legacy, first-fusion, and both-fusion command-path results are 60,930, 34,324, and 7,708 cycles respectively, with 20,480 Golden words each. This is evidence for that synthetic fixture only and is not the TinyNPU trained-CNN comparison.

## Verification and limits

- Top smoke with four random cases and the seeded 20-case top run pass.
- Descriptor validator test passes 49 legal and 28 illegal vectors.
- Compute Cluster UVM regression passes at 128, 256, and 512 KiB SPAD configurations for seed 20261122.
- Matrix FSM formal passes 5/5 assertions and 2/2 covers. GEMV request-stability formal reached the 360-second timeout without a proof result; it remains unresolved.
- All focused GEMM and wide-GEMV benchmark shapes pass their independent Golden checks. TinyNPU compute-engine regression passes 6/6; the fresh TinyNPU CNN graph matches all four Golden bytes; NMAForge Product Top ONNX output is byte-exact.
- PPA is `BLOCKED_ENV`: `dc_shell` is unavailable and `TSMC28_STDCELL_DB` is unset. No mapped area, critical path, timing, or signoff claim is made. The area-growth guardrail therefore remains unverified.

## Reproduction and evidence

Main regression commands, tool versions, source hashes, benchmark target status, workload hashes, and formal/PPA dispositions are in `benchmark/performance_dominance/round32/evidence/run_manifest.json`.

```sh
cd dv/subsystem/top_smoke/sim
make ai_smoke AI_RANDOM_CASES=4 AI_SEED=12345
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345

cd dv/block/control/sim
make descriptor-validator-regress

cd dv/uvm/sim
make uvm_compute_cluster_regress SPAD_KIB=128 COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_round32_uvm_128 COMPUTE_CLUSTER_UVM_SEEDS=20261122
make uvm_compute_cluster_regress SPAD_KIB=256 COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_round32_uvm_256 COMPUTE_CLUSTER_UVM_SEEDS=20261122
make uvm_compute_cluster_regress SPAD_KIB=512 COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_round32_uvm_512 COMPUTE_CLUSTER_UVM_SEEDS=20261122

cd dv/block/compute/matrix/formal
make fsm-guards OUT=/tmp/nmaforge_round32_formal_fsm gemv-request-stability GEMV_REQUEST_OUT=/tmp/nmaforge_round32_formal_gemv
```

The focused VCS benchmark raw logs are under `/tmp/nmaforge_round32_baseline_ot8`, `/tmp/nmaforge_round32_final`, `/tmp/nmaforge_round32_ablation_nobcache_ot8`, and `/tmp/nmaforge_round32_depth4`. TinyNPU logs and pinned source identity are under `/tmp/nmaforge_round32_tinywork`; synthetic Product Top fusion logs are under `/tmp/nmaforge_round32_cnn_*`. These generated simulator directories are not checked in. The committed CSVs retain each measured row’s source log path, and the manifest records the source identities.

## Evidence files

- `benchmark/performance_dominance/round32/evidence/comparison.csv` — baseline, candidate, TinyNPU direct-array, wide-GEMV, and CNN/fusion measurements with explicit boundaries.
- `benchmark/performance_dominance/round32/evidence/cycle_breakdown.csv` — exclusive state cycles and separate potentially overlapping events.
- `benchmark/performance_dominance/round32/evidence/ablation.csv` — B-cache, outstanding-read depth, and GEMV descriptor-packing comparisons.
- `benchmark/performance_dominance/round32/evidence/ppa_guardrail.csv` — blocked area/timing guardrail disposition.
- `benchmark/performance_dominance/round32/evidence/source/tb_ai_tensor_matrix_core_round32.sv` — focused benchmark testbench.
