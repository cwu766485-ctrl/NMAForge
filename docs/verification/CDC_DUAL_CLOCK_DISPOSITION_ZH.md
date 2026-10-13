# 双时钟 FIFO CDC Warning Disposition

## 范围与结论

本文仅适用于实验性双时钟 command/completion path：
`rtl/control/cdc/ai_async_fifo.v`、`ai_ctrl_compute_cdc.v` 与
`ai_accel_dual_clock_command_path.v`。当前产品顶层 `ai_accel_top` 仍为单
`aclk` 域；本文不构成产品 CDC/RDC sign-off。

2026-09-29 的 `dual_cdc` SpyGlass structural run 结果是 **0 fatal、0 error、
7 warning、0 unsynchronized crossing**。这 7 条全部来自标准 Gray-pointer
async FIFO 的结构检查，未使用 waiver。每项都由 `ai_async_fifo_sva.sv` 的
bound SVA 和 CDC block 回归约束；若 SVA 或 runtime test 失败，应按 RTL 缺陷
处理，而不能关闭规则。

## 逐条 disposition

| SpyGlass rule / 数量 | 位置 | 根因与 disposition | 对应可执行 SVA |
|---|---|---|---|
| `Ac_conv01` / 1 | `rd_fire` | 报告将 command 与 completion FIFO 的同步器向量列为收敛到 read handshake。`rd_fire` 只由同一实例的 `rd_valid && rd_ready` 构成，`rd_valid` 只由本实例的第二级 `wr_gray_rd2` 产生；这是实例展平下的预期 async-FIFO 控制路径。必须持续检查 elaborated path，不能允许跨实例组合依赖。 | `p_rd_empty_uses_second_sync_stage`、两级同步器性质 |
| `Ac_conv02` / 2 | `wr_full` | `rd_gray_wr2` 的 Gray 指针进入标准 full 比较器，最高两位反相以区分环绕。SpyGlass Gray recognition 为 disabled 时把多 bit 比较报告为收敛；RTL 只使用第二级同步结果。 | `p_wr_gray_matches_binary`、`p_wr_gray_changes_one_bit_per_fire`、`p_wr_full_uses_second_sync_stage` |
| `Ac_conv02` / 2 | `rd_empty` | `wr_gray_rd2` 的 Gray 指针与本地读指针比较是标准 empty decode；不是多位普通数据跨域。RTL 只使用第二级同步结果。 | `p_rd_gray_matches_binary`、`p_rd_gray_changes_one_bit_per_fire`、`p_rd_empty_uses_second_sync_stage` |
| `Reset_sync04` / 2 | 两个 FIFO 本地同步器复位 | 每个域用自己的低有效异步 reset 同时清空本地指针和两级同步器，符合当前“异步断言、复位后经 pointer crossing 建立可见状态”的 FIFO 契约。单边 reset 是 flush，不保留 epoch；恢复 traffic 前必须按 integration TB 所示 quiesce 后双边 reset。 | `p_wr_reset_clears_local_cdc_state`、`p_rd_reset_clears_local_cdc_state`、两级同步器性质 |

## 实现与验证要求

- 两个 Gray 同步器均有 `ASYNC_REG="TRUE"` 属性，供综合/P&R 流保留与 colocate；该属性不改变 RTL 功能或周期。
- 所有 full/empty 判定只能引用第二级同步指针，严禁使用第一同步级或异步源指针。
- Gray 源指针只允许由本地 `valid && ready` handshake 推进，每次推进恰好改变一个 Gray bit。
- reset 是本 FIFO 的明确边界：双边 reset 后 FIFO 必须为空；单边 reset 后不得在未协调 flush 的情况下恢复远端 transaction。

复现命令：

```bash
cd dv/block/cdc/uvm && make uvm_regress
cd ../sim && make shell_run && make command_path_run
cd ../../../spyglass && ./run_spyglass_a8.sh dual_cdc
```

接受标准：VCS/UVM 无 assertion、UVM error 或 fatal；SpyGlass `unsynchronized
crossings=0`，且上述 7 条必须与本表逐条相符。若 warning 数量、规则或层次路径
变化，重新审计后更新本文件。
