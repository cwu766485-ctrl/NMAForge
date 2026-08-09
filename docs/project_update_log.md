# CIMForge 项目更新日志

本文档记录当前 AXI-Lite/AXI4 AI 加速器主线的重要变更与可复核结果。早期 AHB
SRAM/vector 教学轨道已从仓库移除；A2-A6 阶段草案和已过期 FPGA bring-up 记录
不再作为当前项目状态依据。

## 2026-07-29 - ABI v7.2 与 Transformer 组合深度

- 为解决矩阵 INT32 输出无法直接喂回 packed-INT8 GEMM 的真实组合断点，在
  `OP_REQUANT_I8` 上增加 descriptor `flag[4]` 的 PACK_I8 模式；每四个饱和
  INT8 输出合并成一个 32-bit scratchpad word。
- RTL version 更新为 `0x1000_0008`，ABI minor 更新为 7.2，`CAP2[5]`
  明确报告 PACK_I8 layout bridge。
- 新增 `sw/tools/cimforge_mapper.py`，负责 scratchpad 分配、row/column tensor
  layout、ABI v7 descriptor 编码和 bit-accurate golden generation。
- mapper 生成 30 条命令的 4-token/hidden-4 Transformer 微型工作负载：
  Q/K/V、QK^T、四行 Softmax、AV、输出投影、Residual/LayerNorm、
  FFN GEMM/GELU/GEMM、Residual/LayerNorm。所有中间结果均由下一条 RTL
  命令真实消费，不再是三个互不相关 GEMM 冒充 QKV/MHA/FFN。
- mapper 会静态检查每条命令的 source 区间已由常量或前序 descriptor 生产；
  fixture 用 poison pattern 初始化所有 destination，不会预填 golden 结果。
- `A4_REFERENCE_PASS cases=1000 seed=20260722` 和 mapper/golden 自检已通过。
  随后在 Linux/VCS 环境运行 `make ai_transformer` 与 `make ai_smoke` 均为
  `TEST PASS`：30 条 Transformer command、最终 completion、16 个输出 word 和
  matrix MAC cycle 计数均被检查。
- 恢复 `fpga/xczu15eg/scripts/synth_ai_accel_ip.tcl`，并在 Vivado 2024.1 对
  `xczu15eg-ffvb1156-2-i` 完成 A8 standalone OOC synth/place/route：10.0 ns
  约束下 setup WNS=+0.187 ns、hold WNS=+0.032 ns，零条 setup/hold 违例、零个
  failed net。资源为 30,506 LUT、25,238 FF、128 BRAM36、46 DSP；vectorless
  功耗估计 0.923 W（dynamic 0.212 W，static 0.710 W）。
- 这是无板级 pin/clock 包装的 OOC IP 实现结果；Vivado 报告 `HD.CLK_SRC` /
  `HD.PARTPIN_LOCS` 缺失，因此它证明 IP 在 100 MHz 可路由闭合，但不能替代
  完整 block-design 或实板时序结论。
- 28 nm DC 可执行文件和真实 `.db` 均存在，但当前 license feature 未启用，
  `DCSH-1` 在读取 RTL 前退出；A7 的 250 MHz/PPA 只保留为历史基线，A8
  必须复跑后才能引用。

## 2026-07-29 - DMA、scratchpad line、矩阵数据流与 ABI v7

- 删除原 `axi_dma_master` 与 `ai_axi128_dma_ooo` 两套互斥后端，新增统一
  `ai_axi128_dma`。
- 统一 DMA 的 1D、2D、gather、tile 共用一套 planner；128-bit burst 最多
  16 beat，自动执行 4 KiB boundary split，读方向使用 ID 1..4 的 burst
  scoreboard，写响应使用 ID 8..11。
- word-aligned 但非 16-byte 对齐的 external address 使用 32-bit alignment
  beat，达到 line boundary 后切换为 128-bit burst，保持旧 ABI 的 4-byte
  对齐兼容性。
- `DMA_CFG[1]` 不再选择后端，改为读取恒为 1 的统一 128-bit DMA 能力位。
- scratchpad 控制面仍保持 descriptor、completion 优先；scalar、banked、DMA
  三个数据面客户改为 round-robin，消除固定优先级导致的永久 DMA starvation。
- 四个 32-bit bank 增加一条原生 128-bit line read/write 通路。DMA 对齐的
  四 word 搬运使用一次 line transaction，避免每条 AXI beat 在片上拆成四次
  scalar transaction。
- 4x4 matrix core 保留 K-group operand 预取，并把 16 个输出从 16 次 scalar
  write 改为四条 128-bit row write；tile pipeline 的 ping-pong DMA/compute
  overlap 保持不变。
- AXI AR/AW、external command queue、direct DMA 和 tile external base 升级为
  64-bit 地址；`CMDQ_BASE_HI` 与新增 DMA/tile high register 已进入实际地址链。
- 顶层显式输出 AXI `CACHE/PROT/QOS/LOCK` sideband；新增 `ABI_INFO`、`CAP2`、
  `ERROR_INFO`，descriptor v7 统一覆盖全部 opcode，同时兼容旧 v3/v4/v5。
  当时的 RTL version 为 `0x1000_0007`。
- DMA 性能计数由固定每拍 4 byte 改为按 32/128-bit beat 的实际有效 byte 数累计。
- source list、ASIC 综合脚本、FPGA Tcl、memory model、directed DMA/arbiter
  test、软件寄存器头文件和中文 SPEC 已同步。随后已在许可环境通过
  `make ai_upgrade_vcs`；对应证据记录在下方“验证与版本管理”。

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
  - `rtl/dma/`：统一 128-bit tagged multi-beat DMA；
  - `rtl/memory/`：scratchpad、仲裁与保护；
  - `rtl/compute/`：INT8、banked、matrix、SFU、卷积、KV-cache 计算核心；
- 移除旧 AHB SRAM/vector RTL、专属验证环境、回归入口和综合 sanity 脚本，
  仓库只保留 AI 加速器主线。
- 同步检查 `verif/sim/ai_accel.f`、两套 FPGA RTL 清单和 28 nm 综合脚本。
  40 nm 的参考综合脚本与 SRAM 黑盒已删除；ASIC 交付仅保留带真实 SRAM `.db`
  的 28 nm 路径。
- `.gitignore` 增加 Vivado、VCS、DC、PDK cache、板卡示例和临时工件规则，避免本地
  生成物污染提交。

### 验证与版本管理

- `git diff --check` 通过。
- 2026-07-29，具备许可证的 Linux/VCS 环境执行 `make ai_upgrade_vcs` 全部通过：
  `tb_ai_axi128_dma`、`tb_ai_spad_arbiter_rr` 和完整 `tb_ai_accel_smoke`
  （`AI_RANDOM_CASES=0`）均 PASS。该回归覆盖 16-beat burst、tagged read、
  abort drain、scratchpad line/RR 仲裁及完整控制面 smoke。
- 本地 Git 已创建并完成两次提交：
  - `e15c3af Initial CIMForge accelerator sources`
  - `16efb67 Organize AI accelerator project`
- 当前未配置 Git remote，未向 GitHub 或其他外部服务推送。

## 2026-08-02 - A8 单一主线清理与 UVM 入口冻结

- 阅读 `CODEX_CONVERSATION_EXPORT.md` 后，以实际 A8 VCS、Vivado OOC 和
  `A8_TSMC28_SYNTHESIS_REPORT.md` 报告为准，明确早期 AHB/A2/40 nm 的叙述仅为历史记录，
  不再作为当前验收证据。
- 已移除旧 AHB SRAM/vector RTL、对应 class-based verification、旧 40 nm 综合脚本、
  旧 FPGA filelist，以及未被 A8 source list 使用的平铺 A7/A6 RTL 副本；所有当前
  VCS、FPGA 与 DC source list 均只保留 A8 模块。
- 根 README、文档索引和 architecture 已改为 A8 事实源；当前顶层固定为
  `rtl/top/ai_accel_top.v`，统一 DMA 为 `rtl/dma/ai_axi128_dma.v`。
- 已验证证据边界：VCS directed/smoke 与 30-command Transformer micro-workload 已通过；
  XCZU15EG standalone OOC 于 100 MHz setup/hold 闭合；TSMC28 HPC+ 真实 SRAM macro 的
  250 MHz pre-layout DC setup/hold 闭合。它们不等同于 UVM coverage、CDC/formal、
  post-layout sign-off 或实板 workload 验收。

## 2026-08-02 - SpyGlass 静态验证入口

- 新增 `verif/spyglass/`：独立 A8 RTL filelist、单时钟/异步低有效复位的 SGDC intent、
  Lint/CDC/RDC project、Linux 运行封装和 waiver 原则。静态项目明确排除 testbench/SVA，
  并以 `VCS` macro 选择 scratchpad 行为模型，避免 Xilinx XPM 作为未解析库单元。
- 当前架构只定义 `aclk` 与 `aresetn`；CDC 目标是证明没有意外 clock crossing，RDC 不预先
  waiver 异步 reset release。若 SpyGlass 报告 reset deassertion，需明确上游同步释放假设
  或补 reset synchronizer。
- 未在本次操作中执行 SpyGlass：Windows 无可见 WSL distribution，现有 F 盘 bridge 指向
  `/home/ray/ic/dsm_ip` 而非 CIMForge，不能把命令发送到其他项目。待 bridge 以
  `/home/ray/ic/CIMForge` 启动并确认 SpyGlass module/PATH 后运行并归档真实报告。

## 当前项目状态

- 主线：A8 AXI-Lite/128-bit AXI4 INT8 tensor accelerator，512 KiB 四 bank scratchpad。
- 功能重点：command/completion queue、descriptor ABI v7.2、统一 tagged multi-outstanding
  DMA、matrix/SFU/CNN/KV-cache primitives、性能监控和 mapper 驱动的 Transformer 命令链。
- ASIC 依据：TSMC28 HPC+ TT/0.9 V/25 C、32 个真实 SRAM macro 的 A8 版本在 250 MHz
  pre-layout DC setup/hold 均闭合；详见 `TSMC28_SYNTHESIS_REPORT.md`。
- 下一步：冻结当前 RTL/ABI 后开始 UVM。先建立 AXI-Lite/AXI4 agent、RAL、scoreboard、
  reference-model adapter 和 coverage plan；重点覆盖 queue/descriptor、DMA ID/4 KiB/
  abort、scratchpad arbitration 和端到端 Transformer 命令序列。并行清点 DC 的 869 条
  lint-style `check_design` 项，形成可审计的修复/waiver 清单。

## 2026-08-02 - 28 nm 静态验证配置与 A8 SPEC 刷新

- 经 Linux SpyGlass V-2023.12-SP1 实际初跑确认，使用行为 `ai_scratchpad` 的静态工程会因
  4 个 32K x 32 Verilog 数组触发大 memory/blackbox 报错；提高 memory threshold 会使
  工具在行为 SRAM 上长时间展开，并非合理 ASIC lint 方案。此前被手动终止的两次 run
  退出码均为 143，不计为通过。
- `verif/spyglass/a8_static.prj` 改为与 28 nm DC 一致的
  `syn/ai_scratchpad_28nm_macro.v`；新增 `tsmc28_sram_macro_stub.v` 只声明真实
  4Kx32 SRAM 的端口，避免静态检查伪造 512 KiB 行为存储，同时保留 macro wrapper、
  宏使能和地址选择逻辑的可检查性。
- 新建项目中性的 `scripts/cimforge_eda_bridge.sh`，并将 WSL 指南改用
  `cimforge_eda_bridge` / `CIMFORGE_PROJECT_DIR` 命名；旧 `tsmc40_bridge` 仅作
  兼容入口，待新 bridge 就绪后停止，不删除任何旧目录。
- `docs/SPEC.md` 更新为 A8 ABI v7.2 的当前规格：明确 512 KiB/32 macro SPAD、
  128-bit RID/BID-aware DMA、四 outstanding read、opcode/descriptor/completion ABI、
  28 nm 与 XCZU15EG 的真实证据边界，以及 UVM/CDC/RDC/实板仍待完成的验收项。
- 新 bridge 上实际执行 `make ai_smoke`，退出码 0、`TEST PASS`。该回归包含 30-command
  Transformer 链、随机 GEMV/GEMM/Conv、DMA/region-protection error 路径和 reset recovery，
  证明本次 matrix-core 函数显式参数化未破坏端到端功能。
- macro-aware SpyGlass lint 实际完成（V-2023.12-SP1）；行为 SPAD 的四个大数组错误已消失。
  报告剩余的 `SYNTH_5273` 指向 DMA 内实际存在的 4-entry x 128-bit x 16-beat reorder
  buffer（8192 bit），因此将 `mthresh` 精确设为 8193；这不是对 SRAM 或 lint 规则的 waiver。
- 重新运行后 lint 为 **0 error / 393 warning**。CDC structural run 识别 1 个 clock、1 个
  reset，报告 0 个 scalar/vector crossing；但服务器缺少 `Advanced_CDC` feature，部分高级
  CDC rule 未执行，且 `Reset_sync04` 对 `ai_spad_arbiter` 的内部双级采样提出 1 条 warning，
  因此该结果只可标记为“基础结构检查完成”，不可标记为完整 CDC sign-off。
- 初版 RDC launcher 调用了该服务器 methodology 中不存在的 `rdc_setup`，退出码 7；已按
  SpyGlass 返回的可用 goal 改为 `rdc/rdc_verify_struct`，随后重新运行。
- `rdc/rdc_verify_struct` 已完成。其两个 error 分别为 `Ar_resetcross01` 缺少
  `Advanced_CDC` feature、`Ar_resetcross_matrix01` 缺少 `rdc_adv_checker` feature；
  它们是 license coverage 缺口而非设计路径 violation。当前可用结构报告未给出实际
  reset-crossing 错误。CDC/RDC 的正式结论均为“基础结构检查已运行，advanced sign-off
  受服务器 license 阻断”，不得写成完整 sign-off pass。
- 已启动新的 `F:\cimforge_eda_bridge`（WSL 项目固定为 `/home/ray/ic/CIMForge`），并在
  确认其状态为 ready 后干净停止旧 `tsmc40_bridge`；旧 bridge 的文件和日志未删除。
- 使用真实 TSMC28 HPC+ TT/0.9V/25C 标准单元 `.db` 与真实 4Kx32 SRAM macro `.db` 对
  **当前 RTL** 独立执行 `bash syn/run_ai_accel_28nm_dc.sh 4.0`，输出为
  `syn/out/tsmc28_a8_4_0ns_20260802/`，退出码 0。最终 QoR：setup/hold WNS/TNS
  均为 0.00ns、0 条违例、critical path 3.87ns（SRAM Q 到 tensor SFU `sum_exp`）；
  32 macro、133,642 leaf cells、总 area 1,242,475.50 library area units、
  vectorless power 24.16mW。此为 pre-layout 单角结果，不是 post-route/sign-off。
- 当前 DC `check_design` 有 256 条 lint-style potential problems；其中高扇出 net、
  常量 AXI sideband/保留位和 macro 输出活动率未注释是已观察到的类别。它们未产生 timing
  或 max-transition/max-capacitance 违例，但必须在 UVM/后端前形成可审计分类，不可忽略。

## 2026-08-07 - SpyGlass 结果复核与验证计划冻结

- 复核最新 SpyGlass V-2023.12-SP1 结果：`lint/lint_rtl` 为 0 error、414 warnings、4 info；
  `cdc/cdc_setup` 为 0 error、12 warnings；CDC structural report 显示 0 个
  unsynchronized crossing、0 个 convergence。
- `cdc/cdc_verify_struct` 的 1 条 error 是 `Advanced_CDC` license 缺失；
  `rdc/rdc_verify_struct` 的 2 条 error 是 `Advanced_CDC` 与 `rdc_adv_checker`
  license 缺失。它们是工具覆盖限制，不是 RTL crossing 结论；当前不能称 CDC/RDC sign-off。
- 另一次 SpyGlass 运行出现 `SIGSEGV`（signal 11），且 GDB 因 WSL `ptrace` 限制无法生成
  stack trace；该次工具异常不覆盖此前成功的 lint/CDC/RDC 结果。dashboard/datasheet 报告
  还因对应 license 缺失失败，未作为设计结果记录。
- 修正 `docs/SPEC_ZH.md` 的验证证据段，删除过期的 393 warning 数字，明确 license 和
  tool-crash 边界；新增 `docs/VPLAN.md`，冻结 UVM、Formal、LEC、DFT、PPA 的分阶段计划、
  回归矩阵、退出条件和每日学习节奏。
- 下一阶段从 SPEC 学习和 UVM 基础环境开始：先做 AXI-Lite agent/RAL、CMDQ/CPLQ scoreboard，
  再接入 AXI4 DMA、scratchpad arbiter、CNM 四 lane 和 Transformer reference model。

## 2026-08-08 - 文档事实源同步

- 将 `docs/architecture.md` 从英文旧版更新为中文 A8 架构说明，补充当前模块所有权、唯一
  scratchpad 仲裁入口、A2.2 四 bank-local controller/PE、A3.1 4×4 GEMM 数据路径，以及
  最新 VCS、TSMC28、XCZU15EG 和 SpyGlass 证据边界。
- 更新 `docs/README.md` 文档索引，移除已合并删除的 `CNM_A2_EVALUATION_ZH.md`、
  `CNM_A2_A3_COMPARISON_ZH.md` 和旧综合报告链接，新增 `VPLAN.md` 入口。
- 将 `CNM_BANK_LOCAL_PE_RESEARCH_ZH.md` 的 A1/A2/A3 内容改为“已实现结果 + 后续研究边界”，
  并把最新性能数字和源码路径指向统一 CNM 评估报告。
- 同步 `SPEC.md`、`CNM_EVALUATION_ZH.md`、`XCZU15EG_BRINGUP.md` 的报告路径、版本号和
  ABI v7.2/64-bit 地址描述；未改写历史日志中的历史结果。

## 2026-08-09 - 当前 RTL 状态与文档收口

- 以 `rtl/top/ai_accel_top.v`、`verif/sim/ai_accel.f`、当前动态回归日志及
  `syn/out/tsmc28_4_0ns/reports/` 为准，重新核对 A8 的唯一产品线：AXI4-Lite
  控制、128-bit AXI4 DMA、512 KiB 四 bank scratchpad、CMDQ/CPLQ、数字 CNM A1/A2.2、
  4×4 A3.1 matrix tile、SFU、Conv 和 KV primitive 均已接入顶层。
- 修复文档索引中的 `architecture.md` 大小写/重命名链接，统一为
  `ARCHITECTURE.md`；TSMC28 当前报告路径统一为 `syn/out/tsmc28_4_0ns/`，并修正
  当前 run 的日期、leaf cell 数（138,332）及关键路径口径（QoR 3.89 ns）。
- 将 CNM 报告中过期的“等待 VCS/DC/Vivado”描述改为已存在的定向/系统证据，保留
  SAIF workload、UVM coverage、formal/LEC/DFT、后布局和实板压力为未完成门项。
- 明确 XCZU15EG 文档是 bring-up runbook：100 MHz OOC 是现有实现证据；只有出现与
  当前提交/XSA 对应的 JTAG、UART 和 ILA PASS 日志后，才能宣布实板端到端验收。
- 本次仅更新事实文档和日志，不修改 RTL/ABI，也不重新执行仿真、DC、SpyGlass 或板卡。
