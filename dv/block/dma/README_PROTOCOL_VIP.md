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

The bridge runner requires all 20 `[DMA_AXI_VIP_CASE_PASS]` markers on each
seed and retains the original non-VIP regression as a compatibility guard.
The expanded matrix is not accepted until that runner has been re-executed
against the pushed source commit; the historical evidence below is for the
earlier three-operation smoke only.

## Acceptance evidence

Validated against NMAForge code commit `ca00325` on
`feature/axi-vip-integration`, using Rocky-8.10, VCS
`V-2023.12-SP1_Full64`, UVM 1.2, seeds `123` and `98765`. Both seeds passed:

- AXI4 VIP reactive-memory scoreboard: 6 requests completed (5 reads, 1
  write), zero outstanding, reset-aborted requests, or mismatches.
- NMAForge block scoreboard: 32-word load, 4-word store, and 4-word readback
  all matched; three `[SB_PASS]` markers per seed.
- AXI protocol checker: zero violations; UVM WARNING/ERROR/FATAL: `0/0/0`.
- Backward compatibility: the original `dma_load_ooo_smoke_test` compiled
  with the non-VIP filelist and passed at seed `123`, matching 32 words with
  UVM WARNING/ERROR/FATAL=`0/0/0`.
- DMA command functional coverage: `60.48%` for this deliberately small
  acceptance sequence. This is not coverage closure.

Raw compile and per-seed logs are archived locally under
`dv/block/dma/artifacts/protocol-vip/20261105T123640Z/`; the artifacts are
intentionally not committed. Re-run the named bridge task to regenerate them.

This evidence qualifies only a functional smoke slice of the AXI4 interface at
the `ai_axi128_dma` block boundary with the configured 64/128/4 profile. It
does not close the DMA feature matrix or qualify the full accelerator top,
AXI-Lite control path, DDR PHY/controller, clock-domain crossings,
reset/fault combinations beyond this test, physical timing, or tapeout
sign-off.
