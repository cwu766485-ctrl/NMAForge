# NMAForge 项目经历摘要

状态汇总：2026-10-21。本文用于项目介绍，不代替
[规格](../spec/SPEC_ZH.md)、[架构说明](ARCHITECTURE.md)或
[验证证据](../verification/A10_DV_RTM.md)。简历中的职责与个人贡献须按实际工作填写。

## 项目简介

NMAForge 是可综合的 AXI-Lite/AXI4 数字 compute-near-memory 加速器原型，
包含命令与完成队列、128-bit DMA、512 KiB 四 bank scratchpad，以及 INT8、
CNM、Matrix、SFU、CNN/KV 和混合精度 FP 计算路径。

## 有证据支持的结果

- A2 bank-local GEMV 的受控 RTL benchmark 在长度 16/64/256 上相对冻结基线
  为 1.73×/1.92×/1.98×；A3.1 4×4 GEMM 为 3.58×/3.88×/3.97×。
- CNM、CNN/KV、FP、Matrix、SFU 的选定 block/subsystem/top 测试通过；每组的
  样例数量、形式结果和 raw DUT coverage 见[compute-engine status](../verification/COMPUTE_ENGINE_STATUS.md)。
- TSMC28 TT/0.9 V/25 °C、4.0 ns 的 DC setup/hold 结果是 **pre-layout** 证据；
  功耗估计受 SRAM black-box 与 activity annotation 限制。详情见
  [TSMC28 报告](../verification/TSMC28_SYNTHESIS_REPORT.md)。

## 必须保留的边界

这些结果不代表全局 coverage/sign-off、后布局 PPA、真实 DDR 带宽、芯片
TOPS/W 或板级部署。compute 派发是串行的；并行 engine launch 不是当前架构
能力。完整 A10 验证工作流仍按 [A10 RTM](../verification/A10_DV_RTM.md)
追踪，未关闭的 formal、coverage、fault/reset、LEC、DFT 和实现项目仍应明确列出。

对外介绍只使用本人可解释且有复现证据的贡献和数字。
