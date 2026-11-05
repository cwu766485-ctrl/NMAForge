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

# Guard the original BFM-based flow: standard filelists must not depend on the
# optional protocol-vip packages or integration-only test class.
legacy_sim="$out/simv_dma_legacy"
mkdir -p "$out/legacy_csrc"
if ! make -C dv/block/dma/sim uvm_compile \
    SIMV="$legacy_sim" \
    COV_DIR="$out/legacy_compile.vdb" \
    VCS="vcs -Mdir=$out/legacy_csrc" >"$out/legacy_compile.log" 2>&1; then
  echo DMA_LEGACY_COMPILE_FAIL
  tail -n 100 "$out/legacy_compile.log"
  exit 1
fi
legacy_log="$out/legacy_seed_123.log"
if ! "$legacy_sim" \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir "$out/legacy_seed_123.vdb" \
    -cm_name dma_load_ooo_smoke_test \
    +UVM_TESTNAME=dma_load_ooo_smoke_test \
    +ntb_random_seed=123 +UVM_VERBOSITY=UVM_MEDIUM \
    -l "$legacy_log" >"$out/legacy_seed_123.console" 2>&1; then
  echo DMA_LEGACY_SIM_FAIL
  tail -n 100 "$out/legacy_seed_123.console" "$legacy_log"
  exit 1
fi
if ! grep -Fq '[SB_PASS]' "$legacy_log" ||
   grep -Eq 'UVM_(WARNING|ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$legacy_log"; then
  echo DMA_LEGACY_EVIDENCE_FAIL
  tail -n 100 "$legacy_log"
  exit 1
fi
echo "--- LEGACY BFM compatibility evidence ---"
grep -E '\[SB_PASS\]|UVM_(WARNING|ERROR|FATAL)[[:space:]]*:' "$legacy_log"

archive="$PWD/dv/block/dma/artifacts/protocol-vip/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$archive"
cp "$out/compile.log" "$archive/compile.log"
cp "$out/seed_123.log" "$archive/seed_123.log"
cp "$out/seed_123.console" "$archive/seed_123_console.log"
cp "$out/seed_98765.log" "$archive/seed_98765.log"
cp "$out/seed_98765.console" "$archive/seed_98765_console.log"
cp "$out/legacy_compile.log" "$archive/legacy_compile.log"
cp "$legacy_log" "$archive/legacy_seed_123.log"
cp "$out/legacy_seed_123.console" "$archive/legacy_seed_123_console.log"

echo "NMAFORGE_PROTOCOL_VIP_DMA_PASS seeds=2/2 severity=0/0/0"
echo "TEMP_ARTIFACT_ROOT=$out"
echo "ARCHIVED_LOG_ROOT=$archive"
