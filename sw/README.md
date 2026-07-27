# CIMForge software bring-up

Generate the standalone A53 BSP/application and matching ZynqMP FSBL from the
current board XSA with:

```powershell
fpga\xczu15eg\scripts\build_baremetal.ps1
```

The HSI-based flow copies `baremetal/cimforge_bringup.c` and
`include/cimforge_regs.h`, links all DMA/descriptor buffers below 4 GiB and
produces both ELFs under `fpga/xczu15eg/build/baremetal`. It does not require
the removed Classic Vitis IDE.

The hardware control aperture is fixed at `0xA0000000` by `build_board.tcl`;
override `CIMFORGE_BASE_ADDR` only if the block-design address map is
intentionally changed.

The default hardware exposes a 512 KiB host scratchpad window at
`CIMFORGE_BASE_ADDR + 0x10000`; software should read `SPAD_INFO` at register
offset `0x164` instead of assuming the capacity. The complete PS aperture is
1 MiB (`0xA0000000..0xA00fffff`).

The test verifies version readback, cache-maintained PS-DDR DMA load/store, an
external descriptor ring, VDOT execution, scratchpad completion publication,
timeouts, diagnostic error readback and the actual PL-to-PS IRQ through the
GIC. Static DDR objects must link below 4 GiB because descriptor and DMA
addresses are 32-bit in A2.

With the board powered and the PS UART free, deploy and run it using:

```powershell
fpga\xczu15eg\scripts\run_baremetal.ps1 -Port COM11
```

See `docs/XCZU15EG_BRINGUP.md` for the full connection, recovery and acceptance
procedure.
