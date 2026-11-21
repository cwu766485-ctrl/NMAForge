# Reproduction

Run from the candidate root. Use fresh absolute output directories; commands
below use the session prefix `/tmp/nmaforge-opt`. VCS wrapper resolves to
V-2023.12-SP1_Full64, Verilator 5.052, Python 3.12.13. No private technology or
license artifacts are needed in the repository. EDA skill:
`.agents/skills/eda-tool-engineering/SKILL.md`; canonical Makefile entry points
were used because the generic eda.yaml simulation adapter is incomplete.

## Baseline and ablation

Baseline SHA is 9095832f049629dbfb3ee8a6f10839cdb50f4aa4. Use a separate checkout
for the baseline, preserving other worktrees. On baseline and final respectively:

```sh
R28_OUT=/tmp/nmaforge-opt-base R28_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python bash tools/benchmark/run_round28_h16.sh
R28_OUT=/tmp/nmaforge-opt-accepted R28_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python bash tools/benchmark/run_round28_h16.sh
```

To reproduce Matrix-only on the final checkout, substitute **only** the baseline
SFU source into a temporary filelist; no worktree or checked-in file is changed:

```sh
git show 9095832:rtl/compute/sfu/ai_tensor_sfu_core.v > /tmp/nmaforge-opt-sfu-base-core.v
python3 - <<'PY'
from pathlib import Path
s = Path('dv/subsystem/top_smoke/sim/ai_accel.f').read_text()
s = s.replace('../../../../rtl/compute/sfu/ai_tensor_sfu_core.v', '/tmp/nmaforge-opt-sfu-base-core.v')
Path('/tmp/nmaforge-opt-matrix-ablation.f').write_text(s)
s = Path('tools/benchmark/run_round28_h16.sh').read_text().replace('-f ai_accel.f', '-f /tmp/nmaforge-opt-matrix-ablation.f')
Path('/tmp/nmaforge-opt-matrix-ablation.sh').write_text(s)
PY
R28_OUT=/tmp/nmaforge-opt-matrix-ablation R28_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python bash /tmp/nmaforge-opt-matrix-ablation.sh
```

## Focused regressions and traces

```sh
make -C dv/block/compute/sfu/sim random-latency-regress PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python SEEDS='20261109 20261110 20261111' OUT_DIR=/tmp/nmaforge-opt-sfu
make -C dv/block/compute/matrix/sim core-random-regress CORE_OUT_DIR=/tmp/nmaforge-opt-matrix-accepted SEEDS='20261109 20261110 20261111'
make -C dv/block/compute/matrix/sim core-random-run CORE_OUT_DIR=/tmp/nmaforge-opt-depth2 OUTSTANDING_DEPTH=2 SEED=20261109
make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge-opt-no-prefetch SEEDS='20261109'
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
/tmp/nmaforge-opt-matrix-accepted/simv +SEED=20261109 +TINY_NPU_MATCH_MULTI +MATRIX_SCHEDULE_TRACE=/tmp/nmaforge-opt-matrix-accepted/trace.csv -l /tmp/nmaforge-opt-matrix-accepted/shapes.log
/tmp/nmaforge-opt-matrix-accepted/simv +SEED=20261109 +TINY_NPU_MATCH_MULTI +MATRIX_FIXED_MEMORY -l /tmp/nmaforge-opt-accepted-fixed.log
/tmp/nmaforge-opt-matrix-accepted/simv +SEED=20261109 +MATRIX_PRODUCT_GEMV_ONLY +MATRIX_FIXED_MEMORY -l /tmp/nmaforge-opt-accepted-fixed-gemv.log
/tmp/nmaforge-opt-matrix-accepted/simv +SEED=20261109 +MATRIX_GEMV_ABLATION_M4_SHAPE +MATRIX_FIXED_MEMORY -l /tmp/nmaforge-opt-isolated-gemv-final.log
```

For identical baseline profiling instrumentation and fixed-memory switch, use
the final testbench with the baseline Matrix core exported to a temporary file:

```sh
git show 9095832:rtl/compute/matrix/ai_tensor_matrix_core.v > /tmp/nmaforge-opt-matrix-base-core.v
vcs -full64 -sverilog -timescale=1ns/1ps -Mdir=/tmp/nmaforge-opt-fixed-base-csrc -top tb_ai_tensor_matrix_core_random rtl/compute/matrix/ai_tensor_matrix_datapath.v rtl/compute/matrix/ai_tensor_matrix_array.sv /tmp/nmaforge-opt-matrix-base-core.v dv/block/compute/matrix/tb/tb_ai_tensor_matrix_core_random.sv -o /tmp/nmaforge-opt-fixed-base-simv -l /tmp/nmaforge-opt-fixed-base-compile.log
/tmp/nmaforge-opt-fixed-base-simv +SEED=20261109 +TINY_NPU_MATCH_MULTI +MATRIX_FIXED_MEMORY -l /tmp/nmaforge-opt-fixed-base.log
/tmp/nmaforge-opt-fixed-base-simv +SEED=20261109 +TINY_NPU_MATCH_MULTI +MATRIX_SCHEDULE_TRACE=/tmp/nmaforge-opt-matrix-trace-base/trace.csv -l /tmp/nmaforge-opt-matrix-trace-base/shapes.log
```

Create the trace directory first. Omit `MATRIX_FIXED_MEMORY` to reproduce seeded
random-ready/countdown behavior. For baseline GEMV fixed/collision and isolated
results use the same respective plusargs as final, changing only executable/log
paths. Traces sample pre-NBA actual request acceptance, response metadata,
occupancy and controller state. The archive checker validates queue ownership
and exact exclusive phase sums; it does not infer physical bank conflicts.

## TinyNPU and common trained projections

```sh
TINYNPU_WORK_ROOT=/tmp/nmaforge-round28-runs/tiny TINYNPU_GEMM_OUT=/tmp/nmaforge-opt-tiny VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator JOBS=2 bash benchmark/tinynpu/run_tinynpu_gemm.sh
/tmp/nmaforge_arch_v2_py312/bin/python tools/benchmark/generate_shared_h16_qkv.py --model benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json --out /tmp/nmaforge-opt-qkv
```

For each `q`, `k`, `v`, run the Matrix simv with
`+SEED=20261109 +TRAINED_QKV_MATCH +SHARED_OPERANDS=/tmp/nmaforge-opt-qkv/q.memh +SHARED_OUTPUT=/tmp/nmaforge-opt-qkv/nma_q.memh`,
and Tiny `obj/Vengine_tb_top` with environment
`SHARED_OPERANDS=/tmp/nmaforge-opt-qkv/q.memh SHARED_OUTPUT=/tmp/nmaforge-opt-qkv/tiny_q.memh`.
Substitute the operation in all paths, then:

```sh
/tmp/nmaforge_arch_v2_py312/bin/python tools/benchmark/check_shared_h16_qkv.py --run /tmp/nmaforge-opt-qkv
```

The pinned Tiny source is external to this repository; the runner checks SHA
8216c22b762011aa20c05fc2768423fd12dda59d. Its direct wrapper's transfer/dispatch/
clocked output commit are unmeasured. No ratio is formed against NMA CMDQ/core
cycles.

## CNN

Existing Round28 workload files are reused byte-for-byte, not regenerated to
fit the optimization. Their SHA256 values are in `workload_inputs.json`.
Recreate the original workload with the Round28 reproduction instructions when
the local paths do not exist. Run the **baseline and final** H16 simv with:

```sh
/tmp/nmaforge-opt-accepted/simv +ntb_random_seed=20261109 +AI_RANDOM_CASES=0 +AI_SEED=20261109 +ACLK_PERIOD_NS=4 +AI_REPRESENTATIVE_MODEL +AI_REPRESENTATIVE_DMA_PRELOAD +AI_REPRESENTATIVE_DMA_PAYLOAD=/tmp/nmaforge-round28-runs/cnn/dma_payload.memh +AI_REPRESENTATIVE_DMA_PLAN=/tmp/nmaforge-round28-runs/cnn/dma_plan.memh +AI_REPRESENTATIVE_MEMORY=/tmp/nmaforge-round28-runs/cnn/model_memory.memh +AI_REPRESENTATIVE_GOLDEN=/tmp/nmaforge-round28-runs/cnn/model_golden.memh +AI_REPRESENTATIVE_DESC_BASE=106496 +AI_REPRESENTATIVE_CPL_BASE=107008 +AI_REPRESENTATIVE_DESC_COUNT=2 +AI_REPRESENTATIVE_USEFUL_MACS=570164 -l /tmp/nmaforge-opt-accepted-cnn.log
make -C dv/subsystem/top_smoke/sim ai_tinynpu_cnn_match_128k AI_TINYNPU_CNN_RUN=/tmp/nmaforge-opt-common-cnn-final AI_TINYNPU_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python AI_TINYNPU_CNN_MODEL=/tmp/nmaforge-round28-runs/tiny/source/models/conv1x_mini.onnx AI_TINYNPU_CNN_GOLDEN=/tmp/nmaforge-round28-runs/tiny/cnn/graph_cnn/golden.bin
```

An initial common-CNN invocation used a nonexistent `tiny_cnn_int8.onnx` path
and failed before RTL simulation. It was corrected to the pinned `conv1x_mini`
model; only the successful corrected run is performance evidence.

## Basic synthesizability review / archive

```sh
/tmp/nmaforge_verilator_5.052/bin/verilator --lint-only --timing -Wno-fatal --top-module ai_tensor_sfu_core rtl/compute/common/ai_unsigned_divider.v rtl/compute/common/ai_integer_sqrt.v rtl/compute/sfu/ai_tensor_sfu_math.v rtl/compute/sfu/ai_tensor_sfu_core.v
/tmp/nmaforge_verilator_5.052/bin/verilator --lint-only --timing -Wno-fatal --top-module ai_tensor_matrix_core rtl/compute/matrix/ai_tensor_matrix_datapath.v rtl/compute/matrix/ai_tensor_matrix_array.sv rtl/compute/matrix/ai_tensor_matrix_core.v
/tmp/nmaforge_arch_v2_py312/bin/python tools/benchmark/analyze_schedule_optimization.py --prefix /tmp/nmaforge-opt
git diff --check
```

For baseline warning comparison, substitute exported baseline core files. Exit
zero with `-Wno-fatal` is not a clean lint claim; review the archived warnings.
The manifest records parent source SHA plus exact tested RTL hashes because
runs preceded the evidence commit. Archive includes selected public text logs,
CSV and generated test fixtures only. Compile/build products, databases, private
libraries and license/environment data are excluded.
