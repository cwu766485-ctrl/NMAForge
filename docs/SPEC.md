# CIMForge AI 加速器 RTL 规格说明

**文档版本：** 1.2  
**RTL 版本寄存器：** `0x1000_0008`  
**基线日期：** 2026-07-29  
**设计顶层：** `rtl/top/ai_accel_top.v`

## 1. 项目范围

CIMForge 是一个可综合的、全数字、基于 scratchpad 的近存 AI 加速器 IP，包含：

- 32-bit AXI4-Lite 从接口；
- 128-bit AXI4 主接口；
- 命令队列与完成队列；
- 位于 scratchpad 或外部内存的 descriptor；
- 统一的 128-bit tagged DMA，支持 1D、2D、gather 和 tile；
- 512 KiB、4-bank scratchpad；
- 标量 INT8、banked、矩阵、CNN、SFU 与 KV-cache 计算核心；
- scratchpad 区域保护、watchdog、性能计数器和中断。

该设计的计算核心围绕 banked scratchpad 工作，以减少数据在 DDR 与计算单元间的反复搬运，因此可称为：

> 基于 scratchpad 的全数字近存（near-memory）INT8 AI 加速器。

它不修改 SRAM bitcell、bitline 或 sense amplifier；MAC 也不在 SRAM 宏内部完成。因此它不是模拟 CIM，也不是定制 SRAM-CIM macro。

早期 AHB SRAM/vector 教学轨道已经从仓库删除；本说明只覆盖当前 AXI-Lite/AXI4 AI 加速器主线。

## 2. 当前进度与证据边界

| 项目 | 当前状态 |
|---|---|
| 主线 RTL | 23 个可综合 Verilog 模块，6,491 行；DMA 已收敛为单一后端 |
| A8 VCS 回归 | `make ai_transformer`、`make ai_smoke` 均 `TEST PASS` |
| DMA、128-bit SPAD line、ABI v7.2 主线 | A7 基础改版通过 `make ai_upgrade_vcs`；A8 完整 smoke 已复跑通过 |
| ABI v7.2 PACK_I8 与 Transformer 端到端 workload | 30-command 链、completion、最终 tensor 和 matrix MAC cycle 均已由 VCS 检查通过 |
| 整数参考模型 | 1,000 case、seed `20260722` 通过 |
| XCZU15EG | A8 standalone OOC routed 于 100 MHz 闭合：setup WNS=+0.187 ns、hold WNS=+0.032 ns |
| TSMC28 HPC+ | A7 在 TT/0.9 V/25 C 下完成 250 MHz pre-layout 闭合；A8 DC 被 license feature 阻断，尚未复跑 |
| 物理签核 | 尚未完成 |

250 MHz 是 Design Compiler 的 **pre-layout** 结果，不是 post-route Fmax、sign-off STA 或硅后实测频率。floorplan、CTS、布线寄生、MMMC、OCV/AOCV/POCV、IR drop 与 EM 尚未完成。

## 3. 顶层架构

```text
                          +-----------------------+
CPU / SoC AXI-Lite ------>| axi_lite_reg_if       |
                          +-----------+-----------+
                                      |
                   +------------------+------------------+
                   |                                     |
          +--------v---------+                  +--------v---------+
          | ai_accel_regs    |                  | Scratchpad host  |
          | 配置/状态/IRQ    |                  | / debug window   |
          +--------+---------+                  +------------------+
                   |
          +--------v------------------+
          | ai_command_processor      |
          | CMDQ/CPLQ/依赖/发射 FSM    |
          +--+---------------+-----+--+
             |               |     |
     +-------v------+ +------v--+  +v--------------------+
     | descriptor   | | compute |  | completion writer  |
     | fetch        | | engines |  | 四个 word 原子提交  |
     +-------+------+ +----+----+  +----------+----------+
             |             |                  |
             +-------------+------------------+
                           |
                    +------v---------+
                    | ai_spad_arbiter|
                    +------+---------+
                           |
                  +--------v----------+
                  | 4-bank Scratchpad |
                  | 默认 512 KiB      |
                  +--------+----------+
                           |
                    +------v------+
外部 DDR <-------->| 统一 AXI DMA |
                    | 128b/burst  |
                    +-------------+
```

### 3.1 模块所有权

- `ai_accel_regs`：保存软件可见配置，生成控制脉冲，记录 sticky status 和 IRQ。
- `ai_command_processor`：拥有命令生命周期、`CMDQ_HEAD`、`CPLQ_TAIL`、依赖事件、发射顺序与 completion 顺序。
- 软件：发布 `CMDQ_TAIL`，消费 `CPLQ_HEAD`。
- `ai_spad_arbiter`：唯一的 scheduler-side scratchpad 准入点。
- `ai_completion_writer`：四个 completion word 全部写入后，硬件才推进 `CPLQ_TAIL`。
- descriptor fetch：一条 in-flight command 的 descriptor 来源在 fetch 期间保持固定。

## 4. 时钟与复位

| 信号 | 方向 | 说明 |
|---|---|---|
| `aclk` | 输入 | 控制、DMA、scratchpad 和计算核心的公共时钟 |
| `aresetn` | 输入 | 低有效复位 |

控制状态机使用低有效异步复位写法。当前顶层是单一逻辑时钟域；若 SoC 需要时钟转换，应由顶层之外的 wrapper/interconnect 实现。

## 5. 外部接口

### 5.1 AXI4-Lite 从接口

控制接口的地址宽度与数据宽度均为 32 bit。

| 通道 | 加速器输入 | 加速器输出 |
|---|---|---|
| AW | `s_axi_awaddr[31:0]`、`s_axi_awvalid` | `s_axi_awready` |
| W | `s_axi_wdata[31:0]`、`s_axi_wstrb[3:0]`、`s_axi_wvalid` | `s_axi_wready` |
| B | `s_axi_bready` | `s_axi_bresp[1:0]`、`s_axi_bvalid` |
| AR | `s_axi_araddr[31:0]`、`s_axi_arvalid` | `s_axi_arready` |
| R | `s_axi_rready` | `s_axi_rdata[31:0]`、`s_axi_rresp[1:0]`、`s_axi_rvalid` |

协议行为：

- AW 与 W 可在不同周期到达，接口内部会分别保存后二者配对；
- 每个读方向和写方向最多处理一笔控制事务；
- 当 `READY=0` 时，对应的 `VALID` 以及 payload 必须保持稳定；
- 地址、对齐、权限、奇偶校验或寄存器访问错误返回 AXI `SLVERR`；
- 寄存器访问必须 4-byte 对齐；写寄存器要求 `WSTRB=4'b1111`；
- processor 或 DMA busy 时，大多数配置寄存器写入被锁住；status/IRQ/DMA status 清除和 abort 例外。

### 5.2 AXI4 主接口

外部数据接口特性：

- 64-bit byte address；
- 128-bit 读写数据；
- 4-bit AXI ID；
- 8-bit burst length；
- INCR burst。

| 通道 | 加速器输出 | 加速器输入 |
|---|---|---|
| AR | `m_axi_arvalid`、`arid[3:0]`、`araddr[63:0]`、`arlen[7:0]`、`arsize[2:0]`、`arburst[1:0]`、`arcache[3:0]`、`arprot[2:0]`、`arqos[3:0]`、`arlock` | `m_axi_arready` |
| R | `m_axi_rready` | `m_axi_rid[3:0]`、`rdata[127:0]`、`rresp[1:0]`、`rvalid`、`rlast` |
| AW | `m_axi_awvalid`、`awid[3:0]`、`awaddr[63:0]`、`awlen[7:0]`、`awsize[2:0]`、`awburst[1:0]`、`awcache[3:0]`、`awprot[2:0]`、`awqos[3:0]`、`awlock` | `m_axi_awready` |
| W | `m_axi_wvalid`、`wdata[127:0]`、`wstrb[15:0]`、`wlast` | `m_axi_wready` |
| B | `m_axi_bready` | `m_axi_bid[3:0]`、`bresp[1:0]`、`bvalid` |

ID 分配：

- external descriptor fetch：读 ID `0`；
- payload DMA 读：ID `1..4`；
- payload DMA 写：ID `8..11`。

当前顶层把 `AxCACHE` 固定为 `4'b0011`，`AxPROT`、`AxQOS`、`AxLOCK`
固定为 0 并显式暴露。`AxREGION`、`AxUSER` 尚未实现。

### 5.3 中断

`irq` 为高有效电平中断：

```text
irq = IRQ_ENABLE[0] && IRQ_STATUS[0]
```

软件向 `IRQ_STATUS[0]` 写 1 清除 pending 状态。

## 6. 地址空间

顶层对 AXI-Lite 地址的低 20 bit 解码，因此 IP 可以映射到一个 1 MiB 的 SoC aperture 中。历史 XCZU15EG 工程使用 `0xA000_0000` 作为 aperture base。

| 本地 offset | 大小 | 功能 |
|---:|---:|---|
| `0x0000_0000` | `0x200` | 已实现寄存器页 |
| `0x0001_0000` | `0x0008_0000` | 默认 512 KiB scratchpad host window |
| 其他 offset | — | decode error / `SLVERR` |

默认 scratchpad 范围：

```text
SPAD_BASE  = 0x0001_0000
SPAD_BYTES = 0x0008_0000
SPAD_LIMIT = 0x0009_0000   // exclusive
```

descriptor 和计算核心中的源/目的地址是 **scratchpad-relative byte address**，不是 AXI-Lite host window 的绝对地址。

## 7. 寄存器规格

访问标记：

- `RW`：软件可读写；
- `RO`：只读；
- `W1P`：写 1 产生一个周期脉冲；
- `W1C`：写 1 清除 sticky 状态；
- `HW`：正常工作时由硬件推进或更新。

### 7.1 核心控制与状态

| Offset | 名称 | 访问 | 定义 |
|---:|---|---|---|
| `0x000` | `CTRL` | RW/W1P | bit 0：direct start；bit 1：IRQ enable |
| `0x004` | `STATUS` | RO/W1C | bit 0：busy；bit 1：done；bit 2：error；写 bits 1/2 清除 |
| `0x008` | `OP` | RW | operation code，`[7:0]` |
| `0x00C` | `SRC0` | RW | scratchpad source 0 byte address |
| `0x010` | `SRC1` | RW | scratchpad source 1 byte address |
| `0x014` | `DST` | RW | scratchpad destination byte address |
| `0x018` | `LENGTH` | RW | vector length 或 packed-word length，`[15:0]` |
| `0x01C` | `M` | RW | M dimension，`[15:0]` |
| `0x020` | `N` | RW | N dimension，`[15:0]` |
| `0x024` | `K` | RW | K packed-word count，`[15:0]` |
| `0x028` | `QUANT` | RW | shift `[4:0]`；activation `[6:5]` |
| `0x02C` | `RESULT` | RO | 最后一条命令的 result |
| `0x030` | `ERROR` | RO | 最后一条命令的 error code，`[3:0]` |
| `0x034` | `CYCLES` | RO | 最后一条命令的 cycle count |
| `0x038` | `ELEMENTS` | RO | 最后一条命令的 element count |
| `0x03C` | `IRQ_STATUS` | RO/W1C | sticky pending，bit 0 |
| `0x040` | `IRQ_ENABLE` | RW | interrupt enable，bit 0 |
| `0x044` | `VERSION` | RO | `0x1000_0008` |
| `0x048` | `CAP` | RO | `0x001F_FF17` |

已命名 capability bit：

| Bit | 能力 |
|---:|---|
| 12 | 4x4 tensor matrix core |
| 13 | tensor SFU |
| 14 | descriptor v3 |
| 15 | legacy DMA burst capability；当前统一后端最大 16 beat |
| 16 | LayerNorm |
| 17 | descriptor v4 macro |
| 18 | gather DMA |
| 19 | 多笔 read outstanding |
| 20 | 扩展 performance monitor |

### 7.2 命令与完成队列

| Offset | 名称 | 访问 | 定义 |
|---:|---|---|---|
| `0x080` | `CMDQ_BASE_LO` | RW | command descriptor ring base |
| `0x084` | `CMDQ_BASE_HI` | RW | external command ring 64-bit base 的高 32 bit |
| `0x088` | `CMDQ_SIZE` | RW | command ring entry count；零表示 one-shot descriptor mode |
| `0x08C` | `CMDQ_HEAD` | RO/HW | 硬件 consumer index；写入仅用于 reset/debug seed |
| `0x090` | `CPLQ_BASE_LO` | RW | scratchpad completion ring base |
| `0x094` | `CPLQ_BASE_HI` | RW/保留 | 为 ABI 兼容而保存；当前 writer 未使用 |
| `0x098` | `CPLQ_SIZE` | RW | completion ring entry count；零表示不发布 completion |
| `0x09C` | `CPLQ_TAIL` | RO/HW | 硬件 producer index；写入仅用于 reset/debug seed |
| `0x0A0` | `DOORBELL` | W1P | 提交 descriptor/ring 工作 |
| `0x0A4` | `ABORT` | W1P | bit 0 请求 abort |
| `0x0A8` | `WATCHDOG` | RW | 0 禁用；非 0 是 engine cycle limit |
| `0x0AC` | `CMDQ_CTRL` | RW | bit 0：descriptor 位于 external AXI memory |
| `0x0C8` | `CMDQ_TAIL` | RW/SW | 软件 producer index |
| `0x0CC` | `CPLQ_HEAD` | RW/SW | 软件 consumer index |
| `0x0D0` | `QUEUE_STATUS` | RO | bit 0：CMDQ empty；bit 1：CPLQ empty；bit 2：CPLQ full；bit 3：processor busy |

队列 entry 地址：

```text
descriptor_address = CMDQ_BASE + CMDQ_HEAD * 64
completion_address = CPLQ_BASE + CPLQ_TAIL * 16
```

ring index 在 `SIZE-1` 后回绕到 0。软件必须先完成 descriptor 内容写入，再推进 `CMDQ_TAIL`；软件在推进 `CPLQ_HEAD` 前不能复用 completion slot。

### 7.3 DMA

| Offset | 名称 | 访问 | 定义 |
|---:|---|---|---|
| `0x0B0` | `DMA_CTRL` | RW/W1P | bit 0：start；bit 1：store（`1` 为 SPAD 到 external） |
| `0x0B4` | `DMA_STATUS` | RO/W1C | bit 0：busy；bit 1：done；bit 2：error |
| `0x0B8` | `DMA_EXT_ADDR_LO` | RW | external byte address 低 32 bit |
| `0x0BC` | `DMA_SPAD_ADDR` | RW | scratchpad byte address |
| `0x0C0` | `DMA_LENGTH` | RW | 1D length，单位为 32-bit word |
| `0x0C4` | `DMA_ERROR` | RO | DMA error code，`[3:0]` |
| `0x104` | `DMA_ROW_WORDS` | RW | 2D row 中的 word 数 |
| `0x108` | `DMA_ROW_COUNT` | RW | row 数；0 选择 1D mode |
| `0x10C` | `DMA_EXT_STRIDE` | RW | external row-start byte stride |
| `0x110` | `DMA_SPAD_STRIDE` | RW | scratchpad row-start byte stride |
| `0x16C` | `DMA_CFG` | RW | bit 0：gather；bit 1：只读能力位，恒为 1，表示统一 128-bit DMA；`[10:8]`：read outstanding |
| `0x170` | `DMA_GATHER_INDEX` | RW | 保存 external byte address 的 scratchpad 表基址 |
| `0x19C` | `DMA_EXT_ADDR_HI` | RW | external byte address 高 32 bit |

1D、2D、gather 和 tile transfer 全部使用 `ai_axi128_dma`。为兼容旧软件，
`DMA_CFG[1]` 地址位仍然存在，但写入被忽略，读取恒为 1。

external row base、scratchpad 地址与 gather index table 必须 4-byte 对齐。
非 16-byte 对齐的 external row 先使用 32-bit alignment beat，到达 16-byte
边界后自动切换为 128-bit burst。

### 7.4 Bias、tile pipeline 与性能计数器

| Offset | 名称 | 访问 | 定义 |
|---:|---|---|---|
| `0x114` | `BIAS_BASE` | RW | scratchpad bias byte address |
| `0x118` | `POST_CTRL` | RW | bit 0：bias enable |
| `0x120` | `TILE_CTRL` | W1P | bit 0：启动 tile pipeline |
| `0x124` | `TILE_COUNT` | RW | tile 数量 |
| `0x128` | `TILE_EXT_IN_LO` | RW | external input base 低 32 bit |
| `0x12C` | `TILE_EXT_OUT_LO` | RW | external output base 低 32 bit |
| `0x130` | `TILE_EXT_IN_STRIDE` | RW | input tile byte stride |
| `0x134` | `TILE_EXT_OUT_STRIDE` | RW | output tile byte stride |
| `0x138` | `TILE_BUF0` | RW | scratchpad ping buffer |
| `0x13C` | `TILE_BUF1` | RW | scratchpad pong buffer |
| `0x140` | `TILE_IN_WORDS` | RW | 每个 tile load 的 word 数 |
| `0x144` | `TILE_OUT_WORDS` | RW | 每个 tile store 的 word 数 |
| `0x148` | `TILE_OUT_OFFSET` | RW | tile buffer 内 output offset |
| `0x14C` | `PERF_TOTAL` | RO | tile 总 cycle |
| `0x150` | `PERF_DMA` | RO | tile DMA-active cycle |
| `0x154` | `PERF_COMPUTE` | RO | tile compute-active cycle |
| `0x158` | `PERF_OVERLAP` | RO | DMA/compute overlap cycle |
| `0x15C` | `PERF_STALL` | RO | tile stall cycle |
| `0x160` | `TILE_COMPLETED` | RO | 已完成 tile 数 |
| `0x164` | `SPAD_INFO` | RO | 实际 scratchpad byte 数 |
| `0x168` | `EVENT_STATUS` | RO | dependency event，`[15:0]` |
| `0x174` | `PERF_CTRL` | W1P | bit 0：清零扩展计数器 |
| `0x178` | `PERF_MATRIX_CYCLES` | RO | matrix total cycle |
| `0x17C` | `PERF_MATRIX_MAC_CYCLES` | RO | matrix MAC-active cycle |
| `0x180` | `PERF_MATRIX_BANKED_STALL` | RO | matrix banked-read stall cycle |
| `0x184` | `PERF_DMA_READ_BYTES` | RO | DMA read byte 数 |
| `0x188` | `PERF_DMA_WRITE_BYTES` | RO | DMA write byte 数 |
| `0x18C` | `PERF_DMA_AR_COUNT` | RO | 已接受 AR transaction 数 |
| `0x190` | `PERF_DMA_AW_COUNT` | RO | 已接受 AW transaction 数 |
| `0x194` | `PERF_DMA_RD_STATE` | RO | 当前 outstanding `[2:0]`；high-water `[5:3]` |
| `0x198` | `PERF_DMA_R_STALL` | RO | DMA R-channel stall cycle |
| `0x1AC` | `TILE_EXT_IN_HI` | RW | external input base 高 32 bit |
| `0x1B0` | `TILE_EXT_OUT_HI` | RW | external output base 高 32 bit |

### 7.5 ABI、能力与错误来源

| Offset | 名称 | 访问 | 定义 |
|---:|---|---|---|
| `0x1A0` | `ABI_INFO` | RO | `[7:0]` major=7；`[15:8]` minor=2；`[23:16]` descriptor bytes=64；`[31:24]` completion bytes=16 |
| `0x1A4` | `ERROR_INFO` | RO | error code `[3:0]`；error source `[7:4]`，1=command/compute，2=DMA |
| `0x1A8` | `CAP2` | RO | bit 0 unified DMA；bit 1 128-bit SPAD line；bit 2 matrix line-store；bit 3 64-bit external address；bit 4 descriptor v7；bit 5 packed INT8 layout bridge |

### 7.6 Scratchpad 区域保护

| Offset | 寄存器 |
|---:|---|
| `0x0D4`、`0x0D8`、`0x0DC` | Region 0 base、exclusive limit、permission |
| `0x0E0`、`0x0E4`、`0x0E8` | Region 1 base、exclusive limit、permission |
| `0x0EC`、`0x0F0`、`0x0F4` | Region 2 base、exclusive limit、permission |
| `0x0F8`、`0x0FC`、`0x100` | Region 3 base、exclusive limit、permission |

Permission bit：

| Bit | 含义 |
|---:|---|
| 0 | read |
| 1 | write |
| 2 | execute/compute |
| 3 | region enable |

规则：

- region limit 为 exclusive；
- 一笔访问必须完整落在某一个 enabled region 内；
- 不允许借助相邻 region 拼接权限；
- 所有 region disabled 时，为保持兼容性，访问全部允许；
- completion 以完整 16-byte write 检查；
- banked read 以完整、16-byte 对齐的 read 检查。

## 8. Descriptor ABI

descriptor 长度 64 byte，必须 64-byte 对齐，包含 16 个 32-bit little-endian word。

| Word | Bits | 字段 |
|---:|---|---|
| 0 | `[7:0]` | operation |
| 0 | `[31:16]` | task ID |
| 1 | `[31:0]` | source 0 base |
| 2 | `[31:0]` | source 1 base |
| 3 | `[31:0]` | bias base |
| 4 | `[31:0]` | destination base |
| 5 | `[15:0]` | M |
| 5 | `[31:16]` | N |
| 6 | `[15:0]` | K words 或 vector length |
| 7 | `[7:0]` | flags |
| 8 | `[31:0]` | auxiliary value / epsilon / token-head selector |
| 9 | `[4:0]` | requantization shift |
| 9 | `[6:5]` | activation |
| 10 | `[31:0]` | source 0 instance stride |
| 11 | `[31:0]` | source 1 instance stride |
| 12 | `[31:0]` | destination instance stride |
| 13 | `[15:0]` | batch count |
| 13 | `[31:16]` | head count |
| 14 | `[15:0]` | dependency wait mask |
| 14 | `[31:16]` | dependency signal mask |
| 15 | `[7:0]` | descriptor version |
| 15 | `[31:16]` | dependency clear mask |

Flags：

| Bit | 含义 |
|---:|---|
| 0 | bias enable |
| 1 | transpose A |
| 2 | transpose B |
| 3 | v4 macro child descriptor 位于 external memory |
| 4 | `OP_REQUANT_I8` 将四个饱和 INT8 打包为一个 32-bit word |

版本要求：

| 操作 | 所需 descriptor version |
|---|---:|
| 所有当前操作 | 推荐统一使用 7 |
| 基础 scalar/banked INT8 | base/v2-compatible layout；版本号当前不强制检查 |
| Matrix 与 SFU（`0x30..0x39`） | 3 |
| Macro parent（`0x40..0x42`） | 4 |
| Line-buffer convolution 与 KV-cache（`0x16`、`0x17`、`0x43`、`0x44`） | 5 |

所有 source、destination、bias address 必须 4-byte 对齐。macro child list 必须
64-byte 对齐。v7 macro 使用 `{word2, word1}` 表示 64-bit child descriptor base；
旧 v4 macro 继续把 `word1` 解释为 32-bit 地址。

PACK_I8 模式的 `length` 仍表示输入元素数量，destination 占用
`ceil(length/4)` 个 word；最后不足四个元素时，高位 byte 补零。该模式用于把
Matrix/SFU 的逐元素 INT32 输出转换为下一条 INT8 Matrix descriptor 可直接消费的
row-packed layout。

### 8.1 Dependency event

command processor 维护 16 个 event bit：

- descriptor 仅在 `wait_mask` 的所有 bit 已置位时才能执行；
- 成功执行后，`signal_mask` 的 bit 被置位；
- command 发射时，`clear_mask` 的 bit 被清除；
- dependency wait 到 65,535 cycle 饱和时，报告 dependency error。

### 8.2 v4 Macro descriptor

macro operation 顺序执行一组 primitive descriptor，只发布一个 parent completion。

| Opcode | 名称 | child count 约束 |
|---:|---|---|
| `0x40` | QKV projection macro | 必须等于 3 |
| `0x41` | MHA macro | 3 至 256 |
| `0x42` | FFN macro | 3 至 256 |

child fail-stop；中间 child completion 不对软件可见。

## 9. Completion ABI

每个 completion entry 为 16 byte：

| Word | 定义 |
|---:|---|
| 0 | task ID，`[15:0]` |
| 1 | status，`[3:0]`；error code，`[7:4]` |
| 2 | result |
| 3 | element count |

Status 值：

| 值 | 含义 |
|---:|---|
| 1 | 成功完成 |
| 2 | 带错误完成 |

writer 按 word 0 至 word 3 的顺序写入。只有 word 3 被 scratchpad arbiter 接收后，`CPLQ_TAIL` 才会改变。

## 10. Operation set

### 10.1 Scalar INT8 与 CNN

| Opcode | 操作 | 主要维度 |
|---:|---|---|
| `0x10` | INT8 VDOT | `LENGTH` packed word |
| `0x11` | INT8 GEMV | `M`、`K` |
| `0x12` | INT8 GEMM tile | `M`、`N`、`K` |
| `0x13` | INT8 Conv1x1 | GEMM-compatible layout |
| `0x14` | INT8 Conv3x3，im2col-compatible | `M`、`N`、`K` |
| `0x15` | INT8 depthwise Conv3x3，im2col-compatible | `M`、`N`、`K` |
| `0x16` | streaming Conv3x3 line buffer | height=`M`、width=`N`，均至少为 3 |
| `0x17` | streaming depthwise Conv3x3 line buffer | height=`M`、width=`N`，均至少为 3 |

每个 32-bit scratchpad word 含四个 signed INT8 lane。scalar datapath 执行 dot4，在 signed 64-bit accumulator 中累加，并写出 32-bit post-processed output。

### 10.2 Bank-local near-memory

| Opcode | 操作 |
|---:|---|
| `0x20` | 四 bank VDOT |
| `0x21` | 四 bank GEMV |

每个 bank-local PE 消费一对 packed INT8 word，产生 signed partial sum；四输入 reduction tree 生成总和。

### 10.3 Tensor matrix

| Opcode | 操作 |
|---:|---|
| `0x30` | 4x4 tiled tensor GEMM |
| `0x31` | batched/head-flattened tensor GEMM |

约束：

- M、N 必须非零且为 4 的倍数；
- K 以 `K/4` packed-word group 表示；
- A row 与 B column 按 tile-major banked layout 存储；
- 支持 transpose A/B、bias、shift 和 activation；
- `batch_count * head_count` 选择连续 instance；
- batch/head count 为 0 时按 1 处理。

矩阵核保留 A/B operand 的一项预取缓冲，在当前 K-group 的四个 MAC lane
执行期间请求下一组 operand。一个 4x4 tile 的 16 个 INT32 结果按四条
128-bit row 写回，代替原来的 16 次 scalar write；若 destination 仅满足
4-byte 对齐而不满足 16-byte 对齐，则自动回退到兼容的 scalar write。

### 10.4 Tensor SFU

| Opcode | 操作 | 数值约定 |
|---:|---|---|
| `0x32` | Softmax | signed Q8.8 log2-domain input，unsigned Q0.15 output |
| `0x33` | RMSNorm | integer/Q8.8 input，可选 Q0.15 gamma |
| `0x34` | residual add | signed INT32 |
| `0x35` | GELU | signed Q8.8 分段近似 |
| `0x36` | requantization | arithmetic shift 与 signed INT8 saturation |
| `0x37` | SiLU | signed Q8.8 分段近似 |
| `0x38` | LayerNorm | integer/Q8.8 input，可选 beta |
| `0x39` | causal Softmax | query index 位于 auxiliary `[15:0]` |

除法与平方根采用迭代电路，避免形成无界组合关键路径。

Activation 编码：

| 值 | 函数 |
|---:|---|
| 0 | none |
| 1 | ReLU |
| 2 | ReLU6 |
| 3 | 保留 |

### 10.5 KV-cache

| Opcode | 操作 |
|---:|---|
| `0x43` | 向 scratchpad KV-cache 写入 vector |
| `0x44` | 从 scratchpad KV-cache 读取 vector |

`aux0={head_index[15:0], token_index[15:0]}`。source stride 描述 token 与 head 间距。

## 11. Scratchpad 架构

默认组织：

```text
BANKS             = 4
WORDS_PER_BANK    = 32768
WORD_WIDTH        = 32 bit
TOTAL_BYTES       = 4 * 32768 * 4 = 524288 byte
```

地址交织规则：

- word-address 的 bits `[1:0]` 选择 bank；
- 更高 word-address bit 选择该 bank 内 row；
- banked read 同时读取四个 bank 的同一 row，要求 16-byte 对齐。

端口：

- Port A：AXI-Lite host/debug；
- Port B：scheduler scalar、四 bank banked read 或 128-bit line read/write。

read latency 为两拍。arbiter 使用 client tag 将 read response 返回到请求者。write 不会生成 read-response pulse。

host access 若与 scalar/banked/line scheduler access 重叠，会被拒绝并返回错误。

FPGA 综合使用四个 XPM true-dual-port block memory；VCS 使用带 parity tracking 的四数组行为模型。28nm 综合在单一 scheduler admission 模型下，将 512 KiB 映射为 32 个单端口 4Kx32 SRAM macro。

### 11.1 仲裁策略

控制面使用严格优先级：

1. descriptor fetch；
2. completion writer。

未发生控制面请求时，compute（scalar/line）、banked compute 与 DMA
（scalar/line）使用 round-robin 轮转仲裁。三个数据面客户持续请求时，
每个客户都能周期性获得准入机会，不会因为
固定优先级而永久饥饿。控制面请求若无限持续，仍可能延长数据面等待时间。

只有 `valid && ready` 才表示一笔请求被正式接收。

## 12. DMA 行为

### 12.1 统一 128-bit tagged DMA

- 一条 128-bit external beat 对应四个 scratchpad word；
- 16-byte 对齐且至少剩余四个 word 时，DMA 通过一次 128-bit scratchpad
  line transaction 搬运，不再拆成四次 scalar access；
- word-aligned 但未达到 16-byte 边界时，自动使用 32-bit alignment beat；
- 每个 burst 最多 16 beat，即 256 byte；
- burst 自动在 4 KiB boundary 前切分；
- 支持 1D load/store；
- 支持 2D row/stride load/store；
- 支持 gather load：scratchpad 中存放 absolute external row address 表；
- tile pipeline 复用同一 DMA；
- 最多四笔带不同 ID 的 read burst outstanding；
- R burst 可按 ID 乱序完成，由 RID 定位到 burst buffer；
- AXI4 没有 WID，因此一个 burst 内及不同 AW 对应的 W data 保持发射顺序；
- 最多四笔 write response 可通过 BID 独立返回；
- 尾部非完整 128-bit line 使用有效 word 数与 WSTRB 表示；
- DMA 性能计数按实际有效 beat byte 数累计。

### 12.2 AXI response

任意非 `OKAY` 的 read/write response 都转换为 DMA error。发生 backpressure 时，payload 和 valid 状态必须保持协议稳定。

## 13. Error code

error code 需结合报告该错误的模块理解。

### 13.1 Compute/common

| Code | 含义 |
|---:|---|
| 0 | none |
| 1 | invalid configuration |
| 2 | unsupported operation |
| 3 | abort |
| 4 | watchdog timeout |
| 5 | scratchpad parity error |
| 6 | scratchpad protection error |
| 11 | SFU numeric error |

### 13.2 Command processor

| Code | 含义 |
|---:|---|
| 3 | abort |
| 6 | descriptor fetch failure |
| 7 | invalid descriptor |
| 8 | command queue empty |
| 9 | completion queue full/unavailable |
| 10 | completion destination protected |
| 12 | dependency timeout |

### 13.3 DMA

| Code | 含义 |
|---:|---|
| 0 | none |
| 1 | invalid configuration |
| 2 | AXI read response error |
| 3 | AXI write response error |
| 4 | scratchpad access error |
| 5 | abort |

## 14. 性能计数器

性能监控是被动的，不得影响 ready/valid 行为。当前可观测：

- command cycle 与 processed element；
- tile total、DMA、compute、overlap、stall cycle；
- matrix total、MAC-active、banked-stall cycle；
- DMA read/write byte；
- 已接受 AR/AW transaction；
- current/high-water read outstanding；
- DMA R-channel stall cycle。

软件应在待测 workload 开始前清零扩展性能计数器。

## 15. 验证要求

AI sign-off testbench：`verif/tb/tb_ai_accel_smoke.sv`  
AI source list：`verif/sim/ai_accel.f`

VCS 命令：

```bash
cd verif/sim
make ai_upgrade_vcs
make ai_transformer
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

整数 reference model：

```bash
cd verif/sim
make ai_a4_ref
```

smoke environment 覆盖：

- AXI-Lite 独立 AW/W 到达与 response backpressure；
- register 与 scratchpad decode error；
- direct、one-shot descriptor、ring command mode；
- command/completion wrap、empty、full；
- internal/external descriptor fetch；
- completion 四 word 顺序；
- VDOT、GEMV、GEMM、banked、matrix、CNN、SFU、KV-cache；
- descriptor v3 dependency event 与 v4 macro aggregation；
- mapper 生成的 ABI v7.2 Transformer 30-command 数据依赖链；
- DMA load/store、burst、4 KiB split、2D、gather、wide outstanding；
- RID/BID response reordering；
- AXI error injection、abort drain、watchdog、parity、protection；
- reset recovery、sticky status 与 IRQ。

除非对应工具命令实际完成，不得声明仿真或综合通过。

## 16. 实现结果

### 16.1 XCZU15EG

历史项目记录表明，XCZU15EG 上曾以 100 MHz 运行，并完成 bare-metal 控制、DMA、descriptor、compute、completion 和 IRQ 测试。

当前仓库不包含完整 Vivado board build、约束和部署脚本；因此该结果在重新恢复并执行板级流程前，只能表述为“历史实板结果”。

### 16.2 TSMC28 HPC+ pre-layout

条件：

- TSMC28 HPC+；
- TT、0.9 V、25 C；
- clock period 4.0 ns；
- setup uncertainty 100 ps；
- pre-CTS hold uncertainty 20 ps；
- 32 个 `TS1N28HPCPL2SVTB4096X32M4MWBASO` SRAM macro。

报告结果：

| 指标 | 结果 |
|---|---:|
| 目标频率 | 250 MHz |
| Setup 状态 | met |
| Hold 状态 | met |
| 报告的总 cell 数 | 97,792 |
| SRAM macro 数 | 32 |
| Combinational area | 50,994.20 library area units |
| Noncombinational area | 28,024.67 library area units |
| Macro area | 1,127,675.75 library area units |
| Total cell area | 1,206,694.62 library area units |
| Total dynamic power | 14.5414 mW |
| Cell leakage power | 1.9459 mW |

scratchpad macro 约占 total cell area 的 93%。setup critical path 位于 `ai_tensor_sfu_core`。

## 17. 当前限制

- 尚无 post-route ASIC implementation 或 physical sign-off；
- 当前 Git snapshot 中没有可从 clean clone 复现的 XCZU15EG board build；
- 旧的 32-bit M_AXI block design 需要重新生成或插入 64-to-platform-address adapter；
- AXI、external CMDQ、direct DMA 和 tile external base 已支持 64-bit；计算和 completion 地址仍是 32-bit scratchpad-relative address；
- external DMA row base 需要 4-byte 对齐；非 line-aligned 前缀的带宽较低；
- scratchpad scheduler 的数据面已使用 round-robin，但尚未实现可编程 QoS/aging；
- scalar、banked 与 line 流量仍共享一组四 bank Port-B 资源，尚未形成独立多端口 SRAM；
- SFU 固定点运算使用有界硬件近似，不是 IEEE floating-point；
- 未实现 coherent cache interface、IOMMU、virtual addressing 或多进程隔离；
- RTL deliverable 不包含软件 compiler、图划分器或自动 tensor mapper。

## 18. 源码组织

| 目录 | 内容 |
|---|---|
| `rtl/top/` | 顶层集成 |
| `rtl/control/` | AXI-Lite、寄存器、command processor、descriptor、completion、performance |
| `rtl/dma/` | 统一 128-bit tagged multi-beat DMA |
| `rtl/memory/` | scratchpad、arbiter、protection |
| `rtl/compute/` | scalar、banked、matrix、CNN、SFU、KV-cache、tile pipeline |
| `verif/` | AI testbench、memory model、assertion、reference model |
| `syn/` | TSMC28/40 综合 wrapper 与脚本 |
| `fpga/` | FPGA RTL source list 与本地生成物 |
| `sw/` | 寄存器 ABI 与 bare-metal source |

新增或重命名 synthesizable module 时，需要更新：

- `verif/sim/ai_accel.f`；
- `fpga/xilinx_a7_100t/ai_accel_rtl.tcl`；
- `fpga/xczu15eg/ai_accel_rtl.tcl`；
- 对应 ASIC synthesis read list。
