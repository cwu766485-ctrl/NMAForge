# NMAForge Compute Cluster UVM Testplan（中文）

> **文档编号**：NMA-CL-DV-TP-001\
> **版本**：v1.1 / Parallel Compute Requirement Traceability Baseline\
> **日期**：2026-10-26\
> **对应规格**：[Compute Cluster SPEC v1.1](../spec/COMPUTE_CLUSTER_SPEC_ZH.md)\
> **RTL Baseline**：`9c4aea103a23a42a00fea7bcb092fbe7483e3a15`，A10/ABI v7.4\
> **Owner**：NMAForge DV\
> **状态**：v1.1 需求基线已更新。真实 top Compute Cluster UVM 的 Matrix/SFU 与 Matrix P0-C 切片于 2026-10-26 使用 VCS `V-2023.12-SP1_Full64` 完成三 seed 回归；覆盖 next-K prefetch/MAC overlap、A-tile cache reuse、queued SFU、Abort/Reset 和 recovery。focused covergroup=`65.4%`，merged whole-top URG 不等同 DUT-only coverage。完整 Cluster 验证和 signoff 仍未完成。

## 0. 范围、冻结及验证分层

- **已实现 C0-P 子集**：真实 `ai_parallel_compute_dispatcher` + 真实 `ai_compute_spad_mux`，七个行为 Engine、descriptor fetch BFM、单周期注册读响应和 completion-writer BFM；验证按序 dispatch/retirement、21 对并发、每引擎单活动槽、SPAD ready stall/owner、CPLQ 满、错误、abort/drain 与 reset recovery。
- **真实 top C1 定向切片（PASS，有限范围）**：`dv/uvm` 的 `tb_ai_accel_uvm` 实例化产品 top，实际使用 `ai_accel_compute_cluster`、`ai_spad_arbiter`、response routing 和四 Bank behavioral SRAM。真实 Matrix/SFU 执行 16×16×64 GEMM Golden 对拍、跨 Engine overlap、banked/core SPAD 竞争、按序完成、并发 Abort、活动 Reset、无幽灵写回及 reset 后恢复；三 seed 与精确日志见第 7 节。其它引擎与完整 C1 closure 仍未通过验收。
- **仍未覆盖的 C1 范围**：真实 CNM/FP/Conv/KV/scalar 数值任务、多 Bank CNM/parity 注入、SPAD parity 与 protection 错误交叉、ready/backpressure 收敛、全 feature URG/断言闭环、mutation 与 clean-SHA replay。Compute scoreboard 检查 busy/engine mirror invariant、arbiter read accept→response client ledger 和 reset 时未完成 read drain；具体 GEMM/SFU memory image 与 CPLQ golden 由定向 sequence 检查，尚未抽象为全引擎共享 reference-memory scoreboard。
- **2026-10-25 Matrix controller milestone**：Matrix block regression 已用真实 `ai_tensor_matrix_core` + 16×16 array 做 16×16/32×16 SPAD/GEMM 独立 Golden 对拍；top-level UVM 进一步加入同一真实 Matrix 路径并已三 seed 通过。
- **2026-10-26 Matrix/CNM response ownership**：真实 top smoke 同时运行 CNM GEMV 与 Matrix GEMM，检查不同 response client tag、并发区间、两引擎独立 Golden 和 completion；此 directed smoke 不等同于 C1 UVM sequence，也不关闭全 Cluster REQ-PC-007。
- **2026-10-26 Matrix P0-B multi-read**：真实 Matrix core 支持 2/4 笔 ordered banked reads；block regression 在两个深度分别跑三 seed，检查 metadata 归属、满队列 stall、full-depth abort、pending-response parity/drain 和 recovery。对应 `REQ-CL-010/022` 的 directed block evidence，不计入 real-top UVM functional coverage。
- **2026-10-26 Matrix P0-C prefetch / A-tile cache**：block regression 在 depth 2/4 各跑三 seed，验证 inactive-buffer valid、真实 MAC/prefetch overlap、缓存跨 N tile 命中、K>64 bypass，以及 prefetch parity/abort/watchdog drain、reset invalidation/recovery。真实 top UVM 另以 16×32×64 GEMM 检查 512 个 Golden 输出和 16 次 cache hit；此项计入更新后的 focused covergroup。
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

implemented C1-focused top test (three-seed VCS pass; selected slice)
   |-- production ai_accel_top -> dispatcher -> seven real compute engines
   |-- real ai_spad_arbiter/response routing + four-bank behavioral SRAM
   |-- passive engine/SPAD monitor + busy/response-owner scoreboard + focused coverage
   |-- independent 16x16x64 GEMM golden, SFU outputs, ordered CPLQ, abort/reset
remaining C1 closure
   |-- per-engine numeric/memory scoreboard, CNM parity/bank-lane checks
   |-- backpressure/fault matrix, all-engine functional coverage, mutation
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
| REQ-CL-010 | Matrix SPAD多口 | banked读 2/4 outstanding、response address/operand ownership、普通口、128-bit line 与 WSTRB | block response-metadata FIFO scoreboard + top smoke | `depth × A/B × group × stall/fault_phase`；line WSTRB bins 另计 | 2/4 深度各三 seed block PASS；top smoke PASS；完整 UVM/Line WSTRB spec 仍 OPEN |
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
| REQ-CL-022 | Matrix numerics | 4×4 tile-major GEMM/batch, transpose, bias, requant/activation; 16×16 macro tile and cross-tile execution; ordered read depth 2/4 | independent int64 reference + real Matrix core SPAD memory image | `op × transA × transB × batch × macro_tile × read_depth × fault_phase` | 2/4 depth each three seed: 10 numeric/layout cases + 14 error/recovery cases per seed PASS; selected 16×16×64 real-top UVM slice passed three seeds; broader option coverage remains |
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
| REQ-PC-007 | CNM lane 与 Matrix banked/line 通路独立 | per-bank/line monitor 和 response scoreboard | block arbiter test + 2026-10-26 real top smoke 检查 Matrix/CNM tag、response 与独立 Golden；完整 per-bank/line UVM scoreboard 仍 OPEN |
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
| C1-REAL（定向切片 PASS） | 真实 top、Matrix/SFU GEMM、next-K prefetch/MAC overlap、A-tile cache、跨 Engine 并发、arbiter traffic、按序 CPLQ、Abort/活动 Reset/恢复 | `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh` + passive monitor/scoreboard/coverage | 三 seed PASS；每 seed 512 Golden 输出、16 cache hit、120 prefetch overlap 周期；UVM warning/error/fatal=0/0/0，focused covergroup 65.4%。merged whole-top URG line/cond/FSM/branch/assert/group=`47.54/41.38/10.52/37.70/60.00/19.11%`，包含 DUT/SVA/TB/UVM。Matrix/CNM smoke 是独立 directed test，不计入此 UVM。CNM/FP/Conv/KV/scalar 全 C1、广泛故障/背压、完整 REQ closure 未覆盖 |
| C0/C1（后续扩展） | 其余真实 Engine numerics、CNM/Matrix side-channel、parity/protection/error prefix、backpressure、完整 Memory Image | 扩展 UVM agents/monitor/reference scoreboard | REQ-PC-007～008 与完整 C0/C1 signoff |
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
make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_20261025
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
这些是当前工作树运行，不是 clean-SHA replay。C0-P UVM 使用 seeded SPAD
ready stalls 与 completion/fetch delay；SPAD read response 按真实接口固定为
1 周期注册返回，并非可任意乱序或多周期的响应通道。新的 top UVM 切片已
接入真实 Arbiter/四 Bank 并完成三 seed 执行；全 C1 数值与 coverage、mutation
和 clean-SHA replay 仍未通过验收。

**2026-10-25 真实 top UVM 三 seed 回归：** 新增入口为
`make -C dv/uvm/sim uvm_compute_cluster_regress
COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_final_20261025`；
三 seed `20261025/20261026/20261027` 全部通过。此处历史记录的 focused coverage
55.5% 已被 2026-10-26 的扩展切片更新。每 seed 均打印
`COMPUTE_CLUSTER_REAL_UVM_PASS` 和 `CLUSTER_RESET_RECOVERY_PASS`；scoreboard
报告 observations/busy/overlap/done/errors/reads/responses/orphan/reset_dropped
为 `1217/1070/509/5/1/422/420/0/2`，pending read ledger 为全零。这里的
`errors=1` 是预期的并发 Abort 错误完成，不是 UVM_ERROR；每个 seed 的 UVM
warning/error/fatal 均为 `0/0/0`。定向 covergroup 为 55.5%。合并 URG 有三个
test，其 whole-top line/condition/FSM/branch/assertion/group 为
`45.93/39.46/8.99/35.46/60.00/17.88%`，包含 DUT、SVA、TB 和 UVM，不可当作
DUT-only 或全 cluster 覆盖率。compile log 有一条 `Warning-[TFIPC]`：top
protocol SVA instance 有省略端口，elaboration 为零错误。

同轮 `make -C dv/subsystem/top_smoke/sim ai_smoke` 打印 `TEST PASS`；Matrix
命令 `make -C dv/block/compute/matrix/sim core-random-regress
SEEDS='20261021 20261022 20261023'
CORE_OUT_DIR=/tmp/nmaforge_matrix16_core_regress_vcs_20261025` 三 seed 全部通过
（每 seed 8 个数值/布局 case、12 个 fault case、一个 late-tile-fault case 与恢复）。
Matrix core/array 合并 URG 分别为 `96.17/90.83/65.85/93.52%` 与
`82.35/20.00/N/A/58.82%`（line/condition/FSM/branch）。完整原始日志、VDB
和 URG 位于 `/tmp/nmaforge_real_compute_cluster_uvm_final_20261025/` 与
`/tmp/nmaforge_matrix16_core_regress_vcs_20261025/`。此前 license 不可用的
compile 尝试仅作为历史记录，不影响这次通过结果。

**2026-10-26 Matrix P0-B block regression + benchmark：**
`core-random-regress` 分别以 `OUTSTANDING_DEPTH=2` 和 `4` 跑 seeds
`20261021/20261022/20261023`，两组均 PASS；每 seed 10 个数值/布局 case、14 个
fault/recovery case。depth 2 用例命中 read FIFO full stall；两种深度都在满 outstanding
时测试 abort drain、在多个 response pending 时测试 parity drain，随后跑 clean recovery。
VCS `matrix-size-benchmark` 的 16×16×K32 depth-4 结果为 242 cycles、33.851 MAC/cycle、
13.22% physical-array utilization；同配置串行 baseline 为 357 cycles。真实 top
`ai_smoke` 与 20-case `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 均 PASS。
这些 block 结果不计入 real-top UVM functional covergroup。对应 P0-C 更新见下。
复现命令、profile 和证据边界见[Compute Cluster 升级路线](COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md)第 3.3 节。

**2026-10-26 Matrix P0-C block + real-top UVM：** block VCS 三 seed、depth 2/4
均 PASS；每 seed 17 numerical/layout 与 17 fault/recovery cases。depth-4 core DUT-only
URG line/condition/FSM/branch=`96.59/88.48/66.67/95.48%`，FSM transition 为 40/60，
仍有未覆盖转移。real-top UVM 三 seed 以 Matrix16×32×64 workload 验证 512 个 Golden
输出、16 A-cache hits 和 120 个 prefetch/MAC overlap cycles；queued SFU、活动 prefetch
Abort/Reset、recovery 均通过，UVM warning/error/fatal=`0/0/0`，focused covergroup=`65.4%`。
合并 whole-top URG line/condition/FSM/branch/assert/group=`47.54/41.38/10.52/37.70/60.00/19.11%`，
包含 DUT、SVA、testbench、UVM，不是 DUT-only 或 full-cluster 覆盖。
Cache ON/OFF 在 16×16 physical array 上：16×32×K32 从 469 降至 417 cycles、reads 128→96；
32×32×K64 从 1443 降至 1187 cycles、reads 512→384。固定一拍 behavioral bank response，
GOPS 假定 250 MHz，不是 SRAM macro timing/PPA。命令、完整结果和 artifact 路径见
[Compute Cluster 升级路线](COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md)第 3.4 节。

真实 top UVM 三 seed 复现命令：

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_p0c_expanded_20261026
```

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

- 扩展已通过的真实 top 三 seed UVM 切片到 CNM/FP/Conv/KV/scalar 真引擎任务，并为每个引擎保存独立数值和 memory scoreboard 证据。
- 把 C1 定向切片扩展到 CNM/FP/Conv/KV/scalar 真引擎任务；加入 CNM bank-lane/parity、SPAD parity/protection、请求 backpressure 与相关合法故障组合。
- 将 sequence 内的 SPAD image/completion 自检提升为独立 reference-memory / lifecycle scoreboard；为真实 top monitor 加入接受请求、响应 owner、写入及 Matrix line/WSTRB 观察。
- 再用真实 arbiter 复核其余 REQ-PC；数值 oracle 按 REQ-CL-020～028 扩展，并建立 requirement→testpoint→coverage→run ID RTM。
- Execution RTM 要列出 38 条 Requirement 的 Test ID、Run ID、Seed、Coverage Bin、Bug/waiver/blocker。没有证据的状态初始值必须是 NOT_RUN。

**状态声明（2026-10-26 更新）**：C0-P UVM 的 REQ-PC-001～006、009～010 定向子集通过三 seed。真实 top C1 Matrix/SFU/P0-C 定向切片也已通过三 seed，覆盖 Matrix next-K prefetch、A-tile reuse、真实 GEMM、跨引擎并发、arbiter 流量、Abort、活动 Reset 与恢复；focused covergroup 为 65.4%。新增 Matrix/CNM 并发是 block arbiter test 与 top smoke 的 directed 验证；不并入此 UVM coverage。REQ-PC-007 的完整 CNM/banked/line UVM 独立通路与 parity 检查、REQ-PC-008 全引擎 Memory Image scoreboard、其余 engine numerics、全部 38 项 REQ-CL、mutation、clean-SHA replay 和 signoff 仍未完成。
