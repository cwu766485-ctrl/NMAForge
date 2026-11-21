#!/usr/bin/env bash
# Gate 0/1 only. Invoke from repository root; outputs stay outside Git.
set -euo pipefail
run=${SPAD128_OUT:?Set a fresh absolute output directory}
python=${SPAD128_PYTHON:-python3.12}
[[ "$run" = /* && ! -e "$run" ]]
mkdir -p "$run"
git rev-parse HEAD > "$run/source_commit.txt"
git diff --binary HEAD > "$run/source.diff"
"$python" tools/benchmark/spad128/check_allocator.py > "$run/allocator.log" 2>&1
"$python" tools/benchmark/spad128/run_geometry.py --out "$run/geometry" > "$run/geometry-driver.log" 2>&1
# Use canonical mapper, ordered source list and top testbench; isolate VCS products.
"$python" sw/tools/cimforge_mapper.py --svh "$run/ai_transformer_workload.svh" \
 --manifest "$run/transformer_manifest.json" --spad-bytes 131072 > "$run/mapper.log" 2>&1
for depth in 8192 32768; do
 d="$run/top_$depth"
 mkdir -p "$d"
 (
  cd dv/subsystem/top_smoke/sim
  vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps +define+VCS \
   +define+AI_SPAD_WORDS_PER_BANK="$depth" \
   +incdir+../../../block/control/agent +incdir+../../../block/dma/agent \
   +incdir+"$run" +incdir+../fixtures -Mdir="$d/csrc" \
   -top tb_ai_accel_smoke -f ai_accel.f ../../../block/dma/env/axi_memory_model.sv \
   ../tb/tb_ai_accel_smoke.sv -o "$d/simv" -l "$d/compile.log" > "$d/compile.stdout" 2>&1
 )
 "$d/simv" +AI_RANDOM_CASES=20 +AI_SEED=12345 +ntb_random_seed=12345 \
  -l "$d/smoke.log" > "$d/smoke.stdout" 2>&1
 grep -q '^TEST PASS$' "$d/smoke.log"
 ! grep -q 'TEST FAIL' "$d/smoke.log"
 "$d/simv" +AI_SPAD_CAPACITY_BOUNDARIES +AI_SEED=12345 +AI_RANDOM_CASES=0 \
  -l "$d/boundary.log" > "$d/boundary.stdout" 2>&1
 grep -q '^SPAD_CAPACITY_BOUNDARY_PASS ' "$d/boundary.log"
done
simv="$run/top_8192/simv"
"$simv" +AI_DMA_ERROR_STRESS +AI_RANDOM_CASES=0 +AI_SEED=12345 \
 -l "$run/dma_stress.log" > "$run/dma_stress.stdout" 2>&1
grep -q '^TEST PASS$' "$run/dma_stress.log"
STAGE_B_CONTRACT_OUT="$run/fault" bash tools/benchmark/stage_b/run_contract.sh > "$run/fault-driver.log" 2>&1
make -C dv/block/spad_protection/sim run RUN_ROOT="$run/protection" > "$run/protection-driver.log" 2>&1
mkdir -p "$run/arbiter"
vcs -full64 -sverilog -timescale=1ns/1ps -Mdir="$run/arbiter/csrc" \
 -top tb_ai_spad_arbiter_rr rtl/memory/ai_spad_arbiter.v \
 dv/block/spad_arbiter/tb/tb_ai_spad_arbiter_rr.sv -o "$run/arbiter/simv" \
 -l "$run/arbiter/compile.log" > "$run/arbiter/compile.stdout" 2>&1
"$run/arbiter/simv" -l "$run/arbiter/run.log" > "$run/arbiter/stdout.log" 2>&1
grep -q 'SPAD arbiter protection-error response alignment PASS' "$run/arbiter/run.log"
"$python" benchmark/digits/generate_digits_workload.py --out-dir "$run/digits/workload" \
 --spad-bytes 131072 > "$run/digits-map.log" 2>&1
mkdir -p "$run/digits"
"$simv" +AI_DIGITS_INFERENCE +AI_RANDOM_CASES=0 +AI_SEED=12345 \
 +AI_DIGITS_LAYOUT="$run/digits/workload/digits_layout.memh" \
 +AI_DIGITS_MEMORY="$run/digits/workload/digits_spad_writes.memh" \
 +AI_DIGITS_EXPECTED="$run/digits/workload/digits_expected.memh" \
 +AI_DIGITS_HIDDEN="$run/digits/workload/digits_hidden_expected.memh" \
 +AI_DIGITS_RTL_CSV="$run/digits/rtl_logits.csv" \
 -l "$run/digits/run.log" > "$run/digits/stdout.log" 2>&1
"$python" benchmark/digits/digits_quantized_golden.py \
 --model benchmark/digits/artifacts/digits_mlp_int8.npz \
 --rtl-logits "$run/digits/rtl_logits.csv" --out "$run/digits/golden.json" > "$run/digits/golden.log" 2>&1
# Reuse the existing bounded representative-task assertion profile for large graphs.
STAGE_C_OUT="$run/h32" STAGE_C_PYTHON="$python" bash tools/benchmark/stage_c/run_top.sh > "$run/h32-driver.log" 2>&1
"$python" tools/benchmark/stage_c/analyze.py --run "$run/h32/h32" \
 --out "$run/h32/analysis" > "$run/h32/analysis.log" 2>&1
simv="$run/h32/simv"
"$python" tools/benchmark/stage_a/run_cnn.py --simv "$simv" --out "$run/cnn" > "$run/cnn-driver.log" 2>&1
for mode in legacy first_fused both_fused_row_major; do
 "$python" benchmark/representative/verify_trained_3x3_cnn_workload.py \
  --workload-dir "$run/cnn/$mode" > "$run/cnn/$mode/independent_golden.log" 2>&1
done
"$python" sw/tools/run_tiny_gpt2_persistent_session.py \
 --model benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json \
 --simv "$simv" --out "$run/h16" --seed 20261123 --steps 8 \
 --spad-bytes 131072 > "$run/h16-driver.log" 2>&1
# Optional full held-out MiniCNN data set using the checked-in trained weights.
if [[ ${SPAD128_DATASET:-0} = 1 ]]; then
 "$python" benchmark/tinynpu/run_nma_cnn_demo_dataset.py --simv "$simv" \
  --model benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_weights.npz \
  --testset benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_testset.npz \
  --candidate-sha "$(git rev-parse HEAD)" --spad-bytes 131072 \
  --out-dir "$run/mini10dataset" > "$run/mini10dataset-driver.log" 2>&1
fi
echo SPAD128_GATE01_REGRESSION_PASS
