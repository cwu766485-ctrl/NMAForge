# NMAForge block-level verification

This tree owns block-scope test plans, lightweight BFMs, reference models,
assertions and run recipes.  It does not duplicate reusable UVM classes:
protocol agents and common UVM infrastructure stay in `../../dv/uvm/`.

| Scope | DUT | First test objective |
|---|---|---|
| `dma/` | `ai_axi128_dma` | 1D load/store before 2D, gather, 4 KiB, abort and ID reordering |
| `spad_arbiter/` | `ai_spad_arbiter` | priority, round-robin, response routing and starvation bounds |
| `command_processor/` | `ai_command_processor` | descriptor lifecycle, dependencies, launch and error recovery |
| `control/` | AXI-Lite interface + register file | register semantics, WSTRB, reset, status/IRQ and invalid access |
| `compute/` | CNM, matrix, SFU, CNN/KV blocks | bit-accurate directed/random data-path checking |

Every block begins with a deterministic directed test and reference model.
Only protocol/state-machine-heavy blocks graduate to a dedicated UVM environment.
