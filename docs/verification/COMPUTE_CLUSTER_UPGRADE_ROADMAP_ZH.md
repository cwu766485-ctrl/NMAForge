# Compute Cluster 升级路线与验证追踪

**状态日期：2026-10-26。** 本文把升级目标拆成硬件 requirement、testpoint 和 coverage evidence。路线图中的目标值不是已达成的产品指标；每个阶段只在对应 DUT、testbench 和 coverage 口径下报告结果。

## 1. 当前阶段

| 路线图步骤 | 目标 | 状态 |
|---|---|---|
| 1. 冻结现有验证基线 | 保留 4×4 Matrix、FP Dot、CNM、SFU 和 top smoke 回归作为改版对照 | **完成**。Matrix/top 变更前有重跑记录；CNM、FP Dot 本次重放三 seed；SFU 使用前一轮已通过的三 seed 日志。证据及 dirty-worktree 边界见第 2 节。 |
| 2. P0 Tensor Engine | 参数化 4×4/8×8/16×16 INT8 MAC；本地累加和双 operand buffer | **RTL 集成及定向验证完成，整体 signoff 未完成**。top 默认 `ARRAY_SIZE=16`；16×16 与跨宏 tile GEMM 通过独立 Golden。VCS 有逐状态/等待周期 profiler；A/B operand ping-pong buffer 在 K-group 预取路径中启用。Matrix/CNM response tag 已拆分并有真实 top 并发数值回归。 |
| 3. P0 Memory Dataflow | Weight/Activation Buffer、预取、双缓冲、数据复用与 bank/backpressure 管理 | **P0-A/B/C 已实现并完成定向回归**。2/4 深度有序读流水在 abort/parity/protection/watchdog 后停止发新请求并 drain；next-K A/B 预取与当前 MAC 重叠；跨 N tile 的 A-tile 缓存在 K≤64 时复用，K>64 自动绕过。真实性能/完整 cluster signoff 仍未完成。 |
| 4. P1 Transformer 算子和 KV | 用现有 SFU/Matrix/KV 构成真实 Tiny Decoder workload，并验证多 Head/Token 管理 | **已有 primitives，端到端目标未完成**。当前 30-command workload smoke 不是完整 Tiny Qwen/GPT Decoder golden 对拍。 |
| 5. P2 计算融合 | GEMM→SFU streaming，减少 SPAD 中间写回 | **未实现**。当前仍由独立命令和 scratchpad 写回连接算子。 |
| 6. Compute Cluster UVM | 实际 Cluster、全部 Engine、共享 SPAD、跨 Engine 并发、Abort/Reset 与 feature→testpoint→coverage 闭环 | **真实 top Matrix/SFU 定向切片已三 seed 通过；完整 C1 未完成**。新增真实 Matrix 16×32×64 GEMM，逐项核对 512 Golden 输出、16 次 A-tile cache hit、next-K prefetch/MAC overlap；Abort/reset 测试等待真实预取活动后触发。UVM warning/error/fatal=`0/0/0`，focused covergroup=`65.4%`。merged whole-top URG=`47.54/41.38/10.52/37.70/60.00/19.11%`（line/condition/FSM/branch/assert/group，含 DUT/SVA/TB/UVM）。其余引擎、广泛错误/背压场景和完整 REQ closure 仍待覆盖。 |
| 7. Benchmark 与 PPA | Effective GOPS、MAC 利用率、SPAD traffic、cycles/token、面积、频率和功耗 | **仿真 benchmark 已补，PPA 未完成**。固定一拍 bank response 的 3×3 阵列/5 种尺寸 sweep 记录周期、MAC/cycle、SPAD traffic/stall 与归一化 GOPS。16×16 array 的 A-cache 对 16×32×K32 / 32×32×K64 分别减少 11.1%/17.7% cycles、25% reads。DC V-2023.12-SP1 综合被 `DCSH-1` 拒绝，且私有 TSMC standard-cell/SRAM 库未配置，不能报告目标工艺面积/Fmax/功耗。 |

## 2. 冻结基线

改动前基线为 commit `9c4aea103a23a42a00fea7bcb092fbe7483e3a15`（短 SHA `9c4aea1`）对应的 Matrix RTL 和测试；工作树当时还含有前序任务未提交的 SPEC、UVM、SFU 验证改动，因此这不是全仓 clean-SHA replay。Matrix core RTL、矩阵测试和 top smoke RTL 在本次升级前与该 commit 相同。

| 检查 | 命令 / artifacts | 结果 |
|---|---|---|
| Matrix core | `make -C dv/block/compute/matrix/sim core-random-regress SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_matrix_core_baseline_20261025` | 三 seed 均 PASS；每 seed 6 个算术/布局 case、12 个 fault/interactions、late-tile parity、fault+abort、fault+reset 与 recovery。VCS `V-2023.12-SP1`。 |
| Matrix controller follow-up (pre-P0-B baseline) | `make -C dv/block/compute/matrix/sim core-random-regress SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_matrix16_core_regress_20261025` | 改动前基线：三 seed 各 8 个 Golden case + 12 fault cases PASS；16×16 与 32×16 跨 tile；URG `/tmp/nmaforge_matrix16_core_regress_20261025/urg`。 |
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
PASS 检查。初始三 seed 数据记录在此；2026-10-26 P0-C 扩展回归和最新
coverage 见第 3.4 节。旧 license queue 失败仅作为运行历史保留。全引擎数值、
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

### 3.2 P0-A Cycle Breakdown Profiler + Matrix/CNM response ownership

`ai_tensor_matrix_core` now counts each busy FSM state per command, aggregate request-Arbiter stalls, response-wait cycles, and output writeback waits. The state bins sum exactly to `cycle_count`; counters are read hierarchically by the VCS core regression and do not add software-visible CSRs. With the fixed one-cycle bank-response model, `ARRAY_SIZE=16`, seed `20261026`, shape 16×16×K32:

| State / wait class | Cycles |
|---|---:|
| A_REQ / A_WAIT | 43 / 64 |
| B_REQ / B_WAIT | 50 / 64 |
| PREP_MAC / MAC | 8 / 32 |
| WRITE / NEXT / DONE | 94 / 1 / 1 |
| Aggregate request Arbiter stalls | 59 |
| Response wait (A/B) | 64 |
| Writeback wait (subset of Arbiter stalls) | 30 |
| Total | 357 |

Red/green response-owner reproduction: after adding an expected distinct CNM tag, the original RTL made `make ai_spad_arb_run` fail at the seeded CNM grant (`client tag 3`). The fix keeps Matrix tag 3 and assigns CNM tag 5 while both retain the same round-robin slot. The focused test now runs 10,000 cycles and checks adjacent CNM→Matrix accepts/responses. The real top smoke adds a CNM GEMV + Matrix GEMM run with shared arbiter and disjoint outputs; it observes Matrix/CNM overlap, 2 Matrix responses, 32 CNM lane-response cycles, no aliased response, and both independent Goldens/completions pass.

Reproduction commands and results (Rocky Linux / VCS V-2023.12-SP1):

```sh
make -C dv/subsystem/top_smoke/sim ai_spad_arb_run
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_commit_a_20261026
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261026 BENCH_OUT_DIR=/tmp/nmaforge_matrix_profile_20261026
```

All five commands passed after the fix. `ai_smoke` and the 20-case seeded top run both ended with `TEST PASS`; all three Matrix core seeds retained 8 bit-exact cases and 12 fault/recovery cases. Formal replay was attempted but unavailable in this image because `vcf` is not installed; no new formal proof is claimed. These runs are current-worktree evidence, not a clean fixed-SHA replay.

### 3.3 P0-B Ordered multi-outstanding Matrix reads

The Matrix controller now accepts up to `MAX_OUTSTANDING_READS` banked reads (default 4). A local FIFO records operand A/B, 4×4 group, K group and full request address for each grant; each in-order registered response writes only to its recorded destination. The request source holds its address until grant. On abort, watchdog, protection or parity error, issue stops and the controller drains every accepted response before reporting completion. No descriptor, opcode, external port or software ABI changed. This is ordered-response pipelining; it does not yet fetch the next K slice while the current slice computes.

The full-core VCS regression ran three seeds at both depth 2 and depth 4. Each of six runs passed 10 bit-exact/layout cases and 14 error/recovery cases, including high-water occupancy at the configured depth, depth-2 FIFO-full request stalls, abort at full outstanding occupancy, parity on the oldest response while other reads remain pending, drain with no post-fault requests, and a clean GEMM immediately afterward. Depth-2 16×16 cases recorded high-water 2 and 17–25 FIFO-full cycles. Depth-4 cases reached high-water 4 under randomized response delays.

The fixed one-cycle behavioral-SPAD benchmark with depth 4 gives:

| Physical array | Workload | Cycles | MAC/cycle | Array utilization | Normalized GOPS @ 250 MHz | Read high-water |
|---|---:|---:|---:|---:|---:|---:|
| 4×4 | 16×16×K32 | 1600 | 5.120 | 32.00% | 2.560 | 1 |
| 8×8 | 16×16×K32 | 562 | 14.577 | 22.78% | 7.288 | 2 |
| 16×16 | 16×16×K32 | 242 | 33.851 | 13.22% | 16.926 | 2 |

Against the same 16×16 configuration's previous 357-cycle run, this is 115 fewer cycles (32.2%) and 47.5% higher normalized workload throughput. It remains VCS behavioral memory evidence; it does not model macro timing or establish DC/PPA.

Reproduction commands and current results (VCS `V-2023.12-SP1_Full64`):

```sh
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' OUTSTANDING_DEPTH=2 \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_p0b_depth2_regress_20261026
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' OUTSTANDING_DEPTH=4 \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_p0b_depth4_regress_20261026
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261026 OUTSTANDING_DEPTH=4 \
  BENCH_OUT_DIR=/tmp/nmaforge_matrix_p0b_benchmark_20261026
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All passed. `ai_smoke` included real top Matrix/CNM concurrency plus the existing 30-command workload; seeded `ai_run` ended `TEST PASS`. The next-K compute/prefetch overlap was added in P0-C below; these earlier P0-B results remain historical. Full top UVM coverage of outstanding-depth cross bins and complete cluster requirements remains open.

### 3.4 P0-C ping-pong prefetch + P1 bounded A-tile reuse

`ai_tensor_matrix_core` now prefetches the next K group's A/B words into the inactive
operand buffer while the current K group is in MAC. A buffer is marked valid only
after its accepted responses drain; compute switches to it only when valid. The
ordered response FIFO retains the target buffer/group metadata. Abort, watchdog,
parity and protection stop new requests and drain accepted responses before
error retirement. Reset clears local prefetch/FIFO state; top-level reset checks
verify no stale writeback/completion and successful recovery. No descriptor,
opcode, port or software ABI changed.

The optional-by-parameter A-tile cache holds the A tile for up to 16 K groups
(K≤64 INT8 elements for the current 16×16 configuration). It reuses A across
neighboring N macro tiles; a new A-row/batch tag invalidates the cached groups.
Shapes with K>64 bypass the cache and use the normal SPAD read path. Golden tests
cover cache hits, neighboring tiles and the K=68 fallback.

VCS `V-2023.12-SP1_Full64` regressions passed three seeds at both outstanding
depths. Every seed ran 17 numerical/layout cases and 17 fault/recovery cases,
including prefetch parity, abort, watchdog and reset with post-fault recovery:

```sh
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' OUTSTANDING_DEPTH=2 \
  A_TILE_CACHE_ENABLE=1 \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_p0c_cache_depth2_20261026
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' OUTSTANDING_DEPTH=4 \
  A_TILE_CACHE_ENABLE=1 \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_p0c_cache_depth4_20261026
```

The latest depth-4 block VDB was freshly summarized with URG. For
`ai_tensor_matrix_core` DUT-only, line/condition/FSM/branch coverage is
`96.59/88.48/66.67/95.48%`; the aggregate FSM transition coverage remains partial
(40/60 transitions), so no FSM or code-coverage closure is claimed. This report
does not include the array child as part of the core-module percentage.

The real-top UVM sequence also ran three seeds (`20261025/20261026/20261027`)
on the 16×32×64 GEMM. Each seed checked 512 outputs against the UVM Golden,
observed 16 A-cache hits and 120 prefetch/MAC overlap cycles, then exercised
queued SFU work, active prefetch abort/reset and recovery. Each seed reported
UVM warning/error/fatal `0/0/0`; focused functional coverage is `65.4%`. The
merged whole-top URG is line/condition/FSM/branch/assert/group
`47.54/41.38/10.52/37.70/60.00/19.11%`; it includes DUT, SVA, testbench and UVM,
and must not be read as DUT-only or full-cluster coverage.

The benchmark compared cache disabled/enabled at depth 4, with fixed one-cycle
behavioral bank responses and a 10 ns simulation period (GOPS normalized to an
assumed 250 MHz):

| 16×16 physical array | Cache OFF cycles / reads | Cache ON cycles / reads | Change | Cache hits |
|---|---:|---:|---:|---:|
| 16×32×K32 | 469 / 128 | 417 / 96 | cycles −11.1%, reads −25% | 8 |
| 32×32×K64 | 1443 / 512 | 1187 / 384 | cycles −17.7%, reads −25% | 32 |

The 16×16×K32 single-N-tile case remains 233 cycles with cache either enabled
or disabled. These are behavioral VCS measurements, not SRAM timing, silicon
throughput or PPA evidence. Cache-on/off benchmark logs are under
`/tmp/nmaforge_matrix_p0c_cache_{on,off}_20261026/`; top UVM logs and merged URG
are under `/tmp/nmaforge_real_compute_cluster_uvm_p0c_expanded_20261026/`.

Benchmark/cache comparison and real-top rerun commands:

```sh
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261026 OUTSTANDING_DEPTH=4 A_TILE_CACHE_ENABLE=1 \
  BENCH_OUT_DIR=/tmp/nmaforge_matrix_p0c_cache_on_20261026
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261026 OUTSTANDING_DEPTH=4 A_TILE_CACHE_ENABLE=0 \
  BENCH_OUT_DIR=/tmp/nmaforge_matrix_p0c_cache_off_20261026
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_p0c_expanded_20261026
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir /tmp/nmaforge_matrix_p0c_cache_depth4_20261026/coverage.vdb \
  -format text -report /tmp/nmaforge_matrix_p0c_cache_depth4_20261026/urg \
  -log /tmp/nmaforge_matrix_p0c_cache_depth4_20261026/urg.log
```

## 4. 尚未收敛的 P0/P1 项

- **Memory dataflow optimization**：P0-A profiling、P0-B 2/4 深度有序 read FIFO、P0-C next-K ping-pong prefetch 和 K≤64 的 A-tile reuse 已实现并有 block/top UVM 证据。剩余工作是扩大 shape/fault/backpressure 交叉覆盖、继续收敛 FSM transition bins，并完成 SRAM-aware timing/PPA；不得把 behavioral memory 数据当 macro 性能。
- **完整 Compute Cluster UVM**：top smoke 现在增加真实 Matrix/CNM 同时运行及独立 Golden/response owner 检查；top-level C1 Matrix/SFU 定向切片仍有三 seed 通过记录，完整 C1 尚未完成。现有 21 engine-pair/5 场景 C0-P regression 仍使用行为 Engine/SPAD。剩余全引擎场景、CNM parity/bank-lane、request backpressure、独立全引擎 owner/memory scoreboard 与覆盖闭环尚未完成。
- **DC/PPA**：固定工艺角、SRAM latency/timing model 和 250 MHz SDC；DC V-2023.12-SP1 可执行文件已安装，但综合被许可证错误 `DCSH-1: Design Compiler is not enabled` 拒绝；私有 TSMC standard-cell/SRAM 库也未配置，因此面积、Fmax、功耗和目标工艺 PPA 暂无证据。
- **Transformer/KV**：已有 operator primitive 和映射 smoke；还需独立 Tiny Decoder Golden、Head/Token/Prefill/Decode 数据布局及端到端对拍。
- **P2 fusion**：定义 GEMM 到 SFU 的流接口、背压、Abort、结果顺序与 SPAD ownership 后再实现 streaming path。

## 5. 规格和产品边界

本次没有改变 descriptor ABI、opcode 或软件接口。top Matrix path 默认使用 16×16 MAC array，实际完成 SPAD→array→SPAD GEMM；Banked Read 支持 2/4 深度，next-K ping-pong 预取与 MAC 重叠、K≤64 A-tile reuse 均有 block/top 定向验证。这不等于完整 Compute Cluster UVM、FSM/code-coverage closure、DC/PPA 或整体 signoff 完成。
