# Phase 2 reproduction — stop after LN32 implementation and streaming model

Run from the Phase2 checkout root. VCS and Verilator must be on configured legal
EDA paths. Python3.12 needs numpy/sklearn and existing mapper dependencies;
quality evaluation needs torch2.7.1+cpu. Public evidence validation needs only
Python standard library, no EDA license:

```bash
python3 tools/benchmark/phase2/validate.py
```

## Paired Top RTL and directed regressions

Use fresh absolute output/worktree paths. The baseline must compile from the
reviewed merge, never from optimized RTL. The following creates a new detached
baseline worktree without modifying any preexisting one. Existing test/fixture
files are read from this candidate; the product binary is built from baseline.
Recorded session paths were `/tmp/nmaforge-phase2-integration`,
`/tmp/nmaforge-phase2` and `/tmp/nmaforge-phase2-runs`.

```bash
set -euo pipefail
export PHASE2_ROOT="$PWD"
export PHASE2_RUN=/tmp/nmaforge-phase2-reproduce
export PHASE2_BASE=/tmp/nmaforge-phase2-baseline-reproduce
export PHASE2_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python
export PHASE2_TORCH=/tmp/nmaforge_round23_torch/bin/python
export VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator
mkdir -p "$PHASE2_RUN"
git worktree add --detach "$PHASE2_BASE" cb08797e612355b404f9eb697a34f99628deebfd
(cd "$PHASE2_BASE" && PHASE1_OUT="$PHASE2_RUN/baseline" bash tools/benchmark/phase1/build_top.sh)
PHASE1_OUT="$PHASE2_RUN/optimized" bash tools/benchmark/phase1/build_top.sh
"$PHASE2_PYTHON" tools/benchmark/phase2/run_top.py --out "$PHASE2_RUN/baseline" > "$PHASE2_RUN/baseline-driver.log"
"$PHASE2_PYTHON" tools/benchmark/phase2/run_top.py --out "$PHASE2_RUN/optimized" > "$PHASE2_RUN/optimized-driver.log"
for variant in baseline optimized; do
  "$PHASE2_PYTHON" tools/benchmark/phase1/analyze.py --run "$PHASE2_RUN/$variant" --out "$PHASE2_RUN/$variant/analysis" > "$PHASE2_RUN/$variant-analysis.log"
done
git show cb08797e612355b404f9eb697a34f99628deebfd:rtl/compute/sfu/ai_tensor_sfu_core.v > "$PHASE2_RUN/baseline_sfu.v"
PHASE2_DIRECTED_OUT="$PHASE2_RUN/ln32-baseline" PHASE2_SFU_SOURCE="$PHASE2_RUN/baseline_sfu.v" bash tools/benchmark/phase2/run_directed.sh > "$PHASE2_RUN/directed-baseline-driver.log"
PHASE2_DIRECTED_OUT="$PHASE2_RUN/ln32" bash tools/benchmark/phase2/run_directed.sh > "$PHASE2_RUN/directed-driver.log"
(cd "$PHASE2_BASE" && make -C dv/block/compute/sfu/sim random-latency-regress PYTHON="$PHASE2_PYTHON" SEEDS='20261112 20261113 20261114' OUT_DIR="$PHASE2_RUN/sfu-baseline") > "$PHASE2_RUN/sfu-baseline-driver.log" 2>&1
make -C dv/block/compute/sfu/sim random-latency-regress PYTHON="$PHASE2_PYTHON" SEEDS='20261112 20261113 20261114' OUT_DIR="$PHASE2_RUN/sfu-optimized" > "$PHASE2_RUN/sfu-optimized-driver.log" 2>&1
make -C dv/subsystem/top_smoke/sim ai_smoke PYTHON="$PHASE2_PYTHON" > "$PHASE2_RUN/canonical-smoke-driver.log" 2>&1
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345 > "$PHASE2_RUN/canonical-seeded-driver.log" 2>&1
bash tools/benchmark/phase2/lint.sh
"$PHASE2_PYTHON" tools/benchmark/phase1/static_review.py --out "$PHASE2_RUN/static" --verilator "$VERILATOR" > "$PHASE2_RUN/static-driver.log"
"$PHASE2_PYTHON" tools/benchmark/phase2/ablation.py --run "$PHASE2_RUN" > "$PHASE2_RUN/ablation-driver.log"
"$PHASE2_PYTHON" tools/benchmark/phase2/streaming_model.py --baseline "$PHASE2_RUN/baseline" --optimized "$PHASE2_RUN/optimized" --out "$PHASE2_RUN/streaming" > "$PHASE2_RUN/streaming-driver.log"
```

`static_review.py` creates a throwaway mux-default diagnostic copy, not a product
fix. Its raw summary hardcodes the Phase1 `product_rtl_changed=false` field;
Phase2's archiver explicitly corrects that field and documents its scope.
Its named `baseline.log` means the unpatched current candidate, not pre-LN32.
No area/Fmax evidence is provided by these lint commands.

## Fixed-weight quality and same-adapter TinyNPU

No training occurs in Phase2. Use the immutable Phase1 checkpoint/INT8 artifact.
TinyNPU source must be clean at the pinned SHA; obtain it in a new checkout if
not already available. Do not reset or modify another working checkout.

```bash
"$PHASE2_TORCH" tools/benchmark/phase1/evaluate_h32.py \
 --checkpoint benchmark/research/phase1/model/fp32_state.pt \
 --model benchmark/research/phase1/model/h32_int8.json \
 --out "$PHASE2_RUN/blind_quality.json" > "$PHASE2_RUN/blind-quality.log"
export TINY_NPU_ROOT=/tmp/nmaforge-round28-runs/tiny/source
test "$(git -C "$TINY_NPU_ROOT" rev-parse HEAD)" = 8216c22b762011aa20c05fc2768423fd12dda59d
test -z "$(git -C "$TINY_NPU_ROOT" status --porcelain)"
PHASE1_MATCHED_OUT="$PHASE2_RUN/matched" PHASE1_PYTHON="$PHASE2_PYTHON" \
 PHASE1_MODEL="$PHASE2_ROOT/benchmark/research/phase1/model/h32_int8.json" \
 bash tools/benchmark/phase1/run_matched.sh > "$PHASE2_RUN/matched-driver.log" 2>&1
"$PHASE2_PYTHON" tools/benchmark/phase2/archive.py --run "$PHASE2_RUN"
"$PHASE2_PYTHON" tools/benchmark/phase2/validate.py
git diff --check
```

The archiver writes only public allowlisted results under
`benchmark/research/phase2`: no simulator binaries/build databases, coverage,
license settings, private libraries or waveforms. Re-archiving updates evidence
hashes for the current checkout, so inspect the diff before committing it.

PASS markers are checked, not just simulator exit status. Absolute paths in
recorded command files describe the original session; `run_top.py` remaps fixture
paths into the chosen run directory. Timestamp-dependent logs may differ while
cycles/traffic/Golden remain stable. LN32 is measured RTL; streaming is only a
trace-conditioned model and remains unadmitted pending fault-timing review.
