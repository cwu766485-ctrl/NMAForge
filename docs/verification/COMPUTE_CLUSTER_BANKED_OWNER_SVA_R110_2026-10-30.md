# Compute Cluster banked response owner SVA evidence — R110

**Code/test SHA:** `95864f7027ccbec22a09b0a61832c68d3ca08098` (R110, testbench/harness only).

**Product RTL/SPEC baseline:** R99 `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; unchanged by R110.

**Run ID:** `SPAD-BANKED-OWNER-R110-3S`.

**Tools:** VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

**Seeds:** `20261025`, `20261026`, `20261027`.

## Scope and result

The `dma_spad_subsystem_test` drives a Matrix-like banked read requester through the production `ai_accel_memory_fabric`, `ai_spad_arbiter`, protection gate, and registered four-bank SPAD response path. The requester itself is testbench stimulus; this is not a production Matrix engine transaction. The test checks an aligned read at `0x100`, grant client 3, response owner tag 3, absence of simultaneous responses for other clients, and all four returned bank words against the independent host-write image. It holds the run phase through the SVA sampling edge.

All three seeds emit `SPAD_BANKED_OWNER_PASS`; each reports UVM warning/error/fatal `0/0/0`. Merged URG reports `ap_banked_response_tag`: **426 attempts, 3 real successes, 0 failures, 0 incomplete**. The target now hard-fails if the assertion has no real success or any failure/incomplete attempt. The compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

The same code/test SHA also passes the selected `ai_accel_memory_fabric` reset regression on three seeds: accepted external DMA read and pending accepted CNM SPAD response are flushed, reset groups reach 3/3 at 100%, and post-reset DMA/CNM work recovers. The regular DMA/SPAD/CNM subsystem regression at seed `20261025` exits 0 with UVM severity `0/0/0`. These runs check harness compatibility and do not expand R110's banked test into an engine/fault cross.

## Reproduction

From `dv/subsystem/dma_spad/sim`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
  make subsystem_banked_owner_regress \
  BANKED_OWNER_OUT=/tmp/nmaforge_r110_bank_owner_20261030_final \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Additional same-SHA gates:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
  make subsystem_memory_fabric_reset_regress \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r110_clean_reset_95864f7 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
  make subsystem_run SEED=20261025 SIMV=simv_r110_clean \
  COV_DIR=/tmp/nmaforge_r110_clean_subsystem_95864f7/coverage.vdb \
  RUN_LOG=/tmp/nmaforge_r110_clean_subsystem_95864f7/run.log \
  COMPILE_LOG=/tmp/nmaforge_r110_clean_subsystem_95864f7/compile.log
```

The focused gate exited 0 at clean detached worktree `/tmp/nmaforge_r95_clean_119f184`, HEAD `95864f7027ccbec22a09b0a61832c68d3ca08098`. The retained focused output is `/tmp/nmaforge_r110_bank_owner_20261030_final/`; the report records hashes for compile, URG, and all three seed logs. Reset and regular subsystem artifacts are under the paths in the commands above.

## Evidence hashes

| Artifact | SHA-256 |
|---|---|
| Focused compile log | `d4c30e44da612c388b17435f288a29ec6882ed6155126be3a6a0f7938f3b8f58` |
| URG `asserts.html` | `c16955aa7f4c9037b8615837ee219b640dcddf218e8c88efec560d627c470ee8` |
| URG `dashboard.html` | `e501fd4db796b8eb3182a85a69f3ae4a27e75168c0118117065f53e49466cc69` |
| Seed `20261025` run log | `263fcd31570f9b3af1f9177e00e34b8570a2a663bc582cfd823cdd8c92ab96e6` |
| Seed `20261026` run log | `4652db29e7e2ea0afc7fa44c0b39611d7dbead45838609e8b6055f9710f926d2` |
| Seed `20261027` run log | `c37935c3470ede0f87b84b22b75556464cc1c9e7903199a9a86f8029e459fb5b` |
| Reset URG `groups.html` | `d61145a001f29ee99a03d4a77af0d98ca3b5a59f01fe3f43c9c6d552e4e3c1a2` |
| Reset compile log | `958ee75d989fb84afec2da190426065d2ddfffe166f6bfdedd85c48d165c4c00` |
| Regular subsystem compile log | `cc8330e8d5ecada67588b8fdbb441112feb6e9b43de877521ec1c60ff8f43aaf` |
| Regular subsystem run log | `aa35e21c8d8cb62e024d60ea49ac9b07ffd2a652cfe7309a30aca909b57515c6` |

R110 closes the `ap_banked_response_tag` non-vacuity point for this checked-in fabric harness. It does not close `REQ-PC-007`, `CL-COV-002`, or `CL-COV-006`: production Matrix execution, banked response under real multi-requester contention/backpressure, and broader legal fault × phase × reset crosses remain open. The overall RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
