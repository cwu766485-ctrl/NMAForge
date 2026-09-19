# NMAForge commercial-28-nm pre-layout synthesis evidence

## Result summary

The current accelerator RTL was synthesized with a licensed commercial 28 nm
standard-cell library and real single-port SRAM macros at nominal PVT
(TT, 0.9 V, 25 °C). Under a 4.0 ns clock constraint, the recorded Design
Compiler run met zero setup and hold violations.

> This is a **250 MHz pre-layout synthesis closure point** for the documented
> RTL and constraints. It is not post-route timing sign-off, ASIC Fmax, or a
> workload-measured power claim.

## Publicly releasable configuration

| Item | Value |
|---|---|
| Top | `ai_accel_top` |
| RTL profile | AXI4-Lite control, 128-bit AXI4 DMA, four-bank 512 KiB scratchpad |
| Technology | Licensed commercial 28 nm library and SRAM macros |
| PVT | TT / 0.9 V / 25 °C |
| Clock period | 4.0 ns |
| Constraint | 100 ps setup uncertainty; 20 ps pre-CTS hold guard band |
| Memory implementation | 32 single-port SRAM macros arranged as four logical banks |
| Setup / hold result | WNS/TNS = 0.00/0.00 ns for both reported checks |

The macro names, timing-library identifiers, paths, library area units, raw
netlists and report databases are intentionally omitted because they are
licensed foundry collateral.

## Engineering observations

- The reported critical path crosses the scratchpad read path and the SFU
  accumulation/control region. Any frequency increase should first examine
  pipeline placement, post-SRAM mux depth and fixed-point accumulation depth.
- SRAM dominates the physical area of this 512 KiB profile. The largest logic
  contributors in the report were the unified AXI DMA, matrix engine and
  Conv3x3 line-buffer path.
- A default/partially annotated power estimate was generated during the study,
  but no public workload-power figure is claimed. A mapped SAIF/VCD workload,
  post-layout parasitics and a reviewed power methodology are required first.

## What remains before ASIC sign-off

- floorplan, SRAM placement, power grid and CTS;
- routed RC/SI, MMMC and OCV/AOCV/POCV STA;
- IR/EM, DFT and formal/LEC closure;
- workload-annotated power analysis and post-layout timing sign-off.

## Reproduction boundary

The private ASIC overlay contains the foundry library views, a macro adapter,
technology constraints and generated reports. It is deliberately excluded from
Git; see [`../syn/README.md`](../../syn/README.md). A public clone cannot
reproduce this exact run without independently licensed equivalent collateral.
