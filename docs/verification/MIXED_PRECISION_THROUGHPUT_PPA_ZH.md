# BF16/FP16 Dot 吞吐与 PPA 评估

## 目标与边界

本轮针对 `ai_mixed_precision_dot_fp32_core` 的串行 SPAD 读延迟进行吞吐优化，保持
`docs/spec/FP_EXTENSION_SPEC_ZH.md` 中的数值 ABI：BF16/FP16 乘积先转换为 FP32，随后
按递增元素序号逐项执行 RNE FP32 加法；不改变 FMA/舍入次数、求和顺序、opcode、端口或
最终写回语义。

Scratchpad 访问使用两个 A/B word-pair 缓冲槽，发起/跟踪最多两笔未完成读请求，使后续
操作数读取可与单元素/周期的有序累加重叠。请求仍经唯一 `ai_spad_arbiter` core-SPAD 端口，
不新增旁路或独立存储端口。响应保持原有顺序。遇到读 parity/protection 错误时，只允许
错误 word 之前的合法元素前缀继续累加；abort/watchdog 仍即时停止计算，并排空已接受访问。

## 核心吞吐微基准

比较同一 VCS testbench、常量有效 BF16/FP16 输入、每次 SPAD 读接受后固定两周期返回、无
其他 arbiter client/DDR 争用的 BF16/FP16 dot。结果是 core-level cycles，不代表完整 SoC
吞吐。`effective MAC/cycle = element_count / total_cycles`。

| 格式 | 元素数 | 串行基线周期 | 预取重叠周期 | 周期减少 | 基线 MAC/cycle | 当前 MAC/cycle |
|---|---:|---:|---:|---:|---:|---:|
| BF16 / FP16 | 2 | 11 | 9 | 18.2% | 0.1818 | 0.2222 |
| BF16 / FP16 | 8 | 35 | 17 | 51.4% | 0.2286 | 0.4706 |
| BF16 / FP16 | 16 | 67 | 29 | 56.7% | 0.2388 | 0.5517 |
| BF16 / FP16 | 64 | 259 | 101 | 61.0% | 0.2471 | 0.6337 |

## 真实 tile-pipeline DMA/SPAD 争用基准（2026-10-14 更新）

为判断多输出并行是否值得，新增 top-level benchmark，直接使用生产 RTL 的
`ai_tile_pipeline → ai_axi128_dma → ai_spad_arbiter → ai_scratchpad → mixed-precision dot core`
路径。每个争用用例处理 3 个 ping-pong tiles；权重先经 DMA 装入，计时窗口内 tile input DMA、FP
计算及结果 DMA 写回并发运行。专用 benchmark 使用 seed 驱动的伪随机 AXI RVALID 响应间隔
（0–3 个周期）和 WREADY backpressure；普通 smoke 的 memory model 默认延迟不变。外部 DDR
由 testbench 行为模型模拟，因此这是 RTL 系统级争用数据，不是 DDR PHY/板级带宽数据。每个
tile 使用确定性的 1.0 输入/权重；逐 tile 检查 completion 与 DDR 结果。

### 单 tile、无 DMA/FP 重叠基线

| 每 tile 元素数 | 1 | 2 | 3 | 4 | 16 | 64 | 128 | 256 | 1024 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| tile job cycles | 38 | 39 | 41 | 42 | 63 | 159 | 287 | 546 | 2100 |
| FP active cycles | 7 | 8 | 9 | 10 | 28 | 100 | 196 | 388 | 1540 |
| compute MAC 数 | 1 | 2 | 3 | 4 | 16 | 64 | 128 | 256 | 1024 |
| MAC / tile-job cycle | 0.0263 | 0.0513 | 0.0732 | 0.0952 | 0.2540 | 0.4025 | 0.4460 | 0.4689 | 0.4876 |
| MAC / FP-active cycle | 0.1429 | 0.2500 | 0.3333 | 0.4000 | 0.5714 | 0.6400 | 0.6531 | 0.6598 | 0.6649 |

### 三 tile ping-pong、随机 RVALID 延迟与 WREADY 争用

| 格式 | 元素数/tile | 总 tile job cycles | FP active cycles | MAC | FP 请求等待 | FP 响应等待 | DMA SPAD 等待 | DMA grant | DMA/FP overlap | MAC/job cycle | MAC/FP-active cycle |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| BF16 | 64 | 386 | 312 | 192 | 17 | 11 | 14 | 18 | 122 | 0.49741 | 0.61538 |
| FP16 | 64 | 386 | 314 | 192 | 18 | 13 | 14 | 18 | 134 | 0.49741 | 0.61146 |
| BF16 | 256 | 1399 | 1201 | 768 | 65 | 35 | 60 | 66 | 408 | 0.54896 | 0.63947 |
| FP16 | 256 | 1380 | 1199 | 768 | 65 | 36 | 60 | 66 | 384 | 0.55652 | 0.64053 |
| BF16 | 1024 | 5384 | 4752 | 3072 | 249 | 129 | 238 | 258 | 1483 | 0.57058 | 0.64646 |
| FP16 | 1024 | 5374 | 4755 | 3072 | 255 | 131 | 239 | 258 | 1499 | 0.57164 | 0.64606 |

系统吞吐曲线（`MAC/job cycle`；X 轴按 log2 长度显示）：

![BF16/FP16 tile job 吞吐随向量长度变化](./mixed-precision-throughput.svg)

`tile job cycles` 从硬件 `tile_active` 置位计到任务完成，包含 tile 输入 DMA、FP 计算、结果 DMA
写回和 tile 生命周期，不包含 CPU 配置寄存器的时间；因此 `MAC/job cycle` 是该 testbench 所测
tile 任务端到端吞吐。`MAC/FP-active cycle` 只看 `fp_busy` 窗口，用来分离计算引擎效率与系统开销。

计数定义：FP 请求等待为 FP core 请求有效但 core-SPAD 未 grant 的周期；FP 响应等待为存在
未完成读请求、尚无响应且本周期没有 compute fire；DMA SPAD 等待/grant 仅在 FP core busy
时统计 DMA 侧被 arbiter 拒绝/接受的请求周期/事务；overlap 为 perf monitor 对 tile DMA 与
计算重叠的周期计数。这些计数彼此可能重叠，不能直接相加当作总 latency。每个用例另观察到
tile stall counter 为 3（单 tile）或 5（三 tile）。

结果判断：长度 1024 时，FP busy 窗口内有效 MAC/cycle 从无争用的 0.66494 降至争用的
0.64606–0.64646，约下降 2.8%；但现有 ping-pong tile pipeline 把多数 DMA 与计算重叠，三 tile
任务的端到端吞吐达到 0.57058–0.57164 MAC/job-cycle，高于单 tile 顺序任务的 0.48762；长度 64、
256 也观察到类似的端到端提升。可见共享 SPAD 争用真实存在（例如 1024 长度下 FP 请求等待
249–255 周期、DMA 等待 238–239 周期），但当前 pipeline 已能隐藏相当部分搬运开销。综合这些数据，
**暂不建议直接复制多路输出 MAC lane**：本轮已加入 seed 驱动的 RVALID 延迟与 WREADY backpressure；
下一步应在更贴近目标系统的数据复用模型下复测，并构建可随机化多客户端的 DMA/SPAD subsystem
UVM 环境。若增加压力后 FP 端仍持续因供数空转，再开展多输出结构对比。
新增 lane 仍须保持各输出独立的逐元素 FP32 RNE 累加顺序，不可改成树归约或 FMA。

复现命令（Rocky-8.10 WSL / VCS V-2023.12-SP1）：

```bash
make -C dv/subsystem/top_smoke/sim ai_fp_dot_dma_benchmark FP_BENCH_SEED=20261013
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/dma/sim uvm_regress
```

本次 `FP_BENCH_SEED=20261013` 全部 24 个 BF16/FP16 测点 PASS；ping-pong 测点采用随机 RVALID
响应间隔和 WREADY backpressure，DDR BFM 结果、tile 数及结果写回逐项检查通过。DMA UVM 11/11、
普通 `ai_smoke` 与 20-case seeded top regression 也 PASS。原始 CSV 行保存在
`dv/subsystem/top_smoke/sim/ai_fp_dot_dma_benchmark.log`
（为忽略的生成日志，不纳入 Git）。

## Bank 数和 AXI 带宽的设计理由

当前 4-bank 是为了沿用现有 4-lane bank-local CNM/INT8 数据路径，同时在 512 KiB 容量下
给四个 bank 各分配 128 KiB。它是架构与验证范围的折衷，不是“4 个 bank 已证明最优”的结论；
项目没有完成 2/4/8 bank 的同约束面积、时序、冲突率 sweep。4-bank 也不会自动让 scalar FP
核每周期获得四份数据：本轮 FP 使用现有 arbiter-owned 32-bit core-SPAD 端口，bank 数不能
替代端口仲裁和地址映射分析。

AXI4 原始上限为 128 bit = 16 byte/beat，即 4.0 ns（250 MHz）时 4 GB/s，2.5 ns（400 MHz）
时 6.4 GB/s；这是每周期一个满宽 beat、无空泡的理论峰值，不等于 DDR 实际可持续带宽。一个
连续满载 FP16/BF16 MAC 每次消耗 2-byte A 和 2-byte B，单 lane 在 400 MHz 需要约 1.6 GB/s；
四个同样不复用操作数的 lane 则需要 6.4 GB/s，已经吃满 AXI 理论峰值，尚未计 burst 空泡、
读写混合、DMA/descriptor traffic 与 DDR 效率。因此目前只能说 AXI 对单 lane 的纸面带宽够用，
不能说系统没有 AXI/DDR 瓶颈；真实判断要看 DMA 带宽、FP 等待、SPAD 冲突和数据复用的同一
端到端 workload 统计。

64-element core-level latency改善约 2.56×（有效 MAC/cycle 同比提升约 2.56×）。短向量受启动、
写回和完成固定开销影响；越长向量越能体现读/算重叠。此数据只说明固定延迟模型下的核
吞吐，尚不能说明真实系统瓶颈或 DDR 性能。

复现命令（Rocky-8.10 WSL / VCS V-2023.12-SP1）：

```bash
make -C dv/block/compute/fp/sim dot-throughput-bench
make -C dv/block/compute/fp/sim dot-core-test
make -C dv/block/compute/fp/sim dot-uvm-regress DOT_RANDOM_COUNT=256 'DOT_UVM_SEEDS=712345 987654 20261014'
make -C dv/block/dma/sim uvm_regress
make -C dv/block/control/sim uvm_regress
make -C dv/subsystem/top_smoke/sim ai_spad_arb_run
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/subsystem/top_smoke/sim ai_fp_dot_dma_benchmark FP_BENCH_SEED=20261013
```

以上 gate 本轮均通过：FP block test；mixed-dot UVM 四个 seed、每格式 256 个随机向量且
`UVM_ERROR/FATAL=0`、URG merge 成功；DMA UVM 11 项；control UVM 6 项；SPAD arbiter directed
test（含响应周期 parity 对齐）；top `ai_smoke` 与 20-case seeded run 均为 `TEST PASS`；24 个
系统级 FP benchmark 测点的结果、tile 数及 DDR BFM 写回检查通过。Focused FP test 另覆盖
word-1 parity 错误时 element_count 保持 2、已接受请求 drain 且不写回。

## 4.0 ns PPA 比较

注意：本节数字是双 pair-slot 预取候选当时的 4.0 ns pre-layout 结果；本次 profiling 又修正了
`ai_spad_arbiter` 的 response parity/error 对齐逻辑，**尚未对该最新 RTL 重跑 DC**。因此这些数字
不能直接称为包含本次 arbiter 修正的最新版本 PPA；应在后续 PPA 阶段以相同库/约束/workload 复跑。

基线和候选使用同一私有 28 nm 标准单元/SRAM 库、同一 DC 脚本、同一 4.0 ns 时钟约束和相同
smoke workload 导出的 SAIF。库文件、宏模型和 license 配置不属于公开文档/仓库。本节仅记录
pre-layout 综合估算，不代表 place-and-route、post-layout STA 或 sign-off。

约束条件：TT、0.9 V、25 °C，DC V-2023.12-SP1，4.0 ns（250 MHz），zero-wireload；基线取
`e730d1f` 预取改动前 RTL，候选为当前工作区 RTL。基线关键路径由 scratchpad macro 输出到
SFU `sum_exp_r[63]`，路径长度 3.87 ns；这是本 profile 的 pre-layout 结果。

| 指标 | 基线 | 预取重叠候选 | 结论 |
|---|---:|---:|---|
| 综合总面积（含 SRAM macro） | 1,245,600.72 | 1,245,719.00 | +118.29，约 +0.0095% |
| 标准单元逻辑面积 | 117,924.97 | 118,043.25 | +118.29，约 +0.1003% |
| SRAM macro 面积 | 1,127,675.75 | 1,127,675.75 | 不变，32 macros |
| WNS / 关键路径 | 0.00 ns / 3.87 ns | 0.00 ns / 3.87 ns | 4.0 ns 下两者均无 setup violation；关键路径仍在 SFU |
| SAIF 动态功耗 | 22.8209 mW | 23.0483 mW | +0.2274 mW，约 +1.00% |
| Leakage | 1.9729 mW | 1.9720 mW | -0.0009 mW，约 -0.046% |

同一条件下，64-element 微基准周期减少 61.0%（259→101）；DC 显示很小的逻辑面积增量、
4.0 ns 时序不退化，但动态功耗估算增加约 1%。因此这批改动是吞吐优化，不是低功耗优化；
4.0 ns 综合结果也不能证明 400 MHz 可达。

基线与候选 power 报告均有
3 个 switching-activity conflicts，并提示 sequential cell outputs 与 black-box outputs 未注释；
SRAM 宏功耗/部分状态翻转因此不是完整的 activity-accurate 结果。`report_switching_activity`
在本机 DC 安装中不可用，故不能给出已注释对象比例。DC power 仅用于同一 flow 下的方向性
对比，不作为功耗 sign-off。基线与候选的 `qor.rpt`、`area.rpt`、`power.rpt`、`timing.rpt`
分别保存在本机 `/tmp/nmaforge_dc_base4_saif_valid3` 和 `/tmp/nmaforge_dc_opt4_saif_valid1`；
不将私有工艺库或临时报告复制进公开仓库。

## 下一步

1. 先对包含本次 `ai_spad_arbiter` response parity 修正的最新 RTL 重跑 4.0 ns；再用 2.5 ns（400 MHz）
   及更紧的时钟约束检查关键路径。当前记录的旧候选 4.0 ns 结果只适用于其对应 RTL snapshot。
2. 用真实 AXI/DDR workload 与 SPAD 仲裁统计分辨带宽受限、仲裁受限或计算受限；不能仅从
   AXI 128-bit 名义宽度推断系统性能。
3. 只有数据表明单路核仍计算受限，且 PPA/数值/验证可接受后，才评估多输出并行；单个 dot
   的严格顺序累加不能拆成并行 partial sum。4-lane 需额外
   证明 4-bank/共享 arbiter 能持续供数。所有并行累加仍须严格保留每个输出的原顺序 FP32
   舍入，不能擅自改成树归约或 FMA。
