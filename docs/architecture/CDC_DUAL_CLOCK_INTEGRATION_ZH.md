# 双时钟 Command/Completion CDC 集成契约

## 目的与范围

本文件定义从当前单时钟 `ai_accel_top` 演进到 `ctrl_clk` / `compute_clk`
双时钟实现时的边界。它不是当前已集成产品功能：截至 2026-09-29，
`ai_accel_top` 仍使用单一 `aclk` 和 `aresetn`，
`rtl/control/cdc/ai_ctrl_compute_cdc.v` 仅为已验证的 FIFO 原型。

目标是让控制面在 `ctrl_clk`，而 command processor、descriptor fetch、
DMA、scratchpad、completion writer 和计算引擎在 `compute_clk`。外部 AXI4
先保持 `compute_clk`，不额外引入 DDR 时钟域。

## 不变的所有权

- `ai_command_processor` 继续是 command 生命周期、`CMDQ_HEAD` 和
  `CPLQ_TAIL` 的唯一 owner。
- `ai_completion_writer` 必须在 compute 域写完一条 completion 的四个
  32-bit word 后，才能由 command processor 发布新的 `CPLQ_TAIL`。
- `ai_spad_arbiter` 仍是 scheduler-side scratchpad 的唯一 admission point。
- `ai_accel_regs` 只保留软件配置、AXI-Lite 协议和控制域可见状态；它不能
  在控制域复制 command FSM 或 queue pointer。

## CDC 包定义

### 控制域到计算域：command snapshot

`submit`、`direct_start`、`tile_start` 不能作为独立异步脉冲。控制域先把
所有相关配置锁存为一个不可变 snapshot，再以单个 FIFO entry 提交。最小字段为：

| 类别 | 字段 |
|---|---|
| 控制 | abort、submit、direct_start、tile_start |
| CMDQ | base[63:0]、size、tail、external、head load/seed |
| CPLQ | base、size、head、protection、tail load/seed |
| Direct | op、src0/src1/dst、length/m/n/k、shift、activation、bias base/enable |
| Tile | count、输入/输出 64-bit base、stride、双 buffer base、output offset、输入/输出 words |

上述净荷约 840 bit；第一版实现固定为 **1024-bit packet**，预留
version、sequence/tag 和 reserved 字段。这样可防止新地址与旧尺寸等多位总线
被分开采样。后续可优化为 shadow-register + req/ack，但仍必须满足一次 commit
对应一个原子快照。

`abort` 需要单独定义语义：若要求低延迟，应通过专用 async abort handshake
发送，并由 compute 域确认；若随 snapshot FIFO 排队，则必须在软件 ABI 中明确其
可见延迟。第一版不得将它直接两级同步后驱动 DMA/engine abort。

### 计算域到控制域：completion/event

compute 域向控制域发布的 packet 至少包含：

```text
event_valid, event_error, event_error_code[3:0]
event_result[31:0], event_cycles[31:0], event_elements[31:0]
cmdq_head[31:0], cplq_tail[31:0], dependency_events[15:0], busy
```

净荷约 183 bit；第一版固定为 **256-bit packet**，带 sequence/tag。只有在
completion writer 已完成且 command processor 已更新 `cplq_tail` 后才可生成
该 event。控制域将它用于状态、IRQ 和软件可见 readback，不反向拥有 pointer。

## 禁止的跨域方式

以下项目不可直接连线或仅用两级同步器：多位配置总线、submit/direct/tile/abort
脉冲、queue pointer、launch/fetch/completion 握手、DMA/AXI valid-ready/ID/LAST、
scratchpad request-response，以及 descriptor 的多字段返回。

## 分阶段实施与验收

1. 新建独立双时钟 integration shell，保持现有单时钟 `ai_accel_top` 不变。
   当前 `ai_accel_dual_clock_command_path` 已将 shell compute 端接到真实
   `ai_command_processor` 与 `ai_completion_writer`；它仍是独立 integration
   path，尚未替换产品 top。
2. compute 域以 `ai_cdc_event_buffer` 将 processor 的单周期 event 转为
   ready/valid。新 command 仅在 processor idle 且前一事件已进入 reverse FIFO
   时接收；无 launch 的配置更新与 abort 可在 busy 时通过，因此 `CPLQ_HEAD`
   不会被长计算阻塞。
3. 为 1024/256-bit 包增加 pack/unpack、sequence、overflow/underflow 和 reset
   contract；不要让 FIFO 写满时静默丢任务。
4. 用独立的异步 `ctrl_clk` / `compute_clk` testbench 验证随机频率比、随机 reset、
   queue back-pressure、abort、连续 completion 与 IRQ 事件。
5. 更新 filelist、SGDC 中的两个 clock/reset intent，运行 CDC UVM、SpyGlass CDC
   和分层 RDC；RDC 资源受限时必须保留 final-summary 缺失的状态。
6. 只有 ABI、focused test、top smoke 和静态检查均通过后，才评估以双时钟 shell
   替换产品入口。

## 当前验证事实

- CDC FIFO directed、随机/SVA、五项 block UVM 及 URG merge 已通过。
- 新增 `ai_accel_dual_clock_shell` 与字段级异步双时钟 TB；它覆盖 1024-bit
  command snapshot、256-bit completion/event、随机背压及 reset flush 后的新 epoch。
  可复现入口为 `cd dv/block/cdc/sim && make shell_run`。该新 TB 必须在具有
  VCS 的环境中实际 PASS 后，才能作为 runtime evidence。
- dedicated SpyGlass 入口为 `./run_spyglass_a8.sh dual_cdc`；它使用
  `cdc_dual_clock.prj` 与 `cdc_dual_clock_constraints.sgdc`，不会修改单时钟
  `ai_accel_top` 的 SGDC。
- 2026-09-29 首次 command-path VCS compile 成功，但 TB 的 producer 被错误地
  纳入 `join_any`，在 command 入 FIFO 后即提前结束；该 run 不构成功能 PASS。
  同日首次 dual-clock CDC 将 1024x16 FIFO 因默认 `mthresh=4096` black-box，
  由此产生 115 条伪 `Ac_unsync01` crossing。TB 等待结构和 project 的
  `mthresh=32768` 已修正，必须重跑后再判定 CDC 结果。
- 2026-09-29 SpyGlass `cdc_setup` 与 `cdc_verify_struct` 对当前单时钟 top
  通过，均为 0 error / 0 warning。
- 同日全顶层 RDC 在 `Ar_resetcross01` 期间使用约 14.7 GiB RSS 后被 WSL OOM
  killer 终止；这不是 RDC PASS。完整状态见
  `docs/verification/RDC_STATUS_ZH.md`。
