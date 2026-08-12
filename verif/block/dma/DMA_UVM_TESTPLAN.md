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

| Test | Stimulus | Checkers | Status on 2026-08-13 |
|---|---|---|---|
| `dma_load_ooo_smoke_test` | 32 words, four read IDs, newest-first R | highwater=4, OOO order, DDR→SPAD data, SVA | **PASS** in VCS |
| `dma_2d_load_test` | 3×6, DDR/SPAD stride | row-address and data scoreboard | **PASS** in VCS |
| `dma_gather_load_test` | 3×4, SPAD-held DDR row pointers | index addressing and data scoreboard | **PASS** in VCS |
| `dma_store_booo_test` | 16 words, two write bursts, newest-first B | AW/W/WLAST, BID order, SPAD→DDR data | **PASS** in VCS |
| `dma_2d_store_test` | 3×5 strided store | row-address and data scoreboard | **PASS** in VCS |
| `dma_narrow_load_test` | address offset 4, 7 words | narrow bus lane then line data | **PASS** in VCS |
| `dma_4k_load_test` | address `0x1fc0`, 40 words | no AR 4 KiB crossing, data | **PASS** in VCS |
| `dma_abort_read_test` | abort after accepted read work | `ERR_ABORT`, response drain, completion | **PASS** in VCS |
| `dma_config_error_test` | unaligned DDR source address | `ERR_CONFIG`, zero accepted AXI traffic | **PASS** in VCS |
| `dma_backpressure_test` | deterministic stalls + OOO R | no timeout, data/SVA clean | **PASS** in VCS |
| `dma_random_stress_test` | 20 constrained-random legal 1-D load/store commands | every command scores cleanly; replay through `SEED` | **PASS** in VCS |

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
a load-mode cross. The 2026-08-13 random-stress run reported 67.86% command
functional coverage; this confirms collection is live, not coverage closure.
Closure should not be called until:

- every executable test passes with zero UVM errors/fatals;
- constrained-random variants add multiple seeds for each transfer mode;
- all meaningful coverpoint bins are hit or reviewed as unreachable;
- code/assertion coverage is merged with `make coverage` and reviewed.

## Regression commands

```bash
cd /mnt/e/workspace/chip/CIMForge/verif/block/dma/sim
make uvm_smoke
make uvm_regress 2>&1 | tee dma_block_regress.log
make coverage
```

Do not treat a clean compile, an empty log, or a single smoke as closure. The
pass condition is the per-test UVM summary plus scoreboard/SVA evidence.
