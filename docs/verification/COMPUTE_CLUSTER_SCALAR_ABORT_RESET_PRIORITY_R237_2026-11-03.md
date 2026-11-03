# Scalar INT8 Abort/Reset Priority Replay — R237

**Disposition:** PASS for the named Scalar INT8 core reset-priority and recovery point. Compute Cluster v1.0 remains **HOLD**.

## Fixed identity and tools

- Tested commit: local `087f5b84d9871bd79127bcf66e351ec673ec9dd5`; GitHub same-tree commit `89ce56bc16545bbcdcb29c93209adb84af9a6a72`.
- Test tree: `f2eeabb08053dd2aed3d494b68b9571be7efb52f`.
- RTL source blob: `1a050cc42213d074c175c88a495b123d6397d6b5`; no product RTL or SPEC change.
- Testbench blob: `6a73f837e1823b5cd53f184619e168a6a6bcb7bb`.
- Makefile blob: `1f372ca22b1dd32462da6fc273f30a865b239f0f`.
- Tools: Synopsys VCS `V-2023.12-SP1_Full64`; Python `3.12.13`.
- Run ID: `R237-SCALAR-ABORT-RESET-PRIORITY-CLEAN-3S-20261103`.
- Seeds: `20261025`, `20261026`, `20261027`.

## Result

The clean-worktree `numeric-regress` target passes all three seeds. In the reset case, a legal Scalar INT8 VDOT reaches `ST_CALC` only after both accepted SPAD reads return. The test asserts Abort and active-low Reset together on the sampling edge, verifies Reset clears the active task and leaves the destination sentinel unchanged, checks four quiet cycles after reset release, then runs a new VDOT and compares its output and memory image with the independent Golden value `70`.

Each run also retains R236's simultaneous Abort/expired-Watchdog test (`ERR_ABORT=3`, one completion pulse, no output writes) and all 13 prior numeric vectors.

| Seed | Numeric Golden | Abort/Watchdog priority | Abort/Reset priority | Recovery Golden | Compile diagnostics |
|---|---:|---|---|---:|---|
| `20261025` | 13/13 + recovery | PASS | Reset wins; no old completion | 70/70 | No `Warning-` / `Error-` / `[TFIPC]` |
| `20261026` | 13/13 + recovery | PASS | Reset wins; no old completion | 70/70 | No `Warning-` / `Error-` / `[TFIPC]` |
| `20261027` | 13/13 + recovery | PASS | Reset wins; no old completion | 70/70 | No `Warning-` / `Error-` / `[TFIPC]` |

The Make target now requires both priority markers and the 14-case total, so omitting either directed check fails the regression.

## Reproduction

Run from a clean detached worktree at `087f5b84d9871bd79127bcf66e351ec673ec9dd5`:

```sh
for seed in 20261025 20261026 20261027; do
  make -C dv/block/compute/int8/sim numeric-regress \
    SEED="$seed" \
    OUT="/tmp/nmaforge_r237_clean_$seed" \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
    PYTHON=python3.12
done
```

Clean logs and generated vectors are archived outside the repository at `/tmp/nmaforge_r237_scalar_abort_reset_clean_evidence.tar.gz`, SHA-256 `c538ac23e82dbdc3ccfd0578d1cd01101b86738303162cd4b8f832fd70851b88`.

| Seed | Compile log SHA-256 | Run log SHA-256 |
|---|---|---|
| `20261025` | `b43b2ef0b218f5705902032fba30a40b1be2e56efe4f33a66d5cbd5db6d42332` | `0f90867febf1ddfe8916dda8fde7214643a1469ff92db03e98b181bf0ba89102` |
| `20261026` | `84221fac9566e5987d58516b23fbd65fe747e7e59bcaea9972d173422614e282` | `830beae17555e987c191d224e75b24ce6f6a3d755954d709aa5f24c780b426fb` |
| `20261027` | `727a06c9836f17f1cb722c9f72e5ea179a11d88df36c2be3907553ad7f80b586` | `45900e7717f281e884b514a178ce5411aa2b73bcc578794323c1b8587208f83e` |

## Scope and sign-off impact

This closes a Scalar core-level simultaneous Abort/Reset priority point and verifies a fresh local VDOT after reset. It does not cover reset with a SPAD response outstanding, other engines, actual CMDQ/CPLQ publication, cross-engine owner arbitration, or the full fault × phase × reset/backpressure cross. `REQ-CL-013`, `REQ-CL-017`, and `REQ-CL-019` remain `PARTIAL`; no 38-row disposition changes. The overall candidate remains 24 `PASS-SCOPED` / 14 `PARTIAL`, **HOLD**.
