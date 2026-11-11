# Phase 3 reproduction — stop after Gates 0–2

Product merge `c93ea144713d5fafe2e8a5509029927cd6859e75` (PR #4), reviewed
Phase 2 `20bd47ca714551607268d62a74e2c507fbadc7c4`. Product RTL remains identical.
Research branch `feat/phase3-throughput`; no Phase 3 optimized product RTL.
Run from the research checkout root, never overwrite another worktree.

## Public archive validation (no EDA, network or third-party Python packages)

```bash
python3 tools/benchmark/phase2/validate.py
python3 tools/benchmark/phase3/validate.py
```

Expected markers: `PHASE2_PUBLIC_EVIDENCE_PASS`, `PHASE3_PUBLIC_EVIDENCE_PASS`.
The second verifies source/evidence hashes, fresh-to-Phase2 trace equivalence,
exclusive cycle sums, LN32 arithmetic/fault/recovery evidence, real SRAM fault
counterexamples, all 448 decode scalar calibrations, model resource bounds,
1,560 abstract FIFO invariant cases, 1,040 CNN payloads against independent
Golden and null Tiny system-speedup fields. It does not execute new vector RTL.

## Fresh EDA review and merged baseline replay

Recorded host tools: VCS V-2023.12-SP1_Full64, Verilator 5.052, Python 3.12.13.
Use your legally configured VCS environment. Python used for Top drivers needs
the existing mapper dependencies (numpy/sklearn); public validation and model
use only the standard library. Tool-specific absolute paths below are the
recorded environment and may be replaced with compatible installed tools.
No private PDK, macro library or license file is required or copied.
Use a new output directory so earlier results are preserved.

```bash
set -euo pipefail
export PHASE3_OUT=/tmp/nmaforge-phase3-reproduce
export PHASE3_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python
export VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator
mkdir -p "$PHASE3_OUT/review"
gh pr view 4 --repo cwu766485-ctrl/NMAForge --json state,mergeCommit,url > "$PHASE3_OUT/review/pr4.json"
"$PHASE3_PYTHON" tools/benchmark/phase2/validate.py > "$PHASE3_OUT/phase2-validation.log"
bash tools/benchmark/phase3/run_review.sh > "$PHASE3_OUT/review-driver.log" 2>&1
PHASE1_OUT="$PHASE3_OUT/baseline" bash tools/benchmark/phase1/build_top.sh > "$PHASE3_OUT/build-driver.log" 2>&1
"$PHASE3_PYTHON" tools/benchmark/phase2/run_top.py --out "$PHASE3_OUT/baseline" > "$PHASE3_OUT/baseline-driver.log" 2>&1
"$PHASE3_PYTHON" tools/benchmark/phase1/analyze.py --run "$PHASE3_OUT/baseline" --out "$PHASE3_OUT/baseline/analysis" > "$PHASE3_OUT/baseline-analysis.log" 2>&1
```

`run_review.sh` replays LN32 independent integer/directed fault/reset/abort/
watchdog checks, compiles the new real SRAM/protection counterexample test, and
runs focused lint. Expected `PHASE3_FAULT_CONTRACT_PASS` means the unsafe
aggregation counterexamples were reproduced; **it is not a vector-engine pass**.
The Top replay verifies all fixed workloads and independent CNN Golden, H16,
qualified H32 and old H32 images, plus 20 random Top cases/seed12345. CMDQ timing
excludes initial fixture preload/host work. 4 ns behavioral clock and two-edge
read service are simulation conditions, not Fmax or SRAM-macro evidence.

## Cycle models and public archive

```bash
"$PHASE3_PYTHON" tools/benchmark/phase3/model.py --out "$PHASE3_OUT/model" > "$PHASE3_OUT/model-driver.log" 2>&1
"$PHASE3_PYTHON" tools/benchmark/phase3/archive.py --run "$PHASE3_OUT" --tiny-source /tmp/nmaforge-round28-runs/tiny/source
"$PHASE3_PYTHON" tools/benchmark/phase3/validate.py
```

The model consumes pinned compressed Phase 2 traces. `sfu_calibration.csv`
reconstructs the unchanged scalar FSM exactly. `sfu_models.csv` compares 1/2/4
lanes and scalar versus hypothetical line scheduling; all changed schedules
remain `rtl_admitted=False`. `sfu_resource_bounds.csv` reports per-phase memory
and arithmetic lower bounds. The model keeps other-client slots fixed and is
not a closed-loop product simulation. CNN model replays every 80-cycle tile and
compares bounded pack/commit schedules with immutable Golden payloads.

`archive.py` overwrites only the allowlisted Phase 3 evidence directory inside
this checkout. It refuses a changed product RTL, mismatched fresh replay,
unclean/unpinned Tiny source, or product remote SHA different from this reviewed
merge. If product moves later, validate the existing immutable archive instead;
do not reset the product or rewrite old evidence to fit a newer SHA. No EDA
executables/csrc, private environment, libraries, waves or coverage are archived.

The recorded run directory is `/tmp/nmaforge-phase3-runs`. Large raw traces are
not duplicated: `metadata/fresh_replay_ledger.json` records byte-identical fresh
hashes and references the existing immutable Phase 2 archive. Reports distinguish
new measurements, historical Tiny adapter evidence, conditional predictions and
untested proposed hardware.

## Publication verification

Gate 0 product integration used GitHub PR #4; its merge SHA is pinned above.
Phase 3 research is pushed separately without force, deletion or product merge:

```bash
git diff --check
git push -u origin feat/phase3-throughput
git rev-parse HEAD
git ls-remote origin refs/heads/feat/phase3-throughput refs/heads/nmaforge refs/heads/main
```

Require remote research SHA = local HEAD. Product stays at the reviewed merge;
main and all other worktrees/branches are preserved. Stop here; no next stage or
second RTL modification is started.
