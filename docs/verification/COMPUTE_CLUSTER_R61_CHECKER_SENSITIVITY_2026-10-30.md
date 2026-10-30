# Compute Cluster R61 Checker Sensitivity and Clean Replay

**Code/test SHA:** `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`  
**Preceding product/SPEC baseline:** unchanged from the R60 candidate; this commit changes UVM observation, scoreboard, coverage filtering, and Makefile targets only. No product RTL, SPEC, or externally visible ABI changed.  
**Clean worktree:** `/tmp/nmaforge_cluster_r61_clean_d45b89a` (detached at the code/test SHA)  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, Python `3.12.13`.

## Executed checks

Commands were run from the clean worktree root unless the command says otherwise.

```sh
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_cluster_r61_clean_d45b89a/uVM \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026'

make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_cluster_r61_clean_d45b89a/uVM \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_cluster_r61_clean_d45b89a/mutations

cd dv/subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All four targets exited 0. The clean three-seed UVM run compiled without VCS compile warnings/errors and each seed ended with UVM warning/error/fatal `0/0/0`. Each seed compared 5,445 memory words with zero mismatches, unknown reads, stale epoch reads, or orphan responses; pending read/write ledgers drained. The focused compute testpoint group reported `100.0% applicable` on all three seeds. Completion-read response is architecturally N/A in this test and is separately shown as zero/N/A; this is not a claim of 100% RTL code, all functional coverage, or all 38 requirements.

| Run | Result | Evidence |
|---|---|---|
| R61 UVM compile | PASS | `/tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/compile.log` |
| R61 seed `20261030` | PASS | `/tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/seed_20261030/run.log` |
| R61 seed `20261025` | PASS | `/tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/seed_20261025/run.log` |
| R61 seed `20261026` | PASS | `/tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/seed_20261026/run.log` |
| R61 merged assertion report | 22 properties: 17 successes, 5 uncovered, 0 failures/incomplete; 2 UVM RAL properties have no attempts | `/tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/urg_merged/asserts.txt` |
| Top Smoke | PASS, `TEST PASS` | `/tmp/nmaforge_cluster_r61_clean_d45b89a/top_ai_smoke.log` |
| Top seeded regression | PASS, 20 random cases, `TEST PASS` | `/tmp/nmaforge_cluster_r61_clean_d45b89a/top_ai_run20.log` |

The remaining assertion bins are not waived: three AXI AR/AW properties have no real successes in this compute-focused UVM test, and AR/AW stall-to-accept covers did not match; the W stall-to-accept cover matched three times. This run therefore does not close the AXI SVA non-vacuity issue. Top Smoke compilation has the existing fixture `LOOP-REROLL-ENABLED` warning; simulation passes.

## Checker-sensitivity campaign

`make uvm_compute_cluster_mutation` passed **28/28 expected checker catches** on this exact clean SHA:

- `address`, `data`, `owner`, and `wstrb` passive-observation mutations;
- `done`, `missing_done`, and `duplicate_done` lifecycle mutations for each of seven engine bits (21 cases);
- completion error-code mismatch, write-after-terminal-error prefix, and stale response-epoch probes.

The new completion error-code probe alters the observed completion memory image through the testbench host interface. The prefix and epoch cases inject synthetic passive observations. These three cases demonstrate checker sensitivity; they are **not** faults injected into synthesized RTL and do not constitute an RTL mutation score. Their expected UVM errors were required by the Makefile gate and were associated with the named checker markers. Full per-case logs are in `/tmp/nmaforge_cluster_r61_clean_d45b89a/mutations/`.

## Selected evidence hashes

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `f249bb5b658f6264334146e94481f6bceffd1421ecf290b7dbfb01d2407ac2c9` |
| Seed `20261030` log | `fd69c75c4374c4adea765b93856cc5a680f9a3ad3cc31064271fa69891593654` |
| Seed `20261025` log | `54ecda61eb9a96eea82dbce837a607cd269531738918eda978036756982093f3` |
| Seed `20261026` log | `13802161c3f4510b3aae79875082a5c95ca046ec206b16a6c5166c80302157a1` |
| URG `asserts.txt` | `b591c9a5244df2207fd234c02a58794badc8cf52a5ae78a79961026103b03142` |
| `completion_error_code.log` | `538845d11ce9d231638add17b20f731193278d50700217830a5c84e85dd71b5c` |
| `write_after_error.log` | `75c2d7051342b9ec8482366c737aabaf83961dbc0f65953a25677f2f8bafe44d` |
| `response_epoch.log` | `16f11231ff67caa55d1bb4e14b89f36c45b1db63d043bac58937a57453353b49` |
| Top Smoke log | `f84976e1982faa8e94be8763e37d6a022830a65025aed22134c11950b829a65e` |
| Top 20-case log | `5423626763b25d97083bef080fd4aede37ac47a43d9503e4bd59daf8365f7932` |

## Sign-off disposition

R61 adds useful evidence for completion-code, post-error write-prefix, stale-epoch checker sensitivity, and a clean exact-SHA rerun. It does not close the remaining legal `Engine × Fault × Phase × Reset` combinations, external-fabric late-response qualification, Matrix unsupported partial/zero WSTRB cases, descriptor-domain coverage, the default Matrix 49/53 FSM result, AXI AR/AW SVA activation, or the remaining partial RTM rows. Those gaps retain their existing dispositions. **Compute Cluster v1.0 remains HOLD / not signed off.**
