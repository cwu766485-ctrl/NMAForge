# Compute Cluster 七引擎并发 Parity 验证 — R284

**结果：PASS（限定的并发 Parity testpoint）；Compute Cluster v1.0 总体签核仍 HOLD。** 本轮不改产品 RTL，也不提升 Requirement disposition。

## 固定候选与运行

- Test ID：`TC-CL-R284-SEVEN-ENGINE-PARALLEL-PARITY`
- Run ID：`R284-UVM-CLEAN-3S-20261104`
- 代码/测试 SHA：`08111970888ae8d84a956827389cd41133baa235`
- 对应代码/测试树：`0d6f21126899257d7e7677f3f03d1485692a4ef3`
- clean replay：detached worktree `/tmp/nmaforge_r284_clean_final`，HEAD 与候选 SHA 一致，工作树干净
- 工具：Synopsys VCS `V-2023.12-SP1_Full64`，UVM 1.2
- 执行命令：

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r284_clean_final_replay_3seed \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

同一候选 SHA 的 top checks：

```sh
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

三 Seed UVM clean replay、Top Smoke 和 20-case seeded Top 回归均通过。Top Smoke 输出既有 fixture warning `[LOOP-REROLL-ENABLED]`；UVM 编译没有 `Warning-`、`Error-` 或 `[TFIPC]`，每 Seed UVM severity 为 `0/0/0`。

## 并发故障场景及检查器

用真实 CMDQ 和七个生产计算引擎。每次运行提交七个合法 descriptor，并轮换其顺序，使被测故障引擎最后派发；向其首个操作数 word 注入 SPAD parity fault。每个故障响应观察时七个 engine busy 位均为 `1111111`，并发用例覆盖 Scalar、FP、CNM、Matrix、SFU、Conv、KV 七种 fault owner。

每个故障 owner 的 Checker 验证：

- 被测引擎报告预期 `ERR_PARITY`，其输出 sentinel 保持不变；
- 其它六个引擎输出与独立 Golden 的完整 Memory Image 一致；
- 七条 completion 的 task ID、status、result、element count 与实际 engine owner 对应；
- 所有七个 fault-owner functional bins 命中，coverage `7/7 = 100%`；
- FP 同 owner parity response 撤销未接受读请求的计数增量为 1；CNM lane 0 对应 parity response 撤销计数命中（mask `0001`）。

请求稳定性检查器仍对普通 ready 背压、仍保持 valid 时的地址/数据变化严格报错。只允许同 owner/lane 的 parity response 终止尚未握手的读请求：FP/Matrix 在对应响应采样周期检查，CNM 在同 lane 响应边沿后的下一 monitor sample 检查。该例外有独立计数和定向断言。

| Seed | Fault owner bins | FP cancel delta | CNM cancel mask | Memory scoreboard | Response owner ledger | UVM severity |
|---|---:|---:|---:|---|---|---|
| 20261025 | 7/7 | 1 | `0001` | 146,755 words, 0 mismatch/unknown/stale | 10,678 accepted / 10,658 checked / 20 reset-dropped; 0 mismatch, pending=0 | 0/0/0 |
| 20261026 | 7/7 | 1 | `0001` | 146,755 words, 0 mismatch/unknown/stale | 10,678 accepted / 10,658 checked / 20 reset-dropped; 0 mismatch, pending=0 | 0/0/0 |
| 20261027 | 7/7 | 1 | `0001` | 146,755 words, 0 mismatch/unknown/stale | 10,678 accepted / 10,658 checked / 20 reset-dropped; 0 mismatch, pending=0 | 0/0/0 |

三 Seed 合计七种 owner bins 均命中；Makefile 对并发 owner 数、FP same-owner 撤回、CNM same-lane 撤回和总 coverage 设有硬门槛。

## Requirement Traceability 增量

| Requirement | Disposition | Test ID / Checker | Coverage / 结果 | Run ID / Seed | 证据 |
|---|---|---|---|---|---|
| `REQ-CL-006` | `PARTIAL` | `TC-CL-R284-SEVEN-ENGINE-PARALLEL-PARITY`; passive request-stability monitor | 七个 parity owner 各 1 bin；FP same-owner cancel 1/seed，CNM same-lane cancel lane 0/seed；其它 payload 改变仍严格检查。完整 requester × stall × progress 交叉仍未闭合。 | `R284-UVM-CLEAN-3S-20261104`; `20261025/26/27` | clean seed logs、Testplan 和 SPEC 条款；归档见下文 |
| `REQ-CL-007` / `REQ-PC-007` | `PARTIAL` | `CLUSTER_ENGINE_RESPONSE_OWNER`; accepted-read ledger + CMDQ completion owner checker | 每 Seed 10,678 accepted / 10,658 checked / 20 reset-dropped；route/data/error mismatch=0、pending=0；每次七条 task ID/status/result/element 检查通过。其它 fault/phase/reset 全交叉仍开。 | Same run / seeds | clean seed logs |
| `REQ-CL-008` / `REQ-PC-006` | `PARTIAL` | `CLUSTER_MEMORY_SCOREBOARD`; independent per-engine Golden + fault sentinel checker | 每 Seed 检查 146,755 words，0 mismatch/unknown/stale；七个故障目的区 sentinel 均未被写，六个健康引擎完整输出与 Golden 一致。WSTRB 本轮仍为 full-only。 | Same run / seeds | clean seed logs |
| `REQ-CL-011/012` | `PARTIAL` | completion-owner, status/result/element checker | 七个并发任务按 task owner 验证 exactly-once completion；每次运行七个 parity owner sweep 的 completion/result 均通过。其它 op/shape/错误类仍未完全关闭。 | Same run / seeds | clean seed logs |
| `REQ-CL-017` | `PARTIAL` | parity first-read error prefix checker | 每种引擎的首个源读 parity 结果均无输出写入；尚未覆盖已接受写前缀、Protection、Watchdog、Abort 等完整 fault × phase。 | Same run / seeds | clean seed logs |

因此本轮只增加限定 testpoint 的证据；38-row RTM 总数保持 **27 PASS-SCOPED / 11 PARTIAL**，`CL-DV-v1.0` 继续 **HOLD**。这不是 100% code coverage、全 fault cross closure 或完整签核。

## 证据归档

- 日志与 URG 摘要：`/tmp/nmaforge_r284_final_evidence_20261104.tar.gz`
- SHA-256：`ea7deae68950e563a3232c7eafc142dc755e71b2573f0c766a600ecef677ce02`
- 单 Seed 日志：`/tmp/nmaforge_r284_clean_final_replay_3seed/seed_20261025/run.log`、`seed_20261026/run.log`、`seed_20261027/run.log`
- Compile log：`/tmp/nmaforge_r284_clean_final_replay_3seed/compile.log`
- Top VCS compile emitted the existing fixture warning `[LOOP-REROLL-ENABLED]`; `ai_smoke` passed with 4 random cases, log SHA-256 `0352c8af38abf7b449df35fb015e0d4efd603855eb7468b310466d32cdd464ce`
- `ai_run` passed with 20 random cases and seed `12345`, log SHA-256 `72f3078d8e83121b75254b4a24116eef83c297bd4cb74957904dcae7fa7b72c9`
- Both Top logs and the UVM compile/seed/URG summaries are included in the evidence archive above
