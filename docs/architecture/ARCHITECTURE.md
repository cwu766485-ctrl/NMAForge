# NMAForge 架构说明

**状态：按 2026-10-25 RTL 层次核对。** 本文说明已接入 `ai_accel_top` 的模块所有权与数据流；
验证收敛、PPA、后布局和板级状态分别以文末链接的专题报告为准。

## 1. 项目范围

NMAForge 是单时钟、可综合的全数字 AI 近存加速器 IP：控制面为 AXI-Lite，
数据主接口为 128-bit AXI4。权威顶层为 `rtl/top/ai_accel_top.v`；可综合 RTL
分别位于 `rtl/control`、`rtl/dma`、`rtl/memory` 与 `rtl/compute`。

它先将 tile、权重和激活搬入靠近计算单元的四 bank scratchpad，再进行 INT8/定点运算，
以减少 DDR 往返。这里的 CNM 是全数字 Compute-Near-Memory：不修改 SRAM bit-cell、
bit-line 或 sense amplifier，不是模拟 CIM/PIM。

## 2. 模块所有权与命令流

```text
CPU -- AXI-Lite --> axi_lite_reg_if --> ai_accel_regs
                                        │配置/doorbell/status/IRQ
                                        ▼
                       ai_parallel_compute_dispatcher
                        普通 CMDQ 多引擎派发/有序退休
                           ┌────────────┴────────────┐
                ai_command_processor          completion writer
                direct/tile/宏子任务
                           │                         │
DDR <== 128-bit AXI4 ==> ai_axi128_dma <==> ai_spad_arbiter <==> ai_scratchpad
                                                  │唯一调度入口       │4 bank/512 KiB
                                                  ▼                   ▼
                               INT8 / CNM / Matrix / SFU / Conv / KV-cache
```

- `ai_accel_regs` 只保存配置、产生控制脉冲、记录 sticky status/IRQ；不推进队列指针。
- `axi_lite_reg_if` 是纯协议适配层：它分别锁存 AXI-Lite AW 与 W，只有两个 sticky flag
  均已置位的**下一时钟周期**才向 `ai_accel_regs` 发内部写请求。这个额外控制周期避免
  AW/W 同拍或不同拍到达时的压缩状态转移，不改变软件 ABI 或数据面性能。
- 普通 compute CMDQ 由 `ai_parallel_compute_dispatcher` 管理 `CMDQ_HEAD`、描述符校验、
  跨引擎派发及按提交顺序退休；每个引擎最多一个在途任务。`ai_command_processor` 仍管理
  direct/tile 模式，并在普通任务排空后接管宏 descriptor 的串行子任务。软件发布 `CMDQ_TAIL`，
  消费 completion 后推进 `CPLQ_HEAD`。
- 多引擎通过 `ai_compute_spad_mux` 汇入 `ai_spad_arbiter` 的单一 core 客户端。仲裁保持
  请求和响应归属，但不建立跨 descriptor 的数据依赖；软件要避免可能并发任务的 SPAD 读写冲突。
- `ai_spad_arbiter` 是 scheduler-side scratchpad 的唯一拥有者。descriptor/completion
  保持控制面优先；scalar/line/banked compute 与 DMA 在数据面 round-robin；禁止顶层 bypass mux。
  BF16/FP16 dot 共用现有 arbiter-owned 32-bit core SPAD 口，不增加 scratchpad bypass。
- `ai_completion_writer` 必须先提交四个 32-bit completion word，才能发布新的 `CPLQ_TAIL`。
- `ai_desc_fetch` 读取片上描述符，`axi_desc_fetch` 读取外部描述符；命令期间来源固定。

### 2.1 完整系统级数据流图

下面这张图把控制面、数据面、scratchpad 仲裁、四 bank CNM 和其他计算引擎放在同一张图中：

```text
                                      ┌──────────────────────────────┐
                                      │             CPU/SoC            │
                                      │  AXI-Lite 配置 / DMA 描述符 / IRQ │
                                      └──────────────┬───────────────┘
                                                     │
                                      ┌──────────────▼───────────────┐
                                      │       AXI-Lite Register IF     │
                                      │ ai_accel_regs: CTRL/STATUS/IRQ │
                                      │ CMDQ/CPLQ/DMA/PERF/PROTECTION │
                                      └──────────────┬───────────────┘
                                                     │ doorbell / status
                                      ┌──────────────▼───────────────┐
                                      │ ai_parallel_compute_dispatcher │
                                      │ CMDQ issue / per-engine slots  │
                                      │ ordered retirement / abort     │
                                      └───────┬──────────┬─────────────┘
                                              │          │
                         ┌────────────────────▼──┐  ┌──▼──────────────────┐
                         │ ai_desc_fetch          │  │ ai_completion_writer │
                         │ SPAD descriptor source │  │ 4 words then tail    │
                         └────────────┬───────────┘  └──────────┬───────────┘
                                      │                          │
┌──────────────────────┐     ┌───────▼──────────────────────────▼───────┐     ┌──────────────────┐
│ DDR / external memory│◄───►│          ai_axi128_dma (AXI4 master)       │◄───►│ axi_desc_fetch   │
│ 1D/2D/gather/tile    │     │ 64-bit addr / 16-beat / 4KiB split / RID  │     │ external desc     │
└──────────────────────┘     └───────────────────────┬──────────────────┘     └──────────────────┘
                                                      │ DMA SPAD requests
                                      ┌───────────────▼────────────────┐
                                      │       ai_spad_arbiter           │
                                      │ sole scheduler admission point │
                                      │ control priority + data RR     │
                                      └──────┬──────────┬───────────────┘
                                             │ scheduler │ banked lane path
                                             │ port      │ valid/ready/mask
                              ┌──────────────▼───┐  ┌──▼──────────────────────────────┐
                              │  ai_scratchpad    │  │      ai_banked_cnm_core         │
                              │ host/debug port   │  │ 4 × Local Controller + Local PE │
                              │ 128-bit line path │  └──┬──────────┬──────────┬────────┘
                              └──┬──────┬──────┬──┘     │          │          │
                                 │      │      │        │          │          │
                         ┌───────▼┐ ┌──▼────┐ ┌▼───────┐ ┌▼───────┐ ┌▼───────┐ ┌▼───────┐
                         │ SRAM B0│ │SRAM B1│ │SRAM B2 │ │SRAM B3 │ │ LC/PE0 │ │ LC/PE1 │ ...
                         │128 KiB │ │128 KiB│ │128 KiB │ │128 KiB │ │local_acc│ │local_acc│
                         └───────┬┘ └──┬────┘ └──┬─────┘ └──┬─────┘ └────────┘ └────────┘
                                 └─────┴─────────┴─────────┴──────────────┐
                                                                         │ 4 partial sums
                                                            ┌────────────▼───────────┐
                                                            │       Global Reducer    │
                                                            │ sum/quantize/writeback  │
                                                            └────────────┬───────────┘
                                                                         │
             ┌───────────────────────────────┬───────────────────────────┼────────────────────┐
             │                               │                           │                    │
      ┌──────▼──────┐                 ┌──────▼──────┐               ┌────▼─────┐      ┌─────▼─────┐
      │ INT8 VDOT/  │                 │ 16×16 Matrix│               │ SFU      │      │ Conv/KV   │
      │ GEMV / CNM  │                 │ GEMM / A3.1 │               │ Softmax/ │      │ linebuffer│
      │ A1/A2.2     │                 │ QKV/FFN      │               │ Norm     │      │ cache     │
      └─────────────┘                 └─────────────┘               └──────────┘      └───────────┘
                                                                         │
                                                            ┌────────────▼───────────┐
                                                            │ SPAD writeback / CPLQ   │
                                                            │ result + events + error  │
                                                            └────────────────────────┘
```

图中需要特别区分两条路径：DMA/标量/line 计算走 `ai_spad_arbiter` 的 scheduler port；
CNM 使用同一个 scratchpad 资源和唯一 admission 规则，但在被接纳后保留四条 bank lane 的
地址、请求和响应状态。Global Reducer 只接收输出边界的 local sum，不接收每个 K-group 的全部中间 partial sum。

## 3. 数字 CNM bank-local 数据路径

对 opcode `0x20/0x21`，`ai_banked_cnm_core` 实例化四个独立的
`ai_bank_local_controller`。每个 bank 拥有地址发生器、A/B 请求和 response-valid lane、
A ping-pong buffer、64-bit local accumulator、Local PE 与事件计数器；partial sum 只在输出边界
送入 Global Reducer。

```text
SRAM bank0 <-> LC0 + PE0 ---> local_acc0 --\
SRAM bank1 <-> LC1 + PE1 ---> local_acc1 ---+--> Global Reducer --> writeback
SRAM bank2 <-> LC2 + PE2 ---> local_acc2 ---+
SRAM bank3 <-> LC3 + PE3 ---> local_acc3 --/
```

A2.2 定向 VCS 已通过：`result=32`、`cycles=13`、`local_acc=12`、`global_reduce=1`、
`reads=24`、`prefetch=8`、`compute=12`、`rsp_wait=0`。CNM admission 支持四条 bank lane
地址/mask；不同 client 之间的细粒度 bank-level arbitration 尚未实现，不能宣称任意访问都无冲突。

A3.1 在 4×4 GEMM tile 中加入 operand 复用和 B response 预取，适合 GEMM、Q/K/V projection、
attention 矩阵乘和 FFN；N=1 VDOT/GEMV 仍优先走 A2。

## 4. 存储和 DMA

当前 profile 使用四个逻辑 bank、总容量 512 KiB 的 scratchpad，提供 host/debug port、一个
arbiter-owned scheduler port，以及 scalar/banked/128-bit line 操作。VCS 使用 `+define+VCS`
行为 RAM；Vivado 使用 XPM；28 nm DC 使用 32 个真实 4K×32 SRAM macro。

`ai_axi128_dma` 是唯一活动 DMA 实现：支持 64-bit 地址、1D/2D/gather/tile、最大 16-beat burst、
4 KiB boundary split、最多四个 tagged read outstanding、ID-aware response 和 abort drain。
应表述为“带 ID 响应关联的 tagged multi-outstanding DMA”；系统级任意乱序和长期压力仍需 UVM/实板证据。

## 5. 计算和 ABI

描述符 ABI 支持 scalar/banked INT8 VDOT、GEMV、GEMM、4×4 tensor GEMM/batched GEMM、
`0x50 BF16_DOT_ACC_FP32`、`0x51 FP16_DOT_ACC_FP32`、requant、GELU、SiLU、residual、LayerNorm/RMSNorm、
Softmax/causal Softmax、Conv3x3 line-buffer 和 KV-cache primitive。A9/ABI v7.3
定义 `0x50` BF16 点积；A10/ABI v7.4 保留 `0x50` 并增加 `0x51` FP16 点积，均沿用
既有 64-byte descriptor 布局，validator 检查命令字段约束。两个格式经唯一
arbiter-owned 32-bit core SPAD 口按 A word、B word 顺序读取 packed operands。端口每周期
至多呈现一个新请求，但利用两个 operand-pair buffer 可保持最多两笔已接受且尚未返回的
scratchpad 读请求；响应按请求顺序归属，不支持无序响应。每个有效元素的 FP32 乘积按递增序号进入
非融合 FP32 累加，最后将一个 32-bit FP32 word 写回 descriptor 指定的目的地址。
它们复用既有 `ai_command_processor` 命令生命周期和 `ai_completion_writer` 完成提交
路径，不新增 scratchpad bypass，也不改变 completion ABI。

Matrix descriptor 仍使用 4×4 tile-major SPAD 布局和原有 ABI；`ai_tensor_matrix_core`
默认实例化 `ai_tensor_matrix_array` 的 `ARRAY_SIZE=16` 配置。controller 从真实 banked SPAD
接口收集 4×4 子块，组成最多 16×16 的宏 tile，超过宏 tile 尺寸时遍历 M/N tile；16×16 和
32×16（跨宏 tile）已通过 block-level 独立 Golden。4×4/8×8/16×16 物理 array 参数也有统一
VCS benchmark。SPAD 读取当前仍按 request/response 串行推进，尚无 tile 预取或与 MAC 重叠；
Compute Cluster 完整 UVM 和 DC/PPA 仍开放。实现与证据见[Compute Cluster 升级路线](../verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md)。

ABI v7.2 曾增加 PACK_I8 layout bridge，现有 `sw/tools/cimforge_mapper.py` 可用它形成
Transformer 微型命令链：

```text
Q/K/V -> QK^T -> causal/row Softmax -> AV -> projection
      -> residual + norm -> FFN -> residual + norm
```

这是 primitive-composed 的 Transformer 微型命令链，不是生产级融合 MHA/decoder 或完整软件框架。

## 6. 验证与实现状态入口

模块实例关系、接口所有权和数据流以本文及当前 RTL 为准。各计算引擎的
功能测试、形式结果和原始 DUT 覆盖率见[compute-engine 状态页](../verification/COMPUTE_ENGINE_STATUS.md)；
A10 需求追踪与剩余验证项见 [A10 RTM](../verification/A10_DV_RTM.md)。

静态分析限制见 [STATIC_ANALYSIS_REPORT.md](../verification/STATIC_ANALYSIS_REPORT.md)
和 [`dv/spyglass/LINT_TRIAGE.md`](../../dv/spyglass/LINT_TRIAGE.md)。商用 28 nm
pre-layout 结果见 [TSMC28_SYNTHESIS_REPORT.md](../verification/TSMC28_SYNTHESIS_REPORT.md)。
这些报告分别说明工具版本、约束、结果边界和未闭合项；架构说明不复制易过期的
逐次 coverage、seed 或 PPA 数字。

## 7. 全部电路模块
| 分类 | 模块 | 是否在主功能路径 | 作用 |
|---|---|---:|---|
| 顶层 | `ai_accel_top` | 是 | 把 AXI、寄存器、命令、DMA、SRAM、计算核和 IRQ 接起来。 |
| AXI-Lite | `axi_lite_reg_if` | 是 | AXI4-Lite 五通道协议适配，转换成内部寄存器读写请求。 |
| 寄存器 | `ai_accel_regs` | 是 | 保存软件配置，生成 `submit`、`abort`、DMA start 等脉冲，回报状态、性能计数器和 IRQ。 |
| 调度 | `ai_parallel_compute_dispatcher` | 是 | 普通 compute CMDQ 指针所有者；最多每引擎一个在途任务，维护任务归属并按 CMDQ 顺序退休。 |
| 串行命令控制 | `ai_command_processor` | 是 | 管理 direct/tile 命令，接收普通队列排空后的宏 descriptor handoff，并串行执行宏子任务。 |
| Compute SPAD 子仲裁 | `ai_compute_spad_mux` | 是 | 将七个计算引擎的请求轮转映射到唯一 scheduler core-SPAD 客户端，并归还各自响应。 |
| 片上 descriptor | `ai_desc_fetch` | 是 | 从 scratchpad 读取 64B descriptor。 |
| 外部 descriptor | `axi_desc_fetch` | 是 | 从 DDR 读取外部 descriptor，使用 AXI4 读通道。 |
| completion | `ai_completion_writer` | 是 | 向 CPLQ 连续写 4 个 32-bit word，写完后才能推进 `CPLQ_TAIL`。 |
| 计数器 | `ai_perf_monitor` | 是 | 统计 DMA 字节数、AR/AW 数、stall、outstanding 高水位、矩阵 MAC 周期等。 |
| tile 调度 | `ai_tile_pipeline` | 是，作为命令处理器子模块 | 管理 ping-pong tile 的 load / compute / store 重叠流程。 |
| DMA | `ai_axi128_dma` | 是 | 128-bit AXI4 主机 DMA；支持 1D、2D、gather、最大 16-beat burst、4 KiB 切分、最多 4 笔 tagged read outstanding。 |
| 仲裁 | `ai_spad_arbiter` | 是 | scratchpad 的唯一调度入口；descriptor/completion 高优先级，计算/DMA 数据面轮询。 |
| SRAM | `ai_scratchpad` | 是 | 512 KiB、4 bank SRAM；支持 32-bit 单字、128-bit line、四 lane banked/CNM 读取。 |
| 保护 | `ai_spad_protection` | 是，实例化多次 | 检查 host、compute、line、banked、completion 的地址是否越界或权限冲突。 |
| 标量 INT8 核 | `ai_int8_compute_core` | 是 | 普通 INT8 VDOT、GEMV、GEMM tile、Conv1x1 等标量/基础计算控制。 |
| CNM 核 | `ai_banked_cnm_core` | 是 | opcode `0x20/0x21` 的四 bank CNM VDOT/GEMV 顶层。 |
| Local Controller | `ai_bank_local_controller` | 是，CNM 内 4 个实例 | 每个 bank 自己产生地址、等待读响应、预取、双缓冲、局部累加。 |
| Local PE | `ai_bank_pe` | 是，CNM/基线核子模块 | 一个 32-bit packed INT8 dot4 乘加单元。 |
| 混合精度点积核 | `ai_mixed_precision_dot_fp32_core` | 是 | `0x50` BF16 与 `0x51` FP16 共享控制、arbiter-owned 32-bit core SPAD 口和 FP32 顺序累加；按序读 A/B 并写回一个结果 word。 |
| BF16 兼容包装器 | `ai_bf16_dot_fp32_core` | 否（兼容/独立验证） | 固定选择 BF16 格式的旧接口包装器；顶层产品路径使用混合精度核心。 |
| 矩阵核 | `ai_tensor_matrix_core` + `ai_tensor_matrix_array` | 是 | ABI/SPAD 仍按 4×4 tile-major；top 默认 16×16 INT8 array，支持宏 tile 和跨 tile 执行，三 seed Golden 回归通过；SPAD 预取/overlap、完整 Cluster UVM 与 PPA 未收敛。 |
| SFU | `ai_tensor_sfu_core` | 是 | Softmax、causal Softmax、RMSNorm、LayerNorm、Residual、GELU、SiLU、requant。 |
| 除法器 | `ai_unsigned_divider` | 是，SFU 子模块 | 用于 Softmax 归一化等定点除法。 |
| 整数开方 | `ai_integer_sqrt` | 是，SFU 子模块 | 用于 RMSNorm/LayerNorm 的均方根或方差相关计算。 |
| 卷积核 | `ai_conv3x3_linebuffer_core` | 是 | Conv3x3 与 Depthwise Conv3x3 的 line-buffer 路径。 |
| KV 核 | `ai_kv_cache_engine` | 是 | KV-cache 的写入、按 head/token/stride 读取等 primitive。 |


## 8. 下一步

当前 RTL 是已通过 directed/smoke 和已执行 block-UVM 基础回归的 pre-sign-off baseline；
它不是 UVM coverage、formal、LEC、后布局或实板签核完成的设计。下一步优先补
CMDQ/CPLQ、scratchpad arbiter、tensor datapath 的 UVM scoreboard/coverage，再做
多 seed 回归、Formal、LEC、DFT 与增量 DC/SpyGlass。Matrix 8×8/16×16 controller 接入、
真实 Weight/Activation SPAD dataflow 与 PPA 目标见[升级路线](../verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md)。
