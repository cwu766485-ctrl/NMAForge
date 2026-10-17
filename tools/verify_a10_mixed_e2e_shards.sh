#!/usr/bin/env bash
# Audit and merge a sharded run of the A10 mixed-precision DDR E2E campaign.
# Arguments: <first-shard-root> <continuation-shard-root> [URG report path]
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 <first-shard-root> <continuation-shard-root> [URG-report-dir]" >&2
    exit 2
fi

first_root=$1
continuation_root=$2
report_dir=${3:-"$first_root/urg_merged"}
compile_db="$first_root/simv_uvm.vdb"

[[ -d "$compile_db" ]] || { echo "Missing compile coverage database: $compile_db" >&2; exit 1; }
[[ ! -e "$report_dir" ]] || { echo "Refusing to overwrite existing URG report: $report_dir" >&2; exit 1; }

coverage_dbs=("$compile_db")
seed=20261101
while (( seed <= 20261292 )); do
    if (( seed <= 20261191 )); then
        seed_dir="$first_root/seed_$seed"
    else
        seed_dir="$continuation_root/seed_$seed"
    fi
    log="$seed_dir/run.log"
    [[ -s "$log" ]] || { echo "Missing seed log: $log" >&2; exit 1; }
    [[ -d "$seed_dir/coverage.vdb" ]] || { echo "Missing seed coverage database: $seed_dir/coverage.vdb" >&2; exit 1; }

    for marker in \
        '[MIXED_E2E_PASS]' \
        '[MIXED_E2E_COVERAGE]' \
        '[MIXED_E2E_INVALID_DESC_PASS]' \
        '[MIXED_E2E_AXI_ERROR_PASS]' \
        '[MIXED_E2E_ACTIVE_RESET_PASS]' \
        '[MIXED_E2E_DDR_INDEPENDENT_RESET_PASS]' \
        '[MIXED_E2E_DMA_RESET_PASS]' \
        '[MIXED_E2E_RESET_RECOVERY_PASS]'; do
        grep -Fq "$marker" "$log" || { echo "Missing marker $marker in seed $seed" >&2; exit 1; }
    done
    grep -Eq '\[MIXED_E2E_ORDER\].*permutation=[0-5]' "$log" || { echo "Missing randomized descriptor order in seed $seed" >&2; exit 1; }
    grep -Eq '\[MIXED_E2E_VECTOR\].*SPAD_LAYOUT=[0-5] .*FP16 K=[1-4].*BF16 K=[1-4]' "$log" || { echo "Missing randomized layout/length marker in seed $seed" >&2; exit 1; }
    grep -Fq '[MIXED_E2E_AXI_STALL]' "$log" || { echo "Missing AXI stall report in seed $seed" >&2; exit 1; }
    grep -Eq '\[MIXED_E2E_AXI_STALL\].*phase=pre_dma ar_gap_cfg=[0-3] aw_gap_cfg=[0-3] read_gap_cfg=[0-3] ready_gap_cfg=[0-3] txn_jitter=1' "$log" || { echo "Missing pre-DMA AXI jitter in seed $seed" >&2; exit 1; }
    grep -Eq '\[MIXED_E2E_AXI_STALL\].*phase=post_reset ar_gap_cfg=[0-3] aw_gap_cfg=[0-3] read_gap_cfg=[0-3] ready_gap_cfg=[0-3] txn_jitter=1' "$log" || { echo "Missing post-reset AXI jitter in seed $seed" >&2; exit 1; }
    grep -Fq '** Report counts by severity' "$log" || { echo "Missing UVM severity summary in seed $seed" >&2; exit 1; }
    if grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$log"; then
        echo "Nonzero UVM severity in seed $seed" >&2
        exit 1
    fi

    coverage_dbs+=("$seed_dir/coverage.vdb")
    seed=$((seed + 1))
done

grep -Eq '\[AXI_MEM_ADDR_STALL\] channel=AR configured=[1-3] observed=' "$first_root"/seed_*/run.log "$continuation_root"/seed_*/run.log || { echo "Randomized AR address backpressure was not exercised" >&2; exit 1; }
grep -Eq '\[AXI_MEM_ADDR_STALL\] channel=AW configured=[1-3] observed=' "$first_root"/seed_*/run.log "$continuation_root"/seed_*/run.log || { echo "Randomized AW address backpressure was not exercised" >&2; exit 1; }
echo "A10_MIXED_E2E_PER_SEED_GATES_PASS seeds=192"

urg_bin=${URG:-urg}
"$urg_bin" -full64 -dir "$compile_db" "${coverage_dbs[@]}" -format text \
    -report "$report_dir" -log "$first_root/urg_merged.log"
[[ -d "$report_dir" ]] || { echo "URG report directory was not generated" >&2; exit 1; }
if grep -Eq 'Error-\[UCAPI-DNYL\]|Design Not Loaded Yet|Limited design loaded' "$first_root/urg_merged.log"; then
    echo "URG did not load the complete compile-time design database" >&2
    exit 1
fi

groups="$report_dir/groups.txt"
points="$report_dir/grpinfo.txt"
grep -Fq 'ai_accel_env_pkg::ai_mixed_precision_e2e_coverage::e2e_cg' "$groups"
grep -Eq '^100\.00 100\.00[[:space:]]+1[[:space:]]+100[[:space:]]+1[[:space:]]+1.*ai_accel_env_pkg::ai_mixed_precision_e2e_coverage::e2e_cg' "$groups" || { echo "E2E functional covergroup is not 100%" >&2; exit 1; }
for group in axi_arready_stall_cg axi_awready_stall_cg axi_read_response_gap_cg axi_write_data_gap_cg; do
    grep -Eq "^100\\.00 100\\.00[[:space:]]+1[[:space:]]+100[[:space:]]+1[[:space:]]+1.*tb_ai_accel_uvm\\.axi_mem_u::$group" "$groups" || { echo "AXI coverage group $group is not 100%" >&2; exit 1; }
done
for point in \
    'cp_descriptor_order 6 0 6' \
    'cp_spad_layout 6 0 6' \
    'cp_spad_bank 4 0 4' \
    'cp_invalid_descriptor 6 0 6' \
    'cp_fp16_length 4 0 4' \
    'cp_bf16_length 4 0 4' \
    'cp_axi_read_gap 4 0 4' \
    'cp_axi_ready_gap 4 0 4' \
    'cp_axi_ar_gap 4 0 4' \
    'cp_axi_aw_gap 4 0 4' \
    'cp_dma_slverr 1 0 1' \
    'cp_reset_inflight_compute 1 0 1' \
    'cp_reset_inflight_dma 1 0 1' \
    'cp_independent_ddr_reset 1 0 1' \
    'cp_reset_recovery 1 0 1' \
    'cp_end_to_end 1 0 1' \
    'cp_fp_watchdog_completion 1 0 1' \
    'cp_fp_abort_completion 1 0 1' \
    'fp16_x_bf16_length 16 0 16'; do
    read -r name total ignored hit <<<"$point"
    grep -Eq "^$name[[:space:]]+$total[[:space:]]+$ignored[[:space:]]+$hit[[:space:]]+100\\.00" "$points" || { echo "Functional point $name is not 100%" >&2; exit 1; }
done

echo "MIXED_E2E_RANDOM_COVERAGE_PASS seeds=192"
echo "MIXED_E2E_RANDOM_URG_MERGE_PASS: $report_dir"
