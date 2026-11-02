# Scalar INT8 numeric boundary clean-source replay — R175

## Identity

- Run ID: `R175-SCALAR-INT8-NUMERIC-3S-20261102`
- Test ID: `TC-CL-R175-SCALAR-INT8-NUMERIC`
- Fixed source/test SHA: `8a2d5f85add54f81019df1a8d6a29ad08bbe88d6`
- Source tree: `9701bcaa7417c0cb7babdeab4996d6714cbbf04f`
- Tools: Python 3.12 and Synopsys VCS `V-2023.12-SP1_Full64`
- Result: PASS for the standalone Scalar INT8 core's defined VDOT/GEMV/GEMM arithmetic contract.

## Reproduction and results

```sh
make -C dv/block/compute/int8/sim numeric-regress SEED=20261025 OUT=/tmp/nmaforge_r175_scalar_int8_20261025_8a2d5f VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1'
make -C dv/block/compute/int8/sim numeric-regress SEED=20261026 OUT=/tmp/nmaforge_r175_scalar_int8_20261026_8a2d5f VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1'
make -C dv/block/compute/int8/sim numeric-regress SEED=20261027 OUT=/tmp/nmaforge_r175_scalar_int8_20261027_8a2d5f VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1'
```

All three Make invocations exit 0 with `SCALAR_INT8_NUMERIC_PASS cases=13`. Each run checks 11 VDOT, 1 GEMV, and 1 GEMM cases against the independent software model, for 20 checked output words and 152 accepted read responses. The test also checks write addresses/data, read/write request stability during stalls, and that both read and write backpressure occur.

| Seed | Shift bins `{0,1,31,other}` | Activation bins `{identity,ReLU,ReLU6}` | Bias `{off,on}` | Read/write stalls | Vector SHA-256 | Run-log SHA-256 |
|---:|---|---|---:|---:|---|---|
| `20261025` | `{7,1,1,4}` | `{9,2,2}` | `{6,7}` | `52/1` | `21099a49ae3249badafa9dc4bc30e390785197c9d1e5ea863b50515705881d92` | `8f36d26f2a43f2d35ed882f427a288d20e9c62ba1495470e6debd55d9b5a84ba` |
| `20261026` | `{7,1,1,4}` | `{9,2,2}` | `{6,7}` | `60/12` | `88f3104a02e1db0f8c17f09e2f30899125bf5ae0e8e2188b8388a4d202da86e7` | `22fc5a94c1ad3811396d77b6e42ed60189989bbd15f2ba9833093b6cc6c96d21` |
| `20261027` | `{7,1,1,4}` | `{9,2,2}` | `{6,7}` | `39/10` | `a0206403e7ee435d10773574e0a4b8a7d70cf62beaed6f74368914af7bc8d23b` | `89a56c26c1e9dca11a6b2a9ef26a0fe0a56ef9b23842c25eb3bac9b68b27aa34` |

Directed cases include signed lane order, negative arithmetic shift, maximum INT8 products, shift 31, positive and negative saturation, ReLU and ReLU6 lower/upper clamps, and bias-before-shift ordering. Seeded cases add K=17 VDOT, GEMV M=3/K=5, and GEMM M=2/N=3/K=4. All compile logs are free of `Warning-`, `Error-`, and `[TFIPC]` diagnostics.

Logs, generated vectors, and compile logs are archived in `/tmp/nmaforge_r175_scalar_int8_8a2d5f.tar.gz` (SHA-256 `65bc5a3c249af5cb83e20f686a538541331b8ef6b720f7997c10d32e53856521`); `RUN_MANIFEST.md` and `LOG_SHA256SUMS` are included.

## Requirement disposition

| Requirement | Status | Checker and evidence | Disposition |
|---|---|---|---|
| `REQ-CL-020` | `PARTIAL` | Independent signed 64-bit arithmetic Golden, accepted-output address/data checker, and request-stability monitor; `R175-SCALAR-INT8-NUMERIC-3S-20261102`, seeds `20261025/26/27` | Reconfirms the defined VDOT/GEMV/GEMM arithmetic boundaries. Legacy Conv, wider opcode/shape/address coverage, and the full fault/phase matrix remain outside this run; no requirement is promoted. |

This run validates the standalone core with a behavioral SPAD. It does not establish top-level CMDQ dispatch or close the full `REQ-CL-020`/`CL-COV-003` scope. Overall RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
