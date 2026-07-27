#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PERIOD_NS=${1:-4.0}
RUN_DIR=${CIMFORGE_DC_RUN_DIR:-"$ROOT/syn/out/tsmc28_${PERIOD_NS//./_}ns"}

: "${TSMC28_STDCELL_DB:?Set TSMC28_STDCELL_DB to a TSMC28 standard-cell .db}"
: "${TSMC28_SRAM_DB_TT:?Set TSMC28_SRAM_DB_TT to a matching TSMC28 SRAM .db}"
mkdir -p "$RUN_DIR"
export CIMFORGE_DC_PERIOD_NS="$PERIOD_NS"
export CIMFORGE_DC_RUN_DIR="$RUN_DIR"

set +e
set -o pipefail
dc_shell -f "$ROOT/syn/dc_ai_accel_28nm.tcl" | tee "$RUN_DIR/dc.log"
dc_status=${PIPESTATUS[0]}
set -e
if [[ $dc_status -ne 0 ]] || ! grep -q "CIMForge TSMC28 DC completed:" "$RUN_DIR/dc.log"; then
    echo "ERROR: TSMC28 DC did not complete successfully; inspect $RUN_DIR/dc.log" >&2
    exit 1
fi
