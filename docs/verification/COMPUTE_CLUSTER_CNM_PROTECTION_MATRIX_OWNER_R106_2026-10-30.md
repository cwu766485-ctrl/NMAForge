# Concurrent CNM Protection and Matrix Owner Isolation — R106

**Run IDs:** `CLUSTER-CNM-PROTECTION-MATRIX-OWNER-R106-3S`, `CLUSTER-MUTATION-R106-28`, `TOP-SMOKE-R106`, `TOP-RANDOM-R106-20`\
**Exact committed test SHA:** `ef0924767c3ccf0bec9b2f54d4b96da2491c9901`\
**GitHub closeout branch commit:** `583e9c2484271052d67b865f3f38a4aacb55580d` (tree-identical to local SHA; test-only)\
**Product RTL/SPEC:** unchanged from R99 candidate `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8.\
**Disposition:** PASS for this legal concurrent CNM Protection / Matrix Golden owner point and the named passive checker-sensitivity campaign. Compute Cluster v1.0 remains **HOLD**.

## Test intent

The real top dispatches a legal Matrix 16×32×64 GEMM and a legal CNM GEMV through the shared SPAD. Protection denies only the CNM source-A window. The test observes that denial while Matrix is still active, then checks that Matrix completes all 512 Golden output words, CNM retires its own Protection completion (`0x62`), and the CNM destination remains untouched. It also checks both response counters, ordered completion records, zero route mismatches, and a nonzero interval with both engines busy.

## Reproduction

Run in `/tmp/nmaforge_r95_clean_119f184` with VCS `V-2023.12-SP1_Full64` and URG `V-2023.12-SP1`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r106_cnm_protection_matrix_owner_20261030 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r106_mut_compile_20261030 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r106_mutations_20261030 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/subsystem/top_smoke/sim ai_smoke

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All four Make targets returned exit code `0`. Both UVM compile logs contain no `Warning-`, `Error-`, or `[TFIPC]`.

## Results

| Seed | Both engines busy / overlap | Matrix/CNM tagged responses | Completion and memory result |
|---|---:|---:|---|
| `20261025` | `7 / 7` cycles | `192 / 2` | Matrix 512-word Golden PASS; CNM Protection `0x62`; 33,303 checked words, zero mismatch/unknown/stale/orphan |
| `20261026` | `7 / 7` cycles | `192 / 2` | Matrix 512-word Golden PASS; CNM Protection `0x62`; 33,303 checked words, zero mismatch/unknown/stale/orphan |
| `20261027` | `7 / 7` cycles | `192 / 2` | Matrix 512-word Golden PASS; CNM Protection `0x62`; 33,303 checked words, zero mismatch/unknown/stale/orphan |

The Matrix completion precedes the CNM Protection completion in CMDQ order. Every seed reports zero response-route mismatch, unchanged CNM output sentinels, UVM warning/error/fatal `0/0/0`, and `100.0%` focused applicable compute testpoint coverage. The coverage figure is scoped to the current testpoint group, not the full requirement set or DUT code.

The exact-source passive checker-sensitivity target passes `28/28`: Address, Data, response Owner, WSTRB, completion error code, write-after-error, response epoch, and Done/missing-Done/duplicate-Done on each of seven engines. These are passive observation mutations, not RTL fault injection or a DUT mutation score.

The merged compute-workload URG report has 17/22 assertions with real successes, zero failures/incomplete, three AXI assertions without real success in this workload, two UVM RAL properties without attempts, and one of three AXI stall-to-accept covers matched (W). R102's dedicated behavioral AXI run supplies separate AR/AW/W stall evidence. The compile emits the existing top-smoke fixture warning `[LOOP-REROLL-ENABLED]`; the smoke and 20-case seeded top run end with `TEST PASS`.

Top Smoke's mapper precheck reports 86 descriptors and 60 tensors. It and the 20-case top regression were run at exact local source tree `ef09247`; the GitHub code commit above has the same tree. Their outputs are `dv/subsystem/top_smoke/sim/ai_comp.log` and `ai_accel_smoke.log`.

## Traceability and remaining limits

R106 adds a bounded opposite-direction owner/error point for `REQ-CL-017`, `REQ-CL-027`, `REQ-PC-006`, and `REQ-PC-007`, complementing the Matrix Protection/CNM Golden and Matrix Protection/CNM Abort points in R104/R105. These rows remain PARTIAL: the broader Engine × Fault × Phase × Reset space, production requesters under downstream backpressure, and all accepted-write prefix cut points are not closed. The 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.

UVM logs and coverage databases are under `/tmp/nmaforge_r106_cnm_protection_matrix_owner_20261030/`; mutation logs are under `/tmp/nmaforge_r106_mutations_20261030/`. The SHA-256 manifest is `/tmp/nmaforge_r106_SHA256SUMS.txt` (`93e234d290cdcd8e2864ec759a458a0a466d1ceb1aa5824279e6f75169e82454`). Generated simulator databases remain outside Git.
