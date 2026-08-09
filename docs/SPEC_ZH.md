# CIMForge A8 AI 加速器详细规格（中文）

**RTL：A8；软件 ABI：v7.2；版本寄存器：`0x1000_0008`；顶层：`rtl/top/ai_accel_top.v`；事实日期：2026-08-09。**

> 本文按当前 RTL 及 `sw/include/cimforge_regs.h` 编写；发生冲突时，RTL 和头文件优先。本文只陈述已实现的全数字 RTL，规划项不会被写作已交付能力。

> 当前阶段是“RTL 功能基线已建立、进入系统化验证前的冻结点”。动态回归、28nm
> pre-layout DC、SpyGlass lint/基础 CDC/RDC 都已有证据；UVM coverage、formal/LEC/DFT、
> 后布局签核和 XCZU15EG 实板端到端验收仍未完成。

## 1. 产品定位

CIMForge 是可综合、面向 SoC 集成的全数字 AI 近存加速器 IP。软件通过 DMA 将 tile、权重、激活和 KV-cache 搬进邻近计算引擎的本地 SRAM，再在片上完成 INT8/定点计算，以减少外部 DDR 往返。其 banked VDOT/GEMV 路径实现了数字 CNM（Compute-Near-Memory）：四个 SRAM bank 各自邻接一个 Local Controller 和 Local PE，本 bank 内完成地址推进、A/B 读请求、operand 双缓冲、dot4 本地累加；仅在 output 边界传递四个 local sum 到 Global Reducer。它不是模拟 Compute-in-Memory：不修改 SRAM bit-cell、bit-line 或 sense amplifier，不在存储阵列内以模拟方式执行 MAC；也不是包含 CPU、NoC、CXL/LPDDR/HBM-PIM、DDR 控制器和 LLM serving 软件栈的完整系统。

当前重点是 INT8 VDOT/GEMV/GEMM、1x1/3x3/Depthwise 卷积、Q15 Softmax（含 causal）、RMSNorm、LayerNorm、残差、GELU、SiLU、requant，以及 Transformer 的 QKV/MHA/FFN 宏编排与 KV-cache 读写。典型 decoder 数据流为：`Q/K/V 投影 → Q×K^T → causal softmax → attention×V → 输出投影 → residual+RMSNorm → FFN → residual+RMSNorm`。

## 2. 架构、时钟和所有权

```text
CPU -- 32-bit AXI4-Lite --> 寄存器/IRQ --> 命令处理器(CMDQ/CPLQ)
                                         | 描述符/计算/完成项
                                         v
                             唯一 scratchpad 仲裁器
                                         v
                512 KiB、4-bank SRAM <--> 128-bit AXI4 DMA <--> DDR
```

当前只有一个同步时钟域 `aclk`，低有效异步复位为 `aresetn`。控制接口是 32-bit AXI4-Lite；数据主接口为 128-bit AXI4、64-bit 地址、4-bit ID，AR/R 和 AW/W/B 独立，支持 burst、valid/ready 背压和窄传输兼容。`irq` 是由 `IRQ_ENABLE` 掩蔽的 sticky 完成/错误通知。

下列职责是强制架构边界：

- `ai_accel_regs` 只保存软件配置、产生控制脉冲、记录 sticky 状态和 IRQ，不能推进队列或调度描述符。
- `ai_command_processor` 独占取/校验描述符、依赖事件、派发引擎、watchdog/abort、CMDQ_HEAD 和 CPLQ_TAIL 推进。
- `ai_spad_arbiter` 是 scratchpad 调度端口的唯一拥有者。描述符和完成写入为高优先级控制流；标量、line、banked 计算和 DMA 在数据面轮询。顶层不得另加 scratchpad mux。
- `ai_desc_fetch` 读取片上描述符，`axi_desc_fetch` 读取外部描述符；处理器在一条命令期间保持来源不变。
- `ai_completion_writer` 先提交完成项的四个 32-bit word，才发布新的 `CPLQ_TAIL`。

### 2.1 数字 CNM bank-local 数据路径

对 opcode `0x20/0x21`，`ai_banked_cnm_core` 实例化四个 `ai_bank_local_controller`。每个 controller 独立拥有本 bank 的地址发生器、A/B request、`ready/response-valid` lane、A ping-pong buffer、64-bit local accumulator 和事件计数器。接口关系如下：

```text
SRAM bank0 <-> LC0 + PE0 <--- cnm_addr0 / cnm_ready[0] / cnm_rsp_valid[0]
SRAM bank1 <-> LC1 + PE1 <--- cnm_addr1 / cnm_ready[1] / cnm_rsp_valid[1]
SRAM bank2 <-> LC2 + PE2 <--- cnm_addr2 / cnm_ready[2] / cnm_rsp_valid[2]
SRAM bank3 <-> LC3 + PE3 <--- cnm_addr3 / cnm_ready[3] / cnm_rsp_valid[3]
                                          |
                                   output-level Global Reducer
                                          |
                                  quantize / scratchpad writeback
```

`ai_spad_arbiter` 仍是唯一 scheduler-side scratchpad admission point；CNM 不得绕过它在顶层新增 mux。当前 CNM 一次 admission 可携带四个独立 bank lane 地址和 mask，但不同 client 同时访问不同 bank 的细粒度 bank-level arbitration 尚未实现，不能宣称该能力。

## 3. Scratchpad 和工艺视图

| 属性 | 当前实现 |
|---|---|
| 总容量 | 512 KiB（`0x00080000`） |
| 逻辑组织 | 4 bank × 32768 × 32-bit word |
| 单 bank | 128 KiB |
| 数据 line | 128 bit，即四个 32-bit bank word |
| 主机窗口 | `0x00010000` 起的 AXI-Lite scratchpad aperture |
| 读时序 | 注册读，响应在后续周期有效 |

VCS 通过 `+define+VCS` 使用 `rtl/memory/ai_scratchpad.v` 的行为 RAM；Vivado 使用 XPM 分支。TSMC28 DC/SpyGlass 使用 `syn/ai_scratchpad_28nm_macro.v`：每个逻辑 bank 由 8 个 `TS1N28HPCPL2SVTB4096X32M4MWBASO` 4K×32 1RW macro 实现，共 32 个。SpyGlass 仅检查 macro wrapper/控制逻辑，不展开 512 KiB 行为数组；foundry `.db/.lib` 才是综合和 STA 的存储权威视图。未对齐、越界、无权限或保护冲突访问必须报错。

## 4. 队列、描述符与完成项

软件写 CMDQ 描述符并发布 `CMDQ_TAIL`，硬件消费并报告 `CMDQ_HEAD`；硬件写 CPLQ 完成项并发布 `CPLQ_TAIL`，软件消费后发布 `CPLQ_HEAD`。CMDQ/CPLQ 可放在 scratchpad 或外部内存，`CMD_CTRL[0]` 选择外部描述符。CMD_HEAD/CPL_TAIL 的写仅用于复位/调试种子，不是正常运行时的软件推进方式。

一条 ABI v7.2 描述符固定 64 字节、64 字节对齐、16 个 little-endian 32-bit word：

| Word | 字段 | 定义 |
|---:|---|---|
| 0 | task/opcode | task ID[31:16]、opcode[7:0] |
| 1~4 | src0/src1/bias/dst | 地址或宏子描述符参数 |
| 5 | shape | M[15:0]、N[31:16] |
| 6 | extent | K、向量长度或子描述符数 |
| 7 | flags | bit0 bias；bit1/2 transpose A/B；bit3 外部宏；bit4 packed INT8 |
| 8 | aux0 | 操作专用字段，例如 KV head/token |
| 9 | postprocess | shift[4:0]、activation[6:5] |
| 10~12 | strides | src0、src1、dst 实例/批次步长 |
| 13 | batch/head | batch[15:0]、head[31:16] |
| 14 | events | wait[15:0]、signal[31:16] |
| 15 | ABI/clear | version[15:0]、clear[31:16] |

描述符版本、opcode、必要尺寸、宏子描述符或依赖不合法时必须拒绝。转置通过地址/布局产生，不要求整矩阵复制。完成项固定 16 字节：word0=task ID、word1=状态和 error[7:4]、word2=result、word3=element count。关键错误：abort=3、fetch=6、validation=7、empty queue=8、completion=9、protection=10、dependency=12；`ERROR_INFO` 的 source=1/2 分别代表命令/DMA 来源。

## 5. 算子、DMA 和性能

| Opcode | 算子 |
|---:|---|
| 10/11/12 | INT8 VDOT/GEMV/GEMM |
| 13/14/15 | Conv1x1、im2col Conv3x3、Depthwise |
| 16/17 | Conv3x3/Depthwise line-buffer |
| 20/21 | Banked VDOT/GEMV |
| 30/31 | Tensor GEMM/Batch GEMM（4×4 INT8 PE） |
| 32/39 | Softmax/Causal Softmax Q15 |
| 33/38 | RMSNorm/LayerNorm Q15 |
| 34/35/36/37 | Residual、GELU、requant、SiLU |
| 40/41/42 | QKV/MHA/FFN 描述符宏编排 |
| 43/44 | KV write/KV read |

统一 DMA 支持 DDR↔SPAD 1D、二维 row/stride、indexed gather、tile load/compute/store。burst 最多 16 beats，且在每个 4 KiB AXI 边界拆分；最多四个 tagged read outstanding，RID 选槽位并由匹配 RLAST 释放，BID 归因写响应。传输层允许读响应乱序，但命令派发和完成发布仍按序。`DMA_CFG[0]` 为 gather，`[1]` 是只读 128-bit 能力，`[10:8]` 请求读并发且不得大于 4。

计数器提供 total/DMA/compute/overlap/stall 周期、completed tiles、matrix/MAC/banked-stall、DMA 字节、AR/AW、R stall 和 outstanding 高水位。`有效MAC/s=完成MAC数/实际时间`，`有效GB/s=(DMA读+DMA写字节)/实际时间`，`重叠率=PERF_OVERLAP/PERF_TOTAL`，`停顿率=PERF_STALL/PERF_TOTAL`。

## 6. 寄存器摘要

全部寄存器为 32-bit、相对 AXI-Lite base 的字节偏移。`0x000~0x048` 为 CTRL/STATUS/直接模式配置/IRQ/VERSION/CAP；`0x080~0x0D0` 为 CMDQ/CPLQ、doorbell、abort、watchdog、DMA 和 queue status；`0x0D4~0x100` 是 R0~R3 保护区；`0x104~0x118` 为 DMA 二维/后处理；`0x120~0x148` 为 tile 外部地址、双缓冲和尺寸；`0x14C~0x1B0` 为性能、事件、64-bit 地址高字、ABI、错误来源和 CAP2。

核心编码：STATUS bit0/1/2=busy/done/error；DMA_CTRL bit0/1=start/store；`ABI_INFO={16,64,2,7}`；`CAP2=0x3f` 代表 unified DMA、SPAD line128、matrix line store、64-bit address、DESC_V7、packed INT8。

## 7. 验证证据与边界

VCS `make ai_smoke` 已覆盖 Transformer 30-command 链、随机 GEMV/GEMM/Conv、错误/保护和 reset recovery；扩展回归是 `make ai_comp`、`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`。2026-08-06 的 SpyGlass macro-aware lint 记录为 **0 error、414 warnings、4 info**（共 418 条信息，仍需分类）；CDC setup 为 0 error、12 warnings，CDC structural verify 显示 0 个 unsynchronized crossing、0 个 convergence，但因缺少 Advanced_CDC license 而有 1 条工具/许可证 error，不能称 sign-off；RDC structural verify 的 2 条 error 同样仅为 Advanced_CDC / `rdc_adv_checker` license 缺失，不能作为 RTL reset-crossing 违规解读，也不能称 RDC sign-off。

TSMC28 HPC+ TT/0.9V/25°C 的当前 CNM RTL、真实 32 个 SRAM macro、4.0 ns pre-layout DC：setup/hold WNS、TNS 均 0.00 ns、0 条违例；关键路径为 3.89 ns；area 为 1,245,378.649905 library units，其中 SRAM macro area 为 1,127,675.750000。DC power 报告为 dynamic 22.8290 mW、leakage 1.9733 mW、total 24.8063 mW，但由于 PWR-414/PWR-415/PWR-428，仍属于默认/部分活动率估计，不是 SAIF workload sign-off 功耗。XCZU15EG 100 MHz OOC 记录为 setup WNS +0.187 ns、hold WNS +0.032 ns，约 30,506 LUT、25,238 FF、128 RAMB36、46 DSP，尚非整板验收。

可信表述是“TSMC28、250 MHz pre-layout setup/hold closure”。400 MHz 需要 2.5 ns，当前关键路径仍差约 1.37 ns；需要在 SRAM→SFU、exp/sum 和 tile 边界流水化后，重新完成 DC sweep、P&R、多角 STA、功耗和板级验证，才可作进一步频率/PPA 结论。

## 8. 权威文件

`rtl/top/ai_accel_top.v`（集成）、`rtl/control/ai_accel_regs.v` 与 `sw/include/cimforge_regs.h`（ABI）、`rtl/control/ai_command_processor.v`（命令）、`rtl/control/ai_completion_writer.v`（完成原子性）、`rtl/dma/ai_axi128_dma.v`（DMA）、`rtl/memory/ai_spad_arbiter.v`/`ai_scratchpad.v`（SRAM）、`syn/ai_scratchpad_28nm_macro.v`（28nm wrapper）、`verif/sim/ai_accel.f`（VCS）和 `verif/spyglass/a8_static.prj`（SpyGlass）。
