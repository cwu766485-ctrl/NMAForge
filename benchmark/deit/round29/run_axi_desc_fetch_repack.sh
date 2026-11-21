#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../../.." && pwd)
run_dir="${1:-/tmp/nmaforge_round29_axi_desc_fetch}"
mkdir -p "$run_dir"
test ! -e "$run_dir/simv"

cd "$repo_root"
vcs -full64 -sverilog -timescale=1ns/1ps -top tb_axi_desc_fetch_repack \
  -o "$run_dir/simv" rtl/control/descriptor/axi_desc_fetch.v \
  benchmark/deit/round29/tb_axi_desc_fetch_repack.sv \
  -l "$run_dir/compile.log"
"$run_dir/simv" -l "$run_dir/run.log"
grep -q '^AXI_DESC_REPACK_EXTENT_PASS opcode=0x3b length=13 k_words=0$' "$run_dir/run.log"
grep -q '^AXI_DESC_LEGACY_GEMM_EXTENT_PASS opcode=0x30 length=4 k_words=4$' "$run_dir/run.log"
grep -q '^AXI_DESC_FETCH_REPACK_TEST_PASS$' "$run_dir/run.log"
