# Directed top-level smoke regression

This directory owns the pre-UVM, executable system smoke for the real
`ai_accel_top` RTL:

- `sim/` contains the VCS/Questa filelists, Makefiles and Linux smoke script;
- `tb/` contains `tb_ai_accel_smoke.sv`;
- `env/` contains top-level SVA;
- `fixtures/` contains the generated deterministic Transformer workload.

Run it from `sim/` with `make ai_smoke`, `make ai_quick`, or
`make ai_transformer`.  Focused block tests belong under `dv/block/`;
UVM top-level tests belong under `dv/uvm/`.
