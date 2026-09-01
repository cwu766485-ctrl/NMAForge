# Xilinx A7 100T FPGA Bring-up Framework

This folder stages the current `ai_accel_top` IP for synthesis and first board
bring-up on the Artix-7 100T FGG484 hardware described under `docs/hardware/`.

## What is included

- `rtl/fpga_ai_accel_smoke_top.v`: board-level smoke top using the 50 MHz
  oscillator net `FPGA_SYSCLK_50M`.
- `rtl/axi_lite_bringup_master.v`: a tiny synthesizable AXI4-Lite master that
  writes a VDOT INT8 test into scratchpad, starts the accelerator, polls
  `STATUS`, and checks `RESULT` plus the scratchpad output word.
- `constraints/a7_100t_smoke.xdc`: clock and LED constraints derived from the
  Allegro netlist.
- `scripts/synth_ai_accel_ip.tcl`: Vivado out-of-project synthesis for the raw
  AI accelerator IP.
- `scripts/synth_smoke_top.tcl`: Vivado out-of-project synthesis for the FPGA
  smoke wrapper.
- `scripts/build_smoke_bitstream.tcl`: implementation plus bitstream build for
  the smoke wrapper.
- `scripts/program_smoke_bitstream.tcl`: Vivado hardware-manager download for
  the generated bitstream.

## LED behavior

- `user_led[0]`: heartbeat.
- `user_led[1]`: smoke test pass.
- `user_led[2]`: blinks while the bring-up sequencer is running, then stays on
  if the smoke test fails.

The smoke test uses only AXI4-Lite and scratchpad accesses. The accelerator
AXI master port is tied off because this first board step does not exercise
DMA, external descriptor fetch, DDR3, or MIG.

## Run synthesis

From a Vivado-enabled PowerShell:

```powershell
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target ip
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target smoke
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target bitstream
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target program
```

The script finds `vivado` from `PATH` or `VIVADO_HOME`. For another
installation, pass the executable explicitly:

```powershell
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target bitstream -VivadoPath '<vivado-install>\bin\vivado.bat'
```

Override the device if your board is populated differently:

```powershell
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target smoke -Part xc7a35tfgg484-2
```

`program` programs the generated bitstream through the single FPGA visible to
Vivado Hardware Manager. It refuses to choose a device when multiple JTAG
devices are present. For a remote hardware server, pass your local endpoint:

```powershell
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target program -HwServerUrl <host>:3121
```

Reports are written under:

- `fpga/xilinx_a7_100t/build/ip_synth/reports`
- `fpga/xilinx_a7_100t/build/smoke_synth/reports`
- `fpga/xilinx_a7_100t/build/smoke_bitstream/reports`

## Hardware notes

- Use `FPGA_SYSCLK_50M` as the application clock. The netlist maps it to U1
  `W19`.
- Do not use `FPGA_CLK` as a logic clock; the hardware netlist maps it to
  `TCK_0`/JTAG.
- The enabled LED pins are derived from D2/D3/D4 through R13/R14/R15:
  `F20`, `D21`, and `E21`.
- D1 is tied to the configuration `DONE` path and is intentionally not used as
  a user LED.

## Next bring-up step

After this smoke top synthesizes, the next useful FPGA layer is an AXI BRAM or
MIG-backed memory subsystem connected to the accelerator master AXI port. That
will let the board test external descriptor fetch and DMA paths instead of only
the scratchpad compute path.
