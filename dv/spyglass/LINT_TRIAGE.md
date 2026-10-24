# NMAForge SpyGlass lint 分类

## 最新运行（2026-10-20）

- 环境：Rocky Linux 8.10，SpyGlass V-2023.12-SP1
- 命令：`cd dv/spyglass && PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH bash ./run_spyglass_a8.sh lint`
- 顶层：`ai_accel_top`；lint-only 覆盖 `ai_accel_top.SPAD_WORDS_PER_BANK=256`
- 结果：exit 0；0 Fatal、0 Error、305 Warning、4 Info；waiver 0
- 报告：`dv/spyglass/a8_static/ai_accel_top/lint/lint_rtl/spyglass_reports/moresimple.rpt`

此轮在 `ai_command_processor` 的 dependency-timeout 结果参数处显式零扩展
16-bit event mask，消除了两条 `MatchFuncArgWidth` 告警；对应 CP 单 seed、top
smoke、20-case seeded top 均通过。剩余 warning 分类如下：

| 规则 | 数量 | 当前处置 |
|---|---:|---|
| `STARC05-2.2.3.3 InitValUsingNBA` | 124 | 默认赋值与条件更新共存；需逐块确认优先级和互斥关系，不批量改写。 |
| `W415a` | 124 | 同一 always 块多次赋值；优先审查 DMA、命令处理和寄存器接口。 |
| `W287b` | 27 | 实例输出未连接；逐项确认有意丢弃、预留接口或真实漏接。 |
| `STARC05-2.11.3.1 SepStateNextLogic` | 20 | 单进程 FSM 风格告警；需要编码政策 disposition 或逐项处理。 |
| `W528` | 8 | 赋值但未读取；确认死逻辑或保留接口后处置。 |
| `STARC05-1.3.1.3 AsyncResetOtherUse` | 1 | DMA reset 用途分类；结合 reset contract 与 CDC/RDC 结果审查。 |
| `W240` | 1 | 行为级 Scratchpad `resetn` 未使用；存储阵列不依赖 reset。 |

合计 305。另有 4 条 Info。`MatchFuncArgWidth` 在本轮报告中为 0。
该运行仍是 lint 工具执行证据，不代表 warning closure 或 sign-off。CDC 同日结果为
setup 0 error/0 warning/9 infos；结构检查 0 error/1 `Reset_sync04` warning/37 infos，
unsynchronized crossing 与 convergence 均为 0。RDC 在 clean pushed SHA `ff1e3bb`
停于 `Ar_resetcross01` 约 3:49 后终止，没有 RDC 结果。完整记录见
[`A10_DV_RUN_2026-10-20_CURRENT_SNAPSHOT_REFRESH.md`](../../docs/verification/A10_DV_RUN_2026-10-20_CURRENT_SNAPSHOT_REFRESH.md)。

## 历史运行记录（2026-09-17）

- 日期：2026-09-17
- 环境：Rocky Linux 8.10，SpyGlass V-2023.12-SP1
- 命令：`cd dv/spyglass && ./run_spyglass_a8.sh lint`
- 顶层：`ai_accel_top`
- 结果：exit 0；`0 Fatal、0 Error、408 Warning、4 Info`
- waiver：0
- 报告：`a8_static/ai_accel_top/lint/lint_rtl/spyglass_reports/moresimple.rpt`

本次运行以 `VCS` 选择行为级 Scratchpad，并仅对 lint 覆盖
`ai_accel_top.SPAD_WORDS_PER_BANK=256`。这是避免 SpyGlass 展开 512 KiB 行为级
数组而 OOM 的分析配置；产品 RTL 默认 32768 words/bank 未改变，不可将该结果解释为
完整容量 SRAM 的功能或综合验证。

## 历史 warning 分类（2026-09-17）

| 规则 | 数量 | 含义与处置 |
|---|---:|---|
| `STARC05-2.2.3.3` | 156 | 顺序块默认赋值后条件覆盖；与 W415a 大量重叠。优先检查同周期多条件是否互斥，不批量机械改写。 |
| `W415a` | 125 | 同一 always 块对寄存器多次赋值。DMA、命令处理、寄存器接口优先做功能审查。 |
| `W426` | 51 | task 修改模块级寄存器。当前为可综合测试/控制编码风格；逐模块重构需配套回归。 |
| `W287b` | 25 | 实例输出未连接。逐项核实有意丢弃、预留接口或真实漏接；真实漏接列为 P1。 |
| `STARC05-2.11.3.1` | 19 | 单进程 FSM。可综合但不符合该风格规则；避免在验证闭环期一次性转换全部 FSM。 |
| `W528` | 17 | 信号赋值但未读取。检查死逻辑、状态残留和保留接口后再删除。 |
| `WRN_1024` | 10 | 对已 signed 操作数重复 `$signed`。仅在定点参考和饱和边界回归覆盖下清理。 |
| `W216` | 3 | integer loop index 使用位选。低风险风格项；改类型可能使规则迁移，暂保留。 |
| `W240` | 1 | 行为级 Scratchpad `resetn` 未使用；存储阵列不依赖 reset，接口为 XPM/行为模型共用。 |
| `STARC05-1.3.1.3` | 1 | 异步 reset 被工具分类为其他用途。DMA 对应块是标准 `posedge clk or negedge resetn`，交由 CDC/RDC 和 reset contract 处置。 |

合计 408。另有 4 条 Info：`W528`、`ElabSummary`、`DetectTopDesignUnits`、
`CMD_param03` 各 1 条。

## 已消除问题

- Scratchpad 四处 `!|` 语法错误。
- fabric 的 `desc_rready`、`dma_rready` 端口方向错误。
- performance monitor 将同步 clear 放进异步敏感列表的问题。
- 未定义 `VCS` 导致错误选择 XPM 分支的问题。
- 完整行为级 Scratchpad 数组造成的 `SYNTH_5273`、`ErrorAnalyzeBBox`、4 个
  `W123`：采用 lint-only 深度参数覆盖解决工具容量问题，未 waiver 规则。
- burst planner 比较宽度和 descriptor FSM 常量宽度共 3 条低风险 warning。

## 验收边界

当前 lint 已达到零 Fatal/Error，但尚未 warning closure。完成 closure 需要：所有
W287b/W528 和重叠赋值项完成功能审查；其余项目落入经评审的编码政策或窄范围
waiver；CDC/RDC 与相关 VCS 回归有可复现结果。Advanced CDC/RDC license 未覆盖的
规则必须单独记录，不能写成 sign-off pass。

2026-09-17 的 CDC 结构验证识别 1 clock、1 reset，报告 0 Fatal/Error、10 Warning、
36 Info，未同步 crossing=0、convergence=0。RDC 在 `Ar_resetcross01` 展开约 11 分钟
后达到 15.4 GiB RSS，为避免 WSL OOM 被中止；将 RDC-only 深度降至 16 后仍在同一
规则增至 10.1 GiB，证明瓶颈不是 Scratchpad 深度。RDC 尚未完成，不能宣称通过。
