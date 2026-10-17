# NMAForge 执行前沿与学习交接

更新时间：2026-10-17

## 项目定位

NMAForge 是可综合的 AXI-Lite/AXI4 Compute-Near-Memory AI 加速器 IP，顶层为
`rtl/top/ai_accel_top.v`。包含命令/完成队列、128-bit DMA、4-bank scratchpad、
CNM、4x4 matrix、CNN、SFU、KV-cache、Transformer 命令链、保护/异常处理和性能计数器。
当前目录迁移及用户修改必须保留；禁止 `git reset --hard` 和 `git clean`。

## 已完成与当前证据

- **2026-10-17 license 恢复后的 A10 最新验证增量（覆盖下方较早快照）：** FP 混合精度 UVM seeds
  `712345/987654/20261015` 各 482/482 scoreboard PASS（430 numeric + 52 fault/reset/error-transition），
  共 1,446 笔；peak outstanding=2，UVM warning/error/fatal=0/0/0。late-B protection
  ready-pair/error-cutoff cover 每 seed 命中 2 次；request-stability SVA 28,169 attempts、8,582 real
  successes、0 failure/incomplete；Python reference 19/19。DUT line/condition/FSM/branch=
  `97.96/97.00/85.71/92.86%`。`pending_error_r` 为 14/18 transitions；VC Formal 现有
  canonical target 为 12/12 assertions、两个 cover 均命中，显式仿真 reset 后 `No setup issues found`。
  三条 non-vacuous assertion 已证明 `ERR_ABORT`、`ERR_CONFIG`、`ERR_WATCHDOG` 不会在 `ST_WRITE` 中挂起，
  因此 disposition 对应三条 prior-error→`ERR_PROTECTION` transitions。Parity-only assertion 在约 2 分钟内未收敛，
  broad `pending_error_r == ERR_NONE` assertion 也未收敛；两者均非 counterexample，parity transition 仍开放。
  这不等于 reset-release/RDC signoff；V1-FP-04 仍部分完成。
  EDA license 恢复后，CP/completion-writer coverage 3 seeds × 6 profiles 18/18 PASS（每次 29/29 scenario，
  `cp_cg` 49/49 + 10/10）；Control UVM 9/9，DMA 15-test target exit 0，DMA–SPAD subsystem 3 seeds + URG merge。
  `ai_precheck`（含 A4 reference 1,000 cases、Transformer mapper 与 top smoke）、独立 `ai_smoke`、
  20-case `ai_run`，以及 top mixed-precision DDR E2E UVM 192/192 seed 均 PASS。
  Top URG `e2e_cg` 54/54 variables + 16/16 crosses，四个 AXI transaction group 均 100%；22 assertions 中
  20 success、0 failure/incomplete、2 个 UVM RAL no-attempt。此前 license connection failure 是历史环境阻塞，当前
  interactive Rocky shell 已可执行 VCS/URG/VC Formal；
  仿真证据仍来自 dirty worktree，不是冻结 SHA clean replay。V2/V3/V4 的既有 bounded regressions 有通过证据，
  但 V1–V5 整体验收、全局 coverage disposition 与固定 SHA clean replay 均未完成。权威矩阵与逐条限制见
  `docs/verification/A10_DV_RTM.md`、运行证据见 `docs/verification/A10_DV_RUN_2026-10-16.md`。

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
- 2026-10-14 login-shell VCS refresh：FP dot 三 seed、`dot-core-test`、Control UVM 6/6、DMA UVM
  11/11、Command Processor MVP 三 seed、`ai_smoke` 与 20-case `ai_run` 均通过。Control/DMA/CP
  UVM 的 warning/error/fatal 均为 0。Top smoke 曾报 CNM 可选 telemetry 输出未连接的 `TFIPC`；集成处已显式空接，
  随后重跑 compile 未见 `Warning-`/`Error-`。
- 2026-10-15 license 恢复后的 Control/DMA 当前树复跑：Control 六个 block UVM tests + `control_random_rw_test`
  三个 extra seeds 均 PASS，初次 URG 为 75.18%。bin review 发现读事务默认 `strb=0` 被误计为 WSTRB；覆盖模型现已改为
  write-qualified，并对所有 partial strobe 和缺失 window 添加定向刺激。最新六-test URG functional group 为 34/34
  variables + 4/4 crosses = 100%；DMA 11/11
  tests 均 PASS，适用的 transfer scoreboards 命中、UVM warning/error/fatal=0。随后 DMA random stress 增补 3 seeds，14 个 per-test
  VDB 的 URG merge 列出 14 tests，聚合 `dma_cmd_cg` 为 100%（新增 random seed 自报 70%/seed），但没有
  RTL code/assertion metrics。Control/DMA 详细日志、VDB
  分别位于 `/tmp/nmaforge_a10_control_20261015/` 和 `/tmp/nmaforge_a10_dma_cov_20261015/`；两个模块
  的 coverage closure 仍开放。详见 `docs/verification/A10_DV_BASELINE_2026-10-14.md`。
- 2026-10-15 Control AXI-stability closure 增量（已由下一条更新）：修正 B/R response-delay 以从 VALID 开始计时，修正 driver 在
  negedge 轮询而错过 posedge handshake 的竞态；新增 `control_channel_backpressure_test`，对 busy adapter 上的
  第二笔 AW/W/AR 请求施加真实 READY-low。Rocky 8.10 / VCS `V-2023.12-SP1_Full64` 下 canonical
  `cd dv/block/control/sim && make uvm_regress` 七个测试全部 PASS，UVM warning/error/fatal=`0/0/0`。URG
  `/tmp/nmaforge_a10_control_final_20261015/urg_final/` 的功能组为 34/34 variables + 4/4 crosses；7/7 DUT SVA
  均有非空洞成功、0 failure/incomplete（AW/W/B/AR/R=`7/7/77/4/83`，abort=1，IRQ-known=979）。`axi_lite_reg_if`
  line/cond/branch=`97.30/94.12/90.91%`，write/read FSM transitions=`4/6`、`5/8`；剩余为 in-flight reset-to-idle
  transitions。该七-test 结果已被下一条八-test URG 结果 supersede。
- 2026-10-15 Control in-flight reset 增量：新增 `control_inflight_reset_test`，覆盖写 FSM 的 WR_REQ/WR_RESP_ARM/WR_RESP
  与读 FSM 的 RD_REQ/RD_WAIT/RD_WAIT2 中复位，检查 B/R pending response 与 IRQ 清除及复位后的 VERSION 访问。Rocky 8.10 / VCS
  `V-2023.12-SP1_Full64` 下 `cd dv/block/control/sim && make uvm_regress` 八项全部 PASS，UVM warning/error/fatal=`0/0/0`。
  URG `/tmp/nmaforge_a10_control_reset_irq_20261015/urg_final/` 列出 8 tests；selected functional group 34/34 variables
  + 4/4 crosses（100%）；7/7 DUT SVA 均有非空洞成功、0 failure/incomplete（AW/W/B/AR/R=`10/10/83/5/89`，abort=1，IRQ-known=1102）。
  `axi_lite_reg_if` 的 write/read FSM transitions 达 6/6、8/8；line/cond/toggle/branch=`97.30/94.12/66.76/90.91%`。
  `ai_accel_regs` line/cond/toggle/branch=`50.73/60.53/12.24/25.25%`，仍有代码覆盖缺口；该结果只关闭已识别的 adapter in-flight-reset
  转移，不代表 Control 全面或 A10 sign-off。
- 随后在同一当前工作树执行 `cd dv/subsystem/top_smoke/sim && make ai_smoke` 与
  `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`，均 `TEST PASS`；smoke 为 4 个随机 case、seed `12345`。
  这验证当前已改 RTL 集成路径，但仍是 dirty-worktree 结果，不是 clean commit replay。
- A10 混合精度状态：`0x50` BF16 保持不变，`0x51` FP16 使用共享 command/SPAD/completion 路径；
  mixed-dot UVM seeds `712345/987654/20261014` 各 582/582 PASS（536 numeric + 46 fault/reset），
  共 1,746 笔；numeric/fault-reset/busy-start/response-latency functional coverage 均 100%，peak outstanding=2。
  request-under-stall SVA 为 34,928 attempts、10,761 real successes、0 failures/incomplete。DUT
  line/condition/branch/FSM 为 97.96%/96.50%/92.86%/71.43%；主 `state_r` 5/5 状态、10/10
  transitions 全覆盖。专用 slot-reuse 压力与非法 FSM `4'hf` recovery 均已测试；7 个 condition、4 个
  branch outcomes 和 8 个 pending-error FSM transitions 已按 RTL/接口契约逐项 disposition，无 URG exclusion。
  V1 block verification 完成；disposition 不是形式不可达证明。FP16 directed
  DDR→SPAD→FP→SPAD→DDR 已在 compact AXI memory model 上通过；这不是 DDR PHY/板级证据。详见
  `docs/verification/A10_DV_BASELINE_2026-10-14.md`。
- 2026-10-15 V1/reference quick refresh：`python3.12 -m unittest -v test_fp_reference` 为 19/19 PASS；
  `make -C dv/block/compute/fp/sim dot-core-test` 为 PASS；`make -C dv/subsystem/top_smoke/sim ai_precheck`
  完成 A4 reference 1000 cases、Transformer mapper 30 descriptors/31 tensors 与完整 top smoke `TEST PASS`。
- A10 V2 command processor UVM 扩展：真实 `ai_command_processor` + `ai_completion_writer` 环境
  在 seeds `12345/67890/24680` 下均通过，17/17 directed scenario bins；检查 internal/external fetch route、
  invalid descriptor 不 launch、fetch/compute/dependency-timeout completion、CMDQ/CPLQ empty/full、执行中追加命令与
  首 completion 后消费、completion 四字写入与 tail 顺序、随机 ready stall、partial-write reset 后恢复。随机 ring
  每 seed 12–24 条，并强制混合 `ERR_DESC/ERR_FETCH/ERR_COMPUTE/success`，逐项核对 task ID、launch 与 completion；
  outcome 数分别为 `3/5/7/3`、`6/2/2/2`、`7/5/3/5`，所有队列 drain。direct-start tile 场景检查真实
  `ai_tile_pipeline` 三 tile load/compute/store ownership、两个 buffer 均被使用，并观察到 9 个周期 DMA/compute
  同时活动；这不覆盖 CMDQ descriptor 发起 tile。更多 error×abort/reset 交织、wait-then-release 的产品语义、
  真实 FP watchdog-to-CMDQ/completion 已由 top-level UVM 增量覆盖；更多 error×abort/reset 交织、wait-then-release 的产品语义
  和完整 coverage closure 仍未完成；详见 `docs/verification/A10_DV_RTM.md`。
> **2026-10-15 V2 最新增量：** 在 compute-abort/re-doorbell 场景后新增 `ERR_ABORT` completion 部分写回期间 reset/recovery 场景。focused seed `12345` 与新 seeds `20261040..20261049` 通过；每 seed `20/20` bins、abort/reset marker=`1/1/1/2`、UVM severity=`0/0/0`。word0 被接受、word1 backpressure 时 CPLQ tail 不推进且无下一命令 launch；reset 丢弃部分记录，复位后新任务只成功完成一次。仅改 CP UVM/SVA/Makefile/doc，不改 DUT RTL/ABI；随机 fault×abort×reset 和 V2 整体 closure 仍开放。
- A10 V3 DMA/SPAD 最新进展：三 seed subsystem UVM 已连接真实 AXI DMA、memory fabric、BF16/FP16 dot core 与四-lane CNM；覆盖 DMA/SPAD 争用、GEMV K×M 形状、DMA error drain、CNM abort/reset/recovery，以及 A/B OOB source 与 region-denied destination protection。CNM 保护错误增量的 fresh URG 为 31 assertions、29 success、0 failure/incomplete、2 个 UVM RAL internal 未尝试；选定功能 bins 100%。这些是定向/有界子集，不是完整 code/assertion coverage 或 V3 sign-off；随机 reset phase、并发 parity/protection、广泛 fairness 与真实 CMDQ/completion 生命周期仍开放。详见 `docs/verification/A10_DV_RTM.md`。
- **2026-10-15 A10 续跑刷新：** 当前工作树已有 FP reference 19/19、FP dot UVM 三 seed（每 seed 582/582、peak outstanding=2）、DMA block UVM 11/11、Control 8-test UVM；CP UVM 最新 20/20 scenario bins，focused + 10 seeds 覆盖 abort/partial-completion/reset/recovery；DMA–SPAD 最新新增 10-seed subsystem regression。另有 SPAD arbiter、`ai_smoke`、20-case seeded `ai_run`，以及 V4 192-seed mixed DDR E2E、AR/AW backpressure、协调 reset、FP watchdog/software abort 和两拍 DMA SLVERR 原子性证据。以上是选定的 block/subsystem/E2E slices，不代表 V1–V5 全部闭环；V2 随机 fault×abort×reset 组合、V3 更广 fault/fairness 与真实 CMDQ/completion 生命周期、V4 descriptor/error/reset 全空间及 V5 全局 coverage/mutation/未覆盖项 disposition 仍开放。具体工具、命令和日志见 `docs/verification/A10_DV_BASELINE_2026-10-14.md` 与 `docs/verification/A10_DV_RTM.md`。所有结果来自 dirty worktree，固定 SHA 的 clean-checkout replay 仍待冻结后统一执行。
- A10 V4 top UVM：mixed-precision DDR E2E 覆盖周期性 AR/AW READY-low backpressure、compute-active reset/no-late-completion、DMA response 未返回时协调式 reset，以及真实 FP watchdog/software-abort completion。focused mixed-E2E、DMA 11/11、`ai_smoke`、16-run sweep 与刷新后的 192-seed campaign 均 PASS；当前最新 URG 证据见下方 2026-10-15 watchdog/abort 增量。早前 address-wait campaign 在 `/tmp/nmaforge_mixed_precision_e2e_random_20261015_addrwait2/urg_merged` 记录 AR stall 626 次、AW stall 223 次。AXI gap 每 run 固定配置，并非逐事务独立随机；DUT 与 AXI model 共享 reset。多 outstanding/reset phase、其它 descriptor fields/cases 与全局 coverage closure 仍开放。Targeted 100% 不等于 global closure。详见 `docs/verification/A10_DV_RTM.md`；V4/V5 与 overall A10 仍 open。

- 2026-10-15 A10 V4 watchdog/abort 生命周期增量：top UVM 经 AXI-Lite 分别写 `WATCHDOG=1`、`ABORT=1`；真实 FP engine 向 CMDQ/completion writer 返回 `ERR_WATCHDOG`/`ERR_ABORT`，
  task ID=`0x0702`/`0x0703`、word1=`0x42`/`0x32`，结果哨兵保持且两项 CPLQ tail 均 exactly-once。Focused mixed-E2E、`ai_smoke`、16-run URG sweep 和刷新后的 192-seed random coverage 均 PASS；
  192/192 seed 均有 watchdog/abort marker，UVM warning/error/fatal=0；URG `e2e_cg`=53/53 variables + 16/16 crosses（100%），两个 lifecycle bins 均 1/1，
  报告 `/tmp/nmaforge_a10_fpwatchdog_abort_random_20261015/urg_merged`。V4/V5 与 A10 总体验收仍开放。

- 2026-10-15 A10 V4 abort-drain 刷新（latest）：在软件 ABORT 脉冲期间确认 FP core 仍有 1 笔 SPAD read outstanding，之后在 completion 前 drain 至 0；保持 `ERR_ABORT`、无结果写回、completion exactly-once。Focused mixed-E2E、`ai_smoke`、16-run sweep 与 192/192 seeds 均 PASS，URG `e2e_cg` 53/53 variables + 16/16 crosses（100%），报告 `/tmp/nmaforge_a10_abort_drain_random_20261015/urg_merged`。全局 A10 V4/V5 仍 open。
- 同轮还通过 `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345`；这是 legacy top smoke 的 seeded regression，不代表 V4/V5 总体验收。

## Warning 处理原则

Warning 不等于全部设计错误。优先修复会影响语义、综合、时序或协议的项；
对单进程 FSM、行为级 RAM reset、兼容端口和工具风格提示保留明确 disposition。
当前剩余主要集中于 DMA、matrix prefetch、AXI-Lite 握手和 tile pipeline 的
同周期 retire/reissue；继续修改前必须做 focused regression。

## 能力边界（面试必须如实表述）

已有：RTL、AXI、DMA、队列、SRAM banking/仲裁、CNM/matrix 数据流、UVM/SVA、
SpyGlass lint/CDC、VCS 回归、DC pre-layout 综合及时序分析。

尚未完成：将实验性双时钟 FIFO/command shell 接入产品 top 并完成产品级 CDC/RDC；UPF/Low Power、RDC 收敛、P&R 后布局 STA、
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

### A10 V4 outstanding DMA reset 验证增量（2026-10-15）

- 在 mixed-precision top UVM 中新增单字 DMA read reset probe：DDR 地址 `0x1aa0`，memory-model read response gap 固定为 3；等待 AR 被接受、RVALID 尚未置位且 DMA busy 后断言顶层 `aresetn`。
- AXI4 scoreboard 识别并要求看到 probe AR；任何未预测的 R response 都会触发 scoreboard error。复位后 sequence 检查 memory-model read active/queue/RVALID 均清零、DMA idle、DMA_STATUS 清零、SPAD sentinel 保持，并继续完成 FP16 reset recovery。
- 这是 **协调式系统 reset**：`tb_ai_accel_uvm` 将 DUT 与 AXI memory model 共用一个 `aresetn`，因此不等同于“accelerator 独立复位、外部 DDR/interconnect 继续发出旧 response”的协议验证。产品接口对该独立复位行为尚无契约，不能据本测试声称覆盖。
- 验证证据：focused `uvm_mixed_precision_ddr_e2e_axi_stalls`、六种 order/layout `uvm_mixed_precision_ddr_e2e_regress`、16-run coverage sweep、192-seed random coverage campaign 均 PASS；UVM warning/error/fatal=0。随机 URG 在 `/tmp/nmaforge_mixed_precision_e2e_random_20261015_dmareset/urg_merged`：`e2e_cg` 43/43 variable bins、16/16 cross bins，compute/DMA reset bins 均 1/1；whole-design line/condition/FSM/branch/assert 为 48.25%/43.60%/9.67%/36.39%/33.33%，score 40.67。`ai_smoke` 随后 PASS。
- 该增量只补 top-level 一种 outstanding-read 协调 reset phase，不关闭 V4/V5。AXI address-channel backpressure、多个 outstanding transaction 的 reset phase、AXI responder 跨 reset 行为、全面错误/descriptor 随机和 global coverage disposition 仍待处理。

### A10 V4 AXI AR/AW address backpressure 增量（2026-10-15）

- 更新 `dv/block/dma/env/axi_memory_model.sv` 的可选 ARREADY/AWREADY 反压模型：配置 1/2/3 对应 4 个 `aclk` 周期中连续 1/2/3 个 READY-low 周期；phase counter 不看 VALID，避免 testbench responder 引入 VALID→READY 组合路径。配置为 0 时保留原注册 READY 行为。新增 AR/AW stalled payload stability 检查；实际发生 stall 并完成握手时记录 observed cycle 数。
- 在 E2E vector plan、sequence 与 coverage 增加 AR/AW window 参数；常规回归默认关闭。focused target 与 16-run/192-seed sweep 均要求检查参数 marker、实际 backpressure 以及 UVM severity。
- 通过证据（Rocky 8.10 / VCS V-2023.12-SP1）：`make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_axi_stalls` PASS；`make -C dv/block/dma/sim uvm_regress` PASS（11/11 tests）；`make -C dv/subsystem/top_smoke/sim ai_smoke` PASS；16-run coverage `make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress MIXED_E2E_COV_OUT=/tmp/nmaforge_mixed_precision_e2e_cov_20261015_addrwait2` PASS；192-seed `make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_mixed_precision_e2e_random_20261015_addrwait2` PASS，seeds `20261101..20261292`，192/192 日志 PASS，UVM warning/error/fatal=0。
- 最新随机 URG 在 `/tmp/nmaforge_mixed_precision_e2e_random_20261015_addrwait2/urg_merged`：`e2e_cg` 100%，FP16×BF16 K-length cross 16/16，AR/AW gap coverpoints 各 4/4，compute/DMA reset bins 各 1/1。逐日志统计实际 AR stall 626 次、AW stall 223 次。16-run URG 在 `/tmp/nmaforge_mixed_precision_e2e_cov_20261015_addrwait2/urg_merged`，`e2e_cg` 100%，AR/AW gap coverpoints 各 4/4。
- AXI gap 每个 seed 固定配置，非逐事务独立随机；该模型验证周期性地址 READY backpressure，不等于真实 DDR PHY/互连时序。DUT 与 AXI model 共享 reset，独立 accelerator reset 后旧 response 的行为仍未定义/验证。**这只是 V4 E2E 定向增量，不代表 V4/V5 或全项目 coverage/sign-off 完成。**

### A10 V3 CNM parity 与 DMA 争用（2026-10-15）

- 新增 subsystem testbench parity backdoor fault campaign：真实四 lane CNM 执行期间并发 DDR→SPAD DMA load；每 lane 独立检查 `ERR_PARITY=5`、响应排空、结果写抑制、sentinel 保持与无复位恢复。
- VCS/URG 三 seed `12345/987654/20261014` 全 PASS；每 seed lane×DMA-contention cross 4/4，merged URG `/tmp/nmaforge_a10cnmparity_urg` 为 4/4；UVM warning/error/fatal=`0/0/0`。配套 `ai_smoke` PASS。运行命令和证据边界记录于 `docs/verification/A10_DV_RTM.md` 与 `docs/verification/A10_DV_BASELINE_2026-10-14.md`。
- 故障仅在 VCS behavioral scratchpad RAM testbench 中翻转 parity bit；不是 SRAM macro 故障注入。未修改产品 RTL；V3 随机错误×reset/abort、CMDQ completion 生命周期与系统性 fairness 仍未关闭。

### A10 V3 CNM 两阶段 reset/recovery（2026-10-15）

- 将 CNM reset 定向场景扩展为两个覆盖点：accepted read 尚未收到 response；以及四 lane 各 16/16 responses 已返回、CNM 仍 busy 且结果写尚未发起/接受。
- `make subsystem_regress COV_TAG=a10cnmresetphase2` 在 seeds `12345/987654/20261014` 均通过；UVM warning/error/fatal=`0/0/0`。merged URG `/tmp/nmaforge_a10_cnmresetphase2_urg` 的 `cnm_reset_phase_cg` 两个 bin 各命中三次（100%）。每个 reset phase 均检查 reset 清状态、release 后无 stale response/request/write、空 response queues、destination sentinel 不变，再完成 oracle/readback recovery。
- `ai_smoke` 和 `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 通过。该增量仍是固定 reset checkpoint；随机 reset timing、result write in-progress、与 parity/protection/abort 的组合及 subsystem-wide fairness 未闭环。未修改产品 RTL，A10/V3 仍开放；详见 `docs/verification/A10_DV_RTM.md` 与 `docs/verification/A10_DV_BASELINE_2026-10-14.md`。

### A10 V3 CNM × DMA SLVERR drain overlap（2026-10-15）

- 新增 subsystem scenario：真实四-lane CNM K=8/M=1 dot 运行期间，DMA 接受 4 笔 read；8-cycle responder delay 后，在 newest-first 首个响应 beat `0xF060` 注入一次 SLVERR。
- 首轮 48-cycle delay 时错误晚于 CNM busy 窗口，overlap assertion 正确失败；缩短至 8 cycles 后 focused seed 与三 seed regression 通过。每 seed DMA accepted/completed=4/4、busy/error overlap 非零、DMA outstanding drain 至 0、错误路径无 SPAD grant/write、CNM 四 lane 16/16 responses 和 oracle/readback 正确，随后无 reset DMA recovery PASS。UVM warning/error/fatal=`0/0/0`；URG `/tmp/nmaforge_a10cnmerrphase3_urg` 的 `cnm_dma_error_overlap_cg` 两个 coverpoint 与 cross 均 100%。
- `ai_smoke` 与 `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 均 PASS。该场景是 engine-level activity/error-drain overlap，不是 arbiter contention：因为错误位于 newest-first 首个 response，错误发生前不预期有 DMA SPAD grant。只改 testbench/checker 与文档，没有改产品 RTL；随机 error timing、错误×abort/reset、CMDQ/completion-writer CNM 生命周期和 V3/A10 总体验收仍开放。详见 A10 RTM 与 baseline。

### A10 V3 late SLVERR 与真实 CNM/DMA 争用（2026-10-15）

- 保留首响应 SLVERR control，并扩展为 newest-first 响应流中 0/1/2/3 个成功 burst 后报错的四位置 sweep。通过逐 word sentinel/readback 精确要求 `0/8/16/24` 个合法 DMA word 提交，并检查失败/未提交范围无写入；真实四-lane CNM 同时运行。
- focused `make subsystem_run SEED=12345 COV_TAG=a10cnmerrpos4fix1 VCS=vcs` 与默认 seeds `12345/987654/20261014` 的 `make subsystem_regress COV_TAG=a10cnmerrpos4 VCS=vcs URG=urg URG_REPORT=/tmp/nmaforge_a10cnmerrpos4_urg` 均 PASS，UVM warning/error/fatal=`0/0/0`。每 seed 四场景均 4/4 response drain、CNM oracle 正确、无 reset recovery 通过；提交数为 0/8/16/24 words，后三种场景的 CNM/DMA contention grants 为 1/3/3。URG 四位置 bins 各命中三次，scenario×drain 4/4、overlap×drain 1/1。随后 `ai_smoke` 和 `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 通过。
- 延迟根据错误位置定向设置，以避免 DMA 尚未接受所有预期 AR 就被错误提前终止；该测试是 fixed-position sweep，不是随机 error timing。仍未覆盖 error×abort/reset、独立复位或 CMDQ/completion-writer CNM 生命周期；testbench/checker 与文档增量不修改产品 RTL，也不构成 V3/A10 closure。详见 [A10 RTM](../../verification/A10_DV_RTM.md) 与 [A10 baseline](../../verification/A10_DV_BASELINE_2026-10-14.md)。

### A10 V3 CNM active × DMA abort/drain overlap（2026-10-15）

- subsystem testbench 新增 CNM K=8/M=1 运算期间 DMA load abort：四笔 AXI reads 已接受后、首个 response 前发 abort，并监视 abort pulse 与 CNM busy 的同周期重叠。
- VCS focused run 与三 seed `12345/987654/20261014` 均 PASS；每 seed四笔 accepted reads 均完整完成 response drain、outstanding 回零、highwater=4、DMA SPAD commit=0、32-word destination sentinel 不变，CNM oracle/readback 正确；紧随其后的 DMA clean load 无 reset 恢复。UVM warning/error/fatal=`0/0/0`。URG `/tmp/nmaforge_a10cnmabort1_urg` 的 overlap/drain/no-commit/four-outstanding bins 各 3/3（100%）。`ai_smoke` 和 20-case seeded `ai_run` 通过。
- 这是固定 abort 时刻与首响应延迟的定向组合，只改 testbench/coverage 与文档，不改产品 RTL；随机 abort/error/reset 组合、CMDQ/completion-writer CNM lifecycle、系统性 fairness 与 V3/A10 overall closure 仍开放。冻结 SHA 后仍需 clean-checkout replay。

### A10 V4 两拍 DMA SLVERR 位置/原子提交检查（2026-10-15）

- Top UVM 现对两笔 2-beat/8-word DDR→SPAD DMA burst 分别在首个 R beat 和 RLAST 注入 SLVERR；scoreboard 按 RID 追踪到 RLAST 并检查响应数、唯一错误 beat 和 error-position coverage，sequence 要求 `ERR_AXI_RD` 且八个 SPAD sentinel 均未变化。
- 调查确认 RTL burst buffer 只有在整笔 burst 返回 OKAY RLAST 后才写入 SPAD；因此首拍或末拍错误都取消整笔 burst，不应保留合法响应前缀。首次测试中“末拍错误保留前四个 word”的假设是错误的，已修正为 burst-atomicity checker；没有改 DUT RTL，也不再在 checker 失败时发 PASS marker。
- Rocky 8.10 / VCS/URG V-2023.12-SP1：focused mixed-E2E、六 seed `uvm_mixed_precision_ddr_e2e_regress`、16-run `uvm_mixed_precision_ddr_e2e_cov_regress` 与更新后 192-seed `uvm_mixed_precision_ddr_e2e_random_cov_regress` 全 PASS，所有 run UVM warning/error/fatal=`0/0/0`。192-seed URG `/tmp/nmaforge_a10_errorpos_random_20261015/urg_merged` 中 `dma_error_position_cg` 首拍前/末拍 bins 各命中 192 次；`e2e_cg` 53/53 variables + 16/16 crosses（100%）。Makefile 已把两种错误位置 marker 与 16-run coverage 的 `cp_error_position 2/2` 纳入验收门槛。
- 该项是 directed fault-position/burst-integrity evidence，不覆盖随机 SLVERR×abort/reset 或其它 burst 长度；V4/V5/A10 closure 仍开放。变更在 dirty worktree，冻结 SHA 后仍需统一 replay。

### A10 V2 compute-abort 后 doorbell 恢复（2026-10-15）

- 新增 CP UVM scenario 18：真实 command processor 正在处理 `0x1200` 时，compute endpoint 返回 `ERR_ABORT`。checker 要求只有一条 abort completion、没有自动 launch 下一命令，并确认 CMDQ head/CPLQ tail 停在 1；随后 testbench 以软件 doorbell 发布/唤醒 `0x1201`，它正常 launch/完成，最终 head/tail 均为 2。
- `ai_cp_if.sv` 增加 compute-abort launch-suppression SVA，checker 计数保证 antecedent 非空洞（每 seed 一次）；scoreboard 检查两次 launch、两条 completion、task ID/status/error 和最终队列状态。Makefile 增加 `19/19`、`compute_abort_inputs=1 launches=2 completions=2` 与 UVM severity 零值门槛。
- Rocky 8.10 / VCS `V-2023.12-SP1_Full64`：在 `dv/block/command_processor/uvm` 分别运行 `make regress SEEDS=<seed> OUT=/tmp/nmaforge_a10_v2_compute_abort_20261015_final VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，`<seed>` 取 `12345`、`67890`、`24680`；三 seed 全 PASS，日志为 `/tmp/nmaforge_a10_v2_compute_abort_20261015_final/run_<seed>.log`，每份均 `19/19`、abort marker=`1/2/2`、UVM warning/error/fatal=`0/0/0`。此前 `ai_smoke` 与 20-case `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 也 PASS；它们在最后仅收紧 checker counter 门槛前运行，之后三 seed CP 回归重跑通过。
- 本增量只改 CP UVM、接口 SVA、Makefile 和文档，不改产品 RTL、接口或 ABI。仍未覆盖任意 error×abort/reset 随机交织、并发队列压力的全组合、wait-then-release 产品语义或 V2/V5/A10 closure。结果来自 dirty worktree，冻结 SHA 后需 clean-checkout replay。

### A10 V3 DMA/SPAD 10-seed regression（2026-10-15）

- URG 的两项未尝试 assertion 是 UVM library `uvm_pkg::uvm_reg_map::do_read/do_write`；不属于 DUT assertion。
- 在 `dv/subsystem/dma_spad/sim` 用 canonical `subsystem_regress` target 新跑 seeds `20261020..20261029`，10/10 PASS；每 seed UVM warning/error/fatal=`0/0/0`，VCS compile logs 无 `Warning-`/`Error-`。命令和产物清单见 `docs/verification/A10_DV_BASELINE_2026-10-14.md`。
- URG `/tmp/nmaforge_a10_dma_spad_10seed_20261015/urg`：testbench-selected functional groups 100%；assertion 31 项，29 success、0 failure/incomplete、2 unattempted。此为选定 subsystem regression 的统计，不代表全局 RTL code/assertion coverage 或 V3 signoff。
- 未改产品 RTL。V3/V5/A10 仍开放；结果来自 dirty worktree，冻结 SHA 后需 clean-checkout replay。

### A10 V2 Command Processor 10-seed 扩展（2026-10-15）

- `dv/block/command_processor/uvm` 的 canonical `regress` 新增 seeds `20261030..20261039`，10/10 PASS；每 seed 19/19 scenario bins、随机 CMDQ ring 12–22 条任务 accepted=retired、四类随机 outcome 全命中，compute-abort/re-doorbell marker 命中，UVM severity=`0/0/0`。日志与运行命令见 A10 baseline。
- 只增加同一 UVM suite 的 seed 数，未添加新场景；error×abort/reset 随机交织、wait-then-release 与 V2/V5/A10 closure 仍开放。未改产品 RTL。

### A10 V2 abort × partial-completion reset（2026-10-15）

- 新增 CP scenario 19：compute 返回 `ERR_ABORT` 后，completion word0 接受、word1 backpressured 时触发 reset；断言 CPLQ tail 未推进、无下一命令 launch、reset 丢弃半条 completion；之后重新发布合法 command 并校验成功 completion exactly-once。
- Focused `12345` PASS；新 seeds `20261040..20261049` 10/10 PASS，每 seed 20/20 scenario bins、abort/reset marker=`1/1/1/2`、UVM warning/error/fatal=`0/0/0`。Makefile PASS marker 同时要求 ring 完整 retire 与 outcome 类别全命中。
- 只改 CP UVM/interface SVA/Makefile，无产品 RTL 改动。Directed interaction 不能替代随机 fault×abort×reset；V2/V5/A10 仍开放。命令和边界见 A10 baseline。
