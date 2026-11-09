# NMAForge v2 Round 19 — Research Decision

- **Repository:** `cwu766485-ctrl/NMAForge`
- **Target GitHub branch:** `feature/npu-architecture-v2`
- **Source SHA tested:** `7e38a224bfa9558b8b9145c0a9dd81e2786f202a`
- **TinyNPU reference SHA:** `8216c22b762011aa20c05fc2768423fd12dda59d`
- **Run IDs:** `R19-TINY-MATCHED-20261109`, `R19-GEMV-MATCH-20261109`, `R19-CNN-{LEGACY,FIRST-FUSED,BOTH-FUSED-ROW}-20261109`

**RTL changes in this round:** none. The tested product RTL is exactly Source SHA `7e38a224`; changes are benchmark scripts, trained model artifact, results, and this report.

Work was performed in an isolated `codex/round19` worktree at the target branch HEAD so the user's original checkout and other worktrees remained untouched. The remote target branch was verified at the reviewed Source SHA before committing.

## Decision

Round 19 completed its bounded toolchain recovery, paired GEMM/GEMV benchmark, and a trained INT8 CNN experiment through the production Top CMDQ. The CNN is a useful research result, with exact Top Tensor checks for all three dataflow modes. It also exposed the present measurement bottleneck: testbench AXI preload is about 141k cycles, much larger than the 13k–66k command window. The current TinyNPU comparison remains mixed-boundary evidence, not a full-system win. No 400 MHz synthesis or ASIC PPA was run; this architecture should be treated as an RTL research candidate, not as ASIC-signoff-ready.

## P0 — Local toolchain recovery

Reused the existing native Rocky Linux 8.10 installation; no shared/system tool was overwritten and no new package was installed.

| Environment | Result |
|---|---|
| Rocky Verilator | `/tmp/nmaforge_verilator_5.052/bin/verilator`, version `5.052 2026-09-05 rev v5.052` |
| C++ | `/usr/bin/g++`, GCC 8.5.0 |
| Python environment | `/tmp/nmaforge_arch_v2_py312/bin/python`, Python 3.12.13, NumPy 2.4.6, ONNX 1.17.0, scikit-learn 1.9.1 |
| VCS | `/usr/local/bin/vcs`, V-2023.12-SP1_Full64; compile and simulation both completed, so the current license was usable for this run |
| Windows WSL inventory | PowerShell `wsl --list --verbose` showed Rocky 8.10 and Ubuntu 24.04 as separate WSL2 distributions |
| Verified VHD locations | Rocky `F:\WSL\Rocky-8.10`; Ubuntu `E:\WSL\Ubuntu` (read from Windows distro registration; not inferred from a drive assumption) |
| Ubuntu tools | Verilator 5.020, GCC 13.3.0, Python 3.12.3 and NumPy 1.26.4; ONNX was absent. Ubuntu was not changed. |

The requested benchmark and Top flow ran in Rocky because that environment already has the compatible VCS setup. Verilator 5.052 is also the executable used to rebuild the pinned TinyNPU reference. No license-server endpoint or private license configuration is recorded here.

## P1 — TinyNPU benchmark rebuild

The TinyNPU source was checked out in a temporary work directory at the pinned SHA and rebuilt using `benchmark/tinynpu/run_comparison.sh`; the four GEMV cases were run through `benchmark/tinynpu/run_gemv_match.sh`. Both paired runs passed their independent signed INT8/INT32 Golden checks. The TinyNPU engine regression was 6/6 PASS and its 15-case Matrix size sweep passed using behavioral SPAD timing.

Reproduction (Rocky):

```bash
TINYNPU_BENCH_OUT=/tmp/nmaforge_round19_tinynpu_20261109 \
TINYNPU_WORK_ROOT=/tmp/nmaforge_round19_tiny_reference \
TINY_NPU_ROOT=/tmp/nmaforge_round19_tiny_reference/source \
VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
BENCH_RUN_ID=R19-TINY-MATCHED-20261109 SEED=20261118 JOBS=4 \
bash benchmark/tinynpu/run_comparison.sh

TINYNPU_BENCH_OUT=/tmp/nmaforge_round19_tinynpu_20261109 \
TINYNPU_WORK_ROOT=/tmp/nmaforge_round19_tiny_reference \
TINY_NPU_ROOT=/tmp/nmaforge_round19_tiny_reference/source \
VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
VCS_VERSION=V-2023.12-SP1_Full64 \
BENCH_RUN_ID=R19-GEMV-MATCH-20261109 SEED=20261118 \
bash benchmark/tinynpu/run_gemv_match.sh
```

### GEMM paired matrix

All numbers below are cycles. NMAForge is Matrix controller + behavioral SPAD RTL. TinyNPU array cycles are direct RTL; its normalized endpoint adds serialized modeled reads/writes at 16 bytes/cycle, one-cycle read response, and accumulator clear. Thus `NMA / Tiny normalized` is only a diagnostic ratio; values above 1 mean NMAForge took more cycles under this mixed measured/modeled endpoint.

| Shape | NMAForge measured | TinyNPU array RTL | TinyNPU + memory model | NMA/Tiny modeled ratio | Golden |
|---|---:|---:|---:|---:|---|
| 16×16×16 | 185 | 52 | 151 | 1.2252 | PASS/PASS |
| 16×16×32 | 254 | 100 | 231 | 1.0996 | PASS/PASS |
| 32×32×64 | 1,384 | 790 | 1,305 | 1.0605 | PASS/PASS |

### GEMV paired matrix

TinyNPU has no corresponding product GEMV descriptor/SPAD interface in this harness. M=1/8 operands are padded into its direct 16×16 array; Tiny memory service is modeled separately. These results are not end-to-end speedups.

| Shape | NMAForge `0x52` RTL | TinyNPU direct array | Tiny modeled endpoint | NMA/Tiny modeled ratio | Golden |
|---|---:|---:|---:|---:|---|
| 1×13×17 | 70 | 100 | 126 | 0.5556 | PASS/PASS |
| 8×16×19 | 148 | 100 | 170 | 0.8706 | PASS/PASS |
| 16×16×19 | 253 | 100 | 218 | 1.1606 | PASS/PASS |
| 16×16×65 | 641 | 244 | 459 | 1.3965 | PASS/PASS |

The shorter M=1 and 8×16 cases are promising under the explicitly modeled endpoint; the larger M/K cases are slower. Tiny direct array cycles exclude the product-level GEMV controller, and modeled memory is not TinyNPU RTL. No system-level winner is claimed.

### Common Mini CNN

Both designs passed exact output checks for `conv1x_mini.onnx`, with the same ONNX SHA `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`, input seed 99, and INT8 input SHA `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`.

| Design | Reported cycles | Scope |
|---|---:|---|
| NMAForge | 1,985 compute + 1,080 host layout = 3,065 reported phase cycles | CMDQ windows exclude preload, descriptor programming, and final host read |
| TinyNPU | 4,781 graph cycles | ONNX graph dispatcher and testbench DMA/SRAM shim; testbench input setup excluded |

The model and final bytes match, but the cycle windows do not. No CNN speedup is computed. There is not yet a shared native controller/memory endpoint.

Machine-readable paired results: `benchmark/tinynpu/benchmark_summary.json`, `gemm_results.csv`, `gemv_summary.json`, `gemv_results.csv`, `cnn_summary.json`, and `cnn_results.csv`. Tool versions are recorded in the JSON metadata.

## P2 — Trained 3×3 CNN on production Top

### Model and quality

The deterministic training flow uses scikit-learn Digits, a stratified 80/20 split (1,437 train / 360 held out), seed `20261119`, and 250 epochs of NumPy analytic-backprop/Adam training. The 8×8 grayscale image is nearest-neighbor upsampled to 16×16 and accompanied by constant, x-coordinate, and y-coordinate planes. The network has a valid 3×3 INT8 convolution (4→63 trained channels, exported as 64 with one constant feature channel for bias) followed by a 1×1 INT8 projection (64→10, padded to 16 output lanes). Layer outputs use signed INT32 accumulation, per-layer symmetric INT8 weights, shifts 9 and 7, and signed saturation; the first layer applies ReLU. Host performs image preparation, 3×3 Im2col, weight/operand packing, and final spatial global average + argmax. There is no host computation of an intermediate convolution output; both matrix products execute in production Top RTL.

| Item | Value |
|---|---|
| Software INT8 held-out accuracy | 96.111% over all 360 held-out samples |
| Float held-out accuracy | 95.556% |
| Useful MACs/inference | 570,164 (logical channels; includes 3×3 and 1×1 layers) |
| Dataset SHA-256 | `f6d9e39f37dc45d327f6db33428ee58970ccceabb2535a5c179de35886b70443` |
| Deployed INT8 weight SHA-256 | `0d772a4d569814b67aefe7dabe596f43cf275b3aa26df4a529f3a3e83bbd3e6c` |
| Model artifact SHA-256 | `763a86d8a4ad508bd3ec34106163891f26870a98868889b0bc6c8bfe285370f8` |
| Training script SHA-256 | `51a5bd1bc3d3b0fee733bb93331addc8620fcdaf25a073e21d304ad97264cd16` |
| SPAD configuration | 128 KiB total, four banks; highest allocated byte `0x1a240` |

The Top run executes held-out sample index 42 (true class 1). The model predicts class 5 for this sample, so **that sample is misclassified**. It is not hidden by the aggregate held-out accuracy. Top verification establishes Tensor/GEMM/requant/layout correctness for this sample; it does not establish Top RTL accuracy over all 360 samples.

### Dataflow ablation and Top evidence

| Mode | Descriptors | CMDQ cycles | Host AXI preload cycles | Preload + CMDQ | Useful MAC/CMDQ cycle | Array-utilization counter | SPAD read/write bytes | SFU busy cycles | Top Golden |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Legacy: `0x30,0x36,0x30,0x36` | 4 | 66,023 | 141,503 | 207,526 | 8.6358 | 82.37% | 130,624 / 83,200 | 54,084 | 20,800/20,800 words PASS |
| First layer fused: `0x53,0x30,0x36` | 3 | 23,577 | 141,383 | 164,960 | 24.1831 | 82.37% | 77,376 / 29,952 | 10,817 | 20,800/20,800 words PASS |
| Both fused, Row-Major output: `0x53,0x53` | 2 | 12,947 | 141,263 | 154,210 | 44.0383 | 82.37% | 64,064 / 16,640 | 0 | 20,800/20,800 words PASS |

Against Legacy, first-layer fusion reduced CMDQ cycles by 64.3% and preload+CMDQ cycles by 20.5%. Both-layer Fused Row-Major reduced CMDQ cycles by 80.4% and preload+CMDQ by 25.7%. The last mode is output compatible and passed the same Row-Major packed INT8 Golden; it is therefore a valid complete-output result for this descriptor chain, unlike a native Matrix-A-only output.

The Top counter reports the same 2,704 Matrix MAC-active cycles and 82.37% array utilization in all modes. `Useful MAC/CMDQ cycle` rises because fused epilogue removes long separate SFU requant windows; it does not mean the array’s per-active-cycle utilization changed. The SFU busy counter drops from 54,084 to 0, while the CMDQ reduction is smaller because Matrix writeback, command dispatch, and other work remain.

### Transfer and timing limits

- The input and weights occupy 10,816 useful bytes: valid Im2col is 7,056 bytes, padded Im2col is 7,488 bytes, and weights are 3,328 bytes. There are 12 padded rows.
- The Top reports 94,336 / 94,256 / 94,176 preloaded bytes. This AXI testbench preload also initializes poison/sentinel areas and control data; those counts are **not** useful model payload. This flow performs per-word AXI SPAD initialization, not DMA, so it is not a DMA-bandwidth result.
- Preload+CMDQ cycles are simulated Top cycles from preload through command completion. Software Im2col/preparation was separately measured at 0.300 / 0.345 / 0.522 ms for these three generated runs; host training, software Golden, output readback, global average, and argmax are not part of those cycle totals. Golden readback was not separately timed.
- Consequently these measurements support a command/dataflow ablation, not a complete wall-clock model latency. Preload dominates and masks much of the CMDQ gain; the next data-movement question is transaction-efficient loading and/or legal overlap, supported by transaction profiling rather than by assuming it is free.

### Reproduction commands

Training and independent workload verification:

```bash
/tmp/nmaforge_arch_v2_py312/bin/python benchmark/representative/train_digits_3x3_cnn.py \
  --seed 20261119 --epochs 250 \
  --out benchmark/representative/models/r19_trained_digits_3x3_cnn.json

for mode in legacy first_fused both_fused_row_major; do
  /tmp/nmaforge_arch_v2_py312/bin/python benchmark/representative/generate_trained_3x3_cnn_workload.py \
    --model benchmark/representative/models/r19_trained_digits_3x3_cnn.json \
    --out-dir "/tmp/r19_cnn_${mode}" --fusion-mode "$mode" --test-rank 0
  /tmp/nmaforge_arch_v2_py312/bin/python benchmark/representative/verify_trained_3x3_cnn_workload.py \
    --workload-dir "/tmp/r19_cnn_${mode}"
done
```

Top compile (run from `dv/subsystem/top_smoke/sim`):

```bash
vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps \
  +define+VCS +define+AI_REPRESENTATIVE_LONG_TASK \
  +define+AI_SPAD_WORDS_PER_BANK=8192 \
  +incdir+../../../block/control/agent +incdir+../../../block/dma/agent \
  +incdir+../fixtures -Mdir=/tmp/r19_cnn_top/csrc \
  -top tb_ai_accel_smoke -f ai_accel.f \
  ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
  -o /tmp/r19_cnn_top/simv -l /tmp/r19_cnn_top/compile.log
```

For each mode, run the compiled `simv` with `+AI_REPRESENTATIVE_MODEL`, the corresponding `/tmp/r19_cnn_<mode>/model_memory.memh` and `model_golden.memh`, descriptor base 102400, completion base 102912, descriptor count 4/3/2, `+AI_REPRESENTATIVE_USEFUL_MACS=570164`, and `+ntb_random_seed=20261119 +AI_RANDOM_CASES=0 +AI_SEED=20261119 +ACLK_PERIOD_NS=4.000`. Full commands and parsed results are recorded in `benchmark/representative/round19/cnn_results.json`; source testbench is `dv/subsystem/top_smoke/sim/tb/tb_ai_accel_smoke.sv`.

## P3 — Freeze assessment and remaining work

| Topic | Round 19 status |
|---|---|
| Rocky Verilator/VCS toolchain | PASS; existing local tools reused, Top VCS compile/sim completed |
| TinyNPU paired GEMM/GEMV Golden | PASS; timings remain array-vs-controller/model mixed endpoints |
| Common `conv1x_mini.onnx` | Both Golden PASS; no fair system speedup due different timing windows and memory/graph paths |
| Trained ≥100K-MAC CNN | Software training/evaluation PASS; Top Tensor Golden PASS in 3 modes for one held-out sample; that sample classification FAIL |
| Trained CNN full held-out Top accuracy | NOT_RUN (only one sample went through Top) |
| Trained multi-layer Transformer / language-model quality | NOT_RUN; earlier H16 work is not a trained language-model benchmark |
| DMA/Compute overlap and input transaction optimization | NOT_RUN; this CNN test uses per-word Top AXI preload |
| ASIC 400 MHz / PPA | NOT_RUN by scope |
| Architecture freeze for ASIC signoff | NOT READY; RTL candidate can be frozen for a separately scoped synthesis evaluation, but no PPA/signoff evidence is produced here |

The two existing research directions have evidence with limits: shape-adaptive GEMV has positive results for two small shapes and negative results for two larger shapes under a modeled Tiny memory endpoint; fused epilogue and compatible Row-Major writeback reduce Top CMDQ cycles materially on the trained CNN sample. Neither result proves a full-system TinyNPU advantage or ASIC frequency/area/power benefit. No product RTL change was justified or made in this round.

## Files and evidence

- Machine-readable CNN results: `benchmark/representative/round19/cnn_results.csv` and `cnn_results.json`.
- Trained model and reproducible training source: `benchmark/representative/models/r19_trained_digits_3x3_cnn.json`, `train_digits_3x3_cnn.py`.
- Top workload generator and independent physical-layout verifier: `generate_trained_3x3_cnn_workload.py`, `verify_trained_3x3_cnn_workload.py`.
- Paired TinyNPU data: `benchmark/tinynpu/benchmark_summary.json`, `gemm_results.csv`, `gemv_summary.json`, `gemv_results.csv`, `cnn_summary.json`, `cnn_results.csv`.
- Top VCS raw logs remain in `/tmp/r19_cnn_top/` on the tested machine and are SHA-256 recorded in `cnn_results.json`; no VCS build directory or private tool/library/license material is committed.

This report is a research benchmark closeout only. It is not Compute Cluster DV sign-off, an ASIC PPA report, or a Tapeout readiness claim.
