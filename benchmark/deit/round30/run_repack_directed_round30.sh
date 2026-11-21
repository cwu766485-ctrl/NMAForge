#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
if [[ $# -gt 0 ]]; then
  out_dir="$1"
else
  out_dir="$(mktemp -d "${TMPDIR:-/tmp}/nmaforge-round30-repack.XXXXXX")"
fi
mkdir -p "$out_dir"
vcs_bin="${VCS:-vcs}"

"$vcs_bin" -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
  -top tb_tensor_repack -o "$out_dir/simv" \
  "$repo_root/rtl/compute/common/ai_unsigned_divider.v" \
  "$repo_root/rtl/compute/common/ai_integer_sqrt.v" \
  "$repo_root/rtl/compute/sfu/ai_tensor_sfu_math.v" \
  "$repo_root/rtl/control/descriptor/ai_descriptor_validator.v" \
  "$repo_root/rtl/compute/sfu/ai_tensor_sfu_core.v" \
  "$repo_root/benchmark/deit/round29/tb_tensor_repack.sv" \
  -l "$out_dir/compile.log" 2>&1 | tee "$out_dir/compile.console.log"

"$out_dir/simv" -l "$out_dir/run.log" 2>&1 | tee "$out_dir/run.console.log"
grep -q '^TENSOR_REPACK_DIRECTED_TEST_PASS modes=3 heads=3 valid_rows=29 padded_rows=3 golden_words=6144$' \
  "$out_dir/run.log"
(cd "$out_dir" && sha256sum compile.log compile.console.log run.log run.console.log > sha256sums.txt)
printf 'TENSOR_REPACK_DIRECTED_TEST_PASS; artifacts=%s\n' "$out_dir"
