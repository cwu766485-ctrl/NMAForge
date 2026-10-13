# G1 FP32 顺序累加器 Block 报告

日期：2026-10-13
状态：独立非融合 FP32 顺序累加器已通过当前工作区 VCS 逐拍 bit-exact 回归；尚未接入产品 opcode，G1 整体仍未完成。

## 模块契约

- RTL：`rtl/compute/fp/ai_fp32_accumulator.v`
- 输入 `product_bits` 是已经单独舍入为 FP32 的乘积；每个 `accumulate` 上升沿执行一次 FP32 RNE 加法并写回累加寄存器。
- 通过实例化 `ai_fp32_add` 实现每步 `round_RNE_FP32(accumulator + product)`，不会将乘法与加法合并成 FMA。
- `rst_n` 为低有效异步复位；`clear` 为同步清零且优先于 `accumulate`；无清零/累加时保持状态。
- 该模块仅是累加寄存器 wrapper；没有输入/输出 ready-valid、长度计数、abort 或命令生命周期，后续由 compute engine 负责。

## 可复现命令与结果

在 Rocky Linux 8.10、Synopsys VCS V-2023.12-SP1_Full64、已加载 license 的交互式 WSL shell 中从仓库根目录运行：

```bash
# Set VCS_HOME to the locally installed VCS release; license configuration stays local.
export PATH="$VCS_HOME/bin:$PATH"
make -C dv/block/compute/fp/sim accum-test SEED=20261013 RANDOM_CASES=10000
make -C dv/block/compute/fp/sim accum-test SEED=987654321 RANDOM_CASES=100000
(cd dv/block/compute/fp/model && PYTHONDONTWRITEBYTECODE=1 python3.12 -m unittest -v test_fp_reference.py)
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=1791860897
```

- 10,000 随机累加输入：`FP32_ACCUM_PASS vectors=10189`，0 mismatch，VCS compile 无新 warning。
- 100,000 随机累加输入：`FP32_ACCUM_PASS vectors=101595`，0 mismatch，VCS compile 无新 warning。
- 两轮包含 directed sequences：异步 reset、clear-over-accumulate、idle hold、逐步舍入 tie、正负零、精确抵消、Inf、canonical NaN、subnormal/normal 边界；随机累加流每 64 个输入清零一次，避免一次随机 overflow 让剩余长测只重复传播 Inf。
- 期望值逐周期由独立 `fp_reference.fp32_add_bits` 计算，不从 DUT 中取值生成；模型单测 16/16 通过。
- 已增加独立 checker `dv/block/compute/fp/assertions/ai_fp32_accumulator_sva.sv`，并由 VCS `-assert svaext` 启用。断言覆盖同步 clear 优先并清零、`accumulate` 下一拍写入前一拍 FP32 add 结果、idle 保持；包含 checker 的 100,000 随机长回归通过，断言无失败。数值正确性仍由 Python raw-bit scoreboard 独立判定。
- FP-only SpyGlass project `dv/spyglass/fp_blocks.prj` 将 accumulator 及其算术依赖实例化后检查。命令 `cd dv/spyglass && spyglass -batch -project fp_blocks.prj -goal lint/lint_rtl`：0 errors、16 warnings，均为 FP32 add/addsub 组合临时变量 W415a；不代表零告警 signoff。
- 更新 source lists 后，top `ai_smoke` 与 20-case seeded top regression 均 `TEST PASS`。
- 顶层编译仍有一条既有 `Warning-[TFIPC]`，在 `ai_accel_compute_cluster.v:163` 的 CNM 实例；新增累加器没有新增顶层 warning。

向量和仿真输出留在本机 `/tmp/nmaforge_fp32_accumulator/`，不纳入仓库。随机原始位型回归不等同于功能 coverage closure 或 formal equivalence。

## 集成状态与下一步

累加器及其依赖已加入 top smoke、top UVM、SpyGlass RTL/static project 和两套 FPGA RTL source lists，以便后续集成时能够统一解析；目前没有任何产品模块实例化它。BF16/FP16 Add/Sub block 已实现并通过独立回归，证据见 [`FP_G1_ADDSUB_REPORT.md`](FP_G1_ADDSUB_REPORT.md)。本次加入累加器控制 SVA 并重跑 100,000 随机长测通过；top smoke 也再次 `TEST PASS`。FP-only lint 显示 0 errors、16 条 W415a 组合临时变量告警并已分类处置；无零告警或 signoff 声明。G1 独立算术 block 功能/静态检查 gate 已关闭，但 URG/code coverage closure、综合/PPA、产品实例化和端到端 `0x50 BF16_DOT_ACC_FP32` 仍未完成。
