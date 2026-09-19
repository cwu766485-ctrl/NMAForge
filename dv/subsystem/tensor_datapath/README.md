# Tensor datapath subsystem verification

This subsystem combines the matrix engine, SFU, CNM path, scratchpad arbiter,
and tile-pipeline ownership signals.  It is deliberately below the full
`ai_accel_top` level: no AXI-Lite software model or DDR responder is needed.

- `ref/` holds fixed-point tensor/SFU reference calculations.
- `assertions/` holds ownership, launch/done, and buffer-handoff properties.
- `tb/` and `tests/` hold focused SystemVerilog/UVM wrappers and tests.
- `sim/` holds local filelists and make targets.

Reusable AXI items and agents remain in `dv/uvm/`.
