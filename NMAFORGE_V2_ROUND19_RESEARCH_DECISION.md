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

