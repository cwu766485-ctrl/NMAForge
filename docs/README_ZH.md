# NMAForge 文档索引

[English index](README.md) · [项目中文 README](../README_ZH.md)

## 当前设计与验证依据

| 主题 | 文档 |
|---|---|
| 产品行为、寄存器 ABI 与数值契约 | [中文规格](spec/SPEC_ZH.md) · [English spec](spec/SPEC.md) · [混合精度 FP 规格](spec/FP_EXTENSION_SPEC_ZH.md) · [命名兼容](spec/NAMING_COMPATIBILITY.md) |
| RTL 所有权与数据流 | [架构说明](architecture/ARCHITECTURE.md) |
| 五个 compute 验证组收敛情况 | [验证状态统计](verification/COMPUTE_ENGINE_STATUS.md) · [2026-10-21 运行记录](verification/COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-21.md) |
| A10 需求追踪与剩余收口项 | [A10 RTM](verification/A10_DV_RTM.md) · [缺陷登记](verification/A10_BUG_REGISTER.md) · [验证计划](verification/VPLAN.md) |
| Lint、CDC/RDC 与综合证据 | [静态分析](verification/STATIC_ANALYSIS_REPORT.md) · [CDC disposition](verification/CDC_DUAL_CLOCK_DISPOSITION_ZH.md) · [RDC 状态](verification/RDC_STATUS_ZH.md) · [SpyGlass triage](../dv/spyglass/LINT_TRIAGE.md) · [TSMC28 综合](verification/TSMC28_SYNTHESIS_REPORT.md) |
| FPGA 板级 bring-up | [XCZU15EG 流程](verification/XCZU15EG_BRINGUP.md) |
| CNM 评估与研究 | [中文评估](architecture/CNM_EVALUATION_ZH.md) · [English summary](architecture/CNM_EVALUATION.md) · [文献综述](architecture/Literature_Review.md) |
| 性能、项目经验与发布 | [性能/PPA 报告](architecture/PERFORMANCE_PPA_REPORT_ZH.md) · [项目经验](architecture/PROJECT_EXPERIENCE_ZH.md) · [公开发布指南](PUBLIC_RELEASE.md) |
| RTL 阅读与安全重构 | [RTL 指南](RTL_GUIDE.md) |

逐次 A10 运行记录保留在 `verification/` 供历史追溯。当前状态以 RTM
为准，不要把较早的运行快照当成最新结论。

## 常用验证入口

除特别说明外，从仓库根目录运行：

| 范围 | 命令 |
|---|---|
| 五个 compute 验证组 | `make -C dv/subsystem/tensor_datapath/sim cluster_regress` |
| Top smoke | `make -C dv/subsystem/top_smoke/sim ai_smoke` |
| Top seeded regression | `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345` |
| Control UVM | `make -C dv/block/control/sim uvm_regress` |
| DMA UVM | `make -C dv/block/dma/sim uvm_regress` |
| SpyGlass | `cd dv/spyglass && ./run_spyglass_a8.sh all` |

长时间回归前确认工具与 license 可用，并把仿真、coverage 和 EDA 生成物放在源码树之外。
