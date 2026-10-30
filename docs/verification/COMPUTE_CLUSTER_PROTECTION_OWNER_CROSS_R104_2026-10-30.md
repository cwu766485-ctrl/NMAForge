# Matrix Protection with Concurrent CNM Owner Cross — R104

**Run IDs:** `CLUSTER-PROTECTION-OWNER-CROSS-R104-3S`, `CLUSTER-MUTATION-R104-28`  
**Exact tested code/test SHA:** `ee18cfc0363b9130cefcd4f73c58111717fa8b7a`  
**Product RTL/SPEC:** unchanged from selected R99 baseline `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; R104 changes only the UVM sequence and its Make gate.  
**Disposition:** PASS for the named concurrent Protection/response-owner point and 28 passive checker-sensitivity probes. Compute Cluster v1.0 remains **HOLD**.

## What the test exercises

The real top dispatches a legal Matrix GEMM and CNM GEMV concurrently through the shared banked scratchpad. Matrix reads its permitted operands and computes before its output write is denied by the configured Protection regions. CNM uses a separate permitted memory image and completes normally. The test checks both response tags, shared-memory admission, ordered completions, the CNM Golden output, and all Matrix destination sentinels. It does not alter RTL or relax any checker.

## Reproduction

From the isolated clean worktree `/tmp/nmaforge_r95_clean_119f184`, VCS `V-2023.12-SP1_Full64` and URG `V-2023.12-SP1`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r104_concurrent_protection_20261030 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r104_mut_compile_20261030 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r104_mutations_20261030 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

## Results

| Seed | Concurrent busy cycles, Matrix/CNM | Both busy / parallel-mode cycles | Shared banked accepts | Matrix/CNM tagged responses | Route mismatches | Memory scoreboard |
|---|---:|---:|---:|---:|---:|---|
| `20261025` | `393 / 1637` | `341 / 1752` | `154` | `128 / 1024` | `0` | 31,091 checked words; 0 mismatch, unknown read, stale epoch, or orphan |
| `20261026` | `393 / 1637` | `341 / 1752` | `154` | `128 / 1024` | `0` | 31,091 checked words; 0 mismatch, unknown read, stale epoch, or orphan |
| `20261027` | `393 / 1637` | `341 / 1752` | `154` | `128 / 1024` | `0` | 31,091 checked words; 0 mismatch, unknown read, stale epoch, or orphan |

Each seed reports Matrix task `0x07d0` Protection completion/error `0x62`, followed by CNM task `0x07d1` successful completion. All 16 CNM result words match the independent Golden image; all 512 Matrix output words retain their sentinels. UVM warning/error/fatal is `0/0/0` per seed. The applicable focused compute group reports `100.0%`; that is the named applicable testpoint group, not global functional or code coverage.

The R104 Compute Cluster URG merge reports 17/22 assertions with real successes and zero failures/incomplete. Three AXI properties have attempts but no successful antecedent in this compute-only workload; two UVM RAL properties have no attempts. Of the three AXI stall-to-accept covers, only W is hit here (3 matches); AR/AW are supplied by the separate R102 AXI-stall workload. Compile logs contain no `Warning-`, `Error-`, or `[TFIPC]`.

The checker-sensitivity target passes `28/28`: address, data, response owner, WSTRB, completion error code, write-after-error, response epoch, and Done/missing-Done/duplicate-Done for each of seven engines. Every injected passive-observation corruption is reported by its named checker. These probes test checker sensitivity; they are not synthesized RTL fault injection or an RTL mutation score. Each mutation run intentionally reports one or more UVM errors as the checker catches the corruption.

## Traceability and limits

R104 adds direct bounded evidence for the concurrent shared-SPAD Protection/error-owner point in `REQ-CL-017`, `REQ-CL-019`, `REQ-PC-006`, and `REQ-PC-007`. It does not close these broader rows. Legal Engine × Fault × Phase × Abort/Reset combinations, production requester × downstream backpressure, other error phases, and other response owners remain incomplete. No RTM disposition is promoted.

The exact focused run logs are under `/tmp/nmaforge_r104_concurrent_protection_20261030/`; mutation logs are under `/tmp/nmaforge_r104_mutations_20261030/`. The UVM compile log is `/tmp/nmaforge_r104_concurrent_protection_20261030/compile.log`, URG assertion summary is `/tmp/nmaforge_r104_concurrent_protection_20261030/urg_merged/asserts.txt`, and mutation compile log is `/tmp/nmaforge_r104_mut_compile_20261030/compile.log`. SHA-256 manifest: `/tmp/nmaforge_r104_SHA256SUMS.txt` (`33626ac46b8df5559893ef77a824bcc611c76bc3e0cab78750da5462c70b8dbb`).

