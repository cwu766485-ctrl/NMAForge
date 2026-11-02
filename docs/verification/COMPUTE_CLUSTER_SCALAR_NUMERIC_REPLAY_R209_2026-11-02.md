# Scalar INT8 numeric replay after R208 — R209

**Candidate code/test SHA:** `30378888dadc21a6fd2dace0a125ee78fd20d45b`  
**Tree:** `412ec3700cd79b6c3f5b64e4f0f37691e2f679d8`  
**Run ID:** `R209-SCALAR-INT8-NUMERIC-R208-REPLAY-3S-20261102`  
**Seeds:** `20261102`, `20261103`, `20261104`  
**Environment:** detached clean worktree `/tmp/nmaforge_r208_clean`; VCS `V-2023.12-SP1_Full64`.

## Result

The existing Scalar INT8 independent-Golden regression was replayed after the R208 watchdog retirement fix. All three seeds pass `make numeric-regress`. Each seed checks 13 vectors (11 VDOT, one GEMV, one GEMM), 20 output words and 152 registered read responses. Every run observes both read and write stalls; the request-stability monitor, output-address/data checker and complete modeled SPAD image all pass.

| Seed | Vector file SHA-256 | Run log SHA-256 | Read stalls | Write stalls |
|---|---|---|---:|---:|
| `20261102` | `973cf4f77b4e9d6667294fa352355d10867ca5c640d10f484a147c93f18b35a6` | `a077fa3e4f7af633ace3c0ccf1d6668eebf6c6466428ff183fd725b985c84e4b` | 53 | 9 |
| `20261103` | `729e1257257e250e5d112a7683a8db28b58536903f5a5796f7fd45fbf114dd41` | `24edecb2560d092bfcb10e8094bc2a5c1c63d5fed41f25dc0412a632346b5011` | 42 | 3 |
| `20261104` | `e9800fba9f58e6ebc1923b54f89906f220b0d1ea01031e277ce0c83bdfebc1d2` | `a35546b17f7f54dbd2bc369266b3d43a27161d6bcbc27aefe904c51be40f7bd2` | 28 | 6 |

All three seeds report `cases=13`, `opcode_bins={vdot:11,gemv:1,gemm:1}`, shift bins `{0,1,31,other}={7,1,1,4}`, activation bins `{identity,ReLU,ReLU6}={9,2,2}`, bias off/on `{6,7}`, and 152 responses. Commands:

```sh
cd dv/block/compute/int8/sim
make numeric-regress OUT=/tmp/nmaforge_scalar_int8_numeric_r209_20261102 SEED=20261102
make numeric-regress OUT=/tmp/nmaforge_scalar_int8_numeric_r209_20261103 SEED=20261103
make numeric-regress OUT=/tmp/nmaforge_scalar_int8_numeric_r209_20261104 SEED=20261104
```

The run logs and generated vectors remain under `/tmp`; no generated simulator data is checked in. This is a focused numeric no-regression result only. It does not close Scalar descriptor/shape coverage, legacy Conv across its full legal range, or the integrated fault × phase × reset matrix. `REQ-CL-020` remains `PARTIAL`; global disposition and `CL-DV-v1.0` remain `24 PASS-SCOPED / 14 PARTIAL` and **HOLD**.
