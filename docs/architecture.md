# CIMForge A8 架构说明

## 1. 项目范围

CIMForge A8 是单时钟、可综合的全数字 AI 近存加速器 IP：控制面为 AXI-Lite，
数据主接口为 128-bit AXI4。权威顶层为 `rtl/top/ai_accel_top.v`；可综合 RTL
分别位于 `rtl/control`、`rtl/dma`、`rtl/memory` 与 `rtl/compute`。

它先将 tile、权重和激活搬入靠近计算单元的四 bank scratchpad，再进行 INT8/定点运算，
以减少 DDR 往返。这里的 CNM 是全数字 Compute-Near-Memory：不修改 SRAM bit-cell、
bit-line 或 sense amplifier，不是模拟 CIM/PIM。

## 2. 模块所有权与命令流

```text
CPU -- AXI-Lite --> axi_lite_reg_if --> ai_accel_regs
                                        │配置/doorbell/status/IRQ
                                        ▼
                                ai_command_processor
                              描述符校验/派发/完成排序
                           ┌────────────┴────────────┐
                       desc fetch              completion writer
                           │                         │
DDR <== 128-bit AXI4 ==> ai_axi128_dma <==> ai_spad_arbiter <==> ai_scratchpad
                                                  │唯一调度入口       │4 bank/512 KiB
                                                  ▼                   ▼
                               INT8 / CNM / Matrix / SFU / Conv / KV-cache
```

- `ai_accel_regs` 只保存配置、产生控制脉冲、记录 sticky status/IRQ；不推进队列指针。
- `ai_command_processor` 独占命令生命周期：`CMDQ_HEAD`、`CPLQ_TAIL`、描述符来源选择、
  校验、计算启动和完成排序。软件发布 `CMDQ_TAIL`，并消费后推进 `CPLQ_HEAD`。
- `ai_spad_arbiter` 是 scheduler-side scratchpad 的唯一拥有者。descriptor/completion
  保持控制面优先；scalar/line/banked compute 与 DMA 在数据面 round-robin；禁止顶层 bypass mux。
- `ai_completion_writer` 必须先提交四个 32-bit completion word，才能发布新的 `CPLQ_TAIL`。
- `ai_desc_fetch` 读取片上描述符，`axi_desc_fetch` 读取外部描述符；命令期间来源固定。

## 3. 数字 CNM bank-local 数据路径

对 opcode `0x20/0x21`，`ai_banked_cnm_core` 实例化四个独立的
`ai_bank_local_controller`。每个 bank 拥有地址发生器、A/B 请求和 response-valid lane、
A ping-pong buffer、64-bit local accumulator、Local PE 与事件计数器；partial sum 只在输出边界
送入 Global Reducer。

```text
SRAM bank0 <-> LC0 + PE0 ---> local_acc0 --\
SRAM bank1 <-> LC1 + PE1 ---> local_acc1 ---+--> Global Reducer --> writeback
SRAM bank2 <-> LC2 + PE2 ---> local_acc2 ---+
SRAM bank3 <-> LC3 + PE3 ---> local_acc3 --/
```

A2.2 定向 VCS 已通过：`result=32`、`cycles=13`、`local_acc=12`、`global_reduce=1`、
`reads=24`、`prefetch=8`、`compute=12`、`rsp_wait=0`。CNM admission 支持四条 bank lane
地址/mask；不同 client 之间的细粒度 bank-level arbitration 尚未实现，不能宣称任意访问都无冲突。

A3.1 在 4×4 GEMM tile 中加入 operand 复用和 B response 预取，适合 GEMM、Q/K/V projection、
attention 矩阵乘和 FFN；N=1 VDOT/GEMV 仍优先走 A2。

## 4. 存储和 DMA

当前 profile 使用四个逻辑 bank、总容量 512 KiB 的 scratchpad，提供 host/debug port、一个
arbiter-owned scheduler port，以及 scalar/banked/128-bit line 操作。VCS 使用 `+define+VCS`
行为 RAM；Vivado 使用 XPM；28 nm DC 使用 32 个真实 4K×32 SRAM macro。

`ai_axi128_dma` 是唯一活动 DMA 实现：支持 64-bit 地址、1D/2D/gather/tile、最大 16-beat burst、
4 KiB boundary split、最多四个 tagged read outstanding、ID-aware response 和 abort drain。
应表述为“带 ID 响应关联的 tagged multi-outstanding DMA”；系统级任意乱序和长期压力仍需 UVM/实板证据。

## 5. 计算和 ABI

描述符 ABI 支持 scalar/banked INT8 VDOT、GEMV、GEMM、4×4 tensor GEMM/batched GEMM、
requant、GELU、SiLU、residual、LayerNorm/RMSNorm、Softmax/causal Softmax、Conv3x3
line-buffer 和 KV-cache primitive。ABI v7.2 增加了 PACK_I8 layout bridge，供
`sw/tools/cimforge_mapper.py` 形成真实的 Transformer 微型命令链：

```text
Q/K/V -> QK^T -> causal/row Softmax -> AV -> projection
      -> residual + norm -> FFN -> residual + norm
```

这是 primitive-composed 的 Transformer 微型命令链，不是生产级融合 MHA/decoder 或完整软件框架。

## 6. 当前实测证据与开放门项

| 项目 | 最新结果 | 边界 |
|---|---|---|
| VCS smoke/随机 | `make ai_smoke`、`ai_comp`、`ai_run` 基线通过 | 尚非 UVM coverage closure |
| CNM A1/A2/A3.1 | A2 四 lane PASS；A3.1 benchmark PASS | 受控 workload，需继续 UVM 对拍 |
| XCZU15EG OOC | 100 MHz，setup/hold WNS `+0.187/+0.032 ns` | standalone IP，非整板 sign-off |
| TSMC28 DC | TT/0.9 V/25 °C，4 ns；setup/hold 0 violation，关键路径 3.89 ns | 单角 pre-layout |
| 面积 | `1,245,378.649905` library units；SRAM `1,127,675.75` | 非物理版图面积 |
| 功耗 | dynamic 22.829 mW、leakage 1.9733 mW | PWR-414/415/428，非 SAIF sign-off |
| SpyGlass lint | 0 error、414 warnings、4 info | warning 待分类 |
| SpyGlass CDC/RDC | 0 unsync crossing/0 convergence；CDC 1、RDC 2 license errors | 缺 Advanced_CDC/rdc_adv_checker |

当前可信表述是“TSMC28、250 MHz pre-layout setup/hold closure”。Formal、LEC、DFT、UVM、
后布局 STA/功耗和实板长期压力测试仍未完成，详见 [`VPLAN.md`](VPLAN.md)。

## 7. 下一步

当前 RTL 是完整的 pre-verification baseline。下一步冻结 SPEC/ABI 后开始 UVM：先实现 AXI-Lite
agent + RAL、CMDQ/CPLQ scoreboard，再接入 AXI4 DMA、scratchpad arbiter、CNM 四 lane 和
Transformer reference model；Formal、LEC、DFT 与增量 DC/SpyGlass 并行推进。
