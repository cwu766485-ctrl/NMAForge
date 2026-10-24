# NMAForge 混合精度扩展规格（BF16/FP16 Dot）

> 本文冻结 BF16/FP16 点积的数值与 ABI 契约。当前功能、形式与覆盖率状态见[混合精度验证状态](../verification/COMPUTE_ENGINE_STATUS.md)及 [A10 RTM](../verification/A10_DV_RTM.md)；历史精确运行数据保留在对应的 dated run record。
> A8 / ABI v7.2 与 A9 / ABI v7.3 均为历史兼容版本，其能力以 `SPEC_ZH.md` 为准。

## 1. 产品点积功能

产品提供两个单通道操作：`BF16_DOT_ACC_FP32`（opcode `0x50`）与
`FP16_DOT_ACC_FP32`（opcode `0x51`）。它们从 scratchpad 读取两条 packed
16-bit 输入向量，按递增元素序号逐项相乘，并将每步结果顺序累加到 FP32；
最终写回一个 32-bit FP32 原始位型。两种格式共用一个混合精度点积核心、
命令生命周期、scratchpad arbiter 与 completion writer；格式在命令开始时锁存，
不会增加 DMA 或 scratchpad 私有通道。

乘法器将 BF16/FP16 乘积直接生成为精确的 FP32 表示（有限值乘积可由 FP32
精确承载），累加器每一步执行一次 RNE FP32 加法；不做 FMA，也不重排归约。
该扩展不改变现有 INT8、CNM、Matrix、SFU 的数值语义。BF16/FP16 加减仍只是
独立算术 block，不属于产品 command opcode。

## 2. 原始位型和数值规则

| 格式 | sign | exponent | fraction | 规范 quiet NaN |
|---|---:|---:|---:|---|
| BF16 | 1 | 8 | 7 | `16'h7fc0` |
| FP16 | 1 | 5 | 10 | `16'h7e00` |
| FP32 | 1 | 8 | 23 | `32'h7fc00000` |

- 所有支持的算术使用 round-to-nearest, ties-to-even（RNE）。支持渐进下溢；
  不启用 flush-to-zero 或 denormals-are-zero。
- 必须区分 `+0` 和 `-0` 的原始位型。算术采用 RNE 下的零符号规则；
  golden model 与 DUT 逐位比较，不能把两种零统一为相等。
- 乘法结果为零时，符号等于两个输入符号异或。加减先按 `subtract` 控制
  翻转第二操作数符号；两个 `-0` 相加得到 `-0`，其余 RNE 下的精确零和
  （包括非零数相消）得到 `+0`。
- 输入的 qNaN 或 sNaN 均产生对应输出格式的上述规范 quiet NaN；
  无效算术（如 `0 × Inf` 或 `+Inf + -Inf`）也产生规范 quiet NaN。
  P0 不保留输入 NaN payload，不输出 IEEE exception flags；
  NaN/Inf/overflow/underflow 是数值结果，不自动转成命令错误。
- BF16/FP16 加减 block 的输出与输入格式相同。具体减法控制位在
  产品 opcode 集成前冻结；block 接口先显式使用 `subtract` 输入。

### BF16 dot 的逐步舍入

对于 `length` 个元素，初始累加值为 FP32 `+0`。第 `i` 步为：

```text
a32 = exact_bf16_to_fp32(A[i])
b32 = exact_bf16_to_fp32(B[i])
p32 = round_RNE_FP32(a32 * b32)
acc = round_RNE_FP32(acc + p32)
```

按 `i = 0 .. length-1` 的顺序推进，禁止把乘加合并为一次 FMA 舍入；
任何并行 lane 或重排归约都必须另立模式和 golden 契约。每步算术的
NaN 结果使用上面的规范位型。参考模型需要按 FP32 逐步运算，不能用
宿主 `double` 完成整个 dot 后只舍入一次。

### FP16 dot 的逐步舍入

FP16 输入先按 IEEE binary16 解码。每个有限 FP16×FP16 乘积在 FP32 中精确
表示；随后每个乘积按元素序号依次与 FP32 累加器相加，并对每次加法单独
执行 RNE：

```text
p32 = exact_fp16_product(A[i], B[i])
acc = round_RNE_FP32(acc + p32)
```

特殊值和无效算术遵从本节的规范 NaN/Inf/zero 规则。不得把乘加折叠为 FMA，
也不得为了并行化而改变加法顺序。

首批人工可审查向量（hex 均为原始位型）：

| 运算 | 输入 | 期望输出 |
|---|---|---|
| BF16 dot | A=`3f80,4000`，B=`4040,4080`（1×3 + 2×4） | FP32 `41300000`（11） |
| FP16 dot | A=`3c00,4000`，B=`4200,4400`（1×3 + 2×4） | FP32 `41300000`（11） |
| BF16 dot | A=`0001`，B=`3f80`（最小 BF16 subnormal × 1） | FP32 `00010000` |
| BF16 dot | A=`0000`，B=`7f80`（0 × +Inf） | FP32 `7fc00000` |
| BF16 add block | `3f80 + 3b80`（1 + 半个 BF16 ULP） | BF16 `3f80`（RNE tie） |
| FP16 add block | `3c00 + 1000`（1 + 半个 FP16 ULP） | FP16 `3c00`（RNE tie） |

这些向量只作为规格 sanity check，不替代独立 oracle、随机测试或
NaN/零符号/溢出/取消抵消等完整 corner-case 集合。

## 3. Scratchpad 布局和边界

- 地址为 byte address；`src0`、`src1`、`dst` 至少 4-byte 对齐。
- 32-bit 小端 word 的低 16 位放偶数序号的 BF16/FP16 元素，高 16 位放
  下一个奇数序号元素。`length` 单位是元素，不是 32-bit word。
- 读入 word 数为 `(length + 1) / 2`。当 `length` 为奇数时，最后一个
  word 的高 16 位不参与运算，不能触发额外结果。
- dot 的 `dst` 占一个 32-bit word，按小端写入 FP32 原始位型；
  completion 的 result word 同样记录该原始位型，element count 为 `length`。
- 后续 BF16/FP16 向量加减若写 packed 输出，奇数尾元素所在 word 的高
  16 位写零。该模式写完整 32-bit word，不做隐式 read-modify-write。
- P0 使用连续向量；FP dot descriptor 中非零 stride、bias enable、
  activation、transpose、batch/head 扩展字段均视为非法，不能静默忽略。
- 所有 SPAD 请求仍经 `ai_spad_arbiter` 的现有 32-bit `core_*` 计算端口。
  当前 `ai_scratchpad` 的 scheduler 读数据为两级寄存路径，仲裁器也按
  两周期对齐 response。FP 适配器每周期至多提出一个新请求，使用两个
  operand-pair buffer 保持最多两笔已接受但未返回的读请求，并依请求顺序消费
  `rsp_valid/rsp_client` 响应；该接口没有可用于重排的 read ID。适配器必须等待
  `ready` 接收。A/B word 顺序读取并缓冲；仲裁等待会
  延长实际间隔，因此不可预设每周期双操作数吞吐。新引擎只接入现有
  arbiter，不另加 SRAM 旁路；该 core 端口由当前被派发的唯一计算引擎使用。

## 4. ABI 与兼容原则

| 项目 | 当前 ABI 契约 |
|---|---|
| BF16 opcode | `8'h50`：`BF16_DOT_ACC_FP32`，保持既有 ABI 语义 |
| FP16 opcode | `8'h51`：`FP16_DOT_ACC_FP32` |
| BF16/FP16 add/sub | 仅为独立 block；尚无产品 opcode 分配 |
| 描述符尺寸 | 保持 64 字节和已有 v7 字段位置 |
| 完成项尺寸 | 保持 16 字节和四 word 原子提交规则 |
| 能力发现 | `CAP2[6]` 为 BF16 dot；`CAP2[7]` 为 FP16 dot |
| ABI 版本 | A10 使用 ABI 7.4；旧 ABI 7.2/7.3 descriptor 的既有语义不变 |
| 产品 revision | A10：`VERSION=32'h1000_000a`；A8/A9 历史值不变 |

当前 A10 报告 `VERSION=0x1000_000a`、`ABI_INFO={completion_bytes=16,
descriptor_bytes=64, ABI_minor=4, ABI_major=7}`、`CAP2=0xff`；`CAP2[6]`
代表 BF16 dot-to-FP32，`CAP2[7]` 代表 FP16 dot-to-FP32。A9 历史值为
`VERSION=0x1000_0009`、ABI 7.3、`CAP2=0x7f`；A8 仍为
`VERSION=0x1000_0008`、ABI 7.2、`CAP2=0x3f`。ABI major 7、64-byte descriptor
和 16-byte completion 均保持不变。

`0x50` 与 `0x51` 使用现有 v7 64-byte descriptor，字段约定如下：word1/2 为
`src0/src1`，word4 为 `dst`，word5 的 M/N 均为 1，word6 为所选格式的元素数
`length`，word15 的 version 为 7。word3 bias address、word7 flags、word8
aux0、word9 postprocess、word10–13 strides/batch/head 必须为零；word14
wait/signal event 与 word15 高 16-bit clear mask 沿用现有 command 语义。
三处地址按 32-bit 对齐，读写越界由既有 protection 路径报错。这样可以在
validator 中明确拒绝当前 opcode 不支持的 bias、transpose、activation、
stride 和 batch/head 字段，避免静默忽略。

当前 opcode `8'h50` 与 `8'h51` 已分别接入软件头文件、`ai_accel_opcode_decode`、
`ai_descriptor_validator`、direct-register 和 queue descriptor 路径、compute
cluster、寄存器 capability/version、测试和文档。`8'h51/8'h52` 仍仅为后续
候选且未实现时必须保持非法。A8 软件应先读取版本/capability；旧硬件不声明
对应 capability，旧 A8/A9 软件不得据此假设支持 `0x51`。

## 5. 事务与异常契约

- 一个有效命令最多启动一个 FP engine 生命周期；旧标量 INT8 核不能被
  FP opcode 的“其他类别默认分支”误启动。
- `start` 只在空闲时接受；`busy` 覆盖数据读取、算术和写回直到提交结束。
  完成信号按现有计算簇/命令处理器约定发布，不重复推进 CMDQ/CPLQ 指针。
- `abort`、reset 或保护/奇偶校验错误停止后续 SPAD 请求，按现有
  command processor 错误路径收尾；旧请求的注册读响应不得被当作新命令数据。
- 最终写回的 commit point 是进入 `ST_WRITE` 并提出最终 SPAD 写请求：请求
  一旦提出不可撤销；若 `ready` 未到，valid、地址、数据和写使能必须保持
  稳定直到握手。握手成功后报告成功（除 SPAD protection error），不能被
  随后到达的 abort/watchdog 改判为取消。commit point 前的 abort/watchdog
  仍可取消命令。
- 写回握手成功后才能报告 `done`；不得重复写回或提前发布 completion。
- Block 验证对数值进行 bit-exact 对拍；子系统验证逐地址比较 SPAD/DDR
  的全部有效输出 word，并核对 completion exactly once 与错误归因。

## 6. 阶段验收记录

1. DMA UVM 11/11、Control UVM 6/6、top smoke `TEST PASS`；运行环境、
1. 基线与当前验证缺口见[混合精度验证状态](../verification/COMPUTE_ENGINE_STATUS.md)和 [A10 RTM](../verification/A10_DV_RTM.md)。
2. 历史 A9 冻结 `0x50 BF16_DOT_ACC_FP32` 与 ABI 7.3；当前 A10 保留 `0x50`，
   新增 `0x51 FP16_DOT_ACC_FP32`、ABI 7.4 和 `CAP2[7]`；descriptor 字节布局不变。
3. 独立 Python raw-bit model 使用 `Fraction`/整数 RNE，不依赖 Python float；
   五条规格 sanity vector 与 special、tie、subnormal、overflow 和随机有限值
   共 16 项单元测试通过：`cd dv/block/compute/fp/model && PYTHONDONTWRITEBYTECODE=1 python3.12 -m unittest -v`。
4. 静态核实 `ai_scratchpad`/`ai_spad_arbiter` 两级读响应，确定 A/B
   顺序读取、arbiter ready/response 以及保护错误路径；cluster 的默认 INT8
   dispatch 风险已登记到执行计划。

G0、G1、G2 均已关闭。G2 的当前验收证据：

1. `make -C dv/block/compute/fp/sim dot-core-test` 通过，含 request-stability SVA
   和 stalled writeback 期间 abort 的 commit-point test。
2. Top smoke 检查 A10 VERSION/ABI/CAP2、BF16/FP16 `1×3 + 2×4 = 11`
   (`0x41300000`)、非法 descriptor/direct config 拒绝，并保留旧 Transformer/random。
3. `make -C dv/subsystem/top_smoke/sim ai_smoke`、
   `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345`
   和 `make -C dv/block/cdc/sim command_path_run` 均通过；最后一项汇总
   `commands=2 launches=2 events=2 completion_words=8 errors=0 overflow=0`。
4. A10 增加 directed DDR→DMA→SPAD→queued FP16→SPAD→DMA→DDR 闭环，结果 word 与
   completion 均为 `0x41300000`；`ai_run AI_RANDOM_CASES=20 AI_SEED=12345` 同样 PASS。
   Mixed UVM 三 seed 与 URG merge 已通过：每 seed 582/582，包括 536 数值和 46 fault/reset
   事务；覆盖忙时忽略第二次 start、随机有序 response latency、watchdog 边界、两笔 outstanding
   read、late protection prefix、late protection/abort 优先级及握手前 abort。request-stall SVA 为
   34,928 attempts/10,761 real successes/0 failures。`state_r` 5/5 states、10/10 transitions；
   `pending_error_r` 10/18 transitions。DUT line/condition/branch/FSM 为
   97.96%/96.50%/92.86%/71.43%；非法状态注入通过，剩余 branch/condition/error-FSM outcomes 均已
   逐项 disposition，无 URG exclusion（未做形式不可达证明）。详细数字见 A10 baseline 与 RTM。
5. 运行环境为 Rocky-8.10 WSL / VCS V-2023.12-SP1，工作区 dirty。无新增 FP PPA；
   本页不声称 G3 已闭合或 sign-off。
