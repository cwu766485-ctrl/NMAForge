# NMAForge Compute Cluster 功能与接口规格（中文）

> **文档编号**：NMA-CL-SPEC-001\
> **版本**：v1.4，**Parallel Compute Cluster 功能与 DV 需求基线**（不是 RTL/产品 Sign-off）\
> **日期**：2026-10-28\
> **基线**：从 NMAForge main commit 6742e227c1f52b5266ea19e034b17f33c583b813 延伸，A10 / ABI v7.4\
> **设计模块**：rtl/top/fabric/compute/ai_accel_compute_cluster.v\
> **目的**：约束 Compute Cluster 的功能、时序、对外端口和异常处理，作为 UVM Testplan / Scoreboard / Coverage / SVA 的需求来源。
> **对应 Testplan**：[COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md](../verification/COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md)。
> **Freeze**：v1.1 冻结 REQ-CL-001～028 与 REQ-PC-001～010；v1.2 冻结外部 AXI reset/fabric epoch 边界；v1.3 冻结 SFU 数值合同；v1.4 冻结七类 Engine 的 4-bit Error ABI、同拍错误优先级和可见写回前缀规则。未完成的 Engine × Fault × Phase 覆盖仍是验证缺口，不因写入规格而视为通过；接口或可观察行为变化必须升版。

## 0. 规范用语及适用范围

- **[AS-IS]** 表示已经在指定 RTL 或产品规格中核实的当前行为。
- **[REQ]** 表示计划约定的设计/集成行为，应经过 Review 后成为 Pass/Fail 标准；**不能仅因本文写入就假定 RTL 已满足**。
- **[OPEN]** 表示尚未得到统一规范、需要进一步确认或修正的差异；属于未验证或被阻塞的条件，不能凭本文自动转为通过。
- 本文沿用 v1.0 的七引擎算子和数值基线，并由 v1.1 的 REQ-PC 条款明确 CMDQ 并发、CPLQ 保序、共享 SPAD 所有权及 abort/drain。v1.3 关闭 SFU 定点公式歧义；v1.4 冻结 Error ABI、同拍优先级和写回前缀规则。
- 此文档的 DUT 本体只包括 **ai_accel_compute_cluster** 与内部七类计算核心；顶层 Opcode Decode、普通 Compute Request MUX、SPAD Arbiter、Scratchpad、DMA、AXI、Descriptor Validator、Command Processor 和 Completion Writer 均属于上层/外围。
- **推荐 Subsystem DV 边界**是 Cluster + 与实际顶层等价的 Compute Request MUX/Response Routing + 真实 SPAD Arbiter + 四 Bank 行为 SRAM。仅测 Cluster 裸模块不能证明真实 SPAD 仲裁无误。
- 本 SPEC 不声称其为七路同周期发射、Systolic Array 或完整 RISC-V Vector FP ALU。队列按 CMDQ 顺序逐个派发；最多七个不同引擎各有一个活动任务。

## 1. 硬件架构

~~~text
                  Command Processor / Tile Pipeline
                  core_start, launch_*, core_abort
                               |
                  +------------v-------------+
                  | ai_accel_compute_cluster |
                  | Opcode/Start Gating      |
                  +------------+-------------+
                  |            |             |
       Scalar INT8 / 4-bank CNM / 4x4 Matrix
       Tensor SFU  / Conv3x3   / KV Cache / Mixed FP Dot
                  |            |             |
                  +------------+-------------+
                  | Busy OR / Done OR        |
                  | Done-priority Result MUX |
                  +------------+-------------+
                               |
                   core_busy/done/error/result
                               |
                       Command Processor

每类 Engine 的独立 SPAD 请求
            |
顶层 Compute Request MUX / 专用 CNM-Banked-Line 通路
            |
     ai_spad_arbiter + 4-bank Scratchpad
~~~

**[AS-IS]** Cluster 是结构包装模块，无独立 AXI4/AXI-Lite 接口，不负责真实 SRAM 仲裁。多种引擎共用 **core_start** 和统一的任务结果输出；普通 32-bit SPAD 请求由顶层根据 Engine Busy 选择。

### 1.1 七类 Engine 及 Opcode

| Engine / RTL | Opcode | 目前支持的计算或操作 |
|---|---|---|
| **Scalar INT8**：ai_int8_compute_core | 0x10–0x15（legacy INT8/Conv 路径） | Packed signed INT8 VDOT/GEMV/GEMM Tile 及对应 legacy 卷积操作 |
| **CNM**：ai_banked_cnm_core（4 个 bank-local controller） | 0x20、0x21 | 四 Bank 本地 INT8 累加、全局 Reduction，Banked VDOT/GEMV |
| **Matrix**：ai_tensor_matrix_core | 0x30、0x31 | 4×4 INT8 GEMM / Batch GEMM，Transpose、Bias、Requant、Activation |
| **SFU**：ai_tensor_sfu_core | 0x32–0x39 | Softmax / RMSNorm / Residual / GELU / Requant / SiLU / LayerNorm / Causal Softmax 等定点算子 |
| **Conv Line Buffer**：ai_conv3x3_linebuffer_core | 0x16、0x17 | Conv3×3 / Depthwise Conv3×3，流式行缓冲 |
| **KV Cache**：ai_kv_cache_engine | 0x43、0x44 | KV Write / KV Read 的片上内存复制及 Token/Head 地址生成 |
| **Mixed FP Dot**：ai_mixed_precision_dot_fp32_core | 0x50、0x51 | BF16/FP16 Multiply + 非融合、顺序 FP32 Accumulate，输出 FP32 |

**[AS-IS]** 0x40–0x42 为上层 Macro Descriptor 调度，不是 Cluster 的额外 Engine。顶层 Decoder 将 0x10–0x17 全部归在 int8 class，同时用独立的 **conv_linebuffer_op** 将 0x16/0x17 送至 Conv Engine。因此 0x16/0x17 **不应**按 Scalar INT8 Start 测试。未支持 Opcode 由上层校验；Cluster 自身并没有统一的 Opcode Error Generator。

## 2. Cluster 对外端口（RTL 接口契约）

### 2.1 时钟与启动

| 信号 | 方向/位宽 | 说明 |
|---|---|---|
| aclk / aresetn | in / 1 + 1 | Cluster 时钟、低有效复位；各 Engine 含异步断言复位行为 |
| core_start / core_abort | in / 1 + 1 | 任务启动/终止。**没有 core_ready**，不能把 Start 当作普通 Valid/Ready 接口 |
| banked_op | in / 1 | 启动 CNM |
| tensor_matrix_op | in / 1 | 启动 Matrix |
| tensor_sfu_op | in / 1 | 启动 SFU |
| conv_linebuffer_op | in / 1 | 启动 Conv |
| kv_cache_op | in / 1 | 启动 KV |
| launch_op | in / 8 | Opcode；FP 0x50/0x51 在 Cluster 内直接识别 |

**[AS-IS] Start 条件：**

~~~text
CNM      = core_start && banked_op
Matrix   = core_start && tensor_matrix_op
SFU      = core_start && tensor_sfu_op
Conv     = core_start && conv_linebuffer_op
KV       = core_start && kv_cache_op
Mixed FP = core_start && (launch_op == 0x50 || launch_op == 0x51)
Scalar   = core_start && 上述五个 Engine Select 都为 0
                     && launch_op != 0x50 && launch_op != 0x51
~~~

**[REQ-CL-001]** 上层只在目标 Engine 空闲、Opcode 有效、参数合法时发起对应任务；不同 Engine 可同时保持活动。\
**[REQ-CL-002]** 每次正常启动恰好选择一个 Engine；Opcode Decode 与 Engine Select 必须一致。\
**[REQ-CL-003]** 启动采样边界，launch 参数稳定且有效，完成前不得发生未定义的任务切换。\
**[v1.1 合法 Launch 决议]** 每个 descriptor 只选择一个 Engine；同一 Engine 最多一个活动任务，该 Engine 忙时后续同 Engine descriptor 保留在 CMDQ 等待。不同 Engine 可重叠执行并可同拍 Done。并发发射的调度/退休规则见 REQ-PC-001～010。CMDQ consumer 不得覆盖活动 Engine 的已锁存参数。

### 2.2 Launch 参数

| 信号 | 位宽 | 作用 |
|---|---:|---|
| launch_src0 / launch_src1 / launch_dst | 32 各 | SPAD 源/目标**字节地址** |
| launch_length / launch_m / launch_n / launch_k | 16 各 | 向量长度、矩阵 M/N/K words、图像 H/W；随 Opcode 解释 |
| launch_shift | 5 | 量化或后处理 Shift |
| launch_activation | 2 | 激活方式 |
| launch_bias_base / launch_bias_enable | 32 / 1 | Bias 地址和使能 |
| launch_flags | 8 | Matrix flags[1]/[2] 分别控制 A/B transpose；SFU flags[4] 控制 requant packing |
| launch_aux0 | 32 | SFU epsilon/causal token、KV token/head 等 |
| launch_src0_stride / launch_src1_stride / launch_dst_stride | 32 各 | Batch、KV 等地址步长，单位 byte |
| launch_instance_count | 32 | Matrix Batch 实例数；集成顶层从 Batch × Head 产生 |
| watchdog_limit | 32 | 超时阈值，按 Engine 实际逻辑解释 |

**[REQ-CL-004]** 各 Engine 只使用其 Opcode 定义的有效字段；无关字段变化不能改变正在执行的任务。\
**[REQ-CL-005]** 任务接受后，必需的地址/尺寸/格式等参数在该 Engine 内部正确锁存；运行中上游参数变化不得污染在途任务。\
**[OPEN-CL-002]** 每个 Opcode 的合法 dimension/stride/对齐/零长度、输入输出地址别名和地址溢出须分别对照 Descriptor Validator 与引擎实现建立完整参数表，不能预设所有 Engine 使用同一限制。

### 2.3 普通 Compute → SPAD 接口

**[AS-IS]** Cluster 分别导出以下逻辑请求：**scalar_spad_\***、**fp_spad_\***、**sfu_spad_\***、**conv_spad_\***、**kv_spad_\***、**matrix_spad_\***、**banked_spad_\***。每组的有效字段包括：

- 输出：**valid**（1）、**write**（1）、**addr**（32）、**wdata**（32）。
- 相关输入：**arb_core_ready**（1）、**core_rsp_valid**（1）、**arb_rsp_rdata**（32）、**core_rsp_error**、**core_spad_parity_error**、**compute_prot_error**。

读写**请求**的接受条件：

~~~text
request_fire = selected_spad_valid && arb_core_ready
read_fire    = request_fire && !selected_spad_write
write_fire   = request_fire &&  selected_spad_write
~~~

**[AS-IS]** 顶层 `ai_compute_spad_mux` 对七个普通 Compute requester 使用轮询准入，并在等待 ready 时保持当前 owner；被接受读事务的注册响应返回原 requester。CNM 四-bank 专用请求仍走独立 banked 端口。

该 MUX **位于 Cluster 外**。不能将七个请求端口理解为七个同周期独立完成的物理 SRAM 接口。

**[REQ-CL-006]** 请求在未接受时必须按照所属 Engine/接口的规定保持有效字段稳定；合法 Abort/Reset 例外需另定义。\
**[REQ-CL-007]** 读响应的 data/error 必须只由拥有该已接受请求的 Engine 消费；**core_rsp_valid 不是需要 ready 二次接受的 AXI R 通道**。\
**[REQ-CL-008]** 每一个合法接受的写事务，其地址、数据、数量和最终 Memory Image 与算子 Reference Model 一致；对于多输出算子，错误前可能存在已提交的合法前缀写入。\
**[v1.2 Reset/Fabric 合同，收窄 OPEN-CL-003]** 普通 32-bit 请求先由真实 `ai_compute_spad_mux` 选中一个 Engine，再进入唯一 `ai_spad_arbiter` CORE client；ready/protection 只返回该 owner。注册读响应按接口合同返回已接受读的 owner，非 AXI 通道，不支持任意乱序。FP Dot Outstanding 上限为 2；其它引擎不假定统一深度。Abort 要等待各 Engine 已接受的 SPAD 操作收尾。若 reset 时仍有已接受 AXI 读/写事务，集成必须同时复位加速器与拥有该事务的 AXI fabric；fabric 清除旧 epoch 的 R/B 响应，复位释放后不得向新 epoch 返回旧响应。只复位加速器而保持 fabric 运行时，必须先排空/隔离 DMA，且 AR/AW/W/R/B 均无在途事务。该 reset 不规定外部存储内容是否清零。VCS UVM 已分别在 accepted AR/R 与 accepted AW/W、BVALID 等待阶段执行协调复位，并检查释放后 8 周期无旧 R/B 响应、无新 DMA 请求和 DMA idle；证据针对 behavioral AXI responder。任意外部 fabric 的实现合规及非 FP Engine Abort drain 仍开放。

### 2.4 CNM 四 Bank 专用端口

| 功能 | 真实端口 |
|---|---|
| 请求/Grant | **cnm_read_valid[3:0]**；**cnm_read_addr0..3[31:0]**；**arb_cnm_ready[3:0]** |
| 各 Bank 注册响应 | **cnm_rsp_valid[3:0]**；**cnm_data0..3[31:0]**；**cnm_parity[3:0]** |
| 错误 | **cnm_protection_error** |

**[REQ-CL-009]** 四个 Bank 的请求接受、响应和 Parity 归属必须对应各自 Lane；不能以单个总 ready/rsp_valid 代替。CNM 计算完毕后经普通 Banked Result SPAD 输出写回。

**[v1.1 实现约束，2026-10-26]** Matrix 单行 Banked Read 与 CNM 四 lane 请求共享 `ai_spad_arbiter` 的 Banked 轮询时隙，但响应 owner 必须区分：内部 Matrix client tag=`3`，CNM client tag=`5`。`banked_rsp_valid` 只代表 Matrix；`cnm_rsp_valid[3:0]` 只代表 CNM 并保留各 lane mask。两者同拍竞争时一次只接受一个请求；不得把 CNM 响应同时广播给 Matrix。

### 2.5 Matrix Banked 与 Line 接口

| 功能 | 真实端口 |
|---|---|
| Matrix Banked Read | **matrix_banked_read_valid**, **matrix_banked_read_addr[31:0]**, **arb_banked_ready**, **banked_rsp_valid**, **banked_data0..3**, **banked_parity[3:0]**, **banked_protection_error** |
| Matrix 128-bit Line | **matrix_line_valid**, **matrix_line_write**, **matrix_line_addr[31:0]**, **matrix_line_wdata[127:0]**, **matrix_line_wstrb[15:0]**, **arb_core_line_ready**, **line_prot_error**, **spad_line_raw_error** |

**[REQ-CL-010]** Banked 读取、普通 32-bit 请求、128-bit Line 写回分别使用其对应握手规则、保护判断和数据比对；Line Byte Strobe 为独立的 16-bit 检查对象。\
**[OPEN-CL-004]** Line 接口有效 strobe、地址对齐及部分写入的精确规则，待 Matrix + SPAD 集成 Review 后冻结。

**[Matrix P0-B 实现约束，2026-10-26]** Matrix 默认最多允许 4 笔已接受的 Banked Read 在途，可用 `MAX_OUTSTANDING_READS=2` 配置两笔模式。请求端只在 `valid && ready` 时推进地址；Response 无 ready/ID，必须按接受顺序返回。Controller 的本地 response metadata FIFO 保存 A/B、4×4 group、K group 和完整地址，按该 metadata 写入对应 operand buffer。Abort、watchdog、保护或 parity fault 会停止后续发读，并在报告 completion/error 前排空所有已接受 response。该实现把读请求和 response latency 流水化；它不表示下一 K group 已与当前 MAC 重叠，后者仍属 ping-pong prefetch 计划。

**[Matrix P0-C / P1 dataflow 实现约束，2026-10-26]** Controller 在当前 K group 执行 MAC 时，可向 inactive A/B operand buffer 预取下一 K group；buffer 只有在该组所有已接受 response 收齐后才置 valid，MAC 仅消费有效 buffer。Response metadata 必须保留目标 buffer、A/B operand 与 group 归属。Abort、watchdog、parity、protection 会停止新请求并按 P0-B 规则 drain 已接受响应；reset 清除本地预取状态，top reset 检查须确认无旧任务写回/完成并验证 recovery。对相邻 N macro tile，A-tile cache 复用同一 A 行；当前配置容量为 16 个 K group（K≤64 个 INT8 元素），新 A row/batch tag 清除 cache valid；K>64 自动绕过 cache。Cache 是 RTL 内部优化，不改变 descriptor、opcode、SPAD 布局或软件 ABI。验收使用独立 Golden、inactive-buffer-valid checker、prefetch/MAC overlap、cache-hit/跨 N tile 检查，以及 parity/abort/watchdog/reset 恢复用例。

Matrix/CNM 同时运行时，回归须分别检查 accepted read response 的 owner、lane mask、Matrix Golden 输出及 CNM Golden 输出；共享只读输入和互不重叠输出符合并发 SPAD 合同。

### 2.6 状态、结果和性能接口

| 输出 | 位宽 | [AS-IS] 语义 |
|---|---:|---|
| scalar_busy / fp_busy / banked_busy / matrix_busy / sfu_busy / conv_busy / kv_busy | 各 1 | 对应 Engine Busy |
| core_busy | 1 | 七路 Busy 的逻辑 OR |
| core_done | 1 | 七路 Done 的逻辑 OR |
| core_error / core_error_code | 1 / 4 | 根据 Done Owner 选择 Error 和编码 |
| core_result | 32 | 结果汇总 |
| core_cycle_count / core_element_count | 32 各 | 任务统计 |
| matrix_perf_mac_active / matrix_perf_banked_wait | 1 各 | Matrix 的活动/等待观测 |

VCS Matrix controller 另保留每任务 FSM state-cycle、Arbiter stall、响应等待和写回等待计数，供 benchmark 逐任务读取；这些诊断计数不增加软件 CSR 或 descriptor ABI。接受范围和基准结果见[Compute Cluster 升级路线](../verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md)。

**[AS-IS]** 完成属性 MUX 的选择优先级：

**FP > Conv > KV > Matrix > SFU > CNM > Scalar**（由各路 **done** 控制）。

该 MUX 保留作 direct/tile 兼容观察口；Parallel dispatcher 必须消费 `engine_done/error/result/cycle/element` 七路向量，不能用聚合的 `core_done` 处理并发结果。

**[REQ-CL-011]** 对每个已派发 descriptor 仅接受其 owner Engine 的 Done；不同 descriptor 的多个 Engine 可在同周期 Done，系统必须分别锁存结果，不得依赖 `core_done` 聚合脉冲识别多个完成。\
**[REQ-CL-012]** 当 core_done 有效时，core_result/error/error_code/counters 必须来自**唯一的合法完成 Engine**；其他周期这些字段不保证存在新的有效任务结果。\
**[REQ-CL-013]** 对每个合法任务只能报告一次完成，不得出现丢完成、重复完成、错误的 owner 或错误码串用。\
**[v1.1 完成决议]** 调度器按 CMDQ 顺序为每个 Engine Done 建立独立完成记录。不同 Engine 的完成可乱序到达或同拍到达；软件可见 CPLQ 仍按 descriptor 顺序退休。每个 Engine 在活动槽释放前不得接受其下一 descriptor。

## 3. 算子与结果数据的基本语义

### 3.1 Scalar INT8：VDOT/GEMV/GEMM 与 Legacy Conv

- 32-bit SPAD word 含 4 个 signed INT8 lane；Dot4 按有符号乘法累加。
- 检查输入符号扩展、K words、输出条数、Bias、右移、ReLU/ReLU6、饱和及写回地址。
- **[OPEN-NUM-01]** 每个 Opcode 的逐位舍入/截断、先后处理顺序、溢出边界须补 Numeric Appendix。

### 3.2 CNM：Bank-Local PE 与 Global Reduction

- 四个独立 Bank-Local Controller；各自生成 A/B 请求、保留局部累加，随后 Global Reduction 得最终结果。
- **length 的单位是完整 packed dot4 word**，并非单字节元素；该接口没有 byte-tail/lane-mask。
- 重点检查四路 Bank 地址、Prefetch、每路 Response/Parity、局部/全局累加、背压与恢复。

### 3.3 Matrix：4×4 存储 tile 与 16×16 INT8 Tensor Engine

- M/N 仍以 4 为最小存储 tile，launch_k 是 K/4 的 **word 数**。top 的 Matrix controller 默认使用 16×16/256-MAC array，每个 K word 从原有 tile-major 布局收集最多四组 A/B tile；尺寸大于 16 时遍历 M/N 宏 tile。
- Descriptor、opcode 和 A/B tile-major SPAD 布局保持兼容；支持 Transpose A/B、Batch Stride、Bias、Requant、Activation。
- `ARRAY_SIZE=4/8/16` 均可参数化；检查行列索引、Batch、极值饱和、SPAD Banked/Line 通路、Partial Sum、尾 Tile 合法性。16×16 与 32×16 已有三 seed block Golden evidence；完整 Cluster UVM 仍由 C1 testplan 追踪。

### 3.4 Tensor SFU：0x32–0x39

- 实现定点 Softmax / Causal Softmax / RMSNorm / LayerNorm / Residual / GELU / SiLU / Requant。
- Q 格式、Softmax 指数近似、整数除法/平方根、饱和、PWL 边界和 Requant packing 以 [SFU 定点数值合同](SFU_NUMERIC_CONTRACT_ZH.md) 为准；验收基于其整数公式逐位比较，不对理想实数算子做误差承诺。
- `0x36` 打包输出每 word 最多含 4 个按输入顺序排列的低字节；不完整末尾 word 的有效 byte lane 按向量长度确定。

### 3.5 Conv3×3：0x16/0x17

- 三行 Line Buffer；signed INT8 位于 SPAD 32-bit word 的低 8 位；**stride=1、valid/no-padding**。
- 3×3 卷积输出 INT32；Width 默认最大 128、Height/Width 最低为 3；Depthwise 通过多个 Channel Descriptor 运行。
- 重点为最小/最大图像形状、换行、窗口对应、Signed 和写回 Layout。

### 3.6 KV：0x43/0x44

- KV Write/Read 是片上地址生成与数据搬运，而非完整 Attention 硬件计算。
- **launch_aux0 = {head_index[15:0], token_index[15:0]}**；src0_stride 表示 Token Byte Stride，src1_stride 表示 Head Byte Stride。
- 检查 token/head/stride 地址计算、读写方向、相邻缓存区、长度、地址溢出及 Reset/Abort。

### 3.7 Mixed FP Dot：0x50/0x51

- 每个 32-bit SPAD word 打包两个 BF16/FP16 数据：偶数元素 bits[15:0]，奇数元素 bits[31:16]。
- A/B 顺序读取；乘积以 FP32 参与**非融合、逐元素、固定次序**的 FP32 累加，输出单个 FP32 word。
- 两组 Operand-Pair Buffer，最多两笔被接受但尚未响应的读请求；**返回必须有序**，因为该端口无 Read ID。
- 长度奇数时，尾字的多余元素不得参与计算；按现有数值契约做 bit-exact Reference Model。
- FP NaN/Inf/±0/subnormal/RNE 等语义由 **docs/spec/FP_EXTENSION_SPEC_ZH.md** 细化；不可把它类比为完整 SIMD FP Add/Sub/Compare 单元。

## 4. 任务时序与异常契约

### 4.1 正常任务

1. 上层确保 opcode/参数有效，目标 Engine 活动槽可用；其它 Engine 可继续执行。
2. `launch_valid` 采样后唯一目标 Engine 接受启动，并锁存所需 launch 字段。
3. Engine 通过适当 SPAD 端口读数据，受 Ready 和 Response 延迟影响；执行运算并写入结果。
4. 对应 Engine 给出 Done/Error/Result，Cluster 将唯一 Owner 的结果交给 Command Processor。
5. Parallel dispatcher 记录 Engine 结果并按序交给 Completion Writer；只有提交完成项全部四个 word 后才发布 CPLQ tail。

**[REQ-CL-014]** 未接受的 SPAD 请求不能当成完成；在合法环境进展/Watchdog 假设下，没有无限等待或幽灵事务。\
**[REQ-CL-015]** 正常返回成功的任务必须保持数值/地址正确和 exactly-once Done/有效写回。\
**[REQ-CL-016]** 相邻两个不同 Engine 的任务之间，不得把上个任务迟到的 Response 或 Done 错归给下一个任务。

### 4.2 Abort/Watchdog/Parity/Protection/Reset

**[AS-IS]** 七个引擎分别实现 Abort、超时和 SPAD 错误响应；Cluster 没有统一异常 FSM。规格 v1.4 将各模块 4-bit `error_code` 冻结为一致原因码，并明确不同 Engine 当前可区分的原因范围。

**[REQ-CL-017]** 错误码与 Result 归属必须来自当前 Engine；发生错误后的内存写入必须符合该 Opcode 已提交前缀的规则。\
**[REQ-CL-018]** Reset 后无新任务不得出现旧任务 Done/写请求；已接受外部存储读/写请求的 Drain/Discard 语义需按 Cluster+SPAD Subsystem 单独审查。\
**[REQ-CL-019]** 不允许未验证的 Abort/Reset 同拍组合破坏新任务、泄漏旧任务结果。\

#### 4.2.1 Compute Engine Error ABI（v1.4）

`error_code` 是 Compute Engine 自身的 4-bit 原因码；DMA、Descriptor Validator 和 AXI completion transport 的错误码属于独立 ABI，不复用本表。`0` 表示成功/无错误。七类 Engine 使用同一含义：

| Code | 规范原因 | 适用说明 |
|---:|---|---|
| 0 | NONE | 无错误 |
| 1 | CONFIG | Engine 参数或地址配置不合法 |
| 2 | OPCODE | Engine 收到不支持的操作码；没有原生 opcode 输入的 Engine 不产生此码 |
| 3 | ABORT | 活动任务被软件/上层 Abort |
| 4 | WATCHDOG | 活动任务达到 watchdog 阈值 |
| 5 | PARITY | 可区分的 SPAD 数据 parity 错误 |
| 6 | PROTECTION | 可区分的 SPAD 访问保护错误 |
| 7 | SPAD | Engine 接口只提供合并的 SPAD error 时使用，不能据此区分 parity 与 protection |
| 8 | NUMERIC | SFU 数值运算失败 |
| 9–15 | RESERVED | Compute Engine 不得分配新含义，除非升版 SPEC |

| Engine | 支持的 Error Code |
|---|---|
| Scalar INT8、CNM、Matrix | 1–6 |
| SFU | 1–6、8 |
| Mixed FP | 1、3–6；操作码在上层格式选择，Engine 无独立 OPCODE 错误输入 |
| Conv、KV | 1–4、7；当前接口将 SPAD parity/protection 合并为一个错误输入 |

任务完成时，`error_code` 必须来自对应 Engine owner，并原样进入该任务的 completion；不得被另一个活动 Engine 的错误码覆盖。配置/Opcode 错误发生在启动检查阶段，不参与运行时错误仲裁。此表冻结原因码含义，不意味着每个 Engine 都实现或验证了表中每一种原因。

#### 4.2.2 同周期异常优先级（v1.4）

异步 Reset 始终最高：清除活动任务状态、Done、Error 和 `error_code`，不会报告运行时错误码。配置/Opcode 检查只在启动边界进行。运行期间同一采样沿多个异常同时成立时，按下表选择唯一最终原因：

| Engine | 同拍运行时优先级（高 → 低） | 证据边界 |
|---|---|---|
| Scalar INT8、CNM、SFU | Abort > Watchdog > Protection > Parity | 单故障有码表测试；CNM/SFU 本轮增加 Abort 与已到期 Watchdog 同拍测试；完整 Fault × Phase 未闭环 |
| Matrix | Abort > Watchdog > Protection > Parity > bank-response context/config | Matrix core 定向回归检查已到期 Watchdog 同拍 Abort 和 Abort 与 bank parity/protection；并发 Phase 矩阵仍部分 |
| Conv、KV | Watchdog > Abort > 合并 SPAD error | 本轮逐个检查 Watchdog 已到期时与 Abort/SPAD error 同拍 |
| Mixed FP | 当前尚无 pending error 时，Parity > Read Protection > Write Protection > Abort > Watchdog；跨周期先采到的错误保持为最终原因 | 当前证据验证选定 parity/protection/Abort 序列；全部同拍组合仍待测 |

#### 4.2.3 已提交输出前缀

SPAD 普通写入以 `spad_valid && spad_ready` 为接受；Matrix line 写以对应 `line_valid && line_ready` 为接受。错误发生前或错误采样同一沿已被接受的写入属于已提交结果，不能撤销。对按元素/行顺序输出的 Opcode，所有已接受输出必须组成从逻辑输出索引 0 开始的连续前缀；不得有空洞，出现 Error 后不得再接受该任务的后续输出。单次最终结果 Engine 只能提交零个或一个结果 word。Reset 不回滚 Reset 前已经接受的存储写入，但不得在新 epoch 继续产生旧任务写入。

**当前验证状态：** Error ABI 已冻结；CNM、Matrix、SFU、Conv、KV 的选定 priority/prefix 场景已有 checker 证据。该证据不覆盖每个 Engine 的全部原因对、所有内部 Phase、同拍输出握手和 Reset 组合。REQ-CL-017/019/027 的剩余合法交叉仍为 PARTIAL；禁止仅凭这次规格冻结宣称 DV closure。

## 5. 推荐 Verification Requirements → Testpoints

| ID | Feature | 核心 Testpoint / Check | 推荐 Coverage |
|---|---|---|---|
| CL-001~003 | Launch/Decode | 七 Engine 逐个启动；合法连续切换；非法并发作为待澄清测试 | engine × launch_state |
| CL-004~005 | 参数锁存 | 运行时改变非当前任务参数，不应污染结果 | engine × config_changed |
| CL-006~008 | Scalar SPAD | 请求保持；Ready 随机反压；响应延迟/归属；输出地址/数据 | engine × stall_bin × rd_wr |
| CL-009 | CNM Bank 接口 | 四 Bank 独立响应、读时序偏移、Parity Lane 定位 | cnm_lane × rsp_latency |
| CL-010 | Matrix 专用端口 | Banked 读与 128-bit Line 写；WSTRB/边界 | matrix_op × wstrb × stall |
| CL-011~013 | Done/Result MUX | 各 Engine Done/Result/计数对拍、连续两种 Engine | prev_engine × next_engine × finish_status |
| CL-014~016 | 任务生命周期 | 背压、迟到 Response、Reset/Abort、任务恰好一次完成 | engine × lifecycle_phase × outcome |
| CL-017~019 | 错误/恢复 | Error × State × Recovery，已提交前缀与无幽灵写 | engine × fault_kind × phase |
| Numeric | 算子数值 | Scalar/CNM/Matrix/SFU/Conv/KV/FP 独立 Golden 与结果 Memory Image | engine × opcode × numeric_class |

**验证状态更新（2026-10-27）**：真实 top 七引擎 UVM、Matrix depth-4 block、prefetch fallback、checker-sensitivity campaign 和 clean-SHA replay 已有运行证据；这不等于所有冻结 Requirement 已关闭。按 **Sequence → Monitor/Scoreboard/SVA → Coverpoint → Test Log** 的逐项结果、OPEN 依赖、精确 SHA 和运行记录见[2026-10-27 S1/S2 签核候选报告](../verification/COMPUTE_CLUSTER_S1_S2_SIGNOFF_CANDIDATE_2026-10-27.md)及[Compute Cluster UVM Testplan](../verification/COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md)。SPEC 中仍标记 OPEN/BLOCKED 的条款保持未关闭状态。

### 5.1 推荐验证平台边界

~~~text
UVM Test / Virtual Sequences
       |
Command Agent (Sequencer / Driver / Passive Monitor)
       |
Compute Cluster DUT
       |
Top-compatible Request MUX + Response Router
       |
真实 ai_spad_arbiter + 4-Bank Behavioral SPAD
       ^
Memory Contention / Latency / Error Agent

被动 Command Monitor + SPAD Monitors
            |
Per-Opcode Independent Reference Models
            |
Owner + Memory Image + Numerical Scoreboard
            |
Functional Coverage / SVA / URG
~~~

应优先复用已有 **dv/block/compute/fp/** 的 UVM 和 Python 数值模型、**dv/subsystem/dma_spad/** 中的 CNM/SPAD 检查，以及 Matrix/CNN-KV Directed Bench；**dv/subsystem/tensor_datapath/** 仍是 task-based BFM。`dv/uvm` 新增的 top-level test 也只是尚未运行的 Matrix/SFU 定向切片，不能说已具有完整 Compute Cluster UVM。

### 5.2 建议退出条件（Exit Criteria）

1. 每一个对外支持的 Engine/Opcode 都有非空 Directed 和 Constrained Random 自检（不仅仅有编译通过）。
2. Normal/Abort/Watchdog/Parity/Protection/Reset 中的 P0 合法组合都完成结果与 SPAD Memory Image 检查。
3. 单任务 Owner、请求-响应归属、Backpressure、结果 MUX、Done Exactly Once 均有 SVA/Scoreboard 实际运行证据。
4. Matrix、SFU、Conv、KV 补齐可独立追溯的数值/地址 Golden；FP 与 CNM 资产复用，不重复造轮子。
5. 未命中功能及 RTL 代码覆盖逐项解释，禁止仅凭选定 covergroup 100% 宣称整个集群 100%。
6. 至少一次 Cluster 级 Mutation 被验证环境抓到，保存失败 Seed/波形/恢复回归，且将人为 Mutation 与真实 Bug 区分。
7. 固定 Git SHA，在**干净 Checkout** 重跑代表性 Block + Subsystem Regression，留存 Tool Version、Log、Coverage Manifest。
8. 当前不规定任意“100% Toggle”作为机械目标；合法不可达、未激励和已知未支持场景必须逐项 Disposition。

## 6. 必须先经过设计 Review 的 P0/P1 问题

| 编号 | 级别 | 问题 | 对 DV 的影响 |
|---|---|---|---|
| OPEN-CL-001 | v1.0 已决议 | 非法上游 Launch 不属于合规 DUT 激励 | 环境断言约束；可另外做鲁棒性观察 |
| OPEN-CL-005 | v1.0 串行假设，由 v1.1 REQ-PC-002/003 supersede | 每个 Engine 有一个 active slot；不同 Engine 可重叠，同一 Engine 的下一 descriptor 等待其 slot 释放 | 按 engine owner 和 CMDQ 顺序校验 |
| OPEN-CL-006 | **Closed in v1.4** | 七类 Engine 的统一 4-bit 原因码已冻结；Engine 能力差异显式列于 4.2.1 | 码表冻结不等于所有 Engine × Fault 的覆盖已完成 |
| OPEN-CL-003 | P0 部分冻结 | 正常请求/返回归属用真实 Arbiter；REQ-PC-010 已冻结 reset/fabric epoch 边界；非 FP outstanding 深度及 Abort drain/restart 仍待逐 Engine 核对 | 未定异常组合 Testpoint=BLOCKED_SPEC |
| OPEN-CL-002 | P1 | 每个 Opcode 的参数合法边界、地址别名/越界、零值规则是什么？ | 数值/地址 Reference 缺口 |
| OPEN-CL-004 | P1 | Matrix Line 接口 WSTRB、对齐、Protection 的完整规则是什么？ | 128-bit Line Checker 误判 |
| OPEN-CL-007 | **Contract frozen in v1.4** | Engine-specific 同拍优先级和输出前缀语义已列于 4.2.2/4.2.3 | 合法 Fault × Phase × Reset 交叉覆盖继续追踪为 PARTIAL |
| SFU-NUM-01 | **Closed in v1.3** | SFU 的逐位整数公式与输入域见 [SFU 数值合同](SFU_NUMERIC_CONTRACT_ZH.md) | R21 记录已通过的 testpoint；未测试的输入域仍非 PASS |

## 8. v1.0 补充规范：每 Engine 的需求编号

此前各类运算只有描述没有 Requirement ID。以下数值/数据处理需求属于本版本的可追踪规范，准确度以引用的每算子 RTL、Golden 和既有项目数值 SPEC 为基准，不能复制 DUT 状态机作为 Oracle。

| Requirement | Feature / 验收合同 | 备注 |
|---|---|---|
| REQ-CL-020 | Scalar INT8：0x10～0x15 的有符号 packed INT8、VDOT/GEMV/GEMM/legacy Conv 结果及 Memory Image 正确 | K word 单位、Shift/Activation/Saturation 按精确独立模型 |
| REQ-CL-021 | CNM：0x20/0x21 四 Bank 请求/回应归属、局部乘加/归约和最终写回正确 | K 为完整 packed dot4 word；支持 Bank 响应错拍 |
| REQ-CL-022 | Matrix：0x30/0x31 保持 4×4 tile-major ABI，并执行 16×16 宏 tile/跨 tile GEMM；batch、transpose、bias、requant、Line WSTRB 结果正确 | M/N 为 4 的整数倍；16×16/32×16 block Golden 三 seed 通过；UVM C1 与未确认的部分 WSTRB 情况仍开放 |
| REQ-CL-023 | SFU：0x32～0x39 定点 Q 格式、近似函数、输出饱和/舍入/打包与 [SFU 数值合同](SFU_NUMERIC_CONTRACT_ZH.md) 一致 | 用独立整数 Golden 做 bit-exact；当前通过域限于合同和 RTM 中列出的长度/边界向量 |
| REQ-CL-024 | Conv：0x16/0x17 的有符号 3×3 窗口、stride=1、valid/no-padding、INT32 输出和地址正确 | height/width 至少 3，MAX_WIDTH 参数默认 128 |
| REQ-CL-025 | KV：0x43/0x44 token/head/stride 地址、方向、Memory Image 和异常边界正确 | aux0 高 16=Head、低 16=Token，检查地址计算溢出 |
| REQ-CL-026 | Mixed FP：0x50/0x51 原始 bit、严格顺序的非融合 FP32 累加、奇数尾元素、至多两笔 Outstanding 与单结果正确 | 采用 FP_EXTENSION_SPEC_ZH.md 原始位型 Golden |
| REQ-CL-027 | Error：各 Engine 任务 owner、已有提交前缀、合法错误码及异常后无非授权新写正确 | v1.4 统一原因码；Engine 可实现的故障源不同，证据仍按 Engine/Fault/Phase 追踪 |
| REQ-CL-028 | Perf：cycle/element counters 与唯一任务归属一致；Matrix 活跃/等待事件有可复核计数 | 不假设所有 Engine 的固定周期开销相同 |

### 8.1 符合性假设与测试分层

1. 合法环境：每项 descriptor 只选择一个 Engine；仅当该 Engine 活动槽空闲时派发。不同 Engine 任务允许重叠；软件负责避免并发 SPAD 读写冲突。违反者仅记录 OUT_OF_CONTRACT。
2. Compute Cluster 裸模块没有统一事务 ID 或 AXI 接口；并发 subsystem Testbench 必须复用真实 Top `ai_compute_spad_mux`、Response Routing 与 `ai_spad_arbiter`，并单独跟踪 descriptor/task owner。
3. 验证 Checker 分开处理成功 Memory Image、出错前已提交前缀、未接受请求不得算作成功、Done 恰好一次、返回不能串入下一个 Engine。
4. 非 FP Outstanding 深度/异常 Drain、完整 Fault × Phase 覆盖和 Matrix Line 特殊字节屏蔽仍归档为 OPEN/PARTIAL；Error ABI 与 priority oracle 按本 SPEC v1.4；SFU 算术按 v1.3 合同验收，不可变成空 Covergroup 的 100%。

### 8.2 Open Issue Disposition

| 编号 | 状态 | 解除阻塞所需证据 |
|---|---|---|
| OPEN-CL-003 | P0 部分 OPEN | 非 FP 在途请求深度、Abort/Reset drain/restart 时序、Response ownership 波形与断言证据 |
| OPEN-CL-002 | P1 OPEN | Validator × Engine 的每算子地址/长度/stride/alias 精确定义 |
| OPEN-CL-004 | P1 OPEN | Matrix 128-bit Line WSTRB/Alignment/Partial Write 具体规则 |
| CL-COV-006 | P1 PARTIAL | 依 v1.4 固定优先级 oracle，补齐合法 Engine × Fault × Phase × committed-prefix checker；不可达及接口不提供的故障组合单列 disposition |
| OPEN-NUM-01 | P1 OPEN | Scalar INT8 的逐算子舍入、定点溢出和边界 Numeric Appendix |
| OPEN-NUM-02 | **Closed in v1.3** | SFU 数值公式和独立 bit-exact oracle 已冻结；合同域的实测闭环见 RTM R21 |

**冻结状态说明**：v1.1 是并行派发合法范围 DV 基线；v1.2 定义协调 reset/fabric epoch 约束；v1.3 定义 SFU 定点算术；v1.4 定义 Compute Engine Error ABI、优先级与写回前缀。其他 Open Item 不因升版自动关闭，未来修改可观察行为必须升版并关联 Testplan 的 Requirement ID。

## 7. 仓库基线及引用文件

- [Compute Cluster RTL](https://github.com/cwu766485-ctrl/NMAForge/blob/9c4aea103a23a42a00fea7bcb092fbe7483e3a15/rtl/top/fabric/compute/ai_accel_compute_cluster.v)
- [NPU Top 集成、普通请求选择及保护](https://github.com/cwu766485-ctrl/NMAForge/blob/9c4aea103a23a42a00fea7bcb092fbe7483e3a15/rtl/top/ai_accel_top.v)
- [Opcode Decode](https://github.com/cwu766485-ctrl/NMAForge/blob/9c4aea103a23a42a00fea7bcb092fbe7483e3a15/rtl/control/descriptor/ai_accel_opcode_decode.v)
- [全局中文 SPEC](https://github.com/cwu766485-ctrl/NMAForge/blob/9c4aea103a23a42a00fea7bcb092fbe7483e3a15/docs/spec/SPEC_ZH.md)
- [FP 数值与访存详细 SPEC](https://github.com/cwu766485-ctrl/NMAForge/blob/9c4aea103a23a42a00fea7bcb092fbe7483e3a15/docs/spec/FP_EXTENSION_SPEC_ZH.md)
- [DV Verification Matrix](https://github.com/cwu766485-ctrl/NMAForge/blob/9c4aea103a23a42a00fea7bcb092fbe7483e3a15/dv/VERIFICATION_MATRIX.md)
- [A10 Verification RTM / Closure Status](https://github.com/cwu766485-ctrl/NMAForge/blob/9c4aea103a23a42a00fea7bcb092fbe7483e3a15/docs/verification/A10_DV_RTM.md)

## 9. v1.1 Parallel Compute Cluster Requirements

以下条款是正式 Requirement，覆盖本文件 v1.0 基线中“Cluster 空闲后才可启动下一任务”“同周期最多一个 Engine Done”等串行假设。它们定义顶层 CMDQ 调度、共享普通 SPAD 通路和 CPLQ 可观察行为；不改变各 Engine 的算子数值合同。

| Requirement | 冻结合同 | 验收要点 |
|---|---|---|
| REQ-PC-001 | **21 个无序 Engine Pair 均可并行**：Scalar INT8、Mixed FP、CNM、Matrix、SFU、Conv、KV 七类引擎两两组合共 `C(7,2)=21`；不同 Engine 可同时 busy。 | 21/21 pair overlap，按实际顶层 CMDQ/引擎启动检查。 |
| REQ-PC-002 | **每 Engine 一个 Active 槽**：单个 descriptor 只启动一个 Engine；同 Engine 的后继 descriptor 保留在 CMDQ，前一任务结果被安全锁存且活动槽释放后才能派发。 | 跨引擎并行；同引擎不得双重活动、覆盖上下文或丢任务。 |
| REQ-PC-003 | **CMDQ 派发顺序**：descriptor 按 CMDQ head 顺序取回、校验和尝试派发。目标 Engine 忙时可等待该 descriptor；不得越过它重排软件提交顺序。 | `CMDQ_HEAD`、每次 launch 与 task ID 顺序一致。 |
| REQ-PC-004 | **CPLQ 完成 FIFO**：执行可乱序完成；结果/error/counters 按其 CMDQ descriptor 顺序进入完成 FIFO。CPLQ 满或 Completion Writer busy 时保留记录、不得覆盖/丢失；四个 completion words 全部写入后才推进 tail。 | 故意反转完成延迟；CPLQ 满后确认停在 head、释放空间后按序恢复。 |
| REQ-PC-005 | **同时 Done**：多个不同 Engine 可同拍报告 Done，必须各自锁存唯一 task owner 的结果与状态，不能因聚合 `core_done` 合并或丢失完成。 | 至少一组双 Engine 同周期 Done，并检查各自最终 completion。 |
| REQ-PC-006 | **共享 Compute SPAD 单所有权**：七个普通 requester 经 `ai_compute_spad_mux` 逐个准入 `ai_spad_arbiter` CORE 端口；被接受请求的 owner 贯穿 ready、protection error 和 registered response。未接受 requester 不得看到响应或错误。 | requester 竞争和 ready 背压；按硬件接口的一周期注册响应检查地址/数据/错误只回到 owner，未接受 requester 无副作用。 |
| REQ-PC-007 | **Banked/Line 独立通道**：CNM 的四 Bank 请求与 Matrix banked/128-bit line 端口维持各自接口与响应归属，不得错误折叠进 32-bit owner MUX。 | 四 lane、banked read、line write/WSTRB 按各自 handshake monitor 校验。 |
| REQ-PC-008 | **SPAD 冲突责任**：硬件 MUX 只保证单端口 admission 和 owner 路由，不做跨 descriptor 地址锁或依赖推导；软件必须保证并发任务没有 read-after-write/write-after-read/write-after-write 冲突。共享只读输入可重叠。 | 正常并行 Reference 使用分离输出区；冲突输入属于违规软件流量，单独做健壮性观察。 |
| REQ-PC-009 | **Abort/Drain**：abort 后不再派发未接受的新 descriptor；所有已派发任务均收到 abort，已接受 SPAD 请求/响应按 owner 收尾；任务以 `ERR_ABORT` 或更早已发生的 Engine error 形成一次完成，按 CMDQ 顺序退休。调度器在所有 Engine 和完成项排空前不得报告 idle；未派发的 CMDQ descriptor 留给软件。 | 多 Engine active 时 abort；检查停止新 launch、SPAD owner 无泄漏、完成 FIFO 保序、idle/drain 和随后可恢复运行。 |
| REQ-PC-010 | **Reset 与恢复**：reset 清除 Engine 活动槽、结果 FIFO、SPAD owner pipeline 和未发布 completion；复位后旧 Done/响应不得污染新 task。若 AXI 外部读/写已接受，必须协调复位加速器与 owning fabric，fabric 丢弃旧 epoch R/B；accelerator-only reset 仅可在 DMA/AXI 通道空闲或已完成显式排空/隔离后执行。 | UVM 在已接受 AR 且 R 延迟时协调复位，检查 fabric read queue/active/RVALID 清空，并在 8 周期安静窗口检查无旧 R、新 AR；再检查 SPAD sentinel 未变及 reset 后新事务恢复。该测试不代表 B 通道或任意外部 fabric 实现的独立证明。 |

**v1.1/v1.2/v1.3/v1.4 Freeze Record**：v1.1 冻结 REQ-CL-001～028、REQ-PC-001～010、合法并行任务合同、SPAD owner 及按序 completion 行为；v1.2 冻结外部 AXI reset/fabric epoch 边界；v1.3 冻结 SFU 数值整数公式和约定输入域；v1.4 冻结 Compute Engine Error ABI、同周期优先级和可见写回前缀规则。SPEC 冻结不等于 UVM、coverage 或最终 Sign-off 已完成。现有 verification evidence 与未闭合项见 [Compute Cluster Testplan](../verification/COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md)、[Execution RTM](../verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) 和 [Verification Matrix](../../dv/VERIFICATION_MATRIX.md)。
