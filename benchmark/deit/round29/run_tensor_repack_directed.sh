#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
evidence_dir="$repo_root/benchmark/deit/round29/evidence/repack"
build_dir="${TMPDIR:-/tmp}/nmaforge_round29_tensor_repack"
mkdir -p "$evidence_dir" "$build_dir"

run_id="round29-repack-$(date -u +%Y%m%dT%H%M%SZ)"
printf 'run_id=%s\n' "$run_id" | tee "$evidence_dir/run_manifest.txt"
printf 'source_head=%s\n' "$(git rev-parse HEAD)" | tee -a "$evidence_dir/run_manifest.txt"
printf 'working_diff_sha256=%s\n' "$(git diff --binary | sha256sum | awk '{print $1}')" | tee -a "$evidence_dir/run_manifest.txt"
printf 'vcs_path=%s\n' "$(command -v vcs)" | tee -a "$evidence_dir/run_manifest.txt"
vcs -ID > "$evidence_dir/vcs_version.txt" 2>&1

compile_log="$evidence_dir/${run_id}_compile.log"
run_log="$evidence_dir/${run_id}_run.log"

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
  -top tb_tensor_repack -o "$build_dir/simv" \
  "$repo_root/rtl/compute/common/ai_unsigned_divider.v" \
  "$repo_root/rtl/compute/common/ai_integer_sqrt.v" \
  "$repo_root/rtl/compute/sfu/ai_tensor_sfu_math.v" \
  "$repo_root/rtl/control/descriptor/ai_descriptor_validator.v" \
  "$repo_root/rtl/compute/sfu/ai_tensor_sfu_core.v" \
  "$repo_root/benchmark/deit/round29/tb_tensor_repack.sv" \
  2>&1 | tee "$compile_log"

"$build_dir/simv" "$@" 2>&1 | tee "$run_log"
if ! grep -q 'TENSOR_REPACK_DIRECTED_TEST_PASS' "$run_log"; then
  echo 'directed simulation did not reach the PASS sentinel' >&2
  exit 1
fi

sha256sum "$compile_log" "$run_log" | tee "$evidence_dir/${run_id}_log_sha256.txt"
