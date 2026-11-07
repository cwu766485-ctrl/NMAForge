# AXI protocol VIP integration

The `dma_axi_vip_integration_test` connects the real `ai_axi128_dma` block as
an AXI4 manager to the reusable protocol-vips active AXI4 subordinate agent.
The project-owned `nmaforge_dma_axi4_pin_adapter.sv` maps the DMA's 64-bit
address, 128-bit data, and 4-bit ID pins; optional cache/protection/QoS pins
absent from this block interface are tied low at the adapter boundary.

The acceptance test uses the independent DMA block scoreboard together with
the VIP's active-slave driver, sparse memory, protocol checker, transaction
scoreboard, and coverage. Its 20 directed scenarios cover four outstanding
reads and writes (with observed cross-ID B reordering), 1-D/2-D/gather and narrow loads, 4-KiB boundary cases,
multi-burst/2-D/tail stores, VIP-memory readback, invalid configuration
rejection, injected read/write SLVERR, read/write abort drain, and delayed
responses. The test also requires the VIP's configured maximum burst length
to match this DUT instance's `MAX_BURST_BEATS=2`. The legacy DMA AXI responder
is disabled only for this dedicated test; all existing block tests continue
to use their original responder.

From Rocky Linux/WSL, with VCS configured and the VIP checkout available at
`/mnt/e/workspace/chip/vip`:

```sh
make -C dv/block/dma/sim uvm_vip_run \
  VIP_ROOT=/mnt/e/workspace/chip/vip \
  SEED=123 VCS='vcs -licwait 1'
```

The reviewed two-seed bridge regression is `protocol-vip-dma-vcs-regression`
in `tools/rocky-bridge.tasks.protocol-vip.json`.

The bridge runner requires all 20 actual `[DMA_AXI_VIP_CASE_PASS] case=...`
records (not the UVM report-summary count), zero UVM warning/error/fatal
counts, a gated total-pass marker, observed cross-ID B reordering, clean VIP
scoreboard accounting, and a passing original non-VIP compatibility smoke.
Per-scenario and total pass markers are suppressed when their checks fail.

## Expanded acceptance evidence

Validated against NMAForge integration commit `f348960` on
`feature/axi-vip-integration`, with AXI VIP source `3b4a975`, Rocky-8.10,
VCS `V-2023.12-SP1_Full64`, UVM 1.2, and seeds `123` and `98765`. Both seeds
passed the expanded matrix:

- 20/20 directed scenarios passed, including outstanding traffic, 1-D/2-D/
  gather and narrow loads, 4-KiB splitting, multi-burst and tail stores,
  VIP-memory readback, invalid configuration rejection, SLVERR, abort/drain,
  and backpressure.
- Per seed, the active AXI4 slave VIP completed 48 requests (33 reads, 15
  writes): zero outstanding, reset-aborted requests, scoreboard mismatches,
  or protocol-checker violations. UVM WARNING/ERROR/FATAL was `0/0/0`.
- Four writes were outstanding together. AW IDs `{8,9,A,B}` completed as B
  IDs `{9,A,B,8}`; the checker reported read/write peak outstanding `4/4` and
  cross-ID reorder counts `1/6`.
- The independent DMA block scoreboard matched every positive load/store
  payload; expected-error and abort cases completed with their expected status.
  DMA command functional coverage reported `100%` for this bounded test's
  modeled bins, which is not full DMA or protocol coverage closure. VIP AXI
  functional coverage was `37.32%`; configured sideband bins were not closed.
- Backward compatibility: the original non-VIP
  `dma_load_ooo_smoke_test` compiled from the standard filelist and passed at
  seed `123`, matching 32 words with UVM WARNING/ERROR/FATAL=`0/0/0`.

Raw compile, both seed logs, and legacy-flow logs are archived locally under
`dv/block/dma/artifacts/protocol-vip/20261107T050245Z/`; the artifacts are
intentionally not committed. Re-run the named bridge task to regenerate them.

This is real-DUT block-level evidence for `ai_axi128_dma` with AXI4
address/data/ID widths `64/128/4` and `MAX_BURST_BEATS=2`. It does not close
the full DMA feature matrix or qualify the full accelerator top, top-level
AXI-Lite control path, DDR PHY/controller, clock-domain crossings,
reset/fault combinations beyond these scenarios, physical timing, or tapeout
sign-off.
