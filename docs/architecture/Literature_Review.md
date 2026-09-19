# 文献综述：数字存内计算与高能效 AI 加速器

最后审阅日期：2026-09-13

## 范围与阅读规则

本文区分三个容易混淆的方面：

- **论文报告的结果**是被引芯片在其自身工艺、电压、活动率、工作负载和统计边界下给出的测量值与论断。
- **NMAForge 当前 RTL** 是一个可综合的数字近存计算（compute-near-memory，CNM）加速器，带有四 bank scratchpad。它不修改 SRAM bit-cell、bit-line 或 sense amplifier，因此**不是 SRAM 内数字存内计算（digital-CIM）宏**。
- **建议借鉴的经验**是未来设计方向，不是已实现的功能，也不是 NMAForge 已测得的 PPA 结果。

因此，以下 TOPS/W 或 TOPS/mm2 数值都不能在缺少统一实现和功耗测量方法的情况下用于描述或比较 NMAForge。

## 已审阅论文

| 编号 | 论文 | 回答的主要问题 |
| --- | --- | --- |
| [Wu25] | H. Wu *et al.*, "A 28-nm 19.9-to-258.5-TOPS/W 8b Digital Computing-in-Memory Processor With Two-Cycle Macro Featuring Winograd-Domain Convolution and Macro-Level Parallel Dual-Side Sparsity," *IEEE JSSC*, vol. 60, no. 1, Jan. 2025; DOI: 10.1109/JSSC.2024.3409356. | 数字-CIM 宏如何在支持 Winograd 卷积和宏级粗粒度稀疏调度的同时，减少 INT8 MAC 周期？ |
| [Chen17] | Y.-H. Chen, T. Krishna, J. S. Emer, and V. Sze, "Eyeriss: An Energy-Efficient Reconfigurable Accelerator for Deep Convolutional Neural Networks," *IEEE JSSC*, vol. 52, no. 1, Jan. 2017, pp. 127-138; DOI: 10.1109/JSSC.2016.2616357. | 数据流、局部存储和互连应如何协同降低 CNN 数据搬移？ |
| [Agarwal26] | A. Agarwal *et al.*, "A 147TOPS/W, 250TOPS/mm2, Fully Synthesizable, Digital Compute-in-Memory Accelerator Supporting INT8xINT8 with Zero-Point Quantization in Intel 18A Technology," *ISSCC 2026*, Session 30.9, pp. 528-529; DOI: 10.1109/ISSCC49663.2026.11409207. | 可移植的标准单元数字-CIM 组织能否在支持实际 INT8 零点量化的同时保持低电压能效？ |

本文中的所有技术论断均来自所提供的 PDF。引用标识原始出版物；它们不是针对 NMAForge 的外部 PPA 证据。

## 一页式比较

| 工作 | 架构思想 | 论文中的报告证据 | 对 NMAForge 可迁移的经验 |
| --- | --- | --- | --- |
| [Wu25] | 两周期 Radix-16 加 LUT 数字-CIM 宏；混合空间域/Winograd 数据流；宏级双侧稀疏（MDPS）。 | 28 nm 原型，0.6-1.1 V、78-287 MHz。论文报告 19.9-258.5 TOPS/W；其最佳 258.5 TOPS/W 点位于 0.6 V、116 MHz。 | 将算法、数据流和稀疏映射视为协同设计问题。对 NMAForge 而言，粗粒度 tile/row 工作跳过和经测量的 Winograd 路径，比照搬 CIM 宏电路更现实。 |
| [Chen17] | 在 PE 阵列上采用行驻留（row-stationary，RS）映射，四级存储层次，组播、压缩和数据门控。 | 168 个 PE、108 kB 全局缓冲区、PE 本地 scratchpad。针对 AlexNet，论文报告 278 mW 下 35 fps 和 0.0029 DRAM accesses/MAC；相对于未门控 PE，zero-ifmap 门控使 PE 功耗降低 45%。 | 同时优化并报告输入、权重和部分和的搬移。NMAForge 已有 banked scratchpad 和 DMA 计数器，因此在改变算术结构前即可将其可观测化。 |
| [Agarwal26] | 完全可综合的 DCIM，采用驻留、Booth 编码权重，128 个输入通道、32 个输出通道、两组权重以及内建零点展开。 | Intel 18A 测试芯片。在 1.1 V、25 C 下：2.62 GHz、21.5 TOPS、250 TOPS/mm2，面积 0.0856 mm2。在 400 mV、25 C 下：25% 输入活动率、6.1 mW 时达到 147 TOPS/W。 | 量化格式和权重更新路径是一级微架构问题。零点补偿和双缓冲驻留权重值得进行架构研究，而不是事后增加补丁式后处理。 |

## 论文摘要

### [Wu25] 28 nm 双周期数字 CIM、Winograd 与 MDPS

**实现内容。** 该处理器结合了三层优化：

1. Radix-16 加 LUT 的数字-CIM 宏在两个宏周期内完成一次 INT8 乘法。论文报告 LUT 优化使宏动态功耗降低 21.7%。
2. 混合数据流为 1x1 卷积和 GEMM 选择空间域执行，为 F(2,3) 和 F(4,3) 卷积使用 Winograd 域路径。论文报告其混合 Winograd 评估加速 2.59x，在所引用的比较中精度损失为 0.6%。
3. MDPS 使用激活掩码和宏粒度的水平权重压缩。其目标不是任意逐元素跳过，而是改善有效权重与固定 CIM 阵列的匹配，并减少激活输入周期。在激活和权重稀疏率均为 50% 时，论文报告加速 3.11x。在 ResNet34 评估中，论文报告能效提升 3.11x；该稀疏方法带来 4.5% 的面积开销和 7.8% 的功耗开销。

**意义。** 其有用思想是推理顺序：先以适配物理计算阵列的粒度减少工作量和搬移，再优化局部乘法电路。论文也明确展示了定点 Winograd 的权衡：F(4,3) 及更大的变换可以减少乘法次数，但除非完整量化流程经过验证，否则可能造成过大的 INT8 精度损失。

**应用限制。** [Wu25] 是采用专用宏、局部 SRAM 和专用映射模型的流片数字-CIM 处理器。NMAForge 是紧邻常规 scratchpad 的 bank-local 数字计算，而不是双周期 CIM bitcell/macro。其报告的能效排除了芯片 I/O 和 FPGA DRAM 功耗。因此，正确的借鉴对象是设计方法，而不是直接 PPA 比较，也不能据此声称 NMAForge 具有相同的 CIM 架构。

### [Chen17] Eyeriss 与行驻留数据流

**实现内容。** Eyeriss 将一维卷积原语映射到由 168 个 PE 组成的 12x14 阵列。其行驻留数据流平衡 ifmaps、filters 和 partial sums 的复用，而不是只优化某一个张量。该组织采用四级层次：DRAM、108 kB 全局缓冲区、PE-local scratchpads 和寄存器。可重构 NoC 提供组播和点到点传输；运行长度压缩和数据门控利用零值。

**意义。** 论文最持久的结论是：端到端能耗主要由数据搬移和存储行为决定，而不仅是乘法器数量。论文明确指出，仅统计芯片功耗不足以评估系统能耗。论文报告片上存储约占芯片面积的三分之二，而 PE 乘法器和加法器占 7.4%；这提醒我们，在扩大 MAC 阵列之前，应先研究 scratchpad 访问、bank 冲突和 DMA 流量。

**应用限制。** Eyeriss 是来自不同年代的 CNN 空间阵列设计，并未提供 Transformer/KV-cache 执行模型。其 RS 映射和组播 NoC 应作为 NMAForge 的 tile/dataflow 策略加以改造，而不应被照搬为必须新增的 NoC。

### [Agarwal26] 采用零点量化的完全可综合 DCIM

**实现内容。** 该 DCIM 具有 128 个输入通道、32 个输出通道和两组权重。权重在写入路径上驻留并预编码；计算使用选中的权重组，同时可以更新另一组。该组织使用四级流水线完成 128 路 MAC。激活在列之间广播，而依赖权重的工作被摊销或预计算。

论文处理了 INT8 加速器示例中经常省略的实际问题：非对称零点量化。直接将激活和权重零点相加，会使有符号 8b 计算实质上变成 9b 计算。其无符号到有符号的映射和预计算校正项保留 8b 有符号乘法，使部分积数量由五个减少到四个；据报告，在该设计中 DCIM 功耗降低 17%、面积降低 21%。论文还报告，相比激活编码，驻留权重 Booth 编码使计算功耗降低 28%，但面积增加 7%。

**意义。** “INT8”并不是完整的软件契约。有符号性、per-tensor/per-channel scale、zero-point、舍入、饱和以及校正项的生命周期，共同决定硬件 kernel 能否与真实量化模型互操作。论文还将权重加载/计算重叠作为微架构特性，而不是缓冲的偶然结果。

**应用限制。** 其 18A 标准单元/锁存器实现、电源点、输入活动率和计算阵列无法与 NMAForge 的通用 RTL 及 28 nm 版图前证据相比较。该结果支持研究可移植的数字近存数据通路；它并不能证明仅使用可综合 RTL 就能获得其面积或能效数值。

## NMAForge：已有的匹配点与不匹配点

### 现有架构匹配

NMAForge 已具备若干使这些经验可落地的基础：

- 四个 scratchpad bank，具有 bank-local CNM 地址生成、操作数缓冲、局部累加和输出级归约（`ai_banked_cnm_core` 以及四个 `ai_bank_local_controller` 实例）。
- 128-bit AXI DMA、tile load/compute/store 重叠，以及作为唯一 scheduler-side scratchpad admission point 的仲裁器。
- Scalar INT8、banked VDOT/GEMV、4x4 tensor matrix、convolution、SFU 和 KV-cache 原语。这支持面向 CNN 和 Transformer-style 工作负载的数据流研究，而不局限于 CNN。
- matrix cycles、active MAC cycles、banked stalls、DMA bytes、AXI requests 和 response stalls 的被动计数器。这为面向搬移的测量提供了可靠基线。

### 必须保留的边界

NMAForge 是**数字 CNM**，不是 [Wu25] 或 [Agarwal26] 中那类 DCIM 宏。其 SRAM 仍是 SRAM 实现，算术位于 bitcell/bitline/sense-amplifier 路径之外。公开文档和演示应保留这一界限。未来的物理 DCIM 探索需要 memory-macro/standard-cell-array 协同设计、新的 PPA 流程和功耗表征；不能从当前 RTL 推断出来。

## 建议的借鉴路线图

前两项可以用适度的架构风险换取证据和软件兼容性。其余项目是有意规划的功能工程，不应混入仅为提高可读性的 RTL 重构。

| 优先级 | 借鉴思想 | NMAForge 的具体方向  | 对 RTL/软件的主要影响 | 验收证据 |
| --- | --- | --- | --- | --- |
| P0 | Eyeriss：测量搬移，而不只测量计算 | 定义工作负载记分卡：MAC-active cycles、banked-stall cycles、DMA read/write bytes、scratchpad accesses 以及每个输出元素的端到端周期。仅将基于 SAIF/VCD 的功耗估算作为独立流程添加。 | 复用 `ai_perf_monitor`；只有在确认存在盲点时才增加计数器。先增加 benchmark 脚本/报告模板，不先改变数据通路。 | 在固定 CNN/GEMM/attention 工作负载下提供计数器快照、byte/MAC 和 cycle/MAC 表格以及可复现脚本。 |
| P1 | Eyeriss：数据流/局部复用 | 规定 bank-aware tile 映射策略。在完整复用窗口内将输入、权重和 partial sums 保留在 scratchpad 中；以现有 tile pipeline 和 line-buffer convolution 作为起点。 | 首先修改 descriptor/compiler 映射和测试；不意味着要新增 NoC。 | 在相同输出检查下比较基线映射与建议映射；报告 DMA bytes、bank-conflict stalls 和 cycles。 |
| P2 | Agarwal26：真实的非对称 INT8 | 增加版本化量化契约：激活/权重有符号性、zero-points、scale 以及舍入/饱和语义。在复用有收益的地方实现校正项。 | 影响 descriptor ABI、软件头文件、命令校验、INT8/matrix 数据通路、UVM/RAL 和 golden-model 测试。这是功能开发，而非内部重构。 | 提供覆盖非零 zero-points、溢出、负值、支持时的 per-channel 情形的定向向量，并与 bit-exact 参考模型比较。 |
| P3 | Agarwal26：驻留双缓冲权重 | 研究显式拥有的 weight-tile buffer：计算读取一个驻留 tile 的同时，DMA/loader 填充另一个 tile。不要假设当前 operand ping-pong buffer 已提供这种行为。 | 若 profiling 表明权重流量重要，则新增 weight-buffer 接口/所有权协议并修改 tile scheduler。 | 输出不变；在 back-pressure、abort 和 queue transitions 下证明重叠有效且无 stale-tile hazard。 |
| P4 | Wu25：粗粒度稀疏映射 | 从编译器生成的 tile/row mask 开始，只跳过已证明为零的完整工作单元。将元数据搬移和负载不均衡纳入测量。 | 扩展 descriptor 以及命令/tile 调度；避免在 MAC 关键路径中加入细粒度组合跳过逻辑。 | 同时报告 dense 和 sparse 等价性测试、zero-mask corner cases、元数据字节数、加速比和利用率。 |
| P5 | Wu25：Winograd | 从离线/软件 Winograd 变换和显式 descriptor layout 开始。尽可能使用现有 matrix/conv 原语。只有在精度和流量测量证明合理后，才增加片上变换。 | 影响软件 packer/参考模型、descriptor 格式、卷积/矩阵调度和数值回归。 | 先做 F(2,3)，再做 F(4,3)；比较 INT8 精度、变换 tile 带宽、延迟以及与空间卷积的输出。 |

## 应暂缓的决定

1. **不要给当前 IP 添加 “CIM” 标签。** CNM 是准确且可辩护的；DCIM 需要不同的物理实现论断。
2. **不要直接将细粒度非结构化稀疏性引入 PE 数据通路。** 元数据读取、bank 不均衡和控制切换可能抵消收益。应从粗粒度工作单元和经测量的工作负载稀疏性开始。
3. **不要在 INT8 数值研究之前硬编码 Winograd F(4,3)。** 该变换可能放大量化误差。F(2,3)、golden model 和经测量的数据搬移应作为准入门槛。
4. **不要比较不同论文的 headline TOPS/W。** 工艺节点、电压、温度、活动因子、工作负载、是否包含 I/O 以及 MAC/TOPS 统计方式都有实质差异。

## 建议的下一项实验

最高价值的下一项实验是**面向 bank-aware 的 Conv3x3 tile 映射研究**，而不是立即重写 CIM 宏：

1. 选择一个 Conv3x3 工作负载，记录当前 cycles、DMA bytes、banked stalls 和正确性。
2. 创建两个 descriptor/tile layout，在保持相同算术的同时改变 ifmaps、权重和 partial sums 的复用方式。
3. 使用现有性能计数器识别限制资源。
4. 只有当数据表明权重搬移占主导时，才原型化双缓冲 weight-tile 路径；只有当算术数量占主导且数值分析通过时，才评估软件 Winograd F(2,3)。

该顺序落实了这些论文共同的最强原则：在专门化局部算术之前，先改善局部性，并测量完整数据流。
