# Compute Cluster Top Smoke and Seeded Replay — R313

**Run ID:** `R313-TOP-SMOKE-AND-SEEDED-REGRESSION-CLEAN-20261104`  
**Code/test SHA:** `a88c310afbfaf3b02c3c16a5accc31c04ff379f2`  
**Git tree:** `a8a0fd314f505348bb623c43133e3da464df8718`  
**Worktree:** detached clean worktree `/tmp/nmaforge_r312_clean_a88c310`  
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`

## Reproduction and result

Commands were run from `dv/subsystem/top_smoke/sim` at the exact R312-tested source tree:

```sh
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Both commands finish with `TEST PASS`. The mapper precheck reports 86 descriptors and 60 tensors. The `ai_smoke` default run uses four random cases with `AI_SEED=12345`; the second command explicitly runs 20 cases with the same workload seed.

| Run | Random cases | Seed | Result |
|---|---:|---:|---|
| `ai_smoke` | 4 | 12345 | `TEST PASS` |
| `ai_run` | 20 | 12345 | `TEST PASS` |

The existing VCS compile warning `LOOP-REROLL-ENABLED` for `ai_transformer_workload.svh` remains. Compile output contains no `Error-` or `[TFIPC]` diagnostic. The behavioral smoke demonstrates top-level regression reproducibility for this exact test tree; it does not close the remaining partial Cluster requirements or establish ASIC PPA.

## Evidence archive

The compile log and separate logs for both runs are archived outside Git at `/tmp/nmaforge_r313_top_smoke_r312_evidence.tar.gz` (SHA-256 `e27826c72bbcea4278d8cde36b7b42827568d793e1bd98e3a584beddaa5f8d7b`). Individual log SHA-256 values are included in the archive README.

## Sign-off effect

R313 strengthens clean-candidate reproducibility only. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
