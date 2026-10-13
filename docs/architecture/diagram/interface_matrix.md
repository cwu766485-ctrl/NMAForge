# NMAForge 接口矩阵

| Source | Destination | Protocol/接口 | Role | Width | Clock | CDC | 备注 |
|---|---|---|---|---:|---|---|---|
| CPU/SoC | `ai_accel_control_fabric` | AXI4-Lite | master → slave | 32-bit data/address | `aclk` | none observed | 配置、状态、SPAD host window |
| `ai_accel_regs` | `ai_command_processor` | control pulses/config | producer → owner | mixed | `aclk` | none | direct/submit/abort/tile |
| `ai_command_processor` | descriptor fetch | valid/status | owner → fetcher | 64-bit base | `aclk` | none | SPAD 或外部 DDR source |
| `ai_command_processor` | compute cluster | launch ABI | owner → compute | mixed | `aclk` | none | opcode、地址、shape、量化 |
| `ai_axi128_dma` | `ai_accel_axi_fabric` | AXI4 | master → fabric | 128-bit data, 4-bit ID | `aclk` | none | burst、tagged reads |
| `axi_desc_fetch` | `ai_accel_axi_fabric` | AXI4 read | master → fabric | 128-bit, descriptor ID 0 | `aclk` | none | descriptor read priority |
| DMA/descriptor/compute/completion | `ai_spad_arbiter` | custom valid/ready | clients → arbiter | scalar/line/CNM | `aclk` | none | single admission point |
| `ai_spad_arbiter` | SPAD subsystem | custom request/response | scheduler → memory | scalar/line/4-lane | `aclk` | none | registered read and response tags |
| compute cluster | `ai_perf_monitor` | event counters | event → monitor | events | `aclk` | none | MAC/stall/DMA/overlap evidence |
| `ai_accel_regs` | CPU/SoC | IRQ | interrupt → CPU | 1 | `aclk` | none | sticky done/error masked by enable |
