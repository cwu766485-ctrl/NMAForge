# NMAForge 性能 Sweep 与端到端实验计划

日期：2026-09-24

## 当前结论

本轮首次尝试在 Rocky Linux 8.10 WSL 中运行 VCS 时，入口环境未设置 `VCS_HOME`；补齐 VCS 环境和 license 后已恢复：

```text
wsl -d Rocky-8.10 ... make ai_cnm_compare
ERROR: Cannot find 'vcsMsgReport' script in /bin
```

原始缺失的 `vcsMsgReport` 已定位为环境变量问题，不是工具安装损坏。A2/A3 focused benchmark 和 `ai_smoke` 已恢复 PASS。以下项目仍不能标记为已完成实测：128/256/512 KiB Scratchpad sweep、2/4/8 bank sweep、3.5/3.0/2.5 ns DC sweep，以及统一 CNN/Transformer 端到端吞吐。

## 实验矩阵

| 实验 | 组合 | 必须记录 |
|---|---|---|
| Scratchpad 容量 | 128/256/512 KiB | total cycles、DMA read/write bytes、area、power |
| Bank 数量 | 2/4/8 | bank conflict、stall、MAC/cycle、DDR traffic |
| DC 目标周期 | 4.0/3.5/3.0/2.5 ns | WNS/TNS、critical path、area、power |
| CNN 子图 | Conv3x3→ReLU/Requant→DWConv3x3→Conv1x1 | end-to-end cycles、bytes、images/s |
| Transformer 子图 | Q/K/V→QKᵀ→causal softmax→score×V→RMSNorm | token cycles、bytes、MAC/cycle |

## 已有基线

当前仓库已有 512 KiB、4-bank 基线和 4.0 ns DC 结果：

- A2 bank-local GEMV：最高 1.98× cycle reduction，7.903 MAC/cycle。
- A3.1 4×4 INT8 GEMM：最高 3.97× cycle reduction，15.845 MAC/cycle。
- TSMC28 pre-layout：250 MHz timing closure，critical path 约 3.89 ns。
- DC area：SRAM macro 约占总面积 90.5%；功耗为带 black-box 限制的 pre-layout estimate。

这些是 directed RTL microbenchmark 或 pre-layout 结果，不是端到端 CNN/LLM 吞吐。

本轮实际运行（VCS V-2023.12-SP1，Rocky 8.10；license 由本机环境配置，本文不记录 license 路径或值）：

| Gate | 结果 | 证据 |
|---|---|---|
| A2 GEMV | PASS | `ai_cnm_a2_gemv_bench_run.log`，153/537/2073 cycles |
| A3 GEMM | PASS | `ai_tensor_a3_gemm_bench_run.log`，74/266/1034 cycles |
| SPAD arbiter | PASS | `cnm_grants=6`，`dma_line_grants=6` |
| Top smoke | PASS | `ai_accel_smoke.log`，含 3-tile ping-pong `completed tiles=3`、`overlap cycles=37` |

顶层 smoke 还实际覆盖了 4 outstanding、16-beat burst、4 KiB split、CNN/Transformer 功能链和 reset recovery；这些是功能/协议证据，不应替代端到端吞吐 sweep。

本轮恢复运行后的证据：

```text
# Set VCS_HOME to the locally installed VCS release.
export PATH="$VCS_HOME/bin:$PATH"
# Configure LM_LICENSE_FILE locally; do not commit server or license paths.
export VCS_ARCH_OVERRIDE=linux
make ai_cnm_compare
make ai_smoke AI_RANDOM_CASES=4 AI_SEED=12345
```

结果：A2 GEMV PASS、A3 GEMM PASS、top smoke `TEST PASS`。A3 focused Makefile 原先漏列 `ai_tensor_matrix_datapath.v`，已补齐；这是工程 source-list 修复，不是 RTL 算法改动。

## 可复现实验命令

```text
cd dv/subsystem/top_smoke/sim
make ai_cnm_compare ai_spad_arb_run ai_smoke
cd ../../../..
bash syn/run_ai_accel_28nm_dc.sh 4.0
bash syn/run_ai_accel_28nm_dc.sh 3.5
bash syn/run_ai_accel_28nm_dc.sh 3.0
bash syn/run_ai_accel_28nm_dc.sh 2.5
```

DC 运行前必须在本机配置私有 `TSMC28_STDCELL_DB` 和 `TSMC28_SRAM_DB_TT`。本轮检查环境未发现可用的 `dc_shell` 和私有 `.db/.lib` 文件；4.0 ns 及 3.5/3.0/2.5 ns sweep 均因此未启动，不能产生新的 DC 结论。容量/bank sweep 必须同步更新 Scratchpad 参数、SRAM 宏映射和全部 source list；不能只改变文档中的数字。

## 完成判据

每组实验必须保存 tool version、完整命令、约束、日志路径和 PASS/FAIL。Tile workload 还必须从 `ai_tile_pipeline` 导出 `perf_total_cycles`、`perf_dma_cycles`、`perf_compute_cycles`、`perf_overlap_cycles`、`perf_stall_cycles`、`completed_tiles`，并由 DMA 计数器给出 DDR bytes。未获得这些证据前，不得宣称 DMA/compute overlap 或有效带宽已经闭环。

## Trade-off 记录

- 4-bank 和 local accumulation 降低 bank 冲突及中央归约压力，但增加仲裁、partial-sum 和 reduction 逻辑。
- 128-bit line 提高 DMA 搬运效率，但要求对齐和尾部处理。
- 4 outstanding 可隐藏 DDR 延迟，但增加 ID、乱序响应和 abort-drain 复杂度。
- single-port SRAM 面积/功耗较低，但读写冲突会形成 stall。
- 当前 SRAM 已占面积约 90.5%，所以扩大容量前必须先测 reuse、bank conflict 和 DMA stall。
