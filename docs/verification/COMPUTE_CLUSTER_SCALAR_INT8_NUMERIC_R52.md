# Scalar INT8 Numeric Testpoint Closure — R52

**Date:** 2026-10-30  
**Run ID:** `SCALAR-INT8-NUM-LEGAL-3S-DDE7806`  
**Product RTL identity:** selected candidate `6848a414eaeaa05cf9e1411cf55d9d27333208a6`; the Scalar INT8 RTL files in the test checkout are byte-identical to this candidate.  
**Test commit:** `dde780660e40cb6accff5a53c2e6f8163b325839`  
**Checkout:** detached clean worktree `/tmp/nmaforge_scalar_legal_clean_dde7806`  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; Python `3.12.13`

## Result

**PASS for the declared legal Scalar INT8 numeric testpoint subset.** Three clean-worktree seeds (`20261030`, `20261025`, `20261026`) each passed 13 independent Python-Golden cases. The test checked 60 output words across the three seeds and compared every expected output address and word against the simulated SPAD image. Each seed drained its single-outstanding read response, checked the result and write count, enforced request stability while stalled, and hit all declared required opcode, shift, activation, bias, read-stall and write-stall bins. No reserved activation encoding was generated or counted. No product RTL changed.

| Testpoint group | Required/observed scope per seed |
|---|---|
| Opcode | VDOT 11, GEMV 1, GEMM 1; all three required bins hit |
| Shift | 0, 1, 31 and other legal shifts; negative arithmetic-shift and shift-31 boundary cases |
| Activation | Identity (0), ReLU (1), ReLU6 (2); all assigned values hit |
| Bias | Disabled and enabled; signed bias-before-dot/shift ordering |
| Arithmetic | Signed lane ordering, maximum INT8 product, positive/negative INT32 saturation, ReLU negative clamp, ReLU6 upper/lower clamp |
| SPAD/checker | 20 output words per seed; exact address/data image, write count, final result, response drain, request stability, and nonzero read/write stalls |

These are directed declared testpoint bins, **not URG code coverage and not 100% REQ-CL-020 closure**. Legacy Conv address generation, all legal opcode/shape combinations, protection/parity injection, Abort/Reset, and broader fault crosses remain outside this run. Therefore `REQ-CL-020` remains PARTIAL under `CL-COV-003`; this run only supplies the legal VDOT/GEMV/GEMM common-arithmetic evidence for `OPEN-NUM-01`.

## Reproduction

Run each command from `/tmp/nmaforge_scalar_legal_clean_dde7806`:

```sh
make -C dv/block/compute/int8/sim numeric-regress \
  SEED=20261030 OUT=/tmp/nmaforge_scalar_legal_dde7806_s20261030
make -C dv/block/compute/int8/sim numeric-regress \
  SEED=20261025 OUT=/tmp/nmaforge_scalar_legal_dde7806_s20261025
make -C dv/block/compute/int8/sim numeric-regress \
  SEED=20261026 OUT=/tmp/nmaforge_scalar_legal_dde7806_s20261026
```

| Seed | Vector SHA-256 | Cases | Output words | Read stalls | Write stalls | Responses | Result |
|---:|---|---:|---:|---:|---:|---:|---|
| 20261030 | `bd2a5aceac5f23014d5f05fe37e4aaf597a1a99e7a8c9130091922109a1622dd` | 13 | 20 | 62 | 15 | 152 | PASS |
| 20261025 | `21099a49ae3249badafa9dc4bc30e390785197c9d1e5ea863b50515705881d92` | 13 | 20 | 52 | 1 | 152 | PASS |
| 20261026 | `88f3104a02e1db0f8c17f09e2f30899125bf5ae0e8e2188b8388a4d202da86e7` | 13 | 20 | 60 | 12 | 152 | PASS |

Each run emitted `SCALAR_INT8_NUMERIC_PASS cases=13 opcode_bins={vdot:11,gemv:1,gemm:1} shift_bins={0:7,1:1,31:1,other:4} activation_bins={none:9,relu:2,relu6:2} bias={off:6,on:7}` and passed the Makefile gate. The required read/write stall counts were nonzero on every seed. Compile logs contain no `Warning-`, `Error-`, `[TFIPC]`, or `Fatal` diagnostics. Vectors and logs are retained under `/tmp/nmaforge_scalar_legal_dde7806_s<seed>/`; generated simulator files remain outside Git.

R52 supersedes R51. R51 is retained as historical exploratory evidence only because its testpoint set required a stimulus for unassigned activation encoding `3`; its PASS marker is excluded from compliance and coverage claims. See [R51 disposition](COMPUTE_CLUSTER_SCALAR_INT8_NUMERIC_R51.md).
