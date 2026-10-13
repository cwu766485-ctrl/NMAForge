# NMAForge 系统级低功耗设计与验证计划

## 目标与边界

本计划的目标是在不改变 AXI ABI、算子结果、命令生命周期或吞吐周期的前提下，减少
空闲模块和未访问 SRAM bank 的无效翻转。产品 RTL 目前仍是单一 `aclk` 域；本计划
不以低功耗为由拆分时钟域，也不将实验性 CDC FIFO 当作已集成产品功能。

当前已拥有周期匹配的 smoke SAIF 基线。以 TT/0.9 V/25 C、ZeroWireload 的
post-synthesis pre-layout 估算为例，4.0 ns 下动态功耗约 22.49 mW，其中 clock
network 约占 95%。这说明优先级应为：安全 clock-enable/ICG 边界，其次才是
组合逻辑微优化；这不是 CTS、布局布线或 silicon sign-off 结论。

## 分层策略

| 层级 | 本项目立即可做 | 需 low-power kit 后才可做 |
|---|---|---|
| SRAM/数据活动 | 每 bank、每 port 的访问 enable；减少不被请求 bank 的端口活动 | SRAM sleep/retention 的真实 macro 映射 |
| 时钟活动 | 定义安全 clock-enable 契约、以 SAIF 比较优化前后活动 | 映射工艺 ICG cell、CTS clock-gating 检查 |
| 电源域 | 定义 AON/compute/SRAM 的控制协议、隔离与保存恢复接口 | UPF cell mapping、power switch、isolation、retention、power-aware 仿真 |
| 电压/频率 | 单时钟频率与工作负载 PPA sweep | 多电压 level shifter、DVFS 电源状态签核 |

`syn/upf/ai_accel_top_experimental.upf` 仍仅为意图草案；在取得 isolation、retention、
level-shifter、power-switch 的可综合/可时序分析 library view 及 UPF/CPF kit 前，禁止
将任何 UPF、power-domain 或 ICG 结果描述为已实现或已签核。

## 设计顺序

### P0：测量基线（已具备）

1. 用相同 smoke seed 和 `+ACLK_PERIOD_NS` 导出 SAIF。
2. 使用同 PVT、同约束回标 DC，比较 dynamic、leakage、area、WNS/TNS。
3. 每项优化只改变一个变量；没有 matched SAIF 的 vectorless 功耗只作调试参考。

### P1：Scratchpad bank-port activity（首个实现批次）

`ai_scratchpad` 的 XPM Port-B 必须由独立 bank enable 驱动：

- line 或 matrix banked read：四个 bank 都 enable；
- CNM：仅 `cnm_read_valid[i]` 且地址合法的 bank `i` enable；
- scalar/DMA/descriptor：仅 `compute_bank` 对应 bank enable；
- 无 scheduler request：四个 bank 都不 enable。

此批次不改变 registered-read latency、Port-B 仲裁优先级或 VCS behavioral RAM 行为；
它的验收重点是结果、响应掩码和 RAM 访问时序完全等价。该项可减少 FPGA XPM/未来
SRAM wrapper 的无效端口活动，但本身不是 clock-tree gating。

#### P1 执行记录（2026-09-28）

`rtl/memory/ai_scratchpad.v` 的 XPM 分支已将原来共享的 Port-B enable 改为
`portb_bank_enable[3:0]`：line/banked 为 `4'hf`，CNM 由合法 lane mask 决定，
scalar scheduler access 只使能 `compute_bank`。Host Port-A、所有模块端口、行为级
`+define+VCS` RAM、读延迟和 arbiter 均未改动。

在 Rocky-8.10/VCS 中执行：

```bash
cd dv/subsystem/top_smoke/sim
make ai_spad_arb_run
make ai_smoke
```

结果分别为 `CNM/DMA SPAD contention PASS`、`Scratchpad round-robin arbiter PASS` 和
顶层 `TEST PASS`。注意 VCS 编译以 `+define+VCS` 选择行为级 RAM，故它验证了架构
功能不变，但不编译刚改动的 XPM 分支；P1 尚须补一次 FPGA/Vivado XPM 编译或 OOC
综合，才能把该分支也标记为编译验证。

2026-09-28 已检查该 OOC 环境：既有脚本
`fpga/xilinx_a7_100t/scripts/synth_ai_accel_ip.tcl` 的目标为
`ai_accel_top` / `xc7a100tfgg484-2` / `SPAD_WORDS_PER_BANK=4096`，输出目录为
被忽略的 `fpga/xilinx_a7_100t/build/ip_synth/`。但 Windows 与 WSL 均未找到
`vivado`、`vivado.bat` 或 `vivado_lab`；仅有许可证路径不能替代 Vivado 安装，因此
未执行该脚本、也未产生伪造报告。工具安装后应运行：

```powershell
vivado -mode batch -source fpga/xilinx_a7_100t/scripts/synth_ai_accel_ip.tcl
```

并检查 `ai_accel_top_drc.rpt`、`ai_accel_top_timing.rpt` 与 utilization report。

### P2：计算簇 clock-enable 契约

先不直接门控 `aclk`。各引擎先显式导出或内部定义 `wake`、`active`、`quiescent` 的
语义，再由工艺 ICG 或综合 clock-gating 推断使用：

| 子系统 | 唤醒条件 | 可进入 quiescent 的必要条件 | 绝不能停止的阶段 |
|---|---|---|---|
| INT8/CNM/matrix/SFU/CNN/KV | 对应 `start`、`abort` | 无 busy、无 done/error 脉冲、无 pending SPAD response | SPAD wait、watchdog、abort、done retire |
| DMA | start、AXI response、abort | 无 outstanding read/write、无 held valid、非 drain | `VALID&&!READY`、RLAST/BID、abort drain |
| command/completion | submit、doorbell、fetch/done/error | 无队列事务、无四 word completion 未提交 | pointer 更新、completion 原子提交 |
| AXI-Lite/IRQ | 任意 AXI channel 活动、IRQ 事件 | 不适用，保持 always-on | AW/W/AR/B/R 握手、sticky status |

只有证明 `quiescent` 后才可将某子模块的局部 CE 映射为 ICG。不能用 `busy==0` 直接
关整块：许多 FSM 在 idle、done、延迟读响应或 abort 时仍需一个或多个时钟。

#### P2 执行记录（2026-09-28）

计算簇的 `wake / active / quiescent` 契约已在顶层 smoke testbench 中以
`ai_compute_activity_sva` 实例化，并覆盖 INT8、CNM、matrix、SFU、CNN 与 KV：

- `active = wake || busy || done || error`，其余周期为 quiescent；
- quiescent 时不得产生新的 scratchpad request；
- 相邻两个 quiescent 周期必须保持可见的 `cycle_count` 与 `element_count`；
- reset 期间关闭检查。`busy`、done/error、abort、watchdog 与所有 request/response
  handshake 仍由原 FSM 持续驱动，未被门控。

CNM 的最小 activity 优化位于 `ai_bank_local_controller` / `ai_bank_pe`：仅在
`ST_WAIT_B && rsp_valid && !rsp_parity_error`（即原本更新 local accumulator 和
compute-event counter 的同一周期）向 PE 传递真实 operand；其余周期将 PE 的两组
输入隔离为零。没有改变 lane 映射、地址计数、状态机、请求时序或累加宽度。

Matrix 审计确认 operand、accumulator、prefetch buffer 与 writeback 寄存器已经分别
只在 response、`ST_MAC`、prefetch response 与 write handshake 时更新。因此只在
`ai_tensor_matrix_datapath` 的 16 路乘法器输入加入 `state_r == ST_MAC` 的 operand
isolation；`post_scalar/post0..3` 仍在写回周期保持原组合计算。未门控 SPAD wait、
response、watchdog 或 abort 路径。

当前功能证据（Rocky-8.10 / VCS）为：

```bash
cd dv/subsystem/top_smoke/sim
make ai_cnm_a22
make ai_cnm_a2_gemv_bench
make ai_tensor_a3_gemm_bench
make ai_quick
make ai_smoke
```

五项均通过；其中 Matrix benchmark 的 L=16/64/256 结果保持
`mac_active=64/256/1024`，表明 MAC 工作周期未改变。顶层编译仍报告既有的
`TFIPC`（`ai_banked_cnm_core` 有被动监控输出未连接）；它不是本批新增 warning，
但应在独立 lint 清理任务中 disposition。

由于 P3 需要的工艺 low-power kit 尚不可用，先执行不依赖该 kit 的 P4/P5；P3 的
物理 ICG/UPF 实施仍保持在后面、不得提前宣称完成。

#### P4：SFU / DMA 审计（本批不改 RTL）

- SFU 的 divider/sqrt 由 one-cycle `*_start_r` 脉冲启动，`*_WAIT` 状态必须继续消费
  `done/error`；同时 abort、watchdog 与 SPAD response 仍有优先级。因此不对迭代器
  或其等待状态做门控。
- DMA 的 read-slot、write pending-B、`VALID&&!READY` 与 `abort drain` 元数据共同
  维护 AXI 已接受事务的生命周期。任何局部 CE 必须证明不阻断 RLAST/BID 或 drain，
  本批不修改该高风险路径。

#### P5：CNM SAIF/DC 对比（2026-09-28）

对 CNM operand isolation 单独重跑了 4.0 ns fixed-seed smoke SAIF，并以更新后的
RTL 从头执行 DC（不复用旧 DDC）：

```bash
cd dv/subsystem/top_smoke/sim
make ai_smoke_saif ACLK_PERIOD_NS=4.0 AI_RANDOM_CASES=4 AI_SEED=12345 SEED=12345

# Return to the repository root before configuring the synthesis run.
cd ../../../..
# Configure private local PDK paths; library names and paths are intentionally omitted.
export TSMC28_STDCELL_DB="$PDK_PRIVATE_DIR/standard_cells_tt.db"
export TSMC28_SRAM_DB_TT="$PDK_PRIVATE_DIR/sram_macro_tt.db"
export CIMFORGE_SAIF=$PWD/dv/subsystem/top_smoke/sim/ai_accel_smoke_4_0ns_dc.saif
export CIMFORGE_SAIF_INSTANCE=ai_accel_top
export CIMFORGE_DC_RUN_DIR=$PWD/syn/out/tsmc28_4_0ns_saif_cnm_activity_seed12345
bash syn/run_ai_accel_28nm_dc.sh 4.0
```

DC 日志明确报告 `CIMForge DC activity: measured SAIF=... instance=ai_accel_top`。
在同一 TT/0.9 V/25 C、ZeroWireload、4.0 ns pre-layout 约束和 smoke seed 下：

| 指标 | 优化前 | CNM operand isolation 后 | 变化 |
|---|---:|---:|---:|
| dynamic power | 22.8714 mW | 22.5313 mW | -1.49% |
| total power | 24.8483 mW | 24.5014 mW | -1.40% |
| cell area | 1,244,193.24 | 1,241,692.48 | -0.20% |
| critical path | 3.88 ns | 3.87 ns | -0.01 ns |
| setup / hold WNS | 0.00 / 0.00 ns | 0.00 / 0.00 ns | 保持 |

这证明该 workload 下 activity-aware 改动没有性能退化，并有可测的合成功耗估算收益；
但 clock network 仍约占动态功耗 87%，且 DC 的 `check_design` 存在需独立 disposition
的结构提示。因此它是 matched-SAIF 的 pre-layout 比较，不是 CTS、APR、IR/EM 或
低功耗 sign-off 结论。

随后在相同 SAIF/约束下，从包含 CNM 与 Matrix isolation 的最终 RTL 重新综合：

| 指标 | CNM isolation 后 | CNM + Matrix isolation 后 | Matrix 增量 |
|---|---:|---:|---:|
| dynamic power | 22.5313 mW | 22.5273 mW | -0.0040 mW |
| total power | 24.5014 mW | 24.5027 mW | +0.0013 mW |
| cell area | 1,241,692.48 | 1,241,904.35 | +0.02% |
| critical path | 3.87 ns | 3.87 ns | 保持 |

因此 Matrix isolation 保留为已验证、无吞吐/时序退化的活动约束，但该全芯片 smoke
workload 下没有可区分的 PPA 改善；不将它作为功耗数字亮点。原因是 clock network
占动态功耗约 87%，且 Matrix 的原始寄存器更新条件已经很严格。若未来采用 matrix-only
长时间 workload、门级 VCD 或具备真实 ICG/CTS，才应重新评估其局部收益。

#### 2026-09-29 F400 frontier

在同一 TT/0.9 V/25 C、ZeroWireload、0.10 ns uncertainty、pre-layout DC
约束下，使用 `AI_RANDOM_CASES=4`、`AI_SEED=12345` 的 matched-SAIF smoke
活动，对 2.5 ns 和 2.4 ns 周期进行了 F400 frontier 扫描：

| 周期 | SAIF | DC 输出目录 | WNS/TNS | Critical Path Length | cell area | dynamic power | total power | clock power | worst path |
|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| 2.5 ns | `ai_accel_smoke_2_5ns_dc.saif` | `tsmc28_2_5ns_saif_final_seed12345` | 0 / 0 ns | 2.37 ns | 1,245,139.921963 | 35.9927 mW | 37.9677 mW | 34.2889 mW (90.31%) | SRAM bank0 slice5 macro -> `tensor_sfu sum_x_r_reg[62]` |
| 2.4 ns | `ai_accel_smoke_2_4ns_dc.saif` | `tsmc28_2_4ns_saif_final_seed12345` | 0 / 0 ns | 2.28 ns | 1,245,664.907903 | 37.4758 mW | 39.4494 mW | 35.7170 mW (90.54%) | `dma plan_remaining_r_reg[2]` -> `plan_ext_r_reg[63]` |

上述功耗是 matched-SAIF 的 pre-layout 估算；报告仍有 blackbox/unannotated
警告，且 `report_switching_activity` unavailable。因此这些结果不是
post-layout 或 signoff 证据，也不能声称 2.4 ns 或 400 MHz silicon 已获得保证。

### P3：工艺依赖的 ICG / UPF

取得目标库后，按下列顺序实施：

1. 用工艺指定 ICG cell 和门控检查约束映射 P2 的 CE；
2. 先做 AON control + switchable compute，SRAM 是否 retention 由 macro 支持决定；
3. 明确定义 `iso_compute_n`、save、restore、power-good/ack；
4. UPF 静态检查、综合网表 power-aware 仿真、门控时钟/复位/跨域检查；
5. 在相同 SAIF workload 下给出优化前后 PPA，并在 APR 后重新评估。

## 验证规则

每个 RTL 优化都必须先跑对应 focused test，再跑 `make ai_quick` 和 `make ai_smoke`。
DMA、SPAD、top 改动还应在环境允许时运行固定 seed 的顶层随机回归。新增或保持的
断言/覆盖至少包括：

- AXI `VALID && !READY` 下 valid 与 payload 稳定；
- 每个已接受的 SPAD 请求只产生一次对应响应，registered-read latency 不变；
- CNM 每个有效 lane 只消费本 lane 响应一次；
- CMDQ/CPLQ 指针一次命令只推进一次，completion 四个 word 写完才发布 tail；
- idle-to-wake 首次请求、每个 bank enable、wait-state、abort、watchdog 和 back-pressure
  均有覆盖；
- 优化前后固定 seed 的功能日志、完成项、错误码和周期计数按该批次定义比对。

## 完成定义

一个低功耗优化只有在功能回归、协议断言、SAIF/PPA 对比和 `git diff --check` 均通过后
才能保留。无真实 low-power kit 时，只能报告 activity reduction 或 RTL/FPGA RAM-enable
优化；不能报告 physical clock-power saving、power-domain closure 或 UPF sign-off。
