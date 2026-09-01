# NMAForge RTL hierarchy

`ai_accel_top.v` is the only chip-IP top.  Every other directory is a
subsystem with a small number of explicit ownership boundaries; module names
and ports are unchanged by this directory layout.

```text
rtl/
├── top/
│   ├── ai_accel_top.v                 # IP top: external AXI-Lite and AXI4 ABI
│   └── fabric/
│       ├── axi/                       # AXI arbitration, descriptor/DMA source muxes
│       ├── control/                   # AXI-Lite protocol and response integration
│       ├── memory/                    # optional SPAD wiring wrappers and response demux
│       └── compute/                   # compute-engine instance and completion aggregation
├── control/
│   ├── axi_lite/                      # axi_lite_reg_if, ai_accel_regs
│   ├── queue/                         # command lifecycle, completion, pointers, performance
│   └── descriptor/                    # SPAD/AXI fetch, opcode decode, validation
├── dma/                               # ai_axi128_dma owner plus planner/tracker/adapter helpers
├── memory/                            # scratchpad, sole scheduler arbiter, protection
└── compute/
    ├── int8/                          # scalar INT8 core and pure datapath
    ├── cnm/                           # bank-local CNM core/controller/PE
    ├── matrix/                        # 4x4 tensor FSM and datapath
    ├── sfu/                           # tensor SFU FSM and fixed-point math
    ├── common/                        # divider and square-root units
    ├── cnn/                           # line-buffer convolution primitive
    ├── kv/                            # KV-cache addressing engine
    └── pipeline/                      # load/compute/store tile overlap controller
```

## Ownership rules

- `top/ai_accel_top.v` integrates only; it does not own queue, DMA or
  scratchpad scheduling state.
- `control/queue/ai_command_processor.v` owns command/completion lifecycle
  and queue-pointer advancement.
- `memory/ai_spad_arbiter.v` is the sole owner of the scheduler-side
  scratchpad port.
- `dma/ai_axi128_dma.v` owns AXI DMA lifecycle, ID/outstanding accounting and
  abort drain; its helper files are combinational or bookkeeping-only.
- Compute cores own their FSMs and registered scratchpad timing.  Adjacent
  datapath/math files remain stateless helpers.

All source lists are authoritative build inputs.  When moving or adding a
synthesizable file, update the smoke, UVM, SpyGlass and both FPGA source lists
named in `../AGENTS.md`.
