# NMAForge 验证计划（VPLAN）

版本：A10 / ABI v7.4
更新：2026-10-18
顶层：`rtl/top/ai_accel_top.v`

> 本文最初按 A8 / ABI v7.2 编写，后续阶段描述仍可作为验证路线图；其中带日期的旧 PASS、工具和 coverage 数值是历史记录，不代表 A10 全量验收。A10 的逐项需求追踪见 [`A10_DV_RTM.md`](A10_DV_RTM.md)，近期固定 SHA 的选定复跑见 [`A10_DV_RUN_2026-10-18_MAIN452.md`](A10_DV_RUN_2026-10-18_MAIN452.md)；较早的验证快照见 [`A10_DV_BASELINE_2026-10-14.md`](A10_DV_BASELINE_2026-10-14.md)。

> **2026-10-18 DMA candidate refresh:** The dirty candidate based on parent `d6fa711` expands the DMA block UVM suite from 17 to 19 tests. The exact 4-KiB split and 1/2/3-word WSTRB tail tests, all 19 DMA tests, URG merge, and `ai_smoke` passed; each test reported UVM warning/error/fatal=`0/0/0`. This is a directed DMA boundary increment, not a clean-SHA replay or V3/A10/V5 closure. The prior exact-main 16-test replay below remains valid historical evidence for its own SHA; see the latest [A10 run record](A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-dma-burst-planner-4-kib-split-and-partial-tail-coverage-increment).

> **较早的 A10 快照（2026-10-16；DMA 数字已由下一条更新）：** 当时 DMA UVM 14-test regression 为 14/14 PASS、UVM severity 0、`dma_cmd_cg` 14/14 variables + 5/5 crosses、11/11 DMA DUT SVA attempted/success；DUT-only line/condition/toggle/FSM/branch 为 89.44/68.73/36.94/53.57/85.98%。真实 DMA/SPAD/CNM 3-seed compatibility replay 也通过：8/8 选定功能组 100%，31 assertions 中 29 success、0 failure/incomplete、2 个 UVM RAL no-attempt。Command Processor 最新 direct-config/busy-guard campaign 为 18/18 runs、28/28 scenario bins、`cp_cg` 48/48 variables + 10/10 crosses；CP RTL condition/toggle residual 与全局 disposition 仍 open。顶层 mixed-precision UVM active-reset、watchdog/software-abort 与随机 DDR E2E campaign 有通过证据，latest targeted `e2e_cg` 为 54/54 variables + 16/16 crosses。以上均为当前 dirty worktree 的选定回归证据，不代表 A10 V1–V5 总体验收、固定 SHA clean replay 或全设计 code/assertion sign-off。准确证据边界与复跑命令见 [A10 RTM](A10_DV_RTM.md) 和 [A10 baseline](A10_DV_BASELINE_2026-10-14.md)。

> **DMA 最新复跑（2026-10-18 exact-current-main）：** GitHub `main` SHA `3310d3d45cd9ed0168f7855eb253984c2a38387b` 上，DMA block UVM **16/16 PASS**，每项 warning/error/fatal=`0/0/0`，随机压力 20/20；URG `dma_cmd_cg` 14/14 variables + 5/5 crosses，11/11 named DMA DUT SVA 有真实成功、0 failure/incomplete，另有一个 UVM component-name check 成功、两个 UVM RAL no-attempt。DUT-only `ai_axi128_dma` line/condition/toggle/FSM/branch=`93.48/71.04/36.69/53.57/86.92%`。同一 SHA 的 top `ai_smoke` 通过。DMA RTL 残余覆盖、完整 V3 fault/abort/reset 与 fairness 及 A10/V5 总体验收仍未关闭；详见 [A10 RTM](A10_DV_RTM.md) 与 [2026-10-18 run record](A10_DV_RUN_2026-10-18_MAIN452.md)。

## 1. 验证目标

本计划用于把当前已经完成的 RTL、数字 CNM 数据路径、统一 DMA、队列和 Transformer 微工作负载，推进到可审计、可回归、可交付的验证状态。验证必须同时证明：

1. 功能正确：AXI-Lite 配置、AXI4 DMA、scratchpad、命令/完成队列和所有 opcode 的行为符合 `docs/spec/SPEC_ZH.md` 与 ABI 头文件。
2. 时序协议正确：所有 AXI `valid/ready`、burst、ID、RLAST/B响应、back-pressure 和 reset recovery 场景均无死锁、丢包或重复提交。
3. CNM 正确：四个 bank-local controller/PE 的 partial sum、global reduction、lane mask、预取和 K-group 边界与参考模型一致。
4. 可综合可实现：VCS、SpyGlass、DC、Vivado、Formal、LEC 和 DFT 之间使用同一份 RTL 事实源，并保留可追溯日志。
5. 覆盖率可解释：每一项 coverage 都关联到功能点、测试、断言或约束，不能只报告一个没有定义的百分比。

## 2. 当前基线和已知边界

| 项目 | 当前证据 | 状态 |
|---|---|---|
| VCS smoke/随机回归 | `make ai_smoke`、`make ai_comp`、`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | 已通过的回归基线 |
| CNM A1/A2/A3.1 | A2 四 lane PASS；A3.1 4×4 GEMM benchmark PASS，已接入 smoke | 功能基线已建立 |
| TSMC28 DC | TT/0.9 V/25 °C，4 ns，setup/hold 0 violation，关键路径 3.89 ns | pre-layout 闭合 |
| SpyGlass lint | 0 error、414 warning、4 info | lint 通过，warning 待分类 |
| SpyGlass CDC | 0 unsynchronized crossing、0 convergence | Advanced_CDC license 缺失，非 sign-off |
| SpyGlass RDC | 2 条 license error | 缺少 Advanced_CDC/`rdc_adv_checker`，非 RTL 结论 |
| SAIF 功耗 | 已有生成入口，但 DC 仍有 PWR-414/PWR-415/PWR-428 | 只能作为默认/部分活动率估计 |
| UVM | `dv/uvm/` 提供可复用 AXI agent；`dv/block/dma` 与 `dv/block/control` 是当前 block UVM 主线 | DMA 11 项、control 6 项 VCS 回归均通过；2026-08-27 control 回归的每项 `UVM_ERROR=0`、`UVM_FATAL=0`；functional/code coverage closure 和多 seed 仍未完成 |
| Formal/LEC/DFT | 尚未形成完整环境 | 本计划后续阶段 |

## 3. 验证环境分层

```text
UVM agents/sequence ──> DUT ──> scoreboard/reference model
       │                  │
       ├── assertions ────┤── protocol/安全性质
       ├── coverage ──────┤── 功能/交叉覆盖
       └── bind/formal ───┘── 无约束与有约束性质
```

- VCS/Verdi：动态仿真、波形、覆盖率和回归。
- SpyGlass：lint、CDC、RDC、结构性规则。
- VC Formal 或等效工具：队列、仲裁、AXI 握手、CNM 归约和无死锁性质。
- Formality：综合前后 RTL/网表等价。
- DC/PrimeTime/PrimePower：综合、时序和活动率功耗。
- Tessent/DFT 工具（若环境提供）：scan、压缩、ATPG 和测试覆盖率。

## 4. 阶段计划

### V0：规格冻结与可追溯矩阵

建立 `docs/spec/SPEC_ZH.md`、寄存器头文件、descriptor 表、opcode 表与 RTL 端口的映射表。每个功能点必须有：实现模块、UVM sequence、checker/assertion、覆盖点和通过日志。规格变更必须先改 SPEC，再改 RTL 和测试。

退出条件：无未解释的 ABI 字段；所有 opcode、错误码、队列指针所有权均有唯一描述。

### V1：UVM 基础环境与已完成 block 回归

目录职责：

```text
dv/uvm/
  agent/     AXI-Lite/AXI4 agents、transaction types、virtual interfaces
  env/       environment、scoreboard、coverage、reference-model adapters
  formal/    properties、assumptions、harness 与 proof logs
  sim/       independent VCS filelist 与 Makefile
  tb/        DUT 与 behavioural DDR integration
  tests/     base/smoke/random/stress/error/reset sequences and tests
```

已完成：AXI-Lite control block 的 RAL/寄存器/IRQ/abort 回归，以及 DMA block 的
1D/2D/gather、RID/BID 乱序、4 KiB、abort 和 back-pressure 回归。两者均采用真实
DUT、active responder/driver、scoreboard、functional coverage 和局部 SVA。

后续实施顺序：

1. AXI-Lite agent：寄存器读写、WSTRB、非法地址、控制脉冲、sticky status/IRQ。
2. AXI4 agent：AR/AW/W/R/B 独立通道、back-pressure、乱序 RID、RLAST、4 KiB boundary。
3. Queue/descriptor model：CMDQ/CPLQ head/tail、外部/片上 descriptor source、完成四 word 原子提交。
4. Scratchpad/arbiter model：descriptor/completion 优先、scalar/line/banked/DMA round-robin、保护区和冲突错误。
5. CNM model：四 bank lane mask、每 bank A/B 读取、dot4、local accumulation、global reduce、K-group 和边界长度。
6. A3 model：4×4 tile、K-group 预取、矩阵写回、bias/activation/requant。
7. End-to-end Transformer model：QKV、QKᵀ、softmax、AV、FFN、残差和 KV-cache。

最小 UVM 通过门槛：所有 base/smoke/error/reset tests 通过；scoreboard 无 mismatch；AXI protocol checker 无 failure；功能 coverage ≥ 90%，关键交叉 coverage ≥ 80%。最终 sign-off 门槛应由项目负责人根据测试数量和约束质量确认。

### V2：Formal 属性验证

优先验证不依赖具体神经网络数据的控制性质：

- AXI：`valid` 拉高后保持、无 ready 时 payload 稳定、burst 长度与 RLAST/WLAST 一致。
- Queue：不溢出、不下溢、head/tail 单调、completion tail 仅在四 word 全部写完后推进。
- DMA：每个 RID/BID 只释放一次；abort 后 outstanding drain；4 KiB boundary 不跨越。
- Arbiter：高优先级控制流不被数据流饿死；round-robin 最终授予；grant 与 ready 一致。
- CNM：每个 accepted lane 最终产生且只产生一个 partial sum；global reduce 只在四 lane 完成后提交；busy/done/error 互斥。
- Reset：复位后队列指针、状态机、错误码和 outstanding 状态回到定义值。

Formal 采用分层约束：先 block-level，再 top-level；对 AXI 外部接口只约束协议假设，不约束 DUT 内部实现。每条 property 记录 proof bound、engine、约束文件和结果。

### V3：LEC

在每次 RTL 结构优化、综合脚本变化或 CNM 数据路径改动后运行 LEC：

1. RTL vs RTL：A2/A3 优化版本与 golden/reference 版本。
2. RTL vs synthesized netlist：使用与 DC 相同的宏 blackbox 和库设置。
3. 分层 compare：先 `ai_spad_arbiter`、DMA、CNM core，再 top-level。

等价前必须统一 reset、未初始化状态、blackbox 宏模型和 don't-care 约定。LEC 不能替代 UVM，也不能证明性能或 PPA。

### V4：DFT

- scan chain 插入前确认所有状态寄存器、RAM macro test port 和异步复位策略。
- 为 SRAM macro 定义 MBIST/repair 接口或明确由 SoC memory controller 接管。
- 运行 scan DRC：时钟、复位、test enable、锁存器和不可控端口检查。
- 生成 stuck-at 与 transition ATPG，记录 fault coverage、未测 fault 原因和压缩比。
- 验证 test mode 不会误触发 DMA、队列推进或 CNM 写回。

### V5：PPA 与实现闭环

重新用真实 TSMC28 `.db`/SRAM `.db` 执行 DC；在 SAIF 层次正确映射后再运行 PrimePower。记录时钟、PVT、面积单位、宏数量、setup/hold、dynamic/leakage、活动率来源。后续 P&R 必须补充 CTS、RC、MMMC、IR drop、EM 和 post-route STA，才能称 sign-off。

## 5. 回归矩阵

| 回归 | 命令/工具 | 触发时机 | 通过条件 |
|---|---|---|---|
| 快速 smoke | `make ai_smoke` | 每次 RTL 提交 | `TEST PASS`、无 fatal |
| 编译/波形 | `make ai_comp` | 接口或源列表变化 | VCS 编译 0 error |
| 随机回归 | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | 每日/夜间 | 全 case PASS、seed 可复现 |
| DMA/仲裁定向 | `make ai_spad_arb_run` 等 target | DMA、arbiter 修改后 | directed checker/断言全通过 |
| SpyGlass lint | `./run_spyglass_a8.sh lint` | RTL 合入前 | 0 error；warning 有分类 |
| CDC/RDC | `./run_spyglass_a8.sh cdc/rdc` | 时钟/复位变化 | 无真实 crossing；license 限制单列 |
| Formal | VC Formal batch | 控制逻辑变化后 | 关键性质 proven/covered |
| LEC | Formality batch | 综合或结构优化后 | no non-equivalent point |
| DC/STA | `bash syn/run_ai_accel_28nm_dc.sh 4.0` | 周期性或大改后 | setup/hold 满足约束 |

## 6. 缺陷管理与证据要求

每个失败必须记录：commit、工具版本、命令、seed、日志路径、最小复现、根因、修复、回归结果。许可证失败、工具崩溃和 RTL 失败必须分开分类。不得把 warning、license error 或工具异常写成设计 pass/fail。

## 7. 每日学习与执行节奏

每天先学习一小节 SPEC（寄存器、descriptor、DMA、CNM 或队列），随后为该章节补一个 UVM sequence、一个 checker/断言和至少一个 coverage 点。当天结束运行快速 smoke，并把可公开复现的命令与结果更新到相应验证 README、测试计划或提交说明；不要把私有聊天记录、机器路径或工具缓存放入公开仓库。

## 8. 当前起始任务

当前 A10 验证按 `docs/verification/A10_DV_RTM.md` 的 V1–V5 状态推进，五阶段均未 overall
complete。V1 FP dot 有强 block 证据：三 seed 各 200 random，另加 fault/reset/error-transition，
每 seed 476/476 bit-exact checks、severity 0、peak outstanding=2；fault-format/mode coverage 48/48，
late-B protection 前缀行为通过。RTL coverage
残余已按结构与 SPAD 协议逐项 disposition（非形式不可达证明），冻结 SHA clean replay 仍待执行。V2 command/completion 与
V3 DMA/SPAD 已有多 seed block/subsystem 证据，统一 closure 仍开。VCS compile、`ai_smoke`、
20-case top random、Control UVM、DMA UVM 16/16 tests（14/14 `dma_cmd_cg` variables、5/5 crosses、11/11 named DMA DUT SVA；最新 DUT-only line/condition/toggle/FSM/branch=`93.48/71.04/36.69/53.57/86.92%`）、DMA 更新后 DMA/SPAD subsystem replay（selected groups 100%，含 prolonged RREADY response stalls）及 Command Processor 最新 3-seed × 6-profile coverage campaign（18/18 runs、28/28 scenarios、48/48 functional variables、10/10 crosses）均有通过证据。Command Processor 最新 line/condition/toggle/FSM/branch=`100.00/83.67/10.10/100.00/88.06%`；其 residual condition/branch/toggle 仍待逐项 disposition。以上不是 A10 V1–V5 总体验收或全设计 code/assertion sign-off。

V4 普通 `uvm_mixed_precision_ddr_e2e_regress` 六次 order/layout 回归均 PASS；16-run mixed-FP DDR E2E
K sweep 与 AXI-gap coverage regression 也 PASS。最新 192-seed
`make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress` 使用确定性 seeds `20261101..20261292`，不设置
order/layout/FP16 K/BF16 K override，由 seeded UVM 随机化合法 descriptor 顺序、SPAD layout、K=1..4
长度、operands 和有界 AXI gap 配置。每次运行包含 queued INT8/BF16/FP16、invalid-descriptor validator、DMA
RRESP SLVERR 的首拍/末拍位置、compute-active reset、DMA response outstanding 时协调式系统 reset、FP watchdog
与软件 abort。192/192 seed 日志 PASS，UVM_WARNING/ERROR/FATAL 均为 0；每个 seed 均核对 AXI burst sentinel、
completion、reset/recovery 与 abort drain。最新 URG `/tmp/nmaforge_a10_20261016_e2e_independent_reset_final/urg_merged`
中的 `e2e_cg` 为 54/54 variable bins、16/16 cross bins（100%）；`dma_error_position_cg` 首拍/末拍位置各命中
192 次，compute-active 且 AXI idle 时的 accelerator-only reset / DDR-live bin 也每 seed 命中。Whole-design raw
dashboard 为 43.05%，混合 DUT、TB 与 UVM，不作为 DUT-only 覆盖结论。AXI gap 配置每次 run 固定，并非逐事务
独立随机；reset 只覆盖总线 idle 边界，不验证 AXI transaction 在途时保持 DDR responder 工作。更广
descriptor/error 随机、随机 reset phase、global code/assertion review、mutation 与最终固定提交 replay 仍未完成；
targeted 100% 不代表 V4/V5 或 overall A10 closure。Campaign artifacts
留在 `/tmp`，SpyGlass 工具/许可证边界继续单独记录；`ai_smoke` 保留为相关 RTL 修改后的基线。
> **2026-10-18 DMA write-response slot increment (candidate based on `3014be4`):** The new four-write-ID UVM test and full DMA suite passed 17/17 with per-test UVM warning/error/fatal=`0/0/0`; 20/20 random transfers scored, URG completed, and top `ai_smoke` passed. `ai_dma_write_response_tracker` line/branch coverage reached 100%; residual planner edge bins, full V3, and A10/V5 remain open. This evidence is from a dirty worktree based on parent SHA `3014be4`, not a clean-SHA replay. See the [A10 run record](A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-dma-four-write-id-slot-coverage-increment).
