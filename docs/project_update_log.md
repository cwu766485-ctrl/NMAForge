# CIMForge 项目更新日志

本文档记录当前 AXI-Lite/AXI4 AI 加速器主线的重要变更与可复核结果。早期 AHB
SRAM/vector 教学轨道、A2-A6 阶段草案和已过期 FPGA bring-up 记录不再作为当前项目
状态依据。

## 2026-07-28 - 28 nm 综合闭环与项目整理

### TSMC28 HPC+ pre-layout 综合

- 使用 TSMC28 HPC+ TT/0.9 V/25 C 标准单元库和
  `TS1N28HPCPL2SVTB4096X32M4MWBASO` SRAM 宏完成 AI 顶层综合。
- 512 KiB scratchpad 映射为 32 个 4K x 32 单端口 SRAM 宏：每个逻辑 bank 使用
  8 个宏，共 4 个逻辑 bank。
- 4.0 ns 时钟约束下（250 MHz），setup WNS/TNS 为 0.00/0.00 ns，零条 setup
  违例；关键路径在 `ai_tensor_sfu_core` 的
  `vector_product_r_reg -> output_word_r_reg`，数据到达时间为 3.89 ns。
- 将综合约束拆为 100 ps setup uncertainty 和 20 ps pre-CTS hold uncertainty，
  最终 run 的 hold WNS/TNS 为 0.00/0.00 ns，零条 hold 违例。
- 当前 PPA：97,779 个标准单元 leaf、32 个 SRAM macro、总 cell area
  1,206,694.62 library area units、动态功耗估计 14.54 mW、leakage 功耗估计
  1.95 mW；scratchpad 面积约占总面积的 93%。
- 该结果是基于真实工艺库的 pre-layout 综合闭环，不是 post-layout sign-off。
  尚未包含 floorplan、CTS、布线 RC、MMMC、OCV、IR drop 和 EM。

### 综合流程修正

- 曾发现局部生成的标准单元 `.db` 不完整，DC 报告 `target library does not contain
  an inverter`，导致 GTECH/unmapped logic 和无效 PPA。该结果已明确作废，不用于
  性能结论。
- `syn/dc_ai_accel_28nm.tcl` 现在会在编译前检查目标库中是否存在
  `INVD1BWP7T40P140` 和 `DFCNQD1BWP7T40P140`，阻止不完整 `.db` 进入综合。
- 28 nm 脚本保留 `set_fix_hold` 和 `compile -incremental -only_hold_time`，以便
  在 pre-layout 阶段显式检查最小延迟约束。

### 文档与目录整理

- 新增中文项目说明 `docs/AI_ACCELERATOR_PROJECT_BRIEF.md`，统一描述当前架构、
  队列协议、验证策略、PPA、综合边界和面试讨论要点。
- 清理已过期的 40 nm、A2-A5 阶段规格、历史更新日志、旧 FPGA bring-up 和环境操作
  文档；当前 `docs/` 仅保留项目说明、28 nm 综合说明和本日志。
- RTL 按功能重新组织：
  - `rtl/top/`：顶层集成；
  - `rtl/control/`：AXI-Lite、寄存器、命令、描述符、completion 与性能计数；
  - `rtl/dma/`：AXI DMA 和 128-bit OOO DMA；
  - `rtl/memory/`：scratchpad、仲裁与保护；
  - `rtl/compute/`：INT8、banked、matrix、SFU、卷积、KV-cache 计算核心；
  - `rtl/legacy/`：保留的 AHB SRAM/vector 教学参考。
- 同步更新 `verif/sim/ai_accel.f`、`verif/sim/rtl.f`、两套 FPGA RTL 清单、28 nm
  综合脚本、40 nm 参考脚本和 legacy sanity 脚本。静态路径检查通过。
- `.gitignore` 增加 Vivado、VCS、DC、PDK cache、板卡示例和临时工件规则，避免本地
  生成物污染提交。

### 验证与版本管理

- `git diff --check` 通过。
- `make ai_comp` 已验证重组后的 AI source list 被正确读取；当前自动化代理无法访问
  VCS license server，因此不声明该环境下的编译通过。需在具备许可证的交互终端运行
  `cd verif/sim && make ai_smoke` 完成最终回归确认。
- 本地 Git 已创建并完成两次提交：
  - `e15c3af Initial CIMForge accelerator sources`
  - `16efb67 Organize AI accelerator project`
- 当前未配置 Git remote，未向 GitHub 或其他外部服务推送。

## 当前项目状态

- 主线：AXI-Lite/AXI4 AI 加速器。
- 功能重点：command/completion queue、描述符读取、DMA、512 KiB scratchpad、INT8
  计算核心和性能监控。
- ASIC 结果：TSMC28 HPC+，250 MHz pre-layout setup/hold 均闭合。
- 下一步：在许可环境复跑 AI smoke；如进入后端流程，则执行 floorplan、CTS、P&R、
  提取 RC 及多角 STA，获得最终 Fmax 和 hold sign-off 结论。
