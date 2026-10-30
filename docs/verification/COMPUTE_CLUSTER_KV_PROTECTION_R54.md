# Compute Cluster Top-Level KV Protection — R54

**Run ID:** `KV-SPAD-PROTECTION-OWNER-R54-1S`  
**Date:** 2026-10-30  
**Test SHA:** `f24c5383fad511c8b2e1132c1157942807994759`  
**Clean checkout:** `/tmp/nmaforge_kv_protection_r54_clean_f24c538`  
**DUT:** real `ai_accel_top`, seven-engine compute cluster, production compute SPAD mux, SPAD protection, completion writer, and behavioral scratchpad.
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`.

## Result

PASS on the exact clean SHA. `make ai_smoke` and
`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` both report `TEST PASS` and
include the directed R54 markers.

The test submits one real `KV_WRITE` descriptor. Its source word at `0x1000`
is in an enabled read/execute region. The cache destination `0x2000` is outside
all permitted regions. A separate read/write region admits descriptor fetch
and the completion record. The top-level engine request monitor observes one
accepted KV source read and the denied KV destination write at the KV owner
port. The KV engine reports its defined merged SPAD error `7`.

| Testpoint | Expected checker result | Observed result |
|---|---|---|
| `KV-PROT-001` source read / owner | Exactly one accepted read from KV owner | PASS, one read |
| `KV-PROT-002` destination denial / owner | Protection error routes to KV owner at `0x2000` | PASS |
| `KV-PROT-003` ordered completion | Task `0x7a53`, error status `2`, error code `7` | PASS |
| `KV-PROT-004` memory side effect | Source unchanged; denied destination remains `0xcafef00d` | PASS |

This closes only the top-level KV Protection-region denial slice previously
listed under `OPEN-CL-002` and `CL-COV-003`. It is not a multi-requester
contention test and does not close the wider `REQ-PC-006` owner/competition
crosses, KV stride/alias coverage, other Engine descriptor contracts, or the
38-requirement DV review.

## Reproduction and evidence

```sh
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Both commands run from `dv/subsystem/top_smoke/sim` in the clean worktree.
VCS compile log: `/tmp/nmaforge_kv_protection_r54_clean_f24c538/dv/subsystem/top_smoke/sim/ai_comp.log`.
Smoke log SHA-256:
`c74039a5389982d86d306821b24c01e35e015b9882711717fecdb6017015e986`.
20-case run log SHA-256:
`b11b58041d0dd72dd32b8cab53ce80858ed9952f36fc2fab763c5c7b5148c6b0`.

The compile retains the existing fixture warning
`Warning-[LOOP-REROLL-ENABLED]` at `ai_transformer_workload.svh:9`; no new
warning, error, `[TFIPC]`, or fatal diagnostic is introduced by R54.
