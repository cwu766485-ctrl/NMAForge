# NMAForge 性能、带宽、流水与 PPA 基线报告

> 版本：2026-09-24。本文只使用仓库内可追溯的 VCS 日志、RTL benchmark 输出和 TSMC28 DC 报告。`实测`、`推导`、`未测`严格区分；不能把推导峰值写成端到端吞吐。

## 1. 测试与证据边界

| 项目 | 证据 |
|---|---|
| A2 GEMV | `dv/subsystem/top_smoke/sim/ai_cnm_a2_gemv_bench_run.log`，VCS V-2023.12-SP1，PASS |
| A3.1 GEMM | `dv/subsystem/top_smoke/sim/ai_tensor_a3_gemm_bench_run.log`，VCS V-2023.12-SP1，PASS |
| SPAD 仲裁 | `ai_spad_arb_run.log`，CNM/DMA contention PASS，`cnm_grants=6`、`dma_line_grants=6` |
| 顶层 smoke | `ai_accel_smoke.log`，`TEST PASS`；覆盖 AXI-Lite、DMA、计算和错误恢复 |
| PPA | `syn/out/tsmc28_4_0ns/reports/{qor,area,power}.rpt`，TSMC28 TT/0.9 V/25°C，pre-layout |
| 重跑限制 | 本轮 WSL 启动返回 `E_ACCESSDENIED`，未声称重新编译成功 |

## 2. 算子级性能基线

### 2.1 A2 bank-local GEMV

每个 case 为 `64×L` INT8 MAC；`mac_per_cycle_x1000` 为 MAC/cycle 的千倍。

| L | MAC 数 | 周期 | MAC/cycle | 读 word | 预取事件 | response wait |
|---:|---:|---:|---:|---:|---:|---:|
| 16 | 1,024 | 153 | 6.692 | 512 | 240 | 0 |
| 64 | 4,096 | 537 | 7.627 | 2,048 | 1,008 | 0 |
| 256 | 16,384 | 2,073 | 7.903 | 8,192 | 4,080 | 0 |

相对冻结的中央 accumulator 基线（265/1033/4105 cycles），加速比分别为 **1.73×、1.92×、1.98×**。这是同频、受控 SRAM 时序、无 DMA 竞争的 RTL 周期收益。

### 2.2 A3.1 4×4 GEMM tile

| L | MAC 数 | 周期 | MAC-active | MAC/cycle | banked wait |
|---:|---:|---:|---:|---:|---:|
| 16 | 1,024 | 74 | 64 | 13.837 | 2 |
| 64 | 4,096 | 266 | 256 | 15.398 | 2 |
| 256 | 16,384 | 1,034 | 1,024 | 15.845 | 2 |

相对冻结基线的加速比分别为 **3.58×、3.88×、3.97×**；相对 A2 的有效吞吐约为 **2.0×**。

## 3. 性能指标（对应 1.1）

| 指标 | 当前结果 | 状态 |
|---|---:|---|
| A2 latency | `153/537/2073 cycles` | 实测 |
| A3.1 latency | `74/266/1034 cycles` | 实测 |
| A2 effective MAC/cycle | `6.692/7.627/7.903` | 实测 |
| A3.1 effective MAC/cycle | `13.837/15.398/15.845` | 实测 |
| A3.1 理论 250 MHz 算术吞吐 | `15.845×250M=3.96 GMAC/s≈7.92 GOPS` | 推导 |
| 端到端 CNN images/s、LLM tokens/s | — | 未测 |
| 多任务 initiation interval | — | 未测；当前 command processor 主要单任务生命周期串行 |

Latency 公式为 `cycles / Fclk`。例如 A3.1 L=256 在 250 MHz 下约 `1034×4 ns=4.136 µs`，这是算子级 RTL 周期换算，不含真实 DDR 和软件开销。

## 4. 存储、带宽与数据供应（对应 1.2）

硬件结构：512 KiB、4 bank、128-bit AXI4 DMA。250 MHz 时 AXI4 理论单方向峰值为：

```text
128 bit × 250 MHz / 8 = 4 GB/s
```

| 指标 | 当前结果 | 状态 |
|---|---:|---|
| A2 read word | `512/2048/8192` | 实测日志 |
| A2 prefetch | `240/1008/4080` | 实测日志 |
| A3.1 banked wait | `2/2/2 cycles` | 实测日志 |
| SPAD contention | CNM 6 grants、DMA line 6 grants | 实测日志 |
| DMA read/write bytes、有效带宽 | smoke 暂未导出固定 workload 快照 | 待补 |
| arithmetic intensity（端到端 DDR） | 需要 DMA byte 计数 | 待补 |
| SPAD reuse/occupancy | 需要固定 tile allocator 记录 | 待补 |
| DMA outstanding high-water | 计数器已存在，未形成 workload 表 | 待补 |

不能用 A2 的 SPAD `read word` 直接替代 DDR bytes；它是 bank-lane 访问计数，端到端带宽必须使用 `PERF_DMA_READ_BYTES/WRITE_BYTES` 和总周期计算。

## 5. 流水与利用率（对应 1.3）

项目已有 `total/dma/compute/overlap/stall`、`matrix_mac_cycles`、`matrix_banked_stall`、`dma_r_stall` 计数器。当前可确认的算子级证据是：

```text
A3.1 L=16/64/256：MAC-active=64/256/1024
A3.1 banked_wait：均为 2 cycles
A2 L=16/64/256：response_wait=0
```

定义：

```text
计算利用率 = MAC-active cycles / compute cycles
DMA/计算重叠率 = overlap_cycles / min(dma_cycles, compute_cycles)
流水效率 = 有效工作周期 / total_cycles
```

当前尚未有同一端到端 Tile workload 的 `dma_cycles/compute_cycles/overlap_cycles/stall_cycles` 快照，因此不能填写重叠率。下一次 benchmark 必须同时记录这五项；不能用算子级 `banked_wait` 冒充 DMA/compute overlap。

## 6. PPA（对应 1.4）

条件：TSMC28 TT/0.9 V/25°C，4.0 ns pre-layout DC；32 个真实 SRAM macro。

| 指标 | 结果 |
|---|---:|
| 目标周期/频率 | 4.0 ns / 250 MHz |
| 关键路径 | 3.89 ns |
| setup WNS/TNS | 0.00 / 0.00 ns |
| hold WNS/TNS | 0.00 / 0.00 ns |
| 总 cell area | 1,245,378.649905 library units |
| SRAM macro area | 1,127,675.750000 units，约90.5% cell area |
| combinational area | 72,476.095923 units |
| sequential area | 45,226.803982 units |
| leaf cells | 138,332 |
| SRAM macros | 32 |
| dynamic power | 22.8290 mW |
| leakage power | 1.9733 mW |
| total（DC估计） | 24.8063 mW |

功耗报告有 `PWR-414/415/428` 未完全标注输入、时序输出和 SRAM black-box 输出；因此 24.8063 mW 只能作为默认/部分活动率 pre-layout 估计，不能作为 SAIF workload sign-off 或 GOPS/W 结论。当前关键路径穿过 Scratchpad read/SFU accumulation-control，后续做频率优化应优先检查 SRAM 后 mux、累加深度和 SFU 路径。

## 7. 第三层：端到端子图计划与当前状态

### CNN 子图

```text
Conv3x3 → ReLU/Requant → DWConv3x3 → Conv1x1
```

### Transformer 子图

```text
Q/K/V projection → QKᵀ → Causal Softmax → score×V → RMSNorm
```

对每个子图必须比较：

```text
直接模式、CMDQ 连续任务、Tile/ping-pong 模式
```

并记录：

```text
端到端 cycles、DMA read/write bytes、有效带宽、MAC/cycle、overlap 比例、
每输出元素周期（CNN）或每 token 周期（Transformer）。
```

当前仓库已有算子 smoke（Conv3x3、DWConv3x3、GEMV、GEMM、DMA、CMDQ）并显示 `TEST PASS`，但还没有固定 CNN/Transformer 子图的统一 cycle/byte 表。因此第三层目前是 **功能覆盖已有，性能统计未闭环**。

## 8. 结论与下一步

当前可公开、可面试的结论：

1. A2 bank-local GEMV 在受控 RTL benchmark 中最高约 1.98× 周期收益。
2. A3.1 4×4 GEMM tile 最高约 3.97× 周期收益，达到约 15.845 MAC/cycle。
3. 250 MHz TSMC28 pre-layout setup/hold closure 已有证据；面积由 512 KiB SRAM 主导。
4. DMA/compute overlap、端到端 DDR 带宽、CNN/Transformer 子图吞吐仍需固定 workload 统计。

推荐下一步：为 CNN 和 Transformer 各写一个固定 shape 的 VCS benchmark，读取 `ai_perf_monitor` 的 DMA/compute/overlap/stall 快照，再用同一 workload 做直接、CMDQ、Tile 三组对比；之后才决定是否增加 pipeline、outstanding 或多核。
