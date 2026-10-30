# Compute Cluster final published HEAD subsystem replay — R116

**Run ID:** `DMA-SPAD-SUBSYSTEM-REGRESS-R116-3S`  
**Exact clean published HEAD:** `e7eb378e64f9dad48edaba597fa6be9eb00b8416`  
**Product RTL / UVM test content:** unchanged from the R114 code/test tree `4797a7710a18670d820f8f3815959091f9636e75`; intervening commits are documentation only.  
**Tools:** Synopsys VCS and URG `V-2023.12-SP1`; UVM 1.2.  
**Seeds:** `12345`, `987654`, `20261014`.  
**Result:** PASS for the default DMA/SPAD/CNM subsystem regression on all three seeds.

## Command and result

The replay ran in detached clean worktree `/tmp/nmaforge_r114_final_5bc52_regress`:

```sh
env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make subsystem_regress \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The target exited `0`, completed all three seeds, generated a merged URG report, and each seed ended with `TEST_DONE` and UVM severity `WARNING/ERROR/FATAL = 0/0/0`. Covered scenarios include DMA/SPAD data integrity, DMA/CNM contention, CNM GEMV shape cases, reset cancellation/recovery, parity and protection cases, and a checked 16-cycle AXI `RREADY` stall.

## Coverage disposition

The merged URG dashboard reports mixed testbench/UVM/DUT totals: line `72.11%`, condition `58.49%`, toggle `40.35%`, FSM `54.82%`, branch `61.86%`, assertions `90.32%`, and functional groups `79.74%`. These are not DUT-only or Compute Cluster-wide sign-off percentages.

The 31 assertion properties have 28 successes, zero failures and zero incomplete attempts. Two UVM RAL internal properties have no attempts. `ap_banked_response_tag` is not attempted in this default regression; its real non-vacuous checks are separately recorded in R110–R114, including the R114 reset/owner point. The 79.74% aggregate functional-group score includes three banked-owner/reset groups not invoked by this default target. `dma_rready_stall_cg` is 55.56%: this target samples the 16-cycle profile, while its declared 64- and 300-cycle bins are not part of this run. Those are real uncovered scenarios, not waived bins. Dedicated R112–R114 runs remain separately reported and are not silently merged into this dashboard.

Consequently, this exact-HEAD replay confirms reproducibility of the default subsystem suite but does **not** satisfy the 100% testpoint-coverage objective or close any RTM requirement. The overall disposition remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.

## Evidence paths and hashes

All generated evidence is outside Git under the clean worktree and `/tmp`:

| Artifact | SHA-256 |
|---|---|
| Driver log `/tmp/nmaforge_r114_e7eb378_subsystem_regress.log` | `1fec7de73fa34d0da83c6fe2fbbf0f5dfb8f4d31d25d73c2d5a105763096481e` |
| Seed `12345` compile log | `f456c83afadedeefed77bb267a8b157a0ff22c46d97d59535aac7f126c8d70a5` |
| Seed `987654` compile log | `ee3ae1127a23505574a6a6fcac82d4638564b6f5672c64748c82db813362f8f5` |
| Seed `20261014` compile log | `8112e331730bd9fb6c8de76b7080f7bc6cfebc00c8305b54650b5140bf438bca` |
| Seed `12345` run log | `4cd4670c175b9a779e904b3ba8f5ed9a6f7ba0771117ac08f55446f7840b5b66` |
| Seed `987654` run log | `6ba32b51bb069ded726f561c89535a23c7664638dc01969baad27ffb5b0af162` |
| Seed `20261014` run log | `5ee2a8ec7df22d980a9c24fff7ca9feecd08cd5139344ecacaae90c93cdd2c85` |
| Merged URG dashboard | `88e232b0832a785196edbe494a1055c28b9572ce87b5c70ce25db1a81a39ea35` |
| Merged URG functional groups | `6af07c68f8bf360655cd31b3f175f4d0b016c90cbbdd2e1a9da3b399bfabb32a` |
| Merged URG assertions | `31d27447955f51c214d3b3b690d7d98e209e0426b9d9b2ce5cf6333930e30a0e` |

VCS printed its existing Rocky Linux 8.10 / WSL2 platform-support notices. No test severity or target failure occurred.
