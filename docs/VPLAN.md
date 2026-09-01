# NMAForge 验证计划（VPLAN）

版本：A8 / ABI v7.2
日期：2026-08-27
顶层：`rtl/top/ai_accel_top.v`

## 1. 验证目标

本计划用于把当前已经完成的 RTL、数字 CNM 数据路径、统一 DMA、队列和 Transformer 微工作负载，推进到可审计、可回归、可交付的验证状态。验证必须同时证明：

1. 功能正确：AXI-Lite 配置、AXI4 DMA、scratchpad、命令/完成队列和所有 opcode 的行为符合 `docs/SPEC_ZH.md` 与 ABI 头文件。
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
| UVM | `uvm_verif/` 提供可复用 AXI agent；`verif/block/dma` 与 `verif/block/control` 是当前 block UVM 主线 | DMA 11 项、control 6 项 VCS 回归均通过；2026-08-27 control 回归的每项 `UVM_ERROR=0`、`UVM_FATAL=0`；functional/code coverage closure 和多 seed 仍未完成 |
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

建立 `docs/SPEC_ZH.md`、寄存器头文件、descriptor 表、opcode 表与 RTL 端口的映射表。每个功能点必须有：实现模块、UVM sequence、checker/assertion、覆盖点和通过日志。规格变更必须先改 SPEC，再改 RTL 和测试。

退出条件：无未解释的 ABI 字段；所有 opcode、错误码、队列指针所有权均有唯一描述。

### V1：UVM 基础环境与已完成 block 回归

目录职责：

```text
uvm_verif/
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

当前优先级是扩大已经可运行的 block UVM：先补 CMDQ/CPLQ completion、scratchpad
arbiter 与 tensor datapath 的 reference model、scoreboard 和 coverage；随后做多 seed
top-level random/coverage。SpyGlass lint 继续逐项处理真实 error；CDC/RDC 的许可证限制
单独记录。原有 VCS smoke 始终保留为每次 RTL 修改后的快速回归基线。
