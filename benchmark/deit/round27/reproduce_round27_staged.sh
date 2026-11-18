#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
OUT=${1:-${TMPDIR:-/tmp}/nmaforge_deit_round27_replay}
PYTHON=${PYTHON:-/tmp/nmaforge_deit_round17_venv/bin/python}
VCS=${VCS:-vcs}
DEIT_MODEL_DIR=${DEIT_MODEL_DIR:-/home/ray/.cache/huggingface/hub/models--facebook--deit-tiny-patch16-224/snapshots/b3428f18dcc7b543470d07f14b4a4157815d1880}

command -v "$PYTHON" >/dev/null || { echo "Python executable not found: $PYTHON" >&2; exit 127; }
command -v "$VCS" >/dev/null || { echo "VCS executable not found: $VCS" >&2; exit 127; }
[[ -d "$DEIT_MODEL_DIR" ]] || { echo "DeiT checkpoint directory not found: $DEIT_MODEL_DIR" >&2; exit 2; }

# Child replay scripts consume these variables while compiling and generating
# each staged workload. Keep the caller's licensed VCS_HOME untouched.
export PYTHON VCS DEIT_MODEL_DIR

mkdir -p "$OUT"
"$ROOT/benchmark/deit/round26/replay_qkv197.sh" "$OUT/qkv197"
DEIT_QKV_EVIDENCE="$OUT/qkv197" \
  "$ROOT/benchmark/deit/round26/replay_attention3_qblock.sh" "$OUT/attention3_qblock"

# Verify the checked-in canonical evidence independently of the fresh replay.
"$PYTHON" "$ROOT/benchmark/deit/round27/audit_round27_staged_runs.py"
echo "ROUND27_DEIT_STAGED_REPLAY_COMPLETE out=$OUT continuous=PARTIAL"
