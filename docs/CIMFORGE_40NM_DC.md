# CIMForge 40 nm Design Compiler profile

## Purpose and scope

`syn/dc_ai_accel_40nm.tcl` synthesizes the AXI AI accelerator with the
available TSMC40 standard-cell `.db`. It is a pre-layout ASIC PPA study, not
an FPGA result and not ASIC sign-off.

The 512 KiB scratchpad is four 32K x 32 common-clock TDP banks. The FPGA
implementation uses Xilinx XPM RAM, which cannot be used as an ASIC memory
model. `syn/ai_scratchpad_asic_macro.v` therefore supplies an ASIC-only
adapter containing four `cimforge_sram_32kx32_tdp` black boxes. This preserves
the accelerator's memory ports, bank muxes, registered read-bank selection,
and macro hierarchy without allowing DC to infer 512 KiB of flip-flops.

## Current limitation

No matching 32K x 32 TDP SRAM macro `.db` was confirmed in the accessible
TSMC40 tree. Consequently the run measures standard-cell logic area/timing
and the logic around memory boundaries only. It excludes SRAM macro area,
leakage and internal access timing. Do not quote it as full-chip area or final
Fmax.

When a macro is available, replace only `cimforge_sram_32kx32_tdp` with the
foundry wrapper, add its `.db` to `link_library`, and keep the wrapper's
common-clock, two-cycle-read microarchitecture unchanged.

## Run in Rocky WSL

```bash
cd ~/ic/CIMForge
cp -a /mnt/e/workspace/chip/CIMForge/syn/. syn/
cp -a /mnt/e/workspace/chip/CIMForge/docs/CIMFORGE_40NM_DC.md docs/

# The environment already provides this library path on the configured host.
test -f "$TSMC40_LIB_TC"

# One point, period in ns.
bash syn/run_ai_accel_40nm_dc.sh 5.0
```

The wrapper accepts a run only when its log ends with `CIMForge DC completed:`;
otherwise it returns non-zero. It writes setup and min-delay reports separately
as `timing.rpt` and `hold_timing.rpt`.

For a sweep, use separate output directories, for example 5.0, 3.33, 2.5,
2.0 and 1.67 ns. A point is feasible only when the timing report has no
negative slack. Add margin before reporting a maximum frequency.

## Current measured reference point

The checked-in flow was run at 4.0 ns with the available `NCCOM` TSMC40
standard-cell view and 0.10 ns clock uncertainty. After the hold-only
incremental repair it reported setup WNS/TNS = 0.00/0.00 ns, hold WNS/TNS =
0.00/0.00 ns and zero transition/capacitance violations. Standard-cell area
was 245,394.28 library units (95,423 leaf cells); macro area is deliberately
zero because all four SRAM instances are black boxes. This supports a
250 MHz *pre-layout logic* feasibility statement only, not a full-chip Fmax
or power/area number.

## Required reporting discipline

Report the selected library/PVT, clock period, uncertainty, I/O delays,
black-box SRAM limitation, DC WNS/TNS, standard-cell area and power assumptions.
Only post-place-and-route STA with extracted parasitics can establish a final
ASIC frequency.
