# NMAForge 架构图证据与审查记录

## 生成范围

本目录的 SVG 基于当前可综合顶层 `rtl/top/ai_accel_top.v` 和其 active RTL
filelist 生成。SVG 是可编辑权威产物；没有依赖 Mermaid 或凭文件名推断模块。

## 已确认事实

- 顶层：`rtl/top/ai_accel_top.v`，模块 `ai_accel_top`。
- 控制面：`ai_accel_control_fabric` → `axi_lite_reg_if` → `ai_accel_regs`。
- 命令面：`ai_command_processor` 拥有 CMDQ/CPLQ 生命周期、descriptor fetch、launch 和 completion 顺序。
- 数据面：`ai_axi128_dma` 使用 128-bit AXI4；`ai_accel_axi_fabric` 将 descriptor read 与 payload DMA read 复用外部读通道。
- 存储：`ai_spad_arbiter` 是 scheduler-side 唯一 admission point；SPAD 为 4-bank、512 KiB，注册读。
- 计算：`ai_accel_compute_cluster` 汇聚 scalar INT8、banked CNM、4×4 matrix、CNN line buffer、SFU 和 KV-cache 路径。
- 时钟：当前 RTL 使用单一 `aclk`；复位为低有效异步 `aresetn`。
- 当前 CDC 图不显示异步 FIFO 或同步器，因为 active top 没有真实多时钟域。

## 主要风险/审查问题

- SPAD arbiter 是单 admission 点；它提供 client-level round-robin，不是不同 client 同周期占用不同 physical bank 的细粒度仲裁。
- descriptor/completion 控制面固定优先于 data-plane，连续控制事务可能暂时压低数据面服务率。
- AXI-Lite 控制适配器的读写状态机共享 `reg_req_*` 内部端口；同周期读写并发应由专门测试和断言确认。
- RDC 尚未闭环；当前图只表达 reset 拓扑，不代表 RDC sign-off。
- 4 GB/s 是 128-bit × 250 MHz 的理论单方向峰值，不是 workload 的实测带宽。

## 未在图中声称的内容

- 没有声称后布局 STA、MMMC、OCV、SI、IR/EM 或量产 sign-off。
- 没有把普通 scratchpad 称为模拟 CIM，也没有声称真实多时钟 CDC/Low Power。
- 备用 `NMAFORGE_ENABLE_MEMORY_FABRIC` 路径在顶层图中归入 SPAD subsystem；默认路径和备用路径的选择由宏控制。

## 主要证据路径

| 架构块 | RTL 证据 |
|---|---|
| Top integration | `rtl/top/ai_accel_top.v` |
| Control fabric | `rtl/top/fabric/control/ai_accel_control_fabric.v` |
| AXI-Lite adapter | `rtl/control/axi_lite/axi_lite_reg_if.v` |
| Register semantics | `rtl/control/axi_lite/ai_accel_regs.v` |
| Command owner | `rtl/control/queue/ai_command_processor.v` |
| Completion protocol | `rtl/control/queue/ai_completion_writer.v` |
| AXI fabric | `rtl/top/fabric/axi/ai_accel_axi_fabric.v` |
| DMA | `rtl/dma/ai_axi128_dma.v` |
| SPAD arbitration | `rtl/memory/ai_spad_arbiter.v` |
| SPAD storage/protection | `rtl/top/fabric/memory/ai_accel_spad_subsystem.v`, `rtl/memory/ai_scratchpad.v`, `rtl/memory/ai_spad_protection.v` |
| Compute cluster | `rtl/top/fabric/compute/ai_accel_compute_cluster.v` |
