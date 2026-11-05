# NMAForge v2 Small-M GEMV vs TinyNPU Replay

**Status:** PASS for the two listed Golden checks; comparison is mixed-boundary, not a product-level win claim.  
**Run ID:** `GEMV-MATCH-V2-S20261029`  
**NMAForge branch/SHA:** `feature/npu-architecture-v2` / `0b1d33704f4895cf48b0f5e1d3f452d61b3df535`  
**TinyNPU SHA:** `8216c22b762011aa20c05fc2768423fd12dda59d`

## Scope and method

The NMAForge side runs opcode `0x52` on its existing shared 16×16, 256-INT8-MAC Matrix array, product controller, and registered four-bank behavioral SPAD. The TinyNPU reference wrapper exposes a direct 16×16 systolic array but no matching product GEMV descriptor or SPAD interface. The comparison therefore pads invalid rows, columns, and K-tail lanes to the TinyNPU array and separately estimates a serialized TinyNPU memory endpoint. Both sides use the same signed INT8 input formulas and independent signed INT32 Golden. This is a bounded functional/timing experiment; it does not establish identical system interfaces or memory-service behavior.

## Results

| Shape (M×N×K) | MACs | NMAForge command cycles | NMA MAC/cycle | NMA read/write bytes | Bank/line stalls | Tiny direct-array RTL cycles | Tiny modeled memory service (R/W/clear) | Tiny normalized cycles | NMA / Tiny normalized | Golden |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1×13×17 | 221 | 76 | 2.9079 | 304 / 52 | 10 / 1 | 100 | 20 / 4 / 2 | 126 | 0.6032 | PASS, 13/13 outputs |
| 8×16×19 | 2,432 | 158 | 15.3924 | 560 / 512 | 13 / 16 | 100 | 36 / 32 / 2 | 170 | 0.9294 | PASS, 128/128 outputs |

The Tiny modeled endpoint is `direct-array RTL cycles + serialized read service + serialized write service + 2 accumulator-clear cycles`. The memory model assumes 16-byte lines, 16 bytes/cycle and one-cycle read response. For example, 304 read bytes are 19 lines and are charged 20 cycles including response latency. The Tiny memory figures are estimates, not RTL measurements.

The ratio is explicitly **NMAForge measured controller/SPAD command cycles divided by TinyNPU direct-array cycles plus modeled memory service**. A value below 1 is lower cycle count for these differing endpoints. It must not be presented as a fair system-level speedup or a general TinyNPU advantage. The TinyNPU direct-array interval alone is 100 cycles for each padded case.

NMAForge PE utilization is 1.14% for 1×13×17 and 6.01% for 8×16×19 relative to 256 MACs/cycle. TinyNPU padded-array utilization is 0.86% and 9.50%, respectively. Utilization uses each measured array interval and is not normalized to common memory latency.

## Per-command cycle/stall evidence

For 1×13×17, the exclusive controller-stage counters sum to 36 cycles and the separately counted prefetch-wait state contributes 40, closing to 76. For 8×16×19, the corresponding counts are 98 + 60 = 158. Arbiter stalls, response waits, writeback waits, and prefetch events are overlapping diagnostic counters; they are intentionally not added to the exclusive cycle partition. The VCS test checks stage-counter closure against each command's total cycles.

| Shape | Prefetch wait | Arbiter stalls | Response wait | Writeback wait | Outstanding high-water | B-cache hits / reads saved |
|---|---:|---:|---:|---:|---:|---:|
| 1×13×17 | 40 | 11 | 7 | 2 | 3 | n/a |
| 8×16×19 | 60 | 29 | 11 | 16 | 4 | 5 / 19 |

These two points exercise K/N tails and M=1/M=8, but do not close broad M/N/K-tail, alias/range, abort/reset, randomized backpressure, or TinyNPU common-memory testing.

## Reproduction

Tools: Synopsys VCS `V-2023.12-SP1_Full64`; Verilator `5.052` (`v5.052`, revision `ea338be98e1e838d3518809ce8899f85a009963c`); Python `3.12.13`. The TinyNPU working tree was checked against the pinned SHA before simulation.

From the NMAForge repository root:

```sh
env \
  VCS_ARCH_OVERRIDE=linux \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
  PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  VCS_VERSION=V-2023.12-SP1_Full64 \
  TINY_NPU_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference/source \
  TINYNPU_WORK_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference \
  GEMV_BENCH_OUT=/tmp/nmaforge_gemv_match_20261105_20261029_0b1d337 \
  BENCH_RUN_ID=GEMV-MATCH-V2-S20261029 \
  SHA=20261029 SEED=20261029 JOBS=8 \
  bash benchmark/tinynpu/run_gemv_match.sh
```

Observed result:

```text
GEMV_COMPARE_PASS run_id=GEMV-MATCH-V2-S20261029 cases=2
GEMV_COMPARE_PASS run_id=GEMV-MATCH-V2-S20261029 nmaforge_sha=0b1d33704f4895cf48b0f5e1d3f452d61b3df535 tinynpu_sha=8216c22b762011aa20c05fc2768423fd12dda59d
```

VCS also passed its focused `MATRIX_PRODUCT_GEMV_ONLY_PASS seed=20261029` regression, including bit-exact tail outputs for 1×13×17 and 8×16×19. Raw VCS/Verilator logs are archived outside Git at `/tmp/nmaforge_gemv_match_20261105_0b1d337_logs.tar.gz`, SHA-256 `e5496f0cb2c167bf38fbee5288b3885931fb04d52baf687c7717021d74c5afef`. Machine-readable evidence is in `benchmark/tinynpu/gemv_results.csv` and `benchmark/tinynpu/gemv_summary.json`; `benchmark/tinynpu/gemv_cycle_comparison.svg` visualizes the same scope and caveat.

## Remaining status

This replay closes only two paired small-M Golden cases. TinyNPU lacks the matching RTL memory/descriptor endpoint in this test, and broad product GEMV fault/recovery and common-resource performance comparison remain open. It does not change Compute Cluster v1.0 sign-off HOLD, close the full v2 DV matrix, or provide ASIC PPA evidence. DC remains blocked without the private foundry cell and SRAM timing libraries.
