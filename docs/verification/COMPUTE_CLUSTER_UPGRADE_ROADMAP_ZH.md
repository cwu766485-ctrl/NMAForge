# Compute Cluster 升级路线与验证追踪

**状态日期：2026-10-25。** 本文把升级目标拆成硬件 requirement、testpoint 和 coverage evidence。路线图中的目标值不是已达成的产品指标；每个阶段只在对应 DUT、testbench 和 coverage 口径下报告结果。

## 1. 当前阶段

| 路线图步骤 | 目标 | 状态 |
|---|---|---|
| 1. 冻结现有验证基线 | 保留 4×4 Matrix、FP Dot、CNM、SFU 和 top smoke 回归作为改版对照 | **完成**。Matrix/top 变更前有重跑记录；CNM、FP Dot 本次重放三 seed；SFU 使用前一轮已通过的三 seed 日志。证据及 dirty-worktree 边界见第 2 节。 |
| 2. P0 Tensor Engine | 参数化 4×4/8×8/16×16 INT8 MAC；本地累加和双 operand buffer | **16×16 controller 集成已完成，双缓冲尚未实现，验证未 signoff**。top 默认 `ARRAY_SIZE=16`；独立 A/B tile registers 收集原有 4×4 tile-major SPAD 数据并驱动 16×16 宏 tile。16×16 与 32×16 跨宏 tile 通过真实 core banked/SPAD 接口和独立 Golden 的三 seed 回归。 |
| 3. P0 Memory Dataflow | Weight/Activation Buffer、预取、双缓冲、数据复用与 bank/backpressure 管理 | **部分完成**。真实 SPAD 地址生成、A/B tile holding registers、写回和 ready stall 已实现；没有 A/B ping-pong buffer、SPAD 预取或读响应与 MAC 重叠，K-group 请求仍串行，跨宏 tile 无驻留复用。固定响应 VCS benchmark 可复现，但有效阵列利用率仍低。 |
| 4. P1 Transformer 算子和 KV | 用现有 SFU/Matrix/KV 构成真实 Tiny Decoder workload，并验证多 Head/Token 管理 | **已有 primitives，端到端目标未完成**。当前 30-command workload smoke 不是完整 Tiny Qwen/GPT Decoder golden 对拍。 |
| 5. P2 计算融合 | GEMM→SFU streaming，减少 SPAD 中间写回 | **未实现**。当前仍由独立命令和 scratchpad 写回连接算子。 |
| 6. Compute Cluster UVM | 实际 Cluster、全部 Engine、共享 SPAD、跨 Engine 并发、Abort/Reset 与 feature→testpoint→coverage 闭环 | **真实 top Matrix/SFU 定向切片已三 seed 通过；完整 C1 未完成**。新 sequence 使用真实 Matrix 16×16 GEMM、排队 SFU、跨引擎 overlap、`ai_spad_arbiter`/四 Bank memory traffic、按序 CPLQ、并发 Abort、活动 Reset 与恢复自检。UVM warning/error/fatal=`0/0/0`，focused covergroup=`55.5%`；whole-top URG 不是 DUT-only 或全 cluster coverage。其余引擎、广泛错误/背压场景和完整 REQ closure 仍待覆盖。 |
| 7. Benchmark 与 PPA | Effective GOPS、MAC 利用率、SPAD traffic、cycles/token、面积、频率和功耗 | **仿真 benchmark 已补，PPA 未完成**。固定一拍 bank response 的 3×3 阵列/尺寸 sweep 记录 cycle、MAC/cycle、模型 SPAD traffic/stall 和归一化 GOPS；DC V-2023.12-SP1 已安装，但启动综合时报 `Design Compiler is not enabled (DCSH-1)`；私有 TSMC standard-cell/SRAM 库未配置，不能报告目标工艺面积/Fmax/功耗。 |

## 2. 冻结基线

改动前基线为 commit `9c4aea103a23a42a00fea7bcb092fbe7483e3a15`（短 SHA `9c4aea1`）对应的 Matrix RTL 和测试；工作树当时还含有前序任务未提交的 SPEC、UVM、SFU 验证改动，因此这不是全仓 clean-SHA replay。Matrix core RTL、矩阵测试和 top smoke RTL 在本次升级前与该 commit 相同。

| 检查 | 命令 / artifacts | 结果 |
|---|---|---|
| Matrix core | `make -C dv/block/compute/matrix/sim core-random-regress SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_matrix_core_baseline_20261025` | 三 seed 均 PASS；每 seed 6 个算术/布局 case、12 个 fault/interactions、late-tile parity、fault+abort、fault+reset 与 recovery。VCS `V-2023.12-SP1`。 |
| Matrix controller follow-up | `make -C dv/block/compute/matrix/sim core-random-regress SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_matrix16_core_regress_20261025` | 三 seed 各 8 个 Golden case + 12 fault cases PASS；16×16 与 32×16 跨 tile；URG `/tmp/nmaforge_matrix16_core_regress_20261025/urg`。 |
| Matrix size benchmark | `make -C dv/block/compute/matrix/sim matrix-size-benchmark SEED=20261025 BENCH_OUT_DIR=/tmp/nmaforge_matrix_size_benchmark_final_20261025` | 4×4/8×8/16×16 physical array × workload size 共 9 组 PASS；固定 1-cycle bank response，日志在每个 `array_{4,8,16}/run.log`。 |
| CNM | `ai_cnm_a22`、`ai_cnm_a2_gemv_bench`，及 `ai_cnm_random_regress CNM_RANDOM_SEEDS='20261021 20261022 20261023' CNM_RANDOM_OUT_DIR=/tmp/nmaforge_cnm_random_baseline_20261025`，从 `dv/subsystem/top_smoke/sim` 运行 | A2.2、GEMV benchmark 与三个 random seed PASS；每 seed 10 cases、8 faults、late fault、reset/fault combo 和 recovery。 |
| FP Dot | `make -C dv/block/compute/fp/sim dot-uvm-regress DOT_UVM_SEEDS='712345 987654 20261015' DOT_UVM_OUT_DIR=/tmp/nmaforge_fp_dot_baseline_20261025 URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg` | 三 seed 每个 212/212 bit-exact；UVM warning/error/fatal `0/0/0`；merged URG 生成。 |
| SFU | `make -C dv/block/compute/sfu/sim random-latency-regress SEEDS='20261024 20261025 20261026' OUT_DIR=/tmp/nmaforge_sfu_fsm_converge_multi_20261024` | 前一轮三 seed 日志均 PASS；39 个 reset state、39 个 Abort state 和 gamma bypass 被命中。该项没有在本轮重新运行。 |
| Top baseline | `make ai_smoke`，工作目录 `dv/subsystem/top_smoke/sim` | `TEST PASS`；包括现有 30-command Transformer-style workload 和常规错误/reset 场景。 |
| Top and A3 integration | `make ai_smoke`；`make -C dv/block/compute/matrix/sim a3-core-test` | 两项 PASS；A3 bench 的 L=16/64/256 均 PASS。A3 standalone filelist 漏了新阵列 module，已补入 `ai_tensor_matrix_array.sv` 后重跑通过。 |
| Seeded top regression | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`，目录 `dv/subsystem/top_smoke/sim` | 本轮未完成：VCS 报 license server 连接失败；带 `+vcs+lic+wait` 重试后进入 license queue，等待期间中断。不是 RTL/test failure。 |
| DC/PPA availability | `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell -version`；attempted Matrix generic synthesis | DC binary is installed (`V-2023.12-SP1`), but synthesis exits `Fatal: Design Compiler is not enabled. (DCSH-1)`; `TSMC28_STDCELL_DB` and `TSMC28_SRAM_DB` are unset. No area/Fmax/power result. |

CNM 初次多目标 make 调用暴露默认输出路径使用递归时间戳，compile 与 regress 展开时可能落入不同秒级目录。本次将 `CNM_RANDOM_OUT_DIR` 改为 parse-time 固定值，并用显式路径重跑三 seed；生成物仍留在 `/tmp`。

本次 C0-P Dispatcher/SPAD-MUX UVM 重跑命令为 `make -C dv/subsystem/tensor_datapath/sim parallel-uvm-regress PARALLEL_SEEDS='20261024 20261025 20261026' PARALLEL_OUT=/tmp/nmaforge_parallel_compute_uvm_20261025_matrix16`；三 seed 均 PASS，UVM warning/error/fatal=`0/0/0`。它只复核已存在的行为 Engine/SPAD 环境。

真实 top UVM 源码已加入 `dv/uvm`，连接产品 top、真实 arbiter/response route 与四 Bank behavioral SRAM。VCS license 恢复后，该 Matrix/SFU 定向切片已完成三 seed 回归并生成 merged URG。复现命令：

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_final_20261025
```

seeds `20261025/20261026/20261027` 全部通过，Matrix/SFU GEMM、overlap、共享
arbiter 流量、completion order、双 Engine Abort、活动 Reset 和 recovery 均有
PASS 检查。每 seed scoreboard 为 1217 observations、509 overlap、5 done、
422 accepted reads、420 responses、0 orphan、2 reset-dropped reads，pending
ledger 清零。旧 license queue 失败仅作为运行历史保留。全引擎数值、
parity/fault matrix、独立全引擎 memory scoreboard、全功能 coverage、mutation
和 clean-SHA replay 仍未完成。

## 3. P0 Tensor Engine：Requirement → Testpoint → Coverage

[ai_tensor_matrix_array.sv](../../rtl/compute/matrix/ai_tensor_matrix_array.sv) 是 output-stationary INT8 MAC array。top 默认 `ARRAY_SIZE=16`，每个有效 MAC 周期可产生 256 个 INT8 product 并更新本地 64-bit accumulator。Matrix controller 从原有 tile-major SPAD 布局读取最多四组 4×4 A/B word，组成宏 tile；尺寸大于 16 时按 M/N 遍历。Descriptor ABI、opcode 和 4×4 子块存储顺序不变。

| Requirement / feature | Testpoint | 多 seed 结果 | Coverage / 当前结论 |
|---|---|---|---|
| **TAR-MAC-001：真实 Matrix controller 的 16×16 GEMM** | registered four-bank SPAD model → 16×16 controller/array → 128-bit output line；对每个输出与独立 int64 Golden 比较 | `20261021/20261022/20261023`；每 seed PASS | 每 seed 8 个 numerical/layout cases；含 M=N=16、K=16。 |
| **TAR-MAC-002：跨宏 tile 和 descriptor compatibility** | 32×16、M/N 多个 16 宏块、A/B transpose、bias、scale、line/scalar 写回 | 同一三 seed；PASS | 32×16 每 seed 全结果与 Golden 一致；4×4/8×8/16×16 物理 array 参数另由 3×3 benchmark 交叉验证。 |
| **TAR-MAC-003：fault/reset/recovery** | bank/SPAD parity/protection、line protection、watchdog、abort、fault+abort、in-flight reset 与 recovery；32×16 第二宏块 late parity | 同一三 seed；每 seed 12 fault cases 与 late fault PASS | late parity 发生在第一 16×16 宏块已写 64 条 line 后；故障后没有新增写回。 |
| **TAR-MAC-004：代码覆盖** | VCS V-2023.12-SP1 + URG，`matrix_core.cm_hier` 只收集 DUT 和 array child，合并三 seed | `/tmp/nmaforge_matrix16_core_regress_20261025/urg` | core line/condition/FSM transition/branch=`96.17/90.83/65.85/93.52%`；array child=`82.35/20.00/N/A/58.82%`。Raw DUT code coverage remains partial; unhit FSM transitions and array output branches are not waived. |

### 3.1 4×4 / 8×8 / 16×16 VCS benchmark

复现命令：

```sh
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261025 \
  BENCH_OUT_DIR=/tmp/nmaforge_matrix_size_benchmark_final_20261025
```

每个物理阵列 build 都运行 4×4、8×8、16×16 的 K=32 workload。Operands 使用 `SEED=20261025`，bank response latency 固定为一拍；ready/stall 使用 testbench 固定 LFSR 序列。GOPS 按每 MAC 两个 operation、250 MHz 归一化。RTL testbench 时钟 period 是 10 ns；以下不是 silicon timing 或 PPA 数据。

| 物理 array | Workload M×N×K | Cycles | MAC/cycle | End-to-end array utilization | GOPS @250MHz normalized | Bank reads / stalls | Line writes / stalls |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4 | 4×4×32 | 99 | 5.172 | 32.32% | 2.586 | 16 / 4 | 4 / 1 |
| 4×4 | 8×8×32 | 407 | 5.032 | 31.45% | 2.516 | 64 / 30 | 16 / 4 |
| 4×4 | 16×16×32 | 1600 | 5.120 | 32.00% | 2.560 | 256 / 81 | 64 / 30 |
| 8×8 | 4×4×32 | 99 | 5.172 | 8.08% | 2.586 | 16 / 4 | 4 / 1 |
| 8×8 | 8×8×32 | 175 | 11.703 | 18.29% | 5.851 | 32 / 8 | 16 / 13 |
| 8×8 | 16×16×32 | 674 | 12.154 | 18.99% | 6.077 | 128 / 38 | 64 / 23 |
| 16×16 | 4×4×32 | 99 | 5.172 | 2.02% | 2.586 | 16 / 4 | 4 / 1 |
| 16×16 | 8×8×32 | 175 | 11.703 | 4.57% | 5.851 | 32 / 8 | 16 / 13 |
| 16×16 | 16×16×32 | 357 | 22.947 | 8.96% | 11.473 | 64 / 29 | 64 / 30 |

The 16×16 configuration cuts the 16×16×K32 command from 1600 cycles on the 4×4 configuration to 357 cycles, but serialized bank requests, response waits and line writeback still limit end-to-end utilization to 8.96%. The arithmetic peak at 256 MAC/cycle and 250 MHz is 128 GOPS; the VCS number above is workload throughput normalized to that assumed clock. Response latency and readiness are behavioral models, not SRAM macro timing.

## 4. 尚未收敛的 P0/P1 项

- **Memory dataflow optimization**：把 banked read response 做有序多笔 outstanding/prefetch，与当前 K-slice MAC overlap；定义 parity/protection/abort 下的 in-flight drain。现有 controller 串行等待每个响应，benchmark 的 16×16 utilization 8.96% 显示这是当前瓶颈。
- **完整 Compute Cluster UVM**：top-level C1 Matrix/SFU 定向切片已用真实 cluster、arbiter 和四 Bank SRAM 三 seed 通过，包含并发、Abort/Reset 与恢复。现有 21 engine-pair/5 场景 C0-P regression 仍使用行为 Engine/SPAD。剩余全引擎场景、CNM parity/bank-lane、request backpressure、独立全引擎 owner/memory scoreboard 与覆盖闭环尚未完成。
- **DC/PPA**：固定工艺角、SRAM latency/timing model 和 250 MHz SDC；DC V-2023.12-SP1 可执行文件已安装，但综合被许可证错误 `DCSH-1: Design Compiler is not enabled` 拒绝；私有 TSMC standard-cell/SRAM 库也未配置，因此面积、Fmax、功耗和目标工艺 PPA 暂无证据。
- **Transformer/KV**：已有 operator primitive 和映射 smoke；还需独立 Tiny Decoder Golden、Head/Token/Prefill/Decode 数据布局及端到端对拍。
- **P2 fusion**：定义 GEMM 到 SFU 的流接口、背压、Abort、结果顺序与 SPAD ownership 后再实现 streaming path。

## 5. 规格和产品边界

本次没有改变 descriptor ABI、opcode 或软件接口。top Matrix path 已默认使用 16×16 MAC array，并由实际 Matrix controller 完成 SPAD→array→SPAD 的 16×16 与跨宏 tile GEMM；这不等于 Compute Cluster UVM、预取/overlap、DC/PPA 或整体 signoff 完成。
