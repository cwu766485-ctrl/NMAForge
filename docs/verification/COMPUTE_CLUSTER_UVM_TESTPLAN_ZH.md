# NMAForge Compute Cluster UVM Testplan（中文）

> **R75 当前验证增量（2026-10-30）**：exact clean code/test SHA `969992291732cf694d7de4bdfef2808d4f017d57`。SFU block core 在 GELU 首个源读请求期间改变所有命令输入，三个 seed 均检查 16 个独立 Python Golden 输出位于原 destination，变更 destination 的 sentinel 保持不变；同一 SFU random-latency regression 的 64 向量、fault、abort/reset 和 FSM 检查也通过。SFU DUT-only URG line/condition/FSM/branch 为 `86.98/85.07/100.00/83.33%`。这是 block-core 输入锁存证据，不是 real-top descriptor 覆盖；一次顶层写 descriptor 与 SFU 请求争用并返回 SLVERR 的尝试已放弃，不计为通过。`REQ-CL-005` 仍 PARTIAL，RTM 仍为 24 PASS-SCOPED / 14 PARTIAL，`CL-DV-v1.0` 仍 HOLD。详见 [R75 报告](COMPUTE_CLUSTER_SFU_PARAMETER_LATCH_R75_2026-10-30.md)。

> **R74 当前 real-top 验证增量（2026-10-30）**：exact clean source/test SHA `519ca161f3c2ce8beab78161a88bbdcb6cbcdc61`。真实 Top UVM 在 Matrix 16×32×64 GEMM busy 后改写 descriptor 的 source、destination、M/N/K 与 transpose；launch snapshot 保持原参数，512 个 Golden 输出、512-word 新 destination sentinel 和 completion count 均通过。三个 seed 每个 17,070 个 Memory Scoreboard words、0 mismatch/unknown/stale、UVM severity `0/0/0`，focused applicable testpoint coverage 100%。同 SHA 的 28/28 checker-sensitivity、Top Smoke、20-case seeded top regression clean replay 通过。该点不关闭所有 engine/field 组合，`REQ-CL-005` 仍 PARTIAL；38 项 RTM 仍 24 PASS-SCOPED / 14 PARTIAL，`CL-DV-v1.0` 仍 HOLD。详见 [R74 报告](COMPUTE_CLUSTER_MATRIX_PARAMETER_LATCH_R74_2026-10-30.md)。

> **R73 当前验证增量（2026-10-30）**：exact clean source/test SHA `9d4e9abdba1f745644a485960620fa6bbc4979db`。真实 Top UVM 在三个 seed 上填满 CPLQ、保持第四条有序 completion、在硬件 busy 时推进 `CPLQ_HEAD`，并检查 tail 环绕和四引擎 Golden。该场景暴露并修复了 `cfg_locked` 错误拒绝 busy 期间 `CPLQ_HEAD` 写入的问题；SPEC v1.8 明确消费者推进合同。每 seed 16,286 个 memory words、mismatch/unknown/stale/orphan 均为 0，UVM severity `0/0/0`；`cp_cplq_full` URG bin 1/1。28/28 checker sensitivity、Top Smoke 和固定 20-case top regression 同 SHA PASS。`REQ-PC-004` 保持 PASS-SCOPED，38 项 RTM 仍为 24 PASS-SCOPED / 14 PARTIAL，`CL-DV-v1.0` 仍 HOLD。详见 [R73 报告](COMPUTE_CLUSTER_CPLQ_BACKPRESSURE_R73_2026-10-30.md)。

> **R71 当前验证增量（2026-10-30）**：latest exact clean verification/test SHA `cfcd4dbe69d54beaaa93ac2f350279a6b95cb144`。真实 Top UVM 在合法、SPAD 地址互不冲突的 Matrix/CNM 并发下，每个 Seed 观察到 84 次 Matrix Line stalled-payload stability check、0 violation；512 个 Matrix 输出、16 个 CNM 输出、按序 completion 和每 Seed 10,708 个 memory words 均通过独立 checker，UVM severity `0/0/0`。Top Smoke 与 20-case seeded Top regression 同 SHA PASS。该增量只关闭 REQ-CL-006 的 Matrix Line integration testpoint；REQ-CL-006 仍为 PARTIAL，38 项 RTM 状态仍是 24 PASS-SCOPED / 14 PARTIAL，CL-DV-v1.0 仍 HOLD。见 [R71 报告](COMPUTE_CLUSTER_MATRIX_LINE_STALL_R71_2026-10-30.md)。

> **R65 历史执行记录（2026-10-30）**：该轮 clean verification/test SHA 为 `2ab887ae1b4846512e7673e3d5ea4ce0061c0d0a`；R65 在三个 seed 上对真实七引擎完成 19 个 Protection phase case/seed（source-A 7、source-B 5、writeback 7），Memory Scoreboard 每 seed 检查 5,812 words 且 mismatch/unknown/stale 均为 0，UVM severity `0/0/0`，同 SHA 的 Top Smoke 和 20-case seeded top regression PASS。R65 仅增加命名的 Protection phase testpoint；38 项 RTM 仍为 24 PASS-SCOPED、14 PARTIAL，`CL-DV-v1.0` 仍为 HOLD。证据与 SHA-256 见 [R65 报告](COMPUTE_CLUSTER_PROTECTION_PHASE_CROSS_R65_2026-10-30.md) 和 [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)。
> **R66 checker sensitivity 增量（同一 SHA）**：在上述 R65 exact SHA clean worktree 上重新编译并执行 28 项 Mutation Campaign，address/data/owner/WSTRB、completion error、write-after-error、stale epoch 和七引擎 Done/missing/duplicate Done 均被预期 checker 捕获；Makefile gate 通过。Mutation test 中的 UVM error 是有意注入并由 checker 捕获的预期结果，不是 DUT 回归失败；这不是 RTL mutation score。见 [R66 mutation replay](COMPUTE_CLUSTER_MUTATION_CLEAN_REPLAY_R66_2026-10-30.md)。不改变 RTM 24/14 和 HOLD 状态。

> **文档编号**：NMA-CL-DV-TP-001
> **版本**：v1.8 / Parallel Compute Requirement Traceability Baseline
> **日期**：2026-10-30
> **对应规格**：[Compute Cluster SPEC v1.8](../spec/COMPUTE_CLUSTER_SPEC_ZH.md)
> **当前审查候选**：精确 clean code/test SHA `3fdb22640dc8b3c73e9ff05d3b07c6f0e3e67a28`；R77 新增真实 Top SFU RMSNorm descriptor-latch 检查与回归门禁，产品 RTL/SPEC v1.8 与 `9d4e9ab` 相同。R77 在 divider-wait 且无活动 SFU SPAD 请求时改写 source/destination/length，三 seed 均检查原四元素 Golden、completion、launch snapshot 与新 destination sentinel；focus testpoint 31/31。Matrix R74 descriptor-latch 与 SFU R77 均是 `REQ-CL-005` 的局部证据，不能关闭所有 engine/field 组合。R75 仍为独立 block-core 证据。先前 SHA 均保留各自范围。38 项 RTM 仍为 24 PASS-SCOPED、14 PARTIAL、0 BLOCKED_SPEC、0 NOT_RUN；CL-DV-v1.0 仍 HOLD。**不得据此宣称已签核。** 当前控制文件是[Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)、[Sign-off Readiness](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md)、[Benchmark](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md)与[Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md)。旧 SHA/旧计数保留为历史运行记录。
> **Owner**：NMAForge DV\
> **R33 覆盖率更新（2026-10-28）**：coverage/checker commit `cb9717eb853dc507f4a7e4d188c7bd840160c955` 在干净 worktree 三 seed 回归通过；focused applicable testpoint group 为 100%（URG 29/29 variables）。Completion read-response 因 writer 仅写而显式排除为 N/A；test 和 Makefile gate 均检查其 hit 数为 0。历史 raw 29/30（98.96%）仍保留；此结果不改变 38 项 Requirement 中 14 项 PARTIAL 的状态。详见 [Execution RTM R33](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)。\
> **Stage A 历史状态**：在 tested SHA `03bf257afdca9b0041ff80b6d30cbaf8107cf7e0` 完成的原始数据见 Stage A 报告。当前逐项结论以 2026-10-30 RTM addendum 和 Readiness Report 为准。完整 fault cross、发布快照回放、ASIC PPA 与产品 signoff 仍未完成。

> **2026-10-30 Matrix Line 合同增量**：SPEC v1.5 冻结当前 RTL 的 full-strobe/16-byte alignment、unaligned-to-line scalar fallback 和 protection-prefix 语义。`MATRIX-LINE-001` 检查 full WSTRB、Line 地址对齐、背压期间请求稳定、4-byte 对齐但非 16-byte 对齐的 scalar fallback 和首笔 Line protection error。R48 找出并修复 testbench 汇总计数器被 DUT reset 清零的问题；R49 三 Seed 全通过，每 Seed 312 次 stall-stability 检查，Golden/output checks 通过。此结果关闭 Matrix Line 接口子项，不关闭 REQ-CL-010/022 的其他交叉覆盖要求。

> **2026-10-30 Scalar INT8 数值增量**：SPEC v1.6 冻结共同的 packed Dot、bias/shift/activation/saturation 顺序。R52 在测试 commit `dde7806` 的 clean worktree 上三 Seed 通过 13 个独立 Golden 用例，覆盖 VDOT/GEMV/GEMM、数值边界、完整输出 Memory Image 与真实读写反压；只使用已分配 Activation 0/1/2。R51 的 reserved Activation=3 bin 已作废并排除。R52 关闭 `OPEN-NUM-01` 的合同歧义和所测子集；legacy Conv 和 REQ-CL-020 更广的 opcode/shape 域仍为 PARTIAL。

> **2026-10-30 KV 地址与 Protection 增量**：SPEC v1.7 冻结 32-bit word 地址、base/stride 对齐及溢出规则。R53 在固定 SHA `f916874` 的 clean worktree 上三 Seed 命中 10/10 拒绝测试点与 `0x7fffc` 最后合法 SPAD word 读写边界；越界/未对齐输入均在首个 SPAD 请求前报 `ERR_CONFIG=1`，无读写副作用。KV DUT-only URG 为 line/condition/FSM/branch `100/98.77/73.33/96.97%`，未命中 FSM transition 未作不可达 waiver。R54 在固定 top-test SHA `f24c538` 的 clean worktree 验证真实 CMDQ KV source read、KV owner 的 Protection denied write、error completion `2/7` 和 destination sentinel。详见 [R53 地址报告](COMPUTE_CLUSTER_KV_ADDRESS_R53.md) 与 [R54 Protection 报告](COMPUTE_CLUSTER_KV_PROTECTION_R54.md)；其他 Engine descriptor contract 与 KV stride/alias 覆盖仍开放。

> **2026-10-30 clean replay R55–R58**：在 `ded9d92` detached worktree 上，七引擎 top UVM 三 Seed 每 Seed 5,368 words 对拍、0 mismatch/unknown/stale/orphan，100% applicable focused testpoints，UVM severity `0/0/0`；25/25 passive observation mutation catches；Matrix depth-4 每 Seed 18 Golden/layout + 35 fault/recovery cases 和 312 次 Line stall-stability；单独编译的 prefetch-off fallback 三 Seed 全通过。Matrix enabled profile DUT-only URG line/condition/FSM/branch `97.08/91.05/93.55/95.52%`，仍是 49/53 FSM；R55 compute-only AXI AR/AW properties有未命中，不代表 AXI E2E closure。详细日志、哈希和 SVA disposition 见 [R55–R58 clean replay report](COMPUTE_CLUSTER_CLEAN_REPLAY_R55_R58_2026-10-30.md)。

> **2026-10-30 Top Smoke clean replay R59**：验证 harness SHA `ded9d92` 上，`make ai_smoke` 与 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 均 PASS；真实 CMDQ KV Protection denial 检查 completion `status/error=2/7` 和源/目的 sentinel，Smoke 还完成 mapper precheck、reset recovery 与 86-descriptor workload。保留 fixture `LOOP-REROLL-ENABLED` 编译 warning。详细日志哈希见 [R59 replay report](COMPUTE_CLUSTER_TOP_SMOKE_REPLAY_R59_2026-10-30.md)。本次不改变 38 项 RTM 的 24 PASS-SCOPED / 14 PARTIAL 和 CL-DV-v1.0 HOLD 状态。

> **2026-10-30 All-engine parity clean replay R60**：验证/test SHA `2768843` 的 clean worktree 上，真实 top UVM 三 Seed 每 Seed parity 18/18，覆盖 INT8/Matrix/CNM/BF16/SFU/Conv/KV 与 CNM 四 lane；UVM severity `0/0/0`、5,445 个 checked words、无 memory mismatch/unknown/orphan。25/25 passive observation mutation、`make ai_smoke` 和 20-case seeded top regression 均 PASS。Conv/KV error-state 完成时序由 owner-specific 单周期 checker grace 检查；产品 RTL/SPEC 未变。Focused applicable testpoints 为 100%，但更广 Engine × Fault × Phase × Abort/Reset 仍未关闭，38 项 RTM 仍是 24/14，CL-DV-v1.0 仍 HOLD。详见 [R60 report](COMPUTE_CLUSTER_ALL_ENGINE_PARITY_R60_2026-10-30.md)。

## 0. 范围、冻结及验证分层

- **已实现 C0-P 子集**：真实 `ai_parallel_compute_dispatcher` + 真实 `ai_compute_spad_mux`，七个行为 Engine、descriptor fetch BFM、单周期注册读响应和 completion-writer BFM；验证按序 dispatch/retirement、21 对并发、每引擎单活动槽、SPAD ready stall/owner、CPLQ 满、错误、abort/drain 与 reset recovery。
- **真实 top C1 定向切片（PASS，范围有限）**：`dv/uvm` 的 `tb_ai_accel_uvm` 实例化产品 top，实际使用生产 dispatch、`ai_spad_arbiter`、response routing 和四 Bank behavioral SRAM。三 seed 检查 Matrix/CNM owner/address ledger、七个生产引擎各自的数值与 completion、请求背压、Matrix/SFU 同时 Abort、活动 Reset/recovery；精确日志见第 7 节。
- **C1 新增验证（Stage A clean SHA，PASS，范围有限）**：真实 top UVM 加入 byte-addressed reference SPAD scoreboard、accepted-owner/epoch 检查、DMA SPAD-to-DDR response bin 和 14 项 seeded parity cross；三 seed 共 42 项全部检查预期错误完成与 no-writeback sentinel。每 seed 比较 4,852 words，无 mismatch/unknown/stale response，UVM warning/error/fatal=`0/0/0`。Focused functional coverage=`99.0%`；DMA response-client PASS，completion read-response 因 write-only writer 显式 WAIVED/N/A。详见 Stage A 报告。
- **仍未完成的 C1 范围**：当前仍是 directed engine Golden sweep，不等于所有 opcode/configuration 的完整随机 REQ closure。SPAD parity/protection × engine/phase 的全组合和全部 38 项 REQ closure仍开放。SPEC v1.5 已将 Matrix partial/zero WSTRB 划为不支持行为；R49 通过 Matrix Line 合同检查，但更广的合法 fault × phase × engine 和其他 REQ closure仍未完成。最新 25/25 mutation suite 只证明 passive checker sensitivity，不是 RTL mutation score；具体 SHA 与 disposition 见当前 Execution RTM。
- **2026-10-25 Matrix controller milestone**：Matrix block regression 已用真实 `ai_tensor_matrix_core` + 16×16 array 做 16×16/32×16 SPAD/GEMM 独立 Golden 对拍；top-level UVM 进一步加入同一真实 Matrix 路径并已三 seed 通过。
- **2026-10-26 Matrix/CNM response ownership**：真实 top smoke 与真实 top UVM 都运行 disjoint-SPAD 的 CNM GEMV + Matrix GEMM，并检查不同 response client tag、并发区间、两引擎 Golden 和 completion；该定向子集不关闭全 Cluster REQ-PC-007。
- **2026-10-26 Matrix/CNM top UVM 增量（已执行）**：真实 top sequence 加入 disjoint-SPAD 的 16×32×64 Matrix + 16-output CNM GEMV；逐 lane 检查 CNM A/B accepted address、四 Bank response mask、tag 3/5 demux、accepted-read ledger、16 个输出与有序 completion。三 seed PASS，且独立 Matrix 基线检查 512 个 Golden 输出和 16 次 A-tile reuse hit。回归中修复了 CNM local controller 在 B request 被 backpressure 时漏接 A response 的 RTL 缺陷，并将四任务测试的 command/completion 环深度设为 8，避免环保留空槽时 tail 回绕造成误配置。
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

implemented C1-focused top test (three-seed VCS pass; selected all-engine slice)
   |-- production ai_accel_top -> dispatcher -> seven real compute engines
   |-- real ai_spad_arbiter/response routing + four-bank behavioral SRAM
   |-- seven-engine output/completion Goldens + request-backpressure coverage
   |-- Matrix/CNM response-owner ledger, multi-engine abort, reset/recovery
implemented C1 additions (three-seed pass)
   |-- byte-addressed SPAD reference model and accepted-read response checks
   |-- randomized 18-case parity cross (INT8/Matrix/CNM/BF16/SFU/Conv/KV, A/B where defined, all CNM lanes)
remaining C1 closure
   |-- broader opcode/configuration and parity/protection × phase crosses
   |-- complete REQ coverage, broader mutation campaign
```

**Monitor 事实来源**：Expected 应从命令 Monitor 和不依赖 DUT 的数值/内存模型生成；Observed 来自真实有效握手/Done/Memory；不要只由 Driver 自述接收作为 Checker 输入。每笔读先登记 accepted，再比对实际 response，不能假设 SPAD 有 AXI Read ID。

## 2. 需求映射矩阵（逐条 REQ）

> 本节 `READY`/`PARTIAL_SPEC` 是测试规划状态，表中执行细节是按日期记录的历史增量。当前执行判定和逐条证据以[2026-10-27 Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)为准。

**Status 定义**：`READY`=合法规格足以实现测试，**不是 PASS**；`PARTIAL_SPEC`=可测试已明确子集，其余需解除依赖；`BLOCKED_SPEC`=未经 Design Owner 决策，不得给出 DUT PASS/FAIL；`NOT_RUN/PASS/FAIL/WAIVED` 是执行阶段另行填写的结果。

| Requirement | Feature | Testpoint / Testcase ID | Checker / Oracle | Coverpoint / Cross | Priority / 设计状态 |
|---|---|---|---|---|---|
| REQ-CL-001 | 合法 Launch | idle / single-task；`tc_cl_legal_start` | 命令 Monitor+owner tracker | `cp_engine × launch_phase` | P0 READY |
| REQ-CL-002 | Engine Decode | 0x10-17,20/21,30-39,43/44,50/51逐一启动，select一致；`tc_cl_opcode_dispatch` | engine start观察 + dec独立解码 | `opcode × selected_engine` | P0 READY |
| REQ-CL-003 | 启动参数时序 | Start 前后变更参数；在采样边缘值稳定；`tc_cl_launch_sampling` | cfg monitor + model | `engine × launch_sampling` | P0 READY |
| REQ-CL-004 | 无关字段隔离 | 随机扰动本 Opcode 不使用的字段；`tc_cl_unused_field_noise` | Golden对比和存储写回 | `engine × unused_field_group` | P1 READY |
| REQ-CL-005 | 参数锁存 | Busy期间修改 Launch 参数，完成原任务；`tc_cl_config_latched` | input monitor + memory scoreboard | `engine × mid_task_change` | P0 READY |
| REQ-CL-006 | 请求背压保持 | 32-bit SPAD ready低1/2/8+周期；`tc_cl_spad_req_stability` | 接口 checker: 普通 stall 保持 payload；已接受 Matrix parity 响应同拍可撤销一笔未接受 banked read，并独立计数；focused covergroup 有 `parity_response_cancels_held_unaccepted_read` bin | `engine × stall_bin × rdwr × terminal_fault_cancel` | P0; R71 Line-stall slice PASS；R72 real-top parity-cancel cross 三 Seed 命中；完整 requester/stall/progress cross 仍 PARTIAL |
| REQ-CL-007 | 响应归属 | 已接受读取与响应一一对应，无窜发；`tc_cl_rsp_owner` | Response FIFO/accepted read ledger | `engine × response_delay × owner` | P0 READY |
| REQ-CL-008 | 写回 Memory Image | 每个已接受写后对照 Golden Memory；`tc_cl_memory_commit` | Byte-aware memory scoreboard | `engine × write_count × status` | P0 READY |
| REQ-CL-009 | 四Bank CNM | 各Bank独立grant/错拍响应/parity；`tc_cl_cnm_bank_independent` | per-bank monitor + CNM ref | `bank × rsp_phase × parity` | P0 READY |
| REQ-CL-010 | Matrix SPAD多口 | banked读 2/4 outstanding、response address/operand ownership、普通口、128-bit line 与 WSTRB；`MATRIX-LINE-001` 检查 full-strobe/alignment/fallback/stall/protection | block response-metadata FIFO scoreboard + top smoke + Matrix line-contract monitor | `depth × A/B × group × stall/fault_phase`；合法 line strobe 仅 full；partial/zero 为 unsupported 并由禁止性 checker 检查 | 2/4 深度各三 seed block PASS；R49 Line 合同 3 Seed PASS；更广的 Matrix response/fault-phase 组合仍未覆盖 |
| REQ-CL-011 | 独占 Done | 单事务只一个 Engine 完成；`tc_cl_unique_done` | owner scoreboard + onehot0(engine_done) SVA | `engine × completion_status` | P0 READY |
| REQ-CL-012 | Result MUX归属 | done拍比对result/error/code/counters；`tc_cl_result_owner` | engine monitor + done-owner scoreboard | `engine × result_class × error` | P0 READY |
| REQ-CL-013 | Exactly Once | 单启动唯一结束，不重复/漏 done；`tc_cl_completion_once` | start/done lifecycle ledger + watchdog bounded | `engine × completion_count` | P0 READY |
| REQ-CL-014 | 被接受请求/进展 | stall时无假accept；公平响应下有进展；`tc_cl_progress_backpressure` | request ledger + bounded SVA with fairness | `engine × stall_bin × progress` | P0 READY |
| REQ-CL-015 | 正常执行完整性 | 每Opcode数值正确、合法写回、唯一done；`tc_cl_normal_all_ops` | per-op Oracle + memory result checker | `opcode × shape × numeric_class` | P0 READY |
| REQ-CL-016 | 跨Engine切换 | FP→Matrix→CNM→SFU等连续任务防迟到污染；`tc_cl_engine_switch` | owner tracker + stale-response checker | `prev_engine × next_engine × spacing` | P0 READY |
| REQ-CL-017 | 错误后写入前缀 | Parity/Protection/Watchdog/Abort已接受写入正确；`tc_cl_error_prefix` | prefix-memory scoreboard + error model | `engine × fault × phase` | P0 PARTIAL；v1.4 已冻结错误/前缀 oracle，合法交叉覆盖未闭合 |
| REQ-CL-018 | 复位隔离 | Reset后不泄漏Done/写；旧 R/B 响应正确丢弃；`tc_cl_reset_stale` | reset epoch ledger / post-reset memory monitor | `engine × reset_phase × pending_reads × pending_writes` | P0 PARTIAL；R32 在真实 top 对七引擎分别于 accepted SPAD read 后 reset，检查 busy、旧响应、completion 和目的图像；R27 验证 behavioral AXI R/B 协调复位；目标外部 fabric 与更广 fault/reset phase 仍 OPEN |
| REQ-CL-019 | 同时异常恢复 | Abort/Reset及其它异常的合法交错；`tc_cl_fault_races` | fault priority oracle + owner monitor | `engine × fault_pair × phase` | P1 PARTIAL；v1.4 已冻结优先级 oracle，完整交叉未闭合 |
| REQ-CL-020 | Scalar INT8 | Signed 4lane packed VDOT/GEMV/GEMM/legacyConv,算术边界；`tb_ai_int8_numeric` / R52 | independent bit-exact integer model + full output Memory Image | Declared legal subset: `opcode × sign_pattern × shift × activation(0/1/2) × bias × saturation`, plus read/write stalls | P0 PARTIAL；R52 三 Seed 覆盖合法 VDOT/GEMV/GEMM common arithmetic path；legacy Conv、完整形状和 fault crosses 未闭合；R51 activation=3 bin excluded |
| REQ-CL-021 | CNM numerics | 4Bank局部ACC/global reduction, K/M边界；`tc_cl_cnm_numeric` | bank-aware integer golden + memory compare | `op × K × M × bank_phase` | P0 READY |
| REQ-CL-022 | Matrix numerics | 4×4 tile-major GEMM/batch, transpose, bias, requant/activation; 16×16 macro tile and cross-tile execution; ordered read depth 2/4; v1.5 Line contract | independent int64 reference + real Matrix core SPAD memory image + `MATRIX-LINE-001` | `op × transA × transB × batch × macro_tile × read_depth × fault_phase`; full/partial/zero WSTRB dispositions follow SPEC v1.5 | 2/4 depth each three seed: 10 numeric/layout cases + 14 error/recovery cases per seed PASS; R49 Line contract/checker 3 Seed PASS with Golden checks; broader numerical/fault crosses remain open |
| REQ-CL-023 | SFU numerics | softmax/norm/residual/GELU/SiLU/requant/causal；`tc_cl_sfu_numeric` | per-op Q-domain fixed-point golden;approx bounds | `op × vector_len × extreme × pack` | P0 PARTIAL；v1.3 已冻结整数域，选定 192 向量通过，更多形状未覆盖 |
| REQ-CL-024 | Conv 3×3 | valid stride1,no-padding,edge H/W, signed 8→32；`tc_cl_conv_window` | independent convolution window image scoreboard | `op × H_class × W_class × sign` | P0 READY |
| REQ-CL-025 | KV Cache | token/head/strides READ/WRITE & alias/overflow; R53 `KV-ADDR-001..011`, R54 `KV-PROT-001..004` | independent address arithmetic + byte-addressed SPAD image; error/no-request and real-top owner/error checker | `op × token × head × stride`, overflow/alignment class, one Protection denial | P0 / address and named top Protection slices PASS; broader stride/alias space remains partial |
| REQ-CL-026 | Mixed FP | 0x50/51 odd tail,NaN,Inf,subnormals,RNE,2 outstanding；`tc_cl_fp_numerical` | raw-bit Python oracle+FP bus scoreboard | `format × class × length × rsp_latency` | P0 READY |
| REQ-CL-027 | Engine error codes | 每引擎原始code + 前缀写 + owner；`tc_cl_error_code_table` | engine×fault mapping; unsupported unify blocked | `engine × fault_type × code` | P0 PARTIAL；v1.4 已冻结映射，完整引擎/故障交叉未覆盖 |
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
| REQ-PC-007 | CNM lane 与 Matrix banked/line 通路独立 | per-bank/line monitor 和 response scoreboard | CNM three-seed block regression + 2026-10-26 real top UVM 检查四 lane 地址/response ledger、Matrix/CNM tag 和独立 Golden；更广的 fault/backpressure 与完整 per-bank/line UVM 仍 OPEN |
| REQ-PC-008 | 并发任务共享只读区、输出区彼此隔离 | 真实 memory image scoreboard；配置非法别名为 out-of-contract | C0-P 未覆盖，待 C1 |
| REQ-PC-009 | 多 Engine active 时 abort 停止后续派发并有序 drain | 两 active + 一个 fetch 延迟任务；检查 no-new-launch、三笔 ERR_ABORT FIFO、idle | C0-P UVM 3 seeds PASS |
| REQ-PC-010 | active reset 与 requester error 组合后清空 slot/owner/FIFO；外部 AXI reset 按 epoch 隔离 | 已接受 AR 且 R 延迟时同时 reset accelerator/fabric；检查 fabric queue/active/RVALID 清空，8 周期无旧 R 或新 AR，再检查 SPAD sentinel 与 reset 后恢复；R32 对真实 top 七引擎执行 accepted-read reset | `CC-RESET-FABRIC-UVM-20261028-1022`、R32 PASS；行为 responder 已覆盖 R/B；真实集成 fabric 仍须按平台契约审查 |

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
| C1-REAL（定向全引擎 slice PASS） | 真实 top、7 个生产 Engine、Matrix/CNM owner、独立结果/completion Golden、请求背压、Matrix/SFU simultaneous Abort、活动 Reset/recovery | 候选 SHA `c83ad7463265062d4edb84d57fe4ada8195f9b10` 三 seed PASS；每 seed parity 14/14、4,852-word 对拍且 0 mismatch/unknown/stale、UVM severity=`0/0/0`；focused group raw=`98.96%`，唯一 miss 为 write-only completion response bin（WAIVED/N/A）。25/25 observation-copy checker mutations 命中对应检查，其中 Done/missing/duplicate Done 覆盖全部七个 engine bit。Merged whole-top URG 包含 DUT/SVA/TB/UVM，不作 DUT-only closure。完整 REQ、fault matrix 与 RTL mutation score 仍未覆盖；见[2026-10-27 签核候选报告](COMPUTE_CLUSTER_S1_S2_SIGNOFF_CANDIDATE_2026-10-27.md) |
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

> 本节早期 SHA 与较低覆盖率记录保留为历史。当前逐项 Requirement disposition、Matrix FSM/SVA 未命中项和 checker-sensitivity 证据以[2026-10-28 Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)和[Readiness Report](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md)为准；Benchmark 与 TinyNPU 对标边界见[Benchmark Report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md)。Stage A 与更早 SHA 记录仍可用于历史回溯。

**2026-10-27 exact-candidate clean replay：** VCS/URG `V-2023.12-SP1_Full64` 在 detached clean worktree 对 `c0832e5c822de1a03f82751d5ff8f831d0addb98` 完成三 seed 回归（`20261025/20261026/20261027`），`make` 与 URG merge 均 PASS。每 seed：4,946 accepted writes、5,256 words checked、mismatch/unknown/stale/orphan 均为 0，UVM warning/error/fatal=`0/0/0`；focused group 为 29/30 bins=`98.96%`。日志、命令、SHA-256 与 SVA disposition 见[Execution RTM R14](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)。这关闭了候选 SHA clean replay 流程项，不关闭 38 项 requirement 中的 partial/blocked 项。

**历史候选后续（R15–R18，source SHA `c0832e5`）：** 在当时的 detached worktree 补跑 16-seed mixed-precision DDR E2E、25 项 checker-sensitivity mutation、Matrix size sweep 三 seed，以及八配置消融三 seed。结果分别为 AXI/FP E2E PASS、25/25、45/45、120/120。URG 显示 20/22 assertions success，另外 2 项 UVM RAL assertion 无 attempts、0 failure/incomplete；五条 AR/AW/W payload/burst assertion 均有 real success，AR/AW/W stall-to-accept cover 匹配 166/70/107 次。Mutation 修改 passive monitor observation copy；这不是 RTL mutation score。历史候选当时的 RTM 状态及证据见 R15–R18。

**当前候选收口（R24–R32，product RTL SHA `9d9e0f0`）：** SPEC v1.4 与 RTL 冻结七引擎 Error ABI、priority 和 accepted-write prefix；三 seed 定向故障、当前 SHA clean top UVM、七引擎 accepted-read reset sweep、25/25 checker mutation、behavioral AXI R/B reset、Matrix depth-4 drain/recovery、CNM/DMA-SPAD Abort/Reset、RREADY 16/64/300 周期 stress、Matrix formal 与两组 benchmark 均通过。R31 的 14 个子系统功能 covergroup 合并后为 100%，它不代表全 Cluster 功能覆盖或 DUT code coverage。当前 38 项状态为 24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN。剩余外部 fabric 合规、partial Line WSTRB 和广义 Fault × Phase × Engine 仍开放。命令、run id、seed、证据路径和 SHA-256 见[当前执行 RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)及[回放清单](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md)。

**2026-10-28 TinyNPU matched workload (R19)：** Candidate NMAForge Matrix 与 pinned TinyNPU 都用 8×8 physical array 跑 16×16×16 signed INT8 GEMM，使用相同输入且 256 个 INT32 输出均通过独立 Golden。另以相同 3×3 单通道 image/filter 比较 NMAForge native Conv 与 TinyNPU padded GEMM lowering，输出均为 -30。TinyNPU VCS 运行需要临时 DSP48E1 functional model 和 `always_ff` 兼容副本；数据代表此行为仿真/计时边界，不代表 UNISIM 或 FPGA PPA。见 [Benchmark Report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md) 和 [Execution RTM R19](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)。


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
接入真实 Arbiter/四 Bank 并完成三 seed 执行；C1 all-engine 定向证据见本节末。
随机 shape/fault matrix、完整 C1 coverage 和广泛 mutation campaign
仍未通过验收；selected fixed-SHA replay 见本节末 evidence record。

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

**2026-10-26 Matrix/CNM top UVM（license 恢复后的中间结果，后续由七引擎切片更新）**：真实 top sequence 检查 Matrix+CNM 并发、CNM 四 lane A/B accepted address、Matrix 地址范围、client tag 3/5 路由、lane response accepted/response ledger、16 个 CNM 输出及 CPLQ 顺序；同时检查 Matrix standalone 512-word Golden、16/16 cache hits，及并发 Matrix 512-word Golden。执行命令为：

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_compute_cluster_cnm_owner_20261026_closeout
```

VCS 编译/elaboration 成功，三 seed `20261025/20261026/20261027` 全部通过，URG merge 成功。每 seed focused compute covergroup=`93.54%`，UVM warning/error/fatal=`0/0/0`；scoreboard 为 `observations/busy/overlap/done/errors/reads/responses/orphan/reset_dropped = 1877/1694/580/8/2/766/764/0/2`，所有 lane accepted/response 都是 32，pending ledger 全零。Matrix/CNM 并发检查记录 Matrix tag3 response=384、CNM tag5 response=32、lane mask=`1111`、Engine overlap=171、共享 banked grants=28；并发运行中仍观测 16 次 A-tile hit。VCS compile 有既有 `Warning-[TFIPC]`（top protocol SVA instance 少接端口），但 UVM warning/error/fatal 均为零。

URG dashboard 的 whole-testbench coverage summary 为 line/condition/FSM/branch/assert/group=`53.02/45.30/16.91/43.46/60.00/22.63%`（overall score `40.22%`）。该合并报告包括 DUT、SVA、TB 和 UVM，不能当作 DUT-only 或完整 Cluster coverage。生成目录：`/tmp/nmaforge_compute_cluster_cnm_owner_20261026_closeout/urg_merged/`。

RTL 修改后的 `make -C dv/subsystem/top_smoke/sim ai_smoke` 与
`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`（工作目录 `dv/subsystem/top_smoke/sim`）均重新通过，两个 smoke 均打印 `TEST PASS`。此前 license daemon 失败仅保留为历史尝试，已由本次成功重跑取代。

**2026-10-26 七引擎 C1 UVM（初始增量）**：在同一真实 top UVM 环境中，按序执行
INT8 VDOT、BF16 dot、CNM、Matrix、SFU、Conv3x3、KV write，并单独检查 KV
readback/token-head stride；每引擎都有结果与 completion 检查。新增请求背压、Matrix/SFU
并发 Abort、活动 Reset/recovery 和逐 lane CNM 地址/响应归属检查。复现命令：

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_c1_all_engines_3seed_20261026
```

VCS `V-2023.12-SP1_Full64` 三 seed 全部 PASS；每 seed focused compute functional
covergroup=`97.9%`，UVM warning/error/fatal=`0/0/0`。每 seed scoreboard 汇总为
`observations/busy/overlap/done/errors/reads/responses/orphan/reset_dropped =
2594/2343/827/16/2/1152/1150/0/2`；CNM 四 lane 每 lane 64 次 accepted/response，所有
pending ledger 归零。`errors=2` 是预期 Abort completion。请求背压累计 236 cycles，engine
mask=`1110111`，Matrix/SFU Abort cross 命中。该 run 是本轮 memory scoreboard / parity
cross 前的中间版本，相关闭环见下方最新证据表。Merged whole-top URG 包含 DUT、SVA、TB、UVM，
不能作为 DUT-only code coverage。Compile 有既有 `Warning-[TFIPC]`（top protocol SVA
instance omitted inputs）；UVM warning/error/fatal 为零。

**2026-10-26 Matrix FSM 收敛增量**：depth-4 Matrix core 三 seed VCS regression 通过，
并与 4×4 physical-array prefetch handoff 定向回归合并 URG。`ai_tensor_matrix_core`
line/condition/FSM-transition/branch=`96.45/88.52/49/53 (92.45%)/95.02%`；FSM 状态
15/15，prefetch FSM transitions 9/9。当前 R28 已逐项 disposition 四条 core transition：
`ST_MAC→ST_A_REQ` 在独立 no-prefetch profile 命中；其余三条由非空洞 formal guard
properties 在合法 descriptor/response 假设下证明不会触发。默认 profile 原始分数仍保留
49/53，不合并不同编译配置，也不宣称全部 FSM/code coverage closure。Matrix child array
line/condition/branch=`82.35/20.00/58.82%` 仍未闭合。复现命令、假设和 URG 目录见
[升级路线 §3.7](COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md#37-2026-10-26-all-engine-uvm-matrix-fsm-and-decoder-follow-up)。

### 7.1 最新 Requirement → Testpoint → Coverage → Run ID → Result

| Requirement | Testpoint / Checker | Coverage / 审查结果 | Run ID / artifact | Result |
|---|---|---|---|---|
| CLEAN-CLUSTER-001：候选版本可复现回归 | detached clean worktree；`ai_compute_cluster_e2e_test`；memory scoreboard、owner ledger、SVA/URG | Current source SHA `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`；三 seed PASS；每 seed 5,256 words checked，无 mismatch/unknown/stale/orphan；UVM severity `0/0/0`；focused group `98.96%` | `CLUSTER-S2-CLEAN-3S-9D9E0F`；`/tmp/nmaforge_final_9d9e0f_uvm/` | **PASS（current top UVM replay）**；其余 requirement 状态见 RTM |
| CLEAN-CLUSTER-002：七引擎 accepted-read reset sweep | clean detached test commit `bb6e3a2`；每个引擎 accepted SPAD read 后对 real top reset；检查 busy、destination/completion image、stale response/writeback | 3 seeds；每 seed 5,094 writes / 5,368 words，zero mismatch/unknown/stale/orphan，reset_dropped=9，UVM severity 0/0/0；focused marker 99.0% rounded | `CLUSTER-ALL-ENGINE-RESET-SWEEP-CLEAN-3S-BB6E3A2`；`/tmp/nmaforge_bb6e3a2_clean3s/` | **PASS（accepted-read reset slice）**；actual external fabric 与 fault/reset cross 仍 OPEN |
| AXI-SVA-001：AXI master properties 非空洞 | real DDR/FP E2E AXI traffic；URG assertion + cover properties | 16 seed；AR/AW/W stalls 与 gap；五条 AR/AW/W payload/burst assertion 均 real-success；AR/AW/W stall-to-accept=`166/70/107`；2 个 UVM RAL assertion 未尝试 | `CLUSTER-AXI-E2E-COV-16S-C0832`；`/tmp/nmaforge_c0832e5_axi_cov_20261028/urg_merged/` | **PASS（AXI assertion scope）**；compute requester/fault cross 仍 OPEN |
| SFU-NUM-001：定点算术合同及 Golden 边界 | `random-latency-regress`；独立 `ai_a3_reference.py`；VCS | 8 opcode × 8 lengths × 3 seeds = 192/192 bit-exact；每 seed reads/responses `1043/1043`、writes `427`、最大 response delay 7；compile 无 Warning/Error/TFIPC | `SFU-RAND-NUM-EDGE-3S-20261028`；`/tmp/nmaforge_sfu_numeric_edges_20261028/`；[SFU 数值合同](../spec/SFU_NUMERIC_CONTRACT_ZH.md) | **PASS-SCOPED**；合同域已验证，不代表理想实数误差或所有长度 |
| MATRIX-SIZE-CAND-001：固定 SHA 物理阵列对照 | 4×4/8×8/16×16 physical array × 5 个 GEMM × 3 seed | 45/45；同 SHA、同 workload、one-cycle behavioral SPAD；记录 cycles/MAC/cycle/utilization/SPAD reads/stalls | `MATRIX-BENCH-CLEAN-3S-9D9E0F`；`/tmp/nmaforge_final_9d9e0f_matrix_size{_20261025,_20261027}/` 与 seed 26 根目录 | **PASS（cycle benchmark）**；不是 SRAM timing/PPA |
| MATRIX-ABLATION-CAND-001：Depth/Prefetch/Cache 八配置 | 2/4 outstanding × prefetch off/on × cache off/on × 5 workloads × 3 seed | 120/120；相同五 workload；每 seed 输出 CSV | `MATRIX-BENCH-CLEAN-3S-9D9E0F`；`/tmp/nmaforge_final_9d9e0f_matrix_config{_20261025,_20261027}/` 与 seed 26 根目录 | **PASS（cycle benchmark）**；TinyNPU 同输入 GEMM/CNN lowering 仍是历史 R19 |
| C1-ENG-001：真实 top 七引擎功能与 completion | `ai_compute_cluster_e2e_seq`；每引擎独立 Golden、completion/order、backpressure、Abort/Reset recovery | Latest SHA `03bf257afdca9b0041ff80b6d30cbaf8107cf7e0` 三 seed；parity 14/14、scoreboard 4,852 words/seed 无 mismatch/unknown/stale，UVM severity 0/0/0；focused group 99.0%。DMA response-client 命中；completion read-response 显式 WAIVED/N/A（writer write-only） | `CC-STAGEA-UVM-3S`；`/tmp/nmaforge_stageA_clean_03bf257_uvm/seed_{20261025,20261026,20261027}/run.log` | **PASS（定向 slice）**；完整 C1 REQ closure 仍 OPEN |
| C1-MEM-001：scratchpad read/write 与 Golden memory image | `ai_compute_cluster_scoreboard`；byte-addressed model、accepted-read snapshot、client/lane/engine owner、WSTRB 与 epoch 检查 | 每 seed `writes=4444`, `checked_words=4852`, `mismatches=0`, `unknown_reads=0`, `stale_epoch=0`; line WSTRB full/partial/zero=`512/0/0`; all four banks/seven engine bits active | `CC-STAGEA-UVM-3S`；clean logs同上 | **PASS（观察到的 traffic classes）**；partial-WSTRB 和完整 REQ image 仍 OPEN |
| C1-FAULT-001：engine / operand / CNM-lane parity cross | Stage A exact-SHA seed-shuffled 14-case parity test；检查 completion `error=2/code=5` 与 no-writeback sentinel | 每 seed `14/14`；三 seed共`42/42`，覆盖 INT8/Matrix/CNM/BF16、A/B；CNM lane 0–3 全命中。此为选定 parity 子集，不是 protection × phase × Abort/Reset 全组合 | `CC-STAGEA-UVM-3S`；`/tmp/nmaforge_stageA_clean_03bf257_uvm/seed_{20261025,20261026,20261027}/run.log` | **PASS（parity subset）**；更广 fault cross 仍开放 |
| MATRIX-FSM-001：Matrix core FSM / prefetch FSM | 三 seed depth-4 regression + prefetch-off 固定 workload + VC Formal guards | Raw default profile `state_r` 15/15 states、49/53 transitions；prefetch FSM 9/9。`ST_MAC→ST_A_REQ` 在关闭 prefetch profile 命中；R28 证明 5/5 非空洞属性、覆盖两个状态可达性，并处置三条 guard/invariant transition。Raw percentage 不合并不同编译 profile | `MATRIX-FSM-FPV-CLEAN-9D9E0F`；`/tmp/nmaforge_final_9d9e0f_matrix_formal/vc_formal.log`；R4 no-prefetch evidence | **Scoped disposition**；不声称 FSM 100% 或所有 profile 全覆盖 |
| MATRIX-BENCH-001：八个 depth/prefetch/cache 配置同负载比较 | `matrix-config-comparison`, `SEED=20261026`, 16×16 physical array、五 workloads、1-cycle behavioral bank response | 8 配置×5 workload 全部 PASS (40/40)；16×16×32 `265→233` cycles；16×32×32 `504→417` (reads `128→96`)；32×32×64 `1698→1187` (reads `512→384`) | `MATRIX-STAGEA-8CFG`；`/tmp/nmaforge_stageA_clean_03bf257_matrix8/` | **PASS（cycle benchmark only）**；不代表 SRAM timing/PPA |
| TRANSFORMER-FUNC-001：prefill/decode 数据路径 | real top 86-descriptor sequence + software Golden | 四 token prefill + 一 token decode；固定手工 INT8 权重，不是 pretrained checkpoint / 模型精度测试 | `TRANSFORMER-CLEAN-827C005`；`/tmp/nmaforge_clean_sha_827c005_top/ai_transformer.log` | **PASS（固定权重功能）**；预训练部署/精度 **NOT_RUN** |
| C1-MUTATION-001（历史 RTL bit-flip） | 曾对 bank 0 registered read-data bit 0 做一次临时 RTL mutation，恢复后同 seed replay | 旧 SHA `827c0052` 有 192 mismatch + Matrix Golden fatal；恢复源后 PASS；此为历史单点敏感度测试，不计入当前 campaign | `CC-MUTATION-827C005-SEED20261025`；[历史记录](COMPUTE_CLUSTER_CLEAN_REPLAY_2026-10-26.md) | **PASS（历史单点）**；不代表 RTL mutation score |
| CLEAN-SHA-001：冻结源回放 | Detached clean worktree 的真实 top UVM、Matrix 8 配置、prefetch-off transition、Transformer、smoke、20-case seeded top | tested source SHA `827c0052cf589fde676e93e34bf459188956182f`；三 seed UVM、8/8 config、86 descriptors、`ai_smoke` 和 `ai_run` 均 PASS；日志及精确命令见 run record | `CC-CLEAN-827C005-*`；[回放证据](COMPUTE_CLUSTER_CLEAN_REPLAY_2026-10-26.md) | **PASS（selected manifest）**；full Cluster signoff **OPEN** |
| C1-MUTATION-STAGEA：Address/Data/Owner/WSTRB/Done checker sensitivity | 在 monitor copied observation 上作五类 mutation，driver、DUT RTL、memory 不变 | 五种 mutation 全部由预期 scoreboard/checker 检出；不折算为 RTL mutation score | `CC-STAGEA-MUT-5`；`/tmp/nmaforge_stageA_clean_03bf257_mutations/{address,data,owner,wstrb,done}.log` | **PASS 5/5（checker sensitivity）** |
| CLUSTER-BENCH-001：serial / staged parallel / queued execution | 同一 descriptor workload，对比 `Matrix→CNM→SFU` 与 Matrix+CNM overlap 后运行 SFU；再比较四任务队列 | `1239→1070` cycles (1.158×)；four-task sequential/queued `1696→1137` (1.492×)，completion 顺序保持。CNM+DMA subsystem contention 三 seed PASS；Matrix+CNM+DMA top 同发受 DMA busy gate 阻挡 | `CC-STAGEA-UVM-3S`、`DMA-CNM-STAGEA-3S`；[benchmark report](COMPUTE_CLUSTER_STAGE_A_AND_BENCHMARKS_2026-10-26.md) | **PASS（测试模式）/ BLOCKED（三引擎 DMA 模式）** |

**当前覆盖率结论**：最新 focused UVM group、Matrix DUT-only URG、FSM transition disposition、R14–R52 evidence 见 2026-10-30 Execution RTM 与 Readiness Report。R40 focused compute marker 为 `100.0%` applicable（URG 29/29 variables）；R46/R47 是许可证恢复前的历史 BLOCKED_ENV；R48 首 Seed checker end gate 因 testbench 计数器 reset 逻辑失败；R49 corrected Matrix Line 3 Seed PASS，每 Seed 312 次 stability observation。R50 在发布 SHA `be78ee2` 上完成六 Seed clean replay，每 Seed applicable focused coverage 100.0%，UVM warning/error/fatal 为 0/0/0，memory scoreboard 5,368 words 零 mismatch/unknown/stale/orphan；Top Smoke 亦 `TEST PASS`。R50 compute-only SVA 的 AR/AW stall-to-accept cover 各 0 hit、W 为 1 hit；R15 独立 E2E 仍提供三项 AXI stall cover 命中证据。R49 VCS coverage database 已生成，但尚未 post-process 为 URG 百分比报告；不以该库宣称全设计 coverage closure。历史 raw 29/30（98.96%）保留，唯一 completion-read response bin 明确标记 Excluded/N/A。运行时和 Makefile gate 均检查 completion read-response 为零且 DMA response-client 命中。R15 AXI URG 为 20/22 assertions success，另外两项 UVM RAL 未尝试，五个 AXI master assertions 和三个 stall cover 均命中。R28 对 Matrix 默认配置 49/53 raw FSM transitions 的 guard 条目给出 formal/test disposition，不将原始百分比改写为 100%。VDB 百分比不代表整个 Cluster 覆盖率；Merged top URG 包含 DUT、SVA、testbench 与 UVM，不能作为 DUT-only closure。旧的 `97.92%` 与 3,536-word 数字属于更早 SHA 的历史运行。

CNM RTL 改动后的定向复核也通过：`ai_cnm_signoff` 中 A2 GEMV、A3 GEMM
benchmark（L=16/64/256）、SPAD arbiter contention/protection checks 和 top
`ai_smoke` 均 PASS；另外 `ai_cnm_random_regress` 的 seeds
`20261021/20261022/20261023` 均为 `CNM_RANDOM_PASS`，每 seed 10 个数值用例、8 个
fault、1 个 late fault、fault+reset 和恢复。随机回归日志/VDB 位于
`/tmp/nmaforge_cnm_controller_fix_20261026/`。

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
| OPEN-CL-006 — Error ABI | REQ-CL-017/019/027 | **SPEC blocker closed by v1.4/R24**; per-engine Error ABI is frozen, while the legal fault/phase verification cross remains partial under CL-COV-006 |
| OPEN-CL-003 — Abort/Reset Drain | REQ-CL-007/014/016/018/019、REQ-PC-009/010 | v1.2 冻结协调式 AXI reset/epoch；R27 在 behavioral responder 上验证 R/B reset，R30 在 Matrix core 验证 depth-4 accepted-read Abort/Reset drain，R32 在 real top 覆盖七引擎 accepted-read reset。更广的 Abort/fault 交叉和目标外部 fabric 合规仍 OPEN |
| OPEN-CL-002 — 参数合法范围 | REQ-CL-004/005/020~025 | R53 冻结并验证 KV 的 32-bit overflow/alignment 子项；R54 验证一条真实 top-level KV Protection denial；其他 Engine descriptor 规则、KV stride/aliasing 仍 OPEN |
| OPEN-CL-004 — Matrix Line checker execution | REQ-CL-010/022 | **Closed for the scoped Line transfer contract by SPEC v1.5 + R49.** Three seeds pass full WSTRB, alignment, scalar fallback, stall stability and protection checks with reference-memory verification. Broader REQ-CL-010/022 coverage remains partial. |
| OPEN-CL-007 — 同拍故障优先级 | REQ-CL-017/019/027 | **SPEC blocker closed by v1.4/R24**; selected same-cycle priority/prefix tests pass, broader legal fault crosses remain partial |
| OPEN-NUM-01 — Scalar fixed-point | REQ-CL-020 | **Closed scoped by SPEC v1.6/R52** for legal-activation VDOT/GEMV/GEMM common arithmetic contract and directed edge vectors; R51 reserved activation=3 is excluded; legacy Conv and wider opcode/shape domain remain PARTIAL under CL-COV-003. |
| OPEN-NUM-02 — SFU fixed-point | REQ-CL-023 | **Closed in SPEC v1.3 / R21 for the documented domain:** exact integer formulas plus independent Golden, 192/192 vectors over 3 seeds; larger input/length space is not claimed. |
| OUT_OF_CONTRACT — illegal launch | REQ-CL-001/002/011 | Busy Start/多 Select 仅鲁棒性探索，不计产品合规覆盖 |

## 9. 下一阶段任务与审查 Checklist

- 扩展已通过的真实 top 七引擎定向 UVM 到随机 shape/opcode 配置，并为每个支持配置保存独立数值和 memory scoreboard 证据。
- 加入 CNM bank-lane/parity、SPAD parity/protection、fault × phase × outstanding 与跨引擎 Abort/Reset 的合法组合；复合故障优先级仍按 SPEC/Design Review 冻结后验证。
- 扩展已落地的 reference-memory / lifecycle scoreboard，纳入 DMA/completion traffic、Matrix full-Line/fallback contract 与完整 opcode/configuration REQ coverage；不得为 partial/zero WSTRB 生成非法合法性激励。
- 再用真实 arbiter 复核其余 REQ-PC；数值 oracle 按 REQ-CL-020～028 扩展，并建立 requirement→testpoint→coverage→run ID RTM。
- Execution RTM 要列出 38 条 Requirement 的 Test ID、Run ID、Seed、Coverage Bin、Bug/waiver/blocker。没有证据的状态初始值必须是 NOT_RUN。

**状态声明（2026-10-26 Stage A 更新）**：固定 SHA `03bf257afdca9b0041ff80b6d30cbaf8107cf7e0` 的 clean worktree 三 seed 七引擎 UVM、5/5 observation-only checker mutation、40/40 Matrix 配置/工作负载、三 seed Matrix depth-4 fault/recovery 与三 seed CNM/DMA subsystem contention 均已执行。Functional covergroup=`99.0%`；DMA bin PASS，completion read-response bin WAIVED/N/A；Memory scoreboard 每 seed 比对 4,852 words 且 mismatch/unknown/stale 均为 0。Matrix `state_r` 49/53、prefetch 9/9，残余状态已逐项审查但未作 formal unreachable waiver。Serial/staged Cluster benchmark 为 1,239/1,070 cycles，四任务 queued mode 为 1,696/1,137 cycles。完整 protection/fault phase cross、partial-WSTRB image、全部 38 项 REQ-CL、Matrix+CNM+DMA top contention（受合法 DMA busy gate 限制）、ASIC PPA 与总体 signoff 仍未完成。详见[Stage A 与 Benchmark 证据](COMPUTE_CLUSTER_STAGE_A_AND_BENCHMARKS_2026-10-26.md)。
