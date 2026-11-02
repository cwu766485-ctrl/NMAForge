# Compute Cluster Conv reset accepted-write prefix — R170

**Run ID:** `R170-CONV-RESET-PREFIX-VCS-BLOCKED-20261102`
**Test ID:** `TC-CL-R170-CONV-RESET-WRITE-PREFIX`
**Result:** `BLOCKED_ENV` — VCS did not acquire a compile license; HDL elaboration and simulation did not start.
**Product RTL/SPEC:** unchanged.

## Change under review

Test commit `a702091b5db8937061f6b766ec7e1d60e6e5f2f2` (tree `041ffab053bcfb6fc83d6d34c61d5e60445b1c8c`) adds a real-top Conv reset cut point to `ai_compute_cluster_e2e_seq.svh` and makes its PASS marker mandatory in `uvm_compute_cluster_regress`.

The directed descriptor uses a legal 6×6 input and 3×3 unit kernel, producing a row-major 4×4 output. The sequence independently calculates all 16 Golden values, seeds destination and completion sentinels, asserts reset after an accepted non-empty proper output prefix, and checks prefix data/address, untouched suffix, old completion suppression, post-reset quiet, and a full 16-word new-epoch Golden recovery. A six-bin focused group is declared. This is one intended legal fault/phase/reset point; it does not close the broader `CL-COV-006` cross.

The corresponding checker evidence was **not observed** because VCS could not enter compilation. Coverage is therefore `NOT_RUN`; no simulation seed ran and no PASS marker or coverage database was produced.

## Commands and environment result

The compile/regression command was:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r170_conv_reset_3seed \
COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

VCS `V-2023.12-SP1_Full64` reported `Cannot connect to the license server` and exited before HDL compilation. A second attempt added `-licwait 1`; VCS entered its license queue and was stopped after the server remained unreachable. The license variable was configured in the environment; its value is intentionally omitted. Diagnostic log: `/tmp/nmaforge_r170_conv_reset_3seed/compile.log`.

No UVM seed, Golden/Memory Image scoreboard, functional bin, or checker result is claimed. The ordinary three-seed UVM target must be rerun from this exact source commit once VCS license service is reachable. Top Smoke and checker mutations were not rerun because this attempt did not alter RTL or checker implementations.

## Requirement disposition

| Requirement | Existing disposition | R170 testpoint status | Evidence |
|---|---|---|---|
| `REQ-CL-017/018/019/027` | `PARTIAL` | `NOT_RUN` (`BLOCKED_ENV` before elaboration) | This report and compile log |
| `REQ-PC-006/007` | `PARTIAL` | `NOT_RUN` (`BLOCKED_ENV` before elaboration) | This report and compile log |

The 38-row disposition remains **24 PASS-SCOPED / 14 PARTIAL**. Declared coverage totals and `CL-DV-v1.0` decision do not change: **HOLD**.

