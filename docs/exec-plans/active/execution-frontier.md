# NMAForge 执行前沿与学习交接

更新时间：2026-09-18

## 项目定位

NMAForge 是可综合的 AXI-Lite/AXI4 Compute-Near-Memory AI 加速器 IP，顶层为
`rtl/top/ai_accel_top.v`。包含命令/完成队列、128-bit DMA、4-bank scratchpad、
CNM、4x4 matrix、CNN、SFU、KV-cache、Transformer 命令链、保护/异常处理和性能计数器。
当前目录迁移及用户修改必须保留；禁止 `git reset --hard` 和 `git clean`。

## 已完成与当前证据

- Scratchpad 四处非法 `!|` 已改为 `!(|...)`，四个语法 Fatal 消失。
- AXI fabric 的 `desc_rready`、`dma_rready` 已改为 input。
- `ai_perf_monitor` 已拆分异步 reset 与同步 clear。
- `a8_static.prj` 已加入 `set_option define VCS`，选择行为级 Scratchpad。
- 清理无效 signed cast、未使用信号/端口、整数索引和部分重复赋值。
- SpyGlass lint：0 Fatal、0 Error、260 Warning、4 Info；曾从 379 Warning 降至 260。
- SpyGlass CDC：0 Fatal、0 Error、0 Warning；当前单时钟设计无未同步 crossing。
- RDC 尚未通过：`Ar_resetcross01` 阶段内存膨胀，16 GiB 环境 RSS 约 9.1 GiB 后无 summary。
- VCS `make ai_smoke`、`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 通过。
- Control UVM 六项回归 `UVM_ERROR=0/UVM_FATAL=0`。

## Warning 处理原则

Warning 不等于全部设计错误。优先修复会影响语义、综合、时序或协议的项；
对单进程 FSM、行为级 RAM reset、兼容端口和工具风格提示保留明确 disposition。
当前剩余主要集中于 DMA、matrix prefetch、AXI-Lite 握手和 tile pipeline 的
同周期 retire/reissue；继续修改前必须做 focused regression。

## 能力边界（面试必须如实表述）

已有：RTL、AXI、DMA、队列、SRAM banking/仲裁、CNM/matrix 数据流、UVM/SVA、
SpyGlass lint/CDC、VCS 回归、DC pre-layout 综合及时序分析。

尚未完成：真实多时钟 CDC/异步 FIFO、UPF/Low Power、RDC 收敛、P&R 后布局 STA、
MMMC/OCV/SI/IR-EM、系统化 PPA sweep。不能把这些规划说成已完成 sign-off。

## 当前学习主线

按一条命令的生命周期学习：

```text
AXI-Lite 配置 → CMDQ → command processor → descriptor/DMA
→ scratchpad/compute → completion writer → IRQ
```

推荐阅读顺序：

1. `docs/spec/SPEC_ZH.md`
2. `docs/architecture/ARCHITECTURE.md`
3. `rtl/top/ai_accel_top.v`
4. `rtl/control/queue/ai_command_processor.v`
5. `rtl/dma/ai_axi128_dma.v`
6. `rtl/memory/ai_spad_arbiter.v` 与 `rtl/memory/ai_scratchpad.v`
7. `rtl/compute/cnm/ai_banked_cnm_core.v`
8. `rtl/compute/matrix/ai_tensor_matrix_core.v`
9. `rtl/compute/pipeline/ai_tile_pipeline.v`
10. `docs/verification/TSMC28_SYNTHESIS_REPORT.md`

## 两个月架构学习计划

目标不是背模块名称，而是能从一条命令解释控制、数据、时序、错误和性能。

- 第 1 周：SPEC、ARCHITECTURE、顶层端口；画控制面/数据面和所有权图。
- 第 2 周：AXI-Lite、寄存器、CMDQ/CPLQ、doorbell、IRQ 和 sticky status。
- 第 3 周：command processor 状态机、descriptor 格式、依赖、abort/watchdog。
- 第 4 周：SPAD、4-bank 地址组织、唯一 arbiter、valid/ready 和响应 tag。
- 第 5 周：DMA burst、4 KiB split、outstanding、乱序响应、back-pressure、drain。
- 第 6 周：INT8/CNM/matrix/compute dispatch，跟踪一次 GEMV 和一次 GEMM。
- 第 7 周：completion、性能计数器、吞吐率、stall/overlap、时序关键路径。
- 第 8 周：用 VCS/UVM 回归验证架构理解；整理 CDC/FIFO/Low Power/PPA 的缺口和面试叙事。

每周固定产物：一张时序或数据流图、一个 RTL 证据清单、一个可运行测试和三条
trade-off 结论。已有 UVM 基础后，验证学习重点放在“激励对应哪条架构不变量”，
而不是重新学习 UVM 语法。

## 下一步实验顺序

1. 先理解系统(SPEC)，画出一条 DMA 命令的控制流、数据流和 back-pressure 时序。\
2. 第三阶段分别深入三个核心：
- DMA：burst、outstanding、4 KiB 边界、abort drain；
- Scratchpad：banking、仲裁、冲突、保护；
- Compute：CNM、matrix、SFU 和 tile pipeline。
3. 建立吞吐率表：total/compute/DMA/overlap/stall cycles、完成 tile 数和有效带宽。
4. 做 128/256/512 KiB 及 2/4/8 bank 容量/带宽 sweep，记录 area、power、DDR traffic。
5. 做 4.0/3.5/3.0/2.5 ns DC frequency sweep，记录 WNS/TNS、面积、功耗和关键路径。
6. 解释 4-bank、local accumulation、128-bit line、4 outstanding 和 single-port SRAM 的 trade-off。
7. 再补项目短板：
- 双时钟异步 FIFO；
- SpyGlass CDC/RDC 闭环；
- UPF Low Power island；
- PPA 优化前后对比；
- 后布局 STA 流程。

## 工具与环境

- VCS/Verdi：RTL、smoke、UVM 和波形调试。
- SpyGlass：lint、CDC、RDC（RDC 当前受内存限制）。
- Design Compiler：TSMC28 pre-layout area/timing/power。
- Vivado：XCZU15EG OOC/XPM，已有 100 MHz 证据。
- UVM 1.2、SVA、URG 流程存在并用于验证。
- Rocky Linux 8.10 使用 `dnf`/`yum`；没有 `rg` 时使用 `grep`。

## 每次修改后的门禁

相关 focused test → `make ai_smoke` → 可用时运行 seeded regression/UVM →
`git diff --check`。不提交生成的 SpyGlass/VCS/波形/覆盖率目录。
