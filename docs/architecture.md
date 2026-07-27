# CIMForge AXI AI Accelerator 架构规格与 A2 验收基线

> A3 primitive 规范见 [CIMFORGE_A3_TRANSFORMER.md](CIMFORGE_A3_TRANSFORMER.md)，A4
> 验证前冻结规格见 [CIMFORGE_A4_TRANSFORMER.md](CIMFORGE_A4_TRANSFORMER.md)。A4 在
> matrix/SFU、descriptor v3、事件依赖和 DMA64 之上加入 LayerNorm、descriptor v4
> QKV/MHA/FFN 宏展开、KV gather 与最多 4 笔 AXI read outstanding。A2 已上板结论仅作为
> 兼容基线；A4 必须用独立 smoke、综合、VCS/UVM 和重新上板证据验收。

## 0. 项目状态声明

截至 2026-07-16，允许对外使用的准确结论是：

> **CIMForge A2 architecture and RTL functional design are complete.** The AXI AI accelerator is integrated, functionally regression-tested, and closes standalone XCZU15EG OOC timing at 100 MHz; board execution and industrial sign-off remain open.

| Gate | 状态 | 证据/边界 |
|---|---|---|
| A2 架构规格冻结 | COMPLETE | AXI 接口、descriptor v2、tile/buffer/bank、数据布局和性能模型已固化 |
| A2 RTL 集成 | COMPLETE | command processor、arbiter、DMA、scratchpad、tile pipeline、scalar/banked compute 已接入 `ai_accel_top` |
| A2 功能验证 | PASS | XSim 20 组随机计算、3-tile ping-pong、DMA abort/drain、AXI reset；Python 1000 组 golden model |
| FPGA 可综合性 | PASS | Vivado 2024.1 XCZU15EG OOC synthesis 0 error/critical warning |
| 100 MHz timing closure | PASS (OOC + board) | 512 KiB OOC routed setup/hold +0.836/+0.023 ns；整板 routed +1.625/+0.012 ns |
| 工业 sign-off | OPEN | VCS coverage、lint/CDC/RDC/formal、P&R/STA、DFT、软件驱动和系统级压力测试尚未全部闭环 |
| 完整流式 CNN frontend | OUT OF A2 SCOPE | A2 正式采用 software/DMA im2col；padding/stride/line-buffer 定义为 A3 |

因此可以宣告“A2 RTL 功能设计完成、XCZU15EG standalone IP 100 MHz 已收敛”，不能宣告“整板已经运行”或“CIMForge 已工业化完成”。

## 1. 范围与当前结论

A2 在 A1 的 command queue、descriptor、completion、DMA 和 INT8 计算基础上，加入可综合的双 context tile 流水，以及 Conv3x3、DWConv3x3、bias、量化移位和激活。`ai_accel_regs` 仍然只负责寄存器配置、doorbell 和 sticky 状态；命令生命周期由 `ai_command_processor` 管理，scratchpad 调度口只由 `ai_spad_arbiter` 驱动。

AI 主线总线为 **AXI-Lite control + AXI4 memory master**，顶层是 `rtl/ai_accel_top.v`。仓库中的 AHB 文件只属于早期 legacy vector track，不是 A1/A2 的依赖，也不纳入 AI smoke、A2 综合或本规格的验收范围。

| 版本 | Git 标识 | 验证状态 |
|---|---|---|
| A1 pre-A2 baseline | annotated tag `a1-baseline`，commit `a5d64a8` | 2026-07-15 在隔离工作树用 XSim 完整 AI smoke，`TEST PASS` |
| A2 integrated baseline | commit `75b849f` | Conv3x3/DWConv3x3、tile overlap、descriptor v2 和旧功能回归，`TEST PASS` |

本阶段的 Conv3x3 是 **im2col 后的 3x3 patch 计算**，不是带 line-buffer 的整图卷积前端。软件或上游 DMA 负责生成 patch。DWConv3x3 使用每像素、每通道一个 patch 的布局。这个边界必须在性能报告和简历中明确说明。

```text
 AXI-Lite                command / tile ownership
    |                              |
    v                              v
+---------+   config/pulse   +----------------------+    AXI master
| register|----------------->| command processor    |<--------------> DRAM
| file    |<-----------------| + 2-context pipeline |      ^
+---------+   status/perf    +----------+-----------+      | DMA
                                          |                 |
                  +-----------------------+-----------------+
                  | descriptor / completion / compute / DMA
                  v
             +-----------+       +-------------------------+
             | SPAD      |------>| scalar + banked INT8    |
             | arbiter   |       | compute engines         |
             +-----+-----+       +-------------------------+
                   |
        4-bank, parameterized scratchpad (XCZU15EG default 512 KiB)
```

## 2. 固化参数与可扩展目标

| 项目 | A2 RTL 基线 | 扩展方向 |
|---|---:|---|
| 数据类型 | signed INT8 输入/权重，signed INT32 输出 | INT16、混合精度 |
| 标量 MAC | 每周期处理一个 packed word，即 4 个 INT8 乘法 | 增加 lane 或复制计算核 |
| banked MAC | 4 bank 并行，每组 16 个 INT8 乘法 | bank 数参数化 |
| scratchpad | 4 bank × `SPAD_WORDS_PER_BANK` × 32 bit；XCZU15EG 默认 512 KiB | ASIC SRAM macro 替换 |
| scratchpad 读延迟 | 2 个时钟，request/wait/return 协议 | SRAM latency 参数化 |
| DMA 数据宽度 | AXI 32 bit | 64/128 bit AXI、outstanding burst |
| tile context | 2 个，固定 ping-pong | 4 context 或 descriptor-driven tile |
| FPGA 时钟目标 | 先以 100 MHz 约束收敛并报告实际 WNS | 按器件和 PPA 结果调优 |

### 2.1 数值化带宽与吞吐目标

以下数字统一以 100 MHz 为目标时钟，并把一次 signed INT8 乘加计为 1 MAC（或 2 OPS）。它们是数据通路的架构目标/上限；当前虽然已经完成 100 MHz timing closure，但仍不能把理论上限当作实板 sustained throughput。

| 路径 | 每次有效传输/计算 | 100 MHz 目标值 | 说明 |
|---|---:|---:|---|
| AXI32 DMA read | 4 byte/cycle | 400 MB/s | 单方向理论 payload 上限，不含 burst setup/back-pressure |
| AXI32 DMA write | 4 byte/cycle | 400 MB/s | 与 read 共用一个 DMA 调度器，tile load/store 不能按 800 MB/s 相加 |
| scalar dot4 datapath | 4 INT8 MAC/accumulate event | 0.4 GMAC/s raw width | 2-cycle SPAD 下约 7 cycle/K-word，长 K 预期约 0.057 GMAC/s |
| 4-bank datapath | 16 INT8 MAC/K-group | 1.6 GMAC/s raw width | A/B 各一次 2-cycle read，约 6 cycle/K-group，长 K 预期约 0.267 GMAC/s |

最终性能报告以 `PERF_*`、实际完成 MAC 数和实现后 `f_clk` 计算 sustained throughput；理论上限不能替代实测值。时钟验收分两级：A2 设计冻结要求 100 MHz 约束下可综合并公开 WNS；A2 timing closure 要求 implementation 后 setup/hold 均非负。当前 OOC IP 和整板实现均已达到后一级，实板吞吐测量仍待完成。

## 3. Scratchpad 分区与 ownership

默认物理 scratchpad 地址范围为 `0x0000_0000..0x0007_ffff`。地址低位 `[3:2]` 选择 bank，高位选择 bank 内 word，因此连续的四个 32-bit word 会条带化到四个 bank。逻辑分区不硬编码进 RAM，软件需遵循下表建议，并保证各区不重叠。Artix-7 compatibility profile 仍可将 `SPAD_WORDS_PER_BANK` 设为 4096，得到原64 KiB容量。

| 建议区域 | 用途 | ownership |
|---|---|---|
| `0x00000..0x03fff` | CMDQ descriptor / completion | command processor |
| `0x04000..0x1ffff` | 常驻权重和 bias | 软件装载，compute 只读 |
| `0x20000..0x47fff` | tile buffer 0：输入 + `output_offset` 输出 | context 0 |
| `0x48000..0x6ffff` | tile buffer 1：输入 + `output_offset` 输出 | context 1 |
| `0x70000..0x7ffff` | debug / software workspace | host；运行中避免冲突 |

每个 context 只允许下列状态单向推进：

```text
EMPTY -> LOADING -> READY -> COMPUTING -> PRODUCED -> STORING -> EMPTY
```

DMA 与 compute 可以拥有不同 context，但绝不能同时拥有同一 buffer。load 和 store 共享一个 DMA engine；store 按 tile 序优先，避免完成结果长期占用 buffer。load、compute、store 的 tile index 均独立递增，并保持顺序退休。最后一个 tile 的四字节/多字输出全部写回外部存储后，顶层 `done` 才置位。

典型双缓冲时序：

```text
time --->
DMA:      load T0 | load T1 | store T0 | load T2 | store T1 | store T2
compute:           compute T0          | compute T1          | compute T2
context0: LOAD ---- COMPUTE -- STORE -- LOAD ---- COMPUTE -- STORE
context1:           LOAD ---- COMPUTE -- STORE
```

## 4. Descriptor v2

descriptor 保持 16 word/64 byte，v2 复用原保留字段，因此全零保留字段的 v1 descriptor 继续可用。

| Word | Bit | 含义 |
|---:|---|---|
| 0 | `[7:0]` op，`[31:16]` task ID | 操作码与完成标识 |
| 1 | `[31:0]` | src0 scratchpad byte address |
| 2 | `[31:0]` | src1/weight scratchpad byte address |
| 3 | `[31:0]` | bias base；v2 新增 |
| 4 | `[31:0]` | dst scratchpad byte address |
| 5 | `[15:0]` M，`[31:16]` N | 输出维度 |
| 6 | `[15:0]` K words / vector length | packed word 数 |
| 7 | `[0]` bias enable | v2 新增，其余保留为 0 |
| 8 | — | 保留，写 0 |
| 9 | `[4:0]` right shift，`[6:5]` activation | `0:none, 1:ReLU, 2:ReLU6` |
| 10..15 | — | 保留，写 0 |

支持的计算操作码：`0x10 VDOT`、`0x11 GEMV`、`0x12 GEMM tile`、`0x13 Conv1x1`、`0x14 Conv3x3 im2col`、`0x15 DWConv3x3`、`0x20 banked VDOT`、`0x21 banked GEMV`。banked 路径当前不接 bias/post-op，Conv3x3/DWConv3x3 走标量核。

## 5. 计算数据布局

一个 packed word 的 byte lane 按 little-endian 顺序解释为四个 signed INT8。K 的单位是 packed word，尾部无效 lane 必须填 0。

- Conv3x3：src0 为 `M × K_words` 个 im2col patch，src1 为 `N × K_words` 个卷积核；dst 为 row-major `M × N` signed INT32。
- DWConv3x3：src0 为 `[pixel][channel][K_word]`，src1 为 `[channel][K_word]`；`N` 表示 channel 数，dst 为 `[pixel][channel]`。
- bias：每个输出 channel 一个 signed INT32；GEMV 按 row 取 bias，matrix/conv 按 column/channel 取 bias。
- 后处理顺序：64-bit accumulate → arithmetic right shift → none/ReLU/ReLU6 → signed INT32 saturation → scratchpad write。

参考模型位于 `verif/ref/ai_a2_reference.py`，不依赖 NumPy：

```bash
python verif/ref/ai_a2_reference.py --cases 1000 --seed 12345
```

## 6. Tile 寄存器接口

| Offset | 名称 | 说明 |
|---:|---|---|
| `0x114` | BIAS_BASE | bias scratchpad 地址 |
| `0x118` | POST_CTRL | bit0 bias enable |
| `0x120` | TILE_CTRL | bit0 写 1 启动 |
| `0x124` | TILE_COUNT | tile 数，16 bit |
| `0x128/0x12c` | TILE_EXT_IN/OUT | 外部输入/输出基地址 |
| `0x130/0x134` | TILE_EXT_IN/OUT_STRIDE | 相邻 tile 的 byte stride |
| `0x138/0x13c` | TILE_BUF0/1 | 两个 scratchpad buffer 基址 |
| `0x140/0x144` | TILE_IN/OUT_WORDS | 每 tile DMA word 数 |
| `0x148` | TILE_OUT_OFFSET | buffer 内输出相对地址 |
| `0x14c` | PERF_TOTAL | 流水 busy 总周期 |
| `0x150` | PERF_DMA | DMA active 周期 |
| `0x154` | PERF_COMPUTE | compute active 周期 |
| `0x158` | PERF_OVERLAP | DMA 与 compute 同时 active 周期 |
| `0x15c` | PERF_STALL | 两者都不 active 的流水周期 |
| `0x160` | TILE_COMPLETED | 已完成 store 的 tile 数 |
| `0x164` | SPAD_INFO | 只读，当前 scratchpad 字节容量；默认 `0x00080000` |

配置合法性要求：tile/输入/输出 word 数非零；两个 buffer 基址不同；外部基址、buffer、output offset 均 4-byte 对齐。启动时 command processor 与 DMA 必须空闲。

## 7. 性能模型与报告方法

设每 tile 的 load、compute、store 周期分别为 `L/C/S`，tile 数为 `T`。无重叠参考值为：

`Cycles_serial = T × (L + C + S)`

因为 load/store 共用一个 DMA，长序列稳态下的理论下界为：

`Cycles_lower_bound ≈ startup + T × max(L + S, C) + drain`

实测指标：

- `overlap_ratio = PERF_OVERLAP / PERF_TOTAL`
- `compute_util = PERF_COMPUTE / PERF_TOTAL`
- `dma_util = PERF_DMA / PERF_TOTAL`
- `effective_speedup = Cycles_serial / PERF_TOTAL`
- INT8 MAC 吞吐按实际完成乘加数除以 `PERF_TOTAL / f_clk` 计算。

报告必须同时给出 tile 形状、K words、DMA burst/stride、时钟、器件、WNS、LUT/FF/BRAM/DSP；不能只给功能 smoke 的周期数冒充最终 PPA。

### 7.1 A2 首次综合基线（2026-07-15）

Vivado 2024.1、`xc7a100tfgg484-2`、standalone `ai_accel_top`、100 MHz 约束的综合后结果：

| 指标 | 结果 |
|---|---:|
| Slice LUT | 7,351 / 63,400（11.59%） |
| Slice Register | 4,735 / 126,800（3.73%） |
| BRAM36 tile | 16 / 135（11.85%） |
| DSP | 8 / 240（3.33%） |
| Setup WNS / TNS | -10.342 ns / -5626.246 ns |
| Hold WHS / THS | +0.125 ns / 0 ns |

综合本身为 0 error、0 critical warning，但 **100 MHz setup 尚未收敛**。最差路径从 scalar core 的 row address 经过地址乘法、scratchpad protection 和写端口控制，共 21 级逻辑；这是下一阶段应处理的明确 timing debt，不能把本结果表述为 timing closure。standalone IP 的 DRC 还包含未绑定顶层 I/O standard/LOC 的 UCIO/NSTD warning，需到 board wrapper/implementation 阶段消除。生成报告位于被忽略的 `fpga/xilinx_a7_100t/build/ip_synth/reports/`。

### 7.2 CNN workload 验收口径

A2 正式选择 **software/DMA im2col** 作为 Conv3x3 系统接口：输入 descriptor 指向已经展开的 3x3 patch，RTL 负责 INT8 MAC、bias、shift、activation、饱和和输出退休。满足以下全部条件即判定 A2 Conv/DWConv 通过：

- Conv3x3 与 DWConv3x3 的 M/N/K、signed INT8 lane 和尾部 padding 布局正确；
- bias enable/disable、shift 0..3、none/ReLU/ReLU6 至少被定向和随机用例覆盖；
- RTL 输出与独立 SystemVerilog scoreboard 逐元素一致；Python model 对随机 patch/kernel/post-op 自检一致；
- descriptor v2 和直接寄存器两条启动路径保持兼容；
- tile load/compute/store 能对 im2col tile 做双缓冲重叠。

因此 A2 不宣称接收原始 NCHW/NHWC feature map 后自行完成整图滑窗。完整 CNN frontend 定义为后续 A3：至少支持 input H/W/C、padding 0/1、stride 1/2、3-row line buffer、sliding-window 复用、边界补零和输出尺寸检查，并需与同一 golden model 做整图随机对拍。在 A3 完成前，简历必须写“hardware Conv3x3 on im2col tiles”，不能写“full-image streaming convolution engine”。

## 8. 验收与后续工业化边界

A2 的 RTL 验收包括：旧 A1 队列/descriptor/completion 回归不退化；Conv3x3 bias+ReLU6；DWConv3x3；双 tile load/compute/store overlap；DMA 4 KiB、2D 和保护错误；随机 GEMV/GEMM/Conv3x3/DWConv3x3/post-op；Python golden model 自检。VCS 命令仍以 `verif/sim/Makefile` 为准，Windows 可用 XSim 做功能交叉检查。

A2 是可综合、可验证的求职项目基线，但不是量产 IP。后续工业化工作仍包括 descriptor-driven 多 tile、整图 sliding-window/line-buffer、AXI 多 outstanding、ECC、CDC/RDC、低功耗、formal、功能/代码覆盖率 closure、DFT、综合/P&R/STA/hold closure、PPA 基线和软件 driver。上述工作应在 A2 功能冻结后分阶段进行。

## 9. 上板 P0 固化规则

### 9.1 地址与关键路径

scalar、banked 和 tile 三条路径均使用启动时装载、完成一项后递增的地址寄存器。
scratchpad 请求组合路径中不再计算 `row*N*K`、`row*K`、`row*length` 或
`tile_index*stride`。乘法只属于 INT8 数据计算，不承担循环地址生成。

### 9.2 abort 与 AXI transaction

`ABORT` 错误码为 3（command/compute），DMA 自身的 abort 错误码为 5。软件发出
abort 后不得假设外部总线立即空闲：

- AR 尚未接受时可撤销；已接受时停止 scratchpad side effect，并 drain 到 `RLAST`；
- AW 尚未接受时可撤销；已接受时必须发送协议规定的全部 W beat、`WLAST` 并接收 B；
- AXI response、scratchpad protection/parity 错误也不能遗留半个 accepted burst；
- command processor 在 abort 后停止继续消费后续 descriptor；如 completion ring 已启用，
  当前命令仍按顺序提交 error completion。

### 9.3 queue 发布规则

软件只发布 `CMDQ_TAIL`、消费 `CPLQ_HEAD`；硬件只推进 `CMDQ_HEAD`、发布
`CPLQ_TAIL`。`CPLQ_SIZE=0` 表示未启用 completion ring，direct/one-shot 命令只更新
sticky status，不得推进 tail。启用 ring 时，tail 只在 completion 的四个 word 全部写入
scratchpad 后改变。

### 9.4 XCZU15EG 系统连接

板级控制 aperture 为 `0xA0000000..0xA00fffff`（1 MiB）：寄存器页从 offset 0 开始，
默认 512 KiB host scratchpad window 位于 offset `0x10000..0x8ffff`。PS `M_AXI_HPM0_FPD` 访问
S_AXI control；accelerator M_AXI 经 `S_AXI_HP0_FPD` 访问 PS DDR；`pl_clk0=100 MHz`；
IRQ 接 `pl_ps_irq0`。所有 PL AXI 逻辑使用同一时钟，并由 PS reset 经
`proc_sys_reset` 同步释放，因此本版本没有功能性 CDC crossing。

当前外部地址仍为 32 bit，DDR descriptor/input/output 必须分配在 4 GiB 以下。
该限制由 bare-metal bring-up 在运行时检查，后续若扩展到 64-bit address，必须同步升级
descriptor ABI、DMA、external descriptor fetch、寄存器高地址和软件驱动。

### 9.5 XCZU15EG OOC 实现基线（2026-07-16）

Vivado 2024.1、`xczu15eg-ffvb1156-2-i`、10.000 ns 约束的最新 RTL 结果：

| 指标 | synthesis | post-route |
|---|---:|---:|
| LUT | 7,854 | 7,780 |
| FF | 4,952 | 4,952 |
| RAMB36E2 | 128 | 128 |
| DSP48E2 | 0 | 0 |
| setup slack | +2.684 ns | +0.836 ns |
| hold slack | +0.084 ns | +0.023 ns |

综合为 0 error、0 critical warning；实现脚本完成 opt/place/phys_opt/route、min/max
timing、DRC、methodology 和 power report，并以 setup/hold 任一负 slack 作为失败条件。
Routed DRC violation 为 0；methodology 的 `TIMING-18` 是 OOC 顶层 AXI/I/O 没有外部
input/output delay 的预期 warning，板级路径由 PS/SmartConnect 生成的时钟约束复核。
这里的 0 DSP 是当前 RTL 映射结果，不表示没有乘加：串行 packed INT8 和 banked PE
被综合为 LUT/CARRY 逻辑。后续若追求吞吐/面积比，应专门做 DSP packing 或 SIMD
乘法阵列，而不是把 0 DSP 当作性能优势。

### 9.6 XCZU15EG 整板实现基线（2026-07-16）

使用厂商 PS DDR/MIO 配置、HPM0/HP0 SmartConnect、proc_sys_reset、IRQ 和 native ILA
的完整 block design 已生成 bitstream、XSA 与 LTX：

| 指标 | routed board result |
|---|---:|
| LUT / FF | 17,624 / 19,274 |
| RAMB36E2 / DSP48E2 | 152 / 0 |
| setup / hold slack | +1.625 ns / +0.012 ns |
| timing failing endpoints | setup 0 / hold 0 |
| DRC | 0 error；4 warning |

4 个 DRC warning 均位于 Vivado 自动生成的 `dbg_hub`：3 个 `PDCN-1569` LUT equation
term check 和 1 个 `RTSTAT-10` no-routable-load，不属于 accelerator、PS DDR 或 AXI
连接。bitgen 为 0 error、0 critical warning。该结果证明工程可生成可下载镜像，但仍需
在实体板上完成 FSBL/裸机运行、DDR DMA 数据一致性、IRQ 和 ILA 实测，才能关闭
hardware bring-up gate。
