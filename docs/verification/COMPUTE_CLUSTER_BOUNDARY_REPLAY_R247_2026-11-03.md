# Compute Cluster Descriptor and Scalar INT8 Boundary Replay — R247

**Result: PASS for both named gates.** Tests ran in a detached clean worktree whose tree `93118f724e0f5dc0724e165ee4a83c6fc53103ff` exactly matches published GitHub `main` commit `be7ec4aeaff3d4a75e504809ba70327dc9ec5bbf`. Tool versions: VCS `V-2023.12-SP1_Full64`, Python `3.12.13`.

## Commands and results

Descriptor Validator:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/block/control/sim descriptor-validator-regress \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_r247_descriptor_20261103
```

It passes all 27 supported opcodes, the Matrix tile-pack predicate, 21 invalid-rule classes, 38/38 accepted boundary vectors, 26/26 rejected boundary vectors, and opcode-class consistency. The test explicitly reports `engine_limit_claim=0`.

Scalar INT8 numeric/core gate, repeated on three seeds:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/block/compute/int8/sim numeric-regress \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs PYTHON=python3.12 \
  SEED=20261025 OUT=/tmp/nmaforge_r247_scalar_int8_20261103_py312
```

The same command was run with seeds `20261026` and `20261027`, using output directories `/tmp/nmaforge_r247_scalar_int8_20261026` and `/tmp/nmaforge_r247_scalar_int8_20261027`. Each seed passes 14 cases, including VDOT/GEMV/GEMM, signed shifts, saturation, ReLU/ReLU6, bias, read/write stalls, Abort over simultaneous Watchdog, Reset over simultaneous Abort, and post-reset recovery Golden `70`. Each seed reports 158 responses; read/write stall observations are `52/1`, `60/12`, and `39/10` respectively.

All four VCS compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Runtime includes the informational VCS ASLR save/restore message.

## Evidence and requirement scope

Logs and generated scalar vector text are archived at `/tmp/nmaforge_r247_boundary_replay_evidence_20261103.tar.gz`, SHA-256 `c879d12dce3d435cb90db63eb14e742730b5c22c4ee21c4915b3923356905210`. Compiled VCS output is excluded.

This refreshes bounded evidence for `REQ-CL-002` and `REQ-CL-020`. It does not establish per-engine descriptor maxima, stride/alias/address-overflow contracts, full CMDQ launch legality, all engine shapes, or all fault phases. Both requirements remain `PARTIAL`; overall status remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
