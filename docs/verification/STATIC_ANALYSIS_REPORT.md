# NMAForge RTL 静态分析报告

## 固定 v2 候选复查（2026-11-05，source/test SHA `410b81d`）

VCS 候选回归完成后，使用 SpyGlass V-2023.12-SP1 对当前 A8 project
重新执行 lint。命令为
`PATH="$SPYGLASS_HOME/bin:$PATH" bash dv/spyglass/run_spyglass_a8.sh lint`
（从仓库根目录执行）。结果：exit 0、0 errors、465 warnings、5 infos、0
waivers。Lint 工具执行通过，但没有达到 warning closure。完整摘要和报告副本在
`/tmp/nmaforge_v2_410b81_static_eda.tar.gz`，SHA-256
`178d3267e55304a0c173a9fc89facd547fb7926b516c3c672e1e9ed710dfab60`。

本次 warning 分布：`W415a` 160、`STARC05-2.2.3.3` 141、`W426` 56、
`W287b` 27、`STARC05-2.11.3.1` 22、`W528` 20、`STARC05-2.1.3.1` 11、
`STARC05-2.1.4.5` 11、`W240` 7、`W362` 6，以及
`STARC05-1.3.1.3`、`W216`、`W486`、`FLAT_504` 各 1。`W415a` 与
`InitValUsingNBA` 有重叠，不可将 rule count 当成互斥缺陷数。当前 Matrix
宽度项和 `FLAT_504` 均保留待审，未 waiver。

同候选脚本 CDC 尝试在 `cdc_setup` 无新输出运行 6m10s 后被终止，exit 143；
因此当前 CDC 是 **NOT_RUN**。RDC 在 180 秒上限内推进到 `Ar_resetcross01`
（规则 385/478、约 6.1 GB RSS）后退出码 124，无 RDC 结论。此前同日完成的
结构 CDC 报告仍标出一个 `Reset_sync04` 和一个 `FLAT_504`，但不冒充本次重跑。
其 RTL/约束定位与 disposition 见
[`NMAFORGE_V2_ASIC_READINESS.md`](NMAFORGE_V2_ASIC_READINESS.md)。

## 历史 v2 候选复查（2026-11-05，source/test SHA `145363d`）

当前 v2 RTL/test 候选为 `145363ddff5141177421ee7429fc65f78834830d`，
使用 SpyGlass V-2023.12-SP1 对公开 A8 project 复跑：

| Goal | 结果 | 当前判定 |
|---|---|---|
| lint/lint_rtl | 0 errors、465 warnings、5 infos；exit 0 | 分析执行完成；warning closure 未完成 |
| cdc/cdc_setup | 0 errors、1 warning、9 infos | Setup 有 warning，未 sign-off |
| cdc/cdc_verify_struct | 0 errors、2 warnings、37 infos；unsynchronized crossings=0，convergences=0 | 结构证据；`Reset_sync04` 和 `FLAT_504` 未关闭 |
| rdc/rdc_verify_struct | 180 s timeout，停在 `Ar_resetcross01` | **NOT_RUN**；无 RDC 结论 |

这次检查发现 `ai_parallel_compute_dispatcher.v`、
`ai_tensor_matrix_array.sv` 和 `ai_compute_spad_mux.v` 在 `a8_rtl.f` 中有列出，
但最初未被 `a8_static.prj` 读取。修正 SpyGlass project source list，并将仅供
分析的 `mthresh` 设为 16385 后，lint 已消除 black-box/unsynthesized 错误；
没有修改产品 RTL 或屏蔽规则。完整工具、命令和边界见
[`NMAFORGE_V2_ASIC_READINESS.md`](NMAFORGE_V2_ASIC_READINESS.md)。

Lint/CDC 的完整 RTL view 仍是当前 project 的 256-word/bank 行为 RAM 配置，
不是 512 KiB SRAM 宏映射、综合或物理 sign-off。SpyGlass reports 和数据库
保留在本机忽略目录，没有提交。

## 1. 范围与结论

本报告覆盖 `ai_accel_top` 的公开 SpyGlass project `dv/spyglass/a8_static.prj`，
以及仓库中保存的 lint、CDC、RDC 运行结果。最新可复现运行日期为 2026-10-20，
结论仍是 **pre-sign-off evidence**：lint 有 305 条 warning，CDC 有一条
`Reset_sync04` warning；本次 RDC 检查停滞并被终止，没有结果。高级规则与 RDC
因此仍未 sign-off。

## 2. 最新运行（2026-10-20）

环境为 Rocky Linux 8.10、SpyGlass V-2023.12-SP1。lint/CDC 在当前工作树运行；
工作树包含 `rtl/control/queue/ai_command_processor.v` 中一处显式零扩展修正，
该修正去掉了两条 `MatchFuncArgWidth` warning。只对 SpyGlass 分析使用
`ai_accel_top.SPAD_WORDS_PER_BANK=256`，避免展开完整行为级 Scratchpad；该参数
不是产品配置，也不构成功能或综合验证。

| Goal | 结果 | 当前判定 |
|---|---|---|
| lint/lint_rtl | 0 error，305 warnings，4 infos；exit 0 | **工具执行通过；warning closure 未完成** |
| cdc/cdc_setup | 0 error，0 warning，9 infos | **setup 通过** |
| cdc/cdc_verify_struct | 0 error，1 `Reset_sync04` warning，37 infos；unsynchronized crossings 0，convergence 0 | **结构结果；reset 告警与高级规则仍 open** |
| rdc/rdc_verify_struct | 停在 `Ar_resetcross01` 约 3:49，无 CPU 活动；进程被终止，无报告 | **无结果；未 sign-off** |

lint 和 CDC 命令：

```bash
cd dv/spyglass
PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH bash ./run_spyglass_a8.sh lint
PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH bash ./run_spyglass_a8.sh cdc
```

RDC 的停滞记录来自 clean pushed SHA `ff1e3bb`；之后的零扩展修正没有改动 reset 路径。
该次尝试不能算作 pass、fail 或 license error。完整结果、源版本边界和日志路径见
[2026-10-20 验证记录](A10_DV_RUN_2026-10-20_CURRENT_SNAPSHOT_REFRESH.md)。

## 3. 运行入口

```bash
cd dv/spyglass
./run_spyglass_a8.sh lint
./run_spyglass_a8.sh cdc
./run_spyglass_a8.sh rdc
```

以下是 2026-08-10 保存结果，仅作历史记录；应以第 2 节的 2026-10-20 重跑结果作为当前状态：

## 4. 历史结果摘要（2026-08-10）

| Goal | 已有证据 | 当前判定 |
|---|---|---|
| lint/lint_rtl | 0 error，414 warnings，4 infos；SpyGlass exit code 0 | **历史工具执行结果，非当前计数** |
| cdc/cdc_setup | project/elaboration 完成 | **setup evidence** |
| cdc/cdc_verify_struct | 1 clock、1 reset；scalar/vector crossings 均 0；unsynchronized crossings 0 | **结构 CDC 通过；高级规则未执行** |
| rdc/rdc_verify_struct | 未见结构 crossing 结果；存在 2 个 license errors | **未 sign-off** |

### 4.1 历史 lint 重点告警

- `MatchFuncArgWidth`：`rtl/compute/ai_tensor_sfu_core.v:408`，32-bit 表达式传给 64-bit `clamp_i32` 参数；列为 P0，需显式 signed 64-bit 中间量并做正/负饱和测试。
- `AsyncResetOtherUse`：DMA 数据寄存器路径使用 `aresetn` 的方式被报告；需明确 reset contract，或在 IP 边界实现同步释放。
- `Reset_sync04`：`rtl/memory/ai_spad_arbiter.v:155`，同一时钟域内 reset 被多次同步使用；需统一 reset strategy 或形成窄 waiver。
- `InitValUsingNBA`：180 条，主要是同一 sequential block 中默认赋值和状态更新共存，需逐模块审查，不能批量机械修改。
- `SepStateNextLogic`：20 条，多为单进程 FSM coding style；可作为项目规则 waiver，但必须记录 owner、理由和复审日期。
- `WRN_1024`：11 条，主要是冗余 `$signed` cast。
- `WarnAnalyzeBBox`：私有 SRAM stub 的预期 black-box 告警；公开行为模型与私有 macro flow 应分开管理。

### 4.2 CDC/RDC 限制

CDC 报告显示：

- 1 个用户时钟域 `aclk`、1 个异步低有效 reset `aresetn`；
- scalar/vector unsynchronized crossing 均为 0；
- functional CDC convergence/glitch 项为 0；
- `Reset_sync04 = 1`，不能忽略。

高级规则 `Ac_unsync*`、`Ac_sync*`、`Ac_conv*`、`Ar_converge01` 等因
`Advanced_CDC` license 未运行；RDC 的 `Ar_resetcross01` 和
`Ar_resetcross_matrix01` 也因 license/`rdc_adv_checker` 未运行。故报告只能写成
“基础结构结果无 crossing，完整 CDC/RDC 尚未收口”。

## 5. Closure 门槛

1. 修复或正式 disposition P0/P1 lint 项；
2. 统一 `aresetn` 的 reset release 策略，并重新跑 CDC/RDC；
3. 在具备 `Advanced_CDC` 和 `rdc_adv_checker` 的环境重跑同一 project；
4. 对剩余 warning 建立窄 waiver（rule、instance/path、理由、owner、日期）；
5. 保存 lint/CDC/RDC summary、waiver 和版本/commit，确认 source list 一致。

在上述条件满足前，不能使用“lint 0 error，因此 CDC/RDC 通过”作为 sign-off 表述。

