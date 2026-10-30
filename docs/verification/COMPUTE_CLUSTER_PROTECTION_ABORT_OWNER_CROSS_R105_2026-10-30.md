# Matrix Protection and CNM Abort Owner Cross — R105

**Run IDs:** `CLUSTER-PROTECTION-ABORT-OWNER-CROSS-R105-3S`, `CLUSTER-MUTATION-R105-28`  
**Exact committed test SHA:** `973b4a1291bc3d63deb96ba0720337d84cb3ae34`  
**GitHub closeout branch commit:** `1e44f1356a5b13c63b8b8da13b69c16796a85386` (tree-identical to local SHA; test-only)  
**Product RTL/SPEC:** unchanged from R99 candidate `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8.  
**Disposition:** PASS for this legal concurrent Protection/Abort owner point and the named passive checker-sensitivity campaign. Compute Cluster v1.0 remains **HOLD**.

## What the test exercises

The production top dispatches a legal Matrix GEMM and CNM GEMV concurrently through the shared banked SPAD. Matrix reads its permitted operands and computes before its output write is denied by Protection. The test then issues software Abort while CNM is still active. It checks that the Matrix Protection completion (`0x62`) is retained ahead of the CNM Abort completion (`0x32`), that both response streams remain with their owners, and that accepted memory traffic drains. Matrix output sentinels must remain unchanged; each CNM output word must be either the independent Golden value or its untouched sentinel, matching the allowed abort point.

## Reproduction

Run from the isolated clean checkout `/tmp/nmaforge_r95_clean_119f184` with VCS `V-2023.12-SP1_Full64` and URG `V-2023.12-SP1`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r105_protection_abort_owner_20261030 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r105_mut_compile_20261030 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r105_mutations_20261030 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Both Make targets returned exit code `0`. The UVM regression was run twice at this SHA; both three-seed runs completed, and the final run is the one summarized below. Neither compile log contains `Warning-`, `Error-`, or `[TFIPC]`.

## Results

| Seed | Matrix/CNM active cycles, normal Protection cross | Shared overlap / bank accepts | Normal Matrix/CNM responses | Protection→Abort overlap / bank accepts | Abort Matrix/CNM responses | Scoreboard |
|---|---:|---:|---:|---:|---:|---|
| `20261025` | `393 / 1637` | `341 / 154` | `128 / 1024` | `341 / 154` | `128 / 217` | 32,503 words checked; zero mismatch, unknown, stale-epoch, or orphan |
| `20261026` | `393 / 1637` | `341 / 154` | `128 / 1024` | `341 / 154` | `128 / 217` | 32,503 words checked; zero mismatch, unknown, stale-epoch, or orphan |
| `20261027` | `393 / 1637` | `341 / 154` | `128 / 1024` | `341 / 154` | `128 / 217` | 32,503 words checked; zero mismatch, unknown, stale-epoch, or orphan |

Every seed has both test markers. The normal case completes Matrix task `0x07d0` with Protection error `0x62`, then CNM task `0x07d1` successfully; all 16 CNM words match Golden and all 512 Matrix output sentinels remain unchanged. The Abort case completes Matrix task `0x07d2` with error `0x62`, then CNM task `0x07d3` with `ERR_ABORT=0x32`; the observed response-route mismatch count is zero. All 512 Matrix output sentinels remain unchanged and each CNM output is checked against Golden-or-untouched. UVM warning/error/fatal is `0/0/0` per seed.

The full test's focused applicable compute group is `100.0%`, which is a scoped testpoint result, not global functional or code coverage. The Matrix Line checker observed 902 full-strobe transfers and zero partial/zero-strobe transfers, consistent with SPEC v1.5's full-WSTRB-only contract. This is not evidence for unsupported partial WSTRB behavior.

The compute-only URG merge has 17/22 assertions with real successes, zero failures/incomplete, three AXI assertions without real success in this workload, two UVM RAL properties without attempts, and one of three AXI stall-to-accept cover properties matched (W); R102's dedicated behavioral AXI workload supplies AR/AW/W stall evidence. The URG output is workload-scoped.

The exact-source checker-sensitivity target passes `28/28`: address, data, response owner, WSTRB, completion error code, write-after-error, response epoch, and Done/missing-Done/duplicate-Done on each of seven engines. Each injected passive-observation corruption reached its named checker. These tests measure checker sensitivity; they are not RTL mutation score or synthesized hardware fault injection. The mutation runs intentionally have UVM errors as the expected checker response.

## Traceability and remaining limits

R105 adds bounded evidence to `REQ-CL-017`, `REQ-CL-019`, `REQ-CL-027`, `REQ-PC-006`, and `REQ-PC-007`. It does not close those broader requirements. Remaining gaps include the legal Engine × Fault × Phase × Reset space, production requesters under downstream memory backpressure, other concurrent fault/owner combinations, and broader accepted-write prefix cut points. The 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL; no status was promoted and `CL-DV-v1.0` remains **HOLD**.

UVM logs and coverage databases are under `/tmp/nmaforge_r105_protection_abort_owner_20261030/`; mutation logs are under `/tmp/nmaforge_r105_mutations_20261030/`. The SHA-256 manifest is `/tmp/nmaforge_r105_SHA256SUMS.txt` (`66afd4843e4947624a0a466373309b666082a8058d270d62e1a78294ff5c9f35`). Private generated run data stays outside the repository.
