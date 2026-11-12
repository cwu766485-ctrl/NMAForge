# 128 KiB ASIC readiness

Status: **ASIC_MAPPING_BLOCKED**. This is a feasibility audit, not mapped synthesis or signoff.

`ai_scratchpad`: four banks × 8192 × 32 data bits = 131072 B, plus four banks × 8192 parity bits = 32768 bits (4096 B). Optional 32768-word banks elaborate to 512 KiB data. Host/debug owns port A; scheduler owns port B, with scalar/line/banked/CNM arbitration. Four 32-bit words form a 16 B line. Two registered cycles must be retained in any adapter.

Required macro contract: common-clock true dual port; 13-bit row addressing at 128 KiB; read-first behavior, byte-write masks and parity updated consistently with merged bytes; clock/enable gating; no array reset requirement but defined pipeline reset; simultaneous Host/scheduler collisions must be specified and checked against SPEC. An available single-port macro cannot implement this contract for free. Added banking/replication/cycles would need a new architecture review.

Parity is explicit in the VCS behavioral branch. The XPM branch drives parity-error outputs to zero: FPGA XPM is not evidence of a fault-preserving ASIC macro implementation. Macro data/parity organization, byte-mask RMW behavior and read/write collision handling remain blocking adapter work.

DC V-2023.12-SP1 is installed. `TSMC28_STDCELL_DB`, `TSMC28_SRAM_DB_TT`, `TSMC28_SRAM_DB`, and `TSMC28_SRAM_VERILOG` are unset. Public `syn/README.md` states private macros/libraries/wrappers are excluded. No authorized compatible 128 KiB macro mapping or characterized timing constraints were provided. Therefore mapped DC, area, setup critical paths and activity power were not run. Old 512 KiB reports are not substituted. No foundry/license assets were copied.

Potential paths requiring real STA: SPAD selection→permission→admission, matrix postprocess→packing, operand/cache selection, SFU arithmetic. Functional 4 ns simulation is not achieved Fmax; 400 MHz/2.5 ns remains unproven. Representative activity must be regenerated after macro mapping and annotated into a legitimate power flow.

Remaining physical work: DFT/MBIST, floorplan, placement, CTS, route, extraction, MMMC setup/hold STA, CDC/RDC release signoff, power, IR/EM and physical verification. **PHYSICAL SIGNOFF NOT DONE**.
