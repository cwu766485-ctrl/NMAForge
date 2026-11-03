# Scalar INT8 requirement disposition — R262

**Disposition:** `REQ-CL-020` is `PASS-SCOPED` for the legal arithmetic testpoint defined by the frozen Testplan. `CL-DV-v1.0` remains **HOLD**.

## Fixed-candidate evidence

Tests ran from clean code/test SHA `724d1f0b3774643df35e14d7cb9ff0e3ad534ac8` (tree `7e168fdbc5e90725d4a924f20b7fb2b1b842d03c`) using VCS `V-2023.12-SP1_Full64` and Python 3.12.13.

The Scalar INT8 block target `make -C dv/block/compute/int8/sim numeric-regress` passes seeds `20261025`, `20261026`, and `20261027`, each with 14 directed/seeded cases: 12 VDOT, one GEMV, one GEMM, plus the required Abort/Watchdog priority and Reset/Abort recovery checks. Every output matches the independent signed-integer Golden. The declared arithmetic bins cover signed lane ordering, negative arithmetic shift, product extrema, shifts 0/1/31/other, positive and negative saturation, ReLU/ReLU6 bounds, bias before shift, K=17, GEMV M=3/K=5, and GEMM M=2/N=3/K=4. The direct-core runs include both read and write stalls and 158 checked responses per seed.

| Seed | Read stalls | Write stalls | Case/result |
|---|---:|---:|---|
| 20261025 | 52 | 1 | 14/14 pass; Abort wins simultaneous Watchdog; Reset wins same-edge Abort; recovery Golden 70 |
| 20261026 | 60 | 12 | 14/14 pass; same priority and recovery checks pass |
| 20261027 | 39 | 10 | 14/14 pass; same priority and recovery checks pass |

The exact-candidate R260 real-top Cluster UVM also requires and passes `CLUSTER_LEGACY_CONV_CMDQ_PASS` on all three seeds. That check fetches Scalar CMDQ opcodes `0x13/0x14/0x15`, verifies three completions, and checks all 12 output words against the independent Golden for the representative Conv1x1, im2col Conv3x3, and depthwise shapes. The full R260 memory scoreboard checks 95,043 words per seed with zero mismatch, unknown read, or stale epoch; UVM severity is `0/0/0`.

## Scope boundary

This closes the Testplan's declared Scalar INT8 arithmetic subset and its three representative legacy-Conv opcode results. It does not claim every shape, descriptor limit, alias/alignment boundary, or the full Engine × Fault × Phase cross product. Those remain under `REQ-CL-015`, `REQ-CL-017`, and `OPEN-CL-002`. No descriptor rule or product RTL was changed.

## Reproduction record

- Run ID: `R262-SCALAR-INT8-R260-CANDIDATE-3S-20261103`
- Command:

  ```sh
  for seed in 20261025 20261026 20261027; do
    VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/block/compute/int8/sim numeric-regress \
      VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs PYTHON=python3.12 \
      SEED=$seed OUT=/tmp/nmaforge_r262_scalar_int8_$seed
  done
  ```
- Logs and generated vectors: `/tmp/nmaforge_r262_scalar_int8_724d1f0_3seed_logs.tar.gz`
- Archive SHA-256: `cf723c8c28743b5089e8643f670a385fcf5730724e99291ec404446ef9d55fdd`
- Legacy-Conv real-top evidence: [R137 testpoint report](COMPUTE_CLUSTER_SCALAR_LEGACY_CONV_CMDQ_R137_2026-10-31.md); exact-candidate three-seed gate and full scoreboard: [R260 replay report](COMPUTE_CLUSTER_FINAL_CANDIDATE_REPLAY_R260_2026-11-03.md)
