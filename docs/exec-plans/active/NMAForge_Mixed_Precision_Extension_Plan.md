# NMAForge Mixed-Precision Extension — Design & Verification Execution Plan

> **版本**：v1.4 · 2026-10-14
> **项目**：NMAForge — AXI4 Near-Memory Tensor Accelerator
> **目标定位**：可集成至 RISC-V/通用 CPU SoC 的独立 AI Accelerator IP；同时形成可审查的 **Digital IC Design** 和 **Design Verification (DV)** 项目成果。
> **本文性质**：执行计划与状态记录。G0/G1/G2 的完成项均附可复现证据；G3 已开始，但仍未闭合。所有性能、覆盖率、PPA 均须用运行证据证明。

---

## 0. 决策摘要（先读）

**唯一主线：在现有 NMAForge 上新增自研 BF16/FP16 混合精度计算能力，并完成 Block → Subsystem → Top-level 的可复现验证闭环。** 不新开第二个重复的 AI 加速器项目，也不将 NMAForge 强行改为 CPU 内部 ALU，更不以独立芯片 Tapeout 作为本轮目标。

- **P0 / 当前已实现**：A8/A9 兼容行为保留；`0x50 BF16_DOT_ACC_FP32` 不变，A10 新增 `0x51 FP16_DOT_ACC_FP32`，两者共用混合精度 dot 核、command/SPAD/completion 路径。最新 mixed-dot UVM 使用 seeds `712345/987654/20261014`，每格式 256 个随机向量并合并 URG；每 seed 582/582 scoreboard PASS、UVM warning/error/fatal 为 0，numeric/fault-reset functional coverage 均 100%。DUT line/condition/branch/FSM 为 97.96%/96.50%/92.86%/71.43%；非法状态注入通过，残余 code-coverage outcomes 已逐项按 RTL/协议 disposition（未做形式不可达证明）。top smoke 包含 DDR→SPAD→FP→SPAD→DDR。FP core 保持最多两笔 outstanding-read 契约；双 pair-slot 使 64-element core microbench 从 259 降至 101 cycles。端到端 benchmark 现在在三 tile ping-pong 时同时随机化 RVALID 响应间隔与 WREADY backpressure，24/24 BF16/FP16 测点通过；1024-element job 的吞吐约为 0.571 MAC/job-cycle。结果和等待统计见 [`MIXED_PRECISION_THROUGHPUT_PPA_ZH.md`](../../verification/MIXED_PRECISION_THROUGHPUT_PPA_ZH.md)。随机 AXI error injection、DMA/SPAD subsystem UVM、top-level random UVM、2.5 ns/400 MHz 和更真实 power characterization 仍开放。
- **P1 / 建议完成**：优先完成随机 AXI error injection、DMA/SPAD 多客户端 subsystem UVM scoreboard/coverage，再扩展 top-level random descriptor UVM；使用数据决定是否开展 2/4 输出并行，只有确认供数/算力瓶颈后才投入 lane 扩展。随后做同约束 DC/Vivado PPA 及可复现 error/mutation testing。
- **P2 / 可选展示**：RISC-V SoC 上 AXI-Lite 裸机控制 + DMA 端到端 Demo；FP32 更完整的运算/异常标志；FMA 融合舍入；FPGA 板级实测；更大规模 CNN/Transformer workload。
- **停止增加功能的硬条件**：只要 P0 Block DV 仍有未解释失败，或旧 INT8/AXI 回归被破坏，不新增 Lane、算子和 CPU 集成。

### 与 RACE LaneFAdd 的关系

RACE LaneFAdd 仅作为**架构、接口和浮点 corner-case 验证思路的参考**。其仓库公开了 CIRCT/FIRRTL 生成的 RTL，但在本次检查中未确认明确的仓库级再分发许可证；在获得授权前，**不要复制其 RTL 或参考模型到 NMAForge**。本计划的核心 BF16/FP16 RTL、golden model、testbench 要自行设计或采用许可明确的第三方组件并正确署名。

---

## 1. 当前 NMAForge 基线与缺口

**2026-10-14 执行状态**：G0–G2 及 A10 FP16 dot RTL 集成已完成；G3 的 FP block UVM/code-coverage disposition、top smoke、seeded regression 与 DMA/SPAD contention profiling 已有 PASS 证据。A10 `VERSION=0x1000000a`、ABI 7.4、`CAP2=0xff`；`0x50` 仍为 BF16 dot，`0x51` 为 FP16 dot。最新 mixed-dot UVM 使用 seeds `712345/987654/20261014` 与每格式 256 个随机向量，每 seed 582/582 scoreboard PASS、UVM warning/error/fatal 为 0，URG merge 成功；DUT line/condition/branch/FSM 为 97.96%/96.50%/92.86%/71.43%，非法状态 default 已 fault-inject，剩余 outcomes 已逐项 RTL/协议 disposition（非形式证明）。Top benchmark 已覆盖 seed-controlled RVALID response interval 与 WREADY backpressure；随机 AXI error injection、DMA/SPAD subsystem UVM 和 top UVM coverage 仍开放。完整门槛与争用数据见下方“真实 DMA/SPAD 争用 profiling 增补”。所有结果限定为 Rocky-8.10 WSL / VCS V-2023.12-SP1 的本工作区运行，不代表 clean checkout。

**审查快照**：GitHub `main` commit `fbaa525512b527e4d8c87bbdda683208f9f757b0`（2026-10-12 查询）；冻结施工分支时需再次核实该 commit 是否仍为基线。

**G0/G1 历史证据**：G0 的 DMA UVM 11/11、Control UVM 6/6、top smoke 和独立 raw-bit model 16/16 记录见 [`FP_G0_BASELINE.md`](FP_G0_BASELINE.md)。G1 算术 block 报告分别见 [`FP_G1_MULTIPLIER_REPORT.md`](FP_G1_MULTIPLIER_REPORT.md)、[`FP_G1_FP32_ADDER_REPORT.md`](FP_G1_FP32_ADDER_REPORT.md)、[`FP_G1_FP32_ACCUMULATOR_REPORT.md`](FP_G1_FP32_ACCUMULATOR_REPORT.md)、[`FP_G1_ADDSUB_REPORT.md`](FP_G1_ADDSUB_REPORT.md) 和 [`FP_G1_COVERAGE_REVIEW.md`](FP_G1_COVERAGE_REVIEW.md)。上述阶段已闭合；定向类别审查不等于 URG/code coverage closure，后者仍属 G3。

| 范围 | 仓库已有 | 本轮尚需补齐 |
|---|---|---|
| 架构 | AXI4-Lite/AXI4、512 KiB SPAD、CMDQ/CPLQ、INT8/CNM/matrix/SFU、BF16 `0x50` 与 FP16 `0x51` dot queue/direct 路径 | 更广泛的 FP subsystem stress 和 FP PPA |
| 设计语言 | G0/G1 FP arithmetic blocks 与 G2 command-to-SPAD integration RTL | 后续扩展算子/lane 需另立范围 |
| Block / command-path DV | BF16/FP16 arithmetic block、mixed-dot 3-seed UVM/URG（256 随机向量/格式/seed）、DMA UVM 11 项、control UVM 6 项与 CDC command-path regression已运行 PASS | 随机 AXI error injection、DMA/SPAD 与更广泛 FP subsystem stress（G3） |
| Top-level DV | A10 `ai_smoke`、20-case seeded run、FP16 DDR→SPAD→FP→SPAD→DDR，以及三 tile randomized-RVALID/WREADY DMA/FP contention benchmark 均 PASS | compact AXI memory model 不代表 DDR PHY/board；尚缺随机 AXI error stress 和 top-level UVM coverage closure |
| 实现 | 4.0 ns pre-layout DC 已有基线/候选同约束比较 | 2.5 ns/400 MHz 与 2.4 ns sweep 未运行；不能沿用旧版结果宣称达标 |

**G3 未闭合边界（2026-10-14 更新）**：FP16 的 directed top-smoke 已验证 DDR→DMA→SPAD→queued FP16 dot→SPAD→DMA→DDR；mixed BF16/FP16 UVM 三 seed 回归每 seed 582/582（536 数值 + 46 fault/reset），URG 合并与功能覆盖通过。DUT line/condition/branch/FSM 为 97.96%/96.50%/92.86%/71.43%；非法状态 default 已注入，残余 outcome 已逐项 RTL/协议 disposition（未做形式不可达证明）。本日顶层 benchmark 对 3-tile ping-pong workload seed-randomizes AXI RVALID response gap 与 WREADY，并通过 24/24 测点；随机 AXI error injection、随机 DMA/SPAD subsystem UVM 及 top UVM coverage 仍开放。行为级 DDR 模型不代表 DDR PHY/板级带宽。4.0 ns 新 FP PPA 为 pre-layout 对比且 SAIF 有未注释对象，2.5 ns/400 MHz sweep 仍未完成。旧 DMA 文档中的 **67.86%** command functional coverage 不是 FP closure 证据。

**现有关键路径与约束**：`rtl/top/ai_accel_top.v` 是源事实；`ai_spad_arbiter` 是 scratchpad 调度侧**唯一仲裁入口**。新模块不得绕过其规则在顶层新增直连 SRAM 的私有旁路。

---

## 2. 项目最终结构与边界

```text
                      RISC-V / Host CPU （集成阶段可选）
                             │ AXI4-Lite / IRQ
                      CMDQ / Descriptor Engine
                             │ launch / abort / completion
          DDR ⇄ AXI4 DMA ⇄ Scratchpad Arbiter ⇄ 4-bank SRAM
                                             │
                        ┌────────────────────┴───────────────────┐
                        │                                        │
                  Existing INT8/CNM                        NEW Mixed FP
                    / Matrix / SFU                         Engine (self RTL)
                                                              │
                                               BF16/FP16 Add/Sub Block
                                               BF16 Multiply + FP32 ACC
                                               Issue/Buffer/Writeback
                        └────────────────────┬───────────────────┘
                                             │
                                      Result to SPAD
                                             │
                                   Completion / IRQ / DMA
```

**项目定义**：可综合、可作为独立 IP 接入 SoC 的混合精度加速器，而非完整 RISC-V CPU/GPU/独立芯片。

### 本轮不做什么

1. 不实现完整 RISC-V Vector ISA（RVV），只新增明确列出的计算 opcode。
2. 不把旧定点 SFU 宣称为浮点 Softmax、浮点 Tensor Core 或生产级 LLM 推理引擎。
3. 不将“4 bank”直接等同于“4 路计算每周期持续满吞吐”；真实吞吐受 SRAM 读端口、地址/数据供给、仲裁及写回限制。
4. 不把本轮 pre-layout synthesis、单 PVT corner 和 smoke test 称为流片 sign-off。

---

## 3. 规格冻结：最重要的架构决策

> **G0 门禁：没冻结这些决策之前不开始 RTL 扩展。** 任何变更先改 SPEC，再同步更新 RTL、软件头文件、golden 和测试计划。

### 3.1 数值规范（FP contract）

| 属性 | P0 选择 | 说明 |
|---|---|---|
| 输入格式 | BF16、FP16 | 两种 16-bit 格式均用 raw bits 传入；BF16 8 位 exponent / 7 位 fraction；FP16 5/10 |
| 输出格式 | FP16/BF16 算术输出；累加输出 FP32 | **分别**定义指令的输出和 Scratchpad 存储布局 |
| 主要计算 | 加/减；BF16×BF16 与 FP32 累加 | 真正用于 AI 计算的关键是 multiply-accumulate，而非仅浮点加法 |
| 舍入 | 初版只支持 RNE | Round to nearest, ties to even；覆盖 ties、溢出、下溢 |
| 累加语义 | **P0 明确采用非融合**：每次乘法转 FP32，再按 FP32 舍入累加 | 若日后改为 fused FMA，必须另设 opcode/模式并更改参考模型，**不能混用** |
| 特殊值 | ±0、normal、subnormal、±Inf、qNaN、sNaN 输入 | qNaN/sNaN 输入均生成规范 qNaN；P0 不输出 flags；**不能简单认为 ±0 所有情况等价** |
| 异常标志 | P0 明确记录不支持/不输出哪些 IEEE 754 flags | 切忌默认沿用 RACE 的宽松 NaN/fflags 验证约定而称“IEEE 完整符合” |
| 数据布局 | 32-bit SRAM word 存 2×BF16/FP16，FP32 acc 独占 32-bit | 端序、mask、tail、stride、base alignment 全部明文规定 |

**性能策略与当前状态**：当前单输出 dot 保持逐元素顺序乘积/累加，但用两个 A/B word-pair 缓冲槽预取，最多两笔 outstanding read 与计算重叠；64 元素固定双周期 SPAD 响应微基准从 259 降到 101 cycles。此结果不是 DDR/arbiter 下的系统吞吐；先跑 2.5 ns 时序与真实 DMA/SPAD contention profiling，再决定是否做多输出/多 lane。单个 dot 的严格累加顺序不能拆成 parallel partial sums；已有 SRAM 为单端口 macro 的物理映射，也不可假设同一 Bank 每周期可自由提供两次独立读取。

### 3.2 ABI / Opcode 策略

旧项目使用 **A8 / ABI v7.2**（固定 64B descriptor、16B completion）。为避免破坏现有软件，**先选择兼容扩展方案**：

1. 历史 A8 opcode 范围到 `0x44`；A9 曾交付 **`0x50 = BF16_DOT_ACC_FP32`**，ABI 7.3 与 `CAP2[6]`。当前 A10 保留 `0x50`，新增 **`0x51 = FP16_DOT_ACC_FP32`**，ABI 7.4 与 `CAP2[7]`；BF16/FP16 Add/Sub 仍只是独立 block，没有产品 opcode 分配。
2. 优先复用 descriptor 的现有 `src0/src1/dst/length/m/n/k/stride/flags` 字段；无法清晰表达的语义**不得隐式复用**，应明确提出 ABI 小版本变更及兼容策略。
3. `ai_command_processor`：opcode decode、descriptor validation、计算启动、abort、completion、error code；`ai_accel_compute_cluster`：FP 路径选择、busy/done/error 汇总；软件头文件、寄存器 capability/version 同步更新。现有 cluster 的标量 INT8 `start` 是“排除其他已知引擎后的默认分支”，加入 `0x50` 时必须显式把 FP opcode 排除，避免同时误启动 INT8。
4. 原 INT8/CNM、矩阵和定点 SFU 的数值/性能行为必须保持向后兼容。若需要改动现有地址映射，先出 ABI migration note。

### 3.3 资源与接口设计

**P0 单通道可综合接口契约**（建议形式，字段以最终 SPEC 为准）：

```systemverilog
// 示例契约，不是已实现代码
// Accepted input = in_valid && in_ready
// Accepted output = out_valid && out_ready
// 每个已接收的非 abort 事务，最终恰好产生一个结果
// ID 用于结果归因，不允许在 reset/abort 后错误复用旧事务
```

架构需要写明：input/output handshake、FIFO 深度、数据有效掩码、事务 ID、reset/abort/drain、计算异常处理、源/目的 buffer 所有权、latency 和吞吐上界。**FP Core 的 `ready`、pipeline stall、output buffer 必须由我们自行正确设计，不得默认原 RACE LaneFAdd 可以暂停。**

---

## 4. 建议的实现文件与模块分工

新路径建议在 NMAForge 的现有层次下创建；**最终文件名以项目编码风格检查后冻结**。

```text
rtl/compute/fp/
  fp_format_pkg.sv                 # FP format / opcode / rounding definitions
  fp16_bf16_unpack.sv             # 分类/解包/特殊值
  fp_addsub_core.sv                # 对阶、加减、规格化、舍入
  bf16_mul_fp32.sv                 # BF16 乘法与 FP32 表达
  fp32_accumulator.sv             # 非融合、逐步 FP32 舍入累加
  fp_compute_engine.sv            # 唯一 FSM owner / accepted transaction / abort
  fp_spad_adapter.sv              # A/B 顺序读取、响应归属与写回缓冲

rtl/top/fabric/compute/
  ai_accel_compute_cluster.v      # 集成 FP 子系统（修改现有）
rtl/control/queue/
  ai_command_processor.v          # opcode/launch/error 生命周期（修改现有）
sw/include/
  cimforge_regs.h                 # ABI/opcodes/capability（修改现有）

dv/block/compute/fp/
  spec/FP_VERIFICATION_SPEC.md
  agent/ env/ model/ tb/ tests/ assertions/ sim/

dv/subsystem/fp_spad_dma/
  ref/ tb/ tests/ assertions/ sim/

docs/extension/
  FP_ARCHITECTURE.md
  FP_EXTENSION_SPEC_ZH.md             # 数值、descriptor 与 ABI 规范（G0 草案）
  FP_TESTPLAN.md
  FP_PPA_COMPARISON.md
  FP_BUG_REPORTS.md
```

**重用优先**：现有 AXI4 DMA agent、AXI-Lite RAL、行为 DDR、SPAD 访问模型、SVA、VCS 脚本；不再复制一份与项目其余部分脱节的验证框架。

---

## 5. 按阶段推进（建议 16–20 周，每周约 10–15 小时）

时间为规划基准，不是完成承诺。每阶段需要通过 gate，才能进入下一阶段。

| 阶段 | 周次 | 必须交付 | Exit Criteria（必须证明） |
|---|---:|---|---|
| **G0 Baseline & Spec — 已闭合** | W1–2 | 基线回归、冻结 FP numeric/ABI spec、SPAD 时序/带宽预算、raw-bit vectors | dirty worktree 上 DMA 11/11、Control 6/6、top smoke、reference model 16/16；证据见 G0 报告 |
| **G1 FP Block Design — 已闭合** | W3–5 | BF16 Mul→FP32 ACC、FP32 adder/accumulator、BF16/FP16 Add/Sub blocks | Raw-bit 回归、directed review、SVA 与 FP-only lint evidence 已记录；URG/code coverage 留 G3 |
| **G2 首个 opcode 集成 — 已闭合（片上预加载 SPAD 范围）** | W6–9 | `0x50` queue/direct-register dispatch、FP compute cluster、SPAD 读写、completion/abort commit point | 下列四项 VCS gates PASS；BF16 结果、非法请求、旧 Transformer/random 与 command path 检查通过；未覆盖 DDR 端到端 |
| **G3 DV 与 PPA 扩展 — 未闭合** | W10–18 | DDR→SPAD→FP→SPAD→DDR、UVM/URG coverage、独立数值/事务 oracle、同约束新增 FP PPA 与带宽实验 | 逐地址一致、关键 bins/multi-seed closure 和受控 PPA 均需独立证据；本轮不声称 G3 通过 |
| **Optional SoC/FPGA** | W19–20+ | RISC-V bare-metal driver、AXI-Lite+IRQ/FPGA Demo | 非必选；必须有真实仿真或板级日志才可列在简历 |

### G0 — 基线检查（开工第一天）

```bash
# 在已配置 Linux/VCS 的工程环境使用；不要把这些命令当作本机已运行证据
# 1. 获取并固定审查快照（如继续使用新 HEAD，要重新记录新的 SHA）
git clone https://github.com/cwu766485-ctrl/NMAForge.git
cd NMAForge
git rev-parse HEAD
# 2. 在单独分支开发；不覆盖原有 main
# git switch -c feature/mixed-precision-fp

# 3. 原有回归（必须拥有 VCS license/工具环境）
cd dv/block/dma/sim && make uvm_regress
cd ../../control/sim && make uvm_regress
cd ../../../subsystem/top_smoke/sim && make ai_smoke
```

> 命令以仓库当前 Makefile 为依据；目录切换容易出错，建议**每个命令单独从仓库根目录**使用 `make -C`，例如 `make -C dv/block/dma/sim uvm_regress`，并保留日志/seed/commit。若 license 不足，须记录为工具限制，不得标为 DUT 通过或失败。

**第一份产物 `BASELINE.md` 必须包含**：实际 commit、工具版本、17 项 UVM 原有回归结果、top smoke、已知 warn/fail、静态约束与覆盖率缺口。已有文档的“PASS”是历史证据，不能替代这次重跑。

### G1 — 单路算术块设计与验收

- Add/Sub 需要明确：unpack → exponent alignment → signed significand op → normalization → GRS rounding → pack；BF16/FP16 不能只把操作数转换成宿主 `float` 后在 RTL 中做运算。
- BF16×BF16 → FP32 需要明确指数/尾数计算、符号、特殊值和 underflow/overflow；FP32 accumulator 明确迭代依赖和输出写回。
- 由 **`docs/spec/FP_EXTENSION_SPEC_ZH.md`** 逐项规定 NaN、Inf、signed zero、subnormal、舍入 tie、累加顺序。**加法与乘加的结果一律 bit-exact 检查**；有意允许的 NaN payload 等效关系须单独明确，不允许用不受控 tolerance 掩盖数值错误。
- 先完成单 Lane；双/四 Lane 不是 G1 准入要求。

### G1 — Block DV 验证设计

**UVM 基础组件**：input active agent（sequence/driver/monitor）、output passive monitor、reference model（用 DPI-C 接独立 SoftFloat/或经审计的 bit-exact 实现）、scoreboard、covergroups、SVA、replayable regression；不能只靠 DUT 公式复制一份 reference 进行比较。

**P0 测试分类**：

1. Numerical: Normal、±0、Subnormal、Inf、NaN、指数差很大/很小、cancellation、tie-to-even、溢出/下溢。
2. Control: consecutive valid、input gap、output backpressure、FIFO 满/空、连续 reset/abort、流水线清空、tag/ID 匹配。
3. Accumulation: 正负混合、长链累加、每步舍入、边界 K 长度、tail/残余元素。
4. Format: FP16 vs BF16 mode、输入掩码、packed 两元素/word、格式切换后的连续事务。
5. Negative: 非法 opcode/invalid length/超界地址，区分 expected rejection 与 RTL bug。

**P0 核心 SVA/事务不变量**：accepted request 不丢失；无 reset/abort 时完成数不超过接受数；任何 stalled `valid` 的 payload 保持稳定；output valid 与 data/tag 同步；abort 后不能出现过期结果；计数器不溢出/不下溢。若 liveness 证明依赖下游最终响应，须写明 fairness 假设或用有界 timeout 检查。

**Coverage Closure 不是数字表演**：先从规格生成合法 coverpoint/cross 列表，再量化完成率。P0 要求 *全部已定义关键功能 bins* 被命中；建议非关键合法功能 bins ≥95%，重要 cross ≥90%，代码覆盖及 waiver 独立报告。任何覆盖率目标都不得通过删除难达 bin 或粗暴 waiver 实现。

### G2 — SPAD/命令集成

- 保持 `ai_spad_arbiter` 的唯一 admission 权限；G2 通过当前 core-SPAD mux 的现有调度入口完成片上 A/B 读取和结果写回。
- 当前验收输入已预加载在 SPAD，测试闭环为 command→SPAD→FP→SPAD→completion；不含 DMA DDR load/store。DDR 端到端验证留在 G3。
- G2 支持 queue descriptor 与 direct-register 命令。top smoke 核对 A9 `VERSION=0x10000009`、ABI 7.3、`CAP2=0x7f`；BF16 `1×3 + 2×4` 返回 FP32 `0x41300000`；非法 descriptor 与非法 direct config 被拒绝。
- **最终写回 commit point**：进入 `ST_WRITE` 并提出最终 SPAD 写请求后，请求已不可撤销；若 `ready` 未到，`valid`、地址、数据和写使能必须保持稳定直到握手。握手成功即提交并报告成功，除非发生 SPAD protection error；不得由随后到达的 abort/watchdog 撤销或改报取消。commit point 之前的 abort/watchdog 仍可取消命令。Block gate 含 request-stability SVA 及 stalled writeback 期间 abort 的 commit-point test。
- 已有 VCS gate（命令均从 repo root 执行，环境 Rocky-8.10 WSL / VCS V-2023.12-SP1；worktree dirty）：

  ```bash
  make -C dv/block/compute/fp/sim dot-core-test
  make -C dv/subsystem/top_smoke/sim ai_smoke
  make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
  make -C dv/block/cdc/sim command_path_run
  ```

  四项均 PASS。`command_path_run` 汇总 `commands=2 launches=2 events=2 completion_words=8 errors=0 overflow=0`。top smoke 含既有 Transformer/random 检查。具体运行记录另见 `docs/project_update_log.md` 的 2026-10-13 G2 条目。
- 当前整机 SpyGlass lint：exit 0、0 errors、285 warnings、4 infos。该结果只说明规则检查完成，
  不代表 warning closure 或 signoff；新增 dot core 有单进程 FSM/同一顺序块多路径更新
  `pending_error_r`（STARC05-2.11.3.1、STARC05-2.2.3.3、W415a）告警，FP32 组合加法器
  也有已知 W415a 临时变量类告警。未对这些规则做 blanket waiver；逐项审查/是否重构仍是
  lint triage 工作。VCS smoke 另有 CNM 计数输出未连接提示。
- **G2 证据边界**：不表示 DDR→SPAD→FP→SPAD→DDR 已验证；不表示 UVM/URG coverage closure；没有新增 FP PPA。三项均留 G3。

### A10 FP16 Dot 实现与验证记录（2026-10-13；mixed UVM/top smoke PASS，coverage disposition 开放）

> 本节记录 A10 初始交付时的状态；UVM seed 数、争用 profiling 与当前 arbiter 修正后的 gate 状态，以下方“真实 DMA/SPAD 争用 profiling 增补”为准。

- RTL 保持 `0x50` 为 BF16 点积；新增 `0x51` FP16 点积。`ai_mixed_precision_dot_fp32_core` 锁存输入格式，共用 FP16/BF16 乘法选择、顺序 FP32 累加、现有 arbiter-owned SPAD 端口和单一结果写回。兼容 BF16 wrapper 保留原接口。
- 命令路径已接入 `ai_accel_opcode_decode`、descriptor validator、command processor、compute cluster 与共享 completion writer；寄存器/软件 ABI 同步为 A10、ABI 7.4、`CAP2=0xff`（bit 6 BF16、bit 7 FP16）。
- Block 定向验证：`fp16-mul-test` 的 10,015 个向量 PASS；旧 BF16 `dot-core-test` PASS；Python golden model 19 tests PASS。
- Mixed BF16/FP16 UVM：`make -C dv/block/compute/fp/sim dot-uvm-regress DOT_RANDOM_COUNT=64`，VCS V-2023.12-SP1，seed `712345` 和 `987654` 各完成 162/162 scoreboard transactions：142 笔 bit-exact BF16/FP16 数值向量（各 format 71）、14 笔期望错误事务、6 个异步 reset-in-flight 事务。错误场景包括配置、A/B operand parity、read/write protection、WAIT_A/CALC abort、watchdog，以及 A/B read handshake 前 abort；reset 覆盖 READ_A、WAIT_A、READ_B、WAIT_B、CALC、WRITE。每 seed `UVM_WARNING/ERROR/FATAL=0`；URG 双数据库合并成功，成功数值事务的功能 covergroup 100%。Makefile 已能通过 `VCS_HOME` 自动定位 URG，且仅合并本次选定 seeds 的 VDB。
- URG 中 `ai_mixed_precision_dot_fp32_core` line/condition/FSM/branch 为 `98.32%/63.50%/87.80%/83.33%`；所有 9 个 `state_r` 状态与 23 个转移均命中。`pending_error_r` 6 个状态均命中、18 个转移命中 13 个；未命中的五条转移为 ABORT/CONFIG/PARITY→PROTECTION 与 WATCHDOG→NONE/PROTECTION，暂留 review/disposition。condition/branch 仍非 100%，功能 covergroup 100%不等于 DUT 全覆盖 closure。
- top smoke 已通过旧 BF16 命令、FP16 queued/direct 命令及新增 DDR 闭环：DDR 两个 packed FP16 操数经 DMA 读入 SPAD，`0x51` queued descriptor 经 shared completion，结果再由 DMA 写回 DDR，逐字期望 `0x41300000`。本轮重新运行 `make -C dv/subsystem/top_smoke/sim ai_smoke` 为 `TEST PASS`；20-case seeded top run 为前序证据。VCS compile 留有 CNM perf telemetry 输出未接线的 TFIPC warning，属独立清理项。
- 边界：top 端到端为 directed smoke + compact AXI memory model，不代表 DDR PHY、FPGA 板级或随机 DDR error/back-pressure stress；无 FP PPA 数据。下一步先冻结复合错误优先级规格并处理剩余 condition/branch coverage，再扩展 top FP16 DDR 错误、back-pressure 和 descriptor fetch 场景；最后测量 FP 扩展 PPA。

### 真实 DMA/SPAD 争用 profiling 增补（2026-10-13）

- 为按向量长度衡量端到端吞吐，top smoke 新增 `ai_fp_dot_dma_benchmark`：单 tile 无重叠扫描
  1/2/3/4/16/64/128/256/1024 元素；并以 production `ai_tile_pipeline` 做 3-tile ping-pong，
  随机化 AXI WREADY，扫描 64/256/1024 元素。记录 tile job cycles、FP-active cycles、MAC、FP
  request/response waits、DMA SPAD waits/grants 和 tile DMA/compute overlap，并检查每 tile DDR 写回。
- 长度 1024 的 BF16 三 tile 结果：5322 tile-job cycles、3072 MAC、FP 请求等待 242 cycles、
  FP response wait 124、DMA SPAD wait 232、258 grants、1343 overlap；端到端为 0.57723 MAC/job-cycle。
  FP16 为 5318 cycles、0.57766 MAC/job-cycle。无争用单 tile 同长度为 2100 job cycles/1024 MAC，
  0.48762 MAC/job-cycle。64/256 结果和完整吞吐曲线见
  [`MIXED_PRECISION_THROUGHPUT_PPA_ZH.md`](../../verification/MIXED_PRECISION_THROUGHPUT_PPA_ZH.md)。
- 初步结论：ping-pong DMA overlap 提升了 tile-job 吞吐；共享 SPAD 的等待可观测，但当前证据不支持
  直接复制多输出 MAC lane。先提高 DMA read-response/backpressure 压力并完善真实流量模型，再决定
  是否做并行输出微架构。
- 实测调试中发现 registered scratchpad parity/error 与 tagged response 的对齐问题；更新
  `ai_spad_arbiter.rsp_error` 为与 `rsp_valid`/read data 对齐，并保留 request-time protection error。
  `ai_spad_arb_run` 新增响应周期 parity 检查；CNM/DMA contention 和 parity 对齐均 PASS。AXI/SPAD
  ready/valid/request 路径不变。
- 本轮 VCS gates：FP `dot-core-test`；mixed-dot UVM 四 seed（每格式 256 个随机向量/seed，URG merge，
  每 seed UVM_ERROR/FATAL=0）；DMA UVM 11 项；control UVM 6 项；`ai_spad_arb_run`；`ai_smoke`；
  `ai_run AI_RANDOM_CASES=20 AI_SEED=12345`；`ai_fp_dot_dma_benchmark`，均 PASS。完整命令见吞吐/PPA 报告。
- 限制：AXI memory model 是行为级，不代表 DDR PHY/板卡。随机化当前覆盖 WREADY，不覆盖 AXI RVALID
  latency/error。已有 4.0 ns PPA 数据对应本次 arbiter parity 修复之前的 RTL，后续 PPA 阶段须先对最新 RTL
  重跑 4.0 ns，再做目标频率 sweep。此阶段完成了截图中的验证冻结和多长度/真实 tile-pipeline profiling。

### 2026-10-14 V3 争用验证刷新

- 用户确认保留最多两笔已接受、未返回的 FP scratchpad read；已核对并同步中英文 SPEC、架构说明和 FP 扩展规格，
  响应仍按请求顺序返回且接口不带 read ID。没有修改 RTL/ABI。
- 共享 AXI memory model 新增可配置 read-response beat gap，复位默认值仍是原来的 1-cycle；只有 dedicated FP
  benchmark 的 3-tile ping-pong workload 会用 benchmark seed 随机施加 0–3-cycle RVALID 间隔，同时随机化 WREADY。
  常规 `ai_smoke` 与 seeded top workload 均不启用 latency randomization。
- 验证：DMA UVM 11/11 PASS；FP/DMA/SPAD benchmark 24/24 BF16/FP16 点 PASS；`ai_smoke` 与 20-case seeded
  `ai_run` PASS；`git diff --check` PASS。1024-element、3-tile ping-pong 的 BF16/FP16 分别达到 0.57058/0.57164
  MAC per tile-job cycle。复现命令和原始 CSV 位置见 [`MIXED_PRECISION_THROUGHPUT_PPA_ZH.md`](../../verification/MIXED_PRECISION_THROUGHPUT_PPA_ZH.md)。
- 这是带随机响应时延的行为级 AXI BFM + 真实 tile/DMA/SPAD 仲裁/FP 路径，不是多客户端 subsystem UVM、
  DDR PHY/板卡验证，也不代表 A10 V3/V4 或全计划闭环。

### 2026-10-14 V3 AXI 错误排空修复与验证增量

- 新增 `make -C dv/subsystem/top_smoke/sim ai_dma_error_stress AI_SEED=<seed>`，对 16-word/4-beat DMA burst 伪随机选择 RRESP/BRESP SLVERR beat。Seeds `314159/987654/20261014` 每个各执行 8 个 read + 8 个 write 错误事务，并核对软件错误码与 AXI/BFM drain-to-idle。
- stress 首轮发现真实 RTL 缺陷：read RRESP error/RLAST mismatch 直接进入 `ST_ERROR`，停止 RREADY，遗留已接受 burst 的剩余 beats。现在停止新 AR、清除 completed-but-uncommitted 读槽并进入 `ST_ABORT_READ`，持续接收已接受响应直到 RLAST，再报告错误完成；读期间 SPAD 错误也复用该 drain 状态。
- RTL 修复后的 DMA block UVM 11/11（所有 UVM warning/error/fatal=0）、`ai_dma_error_stress` 三 seeds、`ai_smoke`、20-case seeded `ai_run` 与 FP/DMA/SPAD benchmark 24/24 均通过。完整日志见 A10 baseline。
- 该测试是有界的 seeded top-BFM error stress；多笔 outstanding 错误归因、AXI error 与 compute/SPAD 多客户端争用并发、随机 subsystem UVM scoreboard/fairness coverage 仍未闭合。

### G3 前一 BF16-only 快照（2026-10-13；已由上方 A10 记录 supersede）

- 新增 `make -C dv/block/compute/fp/sim dot-core-random-test`，通过 Python `Fraction` bit-exact `bf16_dot` oracle 生成 7 个必达 corner/length 事务和 64 个 seeded finite-random 事务；SV testbench 在 SPAD transaction model 上核对每次读取地址、读数、有效 lane 数、单次写回地址/数据和最终结果，并对读/write back-pressure 与 request stability assertion 做检查。
- VCS V-2023.12-SP1，两组 seed 均 PASS：

  | Seed | Transactions | Length 1/2/3/4 | Zero/Subnormal/Normal/Inf/NaN | Positive/Negative | Stalled requests |
  |---:|---:|---:|---:|---:|---:|
| 712345 | 71 | 20/17/14/20 | 63/69/217/2/1 | 180/172 | 105 |
  | 987654 | 71 | 22/19/14/16 | 70/67/192/2/1 | 177/155 | 99 |

  Seed `712345` 的复跑得到完全相同的向量覆盖计数，确认可回放。

- `python3.12 -m unittest discover -s dv/block/compute/fp/model -p test_fp_reference.py`：16 tests PASS。
- `dot-uvm-regress` 已在 VCS V-2023.12-SP1 完成两 seed 回归：每个 seed 均 71/71 bit-exact transactions PASS，`UVM_WARNING=0`、`UVM_ERROR=0`、`UVM_FATAL=0`；独立 URG merge 报告已生成。此结果关闭了“UVM 尚未运行”的状态，但不等于 coverage closure。
- UVM 功能 covergroup 合并得分 95%：length、BF16 class、sign、back-pressure 的单项 bins 均 100%；`length × class` cross 为 15/20（75%），尚缺 length 2/3/4 分别与 NaN/Inf 的 5 个组合。两 seed 都以长度 1–4 事务为主，错误、复位、abort 仍由现有 directed block test 覆盖，尚未迁移为 UVM 场景。
- URG 合并的 DUT 模块定义覆盖显示：`ai_bf16_dot_fp32_core` line/condition/FSM/branch 为 81.98%/45.05%/23.08%/60.42%；`ai_bf16_mul_fp32` 为 98.61%/80.56%/—/94.12%；`ai_fp32_add` 为 90.57%/83.91%/—/82.35%；`ai_fp32_accumulator` line/branch 为 100%/100%。因此当前属于**有独立 oracle 的 block-level UVM 初步闭环，功能通过、覆盖仍开放**；尤其要分析 core FSM 未命中状态/转移，不能用总体 URG score 代替 DUT closure（总分还包含 UVM package）。
- 当前 testbench 每笔最长 4 个 BF16 element，仍不覆盖 descriptor→DMA load→SPAD→FP→DMA store 的真实 DDR 端到端路径。

### BF16-only UVM 初始 bring-up 历史快照（已由上方 A10 mixed-dot 结果取代）

- 新增独立 block UVM 环境：`dv/block/compute/fp/uvm/ai_bf16_dot_uvm_pkg.sv`、`ai_bf16_dot_if.sv`、`tb_ai_bf16_dot_uvm.sv` 与专用 filelist；package 将 item/sequence/driver/monitor/scoreboard/coverage/env-test 分为独立 include 源片段，最大组件文件约 154 行。向量由独立 Python bit-exact oracle 生成；UVM sequence 逐行驱动，SPAD BFM 加入可复现的读响应延迟和 request back-pressure。
- Scoreboard 分别接收 driver transaction 与 monitor 观察到的总线握手，逐笔核对 transaction ID、SPAD 地址/数量、有效 element 数、唯一结果写回地址/数据、error 与最终 FP32 raw bits。Coverage subscriber 对通过的事务采样 length、BF16 zero/subnormal/normal/Inf/NaN、正负号、无 stall/有 stall，并定义 length×class cross。
- 新增 `make dot-uvm-test DOT_RANDOM_SEED=<seed> DOT_RANDOM_COUNT=64` 单 seed 验收，以及 `make dot-uvm-regress DOT_RANDOM_COUNT=64` 双 seed 回归/合并 URG 报告。已运行命令：`cd dv/block/compute/fp/sim && make dot-uvm-regress DOT_RANDOM_COUNT=64`。流程包括 VCS UVM 编译/断言、line/condition/branch/FSM 覆盖数据库。输出按 seed 隔离在 `/tmp/nmaforge_bf16_dot_uvm/seed_<seed>/`，合并报告位于 `/tmp/nmaforge_bf16_dot_uvm/urg_report_merged/`。
- **验收状态：block UVM 运行 PASS；coverage closure 未完成。** Seed `712345` 与 `987654` 各完成 71/71 bit-exact transactions，两个 run 均为 UVM warning/error/fatal 0；URG 的 covergroup 为 95%，其中 5 个 length×class cross bin 未命中。DUT `ai_bf16_dot_fp32_core` 的 FSM coverage 为 23.08%，必须逐项审查未覆盖状态/转移及可达性，再补场景或给出有依据的 disposition；不能仅凭零错误报告或功能 covergroup 得分声称 coverage closure。
- DDR→SPAD→BF16 dot→SPAD→DDR 阶段尚未开始；不会将 block 级 SPAD BFM 结果当成系统级 DDR 验证。

### G3 — End-to-End DV

使用两个不依赖 DUT 内部计算过程的 oracle：

- **数值 oracle**：根据输入矩阵/向量、格式与指定舍入逐步计算预期数据。
- **事务 oracle**：根据 descriptor、memory image、stride、地址和完成队列约定预测每次 SPAD/DDR 可见效果。

必须实测以下场景：DDR 响应 ID 重排、SPAD backpressure、多任务间隔、请求交错、abort/reset 边界、错误 descriptor、结果写回争用、Completion exactly-once、IRQ 与错误码归因。输出端不只检查最后一个 checksum，应对比**全部地址和每个有效 element**。

### G3 — 设计与性能证据

建立严格公平的对比矩阵：

| 比较 | 变量 | 固定条件 | 结论范围 |
|---|---|---|---|
| 原版 A8 vs 增加 FP 后 | logic area、时序、macro 用量、功耗估计 | 同工艺库、PVT、约束、综合脚本、宏映射 | 只能得出 pre-layout 增量成本 |
| FP single lane vs 2/4 lane | II、latency、throughput、area、stall | 同 BF16 workload、地址布局与 backpressure profile | 能否证明 lane scaling 有效 |
| DDR-bound vs compute-bound | effective MAC/s、GB/s、stall、overlap | 定义清楚的 problem shape/统计区间 | 瓶颈归因，非宣传峰值 TOPS |

同时保留关键路径报告、利用率/critical path 变动、相同测试输入下的 cycle count。禁止把旧版 A8 的 250MHz 结论自动迁移到新增 FP RTL；`TT` 单 corner 不等于真实芯片 sign-off。

---

## 6. 候选项目的最终“求职验收清单”

### Design 方向必须拿得出手

- [ ] 独立设计的 FP RTL 源代码（模块图、数据路径、状态机、流水线、寄存器/存储估算）。
- [ ] 清楚说明为什么选择 BF16/FP16、为什么使用该累加舍入语义，以及固定点/浮点 trade-off。
- [ ] 能用波形解释 `valid/ready`、数据 hazard、stall、abort 和写回顺序。
- [ ] 至少一个结构替代方案及可复现的 PPA/吞吐对比，而不是只有“我设计了一个 IP”。
- [ ] 可用 `git diff` 明确区分原有 NMAForge 和自己本轮新增的实现；若使用 AI 协助，仍需能解释每项关键设计决策。

### DV 方向必须拿得出手

- [ ] 规格驱动 FP Block testplan（功能点 ↔ sequence ↔ checker ↔ coverage）。
- [ ] 完整 SV/UVM components、独立 golden、scoreboard、SVA；支持 seed 复现失败。
- [ ] 真实 bit-level FP corner-case 回归，显示 pass/fail/coverage/raw code coverage 和 review 后 waiver。
- [ ] 至少 **2 个**可以讲清楚原因的失败案例：prefer真实 RTL defect，若为人工注入必须明确标成 mutation，**不冒充实际发现的产品 Bug**。
- [ ] Subsystem 的 DDR→SPAD→FP→SPAD→DDR 数据完全一致，无未知失败。
- [ ] 保留旧 DMA/Control/INT8 全部回归，证明新增 FP 未破坏老功能。

### 建议简历主线（仅在完成且有证据后填写数字）

**Design 版**：Designed a synthesizable BF16/FP16 mixed-precision compute engine and integrated it into an AXI4 near-memory accelerator, including command dispatch, banked-SRAM dataflow, pipelined arithmetic and result writeback; evaluated post-extension PPA and throughput under controlled workloads.

**DV 版**：Developed SV/UVM and independent bit-accurate reference models for mixed-precision FP and DMA-to-compute subsystems; verified corner-case numerics, backpressure, abort and transaction completion with reproducible multi-seed regression, SVA and coverage-driven closure.

> 简历中的覆盖率、Bug 数量、PPA、加速比、频率、FP 功能范围只有通过真实运行才能填写；不得提前填虚构数字。

---

## 7. 风险登记与应对

| 风险 | 触发信号 | 对策 |
|---|---|---|
| 任务扩张导致无法收尾 | W5 仍无法得到可靠数值基线 | 先冻结单通道 BF16 Add/Sub + BF16 Mul/FP32 Acc；暂停四 Lane、GEMM、CPU 集成 |
| FP 数值 oracle 本身不正确 | NaN/zero/舍入出现模型分歧 | 用 SoftFloat / 明确许可的参考实现交叉比对，固定 raw test vectors，区分 spec mismatch 与 RTL bug |
| SPAD 带宽不足 | 多 Lane 大量空转 / arbitration stalls | 先 profiling，再决定 burst cache/operand FIFO/double buffering；不可盲目复制 Lane |
| 旧系统功能回退 | DMA/Control/INT8 某条旧用例失败 | CI 阻止合入，最小差分定位，修复后全部回归 |
| 缺商业工具 license | VCS/URG/SpyGlass 报错 | 记录工具限制；可用 Verilator/Yosys 做部分替代但不得宣称商用 UVM sign-off |
| 公开发布侵权/泄密 | 第三方 RTL 无清楚许可证、foundry 宏泄漏 | 不拷贝无许可 RACE RTL；保留第三方 attribution；不上传 PDK、SRAM、芯片库与私有板卡工程 |
| 项目过大无法在面试中解释 | 各模块都有但无个人设计边界/bug案例 | 控制增量范围；深挖 FP Block + DMA/SPAD 一条闭环；把其余模块作为已有工程背景 |

---

## 8. 每周工作的固定模板

每周只需填写以下五项，避免“写了一大堆代码却没有证据”：

```markdown
### Week NN — [阶段]
- Commit / branch:
- 本周冻结的 specification 与 design decision:
- 新增 RTL / DV / SW 文件及实际功能:
- 可复现命令、seed、运行结果（PASS/FAIL/ERROR 分类）:
- Coverage/PPA/波形/最小 bug 复现及下周唯一阻塞项:
```

**每次新增关键 feature 的合入门槛**：Lint/compile clean（不能掩盖 warning）→ Directed Test → Multi-seed Regression → Assertions → Regression on legacy INT8/DMA/Control → Review of coverage/limits → Commit & report。

---

## 9. G0/G1 历史完成检查表

以下记录保留阶段当时的状态；opcode 集成的当前状态以 G2 验收记录和最终决策门禁为准。

- [x] 记录 HEAD `fbaa525…` 与非干净 worktree；回归报告明确说明不是 clean `main` checkout。
- [x] 运行/记录 DMA UVM 11/11、Control UVM 6/6、top smoke `TEST PASS`。
- [x] 冻结 `docs/spec/FP_EXTENSION_SPEC_ZH.md` 的 FP16/BF16 位型、RNE、NaN/zero、FP32 累加语义。
- [x] 核对 `ai_spad_arbiter` / `ai_scratchpad` 读延迟与顺序 A/B 请求，登记保护/背压约束。
- [x] 冻结首个 opcode、descriptor 字段、ABI 7.3、A9 revision 和 capability bit 提案。
- [x] 新增 Fraction/integer raw-bit reference model；16 项 directed 与确定性随机单元测试通过。
- [x] G0 gate review 通过并进入 G1 算术 RTL 工作（历史状态记录；后续 G2 已完成产品路径集成）。
- [x] G1 首个乘法子块：32 directed + 10,000 seeded random，VCS raw-bit 比对 10,032/10,032 通过（当时产品路径尚未接入；后续 G2 状态见本计划上文）。

---

## 10. 参考事实源（开工前应阅读）

1. [NMAForge repository](https://github.com/cwu766485-ctrl/NMAForge/tree/main) — 当前工程主线；施工时固定 SHA。
2. [NMAForge SPEC_ZH](https://github.com/cwu766485-ctrl/NMAForge/blob/main/docs/spec/SPEC_ZH.md) — ABI、opcode、数据格式与资源所有权。
3. [NMAForge ARCHITECTURE](https://github.com/cwu766485-ctrl/NMAForge/blob/main/docs/architecture/ARCHITECTURE.md) — CMDQ、DMA、SPAD、Compute 交互。
4. [NMAForge VPLAN](https://github.com/cwu766485-ctrl/NMAForge/blob/main/docs/verification/VPLAN.md) — 原验证矩阵、实际完成情况与限制。
5. [NMAForge VERIFICATION_MATRIX](https://github.com/cwu766485-ctrl/NMAForge/blob/main/dv/VERIFICATION_MATRIX.md) — Block/subsystem 的证据与未完成项。
6. [RACE LaneFAdd](https://github.com/RACE-org/ut-vector-fadd) 与 [Verification Specification](https://github.com/RACE-org/ut-vector-fadd/blob/main/doc/verification_spec.md) — *仅参考数值测试和控制思路；复用代码须确认许可*。
7. [Berkeley SoftFloat](https://www.jhauser.us/arithmetic/SoftFloat.html) — 独立浮点 golden 的候选参考；使用前审查授权、编译配置及 rounding/exception 约定。

---

## 11. 最终决策门禁（一页版）

- **G0 通过**：当前记录的 dirty worktree 上基线回归 + spec/ABI/资源/数值契约冻结；允许进入 G1 算术 RTL。clean `main` checkout 的独立复测仍未声称完成。
- **G1 通过**：独立 FP 算术 RTL 与数值参考一致，控制 SVA 及独立 block lint 已检查并 disposition → 允许进入 G2 opcode/生命周期集成；URG/code coverage 仍属于 G3。
- **G2 已通过（历史范围）**：预加载 SPAD 的 `0x50` command→SPAD→FP→SPAD→completion 通过；该阶段记录不含 DDR 端到端。
- **G3 部分通过但未闭合**：当前 A10 已通过 FP16 directed DDR→SPAD→FP→SPAD→DDR、mixed-dot UVM 四 seed（每格式 256 random/seed）、DMA/control 回归、top smoke 和初版 DMA/SPAD contention profiling；仍需完成 DUT FSM/code coverage disposition、随机 DDR read-response/error 压力以及包含本次 arbiter parity 修正的同约束 FP PPA。完成前不声称 G3 通过，也不据此声称 2/4 Lane 扩展结论。

**一句话**：这轮项目的目标不是再堆一个“支持 AI 的浮点模块”，而是打造一个**有自研微架构、有独立数值模型、有 UVM 验证闭环、有 PPA 与失败分析的可交付 AI Accelerator IP**。

## 12. Ordered SPAD-response jitter regression（2026-10-14）

- 将 `review/fp-dot-response-jitter` 的两个提交快进合入 `main`：新增 `dot-throughput-stress` 和可复现的 SPAD response jitter；固定双周期基准保持默认行为。
- 初跑 stress target 发现 Makefile recipe 的 shell 变量未用 `$$` 转义，GNU make 将 `$seed` 等提前展开，导致 VCS 收到非法 plusarg 并触发 timeout。已修正配方转义；并在每个 profile 后检查 PASS 标记，避免 VCS `$fatal` 未传播为非零 shell 状态时误报成功。
- Rocky-8.10 WSL / VCS V-2023.12-SP1 验收：`dot-throughput-bench` PASS；`dot-throughput-stress` 在 2 seeds × 3 组 backpressure/jitter（0/0、30/3、60/11）下 BF16/FP16 各 9 个长度全部 PASS；`dot-core-test` PASS；默认 `dot-uvm-regress` 两个 seed 均 scoreboard 162/162、UVM error/warning/fatal 为 0，URG merge 成功；`ai_smoke` TEST PASS（随机用例 4、seed 12345）。
- Smoke 编译仍有 `ai_accel_compute_cluster` 中 `ai_banked_cnm_core` instance `Too few instance port connections` warning；不影响该 smoke 的 TEST PASS，但应另行核实其是否预期未连接端口。
- 本轮命令均从仓库根目录启动；`make -C` 的路径相对当前工作目录，而不是自动相对仓库根目录。仿真日志、VCS 数据库保留在 WSL `/tmp` 或忽略的本地输出目录，不纳入版本控制。

可复现命令（Rocky-8.10 WSL，仓库根目录）：

```bash
make -C dv/block/compute/fp/sim dot-throughput-bench
make -C dv/block/compute/fp/sim dot-throughput-stress
make -C dv/block/compute/fp/sim dot-core-test
make -C dv/block/compute/fp/sim dot-uvm-regress
make -C dv/subsystem/top_smoke/sim ai_smoke
```
