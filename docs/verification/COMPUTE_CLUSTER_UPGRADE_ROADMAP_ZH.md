# Compute Cluster 升级路线与验证追踪

**状态日期：2026-10-25。** 本文把升级目标拆成硬件 requirement、testpoint 和 coverage evidence。路线图中的目标值不是已达成的产品指标；每个阶段只在对应 DUT、testbench 和 coverage 口径下报告结果。

## 1. 当前阶段

| 路线图步骤 | 目标 | 状态 |
|---|---|---|
| 1. 冻结现有验证基线 | 保留 4×4 Matrix、FP Dot、CNM、SFU 和 top smoke 回归作为改版对照 | **完成**。Matrix/top 变更前有重跑记录；CNM、FP Dot 本次重放三 seed；SFU 使用前一轮已通过的三 seed 日志。证据及 dirty-worktree 边界见第 2 节。 |
| 2. P0 Tensor Engine | 参数化 8×8、16×16 INT8 MAC；增加 local accumulator 与双 operand buffer | **部分完成**。新增参数化阵列；现有 4×4 Matrix core 已复用其 `ARRAY_SIZE=4` 配置。8×8/16×16 已单独 bit-exact 验证，但尚未接入 descriptor/SPAD 控制路径。 |
| 3. P0 Memory Dataflow | Weight/Activation Buffer、预取、双缓冲、数据复用与 bank/backpressure 管理 | **部分完成**。阵列内部有双 bank operand vector buffer；真实 SPAD 到 8×8/16×16 的地址生成、预取调度、bank 冲突和 stall 处理尚未实现。 |
| 4. P1 Transformer 算子和 KV | 用现有 SFU/Matrix/KV 构成真实 Tiny Decoder workload，并验证多 Head/Token 管理 | **已有 primitives，端到端目标未完成**。当前 30-command workload smoke 不是完整 Tiny Qwen/GPT Decoder golden 对拍。 |
| 5. P2 计算融合 | GEMM→SFU streaming，减少 SPAD 中间写回 | **未实现**。当前仍由独立命令和 scratchpad 写回连接算子。 |
| 6. Compute Cluster UVM | 实际 Cluster、全部 Engine、共享 SPAD、跨 Engine 并发、Abort/Reset 与 feature→testpoint→coverage 闭环 | **C0-P 子集通过，完整 C0/C1 未完成**。当前 UVM 使用真实 Dispatcher/SPAD MUX，但 Engine/SPAD 模型化；真实 Arbiter、四 Bank SRAM 和完整 Cluster 尚未进入该台架。 |
| 7. Benchmark 与 PPA | Effective GOPS、MAC 利用率、SPAD traffic、cycles/token、面积、频率和功耗 | **未测新阵列**。下文只列理想算术上限，不作为仿真性能或 DC/PPA 结果。 |

## 2. 冻结基线

改动前基线为 commit `9c4aea103a23a42a00fea7bcb092fbe7483e3a15`（短 SHA `9c4aea1`）对应的 Matrix RTL 和测试；工作树当时还含有前序任务未提交的 SPEC、UVM、SFU 验证改动，因此这不是全仓 clean-SHA replay。Matrix core RTL、矩阵测试和 top smoke RTL 在本次升级前与该 commit 相同。

| 检查 | 命令 / artifacts | 结果 |
|---|---|---|
| Matrix core | `make -C dv/block/compute/matrix/sim core-random-regress SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_matrix_core_baseline_20261025` | 三 seed 均 PASS；每 seed 6 个算术/布局 case、12 个 fault/interactions、late-tile parity、fault+abort、fault+reset 与 recovery。VCS `V-2023.12-SP1`。 |
| CNM | `ai_cnm_a22`、`ai_cnm_a2_gemv_bench`，及 `ai_cnm_random_regress CNM_RANDOM_SEEDS='20261021 20261022 20261023' CNM_RANDOM_OUT_DIR=/tmp/nmaforge_cnm_random_baseline_20261025`，从 `dv/subsystem/top_smoke/sim` 运行 | A2.2、GEMV benchmark 与三个 random seed PASS；每 seed 10 cases、8 faults、late fault、reset/fault combo 和 recovery。 |
| FP Dot | `make -C dv/block/compute/fp/sim dot-uvm-regress DOT_UVM_SEEDS='712345 987654 20261015' DOT_UVM_OUT_DIR=/tmp/nmaforge_fp_dot_baseline_20261025 URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg` | 三 seed 每个 212/212 bit-exact；UVM warning/error/fatal `0/0/0`；merged URG 生成。 |
| SFU | `make -C dv/block/compute/sfu/sim random-latency-regress SEEDS='20261024 20261025 20261026' OUT_DIR=/tmp/nmaforge_sfu_fsm_converge_multi_20261024` | 前一轮三 seed 日志均 PASS；39 个 reset state、39 个 Abort state 和 gamma bypass 被命中。该项没有在本轮重新运行。 |
| Top baseline | `make ai_smoke`，工作目录 `dv/subsystem/top_smoke/sim` | `TEST PASS`；包括现有 30-command Transformer-style workload 和常规错误/reset 场景。 |
| EDA 环境 | `python3 /home/ray/.codex/skills/eda-tool-engineering/scripts/eda.py doctor` | VCS、URG、SpyGlass、VC Formal、DC 等工具路径可发现；不代表 license/PDK signoff 已完成。 |

CNM 初次多目标 make 调用暴露默认输出路径使用递归时间戳，compile 与 regress 展开时可能落入不同秒级目录。本次将 `CNM_RANDOM_OUT_DIR` 改为 parse-time 固定值，并用显式路径重跑三 seed；生成物仍留在 `/tmp`。

## 3. P0 Tensor Engine：Requirement → Testpoint → Coverage

新模块 [ai_tensor_matrix_array.sv](../../rtl/compute/matrix/ai_tensor_matrix_array.sv) 是 output-stationary INT8 MAC array。`ARRAY_SIZE=N` 时，每个 MAC 周期产生 N² 个有符号 INT8 product，并更新 N² 个本地 64-bit accumulator；两组 A/B operand vector buffer 支持计算当前 bank 时装载另一 bank。结果读取支持 bias、arithmetic shift、ReLU、ReLU6 和 signed INT32 saturation。

| Requirement / feature | Testpoint | 多 seed 结果 | Coverage / 当前结论 |
|---|---|---|---|
| **TAR-MAC-001：N=8、16 参数化阵列算术** | 独立 64-bit golden；4 个 GEMM case 覆盖 K=1/3/8/17，检查每个 N×N accumulator 和 post-process 结果 | `20261025/20261026/20261027`；每种尺寸每 seed 4 cases PASS | 每个 seed 4/4 case PASS；functional group 100%。DUT-only URG：line 100%、condition 100%、branch 94.12%、FSM N/A。8×8 与 16×16 使用同一参数化 RTL 定义。 |
| **TAR-MAC-002：A/B transpose 数据布局** | 4 个 case 覆盖 `00/10/01/11`，testbench 按物理转置布局组装输入 vector | 与 TAR-MAC-001 同批 PASS | 阵列接口接收已经整理好的向量；8×8/16×16 的硬件 address/transpose gather 仍未实现。现有实际 4×4 core 的 transpose RTL 另由 core regression 检查。 |
| **TAR-MAC-003：双 buffer load 与 MAC 并行** | MAC 当前 bank 的同一周期装入下一 K vector 到另一 bank；每次 run 检查 overlapped-load marker | 每 seed、每种尺寸 25 次 overlap，marker PASS | Functional coverage group 覆盖 ping-pong overlap bin；100%。该证据只覆盖阵列端口，不覆盖 scratchpad prefetch 或 bank arbitration。 |
| **TAR-MAC-004：宽累加及 INT32 输出边界** | N×N bit-exact 累加；单独检查正向、负向 saturation、ReLU、ReLU6 | 每 seed 正负饱和各 1 项，均 PASS | 64-bit accumulator 对随机向量逐元素核对；输出 saturation 两边均命中。未覆盖 64-bit accumulator 极限溢出，且 Descriptor/实际 memory image 未参与。 |
| **TAR-MAC-005：旧命令路径保持兼容** | 真实 `ai_tensor_matrix_core` 使用共享阵列的 `ARRAY_SIZE=4` 实例；原 fault/reset test 和 top smoke | core seeds `20261021/20261022/20261023` PASS；`ai_smoke` PASS | 保留原 4×4 descriptor 和 scratchpad 行为。当前产品路径仍是 4×4，不应宣称 top 已切换至 8×8 或 16×16。 |

VCS `V-2023.12-SP1` / URG `V-2023.12-SP1` 的 8×8、16×16 原始报告位于 `/tmp/nmaforge_matrix_array_final2_20261025/size_{8,16}/urg/`；每个 size 的功能覆盖组均为 100%。组合 core 报告在 `/tmp/nmaforge_matrix_core_final_20261025/urg/`：`ai_tensor_matrix_core` line/condition/FSM-transition/branch 为 88.05%/87.30%/64.10%/87.50%；该报告中的 `ARRAY_SIZE=4` array 行为 line/condition/branch 82.35%/20.00%/58.82%。后者是 4×4 core 场景代码覆盖，不替代 8×8/16×16 direct-array coverage。

复现命令：

```sh
make -C dv/block/compute/matrix/sim array-random-regress \
  ARRAY_SIZES='8 16' ARRAY_SEEDS='20261025 20261026 20261027' \
  ARRAY_OUT_DIR=/tmp/nmaforge_matrix_array_final2_20261025
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_core_final_20261025
make -C dv/subsystem/top_smoke/sim ai_smoke
```

## 4. 尚未收敛的 P0/P1 项

- **8×8/16×16 命令核接入**：扩展 Matrix controller 的 tile/address generator、banked read schedule、transpose gather、bias 读取和 line/scalar writeback。重点确认 16×16 每 K slice 的 A/B 供数不会超出唯一 SPAD admission 带宽。
- **实际 Weight/Activation Dataflow**：把阵列的本地 vector buffer 接到共享 scratchpad；实现可测的双缓冲填充、prefetch、ready stall、bank conflict、保护/Parity 错误归属和 reset/abort drain。
- **Benchmark/PPA**：以同一 workload 统计有效 MAC/s、利用率、SPAD read/write bytes、cycles/token；使用可用工艺库执行 DC，再评估时序和功耗。理想上限按 `2 × MAC/cycle × frequency`：N=8 为 64 MAC/cycle、250 MHz 下 32 GOPS；N=16 为 256 MAC/cycle、250 MHz 下 128 GOPS。当前实现没有 PPA/有效吞吐数据。
- **Transformer/KV**：已有算子 primitive 和映射 smoke；还需建立 decoder golden、Head/Token/Prefill/Decode 数据布局及跨算子结果对拍。
- **Compute Cluster UVM**：现有 C0-P 的 21 引擎对与 5 场景组覆盖不能证明真实 SPAD Arbiter、四 Bank SRAM、CNM/Matrix side-channel 或共享 memory image 正确；需扩展完整 Cluster+C1 台架。
- **P2 fusion**：定义 GEMM 到 SFU 的流接口、背压、Abort、结果顺序与 SPAD ownership 后再实现 streaming path。

## 5. 规格和产品边界

本次没有改变 descriptor ABI、opcode 或软件接口。当前 top 仍报告 4×4 Tensor GEMM；8×8/16×16 是可综合参数化 MAC-array block 的直接验证结果，不是产品级矩阵功能或 PPA signoff。要求的下一步硬件接入、dataflow 和对应 UVM coverage 必须在该边界解除后，才能把 P0 标为完成。
