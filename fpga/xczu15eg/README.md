# XCZU15EG FPGA integration

This flow targets `xczu15eg-ffvb1156-2-i` with a single 100 MHz PL clock.
CIMForge is connected as an AXI system component, not as a pin-level naked
RTL top:

```text
PS M_AXI_HPM0_FPD -> SmartConnect -> CIMForge S_AXI (AXI4-Lite control)
CIMForge M_AXI    -> SmartConnect -> PS S_AXI_HP0_FPD -> PS DDR4
CIMForge irq      -> pl_ps_irq0
PS pl_clk0/reset  -> proc_sys_reset -> all PL AXI logic
```

The PS DDR/MIO configuration is cloned from the board vendor's known-good
`mem_test.xpr` under `docs/hardware/xczu15eg`. This avoids guessing custom
DDR4, QSPI, eMMC, USB, Ethernet, MIO and clock parameters.

## Standalone IP closure

Run from the repository root with Vivado 2024.1:

```powershell
& 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat' -mode batch `
  -source fpga\xczu15eg\scripts\synth_ai_accel_ip.tcl
& 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat' -mode batch `
  -source fpga\xczu15eg\scripts\implement_ai_accel_ip.tcl
```

The first command performs out-of-context synthesis. The second runs
optimization, placement, routing, post-route setup/hold analysis, DRC,
methodology and power reporting. It exits with an error if either setup or
hold slack is negative. Reports stay under ignored `build/` directories.

The current 512 KiB profile closes post-route at 100 MHz with setup/hold
slack `+0.836/+0.023 ns` and uses 7,780 LUTs, 4,952 FFs and 128 RAMB36E2.

## Board project, bitstream and XSA

```powershell
fpga\xczu15eg\scripts\run_board_build.ps1
```

`build_board.tcl` creates a fresh block design, assigns a 1 MiB control
aperture at `0xA0000000`, builds the bitstream, exports an XSA and writes ILA
probes for IRQ and accelerator-driven AXI handshakes. The aperture includes the
register page and the default 512 KiB host scratchpad window at offsets
`0x10000..0x8ffff`.

The current full-board build uses 17,624 LUTs, 19,274 FFs and 152 RAMB36E2,
closes setup/hold at `+1.625/+0.012 ns`, and produces the bitstream, XSA and
LTX under the ignored `build/board` directory.

For a fast PS/interface/address-map check without synthesis:

```powershell
$env:CIMFORGE_VALIDATE_ONLY = '1'
fpga\xczu15eg\scripts\run_board_build.ps1
Remove-Item Env:CIMFORGE_VALIDATE_ONLY
```

The script expects this reference by default:

```text
docs/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.xpr
```

Override it without editing tracked files:

```powershell
$env:CIMFORGE_VENDOR_XPR = 'D:\board\mem_test\mem_test.xpr'
fpga\xczu15eg\scripts\run_board_build.ps1
```

Generated deliverables are:

- `build/board/cimforge_board.runs/impl_1/*.bit`
- `build/board/cimforge_board.xsa`
- `build/board/cimforge_board.ltx`
- `build/board/reports/` timing, utilization, DRC, methodology and power

## Bare-metal build and board deployment

Build an XSA-matched A53 FSBL and bring-up ELF without requiring the Classic
Vitis IDE:

```powershell
fpga\xczu15eg\scripts\build_baremetal.ps1
```

After connecting and powering the board, run the complete JTAG + UART test:

```powershell
fpga\xczu15eg\scripts\run_baremetal.ps1 -Port COM11
```

The test validates version/capacity readback, cache-maintained DDR DMA
load/store, external descriptor execution, scratchpad completion, VDOT result
and the real PL-to-PS GIC interrupt path. A CPU-independent DAP diagnostic is
also available as `scripts/run_jtag_validate.ps1`; `scripts/run_verify_ila.ps1`
checks the LTX/debug-core match without accessing the PS/DAP. See
`docs/XCZU15EG_BRINGUP.md` and `sw/README.md` for acceptance evidence and
recovery steps.

## Memory and reset rules

- Current AXI address/data ports are 32 bit. Allocate descriptor/data buffers
  below 4 GiB or add a future 64-bit address extension before using high DDR.
- `ai_scratchpad` uses registered XPM true-dual-port RAM in Vivado synthesis;
  `+define+VCS` selects the behavioral simulation model. The XCZU15EG/default
  profile is 4 banks x 32768 words x 32 bits = 512 KiB; the depth is controlled
  by `ai_accel_top.SPAD_WORDS_PER_BANK`.
- Accepted AXI bursts are never truncated. Abort drains an accepted read to
  `RLAST`; an accepted write completes all W beats and B response first.
- Do not use a PL-only asynchronous reset during a live PS AXI transaction.
  The board flow distributes the PS reset through `proc_sys_reset` to the
  accelerator and its AXI interconnects.
