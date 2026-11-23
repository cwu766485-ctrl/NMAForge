# Round 3 — Phase 1: Fair Benchmark Baseline

**Disposition: PARTIAL.** The fixed GEMM matrix and `conv1x_mini.onnx` were rebuilt and passed Golden checks. TinyNPU does not expose a matching scratchpad/controller endpoint, so its normalized GEMM rows mix measured array RTL with an explicit serialized memory model; no system-level speedup is claimed.

## Frozen run

| Item | Value |
|---|---|
| Run ID / seed | `NMA-ROUND3-FAIR-20261122` / `20261122` |
| NMAForge source SHA | `c4c2970ad8e66c93e00e854ef3befff4ccc9188b` |
| TinyNPU source SHA | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| TinyNPU repository | `harishsg993010/tiny-NPU` |
| VCS | `V-2023.12-SP1_Full64` |
| Verilator / Python / NumPy / ONNX | `5.052` / `3.12.13` / `2.2.6` / `1.17.0` |
| Reproduction | `VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator PYTHON=/tmp/nmaforge_round3_bench_py312/bin/python JOBS=2 SEED=20261122 BENCH_RUN_ID=NMA-ROUND3-FAIR-20261122 TINYNPU_BENCH_OUT=/tmp/nmaforge_round3_fair_20261122 bash benchmark/tinynpu/run_comparison.sh` |

The run marker was `BENCHMARK_PASS` with the two SHAs above. VCS log SHA-256: GEMM `ff672481825a5a41bd08c5ef450c7d9203a551fbe16202354d0b43ce26854780`; CNN `fd79fc3fe6e0265441b86b906441679b6730e05207a1d771eb0b5f044465828c`. Logs remain in `/tmp/nmaforge_round3_fair_20261122/` and are not checked in as generated simulator output.

## Matched GEMM results

All three signed INT8/INT32 cases matched the independent Golden in both designs. NMAForge cycles are measured from Matrix command acceptance through final SPAD output commit, with its Matrix controller and behavioral SPAD. TinyNPU array cycles are direct RTL measurements; the normalized endpoint adds a serialized model using 16 bytes/cycle, one-cycle read response, and no load/compute/store overlap. The ratio is `NMAForge measured / TinyNPU normalized`; greater than 1 means NMAForge took more cycles under this mixed endpoint.

| Shape | Useful MACs | NMAForge cycles | TinyNPU array RTL cycles | TinyNPU modeled memory cycles | TinyNPU normalized cycles | NMA / normalized | NMA SPAD R/W bytes |
|---|---:|---:|---:|---:|---:|---:|---:|
| 16×16×16 | 4,096 | 151 | 52 | 99 | 151 | 1.0000 | 512 / 1,024 |
| 16×16×32 | 8,192 | 241 | 100 | 131 | 231 | 1.0433 | 1,024 / 1,024 |
| 32×32×64 | 65,536 | 1,290 | 790 | 515 | 1,305 | 0.9885 | 6,144 / 4,096 |

The normalized observations are near parity: the middle shape is 4.33% higher for NMAForge, the largest is 1.15% lower, and the smallest ties. These are not ASIC or full-system comparisons. TinyNPU direct-array throughput should not be divided into NMAForge controller cycles and labeled system speedup.

## CNN result and boundary

Both implementations passed all 1,872 useful INT8 MACs against the same model/input Golden. Model SHA-256 is `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`; deterministic INT8 input SHA-256 is `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898` (seed 99).

| Design endpoint | Cycles | Detail |
|---|---:|---|
| NMAForge CMDQ compute | 1,874 | 8 descriptors; SPAD read/write 3,360 / 1,600 B |
| NMAForge testbench host layout | 1,080 | 144 B read, 576 B written; testbench-modeled AXI operations, not CPU wall time |
| NMAForge reported phase subtotal | 2,954 | Compute + host layout only; excludes preload, descriptor programming, final output read and orchestration |
| TinyNPU ONNX graph smoke | 4,781 | Graph dispatcher plus testbench DMA/SRAM shim; input setup excluded |

The endpoints differ; no CNN speedup is computed. SPAD initialization (3,456 B) is reported as test setup, not production payload.

## Files and limits

- Machine-readable data: [`gemm_results.csv`](../../benchmark/tinynpu/gemm_results.csv), [`cnn_results.csv`](../../benchmark/tinynpu/cnn_results.csv), [`benchmark_summary.json`](../../benchmark/tinynpu/benchmark_summary.json), [`cnn_summary.json`](../../benchmark/tinynpu/cnn_summary.json).
- Reproduction entry: [`run_comparison.sh`](../../benchmark/tinynpu/run_comparison.sh).
- No RTL was changed. No matched controller+memory RTL endpoint, common native graph endpoint, physical area, power, or ASIC frequency was measured.
- The direct-array sweep in `gemm_results.csv` uses a one-cycle behavioral SPAD and is a separate compute-engine observation.

## Dated rerun addendum — 2026-11-23

The fixed benchmark matrix was rerun as `NMA-ROUND3-FAIR-FINAL-20261123`, seed `20261123`, using the same NMAForge source/test SHA (`c4c2970ad8e66c93e00e854ef3befff4ccc9188b`) and TinyNPU SHA (`8216c22b762011aa20c05fc2768423fd12dda59d`). Tool versions were VCS `V-2023.12-SP1_Full64`, Verilator `5.052 2026-09-05 rev v5.052`, Python `3.12.13`, NumPy `2.2.6`, and ONNX `1.17.0`.

| Shape | Useful MACs | NMAForge measured cycles | TinyNPU array RTL cycles | TinyNPU normalized cycles | NMA / normalized | Golden |
|---|---:|---:|---:|---:|---:|---|
| 16×16×16 | 4,096 | 173 | 52 | 151 | 1.1457 | Both PASS |
| 16×16×32 | 8,192 | 234 | 100 | 231 | 1.0130 | Both PASS |
| 32×32×64 | 65,536 | 1,301 | 790 | 1,305 | 0.9969 | Both PASS |

NMAForge uses measured Matrix-controller plus behavioral-SPAD cycles. TinyNPU normalized cycles add a modeled, serialized 16-byte/cycle memory service with one-cycle read response and two accumulator-clear cycles to measured array RTL. Thus the ratios are mixed measured/modeled normalized observations, not matched-system speedups. NMAForge is slower in the first two rows under this model and near parity in the third; the last row is only 4 cycles lower and does not establish a robust advantage.

The 2026-11-22 report above records `151 / 241 / 1,290` NMAForge cycles for these shapes, whereas this rerun records `173 / 234 / 1,301`. The source/test SHA is unchanged, but the seed and run/configuration context differ. The available artifacts do not explain the per-shape deltas. Keep both dated measurements and treat cycle reproducibility as OPEN until the harness/configuration difference is identified; do not replace the historical values.

The same rerun checked `conv1x_mini.onnx` (model SHA-256 `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`, input seed 99, SHA-256 `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`). Both sides passed the independent Golden for 1,872 useful MACs. NMAForge measured 1,874 CMDQ compute cycles and separately modeled 1,080 host-layout cycles; the 2,954 subtotal excludes preload, descriptor programming, final output read, and orchestration. TinyNPU reported 4,781 graph-smoke cycles with a testbench DMA/SRAM shim and excluded setup. These endpoints differ, so no CNN speedup is computed.

Machine-readable rerun evidence and hashes are in [`round3-20261123 evidence`](evidence/round3-20261123/). Raw simulator logs remain in the originating `/tmp` run directories and are represented by SHA-256 entries in `log_manifest.json`; they are not checked in. This is deliberate because the H64 raw log failed credential-like-pattern screening. The checked-in H64 artifacts are sanitized and contain no raw log lines.
