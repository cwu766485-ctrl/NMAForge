# A10 DV 基线与当前工作树验证记录 — 2026-10-14

## 快照与环境

- RTL 冻结基线 commit：`1b4b61fdb84ecbe0f7e57ab9627b2e772216fc7f` (`1b4b61f`)。
- 可复现性边界：`HEAD` 指向上述基线 commit，但测试时工作树并非 clean checkout，包含 RTL、规格、testbench、UVM 与新增 subsystem 环境的在研修改。因此下列结果是**当前工作树**的实测，不应表述为 pristine commit 的 clean replay；要满足“固定 commit 可重放”的最终验收，需先审阅并提交/冻结这些改动，再从 clean checkout 重跑。FP dot DUT block RTL 本身未改，相关 UVM/testbench 有在研变化；DMA subsystem 测试包含 `ai_axi128_dma.v` 在研 error-drain 修改。
- Top 集成边界：`ai_accel_compute_cluster.v` 对 6 个可选 CNM benchmark telemetry 输出增加显式空连接；该连接不改变功能接口或数据通路。修改后的 top RTL 已重跑 `ai_smoke` 与 20-case seeded `ai_run`。
- 环境：Rocky Linux 8.10 / WSL；Synopsys VCS/URG `V-2023.12-SP1_Full64`；GNU Make 4.2.1；Python 3.12.13。
- VCS license：2026-10-14 已恢复并实际成功 checkout；此前 license-blocked 记录仅作为历史，不代表本轮结果。
- 测试数据库与完整日志：均在 WSL `/tmp/nmaforge_a10_*`，不纳入 Git。

### 2026-10-14 A10 后续复核：FP 三 seed 新目录重跑

- FP UVM 在独立新目录 `/tmp/nmaforge_a10_fp_recheck_20261014/` 重新逐 seed 执行，避免误读旧日志或复用旧 VDB：`DOT_RANDOM_COUNT=256`，seeds `712345`、`987654`、`20261014`。三 seed 均为 `Scoreboard PASS: 582/582 bit-exact transactions`，UVM warning/error/fatal 均为 0；每 seed 536 个数值事务、46 个 fault/reset 事务，peak outstanding reads=2，numeric、response-latency、fault/reset、busy-start 功能 coverage 均为 100%。
- 三份 VDB 已由 VCS URG 合并到 `/tmp/nmaforge_a10_fp_recheck_20261014/urg_report_merged/`。每 seed 独立日志及数据库位于 `seed_<seed>/run.log` 与 `seed_<seed>/coverage.vdb`。此前因宿主 shell 参数传递导致只执行单 seed 的尝试未计入本结论。
- 实际命令为在 Rocky 8.10 已加载 VCS 环境的 shell 中，对每个 seed 分别执行：`DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_fp_recheck_20261014 make -C dv/block/compute/fp/sim dot-uvm-run DOT_RANDOM_SEED=<seed> DOT_RANDOM_COUNT=256`；随后对三个 `coverage.vdb` 执行 `urg -full64 -dir <seed_712345_vdb> <seed_987654_vdb> <seed_20261014_vdb> -format text -report /tmp/nmaforge_a10_fp_recheck_20261014/urg_report_merged`。这次不是 `dot-uvm-regress` target 的单次列表调用。

### 2026-10-15 A10 V1 再验证（isolated output）

- Rocky 8.10 / WSL，VCS/URG `V-2023.12-SP1_Full64`。`make dot-core-test DOT_CORE_OUT_DIR=/tmp/nmaforge_a10_v1_core_20261015` PASS。
- 为避免递归 `dot-uvm-regress` 未按预期传递命令行覆盖值，本次直接逐 seed 执行 `make dot-uvm-run DOT_RANDOM_SEED=<seed> DOT_RANDOM_COUNT=256 DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_v1_uvm_20261015`；seeds `712345`、`987654`、`20261014`。每 seed `Scoreboard PASS: 582/582`（536 numeric、46 fault/reset），peak outstanding reads=2，numeric/response-latency/fault-reset/busy-start 功能组均 100%，UVM warning/error/fatal=`0/0/0`。
- 三个 VDB 合并至 `/tmp/nmaforge_a10_v1_uvm_20261015/urg_merged/`。逐 seed `run.log`、`compile.log` 和 harness log 位于 `/tmp/nmaforge_a10_v1_uvm_20261015/seed_<seed>/` 与同名 `_seed_<seed>.log` 文件。
- 当时的 Command Processor UVM fetch-stage abort 三 seed结果为 `18/18` bins、UVM severity `0/0/0`；后续 compute-abort/re-doorbell 增量已将最新结果提升为 `19/19`（见文末）。top `ai_smoke` `TEST PASS`。所有结果均来自当前 dirty worktree；不是固定 SHA clean replay。

### 2026-10-15 A10 Control/DMA block UVM 当前树复跑

- Control 使用独立仿真程序 `simv_a10_control_refresh`，六个正式用例 `control_reset_version_test`、`control_protocol_test`、`control_irq_error_test`、`control_busy_abort_test`、`control_random_rw_test`、`control_ral_access_test` 均退出码 0；逐项 UVM warning/error/fatal=`0/0/0`。日志位于 `/tmp/nmaforge_a10_control_20261015/`。
- 对 `control_random_rw_test` 又分别以 seeds `712345/987654/20261014` 编译/运行，三项 UVM warning/error/fatal 均为 0。四份 VDB 合并到 `/tmp/nmaforge_a10_control_20261015/urg_merged_4seed/`，报告列出 9 个 tests；functional group `control_env_pkg::control_coverage::cg` 仍为 75.18%（goal 100%），重复随机 seed 未命中新 group bins。merged raw line/condition/toggle/FSM/branch/assertion 为 35.14%/41.43%/23.12%/64.29%/17.80%/30.00%；top hierarchy 对应为 62.15%/67.57%/23.15%/64.29%/28.57%/28.57%。这些数值不是 coverage closure；应先 review 未命中 bins，再增补定向 stimulus。
- **后续 superseding 增量：** URG bin review 发现 read monitor item 的默认 `strb=0` 曾被误计为 WSTRB 覆盖。现将 `cp_strb` 改为仅在 write transaction 采样，并在 `control_protocol_seq` 定向遍历全部 partial WSTRB `0x0..0xe`（都应 SLVERR、OP 保持 `0x31`），同时只读访问缺失的寄存器窗口；未修改 DUT RTL/ABI。Focused protocol 与完整 Control 六 test 均 PASS，UVM warning/error/fatal=0。最新 URG `/tmp/nmaforge_a10_control_targeted_20261015/urg_merged/`：6 tests，`control_coverage::cg` 的 34/34 variables、4/4 crosses、cp_window 14/14、cp_strb 16/16 均为 100%。
- 同一 URG 的 RTL code coverage 仍未关闭：`axi_lite_reg_if` line/condition/branch=`97.30%/88.24%/81.82%`，write FSM states=`4/4`、transitions=`4/6`；`ai_accel_regs` line/condition/branch=`50.73%/60.53%/25.25%`。当时的 assertion report 为 0 failure/incomplete；7 个 DUT SVA 中只有 abort-pulse 与 IRQ-known 有 non-vacuous success，5 个 AXI stability property 没有 real success。该 assertion 状态已被下方最新 channel-backpressure 增量 supersede；旧 functional covergroup 的 75.18% 同样已由 write-qualified WSTRB 结果 supersede。
- **2026-10-15 最新 Control 增量：** `control_axil_driver` 将 B/R 延迟改为在 BVALID/RVALID 出现后保持 READY 低指定周期，并在 posedge 采样 response handshake，修复了原 driver 可能错过握手的测试平台竞态。新增 `control_channel_backpressure_test`，在一笔请求尚未退休时保持第二笔 AW、W、AR 与 payload 稳定，直到 DUT READY 恢复。命令 `cd dv/block/control/sim && make uvm_regress` 对七个用例全部 PASS，UVM warning/error/fatal=`0/0/0`；URG 位于 `/tmp/nmaforge_a10_control_final_20261015/urg_final/`。选定 functional group 为 34/34 variables + 4/4 crosses（100%）；七条 DUT SVA 均有 non-vacuous success，逐项 real successes 为 AW/W/B/AR/R=`7/7/77/4/83`、abort=`1`、IRQ-known=`979`，failure/incomplete=`0/0`；两条无 attempt 项是 UVM RAL 内部 assertion。`axi_lite_reg_if` line/condition/branch=`97.30%/94.12%/90.91%`，write/read FSM states=`4/4`、`5/5`，transitions=`4/6`、`5/8`；未命中项是各 FSM 从 in-flight 状态复位回初态，需继续做 reset-phase disposition。`ai_accel_regs` line/condition/branch=`50.73%/60.53%/25.25%`。Control 的功能组与 DUT SVA 已闭环到本次选定范围，但 code coverage/in-flight reset 和全项目 V5 仍开放。
- 注：上一条七-test Control 数据是当时快照；in-flight reset 测试及八-test URG 的最新证据见本文件后面的“Control UVM refresh — in-flight reset closure”小节。
- DMA 随后按每个 test 单独编译到隔离 VDB，并复跑 Makefile 中 11 个用例：1D/2D load、gather、store、narrow、4 KiB、abort、config error、back-pressure、random stress；seed=`20261015`，逐项退出码 0，UVM warning/error/fatal 均为 0。再对 `dma_random_stress_test` 增跑 seeds `20261016/20261017/20261018`，三者均退出码 0、UVM severity=`0/0/0`，每个 seed 的 scoreboard transaction 均通过；该 random test 的自报 command coverage 每 seed 为 70.00%。14 个 VDB 的 URG merge 报告为 `/tmp/nmaforge_a10_dma_cov_20261015/urg_merged_4seed/`，明确列出 14 tests，聚合 `dma_cmd_cg` functional group 为 100%。该报告没有 assertion properties/sequences，也不包含 RTL code-coverage metrics；100% 只代表该 covergroup 在 directed + random 合并下的命中，不是 DMA coverage/signoff closure。逐 test/seed 日志与 VDB 均在同一 `/tmp/nmaforge_a10_dma_cov_20261015/` 目录。
- 本次 Control/DMA 结果均来自当前 dirty worktree，不能替代固定 SHA clean checkout replay。复跑未修改产品 RTL。

### 2026-10-15 Command Processor 随机混合环队列扩展

- 将 CP UVM ring 场景扩展为每个 seed 随机选择 12–24 条命令。第 0 项固定非法、紧随其后的第 1 项固定合法，后续项以 seed 驱动约 20% 概率随机生成非法 opcode。producer 仅在 ring 有可用槽位时发布 descriptor/CMDQ tail；consumer 对 CPLQ head 更新施加 0–2 cycle 延迟。独立 reference model 逐条比较 fetch slot/address、task ID、launch 与 completion retire 顺序及 completion status/error；非法项必须产生 `ERR_DESC` 且不得 launch，合法项必须成功 launch/retire，最后 expected queues 排空、CMDQ/CPLQ 指针一致。
- 命令：`make -C dv/block/command_processor/uvm regress OUT=/tmp/nmaforge_a10_cp_mixedqueue_20261015 SEEDS='12345 67890 24680'`。VCS `V-2023.12-SP1_Full64` 编译通过，三 seed 的 accepted/retired 分别为 `18/18`、`12/12`、`20/20`；valid launch/ERR_DESC completion 分别为 `14/4`、`10/2`、`15/5`。每 seed scenario bins `17/17`、UVM warning/error/fatal `0/0/0`，pending queues 均为 0。逐 seed 日志位于 `/tmp/nmaforge_a10_cp_mixedqueue_20261015/run_<seed>.log`。
- 此增量只修改 `dv/block/command_processor/uvm/` testbench，不改 RTL、ABI 或 DUT 时序。它加强错误 descriptor 与合法任务交错时的顺序/恢复证据；fetch/compute/dependency error 的广泛随机组合、长时间持续压力和所有队列 backpressure 组合仍未覆盖，因此 CP UVM 仍属于扩展 MVP。

### 2026-10-15 V3 真实 FP core 与 DMA/SPAD 并发

- 将真实 `ai_mixed_precision_dot_fp32_core` 接入 `dv/subsystem/dma_spad` testbench 的 arbiter-owned core SPAD 口；测试通过 `fp_mode` mux 选择真实 FP requester，原 scalar requester 场景保持不变。未修改产品 RTL/ABI/时序，只扩展 subsystem testbench、filelist、monitor 和 checkers。
- 新场景分别预置 64 个 BF16 与 FP16 `1.0×2.0` 元素；每个 dot 都与 32-word DDR model→SPAD DMA load 并发。每种格式的独立期望为 FP32 `128.0`（`0x43000000`），每 seed 检查 core result、SPAD host readback、64/64 accepted reads/responses、1 次结果写、peak outstanding=2，且 FP/DMA 双方均获得争用 grant。
- 命令：`make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10fp16dma SEEDS='12345 987654 20261014' URG_REPORT=/tmp/nmaforge_a10fp16dma_urg`。VCS/URG `V-2023.12-SP1_Full64` 三 seed 均 PASS；每个格式、每 seed 的 FP/DMA contended grants 均为 `5/6`，UVM warning/error/fatal=`0/0/0`。日志为 `dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_a10fp16dma_seed_<seed>.log`，fresh URG dashboard 为 `/tmp/nmaforge_a10fp16dma_urg/dashboard.html`；DMA command 与 arbiter 两个被选功能 covergroups 均 100%，不代表 code/assertion coverage 或 signoff。
- 同日 `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345`、`make -C dv/subsystem/top_smoke/sim ai_smoke` 和顶层 UVM 三 seed E2E 均通过。边界：FP/DMA workload 仍是固定向量 direct-start，不经过 CMDQ/真实 `ai_completion_writer`；不含 CNM、并发 error/abort/parity/protection 或系统性 fairness campaign，V3 仍部分完成。

### 2026-10-15 V3：FP 活跃期间 DMA AXI SLVERR drain 与恢复

- 在真实 `ai_axi128_dma` + `ai_accel_memory_fabric`（arbiter、behavioral scratchpad）环境中，分别让 BF16 和 FP16 dot core 运行，同时 DMA 读取 32 words；AXI responder 在地址 `0xF060` 对一个 R beat 注入 SLVERR。场景先接受 4 个 outstanding AR，再以 48-cycle burst 间隔延迟响应，用于检查错误出现时已有事务 drain，而不是提前结束。
- 每个 seed、每种格式均检查：DMA 错误与 FP busy 的重叠周期；4/4 已接受读请求完成/排空；恰好一个注入的 RRESP 错误被接受；错误路径无 DMA SPAD write；DMA、responder 与 outstanding 状态回 idle；FP 输出及 scratchpad 读回仍为 `0x43000000`；无需 reset 的下一笔 clean DMA transfer 成功。三 seed `12345/987654/20261014` 全部通过，UVM warning/error/fatal 均为 0。该定向测试不等同于随机故障位置、abort/parity/protection 组合或 CMDQ/真实 completion-writer 生命周期验证。
- 命令：`make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10errfpfix SEEDS='12345 987654 20261014' URG_REPORT=/tmp/nmaforge_a10errfpfix_urg`。VCS `V-2023.12-SP1_Full64`；逐 seed 日志为 `dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_a10errfpfix_seed_<seed>.log`，URG merge 目录为 `/tmp/nmaforge_a10errfpfix_urg/`（本地生成物，不提交）。
- 随后用当前工作树复跑 `make -C dv/block/dma/sim uvm_regress`（11/11 PASS，warning/error/fatal 均 0）、`make -C dv/subsystem/top_smoke/sim ai_smoke`（`TEST PASS`）及 `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345`（`TEST PASS`）。这些回归证明新 testbench responder 注入默认关闭时既有 DMA/top 测试未回归；仍是当前 dirty worktree 证据，不是固定 commit clean replay。

### 2026-10-15 V3：真实 CNM 四 lane 与 DMA load/store 共享 SPAD 并发

- 将现有 `ai_bank_pe`、`ai_bank_local_controller` 和 `ai_banked_cnm_core` 接入 `dv/subsystem/dma_spad` UVM testbench，连接真实 `ai_accel_memory_fabric` CNM requester；每 lane expected-word queue 检查 accepted request 与有序 response 的数据和归属，真实 CNM core 执行四 lane 点积。CNM result write 仍通过 scheduler-owned core SPAD port 回写。
- 并发场景一：CNM op `0x20`、K=8，四 lane 各 16 次 read/response；输入使每 lane 累加 80，global reduction 产生 320 (`0x00000140`)，与 32-word DDR→SPAD DMA load 共享仲裁。每 seed contended grants 为 CNM/DMA=`7/5`，request stall=5 cycles。
- 并发场景二：重置场景计数后，运行同一 CNM workload，同时执行 32-word SPAD→DDR DMA store；检查 CNM 结果写回、host readback 和 DMA AXI write scoreboard。每 seed contended grants 为 `1/3`，request stall=3 cycles。
- 该测试首先暴露真实 backpressure bug：`ST_WAIT_B` 在收到 B response 的同一周期尝试发 next-A prefetch；若 arbiter 不给 grant，状态仍留在 `ST_WAIT_B`，而 response 随后消失使 `req_valid` 一并消失，造成永久停顿。RTL 新增 `ST_PREFETCH_A`，在拒绝后保持 request/address，直到被接受；无背压时保留原同周期 prefetch 路径。增加 `ap_cnm_request_stable_when_stalled` SVA 检查 stalled valid/address 稳定性。
- 初次 URG assertion 报告为 0 的根因是 Makefile 只在 VCS 编译时传 `-cm/-cm_dir`，启动 `simv` 时漏传；已修正 `subsystem_run`，编译和运行阶段均传入覆盖参数。最终复跑命令：`make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10cnmcoveragefix SEEDS='12345 987654 20261014' URG_REPORT=/tmp/nmaforge_a10cnmcoveragefix_urg 'VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1'`。VCS 使用 `-assert svaext -cm line+cond+fsm+tgl+branch+assert`；Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`。三 seed 的 load 与 store 场景全部通过，逐 seed UVM warning/error/fatal=`0/0/0`，编译日志无 `Warning-`/`Error-`，未报告 assertion failure。fresh URG 中 DMA-command 与 arbiter 两个 selected functional covergroups 均为 100%；assertion report 总计 30 条、28 success、0 failure、0 incomplete，两个未尝试 assertion 属于 UVM RAL 内部，DUT properties 均有命中；`ap_cnm_request_stable_when_stalled` 合并后有 24 次 non-vacuous success。
- 另外在同一 RTL 下通过 `make -C dv/subsystem/top_smoke/sim ai_smoke` 及 `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345`，均为 `TEST PASS`。
- 证据边界：该初始 CNM/DMA campaign 的 K、地址和计算配置固定，且 CNM 由 subsystem test 直接启动，不经过 CMDQ/真实 `ai_completion_writer`；后续的 abort/recovery、K×M shape 与 reset/recovery 扩展见下方 2026-10-15 增量。**截至本初始 campaign** CNM reset、并发 parity/protection 和长时间 fairness 未闭合；后续 reset 覆盖仍仅为一个定向 phase。

### 2026-10-15 V3 增量：seeded CNM operands、DMA/CNM 相位扰动与有界公平性

- 将原来固定的 packed INT8 操数升级为 UVM seed 驱动的有符号 byte 数据；独立 testbench 参考模型按每个 lane、每个 packed word 计算 dot4，再计算四 lane reduction。monitor 以 host 实际写入地址建立期望数据表，逐个核对每个已接受 CNM read 的 response data/归属。三个 seed 的结果不同，分别为 `0x00000028`、`0x00000003`、`0xffffffd9`，且都与 CNM result 和 SPAD host readback 一致。
- 两种真实并发方向均保留：32-word DDR→SPAD DMA load 与 32-word SPAD→DDR DMA store。DMA 命令在首个 CNM request 出现后随机延迟 0–3 个时钟启动；每 seed、每方向四 lane 都是 16/16 accepted reads/responses，结果恰好写回一次，DMA store scoreboard 匹配 32 words。CNM stall 后的接受次数与最大连续 stall 均计数，不再把“恰好在 DMA valid 同周期获 grant”当作唯一公平性判据；三 seed 的最大连续 CNM stall 均为 1 cycle，load/store 均有 DMA 获准时 CNM 正在请求、CNM 曾被 stall、stall 后继续获准。
- 最终命令：`make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10cnmranddata SEEDS='12345 987654 20261014' URG_REPORT=/tmp/nmaforge_a10cnmranddata_urg 'VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1'`。Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`，每 seed UVM warning/error/fatal=`0/0/0`。load 的 accepted-under-overlap CNM/DMA grants=`7/4`、stall cycles=4；store=`0/2`、stall cycles=2；两场景的 CNM 最大连续 stall 均为 1、stall 后的 CNM grants 分别为 4/2。store 场景的 CNM 被 DMA 抢占，但之后 bounded-progress checker 验证其继续获准；不把未发生的同周期 CNM grant 记作 coverage。
- fresh URG 位于 `/tmp/nmaforge_a10cnmranddata_urg/`：30 assertions 中 28 success、0 failure、0 incomplete；两个未尝试项是 UVM RAL 内部 assertions。CNM request-stability SVA `ap_cnm_request_stable_when_stalled` 为 5,808 attempts、18 real successes、0 failures、0 incomplete。DMA-command 与 arbiter selected functional covergroups 均为 100%，这些指标不是完整 RTL code coverage 或 subsystem signoff。运行日志为 `dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_a10cnmranddata_seed_<seed>.log`。
- 2026-10-15 再增 CNM abort drain 与无复位恢复：三个 seed 均在四 lane 首批 read response 到达后发出 abort，检查完成状态为 `ERR_ABORT=3`、每 lane 接受/返回 `2/2`、所有 expected response FIFO 清空、没有 CNM result write，且 scratchpad 目标地址仍为 `0xfacebaad`；随后不复位，立即重发同一计算，核对四 lane 各 `16/16` reads/responses、一次结果写回及 host readback 与 seed oracle 一致。三个 seed 均 PASS，UVM warning/error/fatal=`0/0/0`。最终命令：`make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10cnmabortrecovery SEEDS='12345 987654 20261014' URG_REPORT=/tmp/nmaforge_a10cnmabortrecovery_urg 'VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1'`；日志为 `dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_a10cnmabortrecovery_seed_<seed>.log`。fresh URG 为 30 assertions、28 success、0 failure/incomplete，2 个未尝试项是 UVM RAL internal assertions；CNM request-stability assertion 为 5,964 attempts、18 real successes、0 failures/incomplete。
- 当前 abort 时点固定在首批四 lane response 之后，不是随机 abort campaign；**截至本段记录时** CNM reset 尚未覆盖（之后新增的一项 outstanding-read reset/recovery 见下方 `V3-CON-03`），parity/protection 错误组合与长时间多客户端 fairness 仍未覆盖。CNM 仍由 subsystem test 直接启动，不经过 CMDQ/真实 `ai_completion_writer`。本轮补上有限的 K×M GEMV shape sweep；完整 packed dot4 K 不支持 byte-tail/lane-mask，其他 fault/lifecycle 与更广 shape coverage 仍未闭合，V3 仍开放。
- 该 RTL 树同时重跑 `make -C dv/subsystem/top_smoke/sim ai_smoke VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，`TEST PASS`；VCS compile 版本 `V-2023.12-SP1_Full64`，smoke 使用 4 个 random cases / seed `12345`。此 top smoke 验证系统集成兼容，不替代新加 CNM abort 场景的 subsystem UVM 检查。

### 2026-10-15 V3 增量：seed-random CNM abort timing

- 将 CNM abort 从固定“首个四 lane 响应后”扩展为 seed 驱动的早期 abort：每次任务在 1–8 个已 scoreboard 检查响应/lane 中选阈值，四 lane 全部达到阈值后拉起 abort；原 drain、`ERR_ABORT=3`、无结果写、destination sentinel 及无复位恢复检查均保留。
- 三 seed 实际阈值：`12345 → 8`、`987654 → 7`、`20261014 → 6`。拉起 abort 时每 lane分别已有 `9/8`、`8/7`、`7/6` 个已接受读/已检查响应；最终各 lane 全部排空到 `10/10`、`9/9`、`8/8`，目标 `0x02a0` 保持 `0xfacebaad`，且随后的 clean CNM 任务无需 reset 即通过。每 seed UVM warning/error/fatal=`0/0/0`。
- 每 seed 命令：`make -C dv/subsystem/dma_spad/sim subsystem_run SEED=<seed> COV_TAG=a10cnmrandabort VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，其中 `<seed>` 依次为 `12345`、`987654`、`20261014`；合并命令：`make -C dv/subsystem/dma_spad/sim subsystem_coverage COV_TAG=a10cnmrandabort SEEDS='12345 987654 20261014' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg URG_REPORT=/tmp/nmaforge_a10cnmrandabort_urg`。三 seed运行与 URG merge 均通过；日志为 `dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_a10cnmrandabort_seed_<seed>.log`。
- Fresh merged URG `/tmp/nmaforge_a10cnmrandabort_urg/`：30 个 assertion 中 28 success、0 failure、0 incomplete、2 without attempts（UVM RAL internal）；`ap_cnm_request_stable_when_stalled` 为 14,669 attempts、18 real successes、0 failure、0 incomplete。该统计不替代更广的代码/功能覆盖闭环。
- 这是有限范围、seed-randomized 的 abort timing，不代表任意周期/并发故障的随机覆盖闭环；**截至本段记录时** CNM reset 尚未覆盖，后续已补一项 outstanding-read reset/recovery（见 `V3-CON-03`），但随机 reset phase、并发 parity/protection、AXI error × CNM abort 组合、长时间 fairness、CMDQ/真实 completion-writer 生命周期仍开放。随后重跑 `make -C dv/subsystem/top_smoke/sim ai_smoke`，以 `TEST PASS` 结束。

### 2026-10-15 V3 增量：CNM GEMV K×M shape sweep

- subsystem UVM 新增真实 `ai_banked_cnm_core` GEMV 形状 sweep，opcode `0x21`，K={1,2,8,9} 个完整 packed dot4 word、M={2,3,4} 个输出。每个 seed 覆盖所有 12 个 K×M 组合；每个 K 内 M 的执行顺序由该 seed 随机化。操作数由 seed 驱动，独立参考模型逐输出行做 dot4/reduction，并逐项检查四 lane read/response 数、aggregate read issue、reduction/write 数、SPAD host readback 和 UVM 错误。
- Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`，seeds `12345/987654/20261014` 均 PASS；每 seed K×M cross=12/12（100%），UVM warning/error/fatal=`0/0/0`。fresh merged URG `/tmp/nmaforge_a10cnmgemvshape_urg/` 的 `k_x_m` cross 为 12 expected / 12 covered / 0 uncovered（100%）；30 assertions 中 28 success、0 failure、0 incomplete，2 个未尝试项为 UVM RAL internal assertions；`ap_cnm_request_stable_when_stalled` 为 14,640 attempts、18 real successes、0 failure/incomplete。日志：`dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_a10cnmgemvshape_seed_{12345,987654,20261014}.log`。
- 可复现命令（从仓库根目录；Linux Rocky 交互环境提供 Synopsys license）：对 seeds `12345`、`987654`、`20261014` 分别执行 `make -C dv/subsystem/dma_spad/sim subsystem_run SEED=<seed> COV_TAG=a10cnmgemvshape VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`；随后执行 `make -C dv/subsystem/dma_spad/sim subsystem_coverage COV_TAG=a10cnmgemvshape SEEDS='12345 987654 20261014' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg URG_REPORT=/tmp/nmaforge_a10cnmgemvshape_urg`。同一工作树 `make -C dv/subsystem/top_smoke/sim ai_smoke` 也以 `TEST PASS` 结束。
- 这是选定 K×M shape 的 directed-complete、seed-random-order 测试，不是无约束随机 shape coverage。K 是完整 packed dot4 word 个数；CNM 端口没有 byte-tail/lane-mask 能力。测试仍直接启动 CNM，不覆盖 CMDQ/真实 `ai_completion_writer` 生命周期、随机 abort/error、并发 parity/protection 或长时间 multi-client fairness。**截至本段记录时** reset 未覆盖；后续单独新增了一个 outstanding-read reset/recovery 时点（见 `V3-CON-03`），仍未完成随机 reset-phase matrix；V3/A10 整体仍未 sign-off。

### 2026-10-15 V3 增量：CNM outstanding-read reset 与任务恢复

- subsystem UVM 新增 reset request/ack 握手：测试只驱动 `subsystem_reset_req`，由 testbench top 在 `negedge` 操作共享 `ctrl_if.resetn` 并回 ack；没有从 virtual-interface 的只读 `resetn` 反向驱动 reset。触发前 monitor 必须观察到 CNM 四 lane 各有一笔已接受、尚未对应 response 的 SPAD read。本场景在该点拉低公共 reset。
- 检查 reset 中 CNM `busy/done/error`、lane request/response valid 与 SPAD request 均清零；reset release 后观察四个周期，确认无 stale response/request/result write，monitor response queues 与 lane counters 清空，scratchpad destination sentinel `0xcafea8a8` 未改变。随后重写 operands 并重新登记 oracle，重新运行完整 K=8/M=1 CNM dot；逐 lane 检查 16/16 accepted reads/responses、一次结果写回和 host readback。三 seed 的独立 oracle/readback 结果分别为 `0xffffffec`、`0xffffffe8`、`0xffffff6e`。
- Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`，seeds `12345/987654/20261014` 均 PASS，UVM warning/error/fatal=`0/0/0`。每 seed 命令：`make -C dv/subsystem/dma_spad/sim subsystem_run SEED=<seed> COV_TAG=a10cnmreset VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`；合并命令：`make -C dv/subsystem/dma_spad/sim subsystem_coverage COV_TAG=a10cnmreset URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg URG_REPORT=/tmp/nmaforge_a10cnmreset_urg`。fresh URG：30 assertions 中 28 success、0 failure、0 incomplete、2 without attempts（UVM RAL internal）；`ap_cnm_request_stable_when_stalled` 为 15,617 attempts、18 real successes、0 failure/incomplete。运行日志为 `dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_a10cnmreset_seed_<seed>.log`，URG 位于 `/tmp/nmaforge_a10cnmreset_urg/`。
- 同一工作树随后执行 `make -C dv/subsystem/top_smoke/sim ai_smoke VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，`TEST PASS`（4 个随机用例，seed `12345`）。reset 证据仅覆盖 CNM 至少一笔已接受未响应读期间的一个 reset 时点及 clean recovery；尚不代表随机 reset 相位、writeback 中断、与 parity/protection/error 组合或完整 subsystem reset closure。CNM 仍 direct-start，不经过 CMDQ/真实 `ai_completion_writer`；V3/A10 整体仍开放。

## 结果摘要

| 范围 | 命令/结果 | 证据与边界 |
|---|---|---|
| FP Python reference | `python3.12 -m unittest -v test_fp_reference` — **19/19 PASS** | 覆盖 BF16/FP16 转换、RNE、subnormal、特殊值、FP32 运算及逐项舍入 dot；这是 reference-model 单测。 |
| FP RTL block | `make -C dv/block/compute/fp/sim dot-core-test` 与 `dot-core-random-test DOT_RANDOM_COUNT=256` — **PASS** | Directed block 检查 request stability 与 stalled writeback/abort commit point；附加 256 个 BF16 random vector 后共 263 个 transaction，bit-exact scoreboard PASS，special-class/stall coverage 被采样。最新 directed log：`/tmp/nmaforge_bf16_dot_fp32_core/run.log`；random log：`/tmp/nmaforge_bf16_dot_fp32_core/random_run.log`。 |
| FP UVM + URG | `make dot-uvm-regress DOT_RANDOM_COUNT=256 DOT_UVM_SEEDS='712345 987654 20261014' DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_fp_final4` — **PASS**；本轮补充 seed `42` 的复跑也 PASS | 正式三 seed 各 582/582 scoreboard PASS：536 个数值事务（BF16/FP16 各 268）+ 46 个 fault/reset 事务；总计 1,746 个事务，其中 1,608 个 bit-exact 数值事务。UVM warning/error/fatal 均 0；numeric、fault/reset format×mode、busy-start format×pulse、响应延迟 cross 均 100%，峰值 outstanding read=2。每 seed BF16/FP16 base/extended latency bins：`712345` 为 12/256、9/259；`987654` 为 15/253、14/254；`20261014` 为 11/257、18/250。watchdog-disabled 与 watchdog-masked-write-stall bins 均命中。非法 FSM encoding `4'hf` 恢复 IDLE 且无副作用。补充命令 `make dot-uvm-regress DOT_RANDOM_COUNT=256 DOT_UVM_SEEDS='712345 987654 42'` 三 seed 各 582/582 PASS，合并报告 `/tmp/nmaforge_bf16_dot_uvm/urg_report_merged/`；merged assertions 中 DUT request-stall SVA 成功，2 个未尝试项为 UVM 内部 RAL assertions。正式 URG 报告：`/tmp/nmaforge_a10_fp_final4/urg_report_merged/`。 |
| FP DUT code coverage | **功能覆盖通过；残余代码覆盖逐项 disposition 完成** | `ai_mixed_precision_dot_fp32_core`：line 97.96%（144/147）、condition 96.50%（193/200）、branch 92.86%（52/56）、综合 FSM 71.43%。`state_r` 为 5/5 状态、10/10 转移；`pending_error_r` 为 6/6 状态、10/18 转移，未命中转移属于 sticky first-error 生命周期不变量。剩余 7 个 condition outcomes 和 4 个 branch outcomes 已逐项映射到 RTL 互斥条件、已接受读/有序响应接口契约或错误截止语义；非法 FSM default 已通过注入测试命中。无 coverage exclusion。disposition 是动态仿真加 RTL 结构/协议分析，不等同形式证明。 |
| FP assertion | request-under-stall SVA — **PASS，无 failure** | 三 seed URG：34,928 attempts、10,761 real successes、0 failures、0 incomplete。另有 2 个 UVM 内部 RAL assertion 未尝试，不属于 DUT checker。 |
| Command processor UVM MVP (10/14 prior run) | `make -C dv/block/command_processor/uvm regress OUT=/tmp/nmaforge_a10_cp_sva_final SEEDS='12345 67890 24680'` — **3 seeds PASS** | 原回归已覆盖 success/descriptor-error/abort/fetch-error/compute-error/dependency-timeout、external fetch、CMDQ empty/CPLQ full、partial-write reset、tile ownership、17/17 scenario bins 与两条 completion-tail SVA。该次固定 5-command ring 结果已由上方 2026-10-15 随机混合环队列复跑扩展；完整当前证据见 [A10 RTM](A10_DV_RTM.md)。 |
| Reference precheck | `make -C dv/subsystem/top_smoke/sim ai_a4_ref` — **1000 cases PASS** | `A4_REFERENCE_PASS cases=1000 seed=20260722`；不代表 RTL simulation。 |
| DMA block UVM | `make -C dv/block/dma/sim uvm_regress` — **2026-10-14 post-fix: 11/11 PASS** | RTL error-drain 修正后重新编译执行 load/store、2D、gather、narrow、4 KiB、abort、配置错误、backpressure、20-case random stress；所有 scoreboard 通过，UVM warning/error/fatal=0。完整重跑日志：`/tmp/nmaforge_a10_dma_uvm_20261014.log`；Coverage VDB 在 `dv/block/dma/sim/coverage/`（受忽略，不纳入 Git）。 |
| DMA + SPAD subsystem UVM MVP + real BF16/FP16 contention | `make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10fp16dma SEEDS='12345 987654 20261014' URG_REPORT=/tmp/nmaforge_a10fp16dma_urg` — **3/3 PASS + fresh tagged URG merge** | 每 seed 实例化真实 `ai_axi128_dma` + `ai_accel_memory_fabric`（真实 arbiter 和 scratchpad，SRAM 深度缩小以加速仿真），AXI memory model 的 read/write backpressure 与 OOO response 开启。每 seed 共 8 笔 bit-exact DMA transfer、192/192 有序 scalar responses；另分别直接启动真实 `ai_mixed_precision_dot_fp32_core` 的 BF16/FP16 K=64，与 32-word DDR→SPAD DMA load 并发。每格式均为 64/64 reads/responses、1 次 SPAD result write、peak outstanding=2、FP/DMA contended grants=`5/6`；结果与 SPAD host readback 均为 `0x43000000`。DMA peak outstanding=4、RID/BID 乱序、descriptor/completion priority probe 和原 checker 保持通过；每 seed UVM warning/error/fatal=0。fresh tagged URG merge 的 DMA command 与 arbiter selected functional groups=100%；仅表示这些功能组，不代表 code/assertion coverage 或 subsystem signoff。report 位于 `/tmp/nmaforge_a10fp16dma_urg/`。FP direct-start 不经过 CMDQ/真实 `ai_completion_writer`；CNM、并发错误/abort/fairness 仍未覆盖。**有界真实 FP/DMA 并发通过；V3 总体验收仍开放。** |
| Control block UVM | Historical baseline: `make -C dv/block/control/sim uvm_regress` — **2026-10-14 refresh: 6/6 PASS; superseded by the 2026-10-15 eight-test rerun below** | 六项 reset/version、protocol、IRQ/error、busy/abort、random register R/W、RAL access 均通过；每项 UVM warning/error/fatal=0。逐项日志在 `dv/block/control/sim/logs/`。 |
| SPAD arbiter | `make -C dv/subsystem/top_smoke/sim ai_spad_arb_run` — **2026-10-14 PASS** | RR、公平轮转、response parity 对齐、CNM/DMA contention；CNM/DMA line grants=6/6。|
| Top smoke | `cd dv/subsystem/top_smoke/sim && make ai_smoke` — **2026-10-15 current-worktree rerun: TEST PASS** | 重新编译当前 dirty tree 的 28 个顶层模块，覆盖 directed 控制/DMA/队列/计算、FP16 DDR→DMA→SPAD→FP→SPAD→DMA→DDR、completion/错误/reset recovery；4 个随机 case、seed `12345`。VCS `V-2023.12-SP1_Full64`；本地 log `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`（忽略、不提交）。 |
| Top seeded regression | `cd dv/subsystem/top_smoke/sim && make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` — **2026-10-15 current-worktree rerun: TEST PASS** | 20-case 可重放随机 workload；日志在仿真生成的 `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`（忽略、不提交）。 |
| Shared top UVM ABI smoke | `make -C dv/uvm/sim uvm_smoke VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'` — **PASS** | 本轮发现旧 sequence 仍期待 A8 `0x10000008`，更新为当前 SPEC A10 `0x1000000a` 后重跑。UVM warning/error/fatal=0；仅作 ABI bring-up。Makefile 现按 test 名写入 `dv/uvm/sim/uvm_run_ai_version_smoke_test.log`，避免后续测试覆盖。 |
| Top UVM queued INT8/BF16/FP16 + descriptor error | `make uvm_mixed_precision_ddr_e2e_regress MIXED_E2E_SEEDS='20261014 712345 987654'`（在 `dv/uvm/sim`）— **2026-10-15 当前工作树复跑 3/3 seeds PASS** | 每 seed 在同一 CMDQ 按序提交 FP16 `0x51` task `0x0503`、BF16 `0x50` task `0x0504`、INT8 VDOT `0x10` task `0x0505`，随后在 slot3 提交非法 opcode `0xff` task `0x0506`。FP16/BF16 K=1/2 由 seed 控制；INT8 四 lane 均含负、零、正值。独立 oracle 检查结果；sequence 检查三组 SPAD/DDR 结果、成功 completion、错误 completion word0=`0x0506`/word1=`0x72`、`REG_ERROR=7`、CMDQ_HEAD/CPLQ_TAIL 环绕与 IRQ sticky/W1C；passive scoreboard 检查 operand AR/R 与 result AW/W/B。每 seed AXI-Lite 217 events、AXI4 21 events、UVM warning/error/fatal=0。日志：`dv/uvm/sim/uvm_run_ai_mixed_precision_ddr_e2e_seed_{20261014,712345,987654}.log`。广泛随机 descriptor、AXI 错误/reset campaign、其他错误类型、DDR PHY/板级和 coverage closure 仍未覆盖；旧 target `uvm_fp16_ddr_e2e` 保留为兼容别名。 |
| Top-level DMA AXI error drain | `make -C dv/subsystem/top_smoke/sim ai_dma_error_stress AI_SEED=<seed>` — **3 seeds PASS** | Seeds `314159/987654/20261014` 各随机选择 16-word/4-beat burst 中的 RRESP/BRESP SLVERR beat；每 seed 8 read + 8 write transactions。检查 read error code=2、write error code=3，且所有接受的 R beats/RLAST 和 B response 后 AXI memory model/DUT 回到 idle。此为带 seed 的 top-BFM stress，不是 UVM random campaign，也未与 FP/CNM 多客户端争用并发。完整日志：`/tmp/nmaforge_a10_dma_error_seed314159.log`、`/tmp/nmaforge_a10_dma_error_seed987654.log`、`/tmp/nmaforge_a10_dma_error_seed20261014.log`。 |
| FP 与 DMA/SPAD 争用吞吐 benchmark | `make -C dv/subsystem/top_smoke/sim ai_fp_dot_dma_benchmark FP_BENCH_SEED=20261013` — **24/24 PASS** | RTL error-drain 修正后复跑。BF16/FP16 长度 1/2/3/4/16/64/128/256/1024；单 tile 基线 + 三 tile ping-pong。ping-pong workload 对 AXI RVALID 响应间隔（seed-controlled 0–3 周期）及 WREADY backpressure 做伪随机化，并逐 tile 检查 completion 与 DDR 写回结果。1024 元素 MAC/job-cycle 为 BF16 0.57058、FP16 0.57164。`ai_smoke` 和 20-case seeded top regression 同样复跑通过；这不是 DDR PHY/板级验证。 |

## Control UVM refresh — in-flight reset closure (2026-10-15)

新增 `control_inflight_reset_test`，在真实 AXI-Lite adapter 的 write `WR_REQ`、`WR_RESP_ARM`、`WR_RESP` 和 read `RD_REQ`、`RD_WAIT`、`RD_WAIT2` 阶段分别断言 reset；每个场景在复位前先启用 IRQ 并注入 processor error event，确认 IRQ 已实际拉高，再检查 reset 清除 B/R response 与 IRQ，并通过复位后 VERSION read 验证恢复。为支持受测 reset，TB 的 resetn 驱动移至 test-only `ai_control_status_if`；未改产品 RTL、接口协议或寄存器 ABI。

Rocky 8.10 / Synopsys VCS+URG `V-2023.12-SP1_Full64` 证据：

- 命令：`cd dv/block/control/sim && make uvm_regress`；8/8 tests PASS，所有日志 UVM warning/error/fatal=`0/0/0`。单测日志位于忽略的 `dv/block/control/sim/logs/`。
- Fresh URG：`/tmp/nmaforge_a10_control_reset_irq_20261015/urg_final/`，列出 8 tests；`control_env_pkg::control_coverage::cg` 为 34/34 variables + 4/4 crosses（100%）。
- 7/7 DUT SVA 均有非空洞成功、0 failure/incomplete；AW/W/B/AR/R real successes=`10/10/83/5/89`，abort=1，IRQ-known=1102。2 个未尝试 assertions 属于 UVM RAL 内部。
- `axi_lite_reg_if` line/condition/toggle/FSM/branch=`97.30/94.12/66.76/100.00/90.91%`；write/read FSM transitions=`6/6`、`8/8`，包括全部 in-flight reset-to-idle 转移。`ai_accel_regs` line/condition/toggle/branch=`50.73/60.53/12.24/25.25%`。

本增量关闭了已识别的 AXI adapter FSM 中途 reset 转移缺口；Control register-file 与整体 RTL code coverage 仍不完整，V5 和 A10 全局 sign-off 仍开放。本轮没有修改 product RTL；在 Control UVM/TB 改动后又按 `cd dv/subsystem/top_smoke/sim && make ai_smoke` 与 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 检查当前工作树，二者均 PASS。所有这些仍是 dirty-worktree 证据，不是固定 Git commit 的 clean replay。

## DMA AXI read-error drain 回归（2026-10-14）

新增的 `ai_dma_error_stress` 首次暴露了真实 RTL 问题：`ai_axi128_dma` 在已接受 burst 收到非 OKAY `RRESP`（或 RLAST/长度不符）时直接转入 `ST_ERROR`，而 `m_axi_rready` 仅在 `ST_READ`/`ST_ABORT_READ` 拉高，导致错误 burst 剩余 beats 及其它已接受 burst 响应无人接收，DONE 可早于总线排空。

修复后读响应错误会禁止新 AR、清除已完成但尚未提交到 SPAD 的槽位，转入 `ST_ABORT_READ` 并继续消费已接受的响应直到每个 burst 的 RLAST；之后再走正常 error completion。scratchpad read failure 在读生命周期中也采用该 drain 状态。错误注入的 3 个 seed 每个各 8 个随机 beat-location 读 SLVERR 与 8 个写 SLVERR 均 PASS；检查 error code 和 DUT/BFM idle。该覆盖仍限单笔多-beat burst 的 seed-driven top stress，不代表 multi-outstanding error UVM closure。

修复后通过：DMA UVM 11/11（每项 UVM warning/error/fatal=0）、`ai_smoke`、`ai_run AI_RANDOM_CASES=20 AI_SEED=12345`、FP/DMA/SPAD benchmark 24/24。完整日志保存在 WSL `/tmp/nmaforge_a10_*_20261014.log` 和忽略的 smoke sim log 中，不纳入 Git。

## FP UVM coverage-fix 说明

在保留两个 outstanding read 的契约下，coverage transaction 携带预期 error/reset 与 fault mode。Scoreboard 只有在错误码、事务数量、部分累加元素数或 reset recovery 检查通过后才采样 fault/reset covergroup。Directed lifecycle cases 对 BF16 和 FP16 各执行一次，覆盖 23 类模式，包括三个单独地址错位、后续 pair parity、A/B/read protection、late protection prefix drain、late protection 与 abort 同周期竞争、六个活动状态 reset 及未接受请求 abort。另有 BF16/FP16 各一个 busy-start directed numeric transaction、unqualified parity sideband、watchdog-disabled 与 watchdog-mask-write-stall 边界、有序 SPAD response 的可复现随机延迟，以及长度 6 的双 slot fill/reuse 压力事务。TB 在 UVM 事务启动前注入非法状态编码 `4'hf`，检查下一拍恢复 IDLE 且无请求/done/error。最终每 seed 536 个数值事务（BF16/FP16 各 268）和 46 个错误/复位事务，共 582 个。

这组 UVM/TB-only directed additions 将 DUT line/condition/branch 从此前 97.28%/96.00%/91.07% 提升到 97.96%/96.50%/92.86%，不改变 DUT RTL、ABI、SPAD 时序或数值语义。5 个未命中 branch outcome 中的非法 FSM default 已由 `4'hf` 注入覆盖；剩余 4 个 branch outcomes 与 7 个 condition outcomes 按下表逐项 disposition。没有通过 URG exclusion 或删除 checker 隐藏缺口。

| 未命中 outcome | disposition 依据 |
|---|---|
| Condition（RTL 142）：`state_r != ST_RUN` 且 `read_request_enable=1` | RTL 的 `read_request_enable` 本身含 `(state_r == ST_RUN)`；同一条件又作为外层门控，因此该组合矛盾。 |
| Condition（RTL 180）：`outstanding_reads_r != 0` 为假且 `response_fire=1` | 需要对没有已接受 outstanding read 的周期送响应；这是违反 SPAD response 关联契约的 unsolicited response。FP UVM monitor 对该情形报错，合法 BFM 只对已接受请求按序应答。 |
| Condition（RTL 75）：cutoff-valid 为真但 pending error 不是 parity/protection | cutoff-valid 只在 parity/read-protection 首错时置位，并在 reset/新任务开始清除；正常任务生命周期内两者保持一致。结构/时序分析，非形式证明。 |
| Condition（RTL 78）：`state_r != ST_WRITE` 且 `spad_valid && spad_ready && spad_protection_error` | `write_protection_failure` 是以 `state_r == ST_WRITE` 开头的短路 `&&` 表达式；左项为 0 时后续项不被该表达式求值，故 URG 的该 MC/DC tuple 不可由输入激励命中。实际 read-protection 由独立 `read_protection_failure` 处理。 |
| Condition（RTL 83）：`state_r != ST_RUN`、其余 read-enable 项全真且 `read_request_enable=1` | `read_request_enable` 定义中已包含 `(state_r == ST_RUN)`，因此组合上不可能出现该 tuple；line 142 的重复状态门控同理。 |
| Condition（RTL 110）：`pair_ready=1` 且 `compute_allowed=0` | 在本接口契约下，memory error 对应的 A/B word 不会被标记 valid；已完成的 cutoff 前缀仍允许计算，所有相关 outstanding response 排空且前缀完成后进入 error。不会留下 cutoff 之后仍 pair-ready 的完整操作数对。late-B-protection 定向用例检查两种格式均 drain 4 reads、仅累计合法 pair-0 的 2 个元素且不写结果。结构/协议 disposition，非形式证明。 |
| Condition（RTL 110）：`ST_RUN` 中 `write_protection_failure=1` | `write_protection_failure` 定义要求 `state_r == ST_WRITE`，与 `ST_RUN` 互斥。 |
| Branch（RTL 179）：只发生 `read_fire` 且 outstanding 已满 | `read_request_enable` 在 outstanding=2 且本周期无 response 时阻止 read handshake；slot-reuse case 检查满槽 backpressure。 |
| Branch（RTL 182）：只发生 `response_fire` 且 outstanding=0 | 同 unsolicited response 协议违规；FP UVM monitor 会报错，合法有序 BFM 不产生。 |
| Branch（RTL 230）：RUN 错误锁存中的 write-protection-only cause | `write_protection_failure` 要求 `ST_WRITE`，与外层 `state_r == ST_RUN` 条件互斥。 |
| Branch（RTL 234 的隐式 else）：`failure_active=1` 但所有错误来源皆为 0 | `failure_active` 正是 abort、watchdog、parity、read/write protection 与既有 pending error 的逻辑或；外层 pending-error-none 条件下，显式 if/else-if 已穷尽全部来源。 |
| FSM `pending_error_r` 的 8 个未命中 error-to-error 转移 | 其中 `ERR_ABORT/PARITY/PROTECTION/WATCHDOG→ERR_CONFIG` 四个在新任务紧接着启动非法配置时可达：ST_IDLE 的 `pending_error<=ERR_NONE` 后，配置错误赋值在同一时钟块后续语句优先，覆盖为 `ERR_CONFIG`。目前 sequence 没有这些跨事务相邻场景，列为待补定向覆盖。其余 `ERR_ABORT/CONFIG/PARITY/PROTECTION/WATCHDOG→ERR_PROTECTION` 四个在正常 lifecycle 不可达：新合法任务先将旧 pending error 清为 NONE，protection 仅会在后续 ST_RUN/ST_WRITE 周期产生；非法配置则不会进入计算/写回。无形式证明。 |

以上 disposition 基于 RTL 定义与已验证 SPAD 协议；四个可达的 pending-error-to-config 转移仍须补测。因此 FP line/condition/branch 的主要残余已分类，但 V1-FP-04 尚未关闭；没有做形式不可达证明，若接口契约或 RTL 变更必须重新评估。

## 可复现命令

```bash
# FP UVM：三个 seed 与 URG merge（同一命令完成）
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_RANDOM_COUNT=256 DOT_UVM_SEEDS='712345 987654 20261014' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_fp_final4
make -C dv/block/command_processor/uvm regress \
  OUT=/tmp/nmaforge_a10_cp_sva_regress SEEDS='12345 67890 24680'

make -C dv/block/compute/fp/sim dot-core-test
make -C dv/block/dma/sim uvm_regress
make -C dv/block/control/sim uvm_regress
make -C dv/block/command_processor/uvm regress \
  OUT=/tmp/nmaforge_a10_cp_sva_final SEEDS='12345 67890 24680'
make -C dv/subsystem/dma_spad/sim subsystem_run SEED=12345
make -C dv/subsystem/dma_spad/sim subsystem_run SEED=987654
make -C dv/subsystem/dma_spad/sim subsystem_run SEED=20261014
make -C dv/subsystem/dma_spad/sim subsystem_regress
make -C dv/subsystem/top_smoke/sim ai_spad_arb_run
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/uvm/sim uvm_smoke
make -C dv/subsystem/top_smoke/sim ai_fp_dot_dma_benchmark FP_BENCH_SEED=20261013
```

DMA/SPAD 可复跑命令：

```sh
make -C dv/subsystem/dma_spad/sim subsystem_regress \
  COV_TAG=a10final VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

`subsystem_regress` 默认运行三个 seed、检查每次 UVM severity summary 且 warning/error/fatal 为 0，最后合并同一 `COV_TAG` 的 VDB。若重复执行且需要保持证据互不覆盖，请使用新的 `COV_TAG`。本轮 fresh report：`dv/subsystem/dma_spad/sim/coverage/urg_dma_spad_subsystem_test_a10final_3seed/`；VDB/log/HTML 均为本地生成物，不应提交。

## 范围结论

> 后续复核更新（2026-10-14）：下方较早摘要中关于 V4“两个 FP descriptor” 的状态，已由本轮三种算子 + 一条 `ERR_DESC` descriptor 的 mixed E2E 证据取代。当前准确边界见上表及 [A10 RTM](A10_DV_RTM.md)：已增加一个定向非法 opcode/队列环绕场景，但随机 descriptor、AXI error、reset recovery 与全覆盖 sign-off 仍开放。
>
> 2026-10-15 Command Processor 更新：下文较早的“五条 ring command”描述被随机长度 12–24 条、混合合法/非法 opcode 的三 seed UVM 结果取代。每条 descriptor 的 fetch/launch/retire 与 completion status/error 均由独立 queue model 检查；准确计数及边界见本页 2026-10-15 小节和 [A10 RTM](A10_DV_RTM.md)。

> 2026-10-15 V3 更新：较早记录中的“尚未使用实际 FP/CNM requester”现已过时。当前子系统 UVM 有真实 BF16/FP16 dot core 与 DMA load 并发（每格式 64/64 reads/responses、FP/DMA contended grants 5/6、peak outstanding=2、readback=`0x43000000`），也有真实四 lane CNM 与 DMA 的 seeded 数据并发（每 lane 16/16 reads/responses；oracle 结果为 `0x00000028`、`0x00000003`、`0xffffffd9`，load/store 均检查 stall 后进展）。CNM 有三 seed abort drain/recovery、两个定向 reset phase（每 lane 有 outstanding read；以及全部 16/16 reads/responses 到齐、result write 尚未接受），以及 K={1,2,8,9} × M={2,3,4} 的 GEMV shape cross（每 seed 与 merged URG 均为 12/12）；BF16/FP16 活跃时 DMA SLVERR drain/recovery 亦有三 seed 证据。上述 compute 场景仍直接启动，不经过 CMDQ/真实 completion writer；CNM byte-tail/lane-mask 不属于当前 K 契约，随机 reset phase、随机 abort/error 组合、并发 fault/fairness 与 V3 overall closure 仍未完成。

G0 已完成规格/RTL/ABI 对照，但冻结提交后的 clean-checkout replay 仍待执行；V1 的 reference、block、三 seed UVM bit-exact、功能 coverage 与 request-stall assertion 已通过。最终三 seed各 582/582；line/condition/branch/FSM 为 97.96%/96.50%/92.86%/71.43%，残余 outcome 和 error-FSM 转移均有逐项 RTL/协议 disposition，无 URG exclusion；这不是形式不可达证明。V2 command processor UVM MVP 三 seed、17/17 scenario bins 通过，新增独立 5-command fetch/launch/retire ring model 与分段 producer/random-delay consumer、真实 tile pipeline 三 tile buffer ownership/重叠 checker；还覆盖 internal/external fetch route、fetch/compute/dependency-timeout error completion 和 partial-write reset/recovery。tile 场景由 direct `tile_start` 驱动，尚未证明 CMDQ descriptor 可发起 tile job。V3 DMA/SPAD MVP 三 seed、每 seed 8 笔 DMA transfer 与 UVM severity gate 通过；fresh tagged URG 的 DMA command 和 arbiter functional covergroups 均为 100%（arbiter 4/4 client×contention bins）。本轮再增加真实 BF16 dot core 与 DMA load 的有界并发：每 seed 64/64 FP reads/responses、1 次结果写、peak outstanding=2、FP/DMA contended grants=5/6，结果与 SPAD readback=`0x43000000`；另有真实四 lane CNM/DMA load-store 并发、seeded abort/recovery、GEMV 12/12 shape cross 和单一 outstanding-read reset/recovery phase（详见上方 V3 增量及 RTM）。覆盖率仅针对所选功能 covergroups，不是代码/断言覆盖或完整 subsystem signoff。FP/CNM 均未通过真实 CMDQ/`ai_completion_writer` 生命周期；FP 与 CNM 同时争用、随机 reset phase、并发错误/abort、parity/protection 与系统性 fairness closure 仍未完成。V4 新增共享顶层 UVM BF16/FP16 两任务 DDR→DDR slice：三 seed检查随机精确操作数、K=1/2、两组结果/completion 与 IRQ；opcode、地址和其余 descriptor 字段仍固定。**完整 V4 top-level UVM 闭环仍未完成。**wait-then-release、完整通用 lifecycle reference model、更广泛随机并发 queue、compute-engine watchdog 与 subsystem coverage closure 仍未完成。DMA、Control block、directed top smoke 和 20-case seeded top regression 有实际回归证据；A10 计划中的随机 descriptor/error/reset top UVM、完整跨层 coverage closure/mutation 尚未实现，因此本记录不构成全芯片 verification sign-off。

### 2026-10-15 A10 当前工作树验证刷新

- FP arithmetic/reference：`cd dv/block/compute/fp/sim && make dot-core-test` PASS（`PASS: BF16 dot core block test`）；`cd dv/block/compute/fp/model && python3.12 -m unittest -v test_fp_reference` 19/19 PASS。独立 block test log `/tmp/nmaforge_bf16_dot_fp32_core/run.log`。
- FP block：三个 seed `712345/987654/20261014` 分别执行 `make dot-uvm-run DOT_RANDOM_SEED=<seed> DOT_RANDOM_COUNT=256 DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_fp_refresh_20261015`，随后 URG merge 到 `/tmp/nmaforge_a10_fp_refresh_20261015/urg_merged`。每 seed 582/582 bit-exact checks（536 numeric + 46 fault/reset），peak outstanding=2，numeric/response-latency/fault-reset/busy-start groups=100%，UVM warning/error/fatal=`0/0/0`。DUT request-under-stall SVA 34,928 attempts、10,761 real successes、0 failure/incomplete；另外 2 个 UVM RAL assertion without attempts。该结果复核现行最多两笔 outstanding 规格，但不等于全局 coverage closure。
- DMA block：在 Rocky 8.10 / VCS `V-2023.12-SP1_Full64` 下运行 `cd dv/block/dma/sim && make uvm_regress`，11/11 tests PASS，所有 UVM warning/error/fatal 均为 0；本地聚合日志 `dv/block/dma/sim/dma_block_regress.log`。本次不是 clean commit replay。
- DMA–SPAD subsystem：运行 `cd dv/subsystem/dma_spad/sim && make subsystem_regress COV_TAG=a10refresh15 URG_REPORT=/tmp/nmaforge_a10_dma_spad_refresh_20261015/urg`。默认 seeds `12345/987654/20261014` 均 PASS，三份 log 的 UVM warning/error/fatal=`0/0/0`，URG merge 成功；日志/VDB 在 `dv/subsystem/dma_spad/sim/`（生成物，不应提交），报告在 `/tmp/nmaforge_a10_dma_spad_refresh_20261015/urg/`。每 seed DMA command、arbiter selected functional groups 与 GEMV K×M shape cross 均 100%。URG whole-design dashboard score/line/condition/toggle/FSM/branch/assert/group=`67.95/70.60/58.26/40.85/53.01/59.35/93.55/100%`；此为该测试环境汇总，不能代表全项目 coverage closure。
- 独立 SPAD arbiter：`cd dv/subsystem/top_smoke/sim && make ai_spad_arb_run` PASS，CNM/DMA contention grant 各 6 次，round-robin 和 registered-response parity alignment 均通过。
- 同一工作树的 `cd dv/subsystem/top_smoke/sim && make ai_smoke` 与 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` PASS。Control 8-test UVM 与 Command Processor 三个 seed 也在本轮 A10 续跑中通过；详见 A10 RTM。此段证据不修改 DUT 规格或端口，且不替代提交冻结后的 final replay。
- 工具 shell 注意：非交互式 `bash -lc` 未继承 Synopsys 环境，VCS 报 `Cannot find 'vcsMsgReport' script in /bin`；使用已配置许可证的 Rocky 交互 shell `bash -ic` 后编译、仿真和 URG 均正常。该首次失败属于环境初始化，不是 RTL/test failure。

### 2026-10-15 V3 CNM parity × DMA contention 增量

- 在 `dv/subsystem/dma_spad/tests/dma_spad_subsystem_test.svh` 增加 testbench-only parity-bit fault campaign：真实四 lane CNM 访问共享 SPAD 时启动 32-word DDR→SPAD DMA load，并依次损坏每个 lane 的 A operand parity bit。每个场景检查 `ERR_PARITY=5`、每 lane 已接受读响应全部 drain、没有结果写、结果 sentinel 不变；随后恢复 parity、重新加载 operand，并用独立 dot-product oracle 和 SPAD readback 检查无复位恢复。
- Rocky 8.10 / VCS V-2023.12-SP1 / URG V-2023.12-SP1 三 seed 回归命令：
  `make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10cnmparity SEEDS='12345 987654 20261014' URG_REPORT=/tmp/nmaforge_a10cnmparity_urg VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg`
  结果三 seed PASS；每 seed lane 0..3 均有 `SPAD_CNM_PARITY_PASS`，UVM warning/error/fatal=`0/0/0`。新增 `cnm_parity_contention_cg` 在每 seed 与 merged URG 中均为 4/4（100%）。随后 `make -C dv/subsystem/top_smoke/sim ai_smoke` PASS，日志 `dv/subsystem/top_smoke/sim/ai_accel_smoke.log` 以 `TEST PASS` 结束。
- Fault injection 仅使用 VCS behavioral scratchpad RAM 的 UVM/testbench backdoor 翻转 parity bit，之后恢复原值；它覆盖 RTL parity detector、CNM error handling、响应排空及恢复行为，不代表 SRAM macro upset、ECC、物理故障模型或 silicon fault-injection。该增量没有改产品 RTL/ABI，也不等于 V3/V5 或 A10 验收关闭。仿真 log/VDB 与 URG HTML 留在本地生成目录，不应提交。
- 同轮交叉回归：`make -C dv/block/command_processor/uvm regress SEEDS='12345 67890 24680' OUT=/tmp/nmaforge_a10_cp_recheck_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs` 三 seed PASS，每 seed 18/18 scenario bins、UVM warning/error/fatal=`0/0/0`；`make -C dv/subsystem/top_smoke/sim ai_smoke` 与 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 均 PASS（VCS V-2023.12-SP1，10 ns `aclk`）。这些都是当前 dirty worktree 的回归，不是冻结 SHA 的 clean-checkout replay。
- 本轮再次刷新 block 基线：FP `make -C dv/block/compute/fp/sim dot-uvm-regress DOT_RANDOM_COUNT=256 DOT_UVM_SEEDS='712345 987654 20261014' DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_fp_current_recheck_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg` 三 seed 均为 582/582 bit-exact transactions，peak outstanding reads=2，numeric/response-latency/fault-reset functional groups=100%，UVM warning/error/fatal=`0/0/0`，URG merged 至 `/tmp/nmaforge_a10_fp_current_recheck_20261015/urg_report_merged`；Control `make -C dv/block/control/sim uvm_regress` canonical 8 tests PASS，severity `0/0/0`；DMA `make -C dv/block/dma/sim uvm_regress` 11/11 PASS，severity `0/0/0`。DMA 运行期间 Make 曾报告一次 WSL filesystem timestamp 的约 2 ms `Clock skew detected` warning，但回归命令退出码为 0、VCS tests 均完成；这是环境警告，应在 Linux-native workspace 重跑以消除，不把它当作 RTL warning。

### 2026-10-15 V3 CNM reset-phase 扩展

- 将 `run_cnm_reset_outstanding_recovery()` 扩展为两个有明确入口条件的 reset checkpoint：`accepted_read_outstanding`（每 lane 至少一笔 accepted read 尚无 response）与 `all_reads_returned_prewrite`（每 lane 16/16 accepted/read responses，CNM 仍 busy，`cnm_spad_valid=0` 且没有 result write 被接受）。新增 `cnm_reset_phase_cg`，要求两个 phase 均有覆盖。
- 两个 checkpoint 在 reset 中均检查 CNM busy/done/error/request/response/SPAD valid 清零；release 后检查连续 4 周期无 stale activity、monitor response queues/lane counters 清空和 destination sentinel `0xcafea8a8` 未改变。之后重装 operands 并完整重跑 K=8/M=1 CNM，检查四 lane 16/16 response、唯一结果写以及独立 oracle/SPAD readback。
- Rocky 8.10 / VCS V-2023.12-SP1 / URG V-2023.12-SP1 命令：在已初始化 Synopsys 环境的 WSL `bash -ic` 中，`cd /mnt/e/workspace/chip/NMAForge/dv/subsystem/dma_spad/sim && make subsystem_regress COV_TAG=a10cnmresetphase2 VCS=vcs URG=urg URG_REPORT=/tmp/nmaforge_a10_cnmresetphase2_urg`。默认 seeds `12345/987654/20261014` 全 PASS；每 seed UVM warning/error/fatal=`0/0/0`，两个 reset recovery 均成功。merged `cnm_reset_phase_cg` 两个 bin 各命中 3 次，100%；dashboard 位于 `/tmp/nmaforge_a10_cnmresetphase2_urg/dashboard.html`。随后 `cd /mnt/e/workspace/chip/NMAForge/dv/subsystem/top_smoke/sim && make ai_smoke` 与 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 均 PASS。
- 此项只覆盖两个固定 reset checkpoint；不覆盖随机复位时刻、result write handshake 进行中复位、异步/独立 accelerator reset、复位期间外部 DDR 继续响应或与 parity/protection/abort 的随机组合。没有修改产品 RTL。仿真日志、VDB 与 URG 报告均为可再生成的本地输出，不应提交；所有回归基于 dirty worktree，不是 clean fixed-SHA replay。

### 2026-10-15 V3 CNM × DMA SLVERR drain overlap

- 在 `dv/subsystem/dma_spad/tests/dma_spad_subsystem_test.svh` 新增真实 CNM active 与 DMA read-error drain 场景：四-lane CNM 做 K=8/M=1 dot；DMA 同时接受 4 笔 read，responder 在 newest-first 首个 response beat `0xF060` 注入一次 SLVERR。检查 CNM busy/error overlap、DMA 4/4 accepted/completed、outstanding drain 到 0、失败 command 无 DMA SPAD grant/write、CNM 每 lane 16/16 reads/responses 与 oracle/readback、以及无 reset 的后续 DMA clean-load recovery。
- 首轮使用 48-cycle response delay 时，DMA SLVERR 晚于短 CNM busy window；UVM 正确报 overlap 未命中，说明 stimulus timing 不满足目标。将这个新场景 delay 调整为 8 cycles 后重新运行；只对该场景绕过 `check_cnm_complete()` 内“必须发生 arbiter DMA grant/stall/fairness”的 contention-only 条件，结果/response/writeback checker 仍启用。此用例是 engine activity/error-drain overlap，不是 SPAD contention：因为 newest-first 首个 response 就是错误 beat，错误前本来就不应有 DMA SPAD grant。未删除或放宽其他争用测试检查。
- Rocky 8.10 / VCS、URG V-2023.12-SP1：focused `make subsystem_run SEED=12345 COV_TAG=a10cnmerrphase3 VCS=vcs` PASS；三 seed `make subsystem_regress COV_TAG=a10cnmerrphase3 VCS=vcs URG=urg URG_REPORT=/tmp/nmaforge_a10cnmerrphase3_urg` PASS，seeds `12345/987654/20261014`，每份 UVM warning/error/fatal=`0/0/0`。merged URG 的 `cnm_dma_error_overlap_cg` 两个 coverpoint 与 overlap×drain cross 均 100%，报告 `/tmp/nmaforge_a10cnmerrphase3_urg/dashboard.html`。另 `make ai_smoke` 与 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` PASS。
- 本次只改 testbench，不改产品 RTL、接口或 ABI。测试固定了故障地址与延迟；不代表随机 DMA error timing、error×abort/reset 组合、真实 CMDQ/`ai_completion_writer` CNM 生命周期或 V3/A10 closure。VCS log/VDB 和 URG HTML 是本地生成证据，不应提交；结果来自 dirty worktree，仍需冻结后的 clean-checkout replay。

### 2026-10-15 V3 SLVERR response-position sweep under CNM contention

- 将 `V3-ERR-04` 的首响应 SLVERR case 保留，并将故障位置扩展为 newest-first 响应流中 0、1、2、3 个成功 burst 后注入 SLVERR。每个 case 运行真实四-lane CNM K=8/M=1 dot 与 DMA 4-read load；DMA 目标预置 sentinel。checker 对目标 32 words 逐 word readback，要求成功提交数严格为 `0/8/16/24`，成功前缀与失败/未提交范围不得被污染；同时检查 4/4 AR response drain、outstanding 回零、CNM oracle/readback 与后续无复位 DMA recovery。
- 响应延迟针对不同故障位置作定向配置，保证预期的 4 笔 AR 已接受后再发出早/中位错误；最晚位置因前序成功响应自然有更多时间接受 AR。每 seed 四种位置均与 CNM busy/error 窗口重叠；除零成功 burst 的 control 外，真实 CNM/DMA contention grant 分别为 1、3、3 次。结果覆盖 SLVERR 触发后已提交数据保留与未提交槽 drain 的不同边界，而非仅仅验证 error bit/drain。
- Rocky 8.10 / VCS 与 URG V-2023.12-SP1：focused `make subsystem_run SEED=12345 COV_TAG=a10cnmerrpos4fix1 VCS=vcs` PASS；默认 seeds `12345/987654/20261014` 的 `make subsystem_regress COV_TAG=a10cnmerrpos4 VCS=vcs URG=urg URG_REPORT=/tmp/nmaforge_a10cnmerrpos4_urg` 全 PASS，各 seed UVM warning/error/fatal=`0/0/0`。URG merged group 4 个位置 bins 各命中 3 次，scenario/drain cross 4/4、error-overlap/drain cross 1/1（100%）。随后 `make ai_smoke` 与 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` PASS。日志、VDB 与 URG dashboard 保存在本地 `/tmp`，不应提交。
- 早期调试运行曾在响应等待不足时触发 SLVERR，令 DMA 在全部 4 笔 AR 接受前停止发新请求；据此将最终 checker 约束为先确认完整接受窗口再核对四位置结果。最终三个 seed 均有 accepted/completed=4/4。本增量仅改 subsystem testbench/checker 与文档，无产品 RTL/ABI 修改。故障位置与等待仍为 directed sweep，不覆盖随机 error timing、error×abort/reset、独立 accelerator reset，也不关闭 V3/A10。证据来自 dirty worktree，仍需冻结 SHA 后 clean-checkout replay。

### 2026-10-15 V3 CNM × DMA abort-drain overlap

- 新增 testbench-only subsystem scenario：真实四-lane CNM K=8/M=1 dot 运行时，启动 32-word DDR→SPAD DMA load，允许四笔 AXI read outstanding，并在首个 R response 发出前由真实 DMA command driver 发送 abort。检查 abort 脉冲确实落在 CNM busy 窗口内、DMA 的四笔已接受读均响应 drain、outstanding 回零、DMA 未对 SPAD 发写 grant、32-word 目标 sentinel 全部保留，CNM oracle/readback 正确。
- 采用 Rocky 8.10 / VCS V-2023.12-SP1：focused `make subsystem_run SEED=12345 COV_TAG=a10cnmabort1 VCS=vcs` PASS；`make subsystem_regress COV_TAG=a10cnmabort1 URG_REPORT=/tmp/nmaforge_a10cnmabort1_urg` 默认 seeds `12345/987654/20261014` 全 PASS。每 seed UVM warning/error/fatal=`0/0/0`，abort/CNM overlap=1 cycle、accepted/completed=4/4、read highwater=4、DMA SPAD commits=0，并且无需 reset 的 clean DMA recovery PASS。`cnm_dma_abort_overlap_cg` 的 overlap、drain、no-commit、four-outstanding bins 各命中 3 次（100%）。随后 `make ai_smoke` 与 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 均 PASS。
- 本增量未修改产品 RTL、接口或 ABI；仅覆盖固定 abort 时刻/首响应延迟的 directed overlap，不代表随机 abort timing、abort×error/reset 全组合、CMDQ/真实 completion-writer 生命周期或 V3/A10 closure。log/VDB/URG 留在本地生成目录；结果来自 dirty worktree，仍需冻结 SHA 后 clean-checkout replay。

### 2026-10-15 V4 两拍 DMA SLVERR 位置与 burst 原子提交

- 顶层 mixed-precision UVM 将原单字 SLVERR probe 扩展为两个独立的两拍/8-word DMA read burst：一个在首个 R beat 出错，另一个在末拍（RLAST）出错。被测 AXI response monitor 按 RID 追踪至 RLAST，并检查每笔 burst 的 beat 数与恰好一个 SLVERR；sequence 核对 `ERR_AXI_RD`、DMA sticky status 清除，以及目标八个 SPAD word 均保持 sentinel。
- 首轮测试暴露了 test expectation 错误：曾假设末拍 SLVERR 会保留前四个 word。检查 `rtl/dma/ai_axi128_dma.v` 后确认 DMA 将数据先放入 burst buffer，只在成功的 OKAY RLAST 后将完整 burst drain 到 SPAD；因此正确要求是任一 beat SLVERR 都取消整笔 burst，不能提交任何 word。修正 stimulus/checker 预期后，不需改 DUT RTL，且 PASS marker 只在全部 sentinel 检查之后打印。
- Rocky 8.10 / VCS V-2023.12-SP1：`cd dv/uvm/sim && make uvm_mixed_precision_ddr_e2e` focused PASS；`make uvm_mixed_precision_ddr_e2e_regress` 六个固定 seeds/order/layout PASS，UVM warning/error/fatal=`0/0/0`；`make uvm_mixed_precision_ddr_e2e_cov_regress MIXED_E2E_COV_OUT=/tmp/nmaforge_a10_v4_errorpos_cov_check_20261015` 的 16 runs 与 URG merge PASS。新 `dma_error_position_cg` 两个 bins `before_burst_last/on_burst_last` 各命中 16 次，2/2（100%）；报告 `/tmp/nmaforge_a10_v4_errorpos_cov_check_20261015/urg_merged/grpinfo.txt`。测试脚本现将两种位置 marker 与 `cp_error_position=2/2` 作为显式通过门槛。
- 本增量只改顶层验证序列、scoreboard、Makefile 与验证文档，不改产品 RTL/ABI。它是确定地址/单错误 beat 的 directed burst-atomicity 检查；随机 SLVERR×abort/reset、其它 burst 长度/多个 outstanding 交织，以及完整 V4/V5 closure 仍未完成。仿真/coverage 工件留在 `/tmp` 或忽略的本地 build 目录；证据来自 dirty worktree，不是冻结 SHA 的 clean replay。
- 继续用当前更新后的序列执行 `cd dv/uvm/sim && make uvm_mixed_precision_ddr_e2e_random_cov_regress MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_errorpos_random_20261015`，固定 seeds `20261101..20261292` 全部 192/192 PASS；逐日志 UVM warning/error/fatal=`0/0/0`，每个 seed 都通过首拍与末拍 SLVERR 场景。URG 中 `dma_error_position_cg` 的 `before_burst_last/on_burst_last` 各命中 192 次；`e2e_cg` 为 53/53 variables + 16/16 crosses（100%），报告 `/tmp/nmaforge_a10_errorpos_random_20261015/urg_merged`。这是在随机合法 descriptor/order/layout/K/operands 和固定每-run AXI gap 配置下重跑；错误 beat 位置本身仍为两种 directed case，故不代表随机错误注入或 fault×abort/reset coverage。全局 code/assertion coverage 与 V4/V5/A10 仍 OPEN。

### 2026-10-15 A10 V2 compute-abort/re-doorbell 验证增量

- 新增真实 `ai_command_processor` + `ai_completion_writer` 场景：任务 `0x1200` 已进入 compute 后，mock compute endpoint 返回 `ERR_ABORT`。checker 逐项核对恰好一条 abort completion、没有自动启动下一命令，且 CMDQ head/CPLQ tail 保持为 1；testbench 随后显式 doorbell，任务 `0x1201` 成功 launch/retire，最终 head/tail=2。
- 增加 compute-abort launch-suppression SVA；`compute_abort_inputs=1` 证明 assertion antecedent 每次运行实际命中。最终验收 marker 为 `compute_abort_inputs=1 launches=2 completions=2`，场景 coverage `19/19`。
- Rocky 8.10 / VCS `V-2023.12-SP1_Full64`，在 `dv/block/command_processor/uvm` 对每个 seed 分别运行：`make regress SEEDS=<seed> OUT=/tmp/nmaforge_a10_v2_compute_abort_20261015_final VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，`<seed>` 取 `12345`、`67890`、`24680`。三 seed 全 PASS；每份日志 `/tmp/nmaforge_a10_v2_compute_abort_20261015_final/run_<seed>.log` 均报告 `19/19`、上述 abort marker 与 UVM warning/error/fatal=`0/0/0`。`ai_smoke` 与 `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 此前 PASS；它们在最后仅收紧 checker counter 门槛之前完成，之后三 seed CP regression 重新执行通过。
- 仅修改 CP 验证环境、SVA、Makefile 门槛和文档，不改 DUT RTL/ABI。此为 compute-abort 后显式重新 doorbell 的定向场景，不证明其他错误与 abort/reset 的随机交织，也不关闭 V2/V5/A10。结果来自 dirty worktree，冻结 SHA 后需 clean-checkout replay。

### 2026-10-15 A10 V3 DMA/SPAD 10-seed regression 增量

- URG `asserts.html` 明细将两项 unattempted assertions 列为 `uvm_pkg::uvm_reg_map::do_read` 与 `uvm_pkg::uvm_reg_map::do_write`（Synopsys UVM library）；不属于 DUT assertion。
- Rocky 8.10 / VCS、URG `V-2023.12-SP1`。新增 seed `20261020..20261029`，通过 canonical target `cd dv/subsystem/dma_spad/sim && make subsystem_regress SEEDS='20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027 20261028 20261029' COV_TAG=a10_10seed_20261015 URG_REPORT=/tmp/nmaforge_a10_dma_spad_10seed_20261015/urg` 运行。
- Regression exit code 0；10/10 seeds 各有独立 run/compile log 与 VDB，所有 seed UVM warning/error/fatal=`0/0/0`，tagged compile logs 无 `Warning-`/`Error-`。URG 合并目录：`/tmp/nmaforge_a10_dma_spad_10seed_20261015/urg`；VDB：`dv/subsystem/dma_spad/sim/coverage/dma_spad_subsystem_test_a10_10seed_20261015_seed<20261020..20261029>.vdb`。
- URG 的 selected functional groups 为 100%；assertion 汇总 31 项，29 success、0 failure、0 incomplete、2 unattempted。整体 code/condition/toggle/assertion dashboard 不是全覆盖，不能据此宣称 subsystem signoff。旧 3-seed suite 的定向检查边界仍适用；V3/V5/A10 closure 仍开放。
- 该 campaign 只增加验证运行与本地忽略的仿真/coverage 工件，没有修改 RTL。结果来自 dirty worktree；冻结提交后仍需在 clean checkout 统一 replay。

### 2026-10-15 A10 V2 Command Processor 10-seed regression

- Rocky 8.10 / VCS `V-2023.12-SP1_Full64`。在 `dv/block/command_processor/uvm` 执行：`make regress SEEDS='20261030 20261031 20261032 20261033 20261034 20261035 20261036 20261037 20261038 20261039' OUT=/tmp/nmaforge_a10_cp_10seed_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`。非交互 login-shell 缺少 `LM_LICENSE_FILE`；通过 WSL interactive shell 初始化后运行成功，且显式设置 `VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1`。
- VCS compile 成功且 compile log 无 `Warning-`/`Error-`；10/10 run logs 通过 Makefile `check-log`，每 seed `scenario_bins=19/19`、UVM warning/error/fatal=`0/0/0`，compute-abort marker=`compute_abort_inputs=1 launches=2 completions=2`。随机 ring 每 seed 12–22 条 command，accepted=retired，expected outcome queues 清空；四类随机结果 `ERR_DESC/ERR_FETCH/ERR_COMPUTE/success` 每 seed 均非零。日志位于 `/tmp/nmaforge_a10_cp_10seed_20261015/run_<seed>.log`，compile log 位于同目录 `compile.log`。
- 本 campaign 只扩展 seed 数，没有添加 scenario 或 coverage model，不表示错误×abort/reset 组合已随机覆盖，也不关闭 V2/V5/A10。证据来自 dirty worktree，冻结 SHA 后仍需 clean-checkout replay。

### 2026-10-15 A10 V2 compute-abort × partial-completion reset/recovery

- 在 CP UVM 场景 19 增加真实 command processor + completion writer 的交叉验证：CMDQ 先发布两条命令；第一条 compute 收到 abort，期望 `ERR_ABORT=3`；completion word0 接受后强制 word1 backpressure，检查 CPLQ tail 仍为 0、CMDQ head=1 且第二条命令未 launch。然后 reset，检查 writer/CP 回 idle、半条 completion 不被提交，再执行一条干净命令并要求成功 completion exactly-once。
- 同步增加 non-vacuous abort/reset monitor counters、scenario bin 19、completion status/task-ID checks、completion-write stability 与 compute-abort launch-suppression SVA；Makefile `check-log` 现要求 20/20 bins 以及 abort/reset recovery marker。只修改 CP UVM/interface SVA/Makefile，不改产品 RTL/ABI。
- Rocky 8.10 / VCS `V-2023.12-SP1_Full64`。Focused：在 WSL interactive shell（继承已配置的 license 环境）导出 `VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1` 后运行 `cd dv/block/command_processor/uvm && make run SEED=12345 OUT=/tmp/nmaforge_a10_cp_abort_reset_focus_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，PASS。随机扩展运行 `make regress SEEDS='20261040 20261041 20261042 20261043 20261044 20261045 20261046 20261047 20261048 20261049' OUT=/tmp/nmaforge_a10_cp_abort_reset_10seed_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，10/10 PASS；compile log 无 `Warning-`/`Error-`。
- 每个新 seed 均报告 scenario bins `20/20`、`abort_inputs=1 recovery_launches=1 recovery_completions=1 partial_resets=2`、UVM warning/error/fatal=`0/0/0`。随机 ring 每 seed 12–21 条命令，accepted=retired 且四类 `ERR_DESC/ERR_FETCH/ERR_COMPUTE/success` outcome 均非零。日志在 `/tmp/nmaforge_a10_cp_abort_reset_10seed_20261015/run_<seed>.log`。
- 这是定向 abort→partial completion→reset→recovery 交叉场景，不是随机 fault×abort×reset campaign；V2/V5/A10 仍开放。结果来自 dirty worktree，冻结 SHA 后需 clean-checkout replay。

### 2026-10-15 FP 双 outstanding-read 契约复核

- 用户确认保留现有最多两笔已接受未返回 read 的产品契约，并要求同步 SPEC。规范现明确：每周期至多呈现一个新 SPAD request；两个 operand-pair buffer 最多保持两笔 outstanding read；由于 core response 没有独立 read ID，响应必须按接受顺序返回，不支持乱序。
- Rocky 8.10 / VCS `V-2023.12-SP1_Full64` focused command：`make -C dv/block/compute/fp/sim dot-uvm-run DOT_RANDOM_SEED=20261015 DOT_RANDOM_COUNT=64 DOT_UVM_OUT_DIR=/tmp/nmaforge_fp_two_outstanding_recheck_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`。Compile 与仿真 PASS；152 个 numeric + 46 个 fault/reset transactions，共 `198/198` bit-exact；peak outstanding reads=`2`；numeric、latency、fault/reset、busy-start functional coverage 均 `100%`；UVM warning/error/fatal=`0/0/0`。日志和 VDB 位于 `/tmp/nmaforge_fp_two_outstanding_recheck_20261015/seed_20261015/`。
- 本次是单 seed 的契约复核，没有重新 merge URG，也不是新 RTL/PPA 结果；它确认该 2-entry contract 在当前工作树中可达到并按序工作。全项目 A10/V5 closure 与冻结 SHA 的 clean-checkout replay 仍开放。

### 2026-10-15 V2 descriptor dependency-event disposition

- 复核 `rtl/control/queue/ai_command_processor.v`：`dependency_events` 是输出寄存状态；端口没有外部 event-set 输入，状态由 command descriptor 的 signal mask 在成功完成时发布。当前 ABI 可表达并已验证“前一 producer 成功发布 event → 后一 consumer wait mask 满足”，以及缺失 event 时阻塞后 abort/`ERR_DEPENDENCY` timeout。
- 最新 CP UVM campaign `20261040..20261049` 的 10 份日志已重新核对：每份 `scenario_bins=20/20`、abort/reset recovery marker 完整、UVM warning/error/fatal=`0/0/0`；compile log 无 `Warning-`/`Error-`。日志目录 `/tmp/nmaforge_a10_cp_abort_reset_10seed_20261015/`。
- “consumer 已等待后由外部异步 producer 释放”不是当前接口/ABI定义的需求；本计划不新增该行为或 RTL 接口。若未来需要，作为单独架构扩展定义并新增验证，不作为当前 V2 缺失项。本 disposition 不等于 V2 全面 closure；随机 fault×abort/reset、queue pressure 与统一跨层 coverage 仍开放。

### 2026-10-15 A10 V3 DMA/SPAD 20-seed URG 合并

- Rocky 8.10 / VCS、URG `V-2023.12-SP1`。新增 seeds `20261050..20261059`。先在 `dv/subsystem/dma_spad/sim` 执行 `make subsystem_compile SEED=20261050 COV_TAG=a10_current_10seed_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，再用同一插桩仿真器逐 seed 启动 `./simv_dma_spad_uvm`，每个 seed 指定独立 `-cm_dir` 和 `-l`；10 个 seed 的实际值均由 UVM log 核对。
- 新增 seed `20261050..20261059` 的 10/10 run logs 均有 UVM report summary、warning/error/fatal=`0/0/0`；每 seed 核对 192/192 core read responses、DMA command functional coverage=100%、arbiter functional coverage=100%、CNM parity/protection 与 GEMV K×M shape cross=100%。compile log 无 `Warning-`/`Error-`。
- 将两组 seed `20261020..20261029`、`20261050..20261059` 的 20 个独立 VDB 再次统一合并，最终报告 `/tmp/nmaforge_a10_dma_spad_20seed_merge_20261015/urg`，`dashboard.html` 存在。合并 total score/line/condition/toggle/FSM/branch/assert/group=`68.59/71.30/59.40/42.14/53.01/60.73/93.55/100%`；assertions 31 项，29 success、0 failure、0 incomplete、2 without attempts（UVM RAL `do_read`/`do_write`，Synopsys UVM library）。选定功能组 100% 不代表整个 RTL code coverage 或 V3 signoff。
- 本批仅做仿真/coverage，不改 RTL。V3 的 CMDQ/真实 completion-writer 集成生命周期、随机 fault×abort×reset 组合、长时 fairness 与未覆盖项 disposition 仍开放。结果来自 dirty worktree，冻结改动后仍需 clean-checkout replay。

### 2026-10-15 A10 当前工作树 Top Smoke 复核

- Rocky 8.10 / VCS `V-2023.12-SP1_Full64`，interactive WSL license environment。运行 `cd dv/subsystem/top_smoke/sim && make ai_smoke`，编译/elaboration 无 warning/error，仿真结束 marker 为 `TEST PASS`；配置 `ACLK_PERIOD_NS=10.0`、`AI_RANDOM_CASES=4`、`AI_SEED=12345`。
- 本次 smoke 检查 ABI v7.4、queue/completion、FP16/BF16、DDR→SPAD→FP→SPAD→DDR、Transformer descriptor chain 和 reset recovery；VCS log `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`，compile log `ai_comp.log`。
- 此为当前 dirty worktree 的 smoke 复核，不能替代固定提交 clean-checkout replay，也不代表 A10 总体验收关闭。

### 2026-10-15 A10 V2 随机前序错误 × compute abort × partial reset/recovery

- 在 CP UVM 新增 scenario 20（总场景 21 个）：随机选择前序 descriptor-invalid (`ERR_DESC`) 或 descriptor-fetch failure (`ERR_FETCH`)，其后启动 compute 并随机等待 0–5 个时钟周期再发 abort；核对 prefix error、`ERR_ABORT=3`、队列中后续 command 未自动 launch、completion word0 接收而 word1 受 backpressure、CPLQ tail 未提交；随后 reset 丢弃 partial completion，提交新 task 并检查 exactly-once 成功恢复。
- Checker 对三次 completion attempt 按 task ID/status/error 逐项比对，单独计数 mixed scenario 的 abort event（非空洞 marker `abort_inputs=1`）；现有 SVA 检查 compute-abort 后不自动 launch。Makefile `check-log` 要求 `scenario_bins=21/21`、abort/reset/recovery counters、mixed marker 与 UVM severity 全零。只修改 CP UVM、interface SVA、Makefile 和验证文档；未修改 DUT RTL/ABI。
- Rocky 8.10 / VCS `V-2023.12-SP1_Full64`。50-seed regression 从 `dv/block/command_processor/uvm` 执行：`export VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 && make regress SEEDS="$(seq 20261061 20261070) $(seq 20261301 20261340)"`，50/50 PASS；compile/run log 在 `/tmp/nmaforge_cp_uvm/`，每 seed Makefile `check-log` 均通过，scenario 21/21，UVM warning/error/fatal=`0/0/0`。环形随机队列每 seed accepted=retired、12–24 条任务、`ERR_DESC/ERR_FETCH/ERR_COMPUTE/success` 四类结果均非零。
- 从 50 份 scoreboard marker 汇总的 `prefix_kind × abort_delay` stimulus 计数如下（这是 run-log 聚合，不是 URG/VCS coverage database merge）：

  | 前序错误 | delay=0 | 1 | 2 | 3 | 4 | 5 |
  |---|---:|---:|---:|---:|---:|---:|
  | `ERR_DESC` | 1 | 2 | 2 | 14 | 6 | 5 |
  | `ERR_FETCH` | 1 | 6 | 5 | 2 | 4 | 2 |

- 最终版本上 `cd dv/subsystem/top_smoke/sim && make ai_smoke` 通过并打印 `TEST PASS`（`AI_RANDOM_CASES=4`）；随后 `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 也打印 `TEST PASS`，配置 `ACLK_PERIOD_NS=10.0`。这些结果来自当前 dirty worktree，不能替代固定 SHA 的 clean-checkout replay。V2 仍有更广 queue-pressure/fairness、coverage database/未覆盖项统一 disposition；A10/V5 不因此 sign-off。

### 2026-10-15 A10 V2 direct-start/macro command 与 coverage-enabled 50-seed 回归（23 场景历史快照）

- 在 `dv/block/command_processor/uvm` 增加两个 CP 验证场景：direct-start 通过真实 `ai_command_processor` 的 direct launch 端口启动，检查一次 launch/result event 且 CMDQ/CPLQ pointers 不变；macro command 通过 queue 接受 parent descriptor，再从 testbench SPAD descriptor model 顺序 fetch 并 launch 三个 child，核对 child task IDs/operation 与唯一 parent completion。`scenario_hits` 和 `cp_cg.cp_scenario` 扩至 23 个 bins。只改 UVM interface/testbench/package/Makefile，不改 DUT RTL、端口或 ABI。
- 新增 `cov-compile` / `cov-regress`，用 VCS `line+cond+fsm+tgl+branch+assert` 对 compile 和每个 seed 独立生成 VDB，最后通过 URG 合并并 gate CP functional group 的 variables/crosses 与数据库错误。最终运行的源版本另要求 direct/macro PASS markers 和 `23/23` scenario bins。
- Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`，WSL interactive license shell 中运行：
  ```sh
  cd /mnt/e/workspace/chip/NMAForge/dv/block/command_processor/uvm
  export VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
  make cov-regress SEEDS="$(seq 20261061 20261070) $(seq 20261301 20261340)" \
    COV_OUT=/tmp/nmaforge_cp_cov_final2_20261015 \
    VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
    URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
  ```
  Run/compile transcript: `/tmp/nmaforge_cp_cov_final2_make.log`; merged report: `/tmp/nmaforge_cp_cov_final2_20261015/urg_merged/`.
- 50/50 run logs and 50 seed VDBs were generated; each run passed the Makefile log gates with `scenario_bins=23/23`, direct-start and macro markers present, UVM warning/error/fatal=`0/0/0`. URG `cp_cg`: 39/39 variables and 6/6 crosses (100%). Assertion summary: 8 total, 6 success, 0 failure, 0 incomplete, 2 without attempts; the five CP interface SVA all have non-zero real successes, and the two no-attempt assertions are UVM RAL `do_read`/`do_write`, not DUT properties.
- This is functional coverage closure for the selected CP covergroup, not CP RTL code-coverage closure: `ai_command_processor` line/condition/toggle/FSM/branch=`87.60/67.73/8.78/92.31/71.64%`; `ai_completion_writer`=`97.44/100.00/27.59/100.00/91.67%`. The CP FSM `state_r` has 12/13 transitions; the unhit `ST_FETCH->ST_IDLE` path appears guarded out for accepted queue tasks because they require an available completion slot, but this is RTL/test reasoning, not a formal unreachable proof. Remaining condition/branch outcomes plus queue-pressure/fairness need explicit disposition. V2/V5/A10 remain OPEN.
- After the CP coverage run, current dirty-tree top regression was rechecked with Rocky 8.10 / VCS `V-2023.12-SP1_Full64`: `cd dv/subsystem/top_smoke/sim && make ai_smoke` PASS (`ACLK_PERIOD_NS=10.0`, `AI_RANDOM_CASES=4`, `AI_SEED=12345`), followed by `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` PASS (`ACLK_PERIOD_NS=10.0`). Both end with `TEST PASS`; logs are the local ignored `dv/subsystem/top_smoke/sim/ai_accel_smoke.log` and compile log `ai_comp.log`. These are current-worktree regressions, not frozen-SHA clean-checkout replay.
- Results came from the dirty worktree; no RTL changed in this increment. They do not replace replay on a frozen commit/clean checkout, nor do they claim complete V2 lifecycle, whole-design code/assertion coverage, or A10 signoff.

### 2026-10-15 A10 V2 fetch-error event without completion queue; final 50-seed URG refresh

- 为覆盖 `ai_command_processor` 的 `ST_FETCH -> ST_IDLE` 转移，CP UVM 新增第 24 个场景：`cmdq_size=0`、`cplq_size=0`，注入 descriptor fetch error，检查 `ERR_FETCH=6` event、result/elements 为零、无 compute launch、无 completion SPAD write、completion writer 不 busy、CPLQ tail 不变且 CMDQ head 按当前 RTL 的 size-zero one-shot pointer 行为前进一次。
- 该场景是对 `ai_ring_pointer_next` 保留的 legacy size-zero 行为的实现测试；SPEC 没有把 size-zero fetch-error/no-completion 组合定义为新的软件 ABI 规则，故不把测试扩展解释为新的产品要求。首次 focused setup 使用 `cmdq_size=4/cplq_size=0`，按 RTL 正确地在 fetch 前以 `ERR_CPL` 拒绝；修正为 size-zero one-shot setup 后 focused VCS test 通过。这个初始结果是 test setup 假设不匹配，不是 DUT defect，也未计为通过证据。
- Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64` 最终复跑命令（从仓库根目录的 Linux shell 执行）：
  ```sh
  cd dv/block/command_processor/uvm
  export VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
  make cov-regress \
    SEEDS="$(seq -s ' ' 20261061 20261070) $(seq -s ' ' 20261301 20261340)" \
    COV_OUT=/tmp/nmaforge_cp_cov_final3_20261015 \
    VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
    URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
  ```
- VCS coverage compile 與 `make cov-regress` 全部通過；50/50 run logs、50 個 seed VDB 均生成，Makefile `check-log` 全部通過；每 seed `scenario_bins=24/24`，UVM warning/error/fatal=`0/0/0`。URG `cp_cg` 為 40/40 variables + 6/6 crosses（100%）。報告：`/tmp/nmaforge_cp_cov_final3_20261015/urg_merged/`；compile、各 seed log/VDB 及 merge log 均在同一 coverage 目錄。
- URG assertion 汇总 8 条：五条 CP interface SVA 均有 real non-vacuous successes、0 failure、0 incomplete——`a_completion_tail_advances_once` 1,980 次、`a_completion_tail_stable_until_commit` 12,775 次、`a_completion_write_stable` 2,725 次、`a_compute_abort_stops_automatic_queue_advance` 150 次、`a_fetch_stage_abort_suppresses_launch` 50 次；UVM `component_name_check_visitor` 另有 1,100 次成功；2 条未尝试 assertions 为 UVM RAL `do_read/do_write`，不是 DUT properties。
- URG 對 `ai_command_processor` 的 line/condition/toggle/FSM/branch 為 `88.80/71.71/9.21/100.00/73.13%`；state FSM 6/6 states、13/13 transitions，新增場景命中此前未覆蓋的 `ST_FETCH->ST_IDLE`。`ai_completion_writer` 為 `97.44/100.00/27.87/100.00/91.67%`。Residual condition/branch/toggle 尚未逐项分类，不构成 CP RTL code-coverage closure 或不可达性证明；更广 queue-pressure/fairness、跨层 closure、V2/V5/A10 仍 OPEN。
- 本增量修改 CP UVM stimulus/checker、Makefile coverage gate 与文档，不改 DUT RTL/接口/ABI。结果来自 dirty worktree；冻结 SHA 后仍需 clean-checkout replay。顶层 `ai_smoke` 与 20-case `ai_run` 最近一次 PASS 见此前基线记录；本次仅变更 CP block testbench，未重复运行顶层回归。
- 一次早期 Windows PowerShell→WSL 命令转发未保留多个 Make 参数，实际只运行默认 coverage 目录中的第一个 seed，随后因 URG 只收到一份 VDB 而被功能 coverage gate 拒绝。该次是 wrapper 参数传递错误，不是 RTL/UVM testcase failure，也不计入 50-seed 结果；最终 run 前用 `make -n` 确认 50 个 seed 与 `COV_OUT` 展开正确，再执行上面的 campaign。

### 2026-10-15 A10 V2 direct-start BF16/FP16 配置交叉覆盖与最终 50-seed 刷新

- CP UVM direct-start 改为测试 BF16 (`cfg_op=0x50`) 与 FP16 (`cfg_op=0x51`) 两种格式：两者均先以 `cfg_length=0` 验证 event=`ERR_DESC=7`、result/elements 为零、没有 compute launch、CMDQ/CPLQ pointers 不变，再以 `cfg_length=4` 各启动一次合法工作并检查结果事件。格式×拒绝/接受 cross 为 4 bins。该改动仅涉及 CP UVM interface/test/package/Makefile，不改 DUT RTL、端口、ABI 或时序。
- Focused command：`make -C dv/block/command_processor/uvm run SEED=20261015 OUT=/tmp/nmaforge_cp_direct_fp_formats_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`。Rocky 8.10 / VCS `V-2023.12-SP1_Full64` 编译、仿真通过，UVM warning/error/fatal=`0/0/0`；日志 marker 为 `invalid_rejected=2 launches=2 events=2 queue_unchanged=1 formats=BF16,FP16`。
- Coverage campaign 命令：
  ```sh
  make -C dv/block/command_processor/uvm cov-regress \
    SEEDS='20261061 20261062 20261063 20261064 20261065 20261066 20261067 20261068 20261069 20261070 20261301 20261302 20261303 20261304 20261305 20261306 20261307 20261308 20261309 20261310 20261311 20261312 20261313 20261314 20261315 20261316 20261317 20261318 20261319 20261320 20261321 20261322 20261323 20261324 20261325 20261326 20261327 20261328 20261329 20261330 20261331 20261332 20261333 20261334 20261335 20261336 20261337 20261338 20261339 20261340' \
    OUT=/tmp/nmaforge_cp_direct_fp_formats_cov_20261015 \
    COV_OUT=/tmp/nmaforge_cp_direct_fp_formats_cov_20261015/coverage \
    VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
    URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
  ```
- Final campaign exited 0: 50/50 seed logs and VDBs generated, each seed passed `scenario_bins=24/24` and UVM warning/error/fatal=`0/0/0`. URG report: `/tmp/nmaforge_cp_direct_fp_formats_cov_20261015/coverage/urg_merged/`; selected `cp_cg` variables 44/44 and crosses 10/10 (100%). BF16/FP16 × rejected/not-rejected cross bins each hit 50 times. Five CP interface SVA had non-vacuous successes with 0 failure/incomplete; two no-attempt assertions are UVM RAL `do_read/do_write`, not DUT properties.
- Updated `ai_command_processor` RTL code coverage: line/condition/toggle/FSM/branch=`90.00/74.50/9.33/100.00/74.63%`; `state_r` 6/6 states and 13/13 transitions. The FP16 direct-start condition is now covered, but residual condition/branch/toggle points remain unclassified; this is not CP RTL coverage closure or an unreachable proof. Queue-pressure/fairness and cross-layer V2/V5 closure remain open.
- An earlier one-format coverage run was initially rejected by a stale Makefile gate expecting 41 rather than the report's 42 functional variables. After correcting the gate, that campaign passed; the final two-format campaign updated the threshold to 44/10 and passed all checks. These were coverage-gate bookkeeping mismatches, not DUT/test failures. Then `make -C dv/subsystem/top_smoke/sim ai_smoke` passed (`TEST PASS`). All evidence is from the current dirty worktree, not a frozen-SHA clean-checkout replay.

### 2026-10-15 A10 V2 CPLQ full/hold/consume/re-doorbell pressure closure increment

- Added CP UVM scenario 24 (25 total): with a 4-slot CMDQ/CPLQ and one-slot-empty ring convention, publish four ordered commands while keeping `CPLQ_HEAD` fixed. Three completions fill the usable CPLQ entries; the fourth command remains published but must not be fetched/launched/completed while full. After six quiet cycles, advance `CPLQ_HEAD` by one and re-doorbell; the fourth command must complete exactly once, in order, with CMDQ and CPLQ pointer wrap. Scoreboard checks expected fetch addresses, launch task IDs, completion task IDs, and final 4/4 fetch/launch/completion counts.
- Focused run: `make -C dv/block/command_processor/uvm run SEED=20261015 OUT=/tmp/nmaforge_cp_queue_pressure_20261015 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`. Rocky 8.10 / VCS `V-2023.12-SP1_Full64`; final run passes with UVM warning/error/fatal=`0/0/0`, `scenario_bins=25/25`, and markers `prefill=3 held=1 resumed=1 completions=4`, `fetches=4 launches=4 completions=4`.
- Coverage campaign used the same 50 seeds as the immediately prior CP run: `20261061..20261070` and `20261301..20261340`. Command:
  ```sh
  make -C dv/block/command_processor/uvm cov-regress \
    SEEDS='20261061 20261062 20261063 20261064 20261065 20261066 20261067 20261068 20261069 20261070 20261301 20261302 20261303 20261304 20261305 20261306 20261307 20261308 20261309 20261310 20261311 20261312 20261313 20261314 20261315 20261316 20261317 20261318 20261319 20261320 20261321 20261322 20261323 20261324 20261325 20261326 20261327 20261328 20261329 20261330 20261331 20261332 20261333 20261334 20261335 20261336 20261337 20261338 20261339 20261340' \
    OUT=/tmp/nmaforge_cp_queue_pressure_20261015 \
    COV_OUT=/tmp/nmaforge_cp_queue_pressure_20261015/coverage \
    VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
    URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
  ```
- Campaign passed 50/50 seeds; each log has scenario bins 25/25, the CPLQ stress marker, exactly four checked fetches/launches/completions, and UVM warning/error/fatal=`0/0/0`. URG report: `/tmp/nmaforge_cp_queue_pressure_20261015/coverage/urg_merged/`; `cp_cg` variables 45/45 and crosses 10/10 (100%). The assertion report has 8 total: 6 success, 0 failure, 0 incomplete, and 2 without attempts (`uvm_reg_map::do_read/do_write`); all five CP interface SVA are non-vacuous. `ai_command_processor` line/condition/toggle/FSM/branch=`90.00/76.10/9.34/100.00/74.63%`, with 6/6 FSM states and 13/13 transitions; `ai_completion_writer` remains `97.44/100.00/27.87/100.00/91.67%`. Code coverage residuals are not yet dispositioned.
- After the CP testbench-only change, `make -C dv/subsystem/top_smoke/sim ai_smoke` also passed (`TEST PASS`, `AI_RANDOM_CASES=4`, `AI_SEED=12345`, `ACLK_PERIOD_NS=10.0`). No product RTL/ABI changed in this increment.
- First focused attempt exposed a checker bookkeeping issue: scenario-hit collection still bounded the enum at `<24`, so the new scenario was omitted from scenario coverage despite its functional marker passing. Updated the collector bound to `<25`, reran the focused test and the complete campaign; final campaign is green. This is a testbench coverage-index fix, not a DUT defect.
- This proves the targeted single full/hold/recovery pattern, not long-duration repeated saturation, arbitrary producer-consumer scheduling, or a fairness guarantee. No separate multi-client fairness contract is defined for the serialized command processor. Evidence is from the dirty worktree, not a clean replay of a frozen SHA; V2/V5/A10 remain open.

### 2026-10-15 A10 V1 FP dot final-worktree recheck

- Re-ran the mixed BF16/FP16 dot block after confirming the product contract remains at most two accepted, not-yet-returned scratchpad reads. Added a directed late-B-word protection case for both formats: pair-1 A and B reads are accepted, B is protection-failed, the checker requires `ERR_PROTECTION`, exactly the two valid pair-0 elements accumulated, four accepted reads drained, and no result write. This exercises the fault format×mode cross and checks the late-error prefix boundary without changing product RTL.
- Independent Python bit-exact reference precheck: `cd dv/block/compute/fp/model && python3.12 -m unittest -v test_fp_reference.py` (`Ran 19 tests`, `OK`), including NaN canonicalization, signed zero, subnormal, tie-to-even, overflow boundaries, and per-product/per-accumulation rounding.
- Final three-seed command from the repository root:
  ```sh
  make -C dv/block/compute/fp/sim dot-uvm-regress \
    DOT_RANDOM_COUNT=256 DOT_UVM_SEEDS='712345 987654 20261014' \
    DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_fp_final_20261015 \
    VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
    URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
  ```
- VCS `V-2023.12-SP1_Full64` and URG both exited 0. All three seeds passed 584/584 bit-exact transactions, including 536 numeric (`268 BF16 + 268 FP16`) and 48 fault/reset transactions (24 modes × 2 formats); `peak_outstanding_reads=2`; numeric, response-latency, fault-format/mode, and busy-start-format coverage each reported 100%; UVM warning/error/fatal=`0/0/0`. The late-B protection checks each logged `code=6 reads=4 writes=0` and the scoreboard checked `element_count=2`.
- Merged URG report: `/tmp/nmaforge_a10_fp_final_20261015/urg_report_merged/`; fault-format cross is 48/48. The DUT request-stability assertion `a_spad_request_stable_while_stalled` had 35,016 attempts, 10,792 real successes, 0 failures, and 0 incomplete; two unattempted assertions are UVM RAL `do_read/do_write`, not DUT properties. The mixed core line/condition/FSM/branch coverage was `97.96/96.50/71.43/92.86%`; main `state_r` is 5/5 states and 10/10 transitions, while `pending_error_r` is 6/6 states and 10/18 transitions. The existing residual structural dispositions remain applicable; they are not formal unreachability proofs. This is block evidence, not whole-project closure. Evidence is from the dirty worktree, not a frozen-SHA clean-checkout replay.
- All three FP UVM compile logs had no `Warning-`/`Error-` matches. After the testbench update, `make -C dv/subsystem/top_smoke/sim ai_smoke` also exited 0 with `TEST PASS`. `git diff --check` exited 0; Git emitted only existing LF→CRLF working-copy notices.

### 2026-10-15 A10 continuation: FP oracle refresh and CP pressure extension pending

- Re-ran the independent reference model from `dv/block/compute/fp/model` with `python3.12 -m unittest -v test_fp_reference.py`: all 19 tests passed (`Ran 19 tests`, `OK`). This refreshes the Python oracle evidence only; it is not a DUT simulation or V1 clean-SHA replay.
- Extended the CP UVM CPLQ-pressure candidate from the previously verified 4-command, single recovery to 8 ordered commands and 5 hold/consume/re-doorbell rounds, checking two CMDQ/CPLQ pointer wraps. New producer/consumer updates are driven on the falling clock edge, and CPLQ-tail waits are bounded to 1000 cycles. Updated the Makefile log gate to require the new markers. This is a testbench-only change; it is **not yet compiled or simulated** and old 4-command evidence does not cover it.
- VCS environment preflight attempted in Rocky WSL with `VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1`, `VCS_ARCH_OVERRIDE=linux64`, and `vcs -ID`; the tool exited with `Sorry, Linux version 6.6.87.2-microsoft-standard-WSL2 is not supported`. The actual CP compile/run and license checkout were not attempted in this turn. Do not classify this as an RTL/UVM failure or as a license failure; rerun when VCS is available in a supported execution environment.
- `git diff --check` passed for the worktree; Git emitted only existing LF→CRLF notices. The V2 candidate and V5 bug-register additions remain dirty-worktree evidence; no commit was created.

### 2026-10-15 post-license rerun — supersedes the pending note above

- The pending note described an earlier non-interactive WSL preflight. After the user activated the license, the interactive Rocky shell (`bash -ic`) exposed the license environment and VCS/URG ran successfully.
- Current verification results and exact command/output paths are recorded in [A10_DV_RUN_2026-10-15.md](A10_DV_RUN_2026-10-15.md). In particular, the 8-command CP CPLQ-pressure extension was compiled and simulated, and its three-seed × six-case coverage regression merged to 100% of the specified `cp_cg` bins.
- All results remain dirty-worktree evidence on `HEAD=1b4b61f`; no fixed-commit clean-checkout replay or commit was made. The prior “pending” text is retained as history, not current status.
