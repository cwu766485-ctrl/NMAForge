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

## 当前项目状态

- 主线：AXI-Lite/AXI4 AI 加速器。
- 功能重点：command/completion queue、描述符读取、DMA、512 KiB scratchpad、INT8
  计算核心和性能监控。
- ASIC 历史基线：A7 RTL 在 TSMC28 HPC+、250 MHz pre-layout setup/hold 均闭合；
  A8 PACK_I8/Transformer 改版尚待复跑。
- 下一步：在许可环境运行 `make ai_transformer`、复跑 A8 28 nm DC 与 XCZU15EG
  timing；如进入后端流程，则执行 floorplan、CTS、P&R、
  提取 RC 及多角 STA，获得最终 Fmax 和 hold sign-off 结论。
