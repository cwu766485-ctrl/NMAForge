# Compute Cluster banked reset epoch evidence — R112

**Run ID:** `SPAD-BANKED-RESET-R112-3S`  
**Exact clean code/test SHA:** `bb31f6e093fc4c7bf63ac29301fe5f55aafb00b2` (R112).  
**Product RTL/SPEC baseline:** R99 `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; R112 changes only the subsystem UVM test and Make gate. SPEC v1.8 is unchanged.  
**Target:** repository `ai_accel_memory_fabric`, through the production arbiter and registered four-bank SPAD response path.  
**Tools:** VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`.  
**Seeds:** `20261025`, `20261026`, `20261027`.  
**Result:** PASS for the named banked reset/epoch point.

## Test and checker result

Each seed accepts a legal aligned banked read on requester/client 3 at address `0x100`, verifies that the registered response is not already visible, then asserts the shared subsystem reset before the response stage can emit. While reset is asserted, the test checks that arbiter, banked, descriptor, core, DMA, DMA-line, and CNM response-valid signals stay inactive. Following reset release it enforces a four-cycle quiet interval to detect a delayed stale response. A fresh client-3 read must then return the correct response owner, no competing response owner, and four words matching the independent bank image.

The three-seed gate exits `0`. All seeds print `[SPAD_BANKED_RESET_EPOCH_PASS]` and report UVM warning/error/fatal `0/0/0`. URG reports `banked_reset_epoch_cg` at **100.00%**. The banked response-owner assertion reports **450 attempts, 3 real successes, 0 failures, 0 incomplete**; the three successes correspond to the post-reset recovery read in each seed. The Make target fails if coverage is below 100%, the assertion has no real success, or any failure/incomplete is present.

The compile log has two platform support notices (`LNX_OS_VERUN` for Rocky Linux 8.10 and `LINX_KRNL` for WSL2 kernel 6.6.87.2). It has no `Error` or `[TFIPC]` diagnostic. No UVM severity warning is reported.

## Reproduction

From a detached clean worktree at the exact SHA above:

```sh
env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1   make subsystem_banked_reset_regress   BANKED_RESET_OUT=/tmp/nmaforge_r112_clean_replay_20261030   VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs   URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The command ran from `dv/subsystem/dma_spad/sim` and exited `0`. Logs and generated coverage output are outside the repository at `/tmp/nmaforge_r112_clean_replay_20261030/`.

## Evidence hashes

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `2db161d70491f962f1cab8236c69c8d30044a1db2b2f7c78ef9dc94a9e1f5502` |
| `seed_20261025/run.log` | `9b9d5e2bb5bcc043a3633eec65d9712fbbf951eae1aa270387f0db48989e2140` |
| `seed_20261026/run.log` | `97d50620e071f0a1c0c996a05bd23fb1f9affdf4a6cb28ddb35641f6466e91af` |
| `seed_20261027/run.log` | `63db77f1fdd1c78aff391e8732f4c954e15659c86c9eefcd24a7a41310f3fb28` |
| `urg/asserts.html` | `385ade7b26fee29c591dfab8e5430a60b1740b255b2b0337a96a45f2b991792b` |
| `urg/groups.html` | `ebe31b760619b12e1c5eb5b3a3f41190bcb446d77422d5aff03228c4ea008c9d` |
| `urg/dashboard.html` | `3b323c70106a0169538d495ca2e0cc3bc67afe0ace897efe3206f9dce19e08d1` |

## Scope limits and disposition

The requester is driven directly by this testbench; it is Matrix-like traffic through the production in-repository fabric, not a production Matrix engine transaction. This test proves the accepted banked request is flushed by reset, that no pre-reset response leaks through reset or the post-reset quiet window, and that tagged banked reads recover afterward. It does not exercise simultaneous production-engine contention, sustained backpressure, a fault combined with reset, or the full Engine × Fault × Phase × Reset matrix. Therefore it adds bounded evidence to `REQ-CL-018` and `REQ-PC-007` but closes neither requirement. `OPEN-CL-003` remains closed for the user's selected in-repository fabric target by R99; R112 strengthens that evidence without claiming arbitrary external-DDR-fabric qualification. The RTM remains **24 PASS-SCOPED / 14 PARTIAL** and `CL-DV-v1.0` remains **HOLD**.
