# Compute Cluster SPAD Fairness Replay — R266 — 2026-11-03

## Result

Both existing deterministic SPAD fairness targets pass from a detached clean
worktree at published candidate SHA `0430b651bb28cc3cca12f29faaccb70a74d52392`
(tree `7422de5cac53d3351da8e0cbee1c8825cde43cfc`). No RTL or testbench source
was changed. Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`.

| Run ID | Test | Observed result |
|---|---|---|
| `R266-COMPUTE-SPAD-MUX-FAIRNESS` | `ai_compute_spad_mux_fairness` | `COMPUTE_SPAD_MUX_FAIRNESS_PASS`; 4,096 cycles, 3,233 grants, seven lane grants `462/462/462/462/462/462/461`, max wait `10/10/10/10/10/10/10` cycles, 2,582 responses. Three assertions passed; none failed, were incomplete, or lacked attempts. |
| `R266-COMPUTE-SPAD-PATH-FAIRNESS` | `ai_compute_spad_path_fairness` | `COMPUTE_SPAD_PATH_FAIRNESS_PASS`; 4,096 cycles and accepts, compute lane grants `193/194/193/193/193/193/193`, max wait `22` cycles per lane, and 3,465 responses checked. Three assertions passed and all four cover properties matched; no failures, incomplete checks, or checks without attempts. |

The second test also observed 1,353 core, 1,352 banked, and 1,352 DMA
admissions. Its assertions cover one-hot scheduler grants, one-hot engine
response ownership, and stable core payload during preemption. Covers observe
core/banked/DMA admission and descriptor service ahead of completion. The first
test checks one-hot lane grants and response owners plus stable selected
payload under stalls.

## Reproduction

Both commands were run in detached clean worktree
`/tmp/nmaforge_r266_spad_clean_0430b65` at the SHA above; VCS output stayed in
`/tmp`.

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
make -C dv/subsystem/top_smoke/sim ai_compute_spad_mux_fairness \
  COMPUTE_SPAD_MUX_RR_RUN=/tmp/nmaforge_r266_mux_0430b65 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
make -C dv/subsystem/top_smoke/sim ai_compute_spad_path_fairness \
  COMPUTE_SPAD_PATH_RUN=/tmp/nmaforge_r266_path_0430b65 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg
```

Both compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.
The first URG assertion summary is 3/3 successful; the path test is 3/3
assertions and 4/4 cover properties. Its harness-level score is 65.82% and the
MUX harness score is 78.81%; these are mixed testbench/hierarchy figures, not
DUT-only Compute Cluster coverage and not a coverage-closure claim.

Logs-only archive:
`/tmp/nmaforge_r266_spad_fairness_logs_v2_20261103.tar.gz`  
SHA-256: `d3762c4b0e3104b52b3f22a23604a7f874c276655a7de2c1852f8d98ac101f61`.
The archive contains compile/run/URG text only; it excludes VDBs, simulator
binaries, `csrc`, and waveforms.

## Requirement trace and limits

This replay adds bounded arbitration-path evidence for `REQ-CL-014` and
`REQ-PC-006/007`. The tests instantiate the production compute SPAD MUX and,
for the path test, the production `ai_spad_arbiter`; requester traffic and
response memory are behavioral harnesses. They do not instantiate the seven
production engines, real SRAM/backpressure, full protection/fault recovery,
or the full memory subsystem. Therefore the tests do not close the production
seven-engine shared-SPAD requirement and do not promote any RTM disposition.
The current RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains
**HOLD**.
