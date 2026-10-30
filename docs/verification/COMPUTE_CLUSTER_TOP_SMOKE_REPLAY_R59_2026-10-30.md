# Compute Cluster Top Smoke Replay — R59

**Run ID:** `CL-TOP-SMOKE-KV-PROT-20-DED9D92`  
**Date:** 2026-10-30  
**Review harness SHA:** `ded9d923a432e869592ec8710a22df5501d8d474`  
**Product RTL/SPEC SHA:** `f916874a9ce60741a4516eaf9e33ebcae4a676c2`  
**Clean checkout:** `/tmp/nmaforge_matrix_r58_clean_ded9d92`  
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`.

## Result

Both exact-clean runs pass:

- `make ai_smoke` → `TEST PASS`
- `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` → `TEST PASS`

Both include the real-top KV Protection denial directed case: one accepted KV
source read, denied cache write routed to KV, completion `task=0x7a53`,
`status/error=2/7`, unchanged source sentinel `0x13579bdf`, and unchanged
destination sentinel `0xcafef00d`. Top Smoke also completes its mapper precheck,
reset recovery, and 86-descriptor functional workload.

The compile retains the known fixture warning
`Warning-[LOOP-REROLL-ENABLED]` at `ai_transformer_workload.svh:9`; no compile
error, `[TFIPC]`, or fatal diagnostic was found.

## Reproduction and evidence

Commands are run from
`/tmp/nmaforge_matrix_r58_clean_ded9d92/dv/subsystem/top_smoke/sim`:

```sh
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

| Artifact | Path | SHA-256 |
|---|---|---|
| VCS compile log | `/tmp/nmaforge_matrix_r58_clean_ded9d92/dv/subsystem/top_smoke/sim/ai_comp.log` | `8a3483317066085a286117863eb07473ded3f69e8798d92bd769aff89a804cd9` |
| Top Smoke console log | `/tmp/nmaforge_cluster_r59_top_smoke_ded9d92.log` | `63f802e9fa0d24d8a3bddd16e3d41e27c7c92a0312dc2b113cf3155ef313be7d` |
| 20-case seeded console log | `/tmp/nmaforge_cluster_r59_top_run20_ded9d92.log` | `71931329bac5ec8d8c578fa6b0460dd2deadf49f164f22c1338211f9d88945a5` |

R59 repeats only these top smoke cases at the latest harness SHA. It does not
re-run the full numeric engine, benchmark, or external-fabric campaigns and
does not change any requirement disposition by itself.
