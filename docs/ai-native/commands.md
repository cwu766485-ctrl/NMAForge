<!-- organize-chip-project:generated-file -->
# Command index

Only commands evidenced by repository text are listed. Validate environment and source revision before execution.

## Build/flow targets

- `dv/block/control/sim/Makefile`: `uvm_compile`, `run_sim`, `uvm_run`, `uvm_smoke`, `uvm_regress`, `coverage`
- `dv/block/dma/sim/Makefile`: `uvm_compile`, `uvm_run`, `uvm_smoke`, `uvm_regress`, `coverage`, `clean`
- `dv/subsystem/top_smoke/sim/Makefile`: `all`, `ai_transformer_gen`, `ai_comp`, `ai_run`, `ai_smoke`, `ai_smoke_vcd`, `ai_smoke_saif`, `ai_transformer`, `ai_quick`, `ai_a4_ref`, `ai_precheck`, `ai_dma_comp`, `ai_dma_run`, `ai_spad_arb_comp`, `ai_spad_arb_run`, `ai_upgrade_vcs`, `ai_a6_dma_comp`, `ai_a6_dma_run`, `ai_a6_datapaths_comp`, `ai_a6_datapaths_run`, `ai_a7_vcs`, `ai_cnm_a22_comp`, `ai_cnm_a22_run`, `ai_cnm_a22`, `ai_cnm_a2_gemv_bench_comp`, `ai_cnm_a2_gemv_bench_run`, `ai_cnm_a2_gemv_bench`, `ai_tensor_a3_gemm_bench_comp`, `ai_tensor_a3_gemm_bench_run`, `ai_tensor_a3_gemm_bench`, `ai_cnm_compare`, `ai_cnm_signoff`, `clean`
- `dv/uvm/sim/Makefile`: `uvm_compile`, `uvm_run`, `uvm_smoke`, `clean`

## Commands found in guidance/CI

- `make uvm_smoke`
- `make uvm_regress 2>&1 | tee control_block_regress.log`
- `make coverage`
- `VCS collected line/condition/FSM/branch/toggle/assertion coverage during the`
- `make uvm_regress 2>&1 | tee dma_block_regress.log`
- `make uvm_compile`
- `make -C ../dv/subsystem/top_smoke/sim ai_transformer_gen`
- `make -C ../dv/subsystem/top_smoke/sim ai_transformer`
- `make -C dv/subsystem/top_smoke/sim ai_transformer_gen`
- `make ai_transformer`
- `make -f dv/block/control/sim/Makefile uvm_compile`
- `make -f dv/block/control/sim/Makefile run_sim`
- `make -f dv/block/control/sim/Makefile uvm_run`
- `make -f dv/block/control/sim/Makefile uvm_smoke`
- `make -f dv/block/control/sim/Makefile uvm_regress`
- `make -f dv/block/control/sim/Makefile coverage`
- `make -f dv/block/dma/sim/Makefile uvm_compile`
- `make -f dv/block/dma/sim/Makefile uvm_run`
- `make -f dv/block/dma/sim/Makefile uvm_smoke`
- `make -f dv/block/dma/sim/Makefile uvm_regress`
- `make -f dv/block/dma/sim/Makefile coverage`
- `make -f dv/block/dma/sim/Makefile clean`
- `make -f dv/subsystem/top_smoke/sim/Makefile all`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_transformer_gen`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_comp`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_run`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_smoke`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_smoke_vcd`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_smoke_saif`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_transformer`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_quick`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_a4_ref`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_precheck`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_dma_comp`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_dma_run`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_spad_arb_comp`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_spad_arb_run`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_upgrade_vcs`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_a6_dma_comp`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_a6_dma_run`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_a6_datapaths_comp`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_a6_datapaths_run`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_a7_vcs`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_cnm_a22_comp`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_cnm_a22_run`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_cnm_a22`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_cnm_a2_gemv_bench_comp`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_cnm_a2_gemv_bench_run`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_cnm_a2_gemv_bench`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_tensor_a3_gemm_bench_comp`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_tensor_a3_gemm_bench_run`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_tensor_a3_gemm_bench`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_cnm_compare`
- `make -f dv/subsystem/top_smoke/sim/Makefile ai_cnm_signoff`
- `make -f dv/subsystem/top_smoke/sim/Makefile clean`
- `make -f dv/uvm/sim/Makefile uvm_compile`
- `make -f dv/uvm/sim/Makefile uvm_run`
- `make -f dv/uvm/sim/Makefile uvm_smoke`
- `make -f dv/uvm/sim/Makefile clean`

## Execution rule

Use the existing canonical flow. Start with a dry-run or smoke check; capture tool versions, configuration, seed, command, exit status, and log path under the project's established run convention.
