# NMAForge AXI4 近存张量加速器详细规格（中文）

**RTL：A10；软件 ABI：v7.4；版本寄存器：`0x1000_000a`；顶层：`rtl/top/ai_accel_top.v`；事实日期：2026-10-26。**

> 本文按当前 RTL 及 `sw/include/cimforge_regs.h` 编写；发生冲突时，RTL 和头文件优先。本文只陈述已实现的全数字 RTL，规划项不会被写作已交付能力。

> 当前 A10 保留 `0x50 BF16_DOT_ACC_FP32`，新增 `0x51 FP16_DOT_ACC_FP32`；top smoke 已验证
> FP16 的 DDR→DMA→SPAD→命令/共享 completion→FP→SPAD→DMA→DDR 闭环，结果为 FP32 `0x41300000`。
> 顶层 UVM 现以六个可复现运行穷举同一 CMDQ 中 FP16 `0x51`、BF16 `0x50` 和 INT8 VDOT `0x10` 的全部 6 种提交顺序；每次均由独立参考模型检查三条成功 completion、SPAD 结果和 DDR 回写，随后在 CMDQ slot 3 提交一类非法 FP16 descriptor，六次分别覆盖 opcode、version、dimension、alignment、stride 与 flags 错误，并检查 `ERR_DESC` completion、CMDQ/CPLQ 环绕及错误 IRQ sticky/W1C。FP16/BF16 K=1/2 与有符号 INT8 lane 随 seed 变化。该六类是定向 validator 场景，不等于广泛随机 descriptor、AXI 错误或 reset recovery 闭环。
> 混合精度 dot UVM 最新工作树复跑的 seeds `712345/987654/20261015` 各有 484/484 scoreboard PASS
>（430 numeric + 54 fault/reset/error-transition），合计 1,452 笔，UVM warning/error/fatal 均为 0；
> 每个 seed 峰值 outstanding read=2，selected numeric/fault/reset 与 odd-tail parity coverage 均为 100%。DUT
> line/condition/FSM/branch 为 97.96%/97.00%/85.71%/92.86%。主 `state_r` 为 5/5 states、10/10
> transitions；`pending_error_r` 为 6/6 states、14/18 transitions；`ERR_ABORT`、`ERR_CONFIG`、`ERR_WATCHDOG` 在 `ST_WRITE` 的 prior-error 条件已形式证明排除，parity prior-error 转移仍未闭环。2026-10-17 新增 B 侧 NaN、`0×Inf` 与 B 侧 Inf 定向向量后，Python `unittest` 19/19 PASS；odd-length final-word parity 测试覆盖 BF16/FP16；late-B protection 用 1-cycle registered response 命中 ready-pair/error-cutoff cover，每 seed 两次；合并 request-stability SVA 为 28,290 attempts、8,610 real successes、0 failure/incomplete。
> 截至 2026-10-17，`ai_smoke` 与 seed `12345` 的 20-case top run 均 PASS；该日期的验证命令、coverage 与限制见 A10 RTM / run record。2026-10-17 VC Formal 证据：reset-initialized canonical harness 的 12/12 选定断言 proven、2/2 covers 命中且 setup clean；长度 1–4 parity harness 在 360 s 预算下通过 5/5 non-vacuous assertions、2/2 covers（depth 5）。扩展到全部非零 16-bit 长度后，read accounting、请求 word index 边界、cutoff 禁止 compute、drain 后进入 `ST_ERROR` 均已 proven；当时其余 cutoff/progress/writeback 属性未收敛且无反例。2026-10-23 后续使用实际 FP core 和算术 RTL，已单独非 vacuous 证明全长 `ST_WRITE` parity exclusion，并命中 2/2 parity covers；cutoff validity 也在 response-index bound 假设下单独 proven。完整六项、无辅助假设的 lifecycle aggregate 仍为 3/6，progress-bound proof 未闭环。reset-release/RDC 不属于这些证明范围。
> 没有新增 FP PPA。
> 全芯片 SpyGlass lint 当前为 0 errors、285 warnings、4 infos，尚非 warning
> closure/signoff。formal/LEC/DFT、后布局签核和 XCZU15EG 实板端到端验收仍未完成。

## 1. 产品定位

NMAForge 是可综合、面向 SoC 集成的全数字 AI 近存加速器 IP。软件通过 DMA 将 tile、权重、激活和 KV-cache 搬进邻近计算引擎的本地 SRAM，再在片上完成 INT8/定点计算，以减少外部 DDR 往返。其 banked VDOT/GEMV 路径实现了数字 CNM（Compute-Near-Memory）：四个 SRAM bank 各自邻接一个 Local Controller 和 Local PE，本 bank 内完成地址推进、A/B 读请求、operand 双缓冲、dot4 本地累加；仅在 output 边界传递四个 local sum 到 Global Reducer。它不是模拟 Compute-in-Memory：不修改 SRAM bit-cell、bit-line 或 sense amplifier，不在存储阵列内以模拟方式执行 MAC；也不是包含 CPU、NoC、CXL/LPDDR/HBM-PIM、DDR 控制器和 LLM serving 软件栈的完整系统。

当前重点是 INT8 VDOT/GEMV/GEMM、BF16/FP16 dot-to-FP32、1x1/3x3/Depthwise 卷积、Q15 Softmax（含 causal）、RMSNorm、LayerNorm、残差、GELU、SiLU、requant，以及 Transformer 的 QKV/MHA/FFN 宏编排与 KV-cache 读写。典型 decoder 数据流为：`Q/K/V 投影 → Q×K^T → causal softmax → attention×V → 输出投影 → residual+RMSNorm → FFN → residual+RMSNorm`。

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
- 普通 compute CMDQ 由 `ai_parallel_compute_dispatcher` 按序取/校验并派发，维护每引擎活动槽、依赖事件、abort/drain、CMDQ_HEAD 和按序 CPLQ_TAIL；宏/direct 等串行兼容路径仍由 `ai_command_processor` 协调。两者的具体边界与 REQ-PC 验收条款见 [Compute Cluster SPEC v1.1](COMPUTE_CLUSTER_SPEC_ZH.md)。
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

VCS 通过 `+define+VCS` 使用 `rtl/memory/ai_scratchpad.v` 的行为 RAM；Vivado 使用 XPM 分支。私有 ASIC overlay 将每个逻辑 bank 映射为 8 个 4K×32 单端口 macro，共 32 个 macro；具体 wrapper、库 view 和 macro 名称均不进入公开仓库。公开 SpyGlass profile 不展开 512 KiB 行为数组；实际综合和 STA 以私有、受许可的 `.db/.lib` 为权威。未对齐、越界、无权限或保护冲突访问必须报错。

SPAD 保护寄存器配置四个区域 R0–R3；每区的 `BASE` 是包含的起始字节地址，`LIMIT` 是不包含的结束字节地址。`PERM[0..3]` 依次表示 read、write、execute、enable；只有 enable 置位的区域参与匹配。有效请求必须在单个区域内完整结束（`addr + bytes <= LIMIT`），不能把相邻区域拼接；区域之间按 OR 匹配，任一完整匹配即可允许。若四区均禁用，保护检查为兼容模式并允许请求；启用任一区域后，零字节请求拒绝。无效请求不构成访问并通过保护检查。请求结束地址以 33 位计算，越过 32 位 SPAD 地址空间的访问不能匹配任何区域。该模块只产生 allow/deny；集成 fabric 负责把拒绝转换为对应客户端的保护错误与事务恢复行为。

## 4. 队列、描述符与完成项

软件写 CMDQ 描述符并发布 `CMDQ_TAIL`，硬件消费并报告 `CMDQ_HEAD`；硬件写 CPLQ 完成项并发布 `CPLQ_TAIL`，软件消费后发布 `CPLQ_HEAD`。CMDQ/CPLQ 可放在 scratchpad 或外部内存，`CMD_CTRL[0]` 选择外部描述符。CMD_HEAD/CPL_TAIL 的写仅用于复位/调试种子，不是正常运行时的软件推进方式。

一条 ABI v7 描述符固定 64 字节、64 字节对齐、16 个 little-endian 32-bit word；A9/ABI v7.3 加入 `0x50 BF16_DOT_ACC_FP32`，A10/ABI v7.4 增加 `0x51 FP16_DOT_ACC_FP32`，均不改变描述符字节布局：

| Word | 字段 | 定义 |
|---:|---|---|
| 0 | task/opcode | task ID[31:16]、opcode[7:0] |
| 1~4 | src0/src1/bias/dst | 地址或宏子描述符参数 |
| 5 | shape | M[15:0]、N[31:16] |
| 6 | extent | K、向量长度或子描述符数 |
| 7 | flags | bit0 bias；bit1/2 transpose A/B；bit3 外部宏；bit4 packed INT8；bit5 `PACK_I8_TILE_A` |
| 8 | aux0 | 操作专用字段，例如 KV head/token |
| 9 | postprocess | shift[4:0]、activation[6:5] |
| 10~12 | strides | src0、src1、dst 实例/批次步长 |
| 13 | batch/head | batch[15:0]、head[31:16] |
| 14 | events | wait[15:0]、signal[31:16] |
| 15 | ABI/clear | version[15:0]、clear[31:16] |

描述符版本、opcode、必要尺寸、宏子描述符或依赖不合法时必须拒绝。转置通过地址/布局产生，不要求整矩阵复制。完成项固定 16 字节：word0=task ID、word1=状态和 error[7:4]、word2=result、word3=element count。关键错误：abort=3、fetch=6、validation=7、empty queue=8、completion=9、protection=10、dependency=12；`ERROR_INFO` 的 source=1/2 分别代表命令/DMA 来源。

宏 opcode `0x40`–`0x42` 支持 v4 兼容地址与 ABI v7 地址：v4 从 `src0` 取 32-bit 子描述符列表基址；v7 从 `{src1,src0}` 取 64-bit 基址。列表基址需 64-byte 对齐，`length` 是子描述符数量，`flags[3]` 选择外部内存 fetch（1）或 scratchpad fetch（0）。v7 的 `src1` 是地址高 32 位，不作为独立数据指针做字节对齐检查；完整 64-bit 基址的低位对齐由 `src0` 检查。宏父命令只提交一个 completion，子命令顺序执行且失败时停止后续子命令。

SFU `REQUANT_I8`（opcode `0x36`）中 `flags[4]` 将饱和后的 INT32 结果按输入连续顺序打包为 INT8。可选 `flags[5]=PACK_I8_TILE_A` 必须同时设置 `flags[4]`，并要求 `M,N` 为非零 4 的倍数且 `length=M×N`。输入仍按 row-major 读取；输出按 Matrix A 的 `[row_group][k_group][row_lane]` 顺序写入，每 word 的四个低字节对应连续四列 K。其 word index 为 `(((row/4)×(N/4)+k/4)×4)+(row mod 4)`，地址为 `dst+4×word_index`。该模式没有 partial word；legacy bit4-only 的线性 packing 语义不变。

### 4.1 Compute CMDQ 并行派发

普通 compute descriptor 按 CMDQ 顺序逐个读取、校验和派发；不同计算引擎的任务允许重叠，每个引擎最多有一个未完成任务。一个引擎仍忙时，属于该引擎的后续 descriptor 留在队列中，不能覆盖它的活动上下文。普通 descriptor 的 `CMDQ_HEAD` 在被派发或被判定为错误时推进；完成记录严格按 descriptor 的 CMDQ 顺序写入 CPLQ，且每项四个 word 全部提交后才推进 `CPLQ_TAIL`。因此任务执行完成顺序可以不同，软件观察到的完成顺序不变。Requirement 编号、测试台架边界和验证证据见 [Compute Cluster SPEC v1.1](COMPUTE_CLUSTER_SPEC_ZH.md) 与 [Compute Cluster UVM Testplan](../verification/COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md)。

事件依赖仍按顺序提交语义处理：依赖事件在对应任务成功完成并轮到它按序退休后才生效；`wait`、`clear` 和 `signal` 不改变 CPLQ 顺序。宏 descriptor 在此前并行任务排空后移交串行命令处理器，宏内部仍按子 descriptor 顺序执行并只产生一个父 completion。direct/tile 模式也不与 CMDQ 并行任务混跑。

多个引擎可经 scheduler 的 round-robin core-SPAD 子仲裁器交错访问 scratchpad。该仲裁只保证单次端口请求和响应归属，不为不同 descriptor 建立数据依赖或跨引擎地址锁。软件必须确保可能并行的任务之间没有 SPAD 读写冲突；共享只读输入可以重叠，任何任务输出都不得覆盖另一活动任务仍要读取的数据。

写 `ABORT` 后停止派发新的 CMDQ descriptor，并向所有已派发的活动计算引擎发 abort。正在读取的 descriptor 先完成 fetch，再归类为 `ERR_ABORT`；已派发任务停止产生后续结果写入，并等待已接受的 SPAD 操作收尾。任务错误按引擎已报告的错误码记录；若 CPLQ 已启用，所有记录仍按 CMDQ 顺序退休。全部在途任务排空后调度器才报告空闲，尚未取出的 descriptor 保留在 CMDQ。

## 5. 算子、DMA 和性能

| Opcode | 算子 |
|---:|---|
| 10/11/12 | INT8 VDOT/GEMV/GEMM |
| 13/14/15 | Conv1x1、im2col Conv3x3、Depthwise |
| 16/17 | Conv3x3/Depthwise line-buffer |
| 20/21 | Banked VDOT/GEMV |
| 30/31 | Tensor GEMM/Batch GEMM（4×4 tile-major SPAD；top 默认 16×16 INT8 PE） |
| 32/39 | Softmax/Causal Softmax Q15 |
| 33/38 | RMSNorm/LayerNorm Q15 |
| 34/35/36/37 | Residual、GELU、requant、SiLU |
| 40/41/42 | QKV/MHA/FFN 描述符宏编排 |
| 43/44 | KV write/KV read |
| 50 (`0x50`) | BF16 点积、FP32 累加与结果（`BF16_DOT_ACC_FP32`） |
| 51 (`0x51`) | FP16 点积、FP32 累加与结果（`FP16_DOT_ACC_FP32`） |

Tensor GEMM descriptor ABI 与 4×4 tile-major SPAD operand 布局保持不变，M/N 仍须为 4 的倍数。Matrix controller 默认以 16×16 MAC array 执行宏 tile：每个 K word 从 SPAD 收集最多四组 4×4 A/B 数据，送入本地 operand buffer；尺寸大于 16 时按宏 tile 遍历，边缘 tile 只写有效元素。`ARRAY_SIZE=4/8/16` 参数配置均保留。

SFU `GELU_Q8_8` (`0x35`) 与 `SILU_Q8_8` (`0x37`) 输入、输出均为 32-bit
signed Q8.8 整数。GELU 分段定义为 `x<=-512: 0`、`x>=512: x`、其余为
`(x*(x+512)) >>> 10`；SiLU 分段定义为 `x<=-768: 0`、`x>=768: x`、其余为
`trunc_toward_zero(x*(x+768)/1536)`。边界比较基于 Q8.8 原始整数编码。
`CAUSAL_SOFTMAX_Q15` (`0x39`) 将 descriptor `aux0`（或 direct 模式的 SFU
epsilon 输入）解释为从 0 开始的 query token 下标，且该下标包含在可见范围内：
只有大于 query 下标的 score 才会被 mask。因此 query token 0 只保留 score 0，
输出 `[32768, 0, ...]`；该 opcode 不套用归一化运算的非零 epsilon 默认值。软件必须保证 query 下标小于向量长度。

`0x50` 与 `0x51` 均使用 ABI v7 descriptor 和现有 32-bit core-SPAD 口；分别解释输入为 BF16 与 IEEE binary16，乘积以 FP32 精度参与按元素顺序的非融合 FP32 累加，最终输出一个 FP32 word。SPAD 端口每周期至多发出一个新请求；两个 operand-pair buffer 允许最多两笔已接受但尚未返回的读请求，SPAD 响应必须按请求顺序返回（该端口不携带独立 read ID）。专用 descriptor 字段约束仍由 RTL validator 执行。`CAP2[6]`（掩码 `0x40`）表示 BF16 dot，`CAP2[7]`（掩码 `0x80`）表示 FP16 dot。A8 (`VERSION=0x1000_0008`) 保持 ABI v7.2 与 `CAP2=0x3f`；A9 为 ABI v7.3、`CAP2=0x7f`；A10 为 ABI v7.4、`CAP2=0xff`。三者 descriptor/completion 大小均为 64/16 字节，软件可据版本与 capability 位区分新增能力。

统一 DMA 支持 DDR↔SPAD 1D、二维 row/stride、indexed gather、tile load/compute/store。burst 最多 16 beats，且在每个 4 KiB AXI 边界拆分；最多四个 tagged read outstanding，RID 选槽位并由匹配 RLAST 释放，BID 归因写响应。传输层允许读响应乱序，但命令派发和完成发布仍按序。`DMA_CFG[0]` 为 gather，`[1]` 是只读 128-bit 能力，`[10:8]` 请求读并发且不得大于 4。

计数器提供 total/DMA/compute/overlap/stall 周期、completed tiles、matrix/MAC/banked-stall、DMA 字节、AR/AW、R stall 和 outstanding 高水位。`有效MAC/s=完成MAC数/实际时间`，`有效GB/s=(DMA读+DMA写字节)/实际时间`，`重叠率=PERF_OVERLAP/PERF_TOTAL`，`停顿率=PERF_STALL/PERF_TOTAL`。

## 6. 寄存器摘要

全部寄存器为 32-bit、相对 AXI-Lite base 的字节偏移。`0x000~0x048` 为 CTRL/STATUS/直接模式配置/IRQ/VERSION/CAP；`0x080~0x0D0` 为 CMDQ/CPLQ、doorbell、abort、watchdog、DMA 和 queue status；`0x0D4~0x100` 是 R0~R3 保护区；`0x104~0x118` 为 DMA 二维/后处理；`0x120~0x148` 为 tile 外部地址、双缓冲和尺寸；`0x14C~0x1B0` 为性能、事件、64-bit 地址高字、ABI、错误来源和 CAP2。

核心编码：STATUS bit0/1/2=busy/done/error；DMA_CTRL bit0/1=start/store；`ABI_INFO={16,64,4,7}`（completion bytes、descriptor bytes、minor、major）；`CAP2=0xff` 代表原有六项能力以及 BF16、FP16 dot-to-FP32。

## 7. 验证证据与边界

**A10 / 混合精度最新证据（2026-10-17 当前工作树）**：BF16 legacy dot-core gate 与 FP16 multiplier
向量测试有通过记录；mixed BF16/FP16 UVM seeds `712345`、`987654`、`20261015` 各 484/484
scoreboard PASS（430 numeric + 54 fault/reset/error-transition），合计 1,452 transactions，UVM
warning/error/fatal 均为 0；每 seed peak outstanding read=2，selected numeric/fault/reset 与 odd-tail parity coverage=100%。
最新三 seed run 将两个格式的随机数值长度覆盖扩展到 1..16：每 seed 420 行、每行 35 fields，BF16/FP16 各 215 numeric transactions；merged URG `cp_length` 16/16、`format_length_cross` 32/32，均 100%。该证据来自 dirty worktree，不是 frozen-SHA replay；只证明长度 1..16 的随机数值仿真，不改变 RTL/ABI，也不证明全长 parity lifecycle/writeback。短 formal 仍约束长度 1..4；V1/A10 总体仍开放。命令及结果目录 `/tmp/nmaforge_a10_fp_length16_20261017/` 见 A10 运行记录。
DUT line/condition/FSM/branch 为 97.96%/97.00%/85.71%/92.86%。`state_r` 5/5 states、10/10
transitions；`pending_error_r` 6/6 states、14/18 transitions；`ERR_ABORT`、`ERR_CONFIG`、`ERR_WATCHDOG` 在 `ST_WRITE` 的 prior-error 条件已形式证明排除，parity prior-error 转移仍未闭环。
late-B protection 的 ready-pair/error-cutoff cover 每 seed 命中 2 次；合并
request-stability SVA 为 28,290 attempts、8,610 real successes、0 failure/incomplete。canonical VC
Formal 对 12 条选定属性 proven、两个 cover 命中且 reset setup clean；长度 1–4 parity proof 为
5/5 assertions、2/2 covers（360 s bounded run）；全长 parity 证明仍有属性未收敛（无反例），不得称 parity closure。最新成功 `ai_smoke` 与
`ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 为 2026-10-17 当前工作树；历史 license 连接失败已由成功
重跑取代。
FP16 queued DDR→DMA→SPAD→FP→SPAD→DMA→DDR 的仿真结果为 `0x41300000`，使用 compact AXI memory
model，不是 DDR PHY/板级验证；也没有新增 FP PPA。完整 transaction、assertion、code-coverage、
命令、环境和 dirty-worktree 边界见 [A10 DV RTM](../verification/A10_DV_RTM.md) 与
[A10 RTM](../verification/A10_DV_RTM.md)。

**2026-10-23 compute 验证追补：** FP core 在最终计算进入 `ST_WRITE` 前显式检查无 pending error、且本拍无新 failure。VC Formal 使用实际 FP core/算术 RTL，在所有非零 16-bit length、对齐地址、禁用 abort/watchdog 和合法 outstanding-response 约束下，证明 `ap_writeback_excludes_pending_parity`（非 vacuous，safe depth 156），并命中 2/2 parity covers。BF16/FP16 长度 `65535` 的 final-A/final-B parity 仿真和 clean recovery 也通过。cutoff validity 在 response-index bound 假设下另有 compositional proof；无辅助假设的六项 lifecycle aggregate 仍为 3/6，progress-bound proof 未收敛。顶层 CMDQ 已支持跨引擎最多每引擎一个在途任务、按提交顺序退休；Matrix+SFU overlap、同引擎排队、SPAD response 归属和并行 abort/drain 通过 directed smoke。覆盖率和 formal 边界见[compute 验证状态](../verification/COMPUTE_ENGINE_STATUS.md)及[交互验证记录](../verification/COMPUTE_ENGINE_INTERACTION_FOLLOWUP_2026-10-23.md)。

**2026-10-25 Matrix 16×16 controller 追补：** `ai_tensor_matrix_core` 默认实例化 `ARRAY_SIZE=16`，descriptor ABI 与 4×4 tile-major SPAD 数据布局不变；controller 已实际完成 16×16 GEMM 与跨宏 tile GEMM 的 SPAD 读、MAC 和写回。对应原始三 seed 数据、benchmark 和当时 coverage 保留为历史记录；更新后的 2026-10-26 多 seed 结果见下一条。

**2026-10-26 Matrix/CNM ownership、profiling 与多读流水追补：** 修正 `ai_spad_arbiter` 的 response client 编码别名：Matrix banked response 使用 tag 3，CNM 使用 tag 5；二者仍共享同一 round-robin admission class。真实 top smoke 对 CNM GEMV + Matrix GEMM 并发运行做 owner 隔离、Golden 和 completion 检查。Matrix core 增加仿真内部状态周期和 stall profile，并为 Banked Read 增加有序 metadata FIFO，最多 4 笔 outstanding；abort、watchdog、protection 和 parity fault 会停止新请求并排空已接受 response。固定一拍 behavioral SPAD 的 16×16×K32 depth-4 VCS benchmark 为 242 cycles、33.85 MAC/cycle、13.22% array utilization、16.93 normalized GOPS@250MHz；相同配置的串行 baseline 为 357 cycles。该仿真不等于 SRAM macro 时序或 PPA。此 P0-B 记录之后已增加 P0-C ping-pong prefetch/MAC overlap 和 A-tile reuse，结果见下一条及[Compute Cluster 升级路线](../verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md)。

**2026-10-26 Matrix P0-C / A-tile reuse 与真实 top UVM 追补：** Matrix core 在当前 K group MAC 期间将下一组 A/B 读入 inactive buffer，响应收齐后才置 valid 和切换；Abort/watchdog/parity/protection 清 valid 并 drain 接受的请求，reset 清除本地队列并由 top-level 检查旧任务隔离和 recovery。K≤64 时在相邻 N macro tile 复用 A tile，K>64 绕过 cache。VCS 三 seed × outstanding depth 2/4 均通过，每 seed 17 numerical/layout cases、17 fault/recovery cases（含 prefetch parity/abort/watchdog/reset）。深度 4 block DUT-only `ai_tensor_matrix_core` URG line/condition/FSM/branch=`96.59/88.48/66.67/95.48%`，FSM 转移仍为 40/60，未收敛到完整覆盖。A-cache ON/OFF 的 16×16 array benchmark：16×32×K32 为 469→417 cycles、128→96 reads；32×32×K64 为 1443→1187 cycles、512→384 reads。真实 top UVM 16×32×64 GEMM 三 seed 均检查 512 个 Golden 输出、16 次 A-cache hit、120 个 prefetch/MAC overlap 周期；UVM warning/error/fatal=`0/0/0`，focused covergroup=`65.4%`。merged whole-top URG line/condition/FSM/branch/assert/group=`47.54/41.38/10.52/37.70/60.00/19.11%`，含 DUT/SVA/TB/UVM，不能当作 DUT-only 或完整 cluster 覆盖。固定一拍 behavioral bank response、假定 250 MHz 的仿真指标不是 macro timing 或 PPA；完整 Cluster UVM 与 signoff 仍开放。复现命令和日志见[Compute Cluster 升级路线](../verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md)。

**2026-10-26 后续验证状态（更新上段的中间结果，不改变本 SPEC 的硬件契约）：** Matrix core focused URG 达到 49/53 FSM transitions（92.45%，15/15 states）；prefetch FSM 为 9/9 transitions。真实 top 七引擎定向 UVM 三 seed 通过，focused functional covergroup=`97.9%`，但不是 DUT-only code coverage；随机 fault/phase cross、完整 reference-memory scoreboard、mutation 与 clean-SHA replay 仍未完成。新的八配置 Matrix cycle/read 比较及 86-descriptor 单头 synthetic-weight Transformer prefill/decode 通过；Transformer fixture 不是 pretrained model，模型精度未评估。DC 能启动，但当前 checkout 缺少可复现的 Matrix/Top synthesis runner、SDC、标准单元库和 SRAM timing view，因此当前 16×16 RTL 的 area/Fmax/power 仍未测量。细节见[升级路线](../verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md)和[Compute Cluster UVM Testplan](../verification/COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md)。

VCS top smoke 当前使用 86-descriptor 的单头 prefill + decode synthetic-weight Transformer fixture，并覆盖随机 GEMV/GEMM/Conv、错误/保护和 reset recovery；该工作负载的精确边界见上方更新。扩展回归是 `make ai_comp`、`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`。2026-08-06 的 SpyGlass macro-aware lint 记录为 **0 error、414 warnings、4 info**（共 418 条信息，仍需分类）；CDC setup 为 0 error、12 warnings，CDC structural verify 显示 0 个 unsynchronized crossing、0 个 convergence，但因缺少 Advanced_CDC license 而有 1 条工具/许可证 error，不能称 sign-off；RDC structural verify 的 2 条 error 同样仅为 Advanced_CDC / `rdc_adv_checker` license 缺失，不能作为 RTL reset-crossing 违规解读，也不能称 RDC sign-off。

商用 28 nm、TT/0.9V/25°C 的当前 CNM RTL 在 4.0 ns pre-layout DC 中 setup/hold 均无违例；关键路径约 3.89 ns。功耗仅有默认/部分活动率估计，不是 SAIF workload sign-off 功耗。XCZU15EG 100 MHz OOC 已有实现证据，但尚非整板验收。公开报告见 `TSMC28_SYNTHESIS_REPORT.md`。

可信表述是“TSMC28、250 MHz pre-layout setup/hold closure”。400 MHz 需要 2.5 ns，当前关键路径仍差约 1.37 ns；需要在 SRAM→SFU、exp/sum 和 tile 边界流水化后，重新完成 DC sweep、P&R、多角 STA、功耗和板级验证，才可作进一步频率/PPA 结论。

## 8. 权威文件

`rtl/top/ai_accel_top.v`（集成）、`rtl/control/axi_lite/ai_accel_regs.v` 与 `sw/include/cimforge_regs.h`（ABI）、`rtl/control/queue/ai_command_processor.v`（命令）、`rtl/control/queue/ai_completion_writer.v`（完成原子性）、`rtl/dma/ai_axi128_dma.v`（DMA）、`rtl/memory/ai_spad_arbiter.v`/`ai_scratchpad.v`（SRAM）、`dv/subsystem/top_smoke/sim/ai_accel.f`（VCS）和 `dv/spyglass/a8_static.prj`（SpyGlass）。ASIC macro adapter 位于私有 overlay。

## 9. 电路模块与信号交互
| 模块 A | 模块 B | 主要信号 | 用零基础语言解释 |
|---|---|---|---|
| CPU | `axi_lite_reg_if` | `aw* / w* / b*`、`ar* / r*` | CPU 通过 AXI-Lite 写配置、读状态。比如“做 GEMM”“CMDQ 在哪”“中断开不开”。 |
| `axi_lite_reg_if` | `ai_accel_regs` | `reg_req_valid/write/addr/wdata`、`reg_rsp_rdata/error` | AXI-Lite 翻译员把复杂总线语言翻成内部“读/写寄存器”。 |
| `ai_accel_regs` | `ai_command_processor` | `submit`、`direct_start`、`core_abort`、`cmdq_*`、`cplq_*` | 前台把 CPU 配置交给主任：有新任务、队列在哪、是否中止。 |
| `ai_command_processor` | `ai_desc_fetch` | `fetch_start`、`fetch_base`、`desc_*` | 主任让片上 descriptor 读取器拿到任务说明书。 |
| `ai_command_processor` | `axi_desc_fetch` | `fetch_start`、`fetch_external`、`fetch_base`、AXI `AR/R` | 若任务说明书在 DDR，主任改叫外部读取器去 DDR 拿。 |
| `ai_desc_fetch` / `axi_desc_fetch` | `ai_command_processor` | `desc_op`、`desc_src0/src1/dst`、`desc_m/n/k`、`desc_flags`、`fetch_done/error` | 读取器把任务说明书交回主任：做什么、数据在哪、矩阵多大、是否转置、有没有错误。 |
| `ai_command_processor` | 各计算核 | `launch_valid`、`launch_op`、`launch_src0/src1/dst`、`launch_m/n/k` | 主任把任务单发给正确的工人。`launch_op` 决定交给谁。 |
| `ai_command_processor` | `ai_completion_writer` | `completion_start`、`task_id`、`status`、`result`、`element_count` | 任务结束后，主任要求质检员写一条完成记录。 |
| `ai_completion_writer` | `ai_spad_arbiter` | `cpl_spad_valid/write/addr/wdata`、`cpl_ready` | 质检员申请往 completion queue 写四个 word。 |
| `ai_axi128_dma` | DDR | `m_axi_ar* / r*`、`m_axi_aw* / w* / b*` | 搬运车从 DDR 读数据或把结果写回 DDR。 |
| `ai_axi128_dma` | `ai_spad_arbiter` | `dma_spad_*`、`dma_spad_line_*` | DMA 说：“我要往 SRAM 搬一行数据”或“我要从 SRAM 取一行数据”。 |
| 所有计算核 | `ai_spad_arbiter` | `spad_valid/write/addr/wdata`、`spad_ready` | 每个计算核想读写 SRAM，都先向交通警察申请。 |
| `ai_spad_arbiter` | `ai_scratchpad` | `spad_*`、`spad_line_*`、`spad_banked_*`、`spad_cnm_*` | 仲裁器决定这拍让谁访问 SRAM，再把请求真正发给 SRAM。 |
| `ai_scratchpad` | `ai_spad_arbiter` | `spad_rdata`、`rsp_valid`、`error`、`parity_error` | SRAM 返回读到的数据，或告诉仲裁器访问失败/校验错误。 |
| `ai_spad_arbiter` | 请求它的模块 | `rsp_valid`、`rsp_client`、`rsp_rdata`、`rsp_error` | 仲裁器把读结果准确还给最初申请的模块。 |
| `ai_banked_cnm_core` | 四个 `ai_bank_local_controller` | 四组 bank-lane 请求/响应 | CNM 总管启动四个本地小工人，每人负责一个 SRAM bank。 |
| `ai_bank_local_controller` | `ai_bank_pe` | `a_word`、`rsp_data`、`partial_sum` | 本地控制器给 PE 两个 INT8 数据块；PE 做 dot4 乘加，返回局部结果。 |
| `ai_banked_cnm_core` | `ai_spad_arbiter` | `cnm_req_valid[3:0]`、`cnm_addr0..3`、`cnm_rsp_valid[3:0]`、`cnm_data0..3` | CNM 一次可对四个 bank 分别发读请求。`[3:0]` 的每一位对应一个 bank。 |
| `ai_tensor_matrix_core` | `ai_spad_arbiter` | `banked_read_*`、`spad_*`、`line_*` | 4×4 矩阵核读取矩阵块、做乘加，再用 128-bit line 写回结果。 |
| `ai_tensor_sfu_core` | `ai_spad_arbiter` | `spad_*`、`busy/done/error` | SFU 从 SRAM 取向量，做 Softmax、Norm、激活、量化，再写回。 |
| `ai_conv3x3_linebuffer_core` | `ai_spad_arbiter` | `spad_*`、`busy/done/error` | 卷积核按滑窗读取数据、计算 Conv3x3 或 DWConv3x3。 |
| `ai_kv_cache_engine` | `ai_spad_arbiter` | `spad_*`、`src0_stride`、`aux0` | KV 单元根据 head、token、stride 读写 KV-cache。 |
| `ai_spad_protection` | host / compute / line / CNM / completion 请求方 | `region*_base/limit/perm`、`*_protection_error` | 保安。检查地址是否越界、是否有读写权限；不合法就报错。 |
| `ai_perf_monitor` | DMA / matrix / tile pipeline / regs | `perf_dma_*`、`perf_matrix_*`、`perf_clear` | 计时员。统计搬了多少数据、停顿多少周期、矩阵核真正干活多少周期。 |
| `ai_accel_regs` | CPU/GIC | `irq` | 任务完成或出错时，按下“通知 CPU”的铃。 |

### 10. 项目功能点
| 你想做的事 | 谁来做 | 模块间怎么配合 | 最终得到什么 |
|---|---|---|---|
| CPU 配置加速器 | CPU、`axi_lite_reg_if`、`ai_accel_regs` | CPU 写 AXI-Lite 寄存器 | 设置任务、DMA 地址、队列、保护区、中断。 |
| 提交 AI 任务 | `ai_accel_regs`、`ai_command_processor` | `submit` + `CMDQ_TAIL` | 主任知道有新任务。 |
| 读取任务说明书 | command processor、`ai_desc_fetch` / `axi_desc_fetch` | `fetch_start`、`desc_*` | 获得算子、地址、矩阵尺寸、stride、依赖关系。 |
| 检查任务是否合法 | `ai_command_processor`、protection | descriptor 字段、地址区间、依赖 event | 不合法任务不会启动，会生成错误 completion。 |
| 从 DDR 搬数据 | `ai_axi128_dma`、arbiter、scratchpad | AXI `AR/R`、`AW/W/B`；`dma_spad_line_*` | 权重、激活、tile、KV 数据搬进片上 SRAM。 |
| 进行普通 INT8 计算 | `ai_int8_compute_core` | `launch_*`、`spad_*` | 支持 VDOT、GEMV、基础 GEMM、Conv1x1 等。 |
| 做 CNM GEMV/VDOT | `ai_banked_cnm_core`、4 个 local controller/PE | `cnm_req_valid[3:0]`、四路地址和数据 | 四个 SRAM bank 各做局部计算，最后合并结果。 |
| 做矩阵乘法 | `ai_tensor_matrix_core` | `banked_read_*`、`line_*` | 4×4 INT8 GEMM、Batch GEMM、转置、bias、激活、量化。 |
| 做 Attention 的特殊步骤 | `ai_tensor_sfu_core` | `spad_*`、`op_mode` | Softmax、causal mask、RMSNorm、LayerNorm、GELU、SiLU、requant。 |
| 做卷积 | `ai_conv3x3_linebuffer_core` | `spad_*`、高度/宽度参数 | Conv3x3、Depthwise Conv3x3。 |
| 读写 KV-cache | `ai_kv_cache_engine` | 地址、stride、head/token 参数 | KV 写入和按布局读取。 |
| 让多个模块别抢 SRAM | `ai_spad_arbiter` | `valid/ready`、`rsp_client` | 控制面优先，计算/DMA 轮询，读结果返回正确客户。 |
| 让 load/compute/store 重叠 | `ai_tile_pipeline`、DMA、计算核 | tile start、buffer0/1、DMA/compute 状态 | 为双缓冲流水提供控制骨架。 |
| 收尾并通知软件 | command processor、completion writer、regs | completion 四 word、`CPLQ_TAIL`、`irq` | 软件可确认任务成功/失败、读结果、继续下一任务。 |
| 测性能瓶颈 | `ai_perf_monitor` | `perf_dma_*`、`perf_matrix_*` | 得到 DMA 字节数、stall、outstanding、MAC 周期等。 |
| 中止或恢复 | command processor、DMA、全部计算核 | `abort`、`watchdog`、`resetn` | 错误时停止任务，等待已发 AXI 事务收尾，恢复空闲状态。 |

最简单的一次任务流程是：
```
1. CPU 写寄存器：任务和数据在哪里？
2. CPU 发布 CMDQ_TAIL：有新任务。
3. command processor 读取 descriptor：任务是否合法？
4. DMA 从 DDR 把输入搬到 SRAM。
5. arbiter 决定谁能访问 SRAM。
6. 计算核从 SRAM 读数据并计算。
7. 结果写回 SRAM，必要时 DMA 写回 DDR。
8. completion writer 写完成项。
9. irq 通知 CPU：这单做完了。
```
