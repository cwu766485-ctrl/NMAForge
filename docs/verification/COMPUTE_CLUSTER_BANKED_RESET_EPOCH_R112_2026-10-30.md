# Compute Cluster banked reset epoch evidence — R112

**Run ID:** `SPAD-BANKED-RESET-R112-3S`
**Exact clean code/test SHA:** `b4d99efe95034ff953ca26c66f90a8402a0cde7c` (R112).
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
env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C /tmp/nmaforge_r112_published_b4d99_clean/dv/subsystem/dma_spad/sim \
  subsystem_banked_reset_regress \
  BANKED_RESET_OUT=/tmp/nmaforge_r112_published_b4d99_clean_runs \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The command targeted `dv/subsystem/dma_spad/sim` in the detached clean worktree and exited `0`. Logs and generated coverage output are outside the repository at `/tmp/nmaforge_r112_published_b4d99_clean_runs/`.

## Evidence hashes

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `244a1c4e11470a21ecbfefecaf55082fb93c832ed1ebe442124dda90c115c4e8` |
| `seed_20261025/run.log` | `95bafba7db42b921d286dac9706c559a4993ec9fe817adc7537a79f762757e38` |
| `seed_20261026/run.log` | `06197784403ef3b3badce7b6ad441fed3627656fc96ff828cd613c04335c39ce` |
| `seed_20261027/run.log` | `8e8c5a19590ea492832f940c587c3d8851ab58c1d69b60a2438cc74c1dee03b0` |
| `urg/asserts.html` | `d0fbd984d8236d6592560f8d53721d0a3dffdaf3b94428af6642870232ad14b4` |
| `urg/groups.html` | `ebe31b760619b12e1c5eb5b3a3f41190bcb446d77422d5aff03228c4ea008c9d` |
| `urg/dashboard.html` | `63b6354b3c9cc2c7bf08c829c92e85889be4bc99536150af77e4ddf6115ea942` |

## Scope limits and disposition

The requester is driven directly by this testbench; it is Matrix-like traffic through the production in-repository fabric, not a production Matrix engine transaction. This test proves the accepted banked request is flushed by reset, that no pre-reset response leaks through reset or the post-reset quiet window, and that tagged banked reads recover afterward. It does not exercise simultaneous production-engine contention, sustained backpressure, a fault combined with reset, or the full Engine × Fault × Phase × Reset matrix. Therefore it adds bounded evidence to `REQ-CL-018` and `REQ-PC-007` but closes neither requirement. `OPEN-CL-003` remains closed for the user's selected in-repository fabric target by R99; R112 strengthens that evidence without claiming arbitrary external-DDR-fabric qualification. The RTM remains **24 PASS-SCOPED / 14 PARTIAL** and `CL-DV-v1.0` remains **HOLD**.
