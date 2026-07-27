#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PERIOD_NS=${1:-5.0}
RUN_DIR=${CIMFORGE_DC_RUN_DIR:-"$ROOT/syn/out/tsmc40_${PERIOD_NS//./_}ns"}

: "${TSMC40_LIB_TC:?Set TSMC40_LIB_TC to a TSMC40 standard-cell .db}"
mkdir -p "$RUN_DIR"
export CIMFORGE_DC_PERIOD_NS="$PERIOD_NS"
export CIMFORGE_DC_RUN_DIR="$RUN_DIR"
set +e
set -o pipefail
dc_shell -f "$ROOT/syn/dc_ai_accel_40nm.tcl" | tee "$RUN_DIR/dc.log"
dc_status=${PIPESTATUS[0]}
set -e

if [[ $dc_status -ne 0 ]] || ! grep -q "CIMForge DC completed:" "$RUN_DIR/dc.log"; then
    echo "ERROR: DC did not complete successfully; inspect $RUN_DIR/dc.log" >&2
    exit 1
fi
