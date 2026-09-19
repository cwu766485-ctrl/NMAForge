# 面向边缘/数据中心推理的数字近存计算 AI 加速器（NMAForge）

**一句话概括：** 面向 CNN/Transformer 核心算子的 **AXI4/AXI-Lite 数字 CNM 加速器 RTL 原型**，通过片上多 bank SRAM、DMA 和 bank-local PE 降低外部内存访问开销并提升 INT8 张量计算效率。

**项目角色：** RTL 设计 / SoC 集成 / 设计验证（按个人实际负责范围调整）  
**技术栈：** **Verilog/SystemVerilog、AXI4、DMA、SRAM/Scratchpad、数字 CNM、UVM、SVA、VCS/Verdi、SpyGlass、Design Compiler、Vivado**

- **架构与 RTL：** 设计并集成 AXI-Lite 控制、命令/完成队列、**128-bit AXI4 DMA**、**512 KiB 四 bank Scratchpad** 和 INT8/CNN/Transformer 计算数据通路，形成从外部内存搬运、片上缓存到计算/写回的闭环。
- **核心亮点：** 通过 **四 bank 并行访问、bank-local partial-sum accumulation、operand prefetch 和 4×4 GEMM tile 复用**，在相同 INT8 MAC workload 下，使 GEMV 执行周期相对 scalar baseline **减少约 42%–49.5%（等效吞吐提升约 73%–98%，1.73×–1.98×）**；4×4 GEMM tile 执行周期**减少约 74.8%（等效吞吐提升约 297%，3.97×）**。
- **验证闭环：** 构建并运行 **Control UVM 6 项**、**DMA UVM 11 项**回归，覆盖 reset、AXI-Lite 协议、RAL、IRQ/error、1D/2D/gather、4 KiB boundary、乱序响应、abort 和 back-pressure；现有回归均为 **`UVM_ERROR=0`、`UVM_FATAL=0`**，top-level smoke 以 **`TEST PASS`** 结束。
- **实现与 PPA：** 在 **TSMC28 TT/0.9 V/25°C、4.0 ns pre-layout DC** 条件下，关键路径约 **3.89 ns**、setup/hold **无违例**，总 cell area 约 **1.245M library units**，使用 **32 个 SRAM macro**；功耗约 **24.8 mW** 为初步活动率估计，**不等同于 sign-off 数据**。

**项目状态：** 已完成主要功能 RTL 和验证基线，当前重点为 coverage closure、Formal/LEC、DFT、后布局 STA/IR/EM 及工作负载功耗分析。

> 简历使用建议：如果版面有限，保留“一句话概括”加前 3 个 bullet；将具体寄存器地址、descriptor 字段和完整 opcode 表留作面试展开内容。上面的“边缘/数据中心推理”是应用定位，不应表述为已有量产芯片或真实部署。
