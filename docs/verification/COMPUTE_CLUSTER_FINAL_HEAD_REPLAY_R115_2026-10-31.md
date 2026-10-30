# Compute Cluster final published HEAD replay — R115

**Run IDs:** `R115-PUBLISHED-HEAD-TOP-SMOKE`, `R115-PUBLISHED-HEAD-TOP-RANDOM-20`  
**Exact published clean-worktree SHA:** `5bc52ed80a763de58c6a1d3487255ca9552cc12b`  
**Compute Cluster UVM test code SHA in that tree:** `4797a7710a18670d820f8f3815959091f9636e75`; the intervening commit changes documentation only.  
**Tools:** VCS `V-2023.12-SP1_Full64`; mapper Python `3.12`.  
**Result:** PASS for the restored Top Smoke and 20-case seeded Top regression.

## Reproduction and results

From the detached clean worktree at the exact published SHA:

```sh
env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C /tmp/nmaforge_r114_final_5bc52_clean/dv/subsystem/top_smoke/sim ai_smoke

env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C /tmp/nmaforge_r114_final_5bc52_clean/dv/subsystem/top_smoke/sim \
  ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

`ai_smoke` runs the mapper precheck and prints `TRANSFORMER_MAPPER_PASS descriptors=86 tensors=60 dataflow=closed poison=enabled`, then VCS ends with `TEST PASS`. The 20-case seeded invocation also ends with `TEST PASS`. Both commands exited `0` in the clean worktree. The generated VCS outputs are outside the repository's tracked files.

VCS reports platform-support notices for Rocky Linux 8.10 and the WSL2 6.6.87.2 kernel. The smoke compile also reports the existing fixture `LOOP-REROLL-ENABLED` line-debug notice at `ai_transformer_workload.svh:9`. These diagnostics are retained; no simulation or mapper failure occurred.

## Evidence paths and hashes

| Artifact | SHA-256 |
|---|---|
| `ai_smoke` driver log (exit `0`) | `b55208f2c5a5716557291203fa9eb6a9d2cb11bed123409600c2c1243407bd42` |
| `ai_run` driver log (exit `0`) | `cb1b14ae150befc8eb06633cdeee6187e45130411ce3d35a10fc8d84f0ff41d6` |
| VCS compile log `ai_comp.log` | `411bda68922641ae478cea5587c6ba3a9b3081b31d1552c576c064d3fb1b58a7` |
| Final seeded VCS simulation log `ai_accel_smoke.log` | `b3fd29b194f792f4c1c5d16dcbcbac303a36284dfbe46056f12ef7f4a9004ca4` |

Driver logs are archived at `/tmp/nmaforge_r114_5bc52_ai_smoke.log` and `/tmp/nmaforge_r114_5bc52_ai_run20.log`; generated files are under `/tmp/nmaforge_r114_final_5bc52_clean/dv/subsystem/top_smoke/sim/`.

## Scope

This confirms the latest published closeout HEAD restores and runs the Top Smoke testbench, mapper precheck, and the named 20-case seeded top scenario. It is not a rerun of the seven-engine UVM suite, the full fault/coverage campaign, Matrix benchmarks, TinyNPU comparisons, or ASIC PPA. The Compute Cluster RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains **HOLD**.
