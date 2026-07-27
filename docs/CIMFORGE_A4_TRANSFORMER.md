# CIMForge A4 Transformer 前端设计规格

## 1. 定位与边界

A4 在 A3 matrix/SFU primitive 基础上补齐进入 Linux/VNC 验证前的设计闭环：

- `LayerNorm Q15` 真实三遍定点数据通路；
- descriptor v4 宏命令以及 `QKV_PROJ/MHA/FFN` 硬件展开；
- KV-cache 行地址 gather；
- AXI load 最多 4 笔同 ID outstanding read；
- 512 KiB 四 bank scratchpad、descriptor v3 primitive、事件依赖与 A2 算子保持兼容。

A4 的 fused command 是 **command-level macro fusion**：减少 CMDQ 取命令、completion 和 IRQ
开销，但不声称已经把多个算子的 PE/SFU 数据通路熔成一个周期级流水。真正的跨算子
datapath fusion 必须在性能计数证明 command/scratchpad 往返成为瓶颈后再做。

## 2. 版本与 capability

- `VERSION = 0x10000004`；
- `CAP[16]` LayerNorm；
- `CAP[17]` descriptor v4 macro；
- `CAP[18]` DMA gather；
- `CAP[19]` DMA read outstanding；
- A3 的 `CAP[12:15]` 和更早 capability 保持不变。

软件以 capability 判断功能，不应只比较完整版本号。

## 3. LayerNorm Q15

`OP_LAYERNORM_Q15 = 0x38`，使用 descriptor v3。`src0`、`src1`、`bias_base`、`dst`
分别是 INT32 input、Q15 gamma、INT32 beta 和 INT32 output；`length` 是元素数，`aux0`
是整数 epsilon。`src1=0` 时 gamma 默认为 32768；flag bit0 置位时读取 beta，否则 beta
为零。

RTL 顺序执行：

1. `mean = trunc_toward_zero(sum(x) / N)`；
2. `variance = sum((x-mean)^2) / N`；
3. 整数平方根和 Q30 reciprocal；
4. `sat32((((x-mean)*gamma)>>15) * reciprocal_q30 >> 30) + beta`。

sum/square 使用 64-bit 中间值，gamma 后先做 INT32 饱和。该整数规则由
`verif/ref/ai_a3_reference.py::layernorm_q15` 固化。

## 4. Descriptor v4 宏命令

父 descriptor 仍为 16 word / 64 byte：

| word | 含义 |
|---:|---|
| 0 | `[31:16] parent task_id`，`[7:0] opcode` |
| 1 | 64-byte 对齐的 child descriptor list 基地址 |
| 6 | `[15:0] child_count` |
| 7 | bit3：child list 位于外部 AXI memory；0 表示 scratchpad |
| 14 | `[31:16] parent signal_mask`，`[15:0] parent wait_mask` |
| 15 | `[31:16] parent clear_mask`，`[7:0] version=4` |

宏 opcode：

- `0x40 QKV_PROJ`：恰好 3 个 child；
- `0x41 MHA`：3..256 个 child；
- `0x42 FFN`：3..256 个 child。

child 是正常的 v2/v3 primitive descriptor，允许各自使用依赖事件，但禁止嵌套宏。
软件负责按 QKV、QK-transpose/Softmax/AV/projection、FFN 的语义排列 child；硬件负责逐条
重新取 descriptor、检查、启动和退休。任一 fetch/descriptor/dependency/compute 错误都会
fail-stop，错误以父 task ID 上报，后续 child 不再执行。

整个宏只发布一个 completion：`result` 为最后已执行 child 的结果，`cycles/elements` 为
所有已执行 child 的和。父 clear 在宏启动时应用，父 signal 只在所有 child 成功后产生。
软件应使用 `cimforge_desc_v4_macro_init()`，不要手工拼 word。

## 5. KV-cache gather 与多 outstanding DMA

新增寄存器：

| offset | 名称 | 含义 |
|---:|---|---|
| `0x16c` | `DMA_CFG` | bit0 gather enable，bits `[10:8]` read outstanding，0 按 1 处理，最大 4 |
| `0x170` | `DMA_GATHER_INDEX` | scratchpad 内 32-bit 索引表基地址 |

gather 仅支持 DDR-to-scratchpad load。`DMA_ROW_COUNT` 是索引数，`DMA_ROW_WORDS` 是每个
KV row 的 word 数，索引表的每项是 4-byte 对齐的 **绝对 DDR byte address**；目标 row
按 `DMA_SPAD_STRIDE` 排列。store+gather、零 row count 或未对齐地址返回 configuration
error。

普通 1D/2D load 和 gather 共用 4 深度 AR metadata FIFO。所有请求使用相同 AXI ID，依赖
AXI 的同 ID response ordering，以 FIFO 中的 destination/length 将每个 R burst 写回
scratchpad。每个 burst 仍限制为 64 beat 且不能跨 4 KiB。abort 或 AXI/scratchpad 错误后
停止发新 AR、禁止新的 scratchpad side effect，并 drain 所有已接受 R burst 后才完成。

写方向保留单 AW/W/B 流：32-bit scratchpad 读口和 AXI W channel 本身串行，提前发多个 AW
不能提高当前 datapath 的有效吞吐，反而扩大 error/abort 恢复状态。本版 capability 因此明确
命名为 **read outstanding**，主要优化权重、activation 和 KV-cache load。

## 6. 验证前冻结项与后续 gate

本地 XPM smoke 必须覆盖：LayerNorm、三种宏 opcode、父 completion 聚合、child fail-stop、
多 AR 在首个 RLAST 前被接受、KV gather、2D/4 KiB/error/abort 回归及 A2/A3 算子回归。

以下工作不是“遗漏的设计”，而是设计冻结后的验证/实现 gate：Linux/VNC VCS coverage、
UVM、lint、CDC/RDC、formal、XCZU15EG post-route，以及 A4 bitstream 的 DDR DMA/CMDQ/
completion/GIC IRQ/ILA 实板复验。完成这些 gate 前只能称为 RTL design complete，不能称为
工业化 sign-off。

## 7. 2026-07-22 本地冻结证据

- Vivado XSim/XPM `a4_signoff.log`：LayerNorm、KV gather、首个 RLAST 前 2 笔 AR、
  QKV/MHA/FFN 聚合 completion、child fail-stop、A2/A3 directed/random 回归全部通过，
  最终 `TEST PASS`；
- Python：`python verif/ref/ai_a3_reference.py --cases 1000 --seed 20260722` 输出
  `A4_REFERENCE_PASS cases=1000 seed=20260722`；
- XCZU15EG OOC、Vivado 2024.1、100 MHz：17,560 LUT、9,896 FF、128 RAMB36E2、22
  DSP48E2，setup/hold 为 `+0.772/+0.083 ns`，0 failing endpoint；
- 综合为 0 error、0 critical warning。DRC 的 151 个 warning 仍是 DSP input/output/reset
  pipeline 方法学项；OOC methodology 的 TIMING-18 是无 board I/O delay 的预期项，均需在
  后续整板 post-route 重新评估。
