# Phase 1 reproduction

Run from the repository root in the established VCS environment. These scripts
change DV/model/evidence only; no Matrix/SFU product optimization is implemented.
Use a fresh absolute run directory. Python3.12 requires numpy, sklearn and mapper
runtime dependencies; training/evaluation additionally require torch2.7.1+cpu.

```bash
set -euo pipefail
export PHASE1_OUT=/tmp/nmaforge-phase1-runs
export PHASE1_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python
export PHASE1_TORCH=/tmp/nmaforge_round23_torch/bin/python
mkdir -p "$PHASE1_OUT"
"$PHASE1_TORCH" tools/benchmark/phase1/train_h32.py --out "$PHASE1_OUT/model" > "$PHASE1_OUT/train.log"
"$PHASE1_TORCH" tools/benchmark/phase1/train_h32.py --out "$PHASE1_OUT/retrain" > "$PHASE1_OUT/retrain.log"
cmp "$PHASE1_OUT/model/h32_int8.json" "$PHASE1_OUT/retrain/h32_int8.json"
"$PHASE1_PYTHON" tools/benchmark/stage_c/reference.py --model "$PHASE1_OUT/model/h32_int8.json" --out "$PHASE1_OUT/model/int8_quality.json" > "$PHASE1_OUT/int8-quality.log"
"$PHASE1_TORCH" tools/benchmark/phase1/evaluate_h32.py --checkpoint "$PHASE1_OUT/model/fp32_state.pt" --model "$PHASE1_OUT/model/h32_int8.json" --out "$PHASE1_OUT/model/blind_quality.json" > "$PHASE1_OUT/blind-quality.log"
bash tools/benchmark/phase1/build_top.sh
"$PHASE1_PYTHON" tools/benchmark/phase1/run.py --out "$PHASE1_OUT" --model "$PHASE1_OUT/model/h32_int8.json" > "$PHASE1_OUT/driver.log"
"$PHASE1_PYTHON" tools/benchmark/phase1/analyze.py --run "$PHASE1_OUT" --out "$PHASE1_OUT/analysis" > "$PHASE1_OUT/analysis-driver.log"
make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=20261112 MATRIX_CONFIG_OUT="$PHASE1_OUT/matrix" > "$PHASE1_OUT/matrix-driver.log" 2>&1
export PHASE1_MATCHED_OUT="$PHASE1_OUT/matched"
export PHASE1_MODEL="$PHASE1_OUT/model/h32_int8.json"
export TINY_NPU_ROOT=/tmp/nmaforge-round28-runs/tiny/source
export VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator
git -C "$TINY_NPU_ROOT" rev-parse HEAD
git -C "$TINY_NPU_ROOT" status --short
bash tools/benchmark/phase1/run_matched.sh > "$PHASE1_OUT/matched-driver.log" 2>&1
"$PHASE1_PYTHON" tools/benchmark/phase1/static_review.py --out "$PHASE1_OUT/static" --verilator "$VERILATOR" > "$PHASE1_OUT/static-driver.log"
"$PHASE1_PYTHON" tools/benchmark/phase1/supplement.py --run "$PHASE1_OUT"
"$PHASE1_PYTHON" tools/benchmark/phase1/archive.py --run "$PHASE1_OUT" --out benchmark/research/phase1
"$PHASE1_PYTHON" tools/benchmark/phase1/validate.py
git diff --check
git diff 48790076b351cb9d49e1785247d32a1f51b8286d -- rtl
```

Tiny must be clean at8216c22b762011aa20c05fc2768423fd12dda59d. Build products,
license/environment variables and private libraries are not published. The archive
allowlist retains public fixtures, raw passive traces, logs, trained weights and
hashes. `validate.py` checks the public package without EDA licenses.

The actual session made an observer-only rebuild and used
`replay_transformers.py --run "$PHASE1_OUT"` to replay the existing exact fixtures.
This corrected the observer's error selection: banked parity comes from the
banked response, not the inactive scalar-data error mux. CNN traces were replayed
with separate `+STAGE_A_PROFILE` and `+PHASE1_PROFILE` prefixes to prevent file
collisions. Both corrections are incorporated in the fresh runner above.

All PASS markers must be checked; simulator process exit0 alone is insufficient.
Host timing and byte-identical training are environment-specific and are not a
promise of physical implementation frequency or natural-language model quality.
