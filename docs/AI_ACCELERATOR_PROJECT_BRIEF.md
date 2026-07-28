# CIMForge AI 加速器项目说明

## 1. 项目定位

CIMForge 是一个可综合的 AI 加速器 RTL 项目。当前主线是一个由 AXI-Lite
配置、通过 AXI4 访问外部存储器的 scratchpad-based 加速器，包含命令/完成队列、
描述符调度、DMA、片上 SRAM 工作区和多种 INT8 计算核心。

本项目覆盖数字前端设计的完整链路：架构定义、RTL 集成、总线协议、仿真验证、
断言检查，以及基于 TSMC 28 nm 标准单元和 SRAM 宏的 pre-layout 综合。

仓库仍保留早期 AHB SRAM/vector 加速器作为教学与验证参考，位于
`rtl/legacy/`，不属于当前 AI 加速器的验收或综合路径。

## 2. 顶层架构

当前顶层模块为 `rtl/top/ai_accel_top.v`。

```text
AXI-Lite 主机
     |
     +--> axi_lite_reg_if --> ai_accel_regs
     |                         | 配置、doorbell、状态、IRQ
     |
     +--> scratchpad host/debug 端口

ai_command_processor
     | CMDQ/CPLQ 生命周期、描述符校验、发射与完成排序
     +--> ai_desc_fetch / axi_desc_fetch
     +--> 计算核心启动
     +--> ai_completion_writer

AXI4 DMA <--> ai_spad_arbiter <--> banked scratchpad SRAM
                    |                 |
                    |                 +--> 512 KiB、4 个逻辑 bank
                    |
                    +--> descriptor / completion / compute / DMA 客户端

计算核心
     ai_int8_compute_core
     ai_banked_compute_core
     ai_tensor_matrix_core
     ai_tensor_sfu_core
     ai_conv3x3_linebuffer_core
     ai_kv_cache_engine
```

### 模块所有权与数据流

- `ai_accel_regs` 仅负责软件可见寄存器、控制脉冲、状态与中断；不推进硬件队列指针。
- `ai_command_processor` 拥有命令生命周期，包括 `CMDQ_HEAD`、`CPLQ_TAIL`、描述符源选择、
  校验、计算发射及 in-order completion。
- `ai_spad_arbiter` 是 scratchpad 标量调度端口的唯一所有者；固定优先级为
  descriptor fetch、completion writer、compute、DMA。
- `ai_desc_fetch` 从 scratchpad 读取描述符；`axi_desc_fetch` 从外部内存读取描述符。
  command processor 会为一个 in-flight command 固定选择的来源。
- `ai_completion_writer` 必须写完 completion entry 的四个 word 后，才推进 `CPLQ_TAIL`，
  因而软件不会看到不完整的完成项。
- `ai_scratchpad` 有 host/debug 端口、仲裁后的 scheduler 端口和 banked-read 路径。仿真使用
  行为级 RAM；28 nm 综合使用 32 个单端口 SRAM 宏。

## 3. 软件队列协议

软件先写 command descriptor，再推进 `CMDQ_TAIL` 并写 doorbell。硬件推进
`CMDQ_HEAD` 来消费命令，写完四个 word 的 completion entry 后才推进 `CPLQ_TAIL`。
软件通过推进 `CPLQ_HEAD` 回收完成项。

软件发布 `CMDQ_TAIL` 并消费 `CPLQ_HEAD`；硬件发布 `CMDQ_HEAD` 与 `CPLQ_TAIL`。
这种单一所有权避免软件和硬件同时修改同一队列指针。为 reset/debug 保留 pointer-load
寄存器写入，但正常队列推进始终在 command processor 内完成。

## 4. 主要 RTL 模块

| 类别 | 模块 | 职责 |
|---|---|---|
| 顶层 | `ai_accel_top` | AXI-Lite、AXI4、寄存器、DMA、scratchpad 与计算核心集成。 |
| 控制 | `axi_lite_reg_if`、`ai_accel_regs` | AXI-Lite 请求处理、配置、状态、错误和中断。 |
| 调度 | `ai_command_processor`、`ai_completion_writer` | 队列、描述符、依赖、发射与 completion 排序。 |
| 描述符 | `ai_desc_fetch`、`axi_desc_fetch` | scratchpad 或外部内存的描述符读取。 |
| DMA | `axi_dma_master`、`ai_axi128_dma_ooo` | AXI burst、4 KB boundary、错误响应及宽数据/OOO 传输。 |
| 存储 | `ai_scratchpad`、`ai_spad_arbiter`、`ai_spad_protection` | 512 KiB scratchpad、请求仲裁和访问保护。 |
| 计算 | INT8、banked、matrix、SFU、Conv line-buffer、KV-cache 核 | INT8 算子和张量数据通路。 |
| 观测 | `ai_perf_monitor` | DMA、计算核心和调度活动的性能计数。 |

## 5. 验证策略

AI smoke test 是 `verif/tb/tb_ai_accel_smoke.sv`，由 `verif/sim/ai_accel.f`
编译。验证环境包含 AXI-Lite 访问任务、AXI memory model、reference model/scoreboard
和 `verif/env/ai_accel_sva.sv` 中的断言。

已覆盖的主要场景包括：

- AXI-Lite 控制访问和 scratchpad host 访问；
- command queue 发布、wrap、描述符读取及 completion entry 排序；
- INT8 VDOT、GEMV、GEMM 的结果检查；
- DMA load/store、多 burst、4 KB split 与 AXI response error injection；
- 描述符校验、错误码、状态和中断行为；
- directed 与随机化 datapath 用例，并通过参考模型对拍。

在 VCS 环境中，可使用：

```bash
cd verif/sim
make ai_smoke
make ai_comp
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

旧 `make regress` 属于 AHB legacy track，不能用作 AI 主线 sign-off。

## 6. TSMC 28 nm Pre-Layout 综合结果

当前综合基线使用 TSMC28 HPC+、TT/0.9 V/25 C。时钟周期为 4.0 ns，setup uncertainty
为 100 ps，pre-CTS hold uncertainty 为 20 ps。512 KiB scratchpad 映射为 32 个
`TS1N28HPCPL2SVTB4096X32M4MWBASO` 4K x 32 单端口 SRAM 宏。

| 指标 | 结果 |
|---|---:|
| 目标频率 | 250 MHz（4.0 ns） |
| Setup WNS / TNS | 0.00 ns / 0.00 ns |
| Hold WNS / TNS | 0.00 ns / 0.00 ns |
| Setup 违例路径数 | 0 |
| Hold 违例路径数 | 0 |
| 标准单元 leaf count | 97,779 |
| SRAM macro 数量 | 32 |
| 总 cell area | 1,206,694.62 library area units |
| Scratchpad 面积占比 | 约 93% |
| 动态功耗估计 | 14.54 mW |
| Leakage 功耗估计 | 1.95 mW |

setup 关键路径位于 `ai_tensor_sfu_core`，从 `vector_product_r_reg` 到
`output_word_r_reg`，arrival 与 required time 均为 3.89 ns。因此，250 MHz
是当前已经证明的 pre-layout 收敛点，而不是 post-layout Fmax 声明。

### 结果边界

该结果使用真实标准单元库和 32 个 SRAM 宏，具有 PPA 参考价值；但并非物理签核结果。
尚未包含 floorplan、CTS clock skew、布线 RC、MMMC、OCV/AOCV/POCV、IR drop 和 EM。
最终 ASIC Fmax 与 hold closure 仍需在布局布线和 sign-off STA 后确认。

## 7. 可用于面试的 Debug 与 Closure 案例

1. **Completion 原子性**：先写完四个 word，再推进 `CPLQ_TAIL`，避免软件观察到部分写入。
2. **Scratchpad 所有权**：将 scheduler 请求统一交给 `ai_spad_arbiter`，避免顶层独立 mux
   引入多客户端冲突。
3. **综合库完整性**：28 nm DC 脚本检查 inverter 和 flip-flop 单元，阻止不完整 `.db`
   生成只有 GTECH/unmapped logic 的伪 PPA 报告。
4. **Pre-layout hold 建模**：将 setup/hold uncertainty 分离，保留 100 ps setup margin 与
   20 ps pre-CTS hold margin；最终 hold 仍由 post-CTS STA 闭环。

## 8. 面试讨论要点

- AXI-Lite/AXI DMA 的 valid-ready 规则，以及在 `valid=1, ready=0` 时 payload 必须稳定的原因。
- 为什么软件和硬件分别拥有不同的 queue pointer。
- DMA 跨 4 KB boundary 时 burst 如何切分，以及 testbench 如何检查。
- scratchpad arbitration 的优先级和单一 scheduler owner 的必要性。
- 行为级 SRAM 仿真模型与 28 nm 单端口 SRAM macro 综合封装的区别。
- 正确表述综合结果：TSMC28、TT/0.9 V/25 C、250 MHz pre-layout closure，不能称为
  post-layout sign-off。

## 9. 复现方式

28 nm 综合脚本位于 `syn/dc_ai_accel_28nm.tcl` 和
`syn/run_ai_accel_28nm_dc.sh`。运行时需要匹配的 TSMC28 RVT standard-cell `.db`
与 SRAM macro `.db`；脚本会在编译前拒绝不完整的标准单元库。foundry PDK 与生成报告
均为本地工件，不应提交到 Git。
