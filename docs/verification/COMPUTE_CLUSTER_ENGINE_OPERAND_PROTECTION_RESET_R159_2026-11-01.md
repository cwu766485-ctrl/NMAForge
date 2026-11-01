# R159 Seven-engine legal-operand Protection/reset/recovery evidence

**Run date:** 2026-11-01  
**Decision impact:** bounded testpoint evidence added; `CL-DV-v1.0` remains **HOLD**.

## Frozen identity

| Item | Identity |
|---|---|
| Product RTL/SPEC baseline | `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8 |
| Exact executed local test SHA/tree | `b9fe1136f02957800c6cf27e32fc52c46979bdd0` / `904f11f85a3f7d705363fd9617cfa7bbc041812d` |
| Published same-tree test snapshot | `876835f2b824f03b9940b14a691a8cefba32ebfd` on `feat/compute-cluster-closeout-6848a41` |
| Local test-change commits | `9ae7186` (cross expansion), `a224e58` (sentinel oracle), `b9fe113` (Conv Protection window) |
| Tool | Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`, UVM 1.2 |

The change is verification-only: `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh` adds legal Source-A/Source-B Protection-reset cases and the scoped covergroup; `dv/uvm/sim/Makefile` gates the 12 legal operand pairs and 72 cross bins. No product RTL or SPEC changes.

## Testpoint and checks

`TC-CL-R159-ENGINE-OPERAND-PROTECTION-RESET` covers 12 legal production engine/operand pairs: Source A on INT8, FP, CNM, Matrix, SFU, Conv, and KV; Source B on INT8, FP, CNM, Matrix, and Conv. SFU and KV have no descriptor Source-B operand, so those combinations are excluded rather than stimulated. Each pair exercises six phases: launch, denied operand request, internal Protection error observed, reset epoch flushed, old completion/writeback suppressed, and successful recovery. Seeded Fisher-Yates ordering changes case order while retaining reproducibility.

The sequence observes the denied transaction at the real selected SPAD requester, checks the existing internal error mapping (6 for INT8/FP/CNM/Matrix/SFU; 7 for Conv/KV), and asserts reset before the faulted descriptor retires. It checks reset/release quiet windows, old completion tail and output sentinels, and a new-epoch completion. Matrix recovery checks its complete 16-word Golden image; all engine recoveries check completion task ID, status, and element count. The full independent Memory Scoreboard checks the resulting image.

## Reproduction and results

Run ID: `R159-UVM-PROT-OPERAND-RESET-3S-20261101`; seeds `20261025`, `20261026`, `20261027`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r159_protection_operand_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'
```

All three seeds pass. The declared `engine_operand_phase_cross` is 72/72 (100.0%) per seed and in merged URG; the existing `cluster_cg` is 64/64. Each seed's full Memory Scoreboard checks 68,692 words with zero mismatch, unknown read, stale epoch, or orphan response; 21,903 accepted reads balance as 21,862 returned plus 41 reset-dropped reads, all pending ledgers are empty, and UVM severity is `0/0/0`. This is 100% of this explicitly scoped cross, not global Compute Cluster testpoint coverage: the merged URG all-group score is 64.86% because unrelated inactive groups remain in the report.

Run ID: `R159-TOP-SMOKE-20-20261101`.

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345
```

PASS: mapper precheck reports 86 descriptors and 60 tensors; the 20-case run ends `TEST PASS`. The existing fixture compile notice `[LOOP-REROLL-ENABLED]` remains.

Run ID: `R159-MUTATION-28-20261101`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r159_mutation_build \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r159_mutations \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'
```

PASS 28/28 expected checker-sensitivity probes: Address, Data, Response Owner, WSTRB, Completion Error Code, Write After Error, and Response Epoch; plus Done, Missing-Done, and Duplicate-Done on all seven engines. Each injection was caught by its assigned checker. These are checker-sensitivity tests, not an RTL mutation score.

The VCS compile has no `TFIPC`, `Warning-`, or `Error-` diagnostics. The logs and URG summaries are archived outside the repository at `/tmp/nmaforge_r159_protection_operand_logs.tar.gz` (SHA-256 `73451b9ffb02440f9c007ccb3990541df082f73038f91fa4d74fb8319c3ac3cb`); the per-file hash manifest is `/tmp/nmaforge_r159_evidence_sha256.txt`.

## Requirement trace and disposition

| Requirement | Added evidence | Disposition |
|---|---|---|
| REQ-CL-017 | Legal A/B Protection denial on all engines with reset, error observation, and suppressed old side effects | PARTIAL |
| REQ-CL-018 | 72-bin engine × legal operand × reset-phase group; quiet reset/release and recovery checks | PARTIAL |
| REQ-CL-019 | Old completion/writeback suppression and new-epoch completion checks | PARTIAL |
| REQ-CL-027 | Per-engine observed internal error mapping and recovery completion payload checks | PARTIAL |
| REQ-PC-006 | Production requester path, full memory-image scoreboard, tagged response ledger | PARTIAL |
| REQ-PC-007 | All seven real requesters covered sequentially; pairwise concurrent owner/fault cross remains open | PARTIAL |

R159 does not cover concurrent seven-engine activity in these cases, all completion error ABI combinations, all fault classes/phases, completion backpressure crossed with reset, or every legal descriptor shape. It promotes no requirement and does not establish full coverage closure. The complete disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Exact published-HEAD clean replay

The published branch head was replayed from an independent detached worktree after the report commit:

| Item | Result |
|---|---|
| Published HEAD / tree | `56f83d6006a931b05286aaa5d7d3a8a0af4a1691` / `1a345218a80f2eb3248946d34e009f39dbd7e406` |
| Clean worktree | `/tmp/nmaforge_r159_published_56f83` |
| UVM Run ID | `R159-PUBLISHED-HEAD-UVM-3S-20261101`; seeds `20261025/26/27` |
| Top Smoke Run ID | `R159-PUBLISHED-HEAD-TOP-SMOKE-20-20261101`; `AI_SEED=12345` |
| Mutation Run ID | `R159-PUBLISHED-HEAD-MUTATION-28-20261101` |

The exact UVM command was:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r159_published_56f83_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'
```

All three seeds pass with the scoped protection cross at 72/72, Memory Scoreboard at 68,692 checked words, zero mismatch/unknown/stale/orphan, 21,903 accepted reads = 21,862 returned + 41 reset-dropped, empty pending ledgers, and UVM severity `0/0/0`. Merged URG reports `cluster_cg` 64/64 and the named cross 72/72; the all-group score remains 64.86% because unrelated groups are inactive.

The Top Smoke command is `make ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345` from `dv/subsystem/top_smoke/sim`; mapper precheck reports 86 descriptors/60 tensors and the run ends `TEST PASS`. The existing `[LOOP-REROLL-ENABLED]` fixture compile warning remains. The same published HEAD passes 28/28 expected checker-sensitivity probes; this is not an RTL mutation score. The UVM compile has no `TFIPC`, `Warning-`, or `Error-` diagnostics.

Published-HEAD logs and URG summaries are archived outside the repository at `/tmp/nmaforge_r159_published_56f83_evidence.tar.gz` (SHA-256 `6d40de6658e2a373b03814bd0a14983628e56a413d8ea449da3218b4c2682783`); the 39-file checksum manifest is `/tmp/nmaforge_r159_published_56f83_evidence_sha256.txt`. The replay confirms the exact published tree and adds no scope: the 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
