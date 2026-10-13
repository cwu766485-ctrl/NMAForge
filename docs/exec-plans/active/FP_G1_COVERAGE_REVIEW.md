# G1 浮点算术块定向覆盖审查

日期：2026-10-13
范围：G1 的 BF16 乘法、FP32 加法/顺序累加、BF16/FP16 加减 block。
性质：这是对已生成并通过独立 raw-bit oracle 对拍的定向输入类别做人工审查；不等同于 VCS covergroup、URG 功能覆盖率或 RTL code coverage。

## 定向数值类别

| Block | 已审查并由 directed 向量明确覆盖的类别 | 通过证据 |
|---|---|---|
| BF16×BF16→FP32 | 普通正/负乘积；`+0/-0` 及符号异或；BF16 最小/最大 subnormal；FP32 gradual underflow；RNE half-way 偶数/奇数；FP32 最小 normal 边界；overflow；`±Inf`；`0×Inf` invalid；qNaN/sNaN 与符号/payload 输入 | 32 条 directed + 10,000 seeded random；`FP_BF16_MUL_FP32_PASS vectors=10032` |
| FP32 加法 | `±0` 组合与 RNE 零符号；相消；有限数与 `±Inf`；`+Inf + -Inf` invalid；qNaN/sNaN；subnormal 累加、normal/subnormal 边界；even/odd tie、tie 下方/上方；overflow | 36 条 directed + 100,000 seeded random；`FP32_ADD_PASS vectors=100036` |
| FP32 顺序累加 | clear/reset、idle hold、clear 优先；逐步舍入 tie 链；`±0`、正负相消；`±Inf` 冲突、NaN canonicalize；subnormal/normal 边界与 overflow；random chain 每 64 步重新 clear | 22 个 directed 累加输入及控制序列 + 100,000 seeded random；`FP32_ACCUM_PASS vectors=101595`；三项 temporal SVA 全程无失败 |
| BF16/FP16 加减 | 两格式分别覆盖 even/odd tie、tie 邻近值、subnormal/normal 边界、渐进下溢、相消、overflow、signed zero、`subtract`、Inf 冲突、qNaN/sNaN | 每种格式 16 条 directed + 50,000 seeded random；`FP16_BF16_ADDSUB_PASS vectors=100032` |

每条 directed/random 结果均与 `dv/block/compute/fp/model/fp_reference.py` 的整数/Fraction raw-bit oracle 对比；没有使用浮点 tolerance。

## 控制 SVA

当前仅有状态的 FP32 accumulator 配置了独立 temporal checker：

- 同步 `clear` 优先于 `accumulate`，并在下一采样点观察到零；
- `accumulate && !clear` 后，下一采样点等于此前累加值和 `product_bits` 的 FP32 add 结果；
- 无 clear/accumulate 时保持 accumulator 值。

BF16 multiplier、FP32 adder、BF16/FP16 addsub 均为组合算术 block，不含 valid/ready 协议或状态寄存器；它们的本阶段检查是数值对拍，不虚构 protocol SVA。

## 尚未覆盖/不能宣称的内容

- 没有 VCS functional covergroup 或 URG cover report，所以没有 coverage 百分比、cross coverage 或 code coverage 结论。
- 没有产品 compute engine 的 ready/valid、SPAD backpressure、abort/drain、reset-with-outstanding 事务；这些属于 G2/G3。
- FP-only SpyGlass profile 修正后复跑为 0 errors、16 warnings。W216（整数 `exponent_field` 的 `[7:0]` range select）已通过将范围限定的字段改为 8-bit 消除；W528（未读 `sticky` 临时变量）已删除 dead temporary。改动后 BF16 multiply 与 FP32 add focused 回归分别通过 10,032/100,036 vectors。
- 剩余 16 条 W415a 都是组合 `always @*` 中临时值多次 blocking assignment：FP32 add 的 `small_ext`、`work_ext`/归一化循环、`rounded_sig`、`result_bits`（8 条）；共享 BF16/FP16 addsub core 的 `small_ext`、`result_sign`、`work_ext`/归一化循环、`rounded_sig`（每个 wrapper 4 条，共 8 条）。这些信号都在组合块入口被赋默认值，未报告 latch/error；保留 warning 可见，不做全局 waiver。数值对拍覆盖功能语义，但不能替代后续 URG/code coverage。
- full-top SpyGlass 不能代表这些未实例化 block 的独立 lint；FP-only profile：`cd dv/spyglass && spyglass -batch -project fp_blocks.prj -goal lint/lint_rtl`。

## G1 判断

本定向输入清单中的关键数值类别均有 stimulus 并通过 bit-exact oracle；accumulator 的控制时序有 SVA；FP-only lint 0 errors，16 条 W415a 已逐类解释且保持可见。因此 G1 的独立算术 block 功能/静态检查 gate 可以关闭。这个判断不宣称 URG/code coverage closure，也不宣称产品 opcode、SPAD 事务或 UVM 已完成；这些留在 G2/G3。
