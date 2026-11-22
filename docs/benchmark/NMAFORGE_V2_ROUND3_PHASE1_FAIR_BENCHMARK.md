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
