# Compute Cluster and TinyNPU paired replay — R134

## Result

**Benchmark run PASS; Compute Cluster sign-off remains HOLD.** At fixed
NMAForge source SHA `207cc3896cb635ff04e7095fc18c435080507724`, the paired
TinyNPU GEMM and CNN harness completed. Both sides passed their independent
Golden checks. This refreshes reproducible functional/cycle evidence; it does
not close `REQ-CL-028`, prove a common-memory RTL comparison, or establish an
ASIC performance advantage.

## Run identity and environment

| Field | Value |
|---|---|
| Run ID | `R134-TINY-NPU-PAIRED-20261031` |
| NMAForge test/source SHA | `207cc3896cb635ff04e7095fc18c435080507724` |
| TinyNPU SHA | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| Seed | `20261026` (GEMM); CNN input seed `99` |
| VCS | `V-2023.12-SP1_Full64` |
| Verilator | `5.052`, source revision `ea338be98e1e838d3518809ce8899f85a009963c` |
| Python / NumPy / ONNX | `3.12.13` / `2.4.6` / `1.17.0` |
| CNN model | `conv1x_mini.onnx`, SHA-256 `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640` |
| CNN input INT8 | seed `99`, SHA-256 `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898` |

The pinned TinyNPU checkout was verified at the listed Git SHA. The host did
not have Verilator installed, so Verilator 5.052 was built in `/tmp` using
`make -C src -j4 opt PYTHON3=python3.12` and installed to an isolated `/tmp`
prefix with `make installbin installredirect installdata`. No repository RTL
or system installation was changed for this setup.

Exact benchmark command (paths resolve to the isolated R134 `/tmp` run area):

```sh
VERILATOR=/tmp/nmaforge_r134_tinynpu_20261031/verilator/bin/verilator \
make benchmark-tinynpu \
  PYTHON=/tmp/nmaforge_r134_tinynpu_20261031/venv/bin/python \
  SEED=20261026 \
  BENCH_RUN_ID=R134-TINY-NPU-PAIRED-20261031 \
  TINYNPU_BENCH_OUT=/tmp/nmaforge_r134_tinynpu_20261031 \
  TINYNPU_WORK_ROOT=/tmp/nmaforge_r134_tinynpu_20261031/reference JOBS=4
```

The command ended with `BENCHMARK_PASS`, both source SHAs, and the R134 output
directory. VCS, Verilator, Python, NumPy and ONNX versions are recorded in the
machine summaries. The pinned TinyNPU's own compute-engine regression also
passed 6/6 checks.

## Matched INT8 GEMM

All three shapes use identical deterministic signed INT8 A/B vectors and
independent signed INT32 output Golden checks. NMAForge cycles and traffic are
measured on the Matrix controller and one-cycle behavioral SPAD. TinyNPU's
array cycles are measured RTL; its normalized endpoint adds a serialized
16-byte/cycle, one-cycle-response memory schedule, including load/store and
two accumulator-clear cycles. TinyNPU does not expose the corresponding SPAD
port, so the normalized values are a model, not measured memory-system RTL.

| Shape | NMAForge measured cycles | NMAForge SPAD read/write bytes | TinyNPU array RTL cycles | TinyNPU normalized cycles | Golden |
|---|---:|---:|---:|---:|---|
| 16×16×16 | 171 | 512 / 1,024 | 52 | 151 | PASS both (256 outputs each) |
| 16×16×32 | 263 | 1,024 / 1,024 | 100 | 231 | PASS both (256 outputs each) |
| 32×32×64 | 1,393 | 6,144 / 4,096 | 790 | 1,305 | PASS both (1,024 outputs each) |

Under this explicitly normalized schedule, NMAForge takes 20, 32 and 88 more
cycles, respectively. The numbers do not demonstrate a TinyNPU or NMAForge
system-level win: only NMAForge traverses its real controller and behavioral
SPAD; TinyNPU's memory portion is modeled and serialized. The result does
show that the current Matrix controller/SPAD path has remaining latency to
optimize for these shapes.

The R134 script also completed the NMAForge 4×4/8×8/16×16 size sweep (15/15
Golden points). The separate R133 run at the same NMAForge SHA and seed passed
the 16×16 physical-array configuration grid (depth 2/4 × prefetch OFF/ON ×
A-cache OFF/ON × five shapes, 40/40 Golden points). Detailed R134 size and
paired results remain in the CSV; the independent [R133 report](../benchmark/COMPUTE_CLUSTER_MATRIX_BENCHMARK_R133_2026-10-31.md)
documents the eight-configuration ablation and traffic/stall interpretation.

## Paired CNN graph

Both designs execute the same fixed-weight `conv1x_mini.onnx` graph (1,872
logical INT8 MACs). TinyNPU completes its graph in 4,781 testbench cycles and
passes all four output bytes. NMAForge passes every intermediate tensor and
all four output bytes, with 1,985 measured compute cycles plus 1,080 separately
measured host layout cycles. The NMAForge interval spans two CMDQ windows and
excludes preload, descriptor programming and final host reads; TinyNPU uses
its graph dispatcher and DMA/SRAM testbench shim. As the timing boundaries
differ, no CNN speedup is computed. This is a fixed-weight functional smoke,
not trained-model inference.

## Evidence and disposition

Committed machine-readable evidence:

- [`gemm_results.csv`](../../benchmark/tinynpu/gemm_results.csv)
- [`benchmark_summary.json`](../../benchmark/tinynpu/benchmark_summary.json)
- [`cnn_results.csv`](../../benchmark/tinynpu/cnn_results.csv)
- [`cnn_summary.json`](../../benchmark/tinynpu/cnn_summary.json)

Raw logs and full run JSON/CSV remain under
`/tmp/nmaforge_r134_tinynpu_20261031/`. SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| GEMM run log | `81d9be233ed5327f6add86af6f1004ff85ea8505ee07b15f49135502c930f831` |
| TinyNPU engine regression log | `7dfc3091722f50a7fe926d105403584ef050cf1b2ded2146547a126f218bc5c6` |
| TinyNPU CNN run log | `8791f7f4bbc406518ae117ad2d81d3b2aeef5c65309017a497f1f0d2bc8df39b` |
| NMAForge matched GEMM run log | `71a851d07b9d06f91bb359723e2e68676dbca9dd57f26ef3df20b20250cafbcc` |
| NMAForge CNN run log | `75e40cd9e764e611ca66c46cfa50cec497bac638805eef493d40a3e99768b1c7` |
| Benchmark summary JSON | `3fcfe1980cbcf9a6c0952edf3d040b16652cff50a534c59ce770c406e15c515a` |
| CNN summary JSON | `131784d050817637364b7c9be9e5f94651f94b75fd9219439f22faafbb9e9a34` |
| GEMM CSV | `33835fa7fd06948af0e210519a7b26811560e12a5bf134d9e87da3b4852cbf1e` |
| CNN CSV | `f08b8cd6603d44352bc93745b0680edf10444b6da0954b01d9ddd9976d2b279b` |

`REQ-CL-028` remains **PARTIAL**: the workload set is not the full requested
TinyNPU common-resource suite (notably 64×64 and GEMV/decode are absent), the
TinyNPU memory service is modeled, and system-level concurrency is not
benchmarked here. The full 38-row disposition remains 24 PASS-SCOPED / 14
PARTIAL and `CL-DV-v1.0` remains **HOLD**. This run is functional/cycle
evidence only; it is not SRAM timing, ASIC PPA, measured Fmax, power, or a
trained model result.
