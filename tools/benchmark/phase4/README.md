# Phase 4 reproducibility

Run from the candidate repository root; use Python 3.12 and VCS V-2023.12-SP1.
All output directories are absolute and external to tracked sources.

```bash
git worktree add --detach /tmp/nma-p4-base c93ea144713d5fafe2e8a5509029927cd6859e75
PHASE4_OUT=/tmp/nma-p4/baseline PHASE4_RTL_ROOT=/tmp/nma-p4-base bash tools/benchmark/phase4/build_top.sh
python3.12 tools/benchmark/phase2/run_top.py --out /tmp/nma-p4/baseline
python3.12 tools/benchmark/phase1/analyze.py --run /tmp/nma-p4/baseline --out /tmp/nma-p4/baseline/analysis
PHASE4_OUT=/tmp/nma-p4/optimized-final bash tools/benchmark/phase4/build_top.sh
python3.12 tools/benchmark/phase2/run_top.py --out /tmp/nma-p4/optimized-final
python3.12 tools/benchmark/phase1/analyze.py --run /tmp/nma-p4/optimized-final --out /tmp/nma-p4/optimized-final/analysis
PHASE4_OUT=/tmp/nma-p4/directed-final bash tools/benchmark/phase4/run_core.sh
PHASE4_OUT=/tmp/nma-p4/disabled PHASE4_ENABLE=0 bash tools/benchmark/phase4/run_core.sh
PHASE4_OUT=/tmp/nma-p4/lint PHASE4_BASELINE=/tmp/nma-p4-base VERILATOR=verilator bash tools/benchmark/phase4/lint.sh
(cd dv/subsystem/top_smoke/sim && make ai_smoke SEED=20261021 > /tmp/nma-p4/canonical-smoke.log 2>&1 && make ai_run SEED=20261022 AI_RANDOM_CASES=20 AI_SEED=12345 > /tmp/nma-p4/canonical-seeded.log 2>&1)
python3.12 tools/benchmark/phase4/archive.py --runs /tmp/nma-p4 --out /tmp/nma-p4/archive
```

`run_top.py` replays the pinned Phase1 workload/Golden without training or numeric
changes. Baseline uses baseline RTL/filelist with the same passive candidate TB.
Gate2 archive compares all 1040 accepted address/data/WSTRB/order transactions to
Phase3's independent payload list, not just total counts. Directed tests exercise
both parameter settings, three seeds, legal and denied prefixes, both buffers
full, last drain, partial tile, both layouts and legacy forwarding fallback.
Watchdog priority probes use a force on the existing latched watchdog limit;
four additional cases program the public input before launch, with no DUT force.
The generic core campaign also exercises existing parity and pending-read drain.
Top smoke includes 0x52/0x53 and seeded20 recovery tests. All simulation products
remain local; public evidence contains source hashes, text logs and CSVs only.

Public evidence replay: `python3.12 tools/benchmark/phase4/validate.py`.
512KiB compatibility (capacity/fault boundary, not full-model replay):

```bash
PHASE4_OUT=/tmp/nma-p4/compat512 PHASE4_SPAD_WORDS=32768 bash tools/benchmark/phase4/build_top.sh
/tmp/nma-p4/compat512/top/simv +AI_SPAD_CAPACITY_BOUNDARIES +AI_RANDOM_CASES=0 +AI_SEED=12345
```
