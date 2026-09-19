# NMAForge —— AXI4 近存张量加速器

[English README](README.md) · [架构说明](docs/architecture/ARCHITECTURE.md) ·
[中文规格](docs/spec/SPEC_ZH.md) · [验证计划](docs/verification/VPLAN.md) ·
[文档索引](docs/README_ZH.md)

> **简短描述：** 基于 AXI4、banked scratchpad 与命令队列的可综合数字近存张量加速器 IP。

NMAForge 是一个可综合的、全数字近存张量加速器 IP。它**不是**模拟 CIM：乘加和
控制逻辑均为数字电路；“近存”的含义是把 tile 放进四 bank scratchpad，并让部分
计算、地址生成和局部累加靠近存储 bank 执行，以减少 DDR 往返。

## 核心架构

- 32-bit AXI4-Lite 控制面，128-bit AXI4 数据主口。
- 512 KiB、四 bank scratchpad；`ai_spad_arbiter` 是唯一仲裁入口，控制面优先。
- CMDQ/CPLQ、片上/外部 descriptor、依赖 event、四 word 原子 completion、状态和 IRQ。
- DDR↔scratchpad DMA：1D、2D stride、gather、4 KiB 拆分、最多四笔 tagged read、
  RID/BID 响应归因、窄传输对齐和 abort drain。
- INT8 VDOT/GEMV/GEMM、4×4 matrix tile、定点 SFU、Conv3x3/DWConv primitive、
  KV-cache 地址生成。
- 用 descriptor primitive 组合 QKV、QKᵀ、causal Softmax、AV、residual/norm、FFN 的
  Transformer 微工作负载。

## 已有证据与边界

- VCS 顶层 smoke 和 Transformer 微工作负载回归已通过。
- DMA block UVM 已通过 11 项定向/随机测试：1D/2D/gather、RID/BID 乱序、4 KiB、
  abort 与 back-pressure。
- AXI-Lite control block UVM 已通过 6 项测试：reset/ABI、AW/W 分离、WSTRB/error、
  IRQ/W1C、busy/abort、随机寄存器访问和 RAL frontdoor。
- 商用 28 nm 库的 pre-layout 综合研究在文档约束下满足 250 MHz；公开报告已经脱敏，
  见 [`docs/verification/TSMC28_SYNTHESIS_REPORT.md`](docs/verification/TSMC28_SYNTHESIS_REPORT.md)。
- XCZU15EG 的 Vivado 与 bring-up 脚本在仓库中；完整上板仍依赖板卡拥有者私有的
  参考工程和实际硬件。

这不是 ASIC sign-off，也不是生产级 LLM serving 的声明。coverage closure、完整
CDC/RDC/formal、后布局 ASIC 签核和实板 workload 性能测量仍待完成。

## 目录

```text
rtl/       可综合加速器 RTL
dv/     smoke、block UVM、subsystem 测试和静态检查资料
dv/uvm/ 可复用 UVM agent 与顶层 UVM bring-up
sw/        ABI 头文件、mapper 与裸机 bring-up 源码
fpga/      公开 Vivado flow 与板级集成脚本
docs/      架构、规格、验证和公开发布说明
```

## 公开仓库边界

仓库不包含 PDK、SRAM macro model、timing library、厂商原理图/参考工程、bitstream、
波形、凭据或机器相关 EDA 配置。发布前请阅读
[`docs/PUBLIC_RELEASE.md`](docs/PUBLIC_RELEASE.md)。

为了保持软件 ABI 兼容，部分历史宏和文件仍带有 `CIMFORGE_*` 前缀；项目公开名称统一为
**NMAForge**。
