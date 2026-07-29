# CIMForge software bring-up

## Transformer descriptor mapper

`tools/cimforge_mapper.py` generates a deterministic ABI-v7.2 descriptor graph,
scratchpad layout, simulation fixture and bit-accurate golden result for the
4-token Transformer micro-workload under `workloads/transformer_micro/`.

```bash
make -C ../verif/sim ai_transformer_gen
make -C ../verif/sim ai_transformer
```

The chain exercises Q/K/V projection, attention, residual/LayerNorm and FFN
composition. `CIMFORGE_DESC_F_PACK_I8` bridges element-wise INT32 outputs back
to the packed INT8 layout consumed by the matrix engine.

## XCZU15EG status

The current repository provides a reproducible standalone-IP
synthesis/place/route gate in
`fpga/xczu15eg/scripts/synth_ai_accel_ip.tcl`. The older board XSA, BSP,
bitstream and programming scripts are not part of the active tree, so this
README does not claim a clean-clone board deployment flow.

External AXI, DMA, tile and external command-queue addresses are 64-bit in ABI
v7.2. Compute tensor and completion addresses remain 32-bit scratchpad-relative
addresses by design.
