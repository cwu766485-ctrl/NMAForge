# Compute-engine feature coverage follow-up — 2026-10-23

> This is the preceding compute-cluster regression snapshot. The latest
> interaction tests, aggregate rerun, and updated merged coverage are in the
> [interaction follow-up](COMPUTE_ENGINE_INTERACTION_FOLLOWUP_2026-10-23.md).

## Scope

The previous compute cluster run covered normal datapaths well but left block
error exits and reset recovery unevenly checked. CNN coverage also used only a
single 3×3 output and did not launch the depthwise opcode directly. This update
adds those scenarios across the compute groups and expands the CNN spatial
window checks.

## Changes and results

- **CNM:** Per seed, the independent signed INT8 oracle now includes a valid
  post-reset recovery case. Six error exits check invalid length, bank parity,
  bank protection, SPAD write protection, watchdog, and abort. Existing A2.2,
  GEMV, and 10-seed DMA–SPAD–CNM tests remain in the aggregate.
- **CNN/KV:** Each of three seeds checks 24 convolution cases with 3–6 row and
  column dimensions, including 12 `DWCONV3X3` opcode cases. The scoreboard
  verifies every sliding-window output. KV checks 24 write/read round trips.
  Both engines now test configuration error, SPAD error, abort, watchdog,
  in-flight reset, and a successful command after reset.
- **Matrix:** Each of three seeds checks the in-flight reset path and a
  successful recovery, alongside 10,072 datapath vectors, six full-core
  numerical/layout/recovery cases, and 10 isolated fault cases.
- **SFU:** Each of three seeds checks seven error exits: invalid length,
  unsupported opcode, unaligned input, SPAD protection, SPAD parity, abort,
  and watchdog. Reset clears an active command; subsequent oracle vectors
  exercise recovery. The existing 64 vectors cover all eight opcodes.
- **FP:** Existing three-seed mixed-format UVM, maximum-length parity,
  add/sub, wrapper, and reference checks ran unchanged.

The added error tests found a real completion bug: while an engine was already
in its error state, a still-true watchdog, abort, or SPAD-error condition kept
overriding the error-state transition. The CNM, CNN, KV, and SFU FSMs now gate
those error detectors off once they enter the error state, allowing the normal
terminal `done` pulse. The new watchdog/error regressions pass with the fix.

## Aggregate evidence

Command from the repository root:

```sh
env -u VCS_ARCH_OVERRIDE make -C dv/subsystem/tensor_datapath/sim cluster_regress \
  CLUSTER_TAG=multi_engine_20261023_final_fault_recovery \
  CLUSTER_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261023_final_fault_recovery \
  COMPUTE_SEEDS='20261021 20261022 20261023' \
  COMPUTE_COV_SEEDS='20261021 20261022 20261023 20261024 20261025' \
  AI_RANDOM_CASES=20 AI_SEED=20261023 \
  VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The command exited 0 with `MULTI_ENGINE_COMPUTE_CLUSTER_PASS`. VCS was
`V-2023.12-SP1_Full64`; URG was `V-2023.12-SP1`; VC Formal was
`V-2023.12-SP2`. Top `ai_smoke` passed. DMA–SPAD–CNM passed 10 UVM seeds with
warning/error/fatal counts `0/0/0`. Serial cluster formal proved 3/3 assertions
and reached 7/7 engine-dispatch covers.

The URG merge contains 29 test instances and every one of the 23 `rtl/compute`
module definitions. Twenty modules have executable code bins; three wiring
wrappers have no applicable line/condition/FSM/branch bins. Merged compute
module-definition line/condition/FSM/branch coverage is
**92.17% / 88.59% / 52.00% / 86.00%**. The separate five-seed top-only module
view is **74.99% / 64.87% / 30.93% / 61.36%**. These are raw code-bin
percentages, not functional feature completion percentages. The merged report
is under
`/tmp/nmaforge_compute_cluster_multi_engine_20261023_final_fault_recovery/dut_coverage/urg/`.

## Remaining verification work

- Cross combinations of multiple CNM, matrix, and SFU faults with abort and
  reset; late-progress fault injection is still limited.
- Broader CNN/KV stride, address-boundary, and long-transaction error/reset
  combinations.
- Full-domain FP parity-to-writeback formal proof and residual FP interactions.
- Simultaneous engine dispatch is not supported by the current serial command
  path. The formal run proves serial ownership/dispatch properties only.
- Remaining raw code bins and project-wide UVM, formal, LEC, DFT, and signoff
  closure.

See [compute-engine status](COMPUTE_ENGINE_STATUS.md) for per-module metrics
and [verification matrix](../../dv/VERIFICATION_MATRIX.md) for the broader DV
frontier.
