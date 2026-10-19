# A10 V4 mixed-precision DDR E2E replay at exact pushed `main`

## Identity and environment

- Exact pushed `main` SHA: `5dd6ed49e577f56ff86b9730fc74d3a8167b62cf`.
- Detached worktree: `/tmp/nmaforge_clean_5dd6ed4_v4e2e_20261019`.
- Rocky Linux 8.10 / WSL2; VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.
- Artifacts: `/tmp/nmaforge_a10_main5dd6ed4_v4e2e_20261019/`.
- The detached worktree was clean before and after the run. No active VCS,
  simulator, or URG process remained at audit time.

This is a fixed-SHA replay of the checked-in mixed-precision DDR E2E campaign.
It does not by itself close all V4 requirements, V5, or A10.

## Command

```sh
git -C /mnt/e/workspace/chip/NMAForge worktree add --detach \
  /tmp/nmaforge_clean_5dd6ed4_v4e2e_20261019 \
  5dd6ed49e577f56ff86b9730fc74d3a8167b62cf

cd /tmp/nmaforge_clean_5dd6ed4_v4e2e_20261019
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress \
  MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_main5dd6ed4_v4e2e_20261019
```

The Makefile's default seeds were `20261101..20261292`. Its built-in gates
checked descriptor order/layout, BF16/FP16 lengths, invalid descriptors,
AXI-Lite SLVERR, DMA SLVERR, reset/recovery paths, per-transaction AXI
backpressure and response gaps, UVM severity, and merged URG coverage.

## Results

- 192/192 seed logs contained `[MIXED_E2E_PASS]`; no seed had nonzero UVM
  warning/error/fatal counts. The compile log had zero `Warning-`/`Error-`
  diagnostic lines.
- The target's E2E functional covergroup, all four AXI AR/AW/R-gap/W-gap
  covergroups, and all 19 checked functional points reached 100%.
- URG assertions: 20 successful, 0 failed, 0 incomplete; 2 UVM RAL internal
  `do_read`/`do_write` properties were not attempted. Cover properties: 3/3
  matched.
- The selected per-DUT raw code-coverage snapshot is workload-specific and is
  not a whole-project closure claim:

  | DUT module | Line | Condition | Branch |
  |---|---:|---:|---:|
  | `ai_mixed_precision_dot_fp32_core` | 91.16% | 64.50% | 76.79% |
  | `ai_command_processor` | 56.80% | 54.37% | 40.30% |
  | `ai_axi128_dma` | 67.08% | 46.33% | 57.94% |
  | `ai_spad_arbiter` | 50.46% | 55.74% | 48.48% |
  | `ai_scratchpad` | 67.92% | 25.00% | 59.46% |

The scenario-targeted functional bins are closed for this run, but raw DUT
coverage remains partial and must be dispositioned by block/workload. This
campaign is not a substitute for FP parity-to-writeback formal, dedicated
block-level coverage closure, or overall V5 review.
