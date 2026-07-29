# Project Prospective

本文档记录 CIMForge 后续演进方向。当前项目主线应从早期 AHB SRAM/SOM demo，收敛为一个更适合求职和工程展示的 **AXI/DMA scratchpad-based INT8 AI accelerator IP**。

## 1. 当前定位

当前项目已经从简单 SRAM controller 演进为一个小型片上 AI 加速器原型：

```text
AXI-Lite control interface
+ AXI master DMA
+ 512 KiB parameterized banked scratchpad SRAM
+ descriptor command queue
+ completion queue / IRQ
+ INT8 VDOT / GEMV / GEMM_TILE / CONV1x1 / CONV3x3 / DWCONV3x3 compute
```

更准确的项目定位是：

> 一个数字 RTL 层面的 scratchpad-based near-memory INT8 accelerator prototype，而不是 transistor-level CIM macro。

其中：

- AXI-Lite 用于 CPU 配置寄存器、读状态、访问 scratchpad window。
- AXI master 用于内部 DMA 或 external descriptor fetch 主动访问外部 DDR/memory。
- scratchpad SRAM 用于缓存 input、weight、output、descriptor 和 completion entry。
- INT8 compute core 支持 packed INT8 dot4、GEMV、GEMM tile。
- descriptor/completion queue 支持更接近真实驱动的“提交任务 -> 硬件执行 -> 完成上报”流程。

截至 2026-07-17，A2 已完成 XCZU15EG 整板时序收敛与实板 P0 验收：A53 裸机软件通过
AXI-Lite/AXI4 驱动 DDR 双向 DMA、external descriptor CMDQ、VDOT、四字 completion 和
GIC IRQ，ILA 可同时观察控制面与数据面。所以下文第 2～8 节保留为架构演进记录；其中已经
实现的条目不再是待办，最新执行优先级以第 9 节为准。

截至 2026-07-22，A4 验证前 RTL 已冻结：新增 4x4 tensor matrix/SFU 基础算子、Softmax、
RMSNorm/LayerNorm、descriptor v3 dependency event、descriptor v4 QKV/MHA/FFN macro、
KV-cache gather 和最多 4 笔 AXI read outstanding。Windows XPM 全量 smoke 与 1000-case
Python reference 均通过；XCZU15EG 100 MHz OOC 综合为 17,560 LUT、9,896 FF、128
RAMB36、22 DSP，setup/hold slack 为 `+0.772/+0.083 ns`。当前下一 gate 已从“继续补 RTL”
切换为 Linux/VNC 的 VCS coverage、UVM、lint/CDC/formal；随后才是 A4 post-route 与新版
bitstream 实板复验。后文仍出现的 single-outstanding/不建议 Transformer 等文字是历史决策
记录，不再代表 A4 当前能力。

### 1.1 CIM 口径边界

本项目后续可以借鉴 CIM/PIM 的数据局部性思想，但不建议直接宣称为“真正的 CIM macro”或“全数字 CIM macro”。

更严谨的分类如下：

| 类型 | 计算位置 | 计算方式 | 本项目是否属于 |
|---|---|---|---|
| 普通数字 AI accelerator | SRAM 外部 MAC array | 数字 MAC | 部分相似 |
| Digital SRAM-CIM | SRAM macro 内/周边计算外围 | XNOR/popcount/bit-serial MAC 等数字逻辑 | 不直接实现 |
| Analog CIM | bitline/cell/sense amp 附近 | 电压/电流/电荷累加，常需要 ADC/DAC | 不属于 |
| All-digital near-memory accelerator | SRAM bank 附近 | 标准 RTL PE + reduction | 本项目目标方向 |

需要特别说明：

- SRAM macro 本体在物理层一定包含 bitline、precharge、sense amplifier 等电路行为，不能简单说成“纯数字”。
- 所谓 digital CIM 通常指“计算路径主要是数字逻辑”，而不是说 SRAM bitcell/bitline 本身没有模拟特性。
- 本项目不修改 SRAM bitcell、bitline 或 sense amplifier，也不实现 custom SRAM-CIM macro。
- 本项目更准确的口径是 **digital CIM-inspired / PIM-inspired all-digital near-memory accelerator**。

推荐面试表述：

> 本项目参考 CIM/PIM 减少数据搬运的思想，但实现层面采用标准数字 RTL：AXI DMA 将数据搬入 banked scratchpad，INT8 PE 靠近 SRAM bank 产生 partial sum，再由 reduction tree 汇总。它不是 transistor-level SRAM-CIM macro，而是一个更容易综合、验证和 SoC 集成的 all-digital near-memory accelerator。

## 2. SOM 的定位调整

SOM 可以保留为实验/legacy 模式，但不建议继续作为项目主线。

原因：

- SOM 在工业界 AI 加速器中不是主流 workload。
- 面试中更容易被追问应用场景，解释成本高。
- 工业界更常见的是 MatMul/GEMM/GEMV/Conv/Attention 相关算子。

建议主线改为：

```text
INT8 VDOT
INT8 GEMV
INT8 GEMM_TILE
CONV1x1
CONV3x3 / DWCONV3x3 optional
```

文档和简历中可以这样描述：

> SOM mode is kept as an experimental memory-centric research mode. The mainline accelerator workload is INT8 matrix/convolution style compute.

## 3. 工业化 RTL 提升路线

### 3.1 主线算子升级

当前已有 VDOT/GEMV/GEMM_TILE。下一步优先级：

| 优先级 | 功能 | 价值 |
|---:|---|---|
| P0 | INT8 GEMV/GEMM_TILE 完善 | 最通用，适合 AI accelerator/NPU 面试 |
| P1 | CONV1x1 | 可复用 GEMM 数据流，工业界常见 |
| P2 | CONV3x3 | CNN/tinyML 常见 workload |
| P2 | DWCONV3x3 | MobileNet/edge AI 常见 |
| P3 | Attention-friendly MatMul | 可用于 QK^T / AV，但不做完整 softmax |

不建议短期做完整 Transformer attention，因为 softmax、归一化、buffer 管理和数值格式会快速拉高复杂度。

### 3.2 Descriptor 格式工程化

当前 descriptor 已支持 op/src/dst/M/N/K/task_id 等字段。后续可以统一扩展为：

```text
word0  : op, flags, task_id
word1  : src0_base
word2  : src1_base
word3  : bias_base
word4  : dst_base
word5  : M, N
word6  : K_WORDS / LENGTH
word7  : src0_stride
word8  : src1_stride
word9  : scale_shift, zero_point, activation
word10 : shape / padding / conv config
word11 : scratchpad region / buffer id
word12~15 : reserved / version / checksum
```

目标是让软件通过 descriptor 描述任务，而不是每种模式都临时增加一堆寄存器。

### 3.3 Scratchpad 地址保护

当前 scratchpad 内部 input/weight/output/cmdq/cplq 主要靠软件约定。更工业化版本应增加 region 配置和越界检查：

```text
SPAD_REGION0_BASE / LIMIT / PERM
SPAD_REGION1_BASE / LIMIT / PERM
SPAD_REGION2_BASE / LIMIT / PERM
SPAD_REGION3_BASE / LIMIT / PERM
```

可检查：

- src0/src1/dst 是否越界。
- dst 是否覆盖 command queue 或 completion queue。
- descriptor 地址是否合法。
- DMA load/store 是否访问未授权区域。

这可以形成清晰的 memory protection 设计点。

### 3.4 Command/Completion Queue 完整化

当前队列更像单 outstanding ring consumer。后续目标：

```text
CMDQ_HEAD / CMDQ_TAIL
CPLQ_HEAD / CPLQ_TAIL
queue full / empty
overflow / underflow error
doorbell count
连续消费多条 descriptor
completion ordering check
```

真正工程化的软件流程应是：

```text
software writes descriptors
software updates CMDQ_TAIL
software rings DOORBELL
hardware consumes CMDQ_HEAD
hardware writes completion at CPLQ_TAIL
software consumes CPLQ_HEAD
```

### 3.5 DMA 工业化

当前 DMA 已支持 32-bit、single outstanding、INCR burst、multi-burst、4KB boundary split。后续可增强：

| 功能 | 价值 |
|---|---|
| 2D DMA stride | 支持矩阵/卷积 tile 搬运 |
| scatter-gather descriptor | 更接近真实 DMA |
| 随机 back-pressure 验证 | 提高协议鲁棒性 |
| outstanding read/write | 提升吞吐，但复杂度较高 |
| AXI prot/cache/qos 预留 | 更像 SoC 集成接口 |

建议优先做 2D DMA stride，因为它和 CONV/GEMM tile 最相关。

### 3.6 性能计数器和 debug

当前已有 cycle_count/element_count。后续建议补：

```text
dma_read_words
dma_write_words
compute_active_cycles
dma_active_cycles
spad_stall_cycles
bank_conflict_count
desc_count
completion_count
error_first_addr
last_task_id
```

这些计数器非常适合面试中解释性能瓶颈和优化方向。

### 3.7 时序友好化

当前 RTL 以原型验证为主，后续应逐步变得更适合综合和时序收敛：

- 配置寄存器在 start/doorbell 时锁存到 local job config。
- scratchpad read latency 参数化，避免默认组合读假设。
- INT8 multiplier/add tree 加 pipeline。
- descriptor decode 加 pipeline。
- AXI-Lite/AXI master 加 skid buffer。
- 多 bank scratchpad 仲裁 one-hot 化。
- reset、abort、busy、done 状态定义更严格。

## 4. 商业近存计算可借鉴方向

已有商业/准商业产品可以借鉴架构思想：

| 厂商/方向 | 类型 | 可借鉴点 |
|---|---|---|
| Samsung HBM-PIM | HBM 内 PIM | memory channel/bank 附近放计算单元 |
| Samsung AXDIMM | DIMM 近存计算 | memory-attached accelerator 思路 |
| SK hynix GDDR6-AiM / AiMX | GDDR6 Accelerator-in-Memory | 面向 FC、attention、activation 等 memory-intensive workload |
| UPMEM PIM DIMM | DRAM module 内 DPU | 多 bank + local processing unit |

这些产品不适合直接在本项目里复刻电路级 CIM 或 custom memory macro，但可以借鉴架构层面的 memory-attached compute 思想：

```text
数据靠近 memory bank
每个 bank 附近放小 PE
bank-local partial sum
reduction tree 汇总
减少全局数据搬运
```

## 5. 建议新增：Banked Near-Memory INT8 Engine

下一阶段最适合实现一个轻量版商业化近存计算抽象：

```text
Banked Scratchpad Near-Memory INT8 Engine
```

它的含义不是“在 SRAM bitline 里直接计算”，而是：

```text
banked scratchpad SRAM
+ bank-local digital PE
+ partial-sum reduction tree
```

也就是把计算单元放到 SRAM bank 附近，用全数字 RTL 实现局部计算和汇总。

目标结构：

```text
                    CPU
                     |
                  AXI-Lite
                     |
+------------------------------------------------+
|                 ai_accel_top                   |
|                                                |
|  regs / descriptor / completion / IRQ          |
|                                                |
|  AXI DMA  <------------------> external DDR    |
|                                                |
|  +---------- scratchpad SRAM ----------+       |
|  | bank0 | bank1 | bank2 | bank3       |       |
|  +-------------------------------------+       |
|      |       |       |       |                 |
|    PE0     PE1     PE2     PE3                |
|      \       \       \       \                 |
|       partial sum / reduction tree             |
|                    |                           |
|                  output                        |
+------------------------------------------------+
```

推荐新增模块：

```text
rtl/
  ai_bank_pe.v
  ai_reduction_tree.v
  ai_banked_compute_core.v
```

新增 op：

```text
OP_BANKED_VDOT = 8'h20
OP_BANKED_GEMV = 8'h21
```

第一版语义：

```text
BANKED_VDOT:
  每个 bank 负责一段 K 维度，PE 产生 partial sum，reducer 汇总 result。

BANKED_GEMV:
  每个 bank 负责一段 input/weight，按 row 产生 partial sum，最终 reduce 写 output。
```

简历/面试口径：

> 参考 HBM-PIM、GDDR6-AiM 和 PIM DIMM 中 memory-attached compute 的思想，在数字 RTL 层实现 banked scratchpad near-memory INT8 engine。每个 SRAM bank 附近布置轻量 PE，产生 partial sum 后由 reduction tree 汇总，以降低单 compute core 反复读 SRAM 的瓶颈。该设计是 digital CIM-inspired near-memory architecture，不宣称实现 transistor-level CIM macro。

## 6. 软件和验证同步提升

要让项目真正像可集成 IP，需要补软件视角。

建议新增：

```text
sw/
  ai_accel_regs.h
  ai_accel_driver.c
  ai_accel_demo.c
```

作用：

- 定义寄存器地址、bit、op 编码。
- 封装 DMA load/store。
- 封装 start/wait/irq/status/completion。
- 给出 VDOT/GEMV/GEMM/CONV demo。

验证平台应模拟软件使用方式：

```text
write_reg()
read_reg()
spad_write()
dma_load()
start_compute()
wait_irq_or_done()
read_completion()
dma_store()
```

验证闭环目标：

```text
external memory model
  -> DMA load
  -> scratchpad
  -> compute
  -> completion queue
  -> DMA store
  -> scoreboard / golden model compare
```

## 7. 推荐下一步

建议按这个顺序推进：

1. 保留 SOM 为 legacy/experimental，文档主线改成 INT8 matrix/conv accelerator。
2. 补软件 `sw/`，写 bare-metal 风格 driver 和 demo。
3. 验证平台改成 software-driven test：用 AXI-Lite task 模拟 CPU 驱动。
4. 增强 descriptor/completion queue：full/empty、overflow、连续 descriptor。
5. 新增 2D DMA stride，为 GEMM/Conv tile 搬运做准备。
6. 新增 CONV1x1，复用 GEMM 数据流。
7. 实现 Banked Near-Memory INT8 Engine：bank PE + reduction tree。
8. 跑 VCS regression、coverage、SVA、lint、DC sanity，形成项目闭环报告。

## 8. RTL 近期提升执行顺序

后续 RTL 不建议继续散着加功能，而是按“先收口、再扩展”的顺序推进。目标是把当前能跑 demo 的原型，逐步变成接口行为清晰、错误处理完整、可由软件驱动的 near-memory INT8 accelerator IP。

### Step 1：补齐 CMDQ/CPLQ 队列语义

当前 command queue / completion queue 已有 base、size、head/tail 雏形，但更像单 outstanding ring consumer。下一步应补：

```text
CMDQ_HEAD / CMDQ_TAIL
CPLQ_HEAD / CPLQ_TAIL
queue full / empty
overflow / underflow error
doorbell count
completion ordering check
```

目标：

- 软件可以连续提交多条 descriptor。
- 硬件可以连续消费 descriptor。
- completion 不会覆盖软件尚未读取的 entry。
- 队列满、队列空、completion overflow 都有明确 `ERROR_CODE`。

这是把 demo 级 doorbell 机制升级成真实 command/completion queue 的关键一步。

### Step 2：增加 scratchpad region protection

当前 scratchpad 内部 input、weight、output、CMDQ、CPLQ 的分区主要依靠软件约定。后续应增加软件可配置的 region 保护寄存器：

```text
SPAD_REGION0_BASE / LIMIT / PERM
SPAD_REGION1_BASE / LIMIT / PERM
SPAD_REGION2_BASE / LIMIT / PERM
SPAD_REGION3_BASE / LIMIT / PERM
```

需要检查：

- `src0/src1/dst` 是否越界。
- descriptor 地址是否合法。
- DMA load/store 是否越界。
- completion 是否覆盖 input/weight/output 区域。
- 非法访问是否阻止进入 compute/DMA，并返回明确错误码。

这一步能把“SRAM 里数据含义全靠口头约定”升级成“硬件可检查的软件/硬件契约”。

### Step 3：增强 DMA，优先做 2D stride

当前 DMA 支持一维连续搬运。AI workload 中更常见的是矩阵/tile 搬运，因此优先增加 2D DMA stride：

```text
base_addr
row_length
row_count
src_stride
dst_stride
```

典型用途：

- 搬 GEMM tile。
- 搬 CONV input patch。
- 搬输出矩阵的一块。
- 支持 ping-pong buffer 时按 tile 分块搬运。

暂时不建议优先做多 outstanding，因为协议复杂度和验证成本较高。2D stride 更贴近当前 GEMM/Conv 演进路线。

### Step 4：新增 CONV1x1

SOM 不再作为主线后，最适合新增的工业常见算子是 `CONV1x1`。

数学形式：

```text
Out[h][w][co] = sum_ci In[h][w][ci] * W[co][ci]
```

它本质上可以复用 GEMV/GEMM datapath：

- 每个像素位置做一次通道维度点积。
- 权重矩阵为 `Cout x Cin`。
- 输出为 `H x W x Cout`。

价值：

- CNN/MobileNet/ResNet 中非常常见。
- 比 SOM 更容易解释工业应用。
- 复用当前 INT8 dot4/GEMV/GEMM 计算核心，RTL 增量可控。

### Step 5：实现 Banked Near-Memory INT8 Engine

在现有 4-bank scratchpad 基础上，增加 bank-local PE 和 reduction tree：

```text
scratchpad bank0 -> PE0 \
scratchpad bank1 -> PE1  \
scratchpad bank2 -> PE2   -> reduction tree -> result
scratchpad bank3 -> PE3  /
```

新增模块建议：

```text
ai_bank_pe.v
ai_reduction_tree.v
ai_banked_compute_core.v
```

新增 op：

```text
OP_BANKED_VDOT
OP_BANKED_GEMV
```

设计目标：

- 每个 bank 负责一段 K 维度。
- 每个 PE 产生 partial sum。
- reduction tree 汇总 partial sum。
- 体现 digital CIM-inspired / PIM-inspired 的 near-memory 数据局部性思想。

需要注意：

> 该结构不是 SRAM bitline 内计算，也不是 transistor-level CIM macro；它是在标准数字 RTL 中把 PE 放到 scratchpad bank 附近，以提升并行读带宽和降低单 compute core 反复访问 SRAM 的瓶颈。

### 阶段目标总结

推荐近期 RTL 收敛路线：

```text
Step 1：CMDQ/CPLQ full-empty-overflow
Step 2：scratchpad region protection
Step 3：2D DMA stride
Step 4：CONV1x1
Step 5：banked PE + reduction tree
```

这 5 步完成后，项目可以从“小型 AI accelerator 原型”升级为：

> 具备 AXI/DMA、scratchpad protection、descriptor queue、2D data mover、INT8 matrix/conv compute 和 banked near-memory datapath 的轻量级 AI accelerator IP。

最终项目口径：

> CIMForge is an AXI/DMA scratchpad-based near-memory INT8 AI accelerator IP prototype. It is inspired by CIM/PIM data-locality ideas but implemented as standard digital RTL, integrating AXI-Lite control, AXI master DMA, banked scratchpad, descriptor/completion queues, INT8 matrix/conv compute, software-driven verification, and FPGA/DC bring-up preparation.

## 9. FPGA P0 通过后的工业化与求职路线图

### 9.1 当前阶段与总体目标

当前准确阶段是：

> A2 RTL 功能设计和 XCZU15EG FPGA P0 原型验证已经完成，项目正在从“可工作的 FPGA
> prototype”进入“完整 DV、静态签核、量化性能和 ASIC 前端闭环”阶段。

当前能力边界：

| 方向 | 当前状态 | 下一里程碑 |
|---|---|---|
| 架构/RTL | AXI 控制与数据面、command processor、descriptor、completion、DMA、512 KiB banked scratchpad、INT8 matrix/conv 已集成 | 冻结稳定接口，只做由性能数据驱动的优化 |
| FPGA | bitstream/XSA/LTX、时序、DDR、GIC IRQ、UART/JTAG/ILA 已通过 | 固化可复现验收包和自动化回归 |
| 动态验证 | directed/random smoke + Python golden model | AXI AI 主线 UVM、coverage closure、长随机回归 |
| 静态验证 | 尚未形成正式签核包 | lint、CDC/RDC、formal 全部清零或 waiver 闭环 |
| 性能 | 有理论模型和性能计数器 | 板上 workload benchmark、瓶颈分析、优化前后对照 |
| ASIC | FPGA 综合实现已闭环 | DC/PT/Formality、门级仿真与 SRAM macro 适配报告 |

总体目标不是继续无边界增加算子，而是把项目升级为：

> 具备架构设计、参数化 RTL、UVM coverage closure、formal/static sign-off、FPGA 实板验证、
> 可量化性能数据及 ASIC 前端实现证据的完整 AI 加速器项目。

### 9.2 Phase 0：冻结可工作的 FPGA 基线

以实板通过提交 `8e657b6` 为基础创建 annotated tag：

```text
a2-fpga-bringup-v1
```

基线签核包至少固定：

- Git commit/tag 与寄存器/descriptor 版本。
- bitstream、XSA、LTX 的生成命令和校验信息。
- XSim/VCS 功能回归 PASS。
- Vivado timing、utilization、DRC 报告。
- JTAG、UART、裸机和 ILA PASS 日志。
- 已知限制、环境版本和复现步骤。

通过标准：从干净 checkout 可以按照文档重新生成产物，并在同一块 XCZU15EG 上重复得到
DDR DMA、CMDQ、VDOT、completion、GIC IRQ 和 ILA PASS。后续优化不得覆盖此 tag。

### 9.3 Phase 1：建设 AXI AI 主线 UVM 环境

这是当前最高优先级，也是设计岗和验证岗共同收益最大的阶段。验证结构建议为：

```text
test / virtual sequence
        |
        +-- AXI-Lite control agent
        +-- AXI4 DDR memory model/monitor
        +-- IRQ monitor
        +-- command-level reference model
        +-- scoreboard
        +-- functional coverage
        +-- protocol/design assertions
```

必须覆盖的功能域：

- CMDQ/CPLQ empty/full、wrap-around、连续 command、doorbell 和 head/tail ownership。
- scratchpad/external descriptor 两种来源、字段合法性和 source hold。
- completion 四字内容、原子发布和 ordering。
- DMA 4 KiB 边界、随机 back-pressure、不同 burst 长度、SLVERR/DECERR、abort/reset/recovery。
- scalar 与 banked VDOT/GEMV/GEMM、Conv1x1/Conv3x3/DWConv3x3。
- bias、shift、量化、饱和、ReLU/ReLU6 的正负边界与溢出。
- 双 context ownership、ping-pong overlap、依赖/完成机制。
- IRQ enable/mask、sticky status、W1C 和 completion-before-IRQ 顺序。
- AXI valid/ready 独立到达、响应提前 ready、长时间 stall。

交付物：

- `verification_plan.md`：功能点、test、coverpoint、assertion 的追踪矩阵。
- 可复用 UVM agents、virtual sequencer、reference model 和 scoreboard。
- directed、constrained-random、error-injection 和 reset/abort tests。
- VCS regression/coverage 脚本、seed 记录、失败最小化方法和验证报告。
- 发现并修复的 bug list，每个 bug 都有防回归用例。

建议签核门槛：

```text
line coverage        >= 95%
branch coverage      >= 90%
toggle coverage      >= 85%
functional coverage  = 100%（按批准后的 verification plan）
assertion failures   = 0
random regression    >= 1000 seeds，无未解释失败
```

覆盖率目标不是机械追数字。不可达代码应删除；设计合理但无法激励的点必须写 waiver，并说明原因和
风险。验证主线只针对 `ai_accel_top`，不能用 legacy AHB regression 替代。

### 9.4 Phase 2：lint、CDC/RDC 与 formal 静态签核

动态验证稳定后，使用 VNC/Synopsys 环境形成正式静态签核包。

Lint 重点：

- 位宽截断、signed/unsigned 扩展和 INT8/INT32 运算语义。
- latch、未驱动/多驱动、悬空信号、不可达 FSM state。
- blocking/nonblocking 使用、simulation/synthesis mismatch。
- reset 值、reset recovery、case 完整性和组合环。
- AXI valid/payload 在 ready 前的稳定性。

CDC/RDC 重点：

- PS AXI clock、accelerator clock 和 debug clock 的真实关系。
- asynchronous reset assertion / synchronous deassertion。
- PL-to-PS IRQ 的同步和 level-sensitive 行为。
- 多 bit control/status 跨域是否有握手、Gray code 或稳定窗口。
- ILA/debug 连接不得改变功能接口或制造新的跨域路径。

Formal 优先证明：

- scratchpad arbiter 同周期最多授权一个 client，优先级与 ownership 不冲突。
- completion 四字全部写完前 `CPLQ_TAIL` 不推进。
- hardware `CMDQ_HEAD` 不越过 software 已发布的 `CMDQ_TAIL`。
- 同一 command 不会重复 completion，completion 顺序与 command 顺序一致。
- descriptor source 在一次 command 生命周期内保持稳定。
- DMA error/abort 后可回到 idle，不遗留 buffer ownership。
- 非法 scratchpad 地址和保护失败不会启动 DMA/compute。
- AXI response/payload 在握手前保持稳定。
- reset 最终释放所有 context、queue transient state 和 sticky ownership。

通过标准：所有 error 清零；warning 必须修复或进入带 owner、理由和风险说明的 waiver 清单；formal
关键 property 全部 proven，不以 timeout/vacuous pass 冒充证明完成。

### 9.5 Phase 3：建立板上可量化性能报告

项目不能只报告“理论 AXI32@100 MHz 为 400 MB/s”或“banked 理论快 4 倍”，必须从板上性能
计数器读取真实性能。建议 workload 矩阵：

| Workload | 建议规模 | 对照组 |
|---|---|---|
| VDOT | 多组 vector length，覆盖短/长向量 | scalar vs banked |
| GEMV | 64×64、128×128 等 | 不同 tile/buffer 分区 |
| GEMM | 32×32×32、64×64×64 等 | ping-pong on/off |
| Conv3x3 | 多组 H/W/Cin/Cout | 不同 stride/padding 或软件 tiling |
| DWConv3x3 | MobileNet 风格 channel 数 | banked 读带宽与量化开销 |

每组至少报告：

- total、DMA read/write、compute active 和 stall cycles。
- command latency、command gap、elements/MAC 数。
- DDR payload 带宽与理论带宽利用率。
- compute utilization 和实际 GOPS。
- LUT、FF、BRAM、DSP 与 GOPS/LUT；有可信功耗时再报告 GOPS/W。
- ping-pong overlap：实测加速比与 `(L+C+S)/max(L+S,C)` 理论上限的差距。
- 结果与 Python/C golden model 的逐元素一致性。

性能报告必须回答：峰值是多少、实际达到多少、损失在哪里，以及瓶颈属于 DDR、AXI transaction、
scratchpad bank/port、compute pipeline 还是 command scheduling。

### 9.6 Phase 4：只做一次由数据驱动的架构升级

性能基线完成前不继续堆 attention/softmax 等新功能。根据测量结果选择一个主瓶颈：

如果 compute-bound：

- 参数化 4×4/8×8 PE array。
- 流水化 multiplier、accumulator 和 reduction tree。
- 明确 INT8 乘法、INT32 accumulation、round/saturate 的位宽契约。
- 评估 DSP48 映射/packing，避免当前计算全部落在 LUT 而无法扩展。
- 选择 output-stationary 或 weight-stationary 数据流并量化复用收益。

如果 memory/transport-bound：

- 增加可配置 burst 长度与多个 outstanding transaction。
- descriptor prefetch 和 command gap 隐藏。
- 改善 2D DMA、tile 合并、weight reuse 和 ping-pong 调度。
- 增加 bank conflict 检测并优化 scratchpad layout。

通过标准：必须有优化前后同 workload、同精度、同频率目标的对照数据，并说明资源/时序/功耗代价。
没有量化收益的功能扩张不算本阶段完成。

### 9.7 Phase 5：完成 ASIC 前端闭环

在 FPGA profile 之外建立 ASIC profile：

- 用 foundry/library memory macro 或可替换 wrapper 取代 FPGA XPM 依赖。
- 编写完整 SDC：clock、input/output delay、uncertainty、false/multicycle path。
- DC synthesis：频率 sweep、面积和功耗估算。
- PrimeTime：多 corner setup/hold、unconstrained path 检查。
- Formality：RTL-to-gate 等价性。
- 门级仿真和 SDF back-annotation。
- 条件允许时完成 ICC2 block-level floorplan、place/CTS/route 和 post-route STA。

报告中必须区分：FPGA BRAM 与 ASIC SRAM macro、FPGA timing closure 与 ASIC sign-off、功能时钟与
debug clock、理想时钟与 propagated clock。项目不必声称已经流片，但必须能解释从 RTL 到
sign-off netlist 的完整链路及剩余 foundry-specific 工作。

### 9.8 求职交付物

技术工作完成后整理一套可在面试中快速验证的材料：

- 一页系统架构图：PS/A53、AXI-Lite、AXI4 HP0、command processor、DMA、scratchpad、compute、IRQ。
- 一页 command 时序图：descriptor publish、doorbell、fetch、compute、completion、IRQ。
- 一页 ping-pong/ownership 图。
- UVM verification plan 与 coverage dashboard。
- lint/CDC/formal sign-off summary。
- FPGA timing/utilization、板上 performance roofline 和优化前后对照。
- 两个实板 debug case：完整系统地址 SLVERR，以及 ILA 单独 tap AXI member 导致接口成员被绑常量。
- 3～5 分钟演示：A53 提交 command、DDR DMA、VDOT/Conv、completion、GIC IRQ、ILA 波形。
- 简历中只写可复现、可量化且本人能够推导解释的结论。

### 9.9 推荐执行顺序与停止条件

严格按以下顺序推进：

```text
1. tag A2 FPGA bring-up baseline
2. AXI AI UVM environment
3. VCS coverage closure
4. lint / CDC / RDC / formal
5. board performance benchmark
6. one bottleneck-driven architecture optimization
7. DC / PT / Formality / gate-level simulation
8. project report / resume / interview demo
```

阶段纪律：

- Phase 1 完成前，不增加大规模新算子。
- Phase 3 数据出来前，不决定 PE array 或 outstanding 深度。
- 所有阶段都要有可重复命令、报告、已知限制和 Git baseline。
- 任何一次 RTL 接口或行为变化都必须同步更新软件、descriptor/register 文档和回归。
- 不以“工具跑完”代替签核；存在未解释 error、coverage hole、timing violation 或板上 mismatch 时，
  对应阶段仍是未完成。

完成第 9.3～9.7 节后，项目才适合从“强 FPGA/RTL 求职项目”升级为：

> 面向数字 IC 前端设计/验证岗位，覆盖架构、RTL、UVM、静态验证、FPGA 实板和 ASIC 前端流程的
> 完整 AI accelerator portfolio project。
