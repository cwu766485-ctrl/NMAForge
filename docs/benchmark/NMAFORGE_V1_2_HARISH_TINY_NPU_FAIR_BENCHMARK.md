# NMAForge v1.2 vs `harishsg993010/tiny-NPU` — Fair Benchmark Review

**Disposition: PARTIAL — reproducible paired microbenchmarks and one common CNN are available; the requested model and larger-shape matrix is incomplete.**

This report is specific to [`harishsg993010/tiny-NPU`](https://github.com/harishsg993010/tiny-NPU). It does not use results from Leonui/tiny-npu or other similarly named projects.

## 1. Frozen source and measurement boundary

| Item | Frozen identity | Scope |
|---|---|---|
| NMAForge GPT-2 research baseline | `research/nmaforge-v1.2-round31-gpt2`, `f7d15974fc654e58e4e48dce1b8f4c87171e67c8` | Source used for the runs in this report |
| NMAForge DeiT research baseline | `research/nmaforge-v1.2-round31-deit`, `d9ef7112efb4ffdada75768f07c1f82d09f9200b` | Frozen and audited as a branch identity; **not** qualified by these runs |
| TinyNPU reference | `8216c22b762011aa20c05fc2768423fd12dda59d` | Exact repository `harishsg993010/tiny-NPU`, detached checkout |
| TinyNPU tree | `5346e3c4568051bf250ccfae03cd7dd42f2897f7` | Clean source tree at the pinned commit |
| GEMM/CNN run | `NMA-R31-FAIR-20261121-S20261121` | Seed `20261121`; CNN input seed `99` |
| GEMV run | `NMA-R31-GEMV-20261121-S20261121` | Seed `20261121` |

NMAForge GPT-2 and DeiT are separate source baselines. There is no single merged model RTL SHA in this experiment. Do not interpret the NMAForge results as a regression of the DeiT branch.

### Actual RTL hierarchy used

| Benchmark | NMAForge side | TinyNPU side | Classification |
|---|---|---|---|
| GEMM | Matrix controller + 16×16 Matrix RTL + registered four-bank behavioral SPAD. Not the full `ai_accel_top` product flow. | `sim/verilator/engine_tb_top.sv` directly drives `rtl/gemm/systolic_array.sv`; no product command controller or memory interface in this measurement. | Different RTL endpoints; the Tiny common-memory endpoint below is modeled. |
| GEMV | Product Matrix Core GEMV opcode `0x52` + behavioral SPAD. | Direct shared 16×16 systolic array with operands zero-padded to the array; no measured TinyNPU GEMV descriptor/SPAD path. | Different RTL endpoints; Tiny common-memory service is modeled. |
| CNN | `rtl/top/ai_accel_top.v` top smoke path, default four-bank 128 KiB SPAD profile, two CMDQ execution windows. | `sim/verilator/onnx_sim_top.sv` Graph wrapper, graph engines, shared wrapper SRAM and testbench DMA/SRAM shim. | Different graph/controller and setup boundaries; no system speedup is calculated. |

The pinned TinyNPU `rtl/top.sv` has AXI ports and a 128-bit AXI data parameter, but it is not the GEMM/Graph product endpoint measured here: its `graph_status` is tied low until a graph top is instantiated, and the GEMM command path uses a simulated ten-cycle completion timer rather than the systolic array. The benchmark therefore uses the project's direct-array and ONNX-wrapper testbenches, not `rtl/top.sv` as if it were an integrated compute product.

### Compute and memory resources observed in source

| Resource | NMAForge | TinyNPU |
|---|---|---|
| INT8 MAC array | 16×16 = 256 INT8 MACs, INT32 accumulation | `systolic_array` default 16×16 = 256 PEs; direct RTL benchmark uses DATA_W=8 and ACC_W=32 |
| FP16 | Not part of these measurements | FP16 mode signals exist in the array/PE RTL; no integrated-top FP16 run or result is included |
| Product/benchmark memory | NMAForge Product Top default SPAD is 4 banks × 8192 words × 4 B = 128 KiB; paired matrix tests use behavioral SPAD | `top.sv` contains 1024×128-bit ucode SRAM = 16 KiB. The ONNX wrapper separately exposes SRAM0 64 KiB, program memory 16 KiB, tensor table 8 KiB, accumulator SRAM 1 KiB, scratch 8 KiB (97 KiB aggregate wrapper-local storage). A separate, uninstantiated KV module is configured for 256 KiB; it is not part of the measured top. These capacities must not be collapsed into one TinyNPU product-memory number. |
| External data bus | NMAForge Product Top M_AXI is 128-bit data; this benchmark does not measure external DDR transactions | Tiny `top.sv` parameter is 128-bit AXI; direct-array benchmarks expose no external memory bus to the array |
| Clock/frequency | No physical clock frequency measured. Some legacy derived metrics may assume 250 MHz; this is not an achieved frequency. | No physical clock frequency measured. |
| Area/power | Not measured | Not measured |

The hierarchy and resource statements above are source audits; module presence is not evidence of integration or functional qualification.

## 2. Toolchain and reproduction

Tool versions captured by the run:

| Tool | Version/path used |
|---|---|
| Synopsys VCS | `/usr/local/bin/vcs`, `V-2023.12-SP1_Full64` |
| Verilator | `/tmp/nmaforge_verilator_5.052/bin/verilator`, `5.052 2026-09-05 rev v5.052` |
| Python | 3.12.13, `/tmp/nmaforge_tiny_bench_venv/bin/python` |
| NumPy | 2.4.6 |
| ONNX | 1.17.0 |

Re-run from the NMAForge source SHA shown above, with the pinned TinyNPU checkout:

```bash
BENCH_RUN_ID=NMA-R31-FAIR-20261121-S20261121 \
SEED=20261121 \
TINYNPU_BENCH_OUT=/tmp/nmaforge_round31_full_benchmark \
TINYNPU_WORK_ROOT=/tmp/nmaforge_round31_full_benchmark/reference \
TINY_NPU_ROOT=/tmp/nmaforge_harish_tiny_npu_20261121 \
PYTHON=/tmp/nmaforge_tiny_bench_venv/bin/python \
VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
VCS=/usr/local/bin/vcs JOBS=4 \
bash benchmark/tinynpu/run_comparison.sh
```

```bash
BENCH_RUN_ID=NMA-R31-GEMV-20261121-S20261121 SEED=20261121 \
GEMV_BENCH_OUT=/tmp/nmaforge_round31_gemv \
TINYNPU_WORK_ROOT=/tmp/nmaforge_round31_gemv/reference \
TINY_NPU_ROOT=/tmp/nmaforge_harish_tiny_npu_20261121 \
PYTHON=/tmp/nmaforge_tiny_bench_venv/bin/python \
VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator JOBS=4 \
bash benchmark/tinynpu/run_gemv_match.sh
```

Both scripted benchmark runs completed with exit code 0 in the recorded run. Raw compile/run logs are preserved byte-for-byte in `raw_logs.tar.gz`; their individual hashes are listed in `manifest.json`. The CSV/JSON and logs are under [`benchmark/tinynpu/results/harishsg993010/20261121/`](../../benchmark/tinynpu/results/harishsg993010/20261121/). The run used behavioral SPAD and RTL simulation, not SRAM timing or ASIC PPA.

## 3. Paired INT8 GEMM

Inputs use the same deterministic signed INT8 A/B formulas, INT32 accumulation, and independent integer GEMM Golden. All listed outputs passed on both sides. NMAForge cycles and traffic are measured at its Matrix-controller/behavioral-SPAD boundary. TinyNPU direct-array cycles are RTL measured; the normalized column adds a **serialized modeled** memory service (16 B/cycle, one-cycle read response, two accumulator-clear cycles) and is not TinyNPU system RTL.

| M×N×K | Useful MACs | NMA measured cycles | NMA MAC/cycle | NMA PE util. | NMA SPAD R/W bytes | NMA bank/line stalls | Tiny direct-array RTL cycles | Tiny normalized modeled cycles | NMA / Tiny normalized cycles | Golden |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 16×16×16 | 4,096 | 175 | 23.406 | 9.14% | 512 / 1,024 | 9 / 34 | 52 | 151 | 1.1589 | PASS / PASS |
| 16×16×32 | 8,192 | 221 | 37.068 | 14.48% | 1,024 / 1,024 | 16 / 17 | 100 | 231 | 0.9567 | PASS / PASS |
| 32×32×64 | 65,536 | 1,280 | 51.200 | 20.00% | 6,144 / 4,096 | 140 / 70 | 790 | 1,305 | 0.9808 | PASS / PASS |

`NMA / Tiny normalized cycles` is a ratio of unlike measured/modelled endpoints; greater than one means the NMAForge measured endpoint took more cycles than that serialized TinyNPU model. Values near one are not evidence of a system-level win. On direct array cycles alone TinyNPU is faster, but that endpoint excludes data service and NMAForge's controller.

The benchmark run also includes an NMAForge-only 15-case array-size sweep (4×4, 8×8, 16×16 physical arrays and several logical shapes). It is not a paired TinyNPU result and is not used to claim comparative performance.

## 4. Paired GEMV

NMAForge uses opcode `0x52` on its Matrix controller and registered four-bank behavioral SPAD. TinyNPU pads each logical shape onto the direct 16×16 array; Tiny has no measured matching GEMV controller/SPAD path. The normalized Tiny cycles add a separate serialized common-memory estimate. NMA stage wait counters can overlap and must not be summed as mutually exclusive cycle buckets.

| M×N×K | Useful MACs | NMA cycles | NMA MAC/cycle | NMA PE util. | NMA SPAD R/W bytes | NMA bank/line stalls | Tiny direct-array RTL cycles | Tiny normalized modeled cycles | NMA / Tiny normalized cycles | Golden |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1×13×17 | 221 | 68 | 3.250 | 1.27% | 304 / 52 | 10 / 0 | 100 | 126 | 0.5397 | PASS / PASS |
| 8×16×19 | 2,432 | 150 | 16.213 | 6.33% | 560 / 512 | 7 / 8 | 100 | 170 | 0.8824 | PASS / PASS |
| 16×16×19 | 4,864 | 261 | 18.636 | 7.28% | 816 / 1,024 | 22 / 16 | 100 | 218 | 1.1972 | PASS / PASS |
| 16×16×65 | 16,640 | 649 | 25.639 | 10.02% | 2,368 / 1,024 | 69 / 39 | 244 | 459 | 1.4139 | PASS / PASS |

At K=65 the run records 358 prefetch-wait events and 108 arbiter-stall events; these counters overlap, so they are diagnostic evidence, not additive cycles. The direct-array versus controller figures are not a fair full-system comparison. The normalized comparison also favors the explicitly serialized memory schedule, so it must remain labelled as modeled.

## 5. Common ONNX Mini CNN

Both sides used the same `conv1x_mini.onnx`, INT8 input, and final output. The input was generated with seed 99. NMAForge checked intermediate tensors and all four output bytes; TinyNPU checked all four output bytes. Both Golden checks passed.

| Field | NMAForge | TinyNPU |
|---|---|---|
| Model SHA-256 | `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640` | same |
| INT8 input SHA-256 | `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898` | same |
| Useful MACs | 1,872 | 1,872 |
| Execution boundary | Product Top smoke, 8 descriptors across two CMDQ windows; compute 1,874 cycles; host layout 1,080 cycles separately; subtotal 2,954 cycles | ONNX graph wrapper, graph dispatcher and testbench DMA/SRAM shim; 4,781 cycles |
| Traffic | Compute SPAD read/write 3,360 / 1,600 B; host-layout read/write 144 / 576 B; SPAD init 3,456 B | Wrapper SRAM traffic 1,312 B |
| Golden | Intermediate tensors and 4/4 final output bytes PASS | 4/4 final output bytes PASS |
| Excluded work | NMAForge excludes SPAD preload, descriptor programming and final host read; host layout is separately counted | Tiny excludes testbench input setup |

No CNN speedup is computed. The cycles cover different graph/command, memory, and setup work. Neither run establishes trained-model accuracy; this is a deterministic one-input ONNX functional workload.

## 6. Requested work not measured

| Requested case | Status | Reason / limit |
|---|---|---|
| INT8 GEMM 64×64×64, paired | NOT_RUN | Existing paired harness contains 16×16×16, 16×16×32, and 32×32×64. The NMA-only size sweep does not supply a matching Tiny result. |
| INT8 GEMM 192×192×192, paired | NOT_RUN | No paired command, output, or Golden in the archived run. |
| GEMV 1×64×64, paired | NOT_RUN | Existing matched GEMV shapes are 1×13×17, 8×16×19, 16×16×19, and 16×16×65. |
| FFN 64→256→64 | NOT_RUN | No paired two-GEMM/activation execution or full-path timing recorded. |
| H64, Context 16, 4-head attention | NOT_RUN | No paired attention command, common model weights, or matching TinyNPU product endpoint recorded. |
| Same H64, 4-layer GPT-2 model; prefill 5 + generate 10 | NOT_RUN | No common weight package/numeric contract and paired per-token logits in this benchmark. |
| Full recompute vs persistent KV decode | NOT_RUN | This run has no paired GPT-2 runtime measurement. No software estimate is substituted. |
| CNN beyond `conv1x_mini.onnx`, including trained CNN | NOT_RUN | Only the common four-output ONNX smoke was run. |
| Phase-4 optimization A/B | NOT_RUN | No optimization was implemented or measured in this comparison package. No area/timing delta exists. |
| Product-level TinyNPU controller + memory endpoint | NOT_RUN | Pinned `rtl/top.sv` GEMM command path is a timed stub; direct array/ONNX wrapper are the available measured endpoints. |
| Area, power, Fmax, frequency-normalized latency | NOT MEASURED | No matched synthesis/PPA flow was run. There is no measured frequency to convert cycles into seconds. |

## 7. What the current evidence says

- **GEMM:** all three paired outputs are correct. The Tiny direct array completes sooner than NMAForge's controller-plus-SPAD endpoint; under the separate serialized modeled-memory endpoint, the cycle counts are close (ratios 0.9567 and 0.9808 for the latter two shapes). This is a useful controller/memory hypothesis, not a system-level TinyNPU win.
- **GEMV:** NMAForge has a real `0x52` controller path and reports actual SPAD bytes. In this set the normalized model favors NMAForge for the two small shapes and TinyNPU for the two 16-row cases; the largest case shows substantial prefetch/arbiter wait events. Because Tiny's memory service is modeled and its compute is padded array RTL, these observations do not prove a platform-level ranking.
- **CNN:** both implementations match the same tiny output, but they time different execution stacks. NMAForge's host-layout work is material (1,080 cycles, separate from 1,874 compute cycles). The recorded 2,954-cycle subtotal and Tiny's 4,781 graph cycles cannot be divided into a defensible speedup.
- **Optimization:** no A/B optimization has been run here. The evidence suggests follow-up should measure NMAForge GEMV prefetch/arbiter behavior and CNN host layout/data movement, but there is no measured gain or area/timing cost to claim.
- **Model quality and full deployment:** this benchmark does not qualify GPT-2 language quality, persistent GPT-2 KV decode, DeiT classification, or either model's full end-to-end deployment.

## 8. Final comparison table

| Metric | NMAForge evidence | TinyNPU evidence | Comparable? |
|---|---|---|---|
| INT8 MAC count | 256 MACs in 16×16 Matrix configuration | 256 array PEs | Array size aligns; actual command/data paths do not |
| GEMM/GEMV cycles | Controller + behavioral SPAD RTL | Direct array RTL; common memory endpoint estimated | No strict system speedup |
| CNN cycles | Product Top compute/host-layout subwindows | ONNX Graph wrapper cycles | No; boundary differs |
| DMA/SPAD bytes | NMAForge SPAD bytes measured for its wrappers | GEMM/GEMV bytes modeled; CNN wrapper reports SRAM traffic | Partial, not equivalent memory systems |
| SRAM capacity | 128 KiB Product Top SPAD profile | 16 KiB ucode in `top.sv`; distinct 97 KiB ONNX wrapper storage; separate 256 KiB KV module not instantiated in top | Cannot state one directly comparable TinyNPU SRAM capacity |
| FP16 | Not measured | RTL mode exists in array/PE, not measured or qualified at integrated top | No |
| Accuracy | Not a trained model benchmark | Not a trained model benchmark | No |
| Area / Power / Frequency | NOT MEASURED | NOT MEASURED | No |

**Current disposition: `PARTIAL`.** The archived evidence is reproducible for its listed scope, but does not satisfy the requested full shape matrix, same GPT-2 workload, full attention, or optimization A/B. The proper next step is to add paired tests only where both pinned source trees expose a real, clearly defined execution endpoint; until then retain independent endpoint results without converting them into system-level speedup claims.

## 9. Artifact index

- [`benchmark_summary.json`](../../benchmark/tinynpu/results/harishsg993010/20261121/benchmark_summary.json)
- [`gemm_results.csv`](../../benchmark/tinynpu/results/harishsg993010/20261121/gemm_results.csv)
- [`gemv_summary.json`](../../benchmark/tinynpu/results/harishsg993010/20261121/gemv_summary.json)
- [`gemv_results.csv`](../../benchmark/tinynpu/results/harishsg993010/20261121/gemv_results.csv)
- [`cnn_summary.json`](../../benchmark/tinynpu/results/harishsg993010/20261121/cnn_summary.json)
- [`cnn_results.csv`](../../benchmark/tinynpu/results/harishsg993010/20261121/cnn_results.csv)
- [`raw_logs.tar.gz`](../../benchmark/tinynpu/results/harishsg993010/20261121/raw_logs.tar.gz) contains the unmodified VCS/Verilator compile and run logs; `manifest.json` records per-log hashes.
- [`manifest.json`](../../benchmark/tinynpu/results/harishsg993010/20261121/manifest.json) and [`SHA256SUMS.txt`](../../benchmark/tinynpu/results/harishsg993010/20261121/SHA256SUMS.txt) bind run metadata and retained evidence files.
