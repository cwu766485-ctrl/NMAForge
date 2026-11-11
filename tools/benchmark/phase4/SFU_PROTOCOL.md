# Phase4 scalar SFU study (no SFU RTL)

```bash
python3.12 tools/benchmark/phase4/sfu_protocol_model.py --out /tmp/nma-p4/sfu_protocol
PHASE3_OUT=/tmp/nma-p4/sfu-contract PHASE3_PYTHON=python3.12 VERILATOR=verilator bash tools/benchmark/phase3/run_review.sh
```

Model PASS means its bounded assertions and counterexamples reproduce, not that
hardware admission passes. It returns a REJECT decision after two directed
rounds. No third repair, scalar pipeline RTL or new error contract is authorized.
The JSON stores concrete host/protection schedules and illustrative closed-loop
contention results; toy cycles are not H32 estimates or trace-calibrated product
cycles. Full refinement to the sole RTL scheduler/dispatcher remains missing.

The separate Gate2 ledger remains immutable at commit73ebc74; public
`validate.py` rechecks its pinned source/artifact hashes. New SFU study has its
own `benchmark/research/phase4/sfu_protocol/manifest.json`, source/artifact SHA256,
actual unchanged-module VCS fault evidence and Python protocol results.
