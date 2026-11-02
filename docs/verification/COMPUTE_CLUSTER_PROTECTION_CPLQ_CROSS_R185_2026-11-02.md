# R185 — 七引擎 Protection × 满 CPLQ 验证 — 2026-11-02

## 固定候选与范围

- Clean Worktree 测试代码/测试 SHA：`65c83c75c0a8a1518f186a345f414416a6acc2dd`。
- 测试树：`c281484182e997a316c45c1f8d1e6f5a927c8065`。
- 同树 GitHub 分支提交：`39d4f09e0e9fa258aad670471647616ea0317979`。
- 产品 RTL 和 SPEC 未修改；本轮增加真实 CMDQ 路径中的七引擎写回 Protection 拒绝与满 Completion Queue 交叉，并加入强制 Make 结果门。
- Test ID：`TC-CL-R185-ENGINE-PROTECTION-FULL-CPLQ`。
- Run ID：`R185-UVM-PROTECTION-FULL-CPLQ-3S-20261102`、`R185-CHECKER-SENSITIVITY-28-20261102`、`R185-TOP-SMOKE-20-20261102`。

## 实际运行命令

工具为 Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`；VCS license 可用。所有回归均在脱离工作树、固定于上述 SHA 的 Clean Worktree 中运行。

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_20261102_122905_270560338 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_20261102_122905_270560338 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_compute_cluster_mutations_20261102_123025_423877381

cd dv/subsystem/top_smoke/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs make ai_precheck
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs make ai_smoke
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

## 结果

每个 UVM seed 都通过七个真实引擎的写回 Protection 拒绝 × 满 CPLQ 测试点，专项结果为 `engines=7/7 coverage=100.0%`。测试先用三个合法 CMDQ 验证错误占满四槽 Completion Queue 的三个可用位置，再提交一个有效引擎 descriptor，其目的写地址被 Protection 拒绝。检查器确认写请求被拒、引擎排空、处理器因满队列等待、CMDQ/CPLQ 指针保持预期；释放一个 CPLQ 槽后，Protection completion 按序提交并完成 tail wrap。Completion task ID/错误归属正确，所有目标内存哨兵保持不变。

引擎错误映射检查为 Scalar、FP、CNM、Matrix、SFU `0x62`，Conv、KV `0x72`。测试没有假设 SPEC 未规定的错误 completion result/element 字段必须为零。每个 seed 的全局 Memory Scoreboard 检查 69,638 words，63,854 writes，mismatch/unknown/stale epoch 均为 0；UVM warning/error/fatal 为 `0/0/0`。三个 seed 均为 `20261025/20261026/20261027`。

该 compute-only URG merge 得分为 71.89%（line/condition/FSM/branch/assert/group：70.11/64.67/45.04/60.31/72.00/71.89%）。`cluster_cg` 为 64/64；专项七引擎点为 7/7。其他组中有未运行本 workload 覆盖的 AXI/DMA 场景，不能将 71.89% 视为全局覆盖率闭环。Passive checker-sensitivity Make 目标通过 28/28；这些是 Checker 观察敏感性探针，不是 DUT RTL mutation score。Top Smoke 的 mapper precheck 为 86 descriptors / 60 tensors，`ai_smoke` 与 `AI_RANDOM_CASES=20, AI_SEED=12345` 均通过；日志保留现有 `[LOOP-REROLL-ENABLED]` fixture warning。

## RTM 影响与未关闭项

本结果为 `REQ-CL-017`（Protection 行为）、`REQ-CL-019`（合法错误/队列压力下的处置）、`REQ-CL-027`（错误归属与 completion）及 `REQ-PC-006/007`（Memory Image / response-owner 相关审查）增加一条有界证据。它没有覆盖同时运行的跨引擎 owner 竞争，也没有完成通用 fault × phase × reset × backpressure 矩阵。因此不升级任何 Requirement：38 项总体状态仍为 24 `PASS-SCOPED` / 14 `PARTIAL`，`CL-DV-v1.0` 保持 **HOLD**。

本专项不验证每个故障类型、阶段、复位切点及其组合，也不关闭剩余合法 fault cross、全局覆盖率缺口或所有 Matrix FSM 转移。没有以非法内部状态强行制造 FSM bin。

## 证据归档

Logs-only 归档：`/tmp/nmaforge_r185_compute_cluster_evidence.tar.gz`。

SHA-256：`137c2cec3dc13985b13f2e48a18bcf5cdd4d96627989b408ef7d6df358470edc`。

归档包含三份 seed log、compile/URG 报告、28 份 Checker sensitivity log 及 Top Smoke/precheck/20-case log；不包含生成的 VCS/VDB 数据库。
