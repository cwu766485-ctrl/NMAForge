# AXI4-Lite VIP acceptance — NMAForge CSR top

## Scope and source identity

This is a bounded real-DUT integration test of the AXI4-Lite Master VIP against
the CSR slave in `ai_accel_top`, through the project-owned pin adapter. The
NMAForge integration branch is `feature/axi-vip-integration` at testbench
commit `1b15584`; the VIP source used by the run is `56eab2b` from
`feature/vip-productization`. The data-master interface at the top is tied off
for this test.

The test exercises legal CSR reads/writes, independent AW/W timing (including
W-before-AW), delayed BREADY/RREADY, and expected SLVERR responses for
unaligned, unmapped, read-only, and partial-WSTRB accesses.

## Result

Rocky Linux 8.10, Synopsys VCS `V-2023.12-SP1_Full64`, UVM 1.2:

| Seed | Result | Timing observation | Transaction accounting |
|---:|---|---|---|
| 20261107 | PASS | AW-only=2, W-only=2, B-stall=11, R-stall=11 cycles | 8/8 complete; 4 reads + 4 writes; outstanding/reset-aborted/mismatches `0/0/0` |
| 20261108 | PASS | AW-only=2, W-only=2, B-stall=11, R-stall=11 cycles | 8/8 complete; 4 reads + 4 writes; outstanding/reset-aborted/mismatches `0/0/0` |

Both runs emitted `NMA_AXIL_VIP_TIMING_PASS` and `NMA_AXIL_VIP_CSR_PASS`.
AXI stability and X/Z-control/payload checks, reset checks, burst checks,
write-strobe checks, unexpected-response counts, and checker violations were
zero. UVM WARNING/ERROR/FATAL counts were `0/0/0`. The sampled generic AXI and
AXI4-Lite PROT coverage summaries were 30.93% and 41.67%, respectively; these
are not coverage-closure claims.

Run logs from the acceptance run:

- `/tmp/nmaforge_axi_lite_vip_20261107T085338Z/run_seed_20261107.log`
- `/tmp/nmaforge_axi_lite_vip_20261107T085338Z/run_seed_20261108.log`
- `/tmp/nmaforge_axi_lite_vip_20261107T085338Z/compile.log`

Reproduce from this checkout in the configured Rocky WSL environment with:

```bash
bash tools/run_protocol_vip_axil_regression.sh
```

## Acceptance boundary

This result accepts only the tested CSR pin/configuration slice. It does not
cover the complete CSR map, reset during outstanding transfers, interrupt
behavior, the AXI4 data path, DMA, CDC, compute behavior, or whole-chip
coverage closure. It is not ASIC/tapeout signoff.
