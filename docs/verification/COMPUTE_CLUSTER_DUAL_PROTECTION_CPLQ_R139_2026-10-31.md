# Compute Cluster R139 — dual Protection faults under CPLQ backpressure

Date: 2026-10-31  
Run ID: `R139-DUAL-PROTECTION-CPLQ-BACKPRESSURE-3S-20261031`

## Scope and source identity

R139 adds a real-top CMDQ sequence that fills the completion ring with three legal engine results, then holds two parallel Matrix/CNM Protection-error completions behind the full ring. It releases one slot at a time and checks ordered retirement across both ring wrap points. This covers the completion-backpressure corner of the existing dual-Protection owner scenario; it does not define simultaneous-fault priority.

The exact test commit is `b86bd5df7256df6a8d641213a5601e1237254124` (tree `a1f77cc77b63795b5abfcf35410588add690f788`), replayed from detached clean worktree `/tmp/nmaforge_r139_replay_b86bd5d`. Product RTL and SPEC were not modified; product baseline remains `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, SPEC v1.8.

The sequence submits five legal descriptors in CMDQ order: Scalar VDOT, SFU GELU, KV write, Matrix GEMM, and CNM GEMV. The first three results fill the three usable entries of a four-slot CPLQ (`tail=3`, `head=0`). Matrix and CNM both encounter Protection error `0x62`; after their engines become idle, the processor remains busy with pending ordered completions. Advancing `CPLQ_HEAD` to 1 permits Matrix to retire at slot 3 and wraps the tail to 0 while the ring remains full. Advancing the head to 2 permits CNM to retire at slot 0 and wraps the tail to 1, again leaving the ring full. The test checks task IDs, error words, completion order, all three preceding Golden results, and the complete Matrix/CNM destination sentinel images.

## Execution

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r139_exact_b86bd5d_20261031 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

VCS is `V-2023.12-SP1_Full64`; URG is `V-2023.12-SP1`. The command exits 0 with `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`. The Make target requires the R139 marker in every seed in addition to its existing regression markers and zero UVM warning/error/fatal counts.

## Same-SHA closeout checks

The following checks were run from a detached checkout of the same test SHA `b86bd5df7256df6a8d641213a5601e1237254124`:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=20261025

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r139_mutation_compile_20261031 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r139_mutations_20261031
```

Top Smoke passes: mapper reports 86 descriptors and 60 tensors, and simulation ends with `TEST PASS`. The existing `Warning-[LOOP-REROLL-ENABLED]` compile notice remains. Checker sensitivity passes all 28/28 probes: address, data, owner, WSTRB, completion error code, write-after-error, response epoch, and Done/missing-Done/duplicate-Done lifecycle mutations for all seven engines. Each expected mutation is injected and caught by its designated checker; injected UVM errors are expected campaign outcomes.

| Run | Result and archived logs | SHA-256 |
|---|---|---|
| `R139-TOP-SMOKE-20CASE-20261031` | PASS; `/tmp/nmaforge_r139_top_smoke_20261031/compile.log`, `run.log` | Compile `920ee7d331c23018b17fd083aa833c36556a14949888fd56d5363f79774f94fb`; run `51e65656dde38b55dc2bcb61f07cbbd0091513dd162a60f7e8d147411d923772` |
| `R139-MUTATION-28-20261031` | PASS 28/28; `/tmp/nmaforge_r139_mutation_compile_20261031/compile.log`, `/tmp/nmaforge_r139_mutations_20261031/*.log` | Compile `9df1d89067af2c494512d2402355b19826bf7520cbc8d2a4e23c99c8a26c102c`; 29-entry `SHA256SUMS` `0b9ca6c2755b5b38c1b7ec5fdfc27af50f48a8ca775200a3eea692e26a550b79` |

## Results

| Seed | CPLQ hold and wrap | Matrix/CNM overlap | Tagged responses | Scoreboard checked words | Mismatch / unknown / stale / orphan | UVM warning/error/fatal |
|---|---|---:|---:|---:|---|---|
| 20261025 | PASS; tail 3→0→1; Matrix then CNM; full after both releases | 141 cycles | 128 / 64 | 44,611 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |
| 20261026 | PASS; tail 3→0→1; Matrix then CNM; full after both releases | 141 cycles | 128 / 64 | 44,611 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |
| 20261027 | PASS; tail 3→0→1; Matrix then CNM; full after both releases | 141 cycles | 128 / 64 | 44,611 | 0 / 0 / 0 / 0 | 0 / 0 / 0 |

Every seed reports `focused_compute_cg_applicable=100.0%`; this is the existing declared focused group, not whole-design or requirement coverage. Merged mixed URG is 56.00% (line/condition/FSM/branch/assert/group `69.31/63.49/41.91/59.59/72.00/29.72%`). Those raw code and mixed testbench scores are not sign-off percentages.

## Requirement traceability and disposition

| Requirement | Status | R139 evidence added | Remaining scope |
|---|---|---|---|
| REQ-PC-004 | PASS-SCOPED | CPLQ full hold with real engines idle, sequential software head advance, ordered completion payloads, and tail wrap at both entries | Other queue sizes and completion-protection boundary combinations remain outside the named PASS scope |
| REQ-CL-017 | PARTIAL | Parallel Matrix/CNM Protection faults retained while completion retirement is blocked | Full engine × fault × phase × Abort/Reset cross and accepted-write prefixes remain open |
| REQ-CL-019 | PARTIAL | Both `0x62` errors retire in CMDQ order after the backpressure hold | Other fault pairs, phases, and reset/Abort precedence remain open |
| REQ-CL-027 | PARTIAL | Error status, task ID, and completion order checked at wrapped slots | Complete error-ABI matrix across engines and fault phases remains open |
| REQ-PC-006 | PARTIAL | Matrix/CNM response-owner counts are 128/64 with zero route mismatch through the blocked-retirement interval | Full requester × error × backpressure/reset matrix remains open |
| REQ-PC-007 | PARTIAL | Real Matrix and CNM share the production SPAD path during two Protection errors; complete memory image and owner ledgers pass | Broad production-engine arbitration and reset/fault cross remains open |

The 38-row Execution RTM remains **24 PASS-SCOPED / 14 PARTIAL**; no disposition is promoted. `REQ-PC-004` retains its existing PASS-SCOPED disposition; the five other rows above remain PARTIAL. `CL-DV-v1.0` remains **HOLD**. Top Smoke and checker-sensitivity mutation also pass at the same exact SHA as recorded above.

## Evidence artifacts

Artifacts are retained outside the repository in `/tmp/nmaforge_r139_exact_b86bd5d_20261031/`.

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `de8da0cee6f4aea72118bbdc5eaf577d89cb275d1e4cb1af080fb52cbe8e4c71` |
| `seed_20261025/run.log` | `bf89b33b72ee311ec2d803f623128a4d2a59b16bb0c890f2a8ff2ce429e034f4` |
| `seed_20261026/run.log` | `e70f7c68de3a5a5cf3db7513e4ad70c91c903c6d581b2d4a2225ac4012eed62c` |
| `seed_20261027/run.log` | `3f1d329be6008bea2cfa4a9de37e5e11b8855dc343858fe3b1f87b2d19271c14` |
| `urg_merged/dashboard.txt` | `1a77e019ddcb792b69f085a68f9efae7f2e64a77e77174346d0105a74ca83b77` |
| `urg_merged/groups.txt` | `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` |
| `urg_merged/asserts.txt` | `9aeb92bc5e99705ff32c37367639bb452bc9d650b22431a1786c37e9429cb35c` |
