# CIMForge 数字 CNM：实现、性能与验证报告

**报告状态：A1、A2.2、A3.1 RTL 已实现；定向 VCS benchmark 与仲裁器单测已通过。**

本文件合并并取代原 `CNM_A2_EVALUATION_ZH.md` 和
`CNM_A2_A3_COMPARISON_ZH.md`，是 CNM 的唯一性能与验证报告。

## 1. 范围与架构结论

本项目的 CNM 是 **数字 Compute-Near-Memory**，不是模拟 CIM：运算使用
数字 MAC、SRAM 使用普通数字读出，不包含 ADC/DAC 或模拟位线累加。

```text
SRAM Bank i <-> Local Controller i <-> Local PE i
                         |
                 output-level Global Reducer
                         |
                  quantize / writeback
```

A2.2 已让四个 SRAM bank 分别具备独立地址、请求/ready、response-valid、
A ping-pong buffer 和 local accumulator；共享全局归约只在一个输出完成时发生。
因此设计已经符合数字 CNM 的架构定义。

边界也必须如实说明：`ai_spad_arbiter` 仍是 scheduler-side scratchpad 的唯一
入口。CNM 可在一次仲裁事务中携带四条 bank lane 地址/mask，但**尚未**实现
“不同外部 client 同时占用不同 bank”的细粒度 bank-level arbitration。

## 2. 阶段实现

| 阶段 | 实现内容 | 主要适用负载 | 状态 |
|---|---|---|---|
| 原始 | 中央 accumulator；每个 K-group 走共享归约 | 基线 GEMV | 冻结作 benchmark 基线 |
| A1 | 四个 64-bit local accumulator；输出边界归约 | VDOT/GEMV | 已实现、定向 PASS |
| A2.1 | A/B 读算流水、A ping-pong buffer、A 预取 | VDOT/GEMV | 已实现 |
| A2.2 | 四个独立 Local Controller 与独立 CNM lane | VDOT/GEMV | 已实现、定向 PASS |
| A3.1 | 4×4 GEMM tile；最后 MAC lane 直接消费 B prefetch response | GEMM/attention/FFN | 已实现、benchmark PASS |

### A1：本地累加

旧路径中，每个 K-group 的 partial sum 都需要进入共享归约。A1 变为先在四个
bank 本地累加，最后只做一次 global reduction。对四个 GEMV 输出、长度为 L
的测试，global reduction 事件从 `4L` 降至 `4`，降幅为：

| L | 原始事件数 | A1/A2 事件数 | 降幅 |
|---:|---:|---:|---:|
| 16 | 64 | 4 | 93.75% |
| 64 | 256 | 4 | 98.44% |
| 256 | 1,024 | 4 | 99.61% |

A1 没有修改原始读请求 FSM，因此在当前 SRAM 时序模型下与原始版本周期相同；
它的收益是减少共享归约活动，而不是已经测得的 cycle speedup。

定向功能证据：

```text
PASS: A1 CNM VDOT result=32 cycles=21 local_acc=12 global_reduce=1
```

### A2.2：四个独立 bank-local Controller

新增模块：

- `rtl/compute/ai_bank_local_controller.v`
- `rtl/compute/ai_banked_cnm_core.v`

每个 controller 独立维护地址状态、A buffer、local sum 与
read/prefetch/compute/wait 计数器。接口映射为：

```text
LC0 -> cnm_addr0 / cnm_ready[0] / cnm_rsp_valid[0] -> SRAM bank0
LC1 -> cnm_addr1 / cnm_ready[1] / cnm_rsp_valid[1] -> SRAM bank1
LC2 -> cnm_addr2 / cnm_ready[2] / cnm_rsp_valid[2] -> SRAM bank2
LC3 -> cnm_addr3 / cnm_ready[3] / cnm_rsp_valid[3] -> SRAM bank3
```

定向测试（Synopsys VCS V-2023.12-SP1，2026-08-05）已通过：

```text
PASS: CNM A2.2 result=32 cycles=13 local_acc=12 global_reduce=1
    reads=24 prefetch=8 compute=12 rsp_wait=0
```

该 case 有 3 个 K-group、4 个 bank：`local_acc=12=4×3`、
`reads=24=4×3×2(A/B)`、`prefetch=8=4×2`、`compute=12=4×3`，证明四条
Local Controller 路径、预取和 output-level reduction 均实际激活。

### 仲裁器验证

`ai_spad_arbiter` 单测已验证 Control-plane priority、Core/banked/DMA
round-robin、128-bit line 请求，以及 CNM 四 lane 请求/响应 mask 保持：

```text
make ai_spad_arb_run
Scratchpad round-robin arbiter PASS
```

此前的 `CNM response lane mask was not preserved` 是 testbench 在 DUT 采样
`posedge` 同时撤销 `cnm_valid` 的 race；已改为跨采样沿保持 valid、在随后
`negedge` 撤销。它不是 CNM RTL mask 丢失。

## 3. 同 MAC 数的实测周期结果

### 3.1 测试口径

- 工具：Synopsys VCS V-2023.12-SP1_Full64。
- `L=16/64/256` 为 K-group 数。
- 每个 case 固定为 `64L` 个 INT8 MAC。
- A2 是 4-row GEMV；A3.1 是 4×4 GEMM tile。
- SRAM read response 为一周期，且无 DMA 竞争。
- 原始版本来自冻结的 central-accumulator RTL，并非手算模型。

因此这里比较的是相同 MAC 数下的 RTL 周期与有效 MAC/cycle；**不是**
post-layout Fmax、功耗或端到端系统吞吐。

### 3.2 原始、A1、A2、A3.1 对比

| L | 总 INT8 MAC | 原始 GEMV cycles | A1 cycles | A2 GEMV cycles | A3.1 GEMM cycles |
|---:|---:|---:|---:|---:|---:|
| 16 | 1,024 | 265 | 265 | 153 | 74 |
| 64 | 4,096 | 1,033 | 1,033 | 537 | 266 |
| 256 | 16,384 | 4,105 | 4,105 | 2,073 | 1,034 |

| L | 原始/A1 MAC/cycle | A2 MAC/cycle | A3.1 MAC/cycle | A2/原始 | A3.1/原始 | A3.1/A2 |
|---:|---:|---:|---:|---:|---:|---:|
| 16 | 3.864 | 6.692 | 13.837 | 1.73× | 3.58× | 2.07× |
| 64 | 3.965 | 7.627 | 15.398 | 1.92× | 3.88× | 2.02× |
| 256 | 3.991 | 7.903 | 15.845 | 1.98× | 3.97× | 2.00× |

结论：A2 在大 GEMV（L=256）取得 **1.98×** 同频周期加速；A3.1 在受控的
GEMM tile 工作负载下取得 **3.97×** 相对原始基线、约 **2×** 相对 A2 的有效
MAC 吞吐。

### 3.3 结构计数

| L | A2 response wait | A2 独立 bank lane read | A2 A-prefetch |
|---:|---:|---:|---:|
| 16 | 0 | 512 | 240 |
| 64 | 0 | 2,048 | 1,008 |
| 256 | 0 | 8,192 | 4,080 |

`lane read` 是四条 32-bit bank lane 的总访问数；原始 RTL 的 `reads=8L` 是
128-bit banked-row 事务数，单位不同，不能拿这两个字段直接比较读次数。

A3.1 的 `MAC-active` 在 L=16/64/256 分别为 64/256/1024，`banked_wait`
均为 2 cycles。相对于 A3.0 的 17/65/257 wait cycles，A3.1 消除了随 L
线性增长的预取等待气泡。

## 4. A3 是否继续推进

**结论：A3.1 已值得保留并纳入验证；现在不建议立即再开 A3.2 改 RTL。**

原因是 A3.1 已经实现并给出明确的、同 MAC 数下约 2× 相对 A2 的 GEMM 吞吐
优势。下一阶段最有价值的是确认它在真实工程约束下仍成立：

| 工作负载 | 推荐路径 | 原因 |
|---|---|---|
| N=1 VDOT/GEMV、向量归约 | A2 | bank-local 控制和预取更贴合一维数据形状 |
| GEMM、Q/K/V projection、attention 矩阵乘、FFN | A3.1 | 4×4 输出复用可提高 MAC 利用率 |

推进顺序：

1. 将 A3.1 纳入 `make ai_smoke` 的系统回归并补矩阵结果覆盖；
2. 加入 DMA 竞争测试，统计 A2/A3 在仲裁压力下的周期；
3. 生成 VCD/SAIF，做功耗分析；
4. 用 DC/Vivado 得到面积、WNS/Fmax，确认 4×4 阵列的频率代价；
5. 只有上述数据揭示新的瓶颈时，再定义 A3.2（例如更大 tile、双缓冲或更细粒度 bank arbitration）。

这样不会把已经通过、且已消除主要 wait 气泡的 A3.1 重新推倒；同时能把“RTL
周期收益”提升为可信的 PPA 结论。

## 5. 当前验证证据与待完成项

已通过：

- `make ai_cnm_a22`：A2.2 bit-exact 与结构计数 PASS；
- `make ai_spad_arb_run`：仲裁器与 CNM 四 lane mask PASS；
- `make ai_smoke`：已记录配置 `AI_RANDOM_CASES=4`、`AI_SEED=12345`，日志为 `TEST PASS`；
- `make ai_cnm_final_compare`：原始/A1/A2/A3.1 的 benchmark PASS。

已补充、待在 Synopsys 环境运行：

- `make ai_spad_arb_run` 现包含 12 个周期的持续 CNM read 与 DMA line
  请求竞争，检查二者 grant 差不超过一个周期，并输出双方 grant 数。这是
  SPAD 仲裁层的数据面竞争测试；direct DMA 和 direct compute 受寄存器 ABI
  互斥限制，不能把它伪装成系统已经支持的直接并发。
- `make ai_smoke` 新增三 K-group 的 CNM VDOT 集成 case，预期结果为 32，覆盖
  AXI-Lite、command processor、CNM、SPAD arbiter 与 writeback。
- `make ai_smoke_saif` 通过同一 smoke 生成 VCD 并调用 `vcd2saif`。DC 仅在
  `CIMFORGE_SAIF` 指向该 SAIF 时将其作为活动率注入 `report_power`；未提供
  SAIF 的 power.rpt 必须标记为默认活动率估计，而不是实测功耗。

待完成：上述新增测试的 VCS PASS、SAIF 功耗、DC/Vivado 时序/面积及后布局
PPA。这些完成前，不应把本报告的周期结果表述为已测 Fmax 提升或芯片总功耗
降低。

### 5.1 DC 运行结果（2026-08-06）

用户已成功启动并执行 `dc_shell -f syn/dc_ai_accel_28nm.tcl`，脚本末尾出现：

```text
CIMForge DC activity: measured SAIF=...
CIMForge TSMC28 DC completed: /mnt/e/workspace/chip/CIMForge/syn/out/tsmc28_4_0ns
```

本次真实库 run 已经得到**有效的面积和时序结果**，但功耗仍需修正 SAIF
层次映射后再签核：

- `area.rpt` 使用真实 TSMC28 标准单元和 SRAM `.db`，32 个 SRAM 宏，
  总 cell area 为 `1,245,378.649905` library area units；其中宏面积
  `1,127,675.750000`，标准单元部分约 `117,702.899905`；
- `qor.rpt` 的关键路径长度为 `3.89 ns`，4.0 ns 时钟下 setup WNS/TNS
  为 `0.00/0.00 ns`，setup 违例为 0；hold WNS/TNS 为 `0.00/0.00 ns`，
  hold 违例为 0；
- `power.rpt` 的库、电压和单位已经有效（TT/0.9 V/25°C、mW/nW），但明确
  报告 `PWR-362: No switching activity has been annotated`，并提示未标注
  primary input、sequential output 和 SRAM black-box output。因此当前
  `22.8290 mW` dynamic、`1.9733 mW` leakage、`24.8063 mW` total 只能作为
  DC 默认/部分活动率估计，不能称为 SAIF 实测功耗；
- `OPT-1207` 的 local accumulator、response wait counter 等寄存器删除信息
  是综合优化的正常现象，不代表 CNM 功能被仿真删除；这些计数器是验证可观测
  逻辑，综合后若无硬件接口使用，DC 删除它们是合理的。

因此这次可以确认：**真实 TSMC28 pre-layout 面积和 250 MHz setup/hold 已
闭合；功耗 SAIF 注释尚未成功。**

### 5.2 PPA 是否正常

当前面积结构是合理的：总面积 `1,245,378.65` 中约 90.5% 来自 32 个 SRAM
宏，标准单元逻辑约 9.5%。对于 512 KiB scratchpad，这种“存储宏主导面积”是
预期现象，不能只看标准单元面积判断 CNM 代价。

`3.89 ns` 关键路径对应 4.0 ns 约束只剩约 `0.11 ns` 裕量，说明 250 MHz
可以闭合，但不是很宽松；后续若增加阵列、改 SFU 或换 PVT，必须重新跑时序。

`22.8290 mW` dynamic / `1.9733 mW` leakage 的数量级暂时可作参考，但由于
`PWR-362` 表示 SAIF 没有成功注释，且 SRAM black-box 输出没有活动率，这两个
数字不能用于 CNM 与 baseline 的功耗对比。特别是 clock network 占比很高，通常
说明活动率覆盖不足或时钟树模型仍是 pre-layout 估计。

## 7. 功耗修正方法与开发流程

功耗修正按以下顺序进行：

1. 用 smoke 生成 VCD/SAIF，确认 SAIF 顶层包含 `tb_ai_accel_smoke/dut`；
2. DC 读取 SAIF 时对综合顶层 `ai_accel_top` 使用 `-auto_map_names`；
3. 检查新增的 `saif_activity.rpt`，确认不是所有寄存器都显示
   `annotated=0`；
4. 对 SRAM 宏单独提供宏级活动模型或保守 toggle/read-write rate，因为硬宏
   black-box 的内部 bitcell 功耗不会从 RTL VCD 自动推导；
5. 重新生成 `power.rpt`，只比较同一 workload、同一时钟、同一 PVT 下的 CNM
   与 baseline。

正常 IC 流程不是“先把 DC 做完，再开始 UVM”，而是并行迭代：

```text
RTL/架构冻结一部分
        |
定向仿真 + lint/elaboration -----> 初版 DC（面积/时序 sanity）
        |                                  |
        +---------- UVM 环境并行 ----------+
                    |
          回归/coverage/scoreboard
                    |
        RTL 修正后重新 DC/功耗/STA
```

对本项目，当前 RTL 和接口已经稳定，先完成 SAIF 映射修正，再搭建 UVM 是合理
顺序。UVM 优先覆盖 AXI-Lite、AXI4 DMA、CMDQ/CPLQ、SPAD arbiter、A2 CNM
四 lane 和 A3 GEMM scoreboard；DC/PPA 则在 UVM 回归期间持续增量运行，不必等
UVM 全部完成才综合。

需要注意：项目早期 A8 run 确实使用过真实 TSMC28 库，证据见
`docs/A8_TSMC28_SYNTHESIS_REPORT.md` 和历史输出目录
`syn/out/tsmc28_a8_4_0ns_20260802/`。本节描述的是 2026-08-06 在新
`/mnt/e` 路径下因环境变量未恢复而产生的无效 run，不否定早期 A8 的真实
250 MHz pre-layout 结果。

## 6. DC/PPA 问题的解决顺序

1. **先修库环境**：获取同一 PVT 的完整 TSMC28 RVT 标准单元 `.db`、SRAM
   macro `.db`，并确认包含 `INVD1BWP7T40P140`、`DFCNQD1BWP7T40P140` 和
   `TS1N28HPCPL2SVTB4096X32M4MWBASO`。不能使用 `gtech.db`、
   `dw_foundation.sldb` 或 `your_library.db`。
2. **再修 link**：重新运行 DC；`reference.rpt` 不应再出现 unresolved
   reference、`gtech`、unmapped logic 或无模型 black-box。脚本现在会在发现
   占位库或缺少 SRAM macro 时直接报错，避免生成 0 面积假报告。
3. **再看面积/功耗**：真实库加载后，`area.rpt` 应有非零 cell/macro area，
   `power.rpt` 应有 V、C、T 和 mW/uW 单位；SAIF 只提供活动率，不能替代工艺库。
4. **最后修时序**：setup 通过后再处理 hold。当前 `-0.02 ns` hold 来自
   pre-CTS min-delay guard 和理想时钟模型；真实库下用 `set_fix_hold` 重新综合。
   仍有 violation 时，根据最短路径插入 hold buffer 或交给 CTS/PD 修复，不能靠
   降低频率解决 hold。
5. **分类处理 tri-state/常量告警**：AXI 常量输出和可选端口可在 lint 中豁免；
   SRAM 宏 A/D 总线告警应由正确的宏 Liberty/Verilog black-box 模型消除。只有
   影响功能或存在 unresolved driver 的告警才需要改 RTL。

在 `dc_shell` 内检查库：

```tcl
list_libs
get_lib_cells */INVD1BWP7T40P140
get_lib_cells */DFCNQD1BWP7T40P140
get_lib_cells */TS1N28HPCPL2SVTB4096X32M4MWBASO
check_library
```

从项目根目录运行：

```bash
cd /mnt/e/workspace/chip/CIMForge
export TSMC28_STDCELL_DB=/home/ray/pdk/TSMC28/standard_cell_rvt/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp7t40p140_180a/tcbn28hpcplusbwp7t40p140tt0p9v25c.db
export TSMC28_SRAM_DB_TT=/home/ray/ic/CIMForge/syn/out/pdk_cache/TS1N28HPCPL2SVTB4096X32M4MWBASO_tt0p9v25c.db
export CIMFORGE_SAIF=$PWD/verif/sim/ai_accel_smoke.saif
export CIMFORGE_SAIF_INSTANCE=ai_accel_top
dc_shell -f syn/dc_ai_accel_28nm.tcl
```

`/真实路径/...` 必须替换为 EDA 环境中的实际 PDK 路径；项目本身无法生成工艺库。

常用命令：

```bash
cd verif/sim
make ai_cnm_a22
make ai_spad_arb_run
make ai_cnm_final_compare
make ai_smoke
make ai_smoke_saif
```
