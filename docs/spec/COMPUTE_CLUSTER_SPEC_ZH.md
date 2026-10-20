# NMAForge Compute Cluster 功能与接口规格（中文）

> **文档编号**：NMA-CL-SPEC-001  
> **版本**：v0.1，Design/DV Review 初稿（**未签核**）  
> **日期**：2026-10-20  
> **基线**：NMAForge main commit ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc，A10 / ABI v7.4  
> **设计模块**：rtl/top/fabric/compute/ai_accel_compute_cluster.v  
> **目的**：约束 Compute Cluster 的功能、时序、对外端口和异常处理，作为 UVM Testplan / Scoreboard / Coverage / SVA 的需求来源。

## 0. 规范用语及适用范围

- **[AS-IS]** 表示已经在指定 RTL 或产品规格中核实的当前行为。
- **[REQ]** 表示计划约定的设计/集成行为，应经过 Review 后成为 Pass/Fail 标准；**不能仅因本文写入就假定 RTL 已满足**。
- **[OPEN]** 表示未得到统一规范、需要进一步确认或修正的差异。
- 此文档的 DUT 本体只包括 **ai_accel_compute_cluster** 与内部七类计算核心；顶层 Opcode Decode、普通 Compute Request MUX、SPAD Arbiter、Scratchpad、DMA、AXI、Descriptor Validator、Command Processor 和 Completion Writer 均属于上层/外围。
- **推荐 Subsystem DV 边界**是 Cluster + 与实际顶层等价的 Compute Request MUX/Response Routing + 真实 SPAD Arbiter + 四 Bank 行为 SRAM。仅测 Cluster 裸模块不能证明真实 SPAD 仲裁无误。
- 本 SPEC 不声称其为完整 NPU、并行七发射、Systolic Array 或完整 RISC-V Vector FP ALU。

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

**[REQ-CL-001]** 上层只在 Cluster Idle、Opcode 有效、参数合法时发起一个任务。  
**[REQ-CL-002]** 每次正常启动恰好选择一个 Engine；Opcode Decode 与 Engine Select 必须一致。  
**[REQ-CL-003]** 启动采样边界，launch 参数稳定且有效，完成前不得发生未定义的任务切换。  
**[OPEN-CL-001]** Busy 时再次 Start、多个 Select 同时有效、FP Opcode 与其它 Select 冲突时，当前 Cluster 未统一防护。需确认是**明确禁止的环境输入**还是需要 RTL 拒绝/报错；在冻结合同前不能把对应 Negative Tests 自动归为 DUT Bug。

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

**[REQ-CL-004]** 各 Engine 只使用其 Opcode 定义的有效字段；无关字段变化不能改变正在执行的任务。  
**[REQ-CL-005]** 任务接受后，必需的地址/尺寸/格式等参数在该 Engine 内部正确锁存；运行中上游参数变化不得污染在途任务。  
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

**[AS-IS]** 顶层 ai_accel_top.v 的普通 Compute Request MUX 优先级为：

**fp_busy > conv_busy > kv_busy > matrix_busy > sfu_busy > banked_busy > scalar（默认）**。

该 MUX **位于 Cluster 外**。不能将七个请求端口理解为七个同周期独立完成的物理 SRAM 接口。

**[REQ-CL-006]** 请求在未接受时必须按照所属 Engine/接口的规定保持有效字段稳定；合法 Abort/Reset 例外需另定义。  
**[REQ-CL-007]** 读响应的 data/error 必须只由拥有该已接受请求的 Engine 消费；**core_rsp_valid 不是需要 ready 二次接受的 AXI R 通道**。  
**[REQ-CL-008]** 每一个合法接受的写事务，其地址、数据、数量和最终 Memory Image 与算子 Reference Model 一致；对于多输出算子，错误前可能存在已提交的合法前缀写入。  
**[OPEN-CL-003]** 非 FP Engine 的 Outstanding 上限、响应延迟/顺序、Abort 时已接受响应的处理和复位边界需要与实际 SPAD 子系统协议逐一确认。

### 2.4 CNM 四 Bank 专用端口

| 功能 | 真实端口 |
|---|---|
| 请求/Grant | **cnm_read_valid[3:0]**；**cnm_read_addr0..3[31:0]**；**arb_cnm_ready[3:0]** |
| 各 Bank 注册响应 | **cnm_rsp_valid[3:0]**；**cnm_data0..3[31:0]**；**cnm_parity[3:0]** |
| 错误 | **cnm_protection_error** |

**[REQ-CL-009]** 四个 Bank 的请求接受、响应和 Parity 归属必须对应各自 Lane；不能以单个总 ready/rsp_valid 代替。CNM 计算完毕后经普通 Banked Result SPAD 输出写回。

### 2.5 Matrix Banked 与 Line 接口

| 功能 | 真实端口 |
|---|---|
| Matrix Banked Read | **matrix_banked_read_valid**, **matrix_banked_read_addr[31:0]**, **arb_banked_ready**, **banked_rsp_valid**, **banked_data0..3**, **banked_parity[3:0]**, **banked_protection_error** |
| Matrix 128-bit Line | **matrix_line_valid**, **matrix_line_write**, **matrix_line_addr[31:0]**, **matrix_line_wdata[127:0]**, **matrix_line_wstrb[15:0]**, **arb_core_line_ready**, **line_prot_error**, **spad_line_raw_error** |

**[REQ-CL-010]** Banked 读取、普通 32-bit 请求、128-bit Line 写回分别使用其对应握手规则、保护判断和数据比对；Line Byte Strobe 为独立的 16-bit 检查对象。  
**[OPEN-CL-004]** Line 接口有效 strobe、地址对齐及部分写入的精确规则，待 Matrix + SPAD 集成 Review 后冻结。

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

**[AS-IS]** 完成属性 MUX 的选择优先级：

**FP > Conv > KV > Matrix > SFU > CNM > Scalar**（由各路 **done** 控制）。

**[REQ-CL-011]** 正常单任务契约下，同一周期最多一个 Engine Done；不能让 OR 后的 core_done 代表两项独立完成。  
**[REQ-CL-012]** 当 core_done 有效时，core_result/error/error_code/counters 必须来自**唯一的合法完成 Engine**；其他周期这些字段不保证存在新的有效任务结果。  
**[REQ-CL-013]** 对每个合法任务只能报告一次完成，不得出现丢完成、重复完成、错误的 owner 或错误码串用。  
**[OPEN-CL-005]** 各引擎 Done 脉冲长度、Done 和 Busy 同拍关系、Busy→下一个 Start 的最短交接周期，应通过波形 Review 明确；当前不可无证据宣布所有 Engine 具有完全一致的 Done 时序。

## 3. 算子与结果数据的基本语义

### 3.1 Scalar INT8：VDOT/GEMV/GEMM 与 Legacy Conv

- 32-bit SPAD word 含 4 个 signed INT8 lane；Dot4 按有符号乘法累加。
- 检查输入符号扩展、K words、输出条数、Bias、右移、ReLU/ReLU6、饱和及写回地址。
- **[OPEN-NUM-01]** 每个 Opcode 的逐位舍入/截断、先后处理顺序、溢出边界须补 Numeric Appendix。

### 3.2 CNM：Bank-Local PE 与 Global Reduction

- 四个独立 Bank-Local Controller；各自生成 A/B 请求、保留局部累加，随后 Global Reduction 得最终结果。
- **length 的单位是完整 packed dot4 word**，并非单字节元素；该接口没有 byte-tail/lane-mask。
- 重点检查四路 Bank 地址、Prefetch、每路 Response/Parity、局部/全局累加、背压与恢复。

### 3.3 Matrix：4×4 INT8 Engine

- 16 路 MAC 计算；M、N 以 4 为 tile 粒度，launch_k 是 K/4 的 **word 数**。
- 输入采用 Matrix 特有 Tile-major 布局；支持 Transpose A/B、Batch Stride、Bias、Requant、Activation。
- 检查行列索引、Batch、极值饱和、SPAD Banked/Line 通路、Partial Sum、尾 Tile 合法性。

### 3.4 Tensor SFU：0x32–0x39

- 实现定点 Softmax / Causal Softmax / RMSNorm / LayerNorm / Residual / GELU / SiLU / Requant。
- 例如 Softmax 使用 Q8.8 log2-domain 分数与 Q0.15 概率表示；GELU/SiLU 采用 Q8.8 有界近似；requant 可使用 launch_flags[4] 打包 4×INT8。
- 不能用 Python double 精度数学函数的结果直接要求硬件逐位相同。
- **[OPEN-NUM-02]** 需要为每个 SFU Opcode 明确 Q 格式、近似分段、溢出/舍入规则、数值误差界与 divide-by-zero 表现。

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

1. 上层确保 opcode/参数有效，Cluster 无正在执行的任务。
2. core_start 采样后唯一 Engine 接受启动，并锁存所需 launch 字段。
3. Engine 通过适当 SPAD 端口读数据，受 Ready 和 Response 延迟影响；执行运算并写入结果。
4. 对应 Engine 给出 Done/Error/Result，Cluster 将唯一 Owner 的结果交给 Command Processor。
5. Command Processor 才负责生成 Completion/IRQ（**不属于 Cluster 本体**）。

**[REQ-CL-014]** 未接受的 SPAD 请求不能当成完成；在合法环境进展/Watchdog 假设下，没有无限等待或幽灵事务。  
**[REQ-CL-015]** 正常返回成功的任务必须保持数值/地址正确和 exactly-once Done/有效写回。  
**[REQ-CL-016]** 相邻两个不同 Engine 的任务之间，不得把上个任务迟到的 Response 或 Done 错归给下一个任务。

### 4.2 Abort/Watchdog/Parity/Protection/Reset

**[AS-IS]** 七个引擎分别实现 Abort、超时和 SPAD 错误响应；Cluster 没有统一异常 FSM。

**[REQ-CL-017]** 错误码与 Result 归属必须来自当前 Engine；发生错误后的内存写入必须符合该 Opcode 已提交前缀的规则。  
**[REQ-CL-018]** Reset 后无新任务不得出现旧任务 Done/写请求；已接受存储读请求的 Drain/Discard 语义需按 Cluster+SPAD Subsystem 单独审查。  
**[REQ-CL-019]** 不允许未验证的 Abort/Reset 同拍组合破坏新任务、泄漏旧任务结果。  
**[OPEN-CL-006，P0]** 当前各 Engine 的 **error_code 编码不完全一致**：Conv 中 ERR_SPAD=4、ERR_WATCHDOG=7，KV 中 ERR_SPAD=4 且 ERR_WATCHDOG=4，而 FP/Matrix/CNM 等通常将 Watchdog 设为 4、Parity 为 5、Protection 为 6。必须先确认是保留 Engine-specific 编码，还是统一产品 ABI；不能直接把所有 Engine 错误码统一写死到一个 Scoreboard。  
**[OPEN-CL-007，P1]** Abort 与 Parity/Protection/Watchdog 同周期发生时，各 Engine 的优先级及在途读排空策略需要逐个冻结，不应在没有规格依据时随意判错。

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

**注意**：上述是新 Compute Cluster DV 的**规划**，并不是仓库中已完成的 UVM Testcase 名称。正式 Testplan 必须将每个已冻结 Requirement 映射到 **Sequence → Monitor/Scoreboard/SVA → Coverpoint → Test Log**。

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

应优先复用已有 **dv/block/compute/fp/** 的 UVM 和 Python 数值模型、**dv/subsystem/dma_spad/** 中的 CNM/SPAD 检查，以及 Matrix/CNN-KV Directed Bench；当前 **dv/subsystem/tensor_datapath/** 仍主要是结构骨架，不能说已具有完整 Compute Cluster UVM。

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
| OPEN-CL-001 | P0 | Busy 时新 Start、多 Select 同时高，是上游禁止还是 Cluster 自行拒绝？ | 非法场景没有可信 Oracle |
| OPEN-CL-005 | P0 | Done 与 Busy 时序、Done 与下个 Start 同周期的规则是什么？ | 生命周期 Scoreboard 可能误判 |
| OPEN-CL-006 | P0 | Conv/KV 的 ERR_SPAD 与 Watchdog 编码如何与 Completion ABI 统一？ | 错误码 Golden 不一致 |
| OPEN-CL-003 | P0 | 各类 SPAD Read 的 Ordering、Outstanding、Abort/Reset Drain 具体合同是什么？ | Response Ownership 无法完整判断 |
| OPEN-CL-002 | P1 | 每个 Opcode 的参数合法边界、地址别名/越界、零值规则是什么？ | 数值/地址 Reference 缺口 |
| OPEN-CL-004 | P1 | Matrix Line 接口 WSTRB、对齐、Protection 的完整规则是什么？ | 128-bit Line Checker 误判 |
| OPEN-CL-007 | P1 | 多错误同周期优先级和部分写回是否有一致语义？ | Fault/Reset Cross 无法严格闭环 |
| SFU-NUM-01 | P1 | SFU 近似函数、Q 格式和定点舍入的 Golden Contract 怎么冻结？ | SFU Bit-exact 不可重复 |

## 7. 仓库基线及引用文件

- [Compute Cluster RTL](https://github.com/cwu766485-ctrl/NMAForge/blob/ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc/rtl/top/fabric/compute/ai_accel_compute_cluster.v)
- [NPU Top 集成、普通请求选择及保护](https://github.com/cwu766485-ctrl/NMAForge/blob/ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc/rtl/top/ai_accel_top.v)
- [Opcode Decode](https://github.com/cwu766485-ctrl/NMAForge/blob/ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc/rtl/control/descriptor/ai_accel_opcode_decode.v)
- [全局中文 SPEC](https://github.com/cwu766485-ctrl/NMAForge/blob/ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc/docs/spec/SPEC_ZH.md)
- [FP 数值与访存详细 SPEC](https://github.com/cwu766485-ctrl/NMAForge/blob/ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc/docs/spec/FP_EXTENSION_SPEC_ZH.md)
- [DV Verification Matrix](https://github.com/cwu766485-ctrl/NMAForge/blob/ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc/dv/VERIFICATION_MATRIX.md)
- [A10 Verification RTM / Closure Status](https://github.com/cwu766485-ctrl/NMAForge/blob/ff1e3bb1b8d11b8db637ac6b25f3fb3f973b01bc/docs/verification/A10_DV_RTM.md)

**建议 v0.2**：先确认 P0 开放项，再补充：(1) 每 Opcode 数值/布局 Appendix，(2) Cluster-SPAD 时序波形 Appendix，(3) Requirement→Test→Coverage 的正式验证表。**本 v0.1 属于待 Review 规格初稿，绝非已经完成验证的声明。**
