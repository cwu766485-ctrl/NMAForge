# NMAForge v2 Round 27 — Performance Gate Review

**Disposition: PARTIAL**\
**Research branch:** `research/harish-tiny-npu-fair-comparison-20261121`\
**Tested NMAForge source SHA:** `49441dfafa130731c822c43bf2e500023e58423c`\
**Tiny-NPU repository:** `harishsg993010/tiny-NPU`\
**Tiny-NPU source SHA:** `38a2498af81f78b9dd8f81144026cf45e2b8328c`\
**Run ID:** `R27-HARISH-20261122-S20261122`

This round closes bounded GEMM/GEMV, CNN layout, and basic regression experiments. It does not close a matched controller-plus-memory comparison, GPT-2/DeiT model deployment, full Design Verification, or ASIC PPA.

## Gate Status

| Gate | Status | Evidence |
|---|---|---|
| 1. Paired GEMM/GEMV benchmark | **PARTIAL** | Fixed operands and independent INT32 Golden pass on both designs. The measured RTL endpoints differ, so no system speedup is computed. |
| 2. GEMV/CNN dataflow optimization | **PASS for bounded A/B** | Four-way GEMV cache/prefetch sweep and three CNN layout modes pass Golden; the improvement is limited to the stated measurement window. |
| 3. GPT-2 and DeiT deployment closure | **NOT RUN** | No model integration or quality work was performed in this performance round. |
| 4. Compute Cluster DV and final integration | **PARTIAL** | `ai_smoke` and a 20-case seeded top run pass. This is not full UVM, formal, coverage, or sign-off closure. |

## Gate 1 — Paired GEMM/GEMV Results

Both projects used the same deterministic INT8 operands and independent INT32 expected results for the paired shapes. NMAForge timings include its Matrix controller and a one-cycle behavioral SPAD. Tiny-NPU timings come from its direct-array testbench and exclude controller and memory service. The values below are therefore measured points at different boundaries, **not cross-project speedups**.

| Workload | NMAForge cycles | Tiny-NPU cycles | NMAForge useful MAC/cycle | Tiny-NPU useful MAC/cycle | Golden |
|---|---:|---:|---:|---:|---|
| GEMM 16×16×16 | 151 | 52 | 27.126 | 78.7692 | PASS / PASS |
| GEMM 16×16×32 | 241 | 100 | 33.992 | 81.9200 | PASS / PASS |
| GEMM 32×32×64 | 1,290 | 790 | 50.803 | 82.9570 | PASS / PASS |
| GEMM 64×64×64 | 4,822 | 3,166 | 54.364 | 82.7997 | PASS / PASS |
| GEMV 1×64×64 | 632 (prefetch off) | 790 | 6.4810 | 5.1848 | PASS / PASS |

The 16×16 array size sweep passed 15/15 array/shape combinations. The remaining fixed GEMV cases and full per-run data are in [`gemm_results.csv`](../../benchmark/tinynpu/round27/R27-HARISH-20261122-S20261122/gemm_results.csv). Tiny-NPU reports no comparable controller-side traffic counters for these direct-array runs.

The common `conv1x_mini.onnx` graph also passed on both implementations with identical model and input hashes. NMAForge measured 1,874 CMDQ cycles plus 1,080 separately measured host-layout cycles; Tiny-NPU measured 4,781 graph-testbench cycles. These windows differ: the NMAForge number excludes preload, descriptor programming, and final host read; the Tiny-NPU number uses its graph dispatcher and testbench DMA/SRAM shim and excludes testbench input setup. No CNN speedup is claimed.

## Gate 2 — GEMV Cache/Prefetch A/B

The four-way experiment used the existing 0x52 GEMV path, 16×16 physical array, a registered four-bank behavioral SPAD with seed-controlled readiness/latency, seed `20261122`, and bit-exact output checking. For shape 16×16×65:

| B-fold cache | Next-K prefetch | Cycles | SPAD read bytes | MAC active cycles | Useful MAC/cycle | Array utilization | Golden |
|---|---|---:|---:|---:|---:|---:|---|
| OFF | OFF | 1,074 | 5,440 | 68 | 15.4935 | 6.0521% | PASS |
| OFF | ON | 1,017 | 5,440 | 68 | 16.3618 | 6.3913% | PASS |
| ON | OFF | 649 | 2,368 | 68 | 25.6394 | 10.0154% | PASS |
| ON | ON | 623 | 2,368 | 68 | 26.7095 | 10.4334% | PASS |

With cache enabled, command latency fell 39.57% and operand read traffic fell 56.47% relative to OFF/OFF. Enabling prefetch on top of cache saved a further 26 cycles (4.01% relative to cache-only). Prefetch without cache saved 57 cycles (5.31%). This supports B-fold reuse as the larger contributor for this batched shape; it does not imply an equivalent M=1 decode gain. The one-seed A/B should be repeated across more seeds before treating the exact percentages as stable.

The run reports exclusive state partition cycles equal to command cycles. Prefetch wait, arbiter, bank, and line counters are event counters that may overlap and must not be added together. See [`gemv_four_way_ablation.csv`](../../benchmark/tinynpu/round27/R27-HARISH-20261122-S20261122/gemv_four_way_ablation.csv) and the raw CSV beside it.

Additional bounded checks:

- M=1 1×64×64 GEMV: prefetch OFF 632 cycles; ON 584 cycles, both with 4,352 read bytes and 256 write bytes, Golden 64/64. This is a 7.60% reduction at the Matrix RTL endpoint, not top-level token latency.
- CNM 1×64×64 directed test: 64/64 output words pass. Always-ready execution took 897 cycles; deterministic per-bank readiness stalls took 1,010 cycles (+12.60%) and produced the same Golden. The stall test is a block-level behavioral-memory test, not the Top arbiter.

## CNN Layout A/B

The same `conv1x_mini.onnx` model, seed-99 INT8 input, expected bytes, compiled simulator, and 1,872 useful MACs were used for all three NMAForge modes. All three passed byte-exact output checking.

| Mode | Descriptors | CMDQ cycles | Host layout cycles | Reported phase cycles | Compute SPAD read/write bytes | Host layout read/write bytes |
|---|---:|---:|---:|---:|---:|---:|
| Legacy GEMM + Requant | 8 | 1,874 | 1,080 | 2,954 | 3,360 / 1,600 | 144 / 576 |
| First-layer fused, native Matrix-A output | 7 | 1,393 | 1,080 | 2,473 | 2,784 / 1,024 | 144 / 576 |
| First-layer fused, Linear-Row output | 7 | 1,430 | 0 | 1,430 | 2,784 / 1,456 | 0 / 0 |

Within this phase window, Linear-Row reduced cycles 51.59% versus Legacy and 42.18% versus native-layout fused. It removes the measured host reorder by producing the consumer-compatible layout in the existing product path; compared with native fused it writes 432 more SPAD bytes and spends 37 more CMDQ cycles. These are **not end-to-end inference numbers**: preload, descriptor programming, and final host output read are excluded. The experiment uses the mini CNN, not the 570,164-MAC trained CNN.

See [`cnn_layout_ablation.csv`](../../benchmark/tinynpu/round27/R27-HARISH-20261122-S20261122/cnn_layout_ablation.csv), [`cnn_layout_ablation.json`](../../benchmark/tinynpu/round27/R27-HARISH-20261122-S20261122/cnn_layout_ablation.json), and archived raw run logs.

## Gate 4 — Regression and RTL Scope

The tested source commit `49441df` contains a bounded CNM fix: per-bank `local_done` pulses are latched until all banks have completed, preventing an early bank completion pulse from being missed while other banks are still active. It also adds the directed CNM bank-stall test. Existing GEMV prefetch and four-way tests exercise Matrix behavior; no GEMV/Matrix RTL optimization was introduced for the measured cache/prefetch A/B.

Actual checks on the tested source:

| Command | Result |
|---|---|
| `make -C dv/subsystem/top_smoke/sim ai_smoke` | PASS (`TEST PASS`) |
| `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | PASS (`TEST PASS`, 20 cases, seed 12345) |
| `make -C dv/block/compute/cnm/sim ai_cnm_round27_gemv_1x64` | PASS, 64/64 words |
| `make -C dv/block/compute/matrix/sim round27-gemv-prefetch-ablation SEEDS=20261122` | PASS, both configurations 64/64 |
| `make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation SEEDS=20261122 PHYSICAL_ARRAY_SIZE=16 GEMV_FOUR_WAY_OUT=/tmp/nmaforge_round27_multirow_ablation_20261122` | PASS, 16/16 rows |

No claim is made for UVM closure, full coverage closure, formal, CDC/RDC, synthesis, or PPA. The top regression make wrapper's seeded-result grep was stricter than the actual simulator log; the log itself contains the explicit `TEST PASS` after the 20-case run.

## Reproduction and Evidence

Run from the repository root unless the command specifies `-C`:

```bash
BENCH_RUN_ID=R27-HARISH-20261122-S20261122 \
SEED=20261122 \
TINYNPU_BENCH_OUT=/tmp/nmaforge_round27_full_20261122 \
TINYNPU_WORK_ROOT=/tmp/harish_tiny_npu_round27 \
TINY_NPU_ROOT=/tmp/harish_tiny_npu_round27 \
VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
PYTHON=/tmp/nmaforge-round27-venv/bin/python JOBS=4 \
bash benchmark/tinynpu/run_comparison.sh

make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation \
  SEEDS=20261122 PHYSICAL_ARRAY_SIZE=16 \
  GEMV_FOUR_WAY_OUT=/tmp/nmaforge_round27_multirow_ablation_20261122

make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/compute/cnm/sim ai_cnm_round27_gemv_1x64
make -C dv/block/compute/matrix/sim round27-gemv-prefetch-ablation SEEDS=20261122
```

Tools used: Synopsys VCS `V-2023.12-SP1_Full64`; Verilator `5.052`; g++ `8.5`; Python `3.11.13`; NumPy `2.4.6`; ONNX `1.23.2`. Model and input SHA-256 values, exact run metadata, archived logs, and per-file log hashes are in [`evidence_manifest.json`](../../benchmark/tinynpu/round27/R27-HARISH-20261122-S20261122/evidence_manifest.json) and [`evidence_log_hashes.json`](../../benchmark/tinynpu/round27/R27-HARISH-20261122-S20261122/evidence_log_hashes.json).

The archived Tiny-NPU tree was rebuilt from the pinned SHA. Its engine regression passed 6/6; the shared mini-CNN graph passed 4/4 outputs. Raw compile/run logs and Make output are under [`evidence/logs`](../../benchmark/tinynpu/round27/R27-HARISH-20261122-S20261122/evidence/logs/).

## Remaining Work

1. Build a true matched controller-plus-memory endpoint before computing a Tiny-NPU system speedup. Until then, report only separately measured raw endpoints.
2. Repeat the shape/cache/prefetch experiments over multiple seeds or characterize their deterministic timing contract more fully.
3. Apply the measured dataflow findings to representative trained CNN workloads and complete host-to-host accounting; the current layout experiment is the common mini CNN only.
4. Continue GPT-2 quality recovery and DeiT continuous encoder integration on their isolated model tracks. Neither was modified or closed in this round.
5. Run the separate full DV and ASIC-readiness work only under its own reviewed scope; it was not part of this performance round.
