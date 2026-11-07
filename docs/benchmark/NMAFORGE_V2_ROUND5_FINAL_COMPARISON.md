# NMAForge v2 Round 5 — Final Comparison

**Disposition: `RESEARCH_BASELINE_PARTIAL`; fixed Round 5 work is complete and
stops here.** This is a research benchmark snapshot, not v2 DV Sign-off, ASIC
sign-off, or a TinyNPU system-level victory.

## 1. Frozen identities and tools

| Item | Identity |
|---|---|
| Reviewed source/test SHA | `73caef0f32140d1635816f1eb4ea28372523e80c` |
| Initial remote target HEAD | `73caef0f32140d1635816f1eb4ea28372523e80c` |
| Product RTL baseline | `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23` |
| TinyNPU reference | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| VCS | `V-2023.12-SP1_Full64` |
| Python / NumPy / ONNX | `3.12.13 / 2.4.6 / 1.17.0` |
| Verilator | `5.052` |
| Design Compiler | `V-2023.12-SP1` |

No product RTL changed during this round. Relative to product RTL baseline
`cd0a05d`, the existing product RTL changes remain confined to
`rtl/compute/matrix/ai_tensor_matrix_core.v` and
`rtl/control/descriptor/ai_descriptor_validator.v` for the already-existing
bounded `0x53` Linear-Row mode. Round 5 code changes are limited to an
opt-in software Mapper experiment, its unit tests / Makefile policy plumbing,
and an exploratory synthesis script. The default Transformer mapping remains
`0x30` GEMM. `main` R250 was not touched.

## 2. CNN results and speedups

### Shared `conv1x_mini.onnx`

Model/input/Golden SHA-256:

- Model: `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`
- Input: `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`
- Output Golden: `94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c`

| System / mode | Useful MACs | Compute / graph cycles | Host Layout cycles | SPAD bytes R/W | Golden |
|---|---:|---:|---:|---:|---|
| NMAForge Legacy Top | 1,872 | 1,985 | 1,080 (testbench-emulated) | Compute 3,360/1,600; layout 144/576 | PASS, byte exact |
| NMAForge `0x53` Linear-Row Top | 1,872 | 1,504 | 0 | 2,784/1,456 | PASS, byte exact |
| TinyNPU ONNX Graph | 1,872 | 4,781 graph-runtime cycles | not separately instrumented | not available | PASS, 4/4 output bytes |

Observed useful throughput is 0.943/1.245 useful MAC per NMAForge compute
cycle for Legacy/Linear-Row (0.369%/0.486% effective occupancy of the 256-MAC
array across that CMDQ interval). TinyNPU's graph-only effective rate is
0.392 useful MAC/cycle, but its graph cycles do not expose Matrix-active,
dispatch, DMA wait, writeback, or memory service sub-counters. Those phase
fields are `N/A_NOT_INSTRUMENTED` in the model CSV rather than inferred from
the top-level total.

Within the same NMAForge Top measurement, Legacy→Linear-Row Compute speedup is
`1,985 / 1,504 = 1.320×` (24.23% fewer cycles). Including the testbench's
simulated Legacy Host Layout, the same NMAForge task window is `3,065 / 1,504
= 2.038×` (50.93% fewer simulation cycles). The latter layout is simulated
AXI transactions, not host CPU wall time. TinyNPU's graph runtime includes
its graph dispatcher and testbench DMA/SRAM shim, so the TinyNPU 4,781 cycles
do not share the NMAForge start/stop boundary. **No cross-system CNN speedup
is calculated.**

### Trained ten-class Digits CNN

Weights SHA-256:
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`;
held-out set SHA-256:
`cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`.
Both modes ran all 396 held-out samples, passed every intermediate/final
Golden, and classified 384/396 (96.9697%). Per sample:

| Measure | Legacy | `0x53` Linear-Row | Same-system change |
|---|---:|---:|---:|
| Useful MACs | 2,736 | 2,736 | unchanged |
| Top CMDQ cycles | 3,193 | 2,712 | `1.177×`, −15.06% |
| Useful MAC / CMDQ cycle | 0.857 | 1.009 | derived |
| Effective 256-MAC occupancy over CMDQ interval | 0.335% | 0.394% | derived, not cycle-active counter |
| Simulated Host Layout | 1,080 cycles; 144 B read + 576 B write | 0 | eliminated |
| Combined simulation interval | 4,273 | 2,712 | `1.576×`, −36.53% |
| Compute SPAD R/W | 6,048/1,920 B | 5,472/1,776 B | −576/−144 B |
| Total SPAD traffic including testbench layout | 8,688 B | 7,248 B | −16.57% |

These paired CNN measurements combine fused epilogue and consumer-ready row
layout; they do not independently measure each contribution.

## 3. TinyNPU GEMM/GEMV fixed matrix

The exact machine-readable seven-row dataset is
[`v2_round5_tinynpu_matrix_20261107.csv`](../../benchmark/v2_round5_tinynpu_matrix_20261107.csv).
NMAForge uses a 16×16, 256-MAC Matrix controller and one-cycle behavioral
four-bank SPAD; TinyNPU timing is the direct 16×16 array interval. Both use
matched deterministic INT8 operands and independent INT32 Golden checking.
TinyNPU does not include controller/SPAD latency in the measured RTL endpoint.

| Shape M×N×K | Useful MACs | NMA cycles / MAC per cycle / PE util. | NMA SPAD R/W B | Tiny direct-array cycles / MAC per cycle / util. | Golden NMA / Tiny |
|---|---:|---:|---:|---:|---|
| 16×16×16 GEMM | 4,096 | 185 / 22.141 / 8.65% | 512/1,024 | 52 / 78.769 / 30.77% | PASS / PASS |
| 16×16×32 GEMM | 8,192 | 270 / 30.341 / 11.85% | 1,024/1,024 | 100 / 81.920 / 32.00% | PASS / PASS |
| 32×32×64 GEMM | 65,536 | 1,381 / 47.455 / 18.54% | 6,144/4,096 | 790 / 82.957 / 32.41% | PASS / PASS |
| 1×13×17 GEMV | 221 | 75 / 2.947 / 1.15% | 304/52 | 100 / 2.210 / 0.86% | PASS / PASS |
| 8×16×19 GEMV | 2,432 | 154 / 15.792 / 6.17% | 560/512 | 100 / 24.320 / 9.50% | PASS / PASS |
| 16×16×19 GEMV | 4,864 | 250 / 19.456 / 7.60% | 816/1,024 | 100 / 48.640 / 19.00% | PASS / PASS |
| 16×16×65 GEMV | 16,640 | 631 / 26.371 / 10.30% | 2,368/1,024 | 244 / 68.197 / 26.64% | PASS / PASS |

For transparency, raw NMAForge/Tiny direct-array cycle ratios are 3.558×,
2.700×, 1.748× for GEMM and 0.750×, 1.540×, 2.500×, 2.586× for GEMV.
They are **not speedups** because the NMAForge side includes controller and
behavioral memory service while TinyNPU is array-only. The previous common
memory endpoint model estimates TinyNPU at 151/231/1,305 GEMM cycles and
122/164/205/441 GEMV cycles. Those rows are `ESTIMATED_NOT_RTL` (serialized
16 B/cycle service, one read-response cycle, two initial accumulator-clear
cycles). NMAForge / estimated-endpoint ratios are 1.225/1.169/1.058 and
0.615/0.939/1.220/1.431 respectively; these are also not system speedups.

On current NMAForge runs the large GEMM is memory/controller limited: the
32×32×64 command reports 140 bank-stall, 69 line-stall, 675 prefetch-wait,
209 arbiter-stall, 23 response-wait and 69 writeback-wait observations. These
categories overlap and must not be summed. GEMM array utilization is
8.65–18.54%; small-M GEMV utilization is only 1.15% at M=1. TinyNPU direct
array has higher throughput in the larger GEMM and M=8/16 GEMV rows; NMAForge
is lower-cycle only for the M=1 array/controller comparison, but that row
still has unlike timing endpoints.

## 4. Transformer Decode and the two innovations

The fixed trained cyclic H4 one-layer Transformer model SHA is
`55cef19181c84dda9f99e940a0a749c1499fc1ccb176b966b1e13462f8ae3c03`.
Baseline GEMM mapping executes 86 descriptors and passes 301/301 checks:
5,682 Prefill + 5,715 single-token Decode = 11,397 doorbell-to-CPL-tail
cycles; 640 useful MACs; 3,816/2,120 SPAD read/write bytes.

An opt-in Mapper policy changes Decode Q/K/V projection descriptors to
opcode `0x52`; default remains `0x30`. Mapper tests pass, but the real Top
integration produces **175 Decode Golden mismatches**. Completion still
arrives and the printed cycle total remains 11,397, but that counter has no
correctness standing. This is `FAIL`, the opt-in path is not for use, and no
Transformer GEMV performance gain is claimed. Cache/prefetch model ablation
is not meaningful on the failing H4 mapping; at M=1 and K=4 there is no
multi-row B-fold reuse or next-K overlap.

**Innovation 1 — Shape-Adaptive GEMM/GEMV + B-fold reuse + prefetch:** the
historical fixed-shape Cache×Prefetch experiment shows cache-dependent
cycle/read reductions (22.3–41.6% / 35.2–56.5% versus Cache OFF and Prefetch
OFF), but it is not current-source Transformer evidence. Round 5's current
matrix uses Cache and Prefetch ON only. Model-level benefit is **not
established**; H4 `0x52` attempt fails Golden.

**Innovation 2 — Fused epilogue + elastic tile forwarding:** the current
10-class CNN shows the paired Legacy→Linear-Row result above, but fusion and
layout are not separated. Earlier fixed-SHA Digits MLP evidence is
110,155→34,761 cycles (3.169×) with exact Golden and unchanged 352/360
classification; a separate directed Tile Forwarding test saved 23 cycles
(about 8%) and halved source-A bank reads. The directed forwarding result is
not a full Top CMDQ producer/consumer test. These separate effects must not
be multiplied or presented as one combined speedup.

## 5. 400 MHz synthesis and 128 KiB SRAM cost

The environment includes TSMC28 HPC+ standard-cell and SRAM libraries and
Design Compiler `V-2023.12-SP1`; the SSG 0.72 V / 125°C standard-cell library
loaded and DC reached Matrix Core elaboration. The exploratory Matrix Core
constraint used 2.500 ns, 100 ps clock uncertainty, 50 ps input transition,
250 ps input/output delays, and 20 fF output load, with no false paths.
These generic port delays are not a product signoff SDC.

Two bounded mapping attempts produced no accepted mapped design. The first
valid-library `compile_ultra` run was terminated before finishing mapping. The
follow-up standard compile failed on unsupported `-no_autoungroup` before
mapping; the script was corrected after the run and not rerun. The resulting
precompile report has zero cell area because it is unmapped and is not valid
PPA. Therefore Matrix Core and Cluster at 300/400/450 MHz, WNS/TNS, critical
path, mapped cell area, power and energy are **NOT_RUN**. The environment is
available; status is **PARTIAL**, not `BLOCKED_ENV`.

The SRAM catalog includes a 4096×32 single-port 16 KiB macro at LEF area
35,239.86555 µm². Capacity-only organization:

| Logical SPAD | Organization | Macro count | LEF macro area sum |
|---|---|---:|---:|
| 128 KiB, 4 banks | 2 × 4096×32 per bank | 8 | 281,918.9244 µm² |
| 512 KiB, 4 banks | 8 × 4096×32 per bank | 32 | 1,127,675.6976 µm² |

These sums exclude wrapper/control, redundancy, routing, utilization, and
periphery. The available macro is single-port while RTL exposes independent
Host and scheduler ports; there is no verified SRAM adapter. The macro's
available Liberty voltage condition also differs from the selected 0.72 V
standard-cell view. These are storage and geometry estimates only, not a
timing-compatible integration or physical PPA.

## 6. Reproduction and evidence records

Primary machine-readable artifacts:

- [`v2_round5_tinynpu_matrix_20261107.csv`](../../benchmark/v2_round5_tinynpu_matrix_20261107.csv)
- [`v2_round5_model_summary_20261107.csv`](../../benchmark/v2_round5_model_summary_20261107.csv)
- [`v2_round5_run_manifest_20261107.json`](../../benchmark/v2_round5_run_manifest_20261107.json)

Representative commands:

```sh
# NMAForge conv1x_mini legacy; same generated simv with
# +AI_TINYNPU_CNN_LINEARIZED for the paired row-layout run.
make -C dv/subsystem/top_smoke/sim ai_tinynpu_cnn_match \
  AI_TINYNPU_CNN_RUN=/tmp/nmaforge_round5_p0_nma_cnn \
  AI_TINYNPU_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  AI_TINYNPU_CNN_MODEL=/tmp/nmaforge_tinynpu_8216c22b/reference/source/models/conv1x_mini.onnx \
  AI_TINYNPU_CNN_GOLDEN=/tmp/nmaforge_round5_p0_tiny_cnn/graph_cnn/golden.bin

# TinyNPU conv1x_mini ONNX graph
TINY_NPU_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference/source \
TINYNPU_CNN_OUT=/tmp/nmaforge_round5_p0_tiny_cnn \
PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator JOBS=4 \
bash benchmark/tinynpu/run_tinynpu_cnn.sh

# NMAForge 3 GEMM matched cases, current-source seed 20261107
make -C dv/block/compute/matrix/sim core-random-compile \
  SEED=20261107 PHYSICAL_ARRAY_SIZE=16 OUTSTANDING_DEPTH=4 \
  A_TILE_CACHE_ENABLE=1 NEXT_K_PREFETCH_ENABLE=1 GEMV_B_TILE_CACHE_ENABLE=1 \
  CORE_OUT_DIR=/tmp/nmaforge_round5_matrix_match
/tmp/nmaforge_round5_matrix_match/simv +SEED=20261107 +TINY_NPU_MATCH_MULTI \
  -cm line+cond+fsm+branch \
  -cm_dir /tmp/nmaforge_round5_matrix_match/coverage.vdb \
  -cm_name round5_gemm_20261107 \
  -l /tmp/nmaforge_round5_matrix_match/gemm_run.log

# NMAForge required GEMV set (the product task also exercises two extra shapes)
/tmp/nmaforge_round5_matrix_match/simv +SEED=20261107 +MATRIX_PRODUCT_GEMV_ONLY \
  -cm line+cond+fsm+branch \
  -cm_dir /tmp/nmaforge_round5_matrix_match/coverage.vdb \
  -cm_name round5_gemv_20261107 \
  -l /tmp/nmaforge_round5_matrix_match/gemv_run.log

# TinyNPU Direct Array 3 GEMM + 4 GEMV cases at the pinned checkout
TINY_NPU_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference/source \
TINYNPU_WORK_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference \
TINYNPU_GEMM_OUT=/tmp/nmaforge_round5_tiny_matrix \
VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator JOBS=4 \
bash benchmark/tinynpu/run_tinynpu_gemm.sh

# Optional Mapper unit checks
cd sw/tools && /tmp/nmaforge_arch_v2_py312/bin/python -m unittest -v test_cimforge_mapper.py
```

Key log SHA-256: NMA mini Legacy
`7c430a551a407fb1d3f1408a75441cc2e787318a7110aeab6c71c12538643983`;
NMA mini Linear-Row
`df8713074b6048105d1bb4d4b76ae6f0d9b5bfcb90c559f9b2448ddaa327a6a5`;
Tiny mini CNN
`88075ee52ada63fb6d44016eb3d5c83e1d2504933d19b206154dd0c84b0dcbaf`;
NMA GEMM `079a632b6fb78df2beb7fce11a7d96ff14c7ae5b33b554eb0ea1e596bb7b224c`;
NMA GEMV `3ae7ada21357a4b354fb512083be2b49a79898b55bb768b26bb9dc9ea67ef267`;
Tiny matrix `e921bef8e90748964ee0b7a566f70607515f5ee650cc00d18bbafbe9a0371bbe`;
Transformer GEMM `1fb2147112f11966cef186301357fb283908637b6081aebdb8342100d3fa1bab`;
Transformer `0x52` failure
`638861b1010c60f4ac9a2c8b332555650d97dcd170fbf22c4c6e93f52cb88707`.
Raw logs remain under the listed `/tmp/nmaforge_round5_*` paths and are not
committed as generated simulator output.

## 7. Final status

| Work item | Status | Evidence / limit |
|---|---|---|
| Current mini-CNN functional and within-NMA layout comparison | PASS | Both modes bit-exact; valid same-boundary NMA speedups above |
| TinyNPU mini-CNN correctness | PASS | 4/4 bytes; graph cycles are not a matched system endpoint |
| Current 3 GEMM + 4 GEMV matrix | PASS | All Golden on each side; timing endpoints differ |
| Baseline H4 Transformer | PASS | 301/301 checks, GEMM Decode |
| H4 Mapper `0x52` Decode | FAIL | 175 Top Golden mismatches; no model speedup |
| Current-source Cache/Prefetch model ablation | NOT_RUN | Only historical fixed-shape ablation exists |
| Innovation 2 mechanism-isolated CNN ablation | PARTIAL | Current CNN pairs fusion+layout; separate earlier tile test is not Top-level |
| Matrix/Cluster 300/400/450 MHz synthesis | NOT_RUN | No accepted mapped netlist or timing report |
| SRAM macro integration | NOT_RUN | Single-port macro has no validated adapter for dual-port RTL |

The project remains a useful, reproducible **partial research baseline**. It
demonstrates a same-system CNN layout optimization and provides a transparent
TinyNPU Direct Array comparison, while exposing poor NMAForge utilization on
small-M/large-Matrix cases and an incorrect current experimental Transformer
GEMV mapping. It does not prove a TinyNPU system-level performance victory,
Transformer GEMV benefit, or 400 MHz feasibility. No further phase is
automatically started after this Round 5 publication.
