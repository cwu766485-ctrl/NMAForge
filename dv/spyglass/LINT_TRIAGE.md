# NMAForge SpyGlass lint 分类

## 运行记录

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

## warning 分类

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
