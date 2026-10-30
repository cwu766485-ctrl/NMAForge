# Compute Cluster Clean Replay and Checker Sensitivity — R101

**Date:** 2026-10-30  
**Exact tested repository tree:** `94a3797dfea4d9011ab16ab4d3877244f0a6aafe`  
**Product RTL/DV/SPEC source base:** `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413` (R100 is documentation-only)  
**Disposition:** named clean replay and passive checker-sensitivity campaign PASS; overall Compute Cluster v1.0 remains HOLD.

## Tool setup

Synopsys VCS/URG `V-2023.12-SP1_Full64` was run on Rocky Linux 8.10 under WSL2. The installed tool expects a `linux64` tree, while this host reports `linux`; a temporary `/tmp/nmaforge_vcs_linux_compat` directory maps the installed tool directories and the `linux`/`linux64` architecture names without modifying the installation. The successful invocations use `VCS_ARCH_OVERRIDE=linux` and `VCS_HOME=/tmp/nmaforge_vcs_linux_compat`. License checkout and compilation completed.

## Three-seed real-top Compute Cluster UVM

Command:

```sh
cd dv/uvm/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
  make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r101_full_cluster_retry2_20261030 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The target exited 0 and printed `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`. All three seeds exercise the production top, parallel dispatcher, seven production engines, compute SPAD MUX, scheduler arbiter, protection, and behavioral four-bank SRAM model.

| Seed | Focused applicable group | Memory scoreboard | UVM warning/error/fatal | Run log SHA-256 |
|---:|---:|---|---:|---|
| 20261025 | 100.0% | 26,451 checked words; 0 mismatch, unknown read, stale epoch, or orphan response | 0/0/0 | `a5da9c9d7e65fb405ad90eae35e4bd62aa7dcfff90f905b87e2742f65c034b39` |
| 20261026 | 100.0% | 26,451 checked words; 0 mismatch, unknown read, stale epoch, or orphan response | 0/0/0 | `40f6ed54003cf53be6186c711fe1aa6556d76bb0160ece968339c40a451a2a3b` |
| 20261027 | 100.0% | 26,451 checked words; 0 mismatch, unknown read, stale epoch, or orphan response | 0/0/0 | `2e7a0556c6644df4e8e82a3cd66c6ef9edb8777fc68b1a18ceb5296c0764558c` |

Each seed also checked the seven-engine overlap, all-engine parity and Protection points, reset and Abort drains, completion-queue backpressure, and its named Golden/memory images. The scoreboard reported nine accepted reads intentionally discarded by reset, zero stale-epoch responses, zero orphans, and no pending client responses at completion.

The merged compute-only URG assertion report records 17/22 properties with real successes, zero failures and incomplete attempts, and two UVM RAL internals without attempts. Three top AXI properties have attempts but no real success in this compute workload (`a_ar_burst_stays_within_4k`, `a_ar_payload_stable_until_accept`, `a_aw_payload_stable_until_accept`). The W stall-to-accept cover matches three times; the AR and AW stall covers do not match. These remain separate from the dedicated AXI E2E evidence. Compile log SHA-256 is `560a7723c2c2003268e0b7f03ac04d342b652cbfa321ad25a7559a8ddd8ef929`; merged `asserts.txt` SHA-256 is `6a1087b8423970e7f9a77ad86022400835d313a16d165b7f32aaa9f427b5d704`.

## Passive checker-sensitivity mutation campaign

Command:

```sh
cd dv/uvm/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
  make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r101_mut_compile_20261030 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r101_mutations_20261030 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The target exited 0 and reported **28/28** expected detections: address, data, owner, WSTRB, completion error, write-after-error prefix, response epoch, and Done/missing-Done/duplicate-Done for each of seven engine bits. The expected Checker was identified for every injected observation mutation. These mutations perturb only passive monitor observation copies; they are checker-sensitivity evidence, not DUT RTL fault injection or an RTL mutation score. The 28 generated logs are outside Git at `/tmp/nmaforge_r101_mutations_20261030/`; their SHA-256 manifest is `/tmp/nmaforge_r101_mutations_20261030/SHA256SUMS.log` (SHA-256 `1fe827db38fd0378cdae4a5dab71c1bbe8159f28b9d1e758757b23de2140bc7f`).

## Sign-off impact and remaining gaps

R101 reproduces the complete named Compute Cluster UVM target and all 28 checker-sensitivity mutations on the post-R99 candidate. It adds no new fault/phase/reset cross and promotes no requirement. The RTM remains **24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN** and `CL-DV-v1.0` remains **HOLD**. In particular, legal Engine × Fault × Phase × Abort/Reset crosses, the broader production requester × memory-backpressure matrix, remaining per-engine descriptor boundaries, and the compute-only AXI AR/AW property no-success bins are still open or bounded by their separate evidence.
