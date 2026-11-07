#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
vip_root="${PROTOCOL_VIP_ROOT:-/mnt/e/workspace/chip/vip}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="${AXIL_VIP_OUT:-/tmp/nmaforge_axi_lite_vip_${stamp}}"
seeds="${AXIL_VIP_SEEDS:-20261107 20261108}"

test -f "${vip_root}/vip_axi/tue/compile.f" || {
  echo "ERROR: missing TUE compile list under ${vip_root}/vip_axi" >&2
  exit 1
}
test -f "${vip_root}/vip_axi/tvip-common/compile.f" || {
  echo "ERROR: missing TVIP Common compile list under ${vip_root}/vip_axi" >&2
  exit 1
}

read -r -a seed_list <<< "${seeds}"
(( ${#seed_list[@]} > 0 )) || { echo "ERROR: AXIL_VIP_SEEDS is empty" >&2; exit 1; }
for seed in "${seed_list[@]}"; do
  [[ "${seed}" =~ ^[0-9]+$ ]] || {
    echo "ERROR: invalid random seed '${seed}'" >&2
    exit 1
  }
done

mkdir -p "${out_dir}"
echo "NMAForge AXI4-Lite VIP CSR regression"
echo "VIP:      $(git -C "${vip_root}" rev-parse --short HEAD)"
echo "Output:   ${out_dir}"
echo "Seeds:    ${seed_list[*]}"

make -C "${repo_root}/dv/uvm/sim" axi_lite_vip_compile \
  PROTOCOL_VIP_ROOT="${vip_root}" AXIL_VIP_OUT="${out_dir}"

compile_log="${out_dir}/compile.log"
test -s "${compile_log}" || { echo "ERROR: compile log missing/empty: ${compile_log}" >&2; exit 1; }
if grep -Eq 'Error-[[:alnum:]_-]+' "${compile_log}"; then
  echo "ERROR: VCS compile log contains an Error diagnostic: ${compile_log}" >&2
  tail -n 80 "${compile_log}" >&2
  exit 1
fi

for seed in "${seed_list[@]}"; do
  run_log="${out_dir}/run_seed_${seed}.log"
  echo "Running AXI-Lite CSR test, seed ${seed}"
  if ! "${out_dir}/simv" +UVM_TESTNAME=nma_axi_lite_csr_vip_test \
      "+ntb_random_seed=${seed}" -l "${run_log}"; then
    echo "ERROR: simulation failed at seed ${seed}; log: ${run_log}" >&2
    tail -n 100 "${run_log}" >&2 || true
    exit 1
  fi

  grep -Fq 'NMA_AXIL_VIP_CSR_PASS: real ai_accel_top' "${run_log}" || {
    echo "ERROR: real-DUT CSR acceptance marker missing at seed ${seed}" >&2
    tail -n 100 "${run_log}" >&2
    exit 1
  }
  grep -Eq 'NMA_AXIL_VIP_TIMING_PASS: AW-only=[1-9][0-9]* W-only=[1-9][0-9]* B-stall=([3-9]|[1-9][0-9]+) R-stall=([3-9]|[1-9][0-9]+)' "${run_log}" || {
    echo "ERROR: independent AW/W timing or B/R backpressure evidence missing at seed ${seed}" >&2
    tail -n 100 "${run_log}" >&2
    exit 1
  }
  grep -Eq 'AXI requests=8 completed=8 reads=4 writes=4 outstanding=0 reset_aborted=0 mismatches=0' "${run_log}" || {
    echo "ERROR: AXI transaction accounting did not close at seed ${seed}" >&2
    tail -n 100 "${run_log}" >&2
    exit 1
  }
  for severity in WARNING ERROR FATAL; do
    grep -Eq "^[[:space:]]*UVM_${severity}[[:space:]]*:[[:space:]]*0[[:space:]]*$" "${run_log}" || {
      echo "ERROR: missing zero UVM_${severity} report at seed ${seed}" >&2
      tail -n 100 "${run_log}" >&2
      exit 1
    }
  done
  echo "PASS seed=${seed}: real ai_accel_top CSR marker, 8/8 transactions, UVM warning/error/fatal=0"
done

echo "PROTOCOL_VIP_AXIL_VCS_REGRESSION_PASS"
echo "Logs: ${out_dir}"
