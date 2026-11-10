#!/usr/bin/env bash
set -euo pipefail
root=$(pwd)
run=${STAGE_A_OUT:?Set a fresh absolute output directory}
python=${STAGE_A_PYTHON:-python3.12}
mkdir -p "$run"
(
 cd dv/subsystem/top_smoke/sim
 vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
  +define+VCS +define+AI_REPRESENTATIVE_LONG_TASK +define+AI_SPAD_WORDS_PER_BANK=8192 \
  +incdir+../../../block/control/agent +incdir+../../../block/dma/agent +incdir+../fixtures \
  -Mdir="$run/csrc" -top tb_ai_accel_smoke -f ai_accel.f \
  ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
  -o "$run/simv" -l "$run/compile.log"
)
# Wrapper injects an observation-only plusarg into the unchanged persistent driver.
printf '#!/usr/bin/env bash\nexec %q +STAGE_A_PROFILE=%q "$@"\n' "$run/simv" "$run/h16" > "$run/profile_simv"
chmod +x "$run/profile_simv"
"$python" "$root/sw/tools/run_tiny_gpt2_persistent_session.py" \
 --model "$root/benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json" \
 --simv "$run/profile_simv" --out "$run/session" --seed 20261123 --steps 8
