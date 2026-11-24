#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
evidence="$repo_root/benchmark/deit/round30/evidence/continuous_attention/full_197_passive_backdoor"
if [[ $# -gt 0 ]]; then
  run_root="$1"
else
  run_root="$(mktemp -d "${TMPDIR:-/tmp}/nmaforge-round30-final.XXXXXX")"
fi
mkdir -p "$run_root"
python_bin="${AI_DEIT_R30_CONT_PYTHON:-/tmp/nmaforge_deit_round17_venv/bin/python}"
if [[ ! -x "$python_bin" ]]; then
  python_bin="$(command -v python3.12 || true)"
fi
if [[ -z "$python_bin" || ! -x "$python_bin" ]]; then
  echo "Python 3.12 is required; set AI_DEIT_R30_CONT_PYTHON to the project environment" >&2
  exit 2
fi
python_bin="$(readlink -f "$python_bin")"
if ! "$python_bin" -c 'import numpy' >/dev/null 2>&1; then
  echo "NumPy is missing from $python_bin; set AI_DEIT_R30_CONT_PYTHON to the project environment" >&2
  exit 2
fi
source_dir="$run_root/source_qkv"
mkdir -p "$source_dir"
tar -xzf "$evidence/source_qkv_inputs.tar.gz" -C "$source_dir"
source_workload="$source_dir/workload"
test -s "$source_workload/dma_payload.memh"
test -s "$source_workload/late_dma_plan.memh"

make -C "$repo_root/dv/block/control/sim" descriptor-validator-regress \
  DESCRIPTOR_VALIDATOR_OUT="$run_root/validator" 2>&1 | tee "$run_root/validator.make.log"

PATH="$(dirname "$python_bin"):$PATH" \
make -C "$repo_root/dv/subsystem/top_smoke/sim" ai_smoke \
  AI_SPAD_WORDS_PER_BANK=8192 AI_RANDOM_CASES=0 AI_SEED=300030 SEED=300030 \
  2>&1 | tee "$run_root/smoke.make.log"

PATH="$(dirname "$python_bin"):$PATH" \
make -C "$repo_root/dv/subsystem/top_smoke/sim" ai_deit_round30_full_attention_256k \
  AI_DEIT_R30_CONT_PYTHON="$python_bin" \
  AI_DEIT_R30_FULL_RUN="$run_root/full_attention" \
  AI_DEIT_R30_CONT_SOURCE="$source_workload" \
  2>&1 | tee "$run_root/full_attention.make.log"

VCS="${VCS:-vcs}" bash "$repo_root/benchmark/deit/round30/run_repack_directed_round30.sh" \
  "$run_root/repack_directed"

printf 'ROUND30_REPRODUCTION_PASS artifacts=%s\n' "$run_root"
