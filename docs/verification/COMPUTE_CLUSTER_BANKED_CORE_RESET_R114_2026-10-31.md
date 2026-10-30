# Compute Cluster banked/core reset epoch — R114

**Run ID:** `SPAD-BANKED-CORE-RESET-R114-3S`  
**Exact published code/test SHA:** `4797a7710a18670d820f8f3815959091f9636e75`  
**Product RTL/SPEC baseline:** R99 `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; R114 changes the subsystem UVM test and Make target only.  
**Target:** in-repository `ai_accel_memory_fabric`, production `ai_spad_arbiter`, and registered four-bank SPAD.  
**Tools:** VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`.  
**Seeds:** `20261025`, `20261026`, `20261027`.  
**Result:** PASS for the selected fabric's simultaneous Core/Banked response and shared-reset epoch point.

## Test and checker result

Each seed starts from a coordinated reset epoch and issues simultaneous legal reads at Core address `0x17c` and Banked row `0x100`. Reset restores the arbiter's Core-first round-robin state. The test checks the Core grant, then accepts the Banked request on the next edge while checking the earlier Core response's tag, exclusive ownership, no-error status, and independent initialized-memory Golden word.

The test asserts the shared subsystem reset while the accepted Banked response is pending in the fabric pipeline. It waits for reset acknowledgement, checks that all fabric response-valid owners are low during reset, releases reset, and checks a four-cycle quiet interval for stale-epoch leakage. It then reissues the simultaneous pair and checks both Core and Banked tags and Golden data after recovery. The UVM clients are testbench-driven; the scenario exercises the production fabric, arbiter, demultiplexer, and SPAD but does not issue a production Matrix-engine transaction.

The exact-SHA clean-worktree three-seed regression exits `0`. Each seed prints `[SPAD_BANKED_CORE_RESET_EPOCH_PASS]` and has UVM warning/error/fatal counts `0/0/0`. URG reports the focused `banked_core_reset_epoch_cg` at **100.00%**. Merged assertion evidence is:

| Assertion | Attempts | Real successes | Failures | Incomplete |
|---|---:|---:|---:|---:|
| `ap_core_response_tag` | 471 | 3 | 0 | 0 |
| `ap_banked_response_tag` | 471 | 3 | 0 | 0 |
| `ap_single_response_owner` | 471 | 441 | 0 | 0 |

VCS emitted platform support notices for Rocky Linux 8.10 and the WSL2 6.6.87.2 kernel; VCS and URG completed successfully. These results are a named testpoint, not global functional-coverage closure.

## Reproduction

From a detached clean worktree at the published SHA:

```sh
env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C /tmp/nmaforge_r114_published_4797_clean/dv/subsystem/dma_spad/sim \
  subsystem_banked_core_reset_regress \
  BANKED_CORE_RESET_OUT=/tmp/nmaforge_r114_published_4797_replay \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

## Evidence paths and hashes

Generated simulation and URG files are outside the repository under `/tmp/nmaforge_r114_published_4797_replay/`.

| Artifact | SHA-256 |
|---|---|
| Driver log (target exit `0`) | `878ec20db7698c736c1ca8717f584a9f858250db6bba2d7be29b70dca3b6eff4` |
| `compile.log` | `bfe4a57cd0d617d0c81fcaf857d6a835fc429f9fd704a83789ccf8355335b16b` |
| `seed_20261025/run.log` | `e93b7e489422e30cd2e95bbb9302c6664b81722d728d3c94cc6e060c3f265df0` |
| `seed_20261026/run.log` | `97f7d2ba54f1488aa3cde2430017ec56ea5aa6c5b616e6068a458794d69761e8` |
| `seed_20261027/run.log` | `fd667231ae8b9c57b560bcf9b6f77acc5ba01007aa6b03c352cc141bf9aacfff` |
| `urg/asserts.html` | `2f6b7176968c6976f8db16018fc957cae6656c1dfb21f5fa5278f47fa25bf018` |
| `urg/groups.html` | `e84a2771fb2cdc87019ca1bf909fc7fd5cfaa299c0e152c3cc985b2450393c0c` |
| `urg/dashboard.html` | `40bb8e6246c2c54e4d55171b20b52724f2bae9b94d6cf2c7551554103732a4c6` |

## Scope and disposition

This extends the selected `ai_accel_memory_fabric` reset/owner evidence with a simultaneous scalar/Core and Matrix-like Banked request pair. It does not cover a production Matrix engine, AXI external-fabric reset semantics, the full seven-engine contention space, or the broader legal Engine × Fault × Phase × Reset and downstream-backpressure crosses. No requirement status is promoted: `REQ-CL-018` and `REQ-PC-007` remain **PARTIAL**, the 38-row RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
