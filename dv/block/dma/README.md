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

## Test matrix

| Test | Feature / intentional stress | Oracle / acceptance |
|---|---|---|
| `dma_load_ooo_smoke_test` | 1-D 128-bit load, four AR IDs, newest-first RID response | `rd_highwater=4`, first completed ID differs from first accepted ID, all 32 words match |
| `dma_2d_load_test` | 3 rows, independent DDR/SPAD strides | all row addresses and words match |
| `dma_gather_load_test` | SPAD index table selects three non-contiguous DDR rows | index read/address generation and output rows match |
| `dma_store_booo_test` | two write bursts and newest-first BID response | AW/W/WLAST plus every DDR word match; BID response is out of order |
| `dma_2d_store_test` | strided 2-D SPAD-to-DDR store | all source/destination row strides match |
| `dma_narrow_load_test` | non-16-byte-aligned address | 32-bit alignment transfers then 128-bit line transfer match |
| `dma_4k_load_test` | transfer crosses a 4-KiB page | SVA proves no individual AR crosses the page; data matches |
| `dma_abort_read_test` | abort with accepted reads held in the responder | error code is `ERR_ABORT`; accepted R traffic drains before `done` |
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
