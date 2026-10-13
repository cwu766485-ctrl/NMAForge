# NMAForge 执行前沿与学习交接

更新时间：2026-10-13

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
- RDC 尚未通过：2026-09-28 的可复现重跑在规则 384/478 后停止输出，RSS 由约 4 GiB
  增至 11.3 GiB，并在 12 GiB 受控虚拟内存预算下触发 `MEM Fatal: Out of memory (MEM-1)`；
  无 final summary，属于工具资源阻塞而非 RTL violation。详见 `docs/verification/RDC_STATUS_ZH.md`。
- VCS `make ai_smoke`、`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 通过。
- Control UVM 六项回归 `UVM_ERROR=0/UVM_FATAL=0`。
- A10 混合精度状态：`0x50` BF16 保持不变，`0x51` FP16 使用共享 command/SPAD/completion 路径；
  mixed-dot UVM 双 seed 各 162/162（142 数值、14 期望错误、6 reset），URG merge 与本轮
  `ai_smoke` 通过。`state_r` 23/23 transitions 命中；`pending_error_r` 13/18 与部分
  condition/branch coverage 仍待 disposition。FP16 directed DDR→SPAD→FP→SPAD→DDR 已在
  compact AXI memory model 上通过；这不是 DDR PHY/板级证据。详见
  `docs/exec-plans/active/NMAForge_Mixed_Precision_Extension_Plan.md`。

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

## 时钟域与补短板修订（2026-09-24）

本项目不为制造 CDC 而给每个 RTL 模块拆时钟。当前 baseline 仍采用单一 `aclk`；只有外部 AXI/DDR 时钟与 `aclk` 不同，或 PPA 实测证明分频/升频有净收益时，才在边界引入 CDC。

推荐的实验性双时钟方案是：

```text
clk_ctrl    ：AXI-Lite、CMDQ/CPLQ、IRQ/status、command processor、perf monitor
clk_compute ：CNM、matrix、CNN、SFU、KV、必要时 Scratchpad/DMA 数据通路
```

控制命令和完成事件必须通过 command/completion async FIFO 或 bundled-data handshake；多 bit 的地址、长度、M/N/K、opcode 不得逐字段直接使用两级 synchronizer。只有在测得 compute-bound、DMA/控制不是瓶颈后，才比较单时钟与双时钟的 latency、steady-state throughput、power、FIFO area 和 CDC 结果。

### 补短板四阶段（修订后）

1. **CDC/RDC 与异步 FIFO**：已新增 `rtl/control/cdc/ai_async_fifo.v`，含 Gray pointer、双触发器同步、full/empty、overflow/underflow sticky 状态；2026-09-24 的 focused VCS 日志显示 `make ai_async_fifo` 在不同写/读时钟下完成 12 项顺序传输 PASS，`make ai_async_fifo_reset` 报告 `ASYNC FIFO RESET PASS`。`ai_ctrl_compute_cdc.v` 双向 command/completion wrapper 同日通过 focused VCS compile/run（`CDC WRAPPER PASS commands=12 completions=12`，见 `dv/subsystem/top_smoke/sim/ai_*fifo*_run.log` 与 `ai_ctrl_compute_cdc_{comp,run}.log`）。运行中异步复位、满/空边界、异常行为和 SpyGlass CDC/RDC 仍需闭环后，才可接入真实 top。
2. **UPF Low Power**：划分 always-on control、switchable compute、retention Scratchpad，定义 isolation/retention/level-shifter/power-state；先静态解析，再做 power-aware 门级仿真。
3. **PPA 前后对比**：以 512 KiB/4-bank、4.0 ns 单时钟为 baseline，逐项比较 clock gating、Scratchpad reuse、bank decode、SFU accumulation、tile buffer 和双时钟方案；每次只改一个变量并保存 area/qor/timing/power。
4. **STA 与后布局**：先做 pre-layout setup/hold、transition/capacitance、MMMC；有 APR/CTS/route 后导出 SPEF，用 PrimeTime 做 post-layout OCV/SI/IR-EM 检查。250 MHz 仍只能称为 pre-layout closure。

### 低功耗决策顺序

```text
clock gating → 减少无效翻转 → Scratchpad/data reuse
→ voltage/frequency 协同优化 → 必要时 clk_ctrl/clk_compute 双时钟
```

验收必须分别记录 CDC/RDC、FIFO UVM/SVA、UPF 静态/门级、PPA 前后和 pre/post-layout STA 证据；不能把计划写成 sign-off。

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

## 2026-09-27 CDC 与 PPA 基线执行记录

### 已通过的 CDC 验证

- 在 Rocky 8.10 的 VCS 环境执行 `make ai_async_fifo ai_async_fifo_reset
  ai_ctrl_compute_cdc ai_smoke`：FIFO 顺序传输 12 笔、异步复位、双向
  control/compute wrapper 和全顶层 smoke 均通过。
- 新增 `tb_ai_async_fifo_random.sv`，用独立 5 ns/7 ns 时钟、随机写入间隔、
  随机读端 back-pressure 与 256 笔有序 scoreboard 覆盖 FIFO。`+SEED=12345`、
  `67890`、`20260927` 均通过，且 SVA 已 cover `rd_valid && !rd_ready` 后的
  stable-data/重新握手路径。
- CDC FIFO block UVM 已补齐并在 Rocky 8.10/VCS 上回归：order、overflow、
  underflow、异步 reset、长期 back-pressure 五项均为 `UVM_ERROR=0`、
  `UVM_FATAL=0`。monitor 使用 clocking-block `#1step` 采样，以避免与 DUT
  posedge 更新竞争；该修复确认此前 overflow 场景的 9 写/8 读是 testbench
  观测竞态而非 RTL 丢数。五份 VDB 的 URG merge 显示 FIFO 实例及总 Group
  functional coverage 均为 100%，包括 full、empty、overflow、underflow、
  read-stall 和双域 reset bins。
- SpyGlass `./run_spyglass_a8.sh cdc` 结束：0 error、0 warning；当前产品 top
  为单 `aclk` 设计，故该结论仅覆盖其结构性 CDC。实验性 async FIFO 尚未接入
  产品 top，不能据此宣称已完成多时钟产品 CDC sign-off。
- SpyGlass RDC 已按 12 GiB/40 min 的可复现预算运行，但在规则 384/478 后以 `MEM-1`
  终止，未产生 summary；RDC closure 仍是开放项，且结果不能归因于 RTL。

### 实验性双时钟 command path（2026-09-29）

- 新增的 `ai_accel_dual_clock_command_path` 仍是**实验性 integration shell**，未替换
  单时钟产品 top。它将 1024-bit control snapshot 送入 compute 域的
  `ai_command_processor`，并把 completion/event 通过 256-bit reverse FIFO 返回 control
  域；completion writer 仍在 compute 域按四个 word 的既有原子提交规则工作。
- 接收端 `ai_ctrl_compute_cdc` 现在使用目的时钟域 one-entry staging register；命令包的
  pulse 字段只在一次 `compute_cmd_valid && compute_cmd_ready` handshake 时进入
  `ai_command_processor`。这避免 valid 因 processor busy 被保持时重复执行同一 submit。
- Rocky 8.10 / VCS focused regression：`make shell_run` 通过（16 command、16 completion、
  0 error）；`make command_path_run` 通过（2 command、2 launch、2 event、8 completion
  word、0 error）。shell reset case 明确执行 quiesce → unilateral reset → bilateral reset →
  pointer resynchronization；单侧 reset 不承诺保持 FIFO epoch。
- SpyGlass `./run_spyglass_a8.sh dual_cdc`（V-2023.12-SP1）使用独立的双时钟工程，
  启用 `enable_fifo` 并以 `mthresh=32768` 保留 1024×16 FIFO 结构。结果为 **0 fatal、
  0 error、7 warning、0 unsynchronized crossing、5 convergence**。5 条 convergence 位于
  Gray-pointer 的 full/empty 比较，2 条为异步 reset 同时初始化两级同步器；均未 waiver，
  仍需随 reset protocol/SVA 与后续 CDC review 进行 disposition。此结果不是 product-top
  CDC/RDC sign-off，RDC 仍处于资源阻塞状态。

### PPA 基线与限制

- `dc_shell`、`pt_shell` 与 TSMC28 标准单元库可用；SRAM 仅提供了 `.lib`，在
  私有本地覆盖中转换为 `.db` 后，library probe 确认标准单元 839 个 cell、目标
  SRAM macro 1 个 cell 可被加载。
- 修复本地、忽略提交的 DC driver，使其从当前 `ai_accel.f` 解析 RTL，并以
  `syn/ai_scratchpad_28nm_macro.v` 替代行为级 scratchpad；这样可避免旧目录结构
  导致 `analyze` 失败却错误打印完成信息。该 driver 含私有工艺流程配置，保持在
  local overlay，不进入公开仓库。
- 4.0 ns、TT/0.9 V/25 C、wire-load-model、无 SAIF 的完整 current-RTL DC run
  已完成：setup/hold WNS/TNS 均为 0，critical-path length 为 3.88 ns，library
  cell area 为 1,244,193.24；动态功耗报告为 22.8714 mW、leakage 为 1.9715 mW。
  功耗报告同时有 `PWR-414/415/428` 未标注活动告警，故只能作为 vectorless
  pre-layout estimate，不能用于真实 workload 功耗结论或 sign-off。
- 当前仍有 4 条高扇出网以 1000 fanout WLM 估算，`check_design` 也有 936 条
  LINT 类提示；这些是后续约束/结构 review 项，不能隐藏。
- 历史的固定时钟 SAIF 覆盖 251,590,000 ps 的 10.0 ns（100 MHz）smoke workload；
  它直接交给 DC 时因根为 `tb_ai_accel_smoke/dut` 触发 `PWR-362`，故不能用于功耗
  结论。`syn/normalize_saif_root.py` 只移除 testbench 包装并将 DUT 根改为
  `ai_accel_top`，从而可由 `read_saif ... -instance ai_accel_top -auto_map_names`
  正确注入；旧的固定周期功耗数据仅保留为历史排错记录。
- smoke testbench 现已通过 `+ACLK_PERIOD_NS=<real>` 参数化，默认 10.0 ns 与旧
  `forever #5` 行为等价；VCS 编译时间精度为 1 ps，故可精确产生 3.5 ns 周期。每次
  `make ai_smoke_saif ACLK_PERIOD_NS=<period> AI_RANDOM_CASES=4 AI_SEED=12345
  SEED=12345` 均生成独立 raw SAIF 和 `<period>_dc.saif`，避免覆盖，也使 SAIF 时钟
  与该 DC 约束点一致。
- 2026-09-28 周期匹配 SAIF power 结果如下；每项均使用对应周期的既有 TT/0.9 V/25 C
  pre-layout DDC（报告为 segmented mode、top 使用 `ZeroWireload`），`read_saif`
  成功且无 `PWR-362`。这里的频率由 SAIF 的真实
  aclk transition count/DURATION 得出，而非由 DC 约束反推：

  | DC period | SAIF clock | Dynamic | Leakage | Report total |
  |---:|---:|---:|---:|---:|
  | 4.0 ns | 250.000 MHz | 22.4913 mW | 1.9734 mW | 24.4697 mW |
  | 3.5 ns | 285.714 MHz | 25.7010 mW | 1.9692 mW | 27.6734 mW |
  | 3.0 ns | 333.333 MHz | 29.9795 mW | 1.9728 mW | 31.9539 mW |
  | 2.5 ns | 400.000 MHz | 35.9905 mW | 1.9738 mW | 37.9669 mW |

  这组数据体现目标频率的 workload-aware 动态功耗趋势；时序/面积仍沿用对应 DDC 的
  QoR（4.0/3.5/3.0 ns critical path 分别为 3.88/3.37/2.87 ns，setup/hold WNS/TNS
  均为 0）。它们仍是单 PVT、WLM 的 pre-layout estimate，不是 CTS/route/OCV/MMMC
  或 silicon sign-off。`PWR-19/PWR-12` 活动冲突/已标注时钟信息、`PWR-415/428`
  未标注对象、`TIM-134` 高扇出 fanout-1000 近似、`TIM-164` trip-point mismatch 与 LINT
  提示均仍需在正式签核流程中 disposition；不可宣称 333 MHz sign-off。
- 2.5 ns（400 MHz）已使用真实可读的 TT/0.9 V/25 C 标准单元 `.db`、同一 SRAM
  macro `.db` 和 `ZeroWireload` top 约束独立重跑。该有效 run 的 setup/hold WNS/TNS 均为
  0、违例路径数为 0、critical path 为 2.37 ns、cell area 为 1,246,155.79，且
  max-transition/max-capacitance 违例均为 0；最差 setup 路径位于
  `tensor_sfu_u/gamma_r_reg[1]` 到 `tensor_sfu_u/x_r_reg[18]`。此前一次 2.5 ns
  尝试因标准单元库文件名错误、产生 unmapped/hold-fail 输出，已明确废弃。有效 run
  已由 `make ai_smoke_saif ACLK_PERIOD_NS=2.5 AI_RANDOM_CASES=4 AI_SEED=12345
  SEED=12345` 导出 62,897,500 ps、400 MHz 的 smoke SAIF；VCS 为 `TEST PASS`，
  原始根 `tb_ai_accel_smoke/dut` 已归一化为 `ai_accel_top`，回标无 `PWR-362`。
  post-synthesis power 为 dynamic **35.9905 mW**、leakage **1.9738 mW**、report
  total **37.9669 mW**。其中 clock network 为 34.2891 mW（90.31%）；`PWR-19`、
  `PWR-415/428` 与高扇出 fanout-1000 近似仍须 disposition，且不支持
  `report_switching_activity`。该数据是 400 MHz workload-aware pre-layout estimate，
  不是 CTS/route/OCV/MMMC 或 sign-off 功耗。
- 该 DC 安装可执行 `read_saif` 和 `report_power`，但没有
  `report_switching_activity` 命令（`CMD-005`）；`syn/report_saif_power.tcl` 将此
  capability limitation 写入 `saif_activity.rpt`，不把缺少逐网标注统计伪装成
  coverage closure。SAIF 成功注入的可审计证据为无 `PWR-362`、`read_saif` 成功返回、
  `PWR-19/PWR-12` annotated-activity 消息以及 `power_saif.rpt`。
  原先该 capability gap 让 DC 在打印 completed 后仍返回非零；本地私有 driver 已改为
  catch 并在 `saif_activity.rpt` 明确记录不可用，后续 run 不会把这个非 RTL 原因误报为
  synthesis failure。

### Low-power / UPF 就绪度（2026-09-28）

- 周期匹配 4.0 ns SAIF 的 dynamic breakdown 为 clock network 21.4343 mW
  （约 95.3%）、memory 0.9663 mW（约 4.3%）、combinational 0.0863 mW（约 0.4%）。
  因此首个低风险候选是**计算簇/空闲子引擎的 clock-enable/ICG 可行性审计**，其次是
  SRAM bank 的现有 access-enable 利用率；不应先对组合 datapath 做无证据的细粒度
  gating，也不应直接引入 power-domain。
- 当前 RTL 没有 `iso_compute_n`、retention save/restore、always-on power
  controller 或已接入产品 top 的可门控时钟。`ai_scratchpad.v` 已有 host/line/CNM/
  compute access-enable，但它们是 RAM port enable，不能替代 clock tree gating。
- 对当前实际加载进 DC 的 TT standard-cell `.db` 与 SRAM `.db` 做只读审计：按
  `ISO/ISOL/RET/LS/LEVEL/SHIF/HEADER/FOOTER/PWR/POWER/SWITCH` 名称模式的
  `get_lib_cells` 均为 0；`is_isolation_cell`、`is_retention_cell`、
  `is_level_shifter` 与 `is_power_switch` 属性均可查询且 non-empty 计数为 0。可访问
  PDK 的 Milkyway 物理库确有 `ISOHID/ISOLOD/ISOSR*` 命名的 CEL/FRAM 视图，但在
  当前目录树未发现 `.upf` 或 `.cpf`，也没有这些 cell 对应的、可供当前综合使用的
  low-power timing/power `.db` 证据。因此结论只限于**当前可访问的库集不具备可验证
  的 low-power mapping**，不外推为该 foundry 没有 low-power kit。
- 故 `syn/upf/ai_accel_top_experimental.upf` 继续只是 intent placeholder：它引用的
  isolation/retention 控制尚未存在，也没有相应 cell mapping。UPF static parse、
  power-aware simulation 与 domain implementation 均阻塞，等待取得目标工艺的
  low-power library/UPF kit，并先定义 always-on controller 与跨域协议；不得将本项
  写为通过或 sign-off。

### 接续顺序

1. 已完成同库同约束的 3.5 ns DC sweep 点：3.5 ns 下 setup/hold WNS/TNS 均为 0，
   critical-path length 为 3.37 ns，library cell area 为 1,240,926.61，
   vectorless dynamic/leakage power 为 26.1208/1.9672 mW。相对 4.0 ns 点，
   面积下降约 0.26%、动态功耗上升约 14.2%；两点均无 SAIF，趋势不能替代
   workload power 结论。
2. RDC 受限于工具资源，待更大内存主机或站点应用工程师拆分 policy 后重试；当前进入
   FIFO block UVM/断言覆盖（full、empty、reset、overflow/underflow）。
3. UPF 先做层次/端口静态审计：当前 `ai_accel_top_experimental.upf` 是未接入的
   intent placeholder，且环境没有 `vc_lp`/`mvrc` 静态 low-power checker；RTL 中
也尚未定义其引用的 `iso_compute_n` 或 retention save/restore 控制。不得将该文件
视为 parsed 或 power-aware-sim 通过；先补齐 power controller、isolation signal
与 retention cell/library，再导入 UPF。

### 双时钟 FIFO warning closure（2026-09-29）

- 新增 bound SVA `dv/block/cdc/assertions/ai_async_fifo_sva.sv`，并将其编入
  CDC FIFO UVM、dual-clock shell 与真实 command-path filelist。它验证本地握手
  才能推进 binary/Gray pointer、每次源域 Gray 变化恰为一 bit、full/empty 只使用
  第二级同步指针、同步器级次，以及两侧 reset 清零本地 pointer/synchronizer 状态。
- Rocky 8.10 / VCS：`cd dv/block/cdc/uvm && make uvm_regress` 的 order、overflow、
  underflow、reset、backpressure 五项均 `UVM_ERROR=0/UVM_FATAL=0`；
  `cd ../sim && make shell_run && make command_path_run` 分别 PASS（16 command /
  16 completion；2 command / 2 launch / 2 event / 8 completion word）。无新增 SVA
  failure。
- SpyGlass V-2023.12-SP1 `./run_spyglass_a8.sh dual_cdc` 重跑为 0 fatal、0 error、
  **7 warning**、0 unsynchronized crossing、5 convergence、0 waiver。7 条逐项
  disposition、reset contract 与验收命令见
  `docs/verification/CDC_DUAL_CLOCK_DISPOSITION_ZH.md`。其中 5 条是 Gray full/empty
  decode convergence、2 条是当前异步断言 reset 初始化；它们已由上述 SVA 和 runtime
  tests 约束，但此实验 shell 仍不等同于 product-top CDC/RDC sign-off。

### Technology-neutral engine gate 第一批结论（2026-09-29）

- CNM、Matrix、SFU 的 RTL latch+AND gate 曾完成 focused regression、top smoke 与
  4.0 ns SAIF smoke；该实现不是工艺 ICG、CTS 或 UPF sign-off。
- 匹配 workload 的 4.0 ns DC SAIF 比较显示 dynamic power **76.5627 mW**，明显劣于
  已接受的同条件 baseline **22.5273 mW**。综合结果将通用实现映射为 latch+logic，
  未形成可验证的工艺 ICG；因此本试验不满足保留门槛。
- 已移除 `ai_engine_clock_gate`、三个 engine 的 gated-clock 接线及其 source-list
  条目，产品 RTL 恢复单一 `aclk`。保留各 engine 的 wake/active/quiescent 活动 SVA，
  作为后续工艺 ICG 的功能契约。
- 后续必须取得目标库 ICG cell 与 mapping 规则，并补 generated-clock/clock-gating
  检查方法，再针对单一 engine 重试；不得把本次功能通过包装为低功耗收益。
- TFIPC 是既有未连被动监控端口，不得说成新 warning。
