#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
array_size=${1:-8}
period_ns=${2:-4.0}
compile_mode=${3:-medium}
synth_top=${4:-ai_tensor_matrix_array}
run_root=${NMAFORGE_R7_RUN_ROOT:-/tmp/nmaforge_round7_synth}
run_dir="$run_root/${synth_top}_${array_size}_${compile_mode}_${period_ns//./p}ns"

setup_script=${TSMC28_ENV_SETUP:?Set TSMC28_ENV_SETUP to the private TSMC28 environment setup script}
source "$setup_script"
std_db=${NMAFORGE_R7_STD_LIB:?Set NMAFORGE_R7_STD_LIB to the private standard-cell NLDM database}
dc_bin="${DC_HOME:-/opt/Synopsys/syn/V-2023.12-SP1}/bin/dc_shell"
if [[ ! -x "$dc_bin" ]]; then
  echo "BLOCKED_ENV: Design Compiler executable is unavailable" >&2
  exit 127
fi
if [[ ! -f "$std_db" ]]; then
  echo "BLOCKED_ENV: selected TT 0.9 V standard-cell database is unavailable" >&2
  exit 127
fi
mkdir -p "$run_dir"
export NMAFORGE_R7_ARRAY_SIZE="$array_size"
export NMAFORGE_R7_PERIOD_NS="$period_ns"
export NMAFORGE_R7_RUN_DIR="$run_dir"
export NMAFORGE_R7_STD_LIB="$std_db"
export NMAFORGE_R7_COMPILE_MODE="$compile_mode"
export NMAFORGE_R7_OPCOND="${NMAFORGE_R7_OPCOND:-tt0p9v25c}"
export NMAFORGE_R7_MAX_CORES="2"
export NMAFORGE_R7_TOP="$synth_top"
timeout_s=${NMAFORGE_R7_TIMEOUT_S:-3600}

{
  printf 'run_id=R7-%s-%s-%s-%s\n' "$synth_top" "$array_size" "$compile_mode" "$period_ns"
  printf 'source_sha=%s\n' "$(git -C "$root" rev-parse HEAD)"
  printf 'tool=Synopsys Design Compiler V-2023.12-SP1\n'
  printf 'pvt=TSMC28 HPC+ RVT TT 0.9V 25C\n'
  printf 'period_ns=%s\narray_size=%s\ncompile_mode=%s\nmax_cores=2\ntimeout_s=%s\n' \
    "$period_ns" "$array_size" "$compile_mode" "$timeout_s"
  printf 'host=%s\n' "$(hostname)"
  printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '\n--- memory before run ---\n'
  free -h
  printf '\n--- cpu ---\n'
  lscpu | rg 'Model name|CPU\(s\)|Thread|Core|Socket' | head -n 8
} > "$run_dir/run_manifest.txt"

set +e
/usr/bin/time -v -o "$run_dir/resource_usage.txt" \
  timeout --signal=TERM --kill-after=30s "${timeout_s}s" \
  "$dc_bin" -f "$root/syn/run_round7_matrix_synth.tcl" \
  > "$run_dir/console.log" 2>&1
status=$?
set -e
cat "$run_dir/console.log"
printf 'exit_status=%s\nfinished_utc=%s\n' "$status" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  >> "$run_dir/run_manifest.txt"
exit "$status"
