# AXI protocol VIP integration

The `dma_axi_vip_integration_test` connects the real `ai_axi128_dma` block as
an AXI4 manager to the reusable protocol-vips active AXI4 subordinate agent.
The project-owned `nmaforge_dma_axi4_pin_adapter.sv` maps the DMA's 64-bit
address, 128-bit data, and 4-bit ID pins; optional cache/protection/QoS pins
absent from this block interface are tied low at the adapter boundary.

The acceptance test runs a 32-word DDR-to-SPAD load with four read requests in
flight, a SPAD-to-DDR store, and a readback from the VIP's sparse byte memory.
The existing DMA scoreboard checks the load and store words; reading the stored
data back also checks that the reactive memory model retained the accepted W
payload. The VIP independently runs its protocol checker, transaction
scoreboard, coverage, and active-slave response driver. The legacy DMA AXI
responder is disabled only for this dedicated test; all existing block tests
continue to use their original responder.

From Rocky Linux/WSL, with VCS configured and the VIP checkout available at
`/mnt/e/workspace/chip/vip`:

```sh
make -C dv/block/dma/sim uvm_vip_run \
  VIP_ROOT=/mnt/e/workspace/chip/vip \
  SEED=123 VCS='vcs -licwait 1'
```

The reviewed two-seed bridge regression is `protocol-vip-dma-vcs-regression`
in `tools/rocky-bridge.tasks.protocol-vip.json`.

## Acceptance evidence

Validated against NMAForge commit `f168a3dbbd53b3ba53aa996323c934629f5b4c9d`
on `feature/axi-vip-integration`, using Rocky-8.10, VCS
`V-2023.12-SP1_Full64`, UVM 1.2, seeds `123` and `98765`. Both seeds passed:

- AXI4 VIP reactive-memory scoreboard: 6 requests completed (5 reads, 1
  write), zero outstanding, reset-aborted requests, or mismatches.
- NMAForge block scoreboard: 32-word load, 4-word store, and 4-word readback
  all matched; three `[SB_PASS]` markers per seed.
- AXI protocol checker: zero violations; UVM WARNING/ERROR/FATAL: `0/0/0`.
- DMA command functional coverage: `60.48%` for this deliberately small
  acceptance sequence. This is not coverage closure.

Raw compile and per-seed logs are archived locally under
`dv/block/dma/artifacts/protocol-vip/`; the directory is intentionally not
committed. Re-run the named bridge task to regenerate them.

This evidence qualifies only a functional smoke slice of the AXI4 interface at
the `ai_axi128_dma` block boundary with the configured 64/128/4 profile. It
does not close the DMA feature matrix or qualify the full accelerator top,
AXI-Lite control path, DDR PHY/controller, clock-domain crossings,
reset/fault combinations beyond this test, physical timing, or tapeout
sign-off.
