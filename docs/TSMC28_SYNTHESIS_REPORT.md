# A8 TSMC28 Pre-Layout 综合报告

## 1. 结论摘要

A8 AXI-Lite/AXI4 AI 加速器已在 TSMC28 HPC+ 工艺库、TT/0.9 V/25 C 条件下完成
4.0 ns pre-layout Design Compiler 综合。该 run 使用真实标准单元库和 32 个 SRAM 宏，
在当前约束模型下达到 250 MHz 的 setup/hold 闭合。

可严谨表述为：

> A8 RTL 在 TSMC28 HPC+、TT/0.9 V/25 C 的 pre-layout Design Compiler 综合中，
> 于 250 MHz（4.0 ns）实现 setup 与 hold 零违例。

该结论不是布局布线后签核，也不是最终 ASIC Fmax。

### 2026-08-03 当前 RTL 复跑确认

在 matrix-core 后处理函数改为显式参数、完成 28nm macro-aware SpyGlass 配置并加入
CNM A2/A3 RTL 后，使用同一 TT/0.9 V/25 C 标准单元和真实 SRAM `.db` 对当前 RTL
进行了重新综合。最新输出目录为 `syn/out/tsmc28_4_0ns/`，DC 退出码为 0。
4.0 ns 下 setup/hold WNS/TNS 仍为 `0.00/0.00 ns`，32 个 SRAM macro、
138,332 leaf cell、1,245,378.649905 library area units。该结果是当前 CNM RTL
的权威 pre-layout 面积/时序结果。

## 2. 运行配置

| 项目 | 配置 |
|---|---|
| 顶层 | `ai_accel_top` |
| 综合工具 | Synopsys Design Compiler V-2023.12-SP1 |
| 标准单元库 | TSMC28 HPC+ RVT `tcbn28hpcplusbwp7t40p140tt0p9v25c` |
| SRAM 宏 | `TS1N28HPCPL2SVTB4096X32M4MWBASO`，4K x 32、单端口 |
| SRAM 数量 | 32（4 个逻辑 bank，每个 bank 8 个宏） |
| PVT | TT / 0.9 V / 25 C |
| 时钟周期 | 4.0 ns |
| 时钟频率 | 250 MHz |
| Setup uncertainty | 0.10 ns |
| Pre-CTS hold uncertainty | 0.02 ns |
| 输出目录 | `syn/out/tsmc28_4_0ns/` |

## 3. 时序结果

| 指标 | 结果 |
|---|---:|
| Setup WNS | 0.00 ns |
| Setup TNS | 0.00 ns |
| Setup 违例路径 | 0 |
| Hold WNS | 0.00 ns |
| Hold TNS | 0.00 ns |
| Hold 违例路径 | 0 |
| 最大 transition/capacitance 违例 | 0 / 0 |

Setup 关键路径从 scratchpad 的 `spad_macro/Q[0]` 到
`tensor_sfu_u/sum_exp_r_reg[63]`。数据到达时间为 3.87 ns，required time 为
3.87 ns，因而 slack 为 0.00 ns。该路径包含 SRAM 读出延迟、scratchpad 数据选择和
SFU 指数和累加数据通路，是下一轮提高频率时应优先优化的路径。

最差 hold 路径位于 `ai_spad_arbiter` 的 accept 到 response 寄存器路径；数据到达
0.05 ns，required time 0.03 ns，hold slack 为 +0.03 ns。

## 4. 面积结果

| 指标 | 结果 |
|---|---:|
| 总 cell area | 1,245,378.649905 library area units |
| 组合逻辑面积 | 72,476.095923 |
| 时序逻辑面积 | 45,226.803982 |
| Buffer/INV 面积 | 16,721.249571 |
| SRAM macro 面积 | 1,127,675.75 |
| SRAM 面积占比 | 约 90.5% |
| Leaf cell 数 | 138,332 |
| 组合 cell 数 | 112,562 |
| 时序 cell 数 | 25,770 |
| Buffer/INV cell 数 | 17,433 |

除 scratchpad 外，面积最大的主要逻辑模块为统一 128-bit AXI DMA
`ai_axi128_dma_AXI_ADDR_WIDTH64`（38,318.69 units），其次为
`ai_tensor_matrix_core`（16,273.59 units）和
`ai_conv3x3_linebuffer_core`（16,225.57 units）。

## 5. 功耗估计

| 指标 | 结果 |
|---|---:|
| Cell internal power | 22.5908 mW |
| Net switching power | 0.2382 mW |
| Dynamic power | 22.8290 mW |
| Cell leakage power | 1.9733 mW |
| 总功耗估计 | 24.8063 mW |

该功耗报告使用真实 TSMC28 TT/0.9 V/25°C 功耗库，单位有效，但 DC 仍报告
`PWR-414/PWR-415/PWR-428`（primary input、sequential output 和 SRAM black-box
output 未完全注释）。本次 `saif_activity.rpt` 还显示 `report_switching_activity`
命令在当前 DC 版本不存在，不能用该文件证明 SAIF 覆盖率。因此 24.8063 mW 仍是
默认/部分活动率估计，不是 workload 实测或最终 sign-off 功耗。

## 6. 映射与检查结果

- `reference.rpt` 显示标准单元映射完整，包含 TSMC28 inverter、flip-flop、组合门和
  32 个 SRAM macro；未发现 GTECH 或未映射逻辑引用。
- QoR 报告中的宏数量为 32，标准单元 leaf 数为 133,642，说明该 run 不是仅逻辑或
  SRAM black-box 的伪 PPA 结果。
- DC QoR 报告显示 max transition 和 max capacitance 均无违例。
- 2026-08-06 当前 RTL 复跑的 `check_design.rpt` 报告 256 项 potential problem，主要是
  LINT-1/LINT-2、constant output、feedthrough 和 shorted output 等 lint-style 提示。
  它们不阻止综合和时序闭合，但应在下一阶段按
  “预期常量/未用功能端口”与“可能的集成遗漏”分类，形成 waiver 或 RTL 清理记录。

## 7. 结果边界与后续工作

本次为 pre-layout 单角综合，使用 ideal clock 和 wire-load model。尚未执行：

- floorplan、SRAM macro placement 与 power grid；
- CTS、真实 clock skew 和 clock tree power；
- routed parasitic RC、SI；
- MMMC、OCV/AOCV/POCV；
- IR drop、EM、DFT 和 PrimeTime sign-off STA。

因此 250 MHz 是当前 A8 RTL 的可信 pre-layout closure 点，不应表述为 post-layout
sign-off Fmax。若需要提高频率，应从 scratchpad-to-SFU 累加关键路径入手，采用
增加流水级、重定时、缩短累加链或优化 SRAM 读后数据选择的方式，并重新验证功能与
队列/AXI 协议时序。

## 8. 证据文件

- `syn/out/tsmc28_a8_4_0ns/reports/qor.rpt`
- `syn/out/tsmc28_a8_4_0ns/reports/timing.rpt`
- `syn/out/tsmc28_a8_4_0ns/reports/hold_timing.rpt`
- `syn/out/tsmc28_a8_4_0ns/reports/area.rpt`
- `syn/out/tsmc28_a8_4_0ns/reports/power.rpt`
- `syn/out/tsmc28_a8_4_0ns/reports/reference.rpt`
- `syn/out/tsmc28_a8_4_0ns/reports/check_design.rpt`
