# CIMForge 文档索引

仓库只保留以 `rtl/top/ai_accel_top.v` 为核心的 A8 AXI-Lite/AXI4 INT8 AI
加速器文档。历史阶段笔记、聊天导出、第三方板卡示例和工具生成物不是项目交付。

| 文档 | 用途 |
|---|---|
| [SPEC_ZH.md](SPEC_ZH.md) | A8/ABI v7.2 中文详细规格：接口、寄存器、队列、DMA、算子与边界。 |
| [SPEC.md](SPEC.md) | 英文兼容规格；内容与 RTL/软件 ABI 对齐。 |
| [architecture.md](architecture.md) | 顶层架构、模块关系、验证与实现状态摘要。 |
| [A8_TSMC28_SYNTHESIS_REPORT.md](A8_TSMC28_SYNTHESIS_REPORT.md) | TSMC28 TT/0.9V/25°C、250MHz pre-layout 综合证据和适用边界。 |
| [XCZU15EG_BRINGUP.md](XCZU15EG_BRINGUP.md) | XCZU15EG 构建、下载与板级 bring-up 步骤。 |
| [CNM_BANK_LOCAL_PE_RESEARCH_ZH.md](CNM_BANK_LOCAL_PE_RESEARCH_ZH.md) | Bank-local PE/CNM 演进的量化研究、目标与实验方案。 |
| [wsl_linux_instruction.md](wsl_linux_instruction.md) | WSL/Linux EDA 环境与运行说明。 |
| [project_update_log.md](project_update_log.md) | 项目更新记录；不替代规格或验证报告。 |

RTL compilation source lists are authoritative:

- `verif/sim/ai_accel.f`
- `fpga/xilinx_a7_100t/ai_accel_rtl.tcl`
- `fpga/xczu15eg/ai_accel_rtl.tcl`

## 文档维护规则

- 架构/ABI 改动同步更新 `SPEC_ZH.md`、`SPEC.md` 和软件头文件。
- PPA、SpyGlass、FPGA 结果只在真实工具运行后写入相应报告；必须写清 PVT、
  约束和 pre-layout/post-layout 边界。
- 中间日志、聊天导出、工具缓存、bitstream、checkpoint、第三方 demo 不进入 `docs/`。
- 新内容应优先并入上述主题文档；只有独立、长期维护的研究结论才新增文档。
