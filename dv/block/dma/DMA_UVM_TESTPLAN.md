# DMA block UVM test plan

## Scope

The DUT is `rtl/dma/ai_axi128_dma.v`. This plan excludes command queue,
register programming and the production scratchpad arbiter; those belong to
the queue-completion and DMA-SPAD subsystem environments.

## Test architecture

```text
dma_cmd sequence/driver ──> ai_axi128_dma ──> AXI4 slave BFM
                                  │                 │
                                  └──> SPAD model ──┴──> scoreboard + SVA + coverage
```

The AXI4 BFM owns only the memory-side protocol behavior. It may independently
stall AR/AW/W, delay responses and return read/write completions newest-first.
Passive AXI/SPAD monitors, rather than the active BFMs, feed the scoreboards.
The scoreboards compare transfer words at the architectural addresses, never
by response arrival order.

## Executable test list

| Test | Stimulus | Checkers | Latest status |
|---|---|---|---|
| `dma_load_ooo_smoke_test` | 32 words, four read IDs, newest-first R | highwater=4, OOO order, DDR→SPAD data, SVA | **PASS** in VCS |
| `dma_2d_load_test` | 3×6, DDR/SPAD stride | row-address and data scoreboard | **PASS** in VCS |
| `dma_gather_load_test` | 3×4, SPAD-held DDR row pointers | index addressing and data scoreboard | **PASS** in VCS |
| `dma_store_booo_test` | 16 words, two write bursts, newest-first B | AW/W/WLAST, BID order, SPAD→DDR data | **PASS** in VCS |
| `dma_store_four_booo_test` | 32 words, four tagged write bursts held until four B responses are pending, newest-first B | exercises IDs 8–11, exact reverse completion order, empty response window, SPAD→DDR data | **PASS**, focused and full 17-test VCS regression, 2026-10-18 |
| `dma_2d_store_test` | 3×5 strided store | row-address and data scoreboard | **PASS** in VCS |
| `dma_narrow_load_test` | address offset 4, 7 words | narrow bus lane then line data | **PASS** in VCS |
| `dma_4k_load_test` | address `0x1fc0`, 40 words | no AR 4 KiB crossing, data | **PASS** in VCS |
| `dma_4k_edge_load_test` | 12-word load from `0x1ff0`, one beat before the 4-KiB boundary | accepted ARs are exactly `0x1ff0/LEN0` then `0x2000/LEN1`; scoreboard checks all data | **PASS**, focused + 19-test regression, 2026-10-18 |
| `dma_short_tail_store_test` | 1-, 2-, and 3-word single-beat stores | exact WSTRB `000f/00ff/0fff`, B-response drain and scoreboard data | **PASS**, focused + 19-test regression, 2026-10-18 |
| `dma_abort_read_test` | abort after accepted read work | `ERR_ABORT`, response drain, completion | **PASS** in VCS |
| `dma_read_slverr_test` | inject `SLVERR` into the first newest-first response after four accepted reads | `ERR_AXI_RD`, all four RLASTs drain, SPAD sentinels stay unchanged, clean recovery read | **PASS** in VCS, 2026-10-16 |
| `dma_spad_error_drain_test` | 32-word load, hold R until four ARs accepted, inject on first newest-first destination line write (`0x1200 + 24×4 = 0x1260`) | `ERR_SPAD` (DMA-local code 4), 4/4 RLASTs drain, all destination sentinels unchanged, no pending response, clean no-reset recovery read | **PASS** in focused VCS rerun and 15-test regression, 2026-10-16 |
| `dma_write_slverr_test` | inject AXI BRESP `SLVERR` for one accepted store burst | `ERR_AXI_WR`, one matching BID completes, no pending B, clean recovery read | **PASS** in VCS, 2026-10-16 |
| `dma_abort_write_test` | abort immediately after accepted AW, with delayed B response | complete accepted W burst, drain B before `done`, then run a clean recovery read | **PASS** in VCS, 2026-10-16 |
| `dma_config_error_test` | unaligned DDR source address | `ERR_CONFIG`, zero accepted AXI traffic | **PASS** in VCS |
| `dma_backpressure_test` | deterministic stalls + OOO R | no timeout, data/SVA clean | **PASS** in VCS |
| `dma_random_stress_test` | 20 constrained-random legal 1-D load/store commands | every command scores cleanly; replay through `SEED` | **PASS** in VCS |

## Four write-ID slot coverage increment (2026-10-18)

On the candidate based on parent `3014be4`, the focused `dma_store_four_booo_test` and full 17-test DMA UVM regression passed on Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`; all tests reported warning/error/fatal=`0/0/0`. The test holds four write responses pending, checks IDs `8..11` accepted and `11..8` completed, verifies all 32 DDR words, and requires the B-response window to drain. `ai_smoke` also passed. The write-response tracker now has 100% line and branch coverage in this suite; residual planner conditions and full DMA/V3 coverage disposition remain open. Exact commands, coverage metrics, and limits are in the [run record](../../../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-dma-four-write-id-slot-coverage-increment).

## Assertions

- AR, AW and W payload stability while back-pressured.
- DMA ARID/RID in 1–4; AWID/BID in 8–11.
- Every accepted AR and AW burst stays within a 4 KiB page.
- R/B control signals are known when valid.

`RLAST`, `WLAST` and response-order checks are also performed transactionally
by the BFM because they depend on the per-ID/per-burst history.

## Functional coverage

The command covergroup samples direction, 1-D/2-D shape, gather enable,
transfer size class, read outstanding depth and 4 KiB-crossing scenario, plus
a load-mode cross. The 2026-08-13 random-stress run reported 67.86%, and an
individual random-stress test may print 70%; neither is the regression aggregate.
The 2026-10-16 latest 15-test run reported 14/14 command
coverpoint bins and 5/5 transfer-mode cross bins. This closes only the bins
currently modeled by `dma_cmd_cg`, not DMA RTL code coverage. The corrected run
also collected all 11 DMA SVA with non-empty real successes and zero
failure/incomplete. See the
[A10 run record](../../../docs/verification/A10_DV_RUN_2026-10-16.md) for the
merged URG path and updated DUT-only code-coverage values.
The first focused `dma_spad_error_drain_test` attempt exposed a stale checker
expectation (`0x1200`); newest-first response ordering makes the first
destination line `0x1260`. The checker was corrected to derive that address
from the transfer geometry. The focused rerun and the full 15-test regression
both pass; the run record retains the first checker-only failure for traceability.

Broader closure should not be called until:

- every executable test passes with zero UVM errors/fatals;
- constrained-random variants add multiple seeds for each transfer mode;
- all meaningful coverpoint bins are hit or reviewed as unreachable;
- code/assertion coverage is merged with `make coverage` and reviewed.

## Regression commands

```bash
cd <repo>/dv/block/dma/sim
make uvm_smoke
make uvm_regress COV_ROOT=coverage/<run-tag>
make coverage COV_ROOT=coverage/<run-tag>
```

Both compile and simv must receive the same VCS `-cm` metrics. The regression
target passes `CM_METRICS` and `COV_DIR` to runtime and allows `COV_ROOT` to keep
each coverage campaign isolated. Do not treat a clean compile, an empty log, or
a single smoke as closure. The pass condition is the per-test UVM summary plus
scoreboard/SVA evidence and reviewed aggregate URG.

## Exact-main DMA planner-edge increment (2026-10-18)

The full DMA block regression now has 19 named tests. Both new directed tests
(`dma_4k_edge_load_test`, `dma_short_tail_store_test`) and the 19-test
regression passed with UVM warning/error/fatal=`0/0/0`; 20/20 randomized
transfers scored, URG merged, and top `ai_smoke` printed `TEST PASS`. The
planner boundary test proves the exact 4-KiB split from `0x1ff0`; the tail
test checks 1/2/3-word WSTRB masks and response drain. A first tail-test
attempt exposed an incorrect expected-mask formula in the testbench; after
correction, DUT data/masks and all regression checks passed. The pushed SHA
`264230a75bd5d4cba97b88dc592290e0f8892ef5` was then replayed with the 19-test
DMA suite, URG, and top smoke. That replay also passed and printed `TEST PASS`;
the evidence is exact-SHA reproducibility for this directed increment, not
closure of all DMA RTL coverage or V3/A10/V5. Commands, exact coverage, and
the failure disposition are in the
[A10 run record](../../../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-main-dma-planner-edge-replay-at-264230a).
