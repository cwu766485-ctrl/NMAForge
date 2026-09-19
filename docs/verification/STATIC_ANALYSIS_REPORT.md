# NMAForge RTL 静态分析报告

## 1. 范围与结论

本报告覆盖 `ai_accel_top` 的公开 SpyGlass project `dv/spyglass/a8_static.prj`，
以及仓库中保存的 lint、CDC、RDC 运行结果。当前结论是 **pre-sign-off evidence**，
不是 lint/CDC/RDC sign-off：基础结构检查有结果，但高级 CDC/RDC 规则因许可证缺失未执行，
lint 仍有大量 warning，且存在至少一项需要整改的 reset 结构告警。

## 2. 运行入口

```bash
cd dv/spyglass
./run_spyglass_a8.sh lint
./run_spyglass_a8.sh cdc
./run_spyglass_a8.sh rdc
```

本机 Windows 环境没有可用的 SpyGlass/WSL Linux EDA 环境，因此本次没有声称重新运行成功。
以下数字来自仓库保存的运行记录（SpyGlass V-2023.12-SP1，日期 2026-08-10）：

## 3. 结果摘要

| Goal | 已有证据 | 当前判定 |
|---|---|---|
| lint/lint_rtl | 0 error，414 warnings，4 infos；SpyGlass exit code 0 | **通过工具执行，未 closure** |
| cdc/cdc_setup | project/elaboration 完成 | **setup evidence** |
| cdc/cdc_verify_struct | 1 clock、1 reset；scalar/vector crossings 均 0；unsynchronized crossings 0 | **结构 CDC 通过；高级规则未执行** |
| rdc/rdc_verify_struct | 未见结构 crossing 结果；存在 2 个 license errors | **未 sign-off** |

### 3.1 Lint 重点告警

- `MatchFuncArgWidth`：`rtl/compute/ai_tensor_sfu_core.v:408`，32-bit 表达式传给 64-bit `clamp_i32` 参数；列为 P0，需显式 signed 64-bit 中间量并做正/负饱和测试。
- `AsyncResetOtherUse`：DMA 数据寄存器路径使用 `aresetn` 的方式被报告；需明确 reset contract，或在 IP 边界实现同步释放。
- `Reset_sync04`：`rtl/memory/ai_spad_arbiter.v:155`，同一时钟域内 reset 被多次同步使用；需统一 reset strategy 或形成窄 waiver。
- `InitValUsingNBA`：180 条，主要是同一 sequential block 中默认赋值和状态更新共存，需逐模块审查，不能批量机械修改。
- `SepStateNextLogic`：20 条，多为单进程 FSM coding style；可作为项目规则 waiver，但必须记录 owner、理由和复审日期。
- `WRN_1024`：11 条，主要是冗余 `$signed` cast。
- `WarnAnalyzeBBox`：私有 SRAM stub 的预期 black-box 告警；公开行为模型与私有 macro flow 应分开管理。

### 3.2 CDC/RDC 限制

CDC 报告显示：

- 1 个用户时钟域 `aclk`、1 个异步低有效 reset `aresetn`；
- scalar/vector unsynchronized crossing 均为 0；
- functional CDC convergence/glitch 项为 0；
- `Reset_sync04 = 1`，不能忽略。

高级规则 `Ac_unsync*`、`Ac_sync*`、`Ac_conv*`、`Ar_converge01` 等因
`Advanced_CDC` license 未运行；RDC 的 `Ar_resetcross01` 和
`Ar_resetcross_matrix01` 也因 license/`rdc_adv_checker` 未运行。故报告只能写成
“基础结构结果无 crossing，完整 CDC/RDC 尚未收口”。

## 4. Closure 门槛

1. 修复或正式 disposition P0/P1 lint 项；
2. 统一 `aresetn` 的 reset release 策略，并重新跑 CDC/RDC；
3. 在具备 `Advanced_CDC` 和 `rdc_adv_checker` 的环境重跑同一 project；
4. 对剩余 warning 建立窄 waiver（rule、instance/path、理由、owner、日期）；
5. 保存 lint/CDC/RDC summary、waiver 和版本/commit，确认 source list 一致。

在上述条件满足前，不能使用“lint 0 error，因此 CDC/RDC 通过”作为 sign-off 表述。

