# Concurrent CNM Protection Fault, Matrix Reads, and Reset Epoch — R107

**Run IDs:** `CLUSTER-CNM-PROTECTION-RESET-OWNER-R107-3S`, `CLUSTER-MUTATION-R107-28`, `TOP-SMOKE-R107`, `TOP-RANDOM-R107-20`\
**Exact committed test SHA:** `53b40e67ac0f82d01dfc3c40ad36ce34745ea929`\
**Product RTL/SPEC:** unchanged from R99 candidate `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8.\
**Disposition:** PASS for the selected legal CNM Protection observation concurrent with Matrix activity and reset/epoch flush. This closes only the named testpoint; Compute Cluster v1.0 remains **HOLD**.

## Test intent

The production top starts a legal 16×32×64 Matrix GEMM and a legal CNM GEMV using shared SPAD. The CNM source-A address is denied by Protection. Once that denial is observed while both engines are active and Matrix has issued real accepted reads, the sequence asserts accelerator reset. It then checks both engines idle, completion tail zero, unchanged Matrix/CNM output sentinels, unchanged eight completion words, no late tagged response or owner mismatch, and an idle SPAD path. The reset supersedes the in-progress CNM fault before an error completion is committed; this point does not claim to verify a CNM error completion code.

## Reproduction

Run from `/tmp/nmaforge_r95_clean_119f184` with Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r107b_cnm_protection_reset_owner_20261030 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r107b_mut_compile_20261030 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r107b_mutations_20261030 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  > /tmp/nmaforge_r107b_mutation_make.log 2>&1

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat make ai_smoke
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

The UVM regression, mutation target, Top Smoke and seeded top run all returned exit code `0`. The UVM compile log has no `Warning-`, `Error-`, or `[TFIPC]`. Top Smoke retains its pre-existing `[LOOP-REROLL-ENABLED]` fixture warning. Its mapper precheck reports 86 descriptors and 60 tensors.

## Results

| Seed | Matrix/CNM both-busy cycles at fault | Accepted Matrix reads before reset | Scoreboard reset-dropped reads | Memory image and UVM result |
|---|---:|---:|---:|---|
| `20261025` | 2 | 26 | 11 total (baseline R106: 9) | 33,435 checked words; zero mismatch/unknown/stale/orphan; pending queues zero; UVM `0/0/0` |
| `20261026` | 2 | 26 | 11 total (baseline R106: 9) | 33,435 checked words; zero mismatch/unknown/stale/orphan; pending queues zero; UVM `0/0/0` |
| `20261027` | 2 | 26 | 11 total (baseline R106: 9) | 33,435 checked words; zero mismatch/unknown/stale/orphan; pending queues zero; UVM `0/0/0` |

The per-seed scoreboard increases `reset_dropped` from R106's 9 to 11; the two additional pending accepted reads are flushed by this new reset case. After reset, all 512 Matrix and 16 CNM destination sentinels and all eight completion words match their prelaunch values; completion tail is zero. No response counters advance after reset recovery, `stale_epoch=0`, route mismatches are zero, and the final pending ledger is empty. The full existing focused Compute Cluster group remains 100% applicable coverage; this is not whole-design coverage closure.

The exact-source passive checker-sensitivity campaign passes `28/28` named observation mutations. It is not RTL fault injection or a DUT mutation score. The merged compute UVM URG summary is 17/22 assertions with real successes, zero failure/incomplete, and two UVM RAL properties without attempts. Three compute-profile AXI assertions lack real success in this workload; the W stall-to-accept cover matches three times while AR/AW are unhit here. R102's separate behavioral AXI workload remains their evidence.

## Traceability and limits

R107 adds one legal reset/epoch point to `REQ-CL-017/018/019` and `REQ-PC-006/007`. The broad Engine × Fault × Phase × Reset matrix, all-engine reset during concurrent shared-SPAD traffic, downstream backpressure crosses, and per-engine accepted-write prefixes remain open. Partial/zero Matrix Line WSTRB remain unsupported by SPEC v1.5. No requirement is promoted: the 38-row RTM remains `24 PASS-SCOPED / 14 PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

UVM artifacts are under `/tmp/nmaforge_r107b_cnm_protection_reset_owner_20261030/`; mutation artifacts are under `/tmp/nmaforge_r107b_mutations_20261030/`. The external SHA-256 manifest is `/tmp/nmaforge_r107b_SHA256SUMS.txt` with manifest SHA-256 `70c4db95e5087bf2b98bf1985bbd96372cb6853c8d58e95cd1316fbcd4ee16fe`. Generated logs/databases remain outside Git.
