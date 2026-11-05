#!/usr/bin/env bash
set -euo pipefail

vip_root=/mnt/e/workspace/chip/vip
out=$(mktemp -d /tmp/nmaforge_protocol_vip_dma.XXXXXX)
mkdir -p "$out/csrc"
sim="$out/simv_dma_axi_vip"

if ! make -C dv/block/dma/sim uvm_vip_compile \
    VIP_ROOT="$vip_root" \
    VIP_SIMV="$sim" \
    VIP_COV_DIR="$out/compile.vdb" \
    VCS="vcs -Mdir=$out/csrc" >"$out/compile.log" 2>&1; then
  echo VIP_DMA_COMPILE_FAIL
  tail -n 100 "$out/compile.log"
  exit 1
fi

for seed in 123 98765; do
  log="$out/seed_$seed.log"
  if ! "$sim" \
      -cm line+cond+fsm+tgl+branch+assert \
      -cm_dir "$out/seed_$seed.vdb" \
      -cm_name dma_axi_vip_integration_test \
      +UVM_TESTNAME=dma_axi_vip_integration_test \
      +ntb_random_seed="$seed" \
      +UVM_VERBOSITY=UVM_MEDIUM \
      -l "$log" >"$out/seed_$seed.console" 2>&1; then
    echo "VIP_DMA_SIM_FAIL_SEED=$seed"
    tail -n 100 "$out/seed_$seed.console" "$log"
    exit 1
  fi

  if ! grep -Fq '[DMA_AXI_VIP_PASS]' "$log"; then
    echo "VIP_DMA_PASS_MARKER_MISSING_SEED=$seed"
    tail -n 100 "$log"
    exit 1
  fi
  if grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$log"; then
    echo "VIP_DMA_UVM_SEVERITY_NONZERO_SEED=$seed"
    tail -n 100 "$log"
    exit 1
  fi
  if ! grep -Eq 'AXI requests=[0-9]+ completed=[0-9]+ reads=[0-9]+ writes=[0-9]+ outstanding=0 reset_aborted=0 mismatches=0' "$log"; then
    echo "VIP_DMA_SCOREBOARD_SUMMARY_MISSING_SEED=$seed"
    tail -n 100 "$log"
    exit 1
  fi
  if [[ $(grep -Fc '[SB_PASS]' "$log") -lt 3 ]]; then
    echo "VIP_DMA_PROJECT_SCOREBOARD_PASS_MARKERS_MISSING_SEED=$seed"
    tail -n 100 "$log"
    exit 1
  fi
  echo "--- SEED $seed acceptance evidence ---"
  grep -E '\[DMA_AXI_VIP_PASS\]|\[SB_PASS\]|\[tvip_axi_scoreboard\] AXI requests=|\[DMA_COVERAGE\]|UVM_(WARNING|ERROR|FATAL)[[:space:]]*:' "$log"
  echo "PASS_SEED=$seed"
done

echo "NMAFORGE_PROTOCOL_VIP_DMA_PASS seeds=2/2 severity=0/0/0"
echo "ARTIFACT_ROOT=$out"
