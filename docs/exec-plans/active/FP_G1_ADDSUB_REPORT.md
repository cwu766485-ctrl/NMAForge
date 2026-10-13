# G1 BF16/FP16 Add/Sub Block 报告

日期：2026-10-13
状态：BF16 与 FP16 组合 Add/Sub 算术 block 已通过当前工作区 VCS 定向和固定种子随机 bit-exact 仿真；G1 的 block 静态与覆盖率收尾仍待完成。

## 模块结构与数值约定

- RTL：`rtl/compute/fp/ai_fp16_bf16_addsub.v`
- 内部共享参数化 core：`ai_fp16_bf16_addsub_core`
- 对外格式 wrapper：`ai_bf16_addsub`、`ai_fp16_addsub`
- 接口为 16-bit raw operands、显式 `subtract` 控制和 16-bit raw result；组合逻辑，无状态/握手。
- 实现 RNE、gradual underflow、±0、Inf 和 canonical qNaN；不产生 IEEE exception flags。
- 独立 oracle：`dv/block/compute/fp/model/fp_reference.py` 的 `bf16_add_bits` / `fp16_add_bits`，使用精确 Fraction/raw-bit 运算。
- 向量生成器：`dv/block/compute/fp/model/generate_add16_vectors.py`；testbench：`dv/block/compute/fp/tb/tb_ai_fp16_bf16_addsub.sv`。

## 可复现命令与结果

环境为 Rocky Linux 8.10、Synopsys VCS V-2023.12-SP1_Full64、已加载本机 license 的交互式 WSL shell：

```bash
# Set VCS_HOME to the locally installed VCS release; license configuration stays local.
export PATH="$VCS_HOME/bin:$PATH"
make -C dv/block/compute/fp/sim add16-test RANDOM_CASES=50000 SEED=8675309
(cd dv/block/compute/fp/model && PYTHONDONTWRITEBYTECODE=1 python3.12 -m unittest -v test_fp_reference.py)
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=1791860897
```

- Focused VCS：`FP16_BF16_ADDSUB_PASS vectors=100032`，32 个 directed vectors（两种格式各 16 个）+ 每种格式 50,000 个固定种子随机原始位型，0 mismatch，VCS compile 无 Warning/Error。
- Directed cases 覆盖偶/奇尾数 tie、次正规数、溢出、抵消、正负零、Inf、qNaN/sNaN 与减法符号处理。
- 独立 reference model：16/16 tests 通过。
- 更新全部 RTL source lists 后，top `ai_smoke` 和 20-case seeded top regression 均 `TEST PASS`；顶层仍显示既有 `Warning-[TFIPC]`（`ai_accel_compute_cluster.v:163` 的 CNM 实例端口连接），不是本次 Add/Sub 新增 warning。
- SpyGlass `lint/lint_rtl`：Exit Code 0，0 errors、260 warnings、4 infos。当前 top 是 `ai_accel_top`；新增 FP 算术模块未被实例化，工具自动将它们作为层级外模块处理，因此不能据此宣称 Add/Sub block 已独立 lint-clean。

实际向量与仿真输出保存在本机 `/tmp/nmaforge_fp16_bf16_addsub/`，未放入仓库。随机样本通过不等于功能覆盖率闭合、形式证明或 signoff。

## 集成边界与剩余工作

Add/Sub、FP32 adder、累加器和 BF16 multiplier 均已进入 top smoke、top UVM、SpyGlass RTL/static 及两套 FPGA RTL source lists，便于后续集成解析；目前它们都没有接入产品 compute cluster、opcode、descriptor、SPAD 或 completion 生命周期。G1 还需补齐 block-level SVA/覆盖率和静态/综合检查；G2 再开始 `0x50 BF16_DOT_ACC_FP32` 的产品路径集成。
