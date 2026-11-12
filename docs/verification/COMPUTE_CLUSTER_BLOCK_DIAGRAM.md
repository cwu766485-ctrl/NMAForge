# Compute Cluster and Top Block Diagrams

**RTL baseline:** `fc60f95d72c0cfb7dfa9df895a30a701c842d21e`. These diagrams show modules instantiated in that RTL only. Signals and widths are taken from top and submodule ports; they do not add the planned macro wrapper or an unimplemented fabric epoch.

## 1. Full NPU Top Architecture

```mermaid
flowchart LR
  CPU[SoC CPU] -->|AXI-Lite 32b AW/W/B + AR/R valid-ready| AXIL[axi_lite_reg_if]
  AXIL -->|reg request/response 32b| REG[ai_accel_regs]
  REG -->|submit abort launch config IRQ| CTRL[Control and Queue Fabric]
  CTRL -->|CMDQ descriptors 16 x 32b| FETCH[ai_desc_fetch or axi_desc_fetch]
  CTRL -->|issue per engine slot| DISP[ai_parallel_compute_dispatcher]
  DISP -->|launch fields latched at start| CL[ai_accel_compute_cluster]
  DISP -->|ordered result FIFO| CPL[ai_completion_writer]
  DDR[(External DDR / memory)] <-->|AXI4 128b data, 64b addr, 4b ID, valid-ready| DMA[ai_axi128_dma]
  DMA -->|scalar/line requests| ARB[ai_spad_arbiter]
  FETCH -->|descriptor reads| ARB
  CPL -->|four completion word writes| ARB
  CL -->|7 ordinary scalar clients through compute mux; Matrix line and banked; CNM lanes| ARB
  ARB <-->|scheduler Port B; response owner + registered data/error| SPAD[ai_scratchpad\n4 banks x 8192 x 32b default]
  CPU -->|AXI-Lite SPAD aperture / host Port A| SPAD
  SPAD -->|registered response/data/parity| ARB
  ARB -->|owner-tagged response| CL
  REG -->|sticky IRQ| IRQ[irq]
```

RTL basis: `rtl/top/ai_accel_top.v:24`, `:595`, `:628`, `:663`, `:1131`, `:1194`, `:1266`, `:1406`; AXI widths at module ports `:37..152`.

## 2. Compute Cluster Microarchitecture

```mermaid
flowchart TB
  DISP[Dispatcher launch\nvalid pulse + latched fields] --> SEL[Opcode classification in top]
  SEL --> INT8[Scalar INT8\n0x10-0x17]
  SEL --> FP[Mixed FP\n0x50/0x51]
  SEL --> CNM[CNM\n0x20/0x21]
  SEL --> MAT[Matrix\n0x30/31/52/53]
  SEL --> SFU[Tensor SFU\n0x32-0x39]
  SEL --> CNN[Conv line buffer\n0x16/0x17]
  SEL --> KV[KV Cache\n0x43/0x44]
  INT8 -->|32b valid/write/address/data; ready; registered response| MUX[ai_compute_spad_mux\n7 x 32b requester lanes]
  FP --> MUX
  SFU --> MUX
  CNN --> MUX
  KV --> MUX
  MAT -->|32b scalar requests| MUX
  MUX -->|one selected request/owner| ARB[ai_spad_arbiter CORE class]
  MAT -->|banked 32b word address; four 32b bank returns| ARB
  MAT -->|128b line write + 16b WSTRB| ARB
  CNM -->|4 independent valid/ready lanes + 4 x 32b address| ARB
  INT8 -.->|busy/done/error/code/result/cycles/elements| DISP
  FP -.-> DISP
  CNM -.-> DISP
  MAT -.-> DISP
  SFU -.-> DISP
  CNN -.-> DISP
  KV -.-> DISP
```

The compute wrapper exports seven independent status vectors, with 7 busy/done/error bits, 28 error-code bits and 224 bits each for result/cycles/elements (`rtl/top/fabric/compute/ai_accel_compute_cluster.v:133..141`, `:184..204`). The aggregate `core_done` view is a serial compatibility signal and does not preserve multiple simultaneous completion identities (`:166..182`).

## 3. Shared SPAD Request/Response Dataflow

```mermaid
sequenceDiagram
  participant E as Engine client
  participant CM as ai_compute_spad_mux (ordinary clients)
  participant A as ai_spad_arbiter
  participant P as ai_scratchpad Port B
  E->>CM: valid + write/address/data
  CM->>A: selected owner + 32b request
  A-->>CM: ready only to selected owner
  A->>P: scheduler request (one accepted transaction/class)
  P-->>A: data + parity/error after registered memory latency
  A-->>CM: rsp_valid + captured response owner + error
  CM-->>E: response routed only to accepted owner
```

Banked side paths are separate interfaces but share admission: Matrix banked-read uses tag 3, CNM uses tag 5 and a registered per-lane response mask. They alternate in the same banked RR class. Line responses are distinguished by `rsp_is_line`. There is no response-ready or arbitrary response ID at these interfaces (`rtl/memory/ai_spad_arbiter.v:47..65`, `:143..177`).

## 4. Command Dispatch and Completion Lifecycle

```mermaid
sequenceDiagram
  participant SW as Software
  participant D as ai_parallel_compute_dispatcher
  participant F as Descriptor fetch + validator
  participant E as One of seven engines
  participant W as ai_completion_writer
  participant S as ai_spad_arbiter / SPAD
  SW->>D: publish CMDQ_TAIL / submit
  D->>F: fetch CMDQ_HEAD descriptor
  F-->>D: descriptor fields / fetch error
  D->>D: validate, wait dependency, reserve one engine slot and FIFO record
  D->>E: one-cycle launch_valid; engine latches fields
  E-->>D: independent done/error/result/cycle/elements
  D->>D: capture by engine slot; retire only FIFO head
  D->>W: task/status/error/result/elements
  W->>S: four 32-bit completion words, each valid/ready
  W-->>D: done after all four accepted
  D->>SW: advance CPLQ_TAIL; emit ordered event / dependency signal
  SW->>D: may advance CPLQ_HEAD while engines remain active (SPEC v1.8)
```

The result FIFO has eight slots; dispatch is one active slot per engine and completion retires in CMDQ order even if engines finish out of order (`rtl/control/queue/ai_parallel_compute_dispatcher.v:134..146`, `:395..428`). Completion storage is four words; tail advancement belongs to the dispatcher after writer done.

## 5. DMA → SPAD → Compute → Output Dataflow

```mermaid
flowchart LR
  DDR[(DDR)] -->|AXI4 AR/R: 128b, ID tagged, max 16 beats and 4KiB split| DMA[ai_axi128_dma]
  DMA -->|32b scalar or 128b line valid/ready| ARB[ai_spad_arbiter]
  ARB -->|Port B scheduler writes| SPAD[4-bank SPAD]
  SPAD -->|registered 32b, banked 4x32b or line 128b| ARB
  ARB -->|owner-tagged response| ENG[Selected Compute Engine]
  ENG -->|accepted scalar / line output writes| ARB
  ARB --> SPAD
  SPAD -->|store source| DMA
  DMA -->|AXI4 AW/W/B: 128b + WSTRB + ID| DDR
  ENG -->|done, result, error, cycles, elements| RETIRE[Ordered completion FIFO]
  RETIRE -->|four 32b words| SPAD
```

This is a shared scheduler port. Compute and DMA can overlap in execution but their SPAD requests contend at admission. Software must prevent concurrent read/write address hazards across descriptors (REQ-PC-008). Accepted writes form an irreversible visible prefix; DMA store completion and compute completion are distinct transactions.

## 6. Clock / Reset / Abort / Fault Domains

```mermaid
flowchart TB
  CLK[Single active top clock: aclk] --> AXIL[AXI-Lite + registers]
  CLK --> QUEUE[Dispatcher / command processor / completion]
  CLK --> DMA[DMA and AXI request state]
  CLK --> ARB[SPAD mux / arbiter / protection response tags]
  CLK --> RAM[Behavioral/XPM scratchpad pipelines]
  CLK --> ENGINES[Seven compute engines]
  RST[aresetn, async active-low assertion] -.->|clears state/valid ownership| QUEUE
  RST -.-> DMA
  RST -.-> ARB
  RST -.-> ENGINES
  ABORT[core_abort] -->|stop new issue + notify active engines; drain accepted work| QUEUE
  ABORT --> DMA
  ABORT --> ENGINES
  PARITY[Parity fault] -->|client-tagged read response or lane error| ARB
  PROT[Protection denial] -->|request class/owner-qualified error| ARB
  WATCH[Per-engine watchdog] -->|engine-specific frozen error priority| ENGINES
  FAB[External AXI fabric] -.->|must be coordinated reset or drained; no RTL epoch tag| DMA
```

The active top is single-clock; standalone dual-clock command shell modules do not become active domains in this top. Reset is not a memory clear. External AXI responses must not cross a reset boundary into new accelerator work; that guarantee is an integration contract and needs a real fabric test.
