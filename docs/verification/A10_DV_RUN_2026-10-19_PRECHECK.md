# A10 DV Precheck Attempt — 2026-10-19

**Tested source commit:** `db2456b9d3ea314650f927fec00ead37e908a38c`

**Environment:** Rocky Linux 8.10 via reviewed WSL bridge task `top-precheck`.

## Command and completed checks

```sh
make -C dv/subsystem/top_smoke/sim ai_precheck
```

The command first ran the following license-independent checks:

- A4 fixed-point reference: `python3.12 ../../../block/compute/matrix/ref/ai_a3_reference.py --cases 1000 --seed 20260722` — **PASS**, marker `A4_REFERENCE_PASS cases=1000 seed=20260722`.
- Transformer mapper: `python3.12 ../../../../sw/tools/cimforge_mapper.py` — **PASS**, marker `TRANSFORMER_MAPPER_PASS descriptors=30 tensors=31 dataflow=closed poison=enabled`.

## VCS result: not established

The next dependency, `ai_quick`, starts by compiling the top-level smoke with
VCS. The bridge output stopped during that compile. The fresh
`dv/subsystem/top_smoke/sim/ai_comp.log` ends after the VCS banner and
`CPU time: .493 seconds to compile`; no current `simv` executable or fresh
`ai_quick.log` was found, and no simulation `TEST PASS` marker was produced.
The bridge process was no longer active when checked. Its final process exit
status was not captured, so this is **not classified as either a VCS PASS or a
functional RTL failure**.

The same-day sanitized license probe reported both configured variables as
present, but `lmutil lmstat` returned exit 241 (`SERVER_UNREACHABLE`) for each.
This is consistent with an EDA access issue, but the incomplete compile log is
not sufficient to attribute the VCS attempt's exact termination cause.

## Disposition

The A4 reference and Transformer mapper checks pass at this source commit.
`ai_precheck` and `ai_quick` remain **unverified**. Once VCS license access is
confirmed, rerun the command and require a fresh compile/run log ending in
`TEST PASS`; do not reuse the stale `ai_quick.log` as evidence. No RTL or
verification source was changed by this attempt.
