# Scalar INT8 Numeric Closure — R51

**Date:** 2026-10-30

**Run ID:** `SCALAR-INT8-NUM-EDGE-3S-5B1D282`

**Product RTL identity:** candidate `6848a414eaeaa05cf9e1411cf55d9d27333208a6` (the two Scalar INT8 RTL files are byte-identical to that candidate)

**Test/SPEC commit:** `5b1d282b97d091e806b035c4a93556f5ac250c37`

**Checkout:** detached clean worktree `/tmp/nmaforge_scalar_clean_5b1d282`
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`; Python `3.12`

## Result

**PASS, scoped to the Scalar INT8 common arithmetic datapath and VDOT/GEMV/GEMM address paths.** Three clean-worktree seeds passed all 14 cases each (42/42 case executions) and checked 63 output words against an independently generated Python integer Golden and output memory image. No product RTL changed. Each seed exercised both read and write backpressure; the request payload stability check and single-outstanding read-response ledger remained clean. The focused VCS compile logs contain no `Warning-`, `Error-`, `[TFIPC]`, or `Fatal` diagnostics.

| Testpoint group | Observed bins / evidence |
|---|---|
| Opcode | VDOT 12 cases, GEMV 1, GEMM 1 per seed |
| Shift | 0, 1, 31, and other legal shifts exercised; negative arithmetic-shift result checked |
| Activation | identity, ReLU, ReLU6, and reserved encoding 3 AS-IS probe; encoding 3 remains unavailable to software |
| Bias | enabled and disabled; signed INT32 bias-before-dot/shift ordering checked |
| Numeric boundaries | signed lane order, maximum `(-128 × -128)` products, positive/negative INT32 saturation, ReLU negative clamp, ReLU6 upper/lower clamp |
| Memory/protocol | complete expected output addresses/data, write count, final result, registered responses, request held stable while stalled; both read and write stalls required by test end gate |

This is a directed testpoint-bin report, not URG code coverage or a percentage for all of REQ-CL-020. It does not exercise legacy Conv opcode address generation, all legal descriptor dimensions, all operand values, protection/parity injection, Abort, or Reset. Thus `OPEN-NUM-01` is closed for the frozen common arithmetic rules and this campaign scope; broader `REQ-CL-020` remains PARTIAL under `CL-COV-003`.

## Reproduction

From the clean worktree root, run each command separately:

```sh
make -C dv/block/compute/int8/sim numeric-regress \
  SEED=20261030 OUT=/tmp/nmaforge_scalar_int8_clean_5b1d282_s20261030
make -C dv/block/compute/int8/sim numeric-regress \
  SEED=20261025 OUT=/tmp/nmaforge_scalar_int8_clean_5b1d282_s20261025
make -C dv/block/compute/int8/sim numeric-regress \
  SEED=20261026 OUT=/tmp/nmaforge_scalar_int8_clean_5b1d282_s20261026
```

| Seed | Vector SHA-256 | Cases | Read stalls | Write stalls | Responses | Result |
|---:|---|---:|---:|---:|---:|---|
| 20261030 | `b90dc23fbd20d32f344268c276c0f2eefa6e4cd27ac290148f6fae66eb50e87b` | 14 | 62 | 15 | 154 | PASS |
| 20261025 | `743260a3575a437026dbb19f1bea21db3060a97d5d243c3b78b358e3cc9a7af6` | 14 | 54 | 1 | 154 | PASS |
| 20261026 | `83a73b01ce293ffe77a4af77d1bddb4a295c8c5a7b18275778a8296189ffd99d` | 14 | 61 | 12 | 154 | PASS |

Logs and generated vectors are under the three `/tmp/nmaforge_scalar_int8_clean_5b1d282_s<seed>/` directories. The executable, compile log and run log remain outside Git.
