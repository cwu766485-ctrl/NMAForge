#!/usr/bin/env bash
set -euo pipefail
run=${PHASE1_MATCHED_OUT:?Set fresh output}
python=${PHASE1_PYTHON:-python3.12}
tiny=${TINY_NPU_ROOT:?Set clean pinned TinyNPU source}
test "$(git -C "$tiny" rev-parse HEAD)" = 8216c22b762011aa20c05fc2768423fd12dda59d
test -z "$(git -C "$tiny" status --porcelain)"
"$python" tools/benchmark/phase1/prepare_matched.py --out "$run" --model "${PHASE1_MODEL:?Set admitted H32 model}"
vcs -full64 -sverilog -timescale=1ns/1ps -Mdir="$run/csrc" -top tb_stage_c_matched_service \
 rtl/compute/matrix/ai_tensor_matrix_array.sv "$run/tb_service.sv" \
 -o "$run/simv" -l "$run/compile.log" > "$run/compile.stdout" 2>&1
TINYNPU_GEMM_OUT="$run/tiny" bash "$run/build_tiny.sh" > "$run/tiny-driver.log" 2>&1
"$python" tools/benchmark/stage_c/bench.py --run "$run"
# Normalize the legacy writer's CRLF CSV for public text evidence.
"$python" -c 'import pathlib,sys;p=pathlib.Path(sys.argv[1]);p.write_bytes(p.read_bytes().replace(b"\r\n",b"\n"))' "$run/matched.csv"
