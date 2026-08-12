# CIMForge subsystem-level verification

Subsystem tests verify real interactions among several RTL blocks.  They reuse
block BFMs/reference models and later reuse the UVM agents under `uvm_verif/`.
They must not bypass the ownership rules in `ai_accel_top`.

| Scope | Integrated path | Key checks |
|---|---|---|
| `dma_spad/` | DMA + protection + arbiter + scratchpad | line/word traffic, back-pressure, protection and data integrity |
| `queue_completion/` | command processor + descriptor fetch + completion writer | CMDQ/CPLQ ownership, dependency events and four-word atomic completion |
| `tensor_datapath/` | matrix/SFU/CNM + scratchpad | data-layout, tile flow, numerical checker and performance counters |
| `top_smoke/` | full `ai_accel_top` directed smoke | legacy AXI-Lite/AXI4, command-chain and Transformer micro-workload regression |

`top_smoke/` owns the legacy directed top-level smoke wrapper.  `uvm_verif/tb/`
owns the UVM top-level wrapper; they share RTL but do not duplicate UVM agents.
