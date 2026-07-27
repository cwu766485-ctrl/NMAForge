# CIMForge A3 Transformer 前端规范

## 1. 设计定位

CIMForge A3 在保持 A2 AXI-Lite/AXI4、512 KiB scratchpad、CMDQ 和 completion ABI
兼容的前提下，新增可由 descriptor 组合的 Transformer 基础算子。A3 的准确定位是
**可编程 tensor primitive accelerator**：软件把 QKV projection、attention、projection、
residual/norm 和 FFN 拆成多条命令，并通过事件依赖连接起来。

A3 不宣称单命令端到端 MHA，也不宣称工业 sign-off。工业化仍需要 UVM 覆盖率、
lint/CDC/RDC/formal、数值误差统计、PPA、STA/hold closure、门级仿真和软件栈。

```text
AXI4 DDR <-> 64-beat/2D DMA ----+
                                 |
AXI-Lite -> register file -> command processor -> 16-bit event scoreboard
                                 |                 |
                                 +-> 4x4 matrix ---+
                                 +-> vector/SFU ---+-> shared banked scratchpad
                                 +-> A2 cores -----+        (512 KiB default)
                                      |
                                  completion ring / IRQ
```

## 2. A3 算子

| opcode | 算子 | 主要数据契约 |
|---:|---|---|
| `0x30` | `TENSOR_GEMM` | 4x4 INT8 PE tile，INT64 累加、INT32 输出 |
| `0x31` | `BATCH_GEMM` | GEMM 加 batch/head 与三路 batch stride |
| `0x32` | `SOFTMAX_Q15` | 输入 signed Q8.8 log2 score，输出 unsigned Q0.15 |
| `0x33` | `RMSNORM_Q15` | INT32/Q8.8 输入、signed Q0.15 gamma、INT32 输出 |
| `0x34` | `RESIDUAL_I32` | 双输入相加、算术右移、INT32 饱和 |
| `0x35` | `GELU_Q8_8` | 有界分段近似 |
| `0x36` | `REQUANT_I8` | 算术右移并饱和到 signed INT8，32-bit 符号扩展写回 |
| `0x37` | `SILU_Q8_8` | 有界分段近似 |

Matrix engine 每个 MAC 周期实例化 16 个 signed INT8 乘法，采用 4x4 output-stationary
累加器。`M`、`N` 必须非零且为 4 的倍数，descriptor 的 `K` 字段表示
`K_WORDS=K/4`。A/B 均为 tile-major 布局：A 的 bank `r` 保存 row `r` 的四个连续
K 元素，B 的 bank `c` 保存 column `c` 的四个连续 K 元素。`TRANSPOSE_A/B` 在
4x4 K slice 的地址/选 lane 边界完成，不复制完整矩阵。输出为 row-major INT32。

Matrix 后处理支持可选 INT32 bias、0..31 算术右移、none/ReLU/ReLU6 和 INT32 饱和。
FPGA 综合应检查乘法是否映射到 DSP48；不能只根据 RTL 中存在乘法器就宣称吞吐。

## 3. Descriptor v3 ABI

Descriptor 仍为 64-byte、16 个 32-bit word，便于沿用现有 CMDQ：

| word | 字段 |
|---:|---|
| 0 | `[31:16] task_id, [7:0] opcode` |
| 1/2/3/4 | `src0/src1/bias_base/dst` scratchpad byte address |
| 5 | `[31:16] N, [15:0] M` |
| 6 | `K_WORDS`（matrix）或 `length`（SFU） |
| 7 | flags：bit0 bias、bit1 transpose A、bit2 transpose B |
| 8 | `aux0`：RMSNorm epsilon，其余 op 保留 |
| 9 | `[6:5] activation, [4:0] shift` |
| 10/11/12 | `src0/src1/dst_batch_stride`，单位 byte |
| 13 | `[31:16] head_count, [15:0] batch_count`；硬件执行二者乘积个 instance |
| 14 | `[31:16] signal_mask, [15:0] wait_mask` |
| 15 | `[31:16] clear_mask, [7:0] version=3` |

Matrix engine 将 batch×head 展平，三个 batch stride 表示相邻 flattened instance 的 byte
跨度。`TENSOR_*` 和 SFU opcode 强制要求 version 3；A2 opcode/descriptor v2 保持原行为。
软件应使用 `sw/include/cimforge_regs.h` 的 `cimforge_desc_v3_init()`，避免手工打包。

## 4. 依赖与完成语义

Command processor 内有 16-bit event scoreboard：

- 只有 `(EVENT_STATUS & wait_mask) == wait_mask` 才启动命令；
- 启动时原子应用 `clear_mask`；
- 只有命令成功完成才置位 `signal_mask`，失败/abort 不产生成功事件；
- 等待超过 65535 cycle 报 dependency-timeout error `12`；
- completion 的四个 word 全部写入后才推进 `CPLQ_TAIL`。

这允许软件表达：QKV → QKᵀ → Softmax → AV → projection → residual/RMSNorm → FFN，
而无需为每个 Transformer 阶段增加 MMIO 寄存器。当前 scoreboard 是单 command issue，
事件用于正确性和 command chaining，不代表多个 compute engine 同时执行。

## 5. 数值契约

Softmax 先减最大值，再用 log2-domain Q8.8 分段线性 `exp2`，用 64-bit 累加求和，
最后以迭代除法得到 Q0.15 概率。RMSNorm 使用 64-bit sum-of-squares、整数平方根和
Q30 reciprocal；gamma 乘法后的中间值先做 INT32 饱和，再进入 reciprocal scaling。
GELU/SiLU 是资源受控的分段近似，不是 IEEE 浮点实现。

`verif/ref/ai_a3_reference.py` 是这些定点规则的可执行模型。正式模型验收仍需加入真实
Transformer tensor 分布，统计 softmax KL/最大绝对误差、RMSNorm 余弦相似度以及
端到端层输出误差；当前 directed/random smoke 只证明 RTL 与既定整数规则一致。

## 6. DMA 与存储

AXI DMA 的最大 INCR burst 从 16 提升到 64 beat，保留 4 KiB boundary split、2D row/
stride、scratchpad protection、abort 后 drain 和单 outstanding 语义。64 beat 在 AXI32
上等于 256 byte。更长 burst 降低地址通道开销，但实际 DDR 带宽必须以上板计数器为准。

当前仍由软件/DMA 将全局 tensor 切成 bank-compatible tile；尚无 KV-cache 专用 gather、
多 outstanding transaction 或完整硬件 transpose engine。只有在性能报告证明 AXI 延迟
是瓶颈后，才应选择 outstanding 深度并补齐乱序 tag/错误回收设计。

## 7. 软件组合示例

一个 decoder attention 子层可由以下 descriptor 链组成：

1. 三条 `BATCH_GEMM` 生成 Q/K/V；
2. `BATCH_GEMM` 配合 transpose-B flag 计算 QKᵀ，并在量化参数中包含
   `1/sqrt(head_dim)` scaling；
3. 每行 `SOFTMAX_Q15`；
4. `BATCH_GEMM` 计算 probability × V；
5. `TENSOR_GEMM` projection；
6. `RESIDUAL_I32` + `RMSNORM_Q15`；
7. 两次 `TENSOR_GEMM`，中间插入 `GELU_Q8_8` 或 `SILU_Q8_8` 完成 FFN。

各阶段用 wait/signal/clear mask 管理 buffer ownership。A3 尚未提供 fused `OP_MHA`、
`OP_QKV_PROJ` 或 `OP_FFN`，因此性能结论必须包含 command、DMA 和 layout 开销。

## 8. 版本与验收边界

- `VERSION = 0x10000003`；
- `CAP[12]` matrix、`CAP[13]` SFU、`CAP[14]` descriptor v3、`CAP[15]` DMA64；
- `EVENT_STATUS` 位于寄存器 offset `0x168`；
- A3 RTL smoke 必须覆盖 4x4 GEMM、batch/transpose、全部 SFU、dependency、completion
  ordering、64-beat DMA 和 A2 回归；
- A3 bitstream 必须重新综合并重跑 XCZU15EG DDR DMA/CMDQ/completion/IRQ/ILA，A2
  的 `0x10000002` 实板日志不能替代 A3 上板验收。

### 8.1 2026-07-22 XCZU15EG OOC 基线

Vivado 2024.1、`xczu15eg-ffvb1156-2-i`、10.000 ns constraint 的 post-synthesis
结果如下：

| LUT | FF | RAMB36E2 | DSP48E2 | setup WNS | hold WHS |
|---:|---:|---:|---:|---:|---:|
| 16,115 | 9,106 | 128 | 22 | +1.067 ns | +0.083 ns |

综合为 0 error、0 critical warning、0 timing failing endpoint。第一次未流水化 SFU 的 WNS
为 -4.464 ns；通过 XPM read-bank tag 对齐以及 SFU product/normalize 分级寄存修复。
OOC DRC 的 151 项均为 DSP input/output pipeline 方法学 warning，没有 DRC error；它们仍需在
post-route/整板实现中重新评估。当前 22 个 DSP 主要来自宽 SFU/地址算术，4x4 INT8 MAC
仍大量映射 LUT，因此后续 FPGA PPA 优化应比较“LUT packed INT8”和“显式 DSP profile”，
不能把 DSP 总数直接等价为 16 个 PE 的占用。
