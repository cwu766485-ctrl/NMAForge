# DMA block UVM

This is the first true block-level UVM environment for NMAForge. The DUT is
`rtl/dma/ai_axi128_dma.v`, not `ai_accel_top`.

## Architecture

The environment has one real DUT (`ai_axi128_dma`) and four independent
verification roles:

- `dma_cmd_driver`: presents a transfer descriptor and handles reset/abort;
- `dma_axi_read_responder`: a configurable AXI4 slave for AR/R and AW/W/B;
- `dma_spad_model`: a scalar/128-bit scratchpad model with optional stalls;
- `dma_axi_monitor` / `dma_spad_monitor`: passive protocol monitors that
  sample actual DUT handshakes independently of both active models;
- `dma_block_scoreboard`: checks every transfer word and owns functional
  coverage.  It does not assume that AXI responses are FIFO.

## Latest write-response slot result (2026-10-18)

`dma_store_four_booo_test` holds all four write responses pending, then returns IDs newest-first (`11,10,9,8`) after accepting `8,9,10,11`. The scoreboard checks all 32 DDR words and confirms the response window drains. The focused test, all 17 DMA UVM tests, URG merge, and top `ai_smoke` passed on Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`; per-test UVM warning/error/fatal was `0/0/0`. URG gives `ai_dma_write_response_tracker` 100% line and branch coverage, while condition coverage remains 66.67%; reachable burst-planner edge cases and broader V3 closure remain open. Artifacts are local under `/tmp/nmaforge_a10_dma_write4_3014be4_20261018/`. See the [A10 run record](../../../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-dma-four-write-id-slot-coverage-increment).

## Test matrix

| Test | Feature / intentional stress | Oracle / acceptance |
|---|---|---|
| `dma_load_ooo_smoke_test` | 1-D 128-bit load, four AR IDs, newest-first RID response | `rd_highwater=4`, first completed ID differs from first accepted ID, all 32 words match |
| `dma_2d_load_test` | 3 rows, independent DDR/SPAD strides | all row addresses and words match |
| `dma_gather_load_test` | SPAD index table selects three non-contiguous DDR rows | index read/address generation and output rows match |
| `dma_store_booo_test` | two write bursts and newest-first BID response | AW/W/WLAST plus every DDR word match; BID response is out of order |
| `dma_store_four_booo_test` | four tagged write bursts held until all four B responses are pending, then newest-first completion | exercises IDs 8–11, checks exact reverse BID order, drains the response window, and matches all 32 DDR words |
| `dma_2d_store_test` | strided 2-D SPAD-to-DDR store | all source/destination row strides match |
| `dma_aw_stall_stability_test` | force AWREADY low before publishing a four-word store, then hold it low for four complete AWVALID cycles | testbench checks AWVALID and `{AWID, AWADDR, AWLEN, AWSIZE, AWBURST}` remain stable while stalled; releases AWREADY, checks one AW/W/B completion, and scores every stored word; intended directed gate for DUT `p_aw_payload_stable` |
| `dma_narrow_load_test` | non-16-byte-aligned address | 32-bit alignment transfers then 128-bit line transfer match |
| `dma_4k_load_test` | transfer crosses a 4-KiB page | SVA proves no individual AR crosses the page; data matches |
| `dma_abort_read_test` | abort with accepted reads held in the responder | error code is `ERR_ABORT`; accepted R traffic drains before `done` |
| `dma_read_slverr_test` | SLVERR on the first newest-first burst after four ARs are accepted | all four read responses drain, destination sentinels do not change, no-reset recovery scores cleanly |
| `dma_spad_error_drain_test` | one-shot protection error on first newest-first destination line write (`0x1200 + 24×4 = 0x1260`) after four ARs are accepted | reports DMA-local `ERR_SPAD` code 4; all four RLASTs drain, destination sentinels stay unchanged, no response remains, no-reset recovery load scores cleanly; included in the 16-test exact-main regression PASS |
| `dma_write_slverr_test` | AXI BRESP SLVERR on one accepted store burst | reports `ERR_AXI_WR`; matching BID completes exactly once, no B remains pending, recovery load scores cleanly |
| `dma_abort_write_test` | abort after an accepted AW; delay B and then issue a recovery read | full accepted W burst and B drain before `done`; recovery command scores cleanly |
| `dma_config_error_test` | unaligned DDR address | `ERR_CONFIG`; absolutely no AXI transaction is accepted |
| `dma_backpressure_test` | deterministic AR/AW/W/SPAD stalls and RID reordering | no deadlock; scoreboard and SVA clean |
| `dma_random_stress_test` | 20 constrained-random legal 1-D load/store commands | each command scores cleanly; failing seed is replayable |

The already executed initial test is `dma_load_ooo_smoke_test`:

- configures a 32-word, 1-D DDR-to-scratchpad load;
- limits a burst to two 128-bit beats, forcing four AXI read IDs in flight;
- holds R traffic until all four ARs are accepted, then returns the newest
  accepted burst first and checks both `rd_highwater==4` and non-FIFO order;
- checks every scratchpad word against the address-derived DDR reference;
- asserts stable AR payload during back-pressure and DMA RID ranges 1..4.

Run one focused test in the WSL/VCS environment:

```bash
cd <repo>/dv/block/dma/sim
make uvm_smoke
```

`UVM_ERROR: 0` and `UVM_FATAL: 0`, together with `SB_PASS`, are the acceptance
criteria.  Run the complete DMA block regression after every DMA RTL/UVM
change:

```bash
make uvm_regress 2>&1 | tee dma_block_regress.log
grep -E 'UVM_(ERROR|FATAL).*[^0]|SB_(LOAD|STORE)_(COUNT|MISSING)|Error:' dma_block_regress.log
make coverage
```

An empty `grep` result, zero errors/fatals in every test, and a generated
`coverage/report/dashboard.html` are regression evidence.  Coverage numbers
are a closure input, not a substitute for the individual acceptance checks.

## Exact-current-main replay (2026-10-18)

At GitHub `main` SHA `3310d3d45cd9ed0168f7855eb253984c2a38387b`, Rocky 8.10
with VCS/URG `V-2023.12-SP1_Full64` passed all 16 tests and URG merge:

```bash
make -C dv/block/dma/sim uvm_regress \
  SIMV=simv_dma_a10_3310d3d \
  COV_ROOT=/tmp/nmaforge_a10_main3310d3d_dma_block_20261018/vdb
make -C dv/block/dma/sim coverage \
  COV_ROOT=/tmp/nmaforge_a10_main3310d3d_dma_block_20261018/vdb URG=urg
```

Each test had UVM warning/error/fatal=`0/0/0`; the random-stress test matched
all 20 commands. `dma_cmd_cg` reached 14/14 variables + 5/5 crosses. The
DUT-only `ai_axi128_dma` line/condition/toggle/FSM/branch coverage was
`93.48/71.04/36.69/53.57/86.92%`. These values are specific to the cited
RTL revision and are not a signoff claim. The exact log and assertion
disposition are recorded in
[`A10_DV_RUN_2026-10-18_MAIN452.md`](../../../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md).

## Exact-main planner-edge result (2026-10-18)

The DMA block suite now contains 19 tests. `dma_4k_edge_load_test` verified a
12-word transfer beginning at `0x1ff0` splits into AR bursts at `0x1ff0`
(`LEN=0`) and `0x2000` (`LEN=1`); `dma_short_tail_store_test` verified exact
WSTRB masks for 1/2/3-word writes and drained all three B responses. The two
focused tests and full 19-test UVM regression passed with per-test severity
`0/0/0`; 20/20 random transfers scored, URG merged, and top `ai_smoke` passed.
All 11 named DMA DUT SVA had real successes; two of 14 aggregate assertion
entries were unattempted UVM RAL internals, with no failures/incomplete. The
same 19-test suite, URG merge, and smoke were replayed at pushed SHA
`264230a75bd5d4cba97b88dc592290e0f8892ef5`: all 19 per-test severities were
`0/0/0`, random stress scored 20/20, and top `ai_smoke` printed `TEST PASS`.
This remains a directed slice, not complete DMA coverage or V3/A10/V5 closure.
Exact commands, assertion disposition, and coverage metrics are in the
[A10 run record](../../../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-main-dma-planner-edge-replay-at-264230a).
