# Scalar INT8 Abort/Watchdog Priority Replay — R236

**Disposition:** PASS for the named Scalar INT8 core priority testpoint; Compute Cluster v1.0 remains **HOLD**.

## Fixed identity and tools

- Test commit: local `77c2383b981e2788f6b0ff1b07f1368e9b97c815`; GitHub same-tree commit `58b8317528378df67d78a2a1f06b6209746dcedb`.
- Test tree: `9d36fae00643afc32f5cba88d3cfeaf539d70337`.
- DUT RTL source identity: blob `1a050cc42213d074c175c88a495b123d6397d6b5`; RTL and SPEC content match candidate `c5755985b0e5b1e1a850122ece983a37be112272` with no R236 product change.
- Testbench blob: `d4a21c31fcabe7774526cc2bbfcf2ec6ef10b098`.
- Tools: Synopsys VCS `V-2023.12-SP1_Full64`; Python `3.12.13`.
- Run ID: `R236-SCALAR-ABORT-WATCHDOG-PRIORITY-CLEAN-3S-20261103`.
- Seeds: `20261025`, `20261026`, `20261027`.

## Result

The clean-worktree `numeric-regress` target passed on all three seeds. Each run checks the existing 13 independent numeric vectors and the new same-sampling-edge priority point. The directed case launches a legal VDOT descriptor, uses deterministic one-cycle behavioral SPAD responses, and asserts Abort when the core is in `ST_CALC` with its watchdog expired.

| Seed | Numeric Golden | Abort/Watchdog | Accepted/returned reads | Accepted writes | Completion pulses |
|---|---:|---|---:|---:|---:|
| `20261025` | 13/13 | Abort wins; `ERR_ABORT=3` | 2/2 | 0 | 1 |
| `20261026` | 13/13 | Abort wins; `ERR_ABORT=3` | 2/2 | 0 | 1 |
| `20261027` | 13/13 | Abort wins; `ERR_ABORT=3` | 2/2 | 0 | 1 |

The checker confirms `dut.watchdog_expired` is high before the sampling edge, both reads have returned with no response pending, no output element is committed, the error completion is exactly one pulse, and the error code remains Abort. Compile logs contain no VCS `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Reproduction

Run from a clean detached worktree at `77c2383b981e2788f6b0ff1b07f1368e9b97c815`:

```sh
for seed in 20261025 20261026 20261027; do
  make -C dv/block/compute/int8/sim numeric-regress \
    SEED="$seed" \
    OUT="/tmp/nmaforge_r236_clean_$seed" \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
    PYTHON=python3.12
done
```

Logs and generated vectors are archived outside the repository at `/tmp/nmaforge_r236_scalar_abort_watchdog_clean_evidence.tar.gz`, SHA-256 `28ad641d08dd0490d38931c7dba4fc3d4e257ce9fb042a2d1622933fe13abcb9`.

| Seed | Compile log SHA-256 | Run log SHA-256 |
|---|---|---|
| `20261025` | `0a2749103c1d4ab125371838dc0777167e661a9f42c589d46c5cac40185d7714` | `d9b5091c525790a91a74dc4c3bac02c8ad920ce39a2281185915fb40b8331173` |
| `20261026` | `9c51c2fe7152fecbea1f37d38c5bbace87e471413d2c029079496cff3c5fa0d6` | `513bcc1ea1cf65f5d7d6e23eb3023498a810a4ab58df38891a5277a89185fe11` |
| `20261027` | `082c6fdab5c9ed49614ac0feb564ba9b93727cd5f4d9fb5a289efc858a076f9f` | `2a7ec53882db752a4bd52e4493647172600527eb6833e837f2d31e148be2c12b` |

## Scope and sign-off impact

This closes the previously untested Scalar INT8 Abort-over-Watchdog simultaneous-priority point at core scope. It does not test the real CMDQ/completion path, external error ownership under concurrent engines, other error pairs or phases, Abort/Reset coincidence, or full fault × phase × reset/backpressure coverage. It does not add a top-level functional-covergroup bin. `REQ-CL-013`, `REQ-CL-017`, and `REQ-CL-027` therefore remain `PARTIAL`; the 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
