# NMAForge Compute Cluster UVM Testplan（中文）

> **文档编号**：NMA-CL-DV-TP-001\
> **版本**：v1.1 / Parallel Compute Requirement Traceability Baseline\
> **日期**：2026-10-24\
> **对应规格**：[Compute Cluster SPEC v1.1](../spec/COMPUTE_CLUSTER_SPEC_ZH.md)\
> **RTL Baseline**：`9c4aea103a23a42a00fea7bcb092fbe7483e3a15`，A10/ABI v7.4\
> **Owner**：NMAForge DV\
> **状态**：v1.1 需求基线已更新。首个 Dispatcher/SPAD MUX UVM 子系统测试于 2026-10-24 完成三 seed 定向回归；详见第 7 节。它只覆盖本页列出的并行控制和 32-bit SPAD owner 场景，不表示全部 Cluster 数值与四 Bank SPAD 验证完成。

## 0. 范围、冻结及验证分层

- **已实现 C0-P 子集**：真实 `ai_parallel_compute_dispatcher` + 真实 `ai_compute_spad_mux`，七个行为 Engine、descriptor fetch BFM、单周期注册读响应和 completion-writer BFM；验证按序 dispatch/retirement、21 对并发、每引擎单活动槽、SPAD ready stall/owner、CPLQ 满、错误、abort/drain 与 reset recovery。
- **完整 C0**：已实现 C0-P + 真实 `ai_accel_compute_cluster`，检查 Engine 级启动/Done/result 接线及数值/接口交互；当前测试没有实例化它。
- **C1**：完整 C0 + 顶层真实 `ai_spad_arbiter`/Response Routing + 4-Bank Behavioral SPAD；验证真实多客户端竞争、memory image、banked CNM 与 Matrix line 通路。本次新增测试尚未达到 C1。
- **C2 提升**：额外引入独立 DMA Contention Agent 与真实 DMA/SPAD 子系统进行系统竞争；不是 Cluster 本体 Signoff 的必需条件，但作为端到端回归入口。
- C0-P/C1 都遵守真实 CMDQ/CPLQ dispatcher 路径；排除范围为 AXI4 外部 DDR、AXI-Lite 控制 plane 覆盖、Macro child execution 和完整 NPU SoC/实验性 CDC Shell。
- 受控假设：单条 descriptor 只选择一个 Engine；同一 Engine 最多一个活动任务，不同 Engine 可并发且可同拍 Done。CMDQ descriptor 按提交顺序派发，CPLQ completion 保序。软件须避免并发 SPAD 数据冲突。
- **禁止提前合并口径**：Error 目前 Engine-specific；SFU 数值近似/Line WSTRB/复位 Drain 的部分组合没有完整的已批准 Oracle。

## 1. UVM Environment 架构

```text
implemented C0-P: ai_parallel_compute_uvm_test
   |-- virtual interface BFM: descriptors, CMDQ tail, CPLQ head, abort/reset
   |-- real ai_parallel_compute_dispatcher + real ai_compute_spad_mux
   |-- seven behavioral Engine agents with independent service delays/Done
   |-- seeded ready stalls + one-cycle registered SPAD response/error model
   |-- fetch/completion delay models and ordered completion payload ledger
   |-- 21-pair overlap bitmap + launch/result/error/abort/reset checkers

planned C0/C1 extension
   |-- ai_accel_compute_cluster + per-Engine transaction monitors
   |-- real ai_spad_arbiter + 4-bank behavioral scratchpad and memory scoreboard
   |-- CNM bank-lane and Matrix line/banked monitors
   |-- independent numeric reference models, assertion and URG collection
```

**Monitor 事实来源**：Expected 应从命令 Monitor 和不依赖 DUT 的数值/内存模型生成；Observed 来自真实有效握手/Done/Memory；不要只由 Driver 自述接收作为 Checker 输入。每笔读先登记 accepted，再比对实际 response，不能假设 SPAD 有 AXI Read ID。

## 2. 需求映射矩阵（逐条 REQ）

**Status 定义**：`READY`=合法规格足以实现测试，**不是 PASS**；`PARTIAL_SPEC`=可测试已明确子集，其余需解除依赖；`BLOCKED_SPEC`=未经 Design Owner 决策，不得给出 DUT PASS/FAIL；`NOT_RUN/PASS/FAIL/WAIVED` 是执行阶段另行填写的结果。

| Requirement | Feature | Testpoint / Testcase ID | Checker / Oracle | Coverpoint / Cross | Priority / 设计状态 |
|---|---|---|---|---|---|
| REQ-CL-001 | 合法 Launch | idle / single-task；`tc_cl_legal_start` | 命令 Monitor+owner tracker | `cp_engine × launch_phase` | P0 READY |
| REQ-CL-002 | Engine Decode | 0x10-17,20/21,30-39,43/44,50/51逐一启动，select一致；`tc_cl_opcode_dispatch` | engine start观察 + dec独立解码 | `opcode × selected_engine` | P0 READY |
| REQ-CL-003 | 启动参数时序 | Start 前后变更参数；在采样边缘值稳定；`tc_cl_launch_sampling` | cfg monitor + model | `engine × launch_sampling` | P0 READY |
| REQ-CL-004 | 无关字段隔离 | 随机扰动本 Opcode 不使用的字段；`tc_cl_unused_field_noise` | Golden对比和存储写回 | `engine × unused_field_group` | P1 READY |
| REQ-CL-005 | 参数锁存 | Busy期间修改 Launch 参数，完成原任务；`tc_cl_config_latched` | input monitor + memory scoreboard | `engine × mid_task_change` | P0 READY |
| REQ-CL-006 | 请求背压保持 | 32-bit SPAD ready低1/2/8+周期；`tc_cl_spad_req_stability` | 接口 SVA valid&&!ready |=> $stable(payload) 按Abort例外 | `engine × stall_bin × rdwr` | P0 READY |
| REQ-CL-007 | 响应归属 | 已接受读取与响应一一对应，无窜发；`tc_cl_rsp_owner` | Response FIFO/accepted read ledger | `engine × response_delay × owner` | P0 READY |
| REQ-CL-008 | 写回 Memory Image | 每个已接受写后对照 Golden Memory；`tc_cl_memory_commit` | Byte-aware memory scoreboard | `engine × write_count × status` | P0 READY |
| REQ-CL-009 | 四Bank CNM | 各Bank独立grant/错拍响应/parity；`tc_cl_cnm_bank_independent` | per-bank monitor + CNM ref | `bank × rsp_phase × parity` | P0 READY |
| REQ-CL-010 | Matrix SPAD多口 | banked读/普通口/128-bit line与WSTRB；`tc_cl_matrix_interfaces` | bank/line monitors + byte mask scoreboard | `matrix_op × port × wstrb_class` | P0 PARTIAL_SPEC |
| REQ-CL-011 | 独占 Done | 单事务只一个 Engine 完成；`tc_cl_unique_done` | owner scoreboard + onehot0(engine_done) SVA | `engine × completion_status` | P0 READY |
| REQ-CL-012 | Result MUX归属 | done拍比对result/error/code/counters；`tc_cl_result_owner` | engine monitor + done-owner scoreboard | `engine × result_class × error` | P0 READY |
| REQ-CL-013 | Exactly Once | 单启动唯一结束，不重复/漏 done；`tc_cl_completion_once` | start/done lifecycle ledger + watchdog bounded | `engine × completion_count` | P0 READY |
| REQ-CL-014 | 被接受请求/进展 | stall时无假accept；公平响应下有进展；`tc_cl_progress_backpressure` | request ledger + bounded SVA with fairness | `engine × stall_bin × progress` | P0 READY |
| REQ-CL-015 | 正常执行完整性 | 每Opcode数值正确、合法写回、唯一done；`tc_cl_normal_all_ops` | per-op Oracle + memory result checker | `opcode × shape × numeric_class` | P0 READY |
| REQ-CL-016 | 跨Engine切换 | FP→Matrix→CNM→SFU等连续任务防迟到污染；`tc_cl_engine_switch` | owner tracker + stale-response checker | `prev_engine × next_engine × spacing` | P0 READY |
| REQ-CL-017 | 错误后写入前缀 | Parity/Protection/Watchdog/Abort已接受写入正确；`tc_cl_error_prefix` | prefix-memory scoreboard + error model | `engine × fault × phase` | P0 PARTIAL_SPEC |
| REQ-CL-018 | 复位隔离 | Reset后不泄漏Done/写；旧读响应正确丢弃；`tc_cl_reset_stale` | reset epoch ledger / post-reset memory monitor | `engine × reset_phase × pending_reads` | P0 PARTIAL_SPEC |
| REQ-CL-019 | 同时异常恢复 | Abort/Reset及其它异常的合法交错；`tc_cl_fault_races` | fault priority oracle + owner monitor | `engine × fault_pair × phase` | P1 BLOCKED_SPEC |
| REQ-CL-020 | Scalar INT8 | Signed 4lane packed VDOT/GEMV/GEMM/legacyConv,算术边界；`tc_cl_scalar_numeric` | independent bit-exact integer model | `opcode × sign_pattern × saturation` | P0 READY |
| REQ-CL-021 | CNM numerics | 4Bank局部ACC/global reduction, K/M边界；`tc_cl_cnm_numeric` | bank-aware integer golden + memory compare | `op × K × M × bank_phase` | P0 READY |
| REQ-CL-022 | Matrix numerics | tile-major GEMM,batch,transpose,bias,requant/activation；`tc_cl_matrix_numeric` | 4×4 independent int64 reference/sat/check | `op × transA × transB × batch` | P0 PARTIAL_SPEC |
| REQ-CL-023 | SFU numerics | softmax/norm/residual/GELU/SiLU/requant/causal；`tc_cl_sfu_numeric` | per-op Q-domain fixed-point golden;approx bounds | `op × vector_len × extreme × pack` | P0 BLOCKED_SPEC subset |
| REQ-CL-024 | Conv 3×3 | valid stride1,no-padding,edge H/W, signed 8→32；`tc_cl_conv_window` | independent convolution window image scoreboard | `op × H_class × W_class × sign` | P0 READY |
| REQ-CL-025 | KV Cache | token/head/strides READ/WRITE & alias/overflow；`tc_cl_kv_address` | independent 64-bit address math+SPAD image | `op × token × head × stride` | P0 READY |
| REQ-CL-026 | Mixed FP | 0x50/51 odd tail,NaN,Inf,subnormals,RNE,2 outstanding；`tc_cl_fp_numerical` | raw-bit Python oracle+FP bus scoreboard | `format × class × length × rsp_latency` | P0 READY |
| REQ-CL-027 | Engine error codes | 每引擎原始code + 前缀写 + owner；`tc_cl_error_code_table` | engine×fault mapping; unsupported unify blocked | `engine × fault_type × code` | P0 PARTIAL_SPEC |
| REQ-CL-028 | Perf Counters | done拍cycle/element 与 owner 一致、Matrix events；`tc_cl_perf_observability` | sampled event counters + scoreboard | `engine × count_boundary × perf_event` | P1 READY |

### 2.1 v1.1 Parallel Dispatcher / SPAD MUX Requirements

| Requirement | UVM Testpoint / Scenario | Checker / Coverage | Status |
|---|---|---|---|
| REQ-PC-001 | 21 个无序 Engine pair 逐对 overlap | `pair_overlap_seen[20:0]`；七个真实 dispatcher Engine slot 全部同活跃 | C0-P UVM 3 seeds，每 seed 21/21 |
| REQ-PC-002 | 同 Engine 连续任务排队、不同 Engine overlap | SFU 两个任务夹杂其他引擎；重复 active launch 计 owner error，最终检查 | C0-P UVM 3 seeds PASS |
| REQ-PC-003 | CMDQ 按序 dispatch，busy Engine 阻塞其后续 descriptor | 首个五任务序列的 launch ID 与 CMDQ 顺序逐项比较；completion FIFO 同样比对 | C0-P UVM 3 seeds PASS |
| REQ-PC-004 | 差异化 Engine service/fetch latency；CPLQ full 保持记录，软件消费后按序恢复退休 | expected FIFO × completion id/status/result/elements；检查 full hold 与 head advance | C0-P UVM 3 seeds PASS |
| REQ-PC-005 | 两个 Engine 同拍 Done | 定向同步 engine1/2 Done；逐项检查各自 result 和最终 FIFO | C0-P UVM 3 seeds PASS |
| REQ-PC-006 | 32-bit requester 竞争及 owner-only response/error | seeded ready stalls；固定 1-cycle 注册 response（匹配硬件端口）；逐 Engine data/error checker | C0-P UVM 3 seeds PASS；未覆盖完整 arbiter |
| REQ-PC-007 | CNM lane 与 Matrix banked/line 通路独立 | per-bank/line monitor 和 response scoreboard | 既有 block + top smoke，C1 回归复核 |
| REQ-PC-008 | 并发任务共享只读区、输出区彼此隔离 | 真实 memory image scoreboard；配置非法别名为 out-of-contract | C0-P 未覆盖，待 C1 |
| REQ-PC-009 | 多 Engine active 时 abort 停止后续派发并有序 drain | 两 active + 一个 fetch 延迟任务；检查 no-new-launch、三笔 ERR_ABORT FIFO、idle | C0-P UVM 3 seeds PASS |
| REQ-PC-010 | active reset 与 requester error 组合后清空 slot/owner/FIFO | 已接受的 SPAD read 挂起 owner error 时 reset；检查旧响应/错误丢弃与 recovery completion | C0-P UVM 3 seeds PASS；外部 SRAM reset contract仍需 C1 |

## 3. Coverage Model 与 Cross 设计

### 3.1 建议 Coverage Collector

- `cl_launch_cg`：opcode, engine, length_bin, start_gap, config_change；含 opcode×engine、prev_engine×next_engine。
- `cl_spad_cg`：request source, scalar/banked/CNM/line, read/write, grant_wait, response_latency, outstanding_high_water, parity/protection; 含 engine×port×stall_class。
- `cl_numeric_cg`：numeric_class {zero,sign,extreme,overflow_boundary,denormal,NaN,Inf,normal}; 只对该 Engine 已定义的数据类型建 bins；含 op×shape×numeric_class。
- `cl_fault_cg`：abort/watchdog/parity/protection/reset, lifecycle_phase, count_of_accepted_reads, writes_committed_before_error, error_code; 组合有效性需根据 Engine-specific 规格裁剪。
- `cl_ownership_cg`：owner, next_owner, pending_read_depth, completion_status, orphan/duplicate (非法事件必须始终 0，由 checker 报错，不将其“命中”作为覆盖成功)。
- `cl_matrix_cg`：batch/transpose/bias/activation/line_wstrb；`cl_cnm_cg`：bank×response phase；`cl_fp_cg`：bf16/fp16×special class×odd tail×max outstanding；`cl_kv_cg`：token/head×stride class；`cl_conv_cg`：shape×window edge；`cl_sfu_cg`：op×Q/numeric class×approximate branch。

**覆盖率计算口径**：报告逐个 Requirement 的 legal bins/covered bins/unhit bins/blocked bins 与 waiver 证据；BLOCKED_SPEC 从合法覆盖率分母排除时必须同时列出数量，不得只展示 100% 汇总结果。功能覆盖不等于 RTL line/condition/branch/toggle/FSM 全闭环。

## 4. Scoreboard 与 Assertion 契约

| Checker ID | 应检查的性质 | 合法假设 / Failure 表达 |
|---|---|---|
| CL-SB-001 | 每条 descriptor 只生成一个 Engine owner；不同 owner 可同时 active，Done 归属不串线 | 目标 Engine slot 空闲；不要求全 cluster idle |
| CL-SB-002 | 32-bit/Banked/CNM/Line 请求仅在 ready 时作为 accepted 登记 | unaccepted 请求不得产生 Memory Side Effect |
| CL-SB-003 | Read accepted → 同客户端/Bank 返回一次有效 data/error | 最大延迟用于有界 liveness；reset/abort drain 根据合同 |
| CL-SB-004 | success 的 Memory Image 和 Result 与独立 Oracle 逐 bit / 指定容差匹配 | 非 FP 定点模型需要 Numeric Appendix |
| CL-SB-005 | error 的已提交写入前缀合法，无额外幽灵写 | 不能简单规定所有错误全量回滚 |
| CL-SB-006 | 每次命令最多一次 Done，重启后不消费旧 Response | 满足合法 owner 边界，不靠固定 done latency |
| CL-SB-007 | result/error_code/counters 来自同一 Done owner | Error 按当前 Engine 原始编码 |
| CL-SB-008 | performance counters 仅基于已定义事件采样，不能把 latency 模型固定成单一周期 | 对齐 Engine Done 采样周期 |
| CL-SVA-001 | 每条 launch 只选一个 Engine；该 Engine 无活动槽时不得重复派发 | Scheduler assumption 与 DUT assertion 分开报告 |
| CL-SVA-002 | req_valid && !req_ready 时 payload 稳定直到 accepted | 合法 abort/reset 允许终止保持 |
| CL-SVA-003 | read response 无孤儿、不会多于 accepted read、client/Bank 匹配 | Checker 用 Scoreboard Ledger；并非无 ID AXI reorder |
| CL-SVA-004 | 同一 descriptor 只记录一次 owner Done；多个不同 Engine 同拍 Done 必须分别锁存 | bind/passive engine_done 向量并检查 FIFO task owner |
| CL-SVA-005 | reset 后无原任务孤儿写回或 done | Reset 边界要先定义 memory responder 状态 |
| CL-SVA-006 | 受控公平授予/有限响应下任务结束或 watchdog error | 必须有 response fairness 和明确 bound，避免空洞“eventually” |

## 5. Testcase / Virtual Sequence 分层

| Phase | 主要工作 | 第一批建议 Sequence | 进入下一阶段门槛 |
|---|---|---|---|
| C0-A（合法并发接口） | engine dispatch、每 Engine 单 active slot、同引擎排队、同拍 Done、按序退休 | `pc_all_engine_pairs_seq`、`pc_same_engine_queue_seq`、`pc_simultaneous_done_seq` | REQ-CL-001/002/003/005/011/012/013/016、REQ-PC-001～005 |
| C0-B（统一 SPAD） | Monitor 与 Response Ledger、Ready Stall、正常写回 | `cl_spad_backpressure_seq`、`cl_rsp_latency_seq` | 没有孤儿响应/重复接受；Memory image checker 自检通过 |
| C1-A（算术 Golden） | Scalar/CNM/FP 复用已成熟模型；Matrix/SFU/CNN/KV 补齐 Oracle | `cl_numeric_by_opcode_seq`、`cl_matrix_transpose_seq`、`cl_kv_stride_seq` | 每个支持 Opcode 有真实数值/地址检查；未定义容差显式 blocked |
| C1-B（故障/恢复） | error prefix、parity/abort/watchdog/reset、跨任务残留 | `cl_parity_bank_seq`、`cl_abort_prefix_seq`、`cl_reset_recovery_seq` | P0 合法组合执行；未定义多错误优先级不能虚假通过 |
| C0-P（已实现 Dispatcher + SPAD MUX UVM 子集） | seeded ready stalls、连续 descriptor、CPLQ full hold/resume、out-of-order/simultaneous Done、owner-only error、abort/drain、pending-error active reset | `ai_parallel_compute_uvm_test` | REQ-PC-001～006、009～010 定向子集；三 seed 通过，限制见第 7 节 |
| C0/C1（后续扩展） | 接入真实 compute cluster、SPAD arbiter、四 Bank SRAM、CNM/Matrix side-channel、并发 Memory Image | 新增标准 UVM agents/sequences | REQ-PC-007～008 与完整 C0/C1 signoff |
| C2（回归闭环） | 多 Seed、Coverage/Code/Assertions、Mutation、clean SHA | `cl_regression_seq`、`cl_mutation_sensitivity_seq` | RTM 每个 P0 ID 的日志/种子/覆盖/waiver 可定位 |

## 6. 复用现有 DV 资产与新建目录

已有资产：`dv/block/compute/fp/` 的 raw-bit 数值模型、FP UVM/SVA；`dv/subsystem/dma_spad/` 的 CNM/SPAD ledger、数据竞争监控；`dv/block/compute/matrix/` 与 `cnn_kv/` 目前多为 directed 及文档骨架。`dv/subsystem/tensor_datapath/uvm/` 已加入 C0-P UVM 测试；它是 task-based BFM harness，不包含完整 agent/scoreboard 类体系，也未实例化真实 Compute Cluster、SPAD Arbiter 或 SRAM。

建议增量目录：

```text
dv/subsystem/tensor_datapath/
  spec/      cl_testbench_contract.md
  tb/        tb_compute_cluster_uvm.sv, interfaces.sv
  agents/    command_agent/, spad_agent/, fault_agent/
  env/       cl_env.svh, cl_virtual_sequencer.svh
  ref/       engine_models/, reference_memory/
  scoreboard/cl_owner_scoreboard.svh, cl_memory_scoreboard.svh
  coverage/  cl_coverage.svh
  assertions/cl_lifecycle_sva.sv, cl_spad_sva.sv
  tests/     cl_base_test.svh, cl_random_test.svh, sequences/
  sim/       compute_cluster_uvm.f, Makefile
  reports/   README.md (仅索引；仿真产物避免提交巨大 VDB)
```

其中 `uvm/ai_parallel_compute_if.sv`、`ai_parallel_compute_uvm_pkg.sv`、
`tb_ai_parallel_compute_uvm.sv` 和 `ai_parallel_compute_uvm.f` 已实现；下表外的
agent、memory model、coverage collector 与 protocol assertions 仍是后续扩展。

复用规则：优先引用现成 Python/Toffee、SV UVM Transaction 与 Memory Scoreboard，不将单个 Driver 自动产生的 expected 当作独立参考结果。

## 7. Regression Entry / Evidence / Closure

执行第一步先记录固定 Commit SHA、`git status --porcelain`、`vcs -ID`、`urg -version`、`make -n` 和回归环境的库/许可证状态。

**已有入口**（以当前工作树 Makefile 实际可用 Target 为准）：

```bash
make -C dv/block/compute/fp/sim dot-core-test
make -C dv/block/compute/fp/sim dot-uvm-regress
make -C dv/subsystem/dma_spad/sim subsystem_regress
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_tensor_a3_gemm_bench
make -C dv/subsystem/top_smoke/sim ai_a6_datapaths_run
make -C dv/subsystem/tensor_datapath/sim parallel-uvm PARALLEL_SEED=20261024
make -C dv/subsystem/tensor_datapath/sim parallel-uvm-regress PARALLEL_SEEDS='20261024 20261025 20261026'
```

**2026-10-24 执行证据：** `make -C dv/subsystem/tensor_datapath/sim
parallel-uvm-regress PARALLEL_SEEDS='20261024 20261025 20261026'
PARALLEL_OUT=/tmp/nmaforge_parallel_compute_uvm_20261024` 使用 VCS
`V-2023.12-SP1`、URG `V-2023.12-SP1` 通过三 seed。每 seed 均覆盖 21/21
无序引擎对和 5/5 场景组（completion FIFO/full/resume、全引擎 overlap、owner
error、abort/drain、pending owner-error + active reset/recovery）；UVM warning/error/fatal 为
`0/0/0`。Merged URG `groups.txt` 两组均 100%；真实
`ai_parallel_compute_dispatcher` FSM transitions 为 100%（line/condition/
branch 为 84.72/57.55/61.43%），真实 `ai_compute_spad_mux` 的 FSM 为 N/A。
code report 含 BFM/UVM 模块，不作为整个 compute RTL DUT-only coverage。
日志位于 `/tmp/nmaforge_parallel_compute_uvm_20261024/` 下的
`run_20261024.log`、`run_20261025.log`、`run_20261026.log`，URG 位于该目录的 `urg/`。

同日 SFU 命令 `make -C dv/block/compute/sfu/sim random-latency-regress
SEEDS='20261024 20261025 20261026'
OUT_DIR=/tmp/nmaforge_sfu_fsm_converge_multi_20261024` 通过三 seed。每 seed
检查 39/39 个合法编码状态的异步复位探测、39/39 个状态的 Abort-to-ERR
探测，以及 RMSNorm gamma bypass。URG
`/tmp/nmaforge_sfu_fsm_converge_multi_20261024/urg/` 报告
`ai_tensor_sfu_core.state_r` 139/139 transitions（100%）。Compute-only FSM
重解析为 258/339（76.11%）；前次同口径为 185/339（54.57%）。

随后 `make -C dv/subsystem/top_smoke/sim ai_smoke` 通过并打印 `TEST PASS`。
这些是当前工作树运行，不是 clean-SHA replay。UVM test 使用 seeded SPAD
ready stalls 与 completion/fetch delay；SPAD read response 按真实接口固定为
1 周期注册返回，并非可任意乱序或多周期的响应通道。完整 C0/C1 数值、真实
Arbiter、四 Bank、全功能 coverage、mutation 和 clean-SHA replay 仍在计划内。

验收门槛：

1. **Functional**：所有已冻结 P0 合法 Requirement 有至少一个通过的 Directed + 有意义的 Random Cross，并有独立结果 Oracle。高级约束场景可按 spec 合法域分类。
2. **Integrity**：所有被接受读/写和响应归属自洽；Result/Memory/DONE 无重复和幽灵行为；严重 Bug 未关闭不得合并。
3. **Coverage**：合法功能 bins 全部 hit 或经审查 disposition；代码覆盖 line/cond/branch/toggle/FSM、Assertion attempts、有效/空洞计数逐项审查，不机械要求无意义 100% Toggle。
4. **Bug sensitivity**：至少一次独立 Mutation（例如将某 Engine 输出结果的一 bit 翻转）被真正 Scoreboard 检出，保留 failing seed 和恢复后的 passing replay；人工注入不可冒称真实 RTL bug。
5. **Reproducibility**：在固定 SHA、clean checkout、多 Seed 环境留存工具版本、源 hash、filelist、编译日志、run logs、URG/cg merge、SVA 和 waiver/blocked 报告。
6. **Exit**：C0/C1/C2 每一步单独发布 Evidence Manifest；只在没有未解决 P0 Bug/Spec Blocker 时提出 Compute Cluster DV Closure，**不能把 Testplan 完成写成 Verification Complete**。

## 8. Spec OPEN / Verification Blocking Register

| Issue | 影响需求 | 计划处理/状态 |
|---|---|---|
| OPEN-CL-006 — Error ABI | REQ-CL-017/019/027 | 全局统一码 BLOCKED_SPEC；现有 per-engine 原始码 subset READY |
| OPEN-CL-003 — Abort/Reset Drain | REQ-CL-007/014/016/018/019、REQ-PC-009/010 | Abort 合同已由 v1.1 REQ-PC-009 定义；Reset 下外部 responder 的 late response 隔离边界仍需实测/设计 review |
| OPEN-CL-002 — 参数合法范围 | REQ-CL-004/005/020~025 | 子模型按 validator/engine 各自边界；未核实组合 BLOCKED_SPEC |
| OPEN-CL-004 — Matrix Line WSTRB | REQ-CL-010/022 | 常规完整 line 可测；部分掩码及不齐整 WSTRB 需 Design Review |
| OPEN-CL-007 — 同拍故障优先级 | REQ-CL-017/019/027 | 单一故障先测；复合 Fault Cross 在定义前 BLOCKED_SPEC |
| OPEN-NUM-01/02 — fixed-point | REQ-CL-020/023 | bit-exact 与近似 tolerance 分别建契约，不采用任意 float 误差 |
| OUT_OF_CONTRACT — illegal launch | REQ-CL-001/002/011 | Busy Start/多 Select 仅鲁棒性探索，不计产品合规覆盖 |

## 9. 第一周建议任务与审查 Checklist

- 将已通过的 C0-P UVM test 提交到 clean checkout 重放，并核对 v1.1 的 21-pair、FIFO、SPAD-owner、abort/drain 条款与实际 Top 信号连接。
- 复用现有 SPAD Arbiter/Response Router 的 filelist，确认 32-bit、CNM 与 Matrix line 各路径在实际 Top 中的连接，明确 Response latency/Bank ownership。
- 将当前 task-based BFM 拆分为标准 transaction、主动 Agent、被动 Monitor 和独立 Owner Scoreboard；把真实 Cluster/Arbiter 接入 C0/C1。
- 先完成 REQ-PC-007 的 CNM/Matrix side-channel checker、REQ-PC-008 的并发 memory image checker，再用真实 arbiter 复核其余 REQ-PC；数值 oracle 按 REQ-CL-020～028 单独扩展。
- Execution RTM 要列出 38 条 Requirement 的 Test ID、Run ID、Seed、Coverage Bin、Bug/waiver/blocker。没有证据的状态初始值必须是 NOT_RUN。

**状态声明（2026-10-24）**：C0-P UVM 的 REQ-PC-001～006、009～010 定向子集通过三 seed；REQ-PC-007 的 CNM/banked/line 独立通路没有纳入新台架复核，REQ-PC-008 尚无并发 Memory Image scoreboard。该运行不实例化真实 compute cores、`ai_spad_arbiter` 或四 Bank SRAM，也没有 URG code coverage database。完整 C0/C1、全部 38 项 REQ-CL、mutation、清洁 SHA replay 与 signoff 仍未完成。
