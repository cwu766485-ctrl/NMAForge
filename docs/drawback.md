# CIMForge 当前短板与整改状态

> 2026-07-29 RTL 整改：原 32-bit 多模式 DMA 与 128-bit single-beat DMA
> 已收敛为单一 `ai_axi128_dma`。统一后端支持 1D、2D、gather、tile、
> 最多 16-beat 的 128-bit burst、4 KiB 切分和最多四笔 tagged read burst。
> scratchpad 数据面仲裁也已由固定优先级改为 round-robin。随后又加入
> 128-bit scratchpad line 通路、矩阵 row 写回、64-bit external address 和
> ABI v7。下面第 4、5、8、9、10 项已经完成设计整改。2026-07-29 已在
> Linux/VCS 环境通过 `make ai_upgrade_vcs`，A8 的 `make ai_transformer` 与
> `make ai_smoke` 也已 `TEST PASS`。XCZU15EG standalone OOC 在 100 MHz routed
> 闭合（setup/hold WNS=+0.187/+0.032 ns）。仍缺 A8 的28 nm DC PPA 复跑。

目前最严重的短板
1. 功能面可能过宽

你的项目一次覆盖：

DMA
Queue
GEMM
CNN
Softmax
LayerNorm
GELU
SiLU
KV-cache
Macro descriptor
Protection
Performance counters

这是优点，也是危险信号。

面试官会怀疑：

6,491 行 RTL 是否真的足够把这么多模块都做深？

例如 Softmax、LayerNorm 和 GELU 都不是简单模块。你必须给出：

数值格式；
近似方式；
最大误差；
corner case；
latency；
throughput；
reference model；
error bound；
关键路径；
面积。

否则这些功能容易被判断为“做了接口，但实现较浅”。

2. 缺乏端到端模型工作负载（整改中）

目前规格里主要是 operation-level 测试，未展示：

ResNet；
MobileNet；
Transformer block；
TinyLLM；
attention layer；
token/s；
image/s；
TOPS；
MAC utilization；
DDR bandwidth；
arithmetic intensity。

此前只能证明：

各 primitive 可以工作。

还没有充分证明：

一个真实神经网络可以高效地映射并执行。

本轮已经增加由 mapper 生成的 30-command Transformer 微型链，覆盖 Q/K/V、
QK^T、逐行 Softmax、AV、输出投影、两组 Residual/LayerNorm 和
GEMM/GELU/GEMM FFN。为让中间结果真正被后级 GEMM 消费，还增加了 PACK_I8
layout bridge。所有 destination 先填 poison pattern，mapper 还会检查每条命令的
输入区间必须已由常量或前序命令生产，避免预填 golden 或断裂数据依赖造成假阳性。
软件 reference/mapper 自检、A8 `make ai_transformer` 与完整 `make ai_smoke`
均已通过。

该 workload 规模只有 4 token、hidden size 4、单 head，因此解决的是“能否真实
端到端组合”的问题，尚不能替代真实模型的 token/s、DDR bandwidth 和利用率报告。

3. ~~没有 compiler 或 tensor mapper~~（轻量 mapper 已实现）

文档明确说明不包含：

compiler；
graph partitioner；
automatic tensor mapper。

这不是致命问题，校招项目不必自研完整编译器。

本轮实现了一个小而真实的软件层：

Tensor layout converter
Descriptor generator
Golden result checker

`sw/tools/cimforge_mapper.py` 已承担 scratchpad allocation、tensor layout、
descriptor generation、数据流闭环检查和 golden result generation；生成的
fixture 由 VCS harness 写入 command queue，并检查 completion、最终 tensor 和
matrix active cycle。它不是通用图编译器，也还不是 Linux kernel/userspace
driver，但已经消除“所有 descriptor 全靠手写”的主要求职风险。

4. ~~宽 DMA 的 burst 利用率仍有限~~（RTL 已整改）

旧版 tagged 宽 DMA 虽然支持多笔 outstanding，但每笔是：

single-beat 128-bit AXI transaction

这意味着它没有充分利用 AXI burst。

四笔 outstanding single-beat 能隐藏部分 latency，但会增加：

AR/AW channel 开销；
interconnect transaction 数；
DDR controller command 开销；
address handshake 压力。

本轮已经实现：

最多 16-beat 的 128-bit burst
+
outstanding burst tracking
+
4 KiB split
+
tail handling

并将 1D、2D、gather 与 tile 收敛到同一后端，旧的两套 DMA RTL 已删除。
定向 DMA 与 AI smoke 已通过；当前剩余工作是 FPGA timing/utilization 和 28 nm
ASIC PPA 检查，确认新 burst buffer 没有带来不可接受的面积或关键路径代价。

而不只是继续增加更多 compute opcode。

5. ~~固定优先级存在饥饿风险~~（RTL 已整改）

旧版仲裁顺序：

descriptor
completion
scalar compute
banked compute
DMA

DMA 最低优先级。

如果上层计算或 descriptor 持续请求，DMA 可能长期得不到服务。你文档也明确说明尚未实现 fairness/QoS。

面试官会问：

是否可能 starvation；
最大等待延迟是多少；
为什么 DMA 排最低；
completion 是否必须高于 compute；
是否需要 round-robin；
是否需要 aging；
real-time workload 如何保证 QoS。

本轮保留 descriptor、completion 的控制面严格优先级，同时把 scalar compute、
banked compute、DMA 三个数据面客户改为 round-robin。持续数据面流量下 DMA
不会永久饥饿。尚未实现可编程 QoS、aging 或实时最大延迟合同，因此这些仍属于
后续产品化能力，而不是当前已宣称完成的功能。

6. 验证缺少 closure 证据

目前测试场景很多，但规格未给出：

code coverage 数字；
functional coverage 数字；
assertion coverage；
coverage closure；
regression seed 数量；
bug count；
bug taxonomy；
formal property；
lint/CDC/RDC；
X-propagation；
mutation testing。

因此项目 2 目前是：

功能验证覆盖面看起来较广。

还不能严谨地称为：

已完成企业级 DV sign-off。

7. FPGA 流程不可复现（standalone IP 流程已恢复，板级闭环仍缺）

这是当前必须优先修复的工程缺口。

你的项目已经有：

RTL；
FPGA source list；
历史 bring-up 记录。

本轮已恢复 XCZU15EG standalone IP 的 Vivado batch Tcl，可执行
synth/place/route 并生成 timing、utilization、power 和 DRC 报告。仍然缺：

block design；
address map；
bitstream 脚本；
BSP；
bare-metal build；
programming；
test procedure；
expected log。

项目交付最基本的要求之一是：

clean clone
→ 一条命令构建
→ 生成 bitstream
→ 编译软件
→ 下载运行
→ 输出 PASS

在恢复这个闭环前，历史实板结果只能作为辅助证据。

8. ~~scratchpad 内部带宽与 AXI 宽度不匹配~~（RTL 已整改）

旧实现虽然 AXI 数据宽度为 128 bit，但 DMA 每收到一条 external line，仍要拆成
四次 32-bit scratchpad transaction；矩阵 4x4 tile 也要执行 16 次 scalar
result write。外部总线加宽并不能等比例转化为片上有效带宽。

本轮给四个 32-bit bank 增加一条原生 128-bit line read/write 通路。满足
16-byte 对齐且剩余至少四个 word 时，DMA 每拍向 scratchpad 提交一条 line；
矩阵核对 16-byte 对齐的输出 row 只提交一次 line write，因此每个 4x4 tile
的写回请求从 16 次降为 4 次；仅满足 4-byte 对齐时自动回退 scalar write。
scalar、banked 和 line 仍复用同一组 SRAM Port-B，面积上没有复制四套存储端口。

定向仲裁与完整 AI smoke 已通过。剩余边界：非 16-byte 对齐的前后缀仍走 scalar；
同一物理 Port-B 上的竞争仍会降低持续带宽；还没有独立 load/store queue、bank
conflict predictor 或可编程 QoS。

9. ~~矩阵数据流搬运/计算重叠不足~~（RTL 已整改一阶段）

矩阵核原有一项 A/B operand 预取缓冲，可在当前 K-group 的四个 MAC lane 执行时
抓取下一组 operand；tile pipeline 原有 ping-pong scratchpad buffer，可重叠不同
tile 的 DMA 和 compute。本轮保留这两级 overlap，并把结果写回升级为四条
128-bit row transaction，减少 output drain 占用 scheduler 的周期。

这不是商用 NPU 级的完整 tensor dataflow：阵列仍是固定 4x4，只有一项 operand
look-ahead，没有多级 load/store queue、weight-stationary systolic forwarding
或跨命令动态调度。因此对求职项目可以客观表述为“具备双缓冲和局部预取”，不应
宣称已经实现大规模乱序 tensor scheduler。

10. ~~ABI 与系统地址接口含义不一致~~（RTL 已整改）

旧版 `CMDQ_BASE_HI` 只保存不使用，DMA、tile 和 AXI master 地址均为 32 bit；
descriptor 版本又随 engine 分成 v3/v4/v5，错误码没有标明来源。

本轮完成：

- AXI AR/AW、external CMDQ、direct DMA 和 tile external base 全链路 64 bit；
- `CMDQ_BASE_HI`、`DMA_EXT_ADDR_HI`、`TILE_EXT_IN_HI`、`TILE_EXT_OUT_HI`
  进入真实地址计算；
- AXI `CACHE/PROT/QOS/LOCK` sideband 显式输出固定值；
- 新增 `ABI_INFO`、`CAP2`、`ERROR_INFO`；当前 A8 定义 ABI 7.2、能力位和错误来源；
- descriptor v7 对所有 opcode 统一有效，旧 v3/v4/v5 继续兼容；
- v7 macro 用 `{word2, word1}` 携带 64-bit external child descriptor base。

completion queue 仍明确位于 scratchpad，因此 `CPLQ_BASE_HI` 仅保留兼容性，
不应被软件解释为 external completion queue。计算 tensor 地址仍是 32-bit
scratchpad-relative address，这属于本地 SRAM ABI，不是 external address 截断。
