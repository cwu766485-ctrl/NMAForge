# CIMForge A8 架构说明

**状态：2026-08-09 的 RTL 功能基线。** 本文描述已接入 `ai_accel_top` 的结构；
不把规划中的 UVM、后布局签核或实板验收写成已完成能力。

## 1. 项目范围

CIMForge A8 是单时钟、可综合的全数字 AI 近存加速器 IP：控制面为 AXI-Lite，
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
                                ai_command_processor
                              描述符校验/派发/完成排序
                           ┌────────────┴────────────┐
                       desc fetch              completion writer
                           │                         │
DDR <== 128-bit AXI4 ==> ai_axi128_dma <==> ai_spad_arbiter <==> ai_scratchpad
                                                  │唯一调度入口       │4 bank/512 KiB
                                                  ▼                   ▼
                               INT8 / CNM / Matrix / SFU / Conv / KV-cache
```

- `ai_accel_regs` 只保存配置、产生控制脉冲、记录 sticky status/IRQ；不推进队列指针。
- `ai_command_processor` 独占命令生命周期：`CMDQ_HEAD`、`CPLQ_TAIL`、描述符来源选择、
  校验、计算启动和完成排序。软件发布 `CMDQ_TAIL`，并消费后推进 `CPLQ_HEAD`。
- `ai_spad_arbiter` 是 scheduler-side scratchpad 的唯一拥有者。descriptor/completion
  保持控制面优先；scalar/line/banked compute 与 DMA 在数据面 round-robin；禁止顶层 bypass mux。
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
                                      │      ai_command_processor      │
                                      │ queue owner / descriptor check │
                                      │ dependency / launch / abort    │
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
      │ INT8 VDOT/  │                 │ 4×4 Matrix  │               │ SFU      │      │ Conv/KV   │
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
requant、GELU、SiLU、residual、LayerNorm/RMSNorm、Softmax/causal Softmax、Conv3x3
line-buffer 和 KV-cache primitive。ABI v7.2 增加了 PACK_I8 layout bridge，供
`sw/tools/cimforge_mapper.py` 形成真实的 Transformer 微型命令链：

```text
Q/K/V -> QK^T -> causal/row Softmax -> AV -> projection
      -> residual + norm -> FFN -> residual + norm
```

这是 primitive-composed 的 Transformer 微型命令链，不是生产级融合 MHA/decoder 或完整软件框架。

## 6. 当前实测证据与开放门项

| 项目 | 最新结果 | 边界 |
|---|---|---|
| VCS smoke/随机 | `make ai_smoke`、`ai_comp`、`ai_run` 基线通过 | 尚非 UVM coverage closure |
| CNM A1/A2/A3.1 | A2 四 lane PASS；A3.1 benchmark PASS | 受控 workload，需继续 UVM 对拍 |
| XCZU15EG OOC | 100 MHz，setup/hold WNS `+0.187/+0.032 ns` | standalone IP，非整板 sign-off |
| TSMC28 DC | TT/0.9 V/25 °C，4 ns；setup/hold 0 violation，关键路径 3.89 ns | 单角 pre-layout |
| 面积 | `1,245,378.649905` library units；SRAM `1,127,675.75` | 非物理版图面积 |
| 功耗 | dynamic 22.829 mW、leakage 1.9733 mW | PWR-414/415/428，非 SAIF sign-off |
| SpyGlass lint | 0 error、414 warnings、4 info | warning 待分类 |
| SpyGlass CDC/RDC | 0 unsync crossing/0 convergence；CDC 1、RDC 2 license errors | 缺 Advanced_CDC/rdc_adv_checker |

当前可信表述是“TSMC28、250 MHz pre-layout setup/hold closure”。Formal、LEC、DFT、UVM、
后布局 STA/功耗和实板长期压力测试仍未完成，详见 [`VPLAN.md`](VPLAN.md)。

## 8. 全部电路模块
| 分类 | 模块 | 是否在主功能路径 | 作用 |
|---|---|---:|---|
| 顶层 | `ai_accel_top` | 是 | 把 AXI、寄存器、命令、DMA、SRAM、计算核和 IRQ 接起来。 |
| AXI-Lite | `axi_lite_reg_if` | 是 | AXI4-Lite 五通道协议适配，转换成内部寄存器读写请求。 |
| 寄存器 | `ai_accel_regs` | 是 | 保存软件配置，生成 `submit`、`abort`、DMA start 等脉冲，回报状态、性能计数器和 IRQ。 |
| 调度 | `ai_command_processor` | 是 | CMDQ/CPLQ 指针所有者；取 descriptor、检查合法性/依赖、选择计算核、等待结束并安排 completion。 |
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
| 矩阵核 | `ai_tensor_matrix_core` | 是 | 4×4 INT8 matrix tile，支持 GEMM、Batch GEMM、转置、bias、激活、量化与 line 写回。 |
| SFU | `ai_tensor_sfu_core` | 是 | Softmax、causal Softmax、RMSNorm、LayerNorm、Residual、GELU、SiLU、requant。 |
| 除法器 | `ai_unsigned_divider` | 是，SFU 子模块 | 用于 Softmax 归一化等定点除法。 |
| 整数开方 | `ai_integer_sqrt` | 是，SFU 子模块 | 用于 RMSNorm/LayerNorm 的均方根或方差相关计算。 |
| 卷积核 | `ai_conv3x3_linebuffer_core` | 是 | Conv3x3 与 Depthwise Conv3x3 的 line-buffer 路径。 |
| KV 核 | `ai_kv_cache_engine` | 是 | KV-cache 的写入、按 head/token/stride 读取等 primitive。 |


## 7. 下一步

当前 RTL 是完整的 pre-verification baseline。下一步冻结 SPEC/ABI 后开始 UVM：先实现 AXI-Lite
agent + RAL、CMDQ/CPLQ scoreboard，再接入 AXI4 DMA、scratchpad arbiter、CNM 四 lane 和
Transformer reference model；Formal、LEC、DFT 与增量 DC/SpyGlass 并行推进。
