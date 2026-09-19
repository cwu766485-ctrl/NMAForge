<!-- organize-chip-project:generated-file -->
# Design and verification index

This index separates design, verification, flow, and protected boundaries so an agent can choose the correct evidence.

## Design

- `dv/block/control/agent/axi_lite_tasks.svh`
- `dv/block/control/agent/control_axil_agent.svh`
- `dv/block/control/agent/control_axil_agent_pkg.sv`
- `dv/block/control/agent/control_axil_driver.svh`
- `dv/block/control/agent/control_axil_monitor.svh`
- `dv/block/control/agent/control_axil_sequencer.svh`
- `dv/block/control/agent/control_axil_types_pkg.sv`
- `dv/block/control/agent/interfaces/ai_control_status_if.sv`
- `dv/block/control/assertions/ai_axil_control_sva.sv`
- `dv/block/control/env/control_coverage.svh`
- `dv/block/control/env/control_env.svh`
- `dv/block/control/env/control_env_pkg.sv`
- `dv/block/control/env/control_reg_model.svh`
- `dv/block/control/env/control_scoreboard.svh`
- `dv/block/dma/agent/ai_dma_tasks.svh`
- `dv/block/dma/agent/dma_axi_monitor.svh`
- `dv/block/dma/agent/dma_axi_read_responder.svh`
- `dv/block/dma/agent/dma_block_agent_pkg.sv`
- `dv/block/dma/agent/dma_block_types_pkg.sv`
- `dv/block/dma/agent/dma_cmd_driver.svh`
- `dv/block/dma/agent/dma_cmd_sequencer.svh`
- `dv/block/dma/agent/dma_spad_model.svh`
- `dv/block/dma/agent/dma_spad_monitor.svh`
- `dv/block/dma/agent/interfaces/ai_dma_axi_if.sv`
- `dv/block/dma/agent/interfaces/ai_dma_ctrl_if.sv`
- `dv/block/dma/agent/interfaces/ai_dma_spad_if.sv`
- `dv/block/dma/assertions/ai_axi128_dma_sva.sv`
- `dv/block/dma/env/axi_memory_model.sv`
- `dv/block/dma/env/dma_block_env.svh`
- `dv/block/dma/env/dma_block_env_pkg.sv`
- `dv/block/dma/env/dma_block_scoreboard.svh`
- `dv/spyglass/tsmc28_sram_macro_stub.v`
- `dv/subsystem/top_smoke/env/ai_accel_sva.sv`
- `dv/subsystem/top_smoke/fixtures/ai_transformer_workload.svh`
- `fpga/xczu15eg/xczu9eg-2ffvb1156.v`
- `fpga/xilinx_a7_100t/rtl/axi_lite_bringup_master.v`
- `fpga/xilinx_a7_100t/rtl/fpga_ai_accel_smoke_top.v`
- `rtl/compute/cnm/ai_bank_local_controller.v`
- `rtl/compute/cnm/ai_bank_pe.v`
- `rtl/compute/cnm/ai_banked_cnm_core.v`

## Verification

- `dv/block/command_processor/tb/.gitkeep`
- `dv/block/command_processor/tests/.gitkeep`
- `dv/block/compute/cnm/tb/tb_ai_banked_cnm_a22.sv`
- `dv/block/compute/cnm/tb/tb_ai_cnm_a2_gemv_bench.sv`
- `dv/block/compute/cnn_kv/tb/tb_ai_a6_datapaths.sv`
- `dv/block/compute/matrix/tb/tb_ai_tensor_a3_gemm_bench.sv`
- `dv/block/control/sim/control_uvm.f`
- `dv/block/control/sim/logs/control_busy_abort_test.log`
- `dv/block/control/sim/logs/control_irq_error_test.log`
- `dv/block/control/sim/logs/control_protocol_test.log`
- `dv/block/control/sim/logs/control_ral_access_test.log`
- `dv/block/control/sim/logs/control_random_rw_test.log`
- `dv/block/control/sim/logs/control_reset_version_test.log`
- `dv/block/control/tb/.gitkeep`
- `dv/block/control/tb/tb_ai_control_uvm.sv`
- `dv/block/control/tests/.gitkeep`
- `dv/block/control/tests/control_base_test.svh`
- `dv/block/control/tests/control_sequences.svh`
- `dv/block/control/tests/control_tests_pkg.sv`
- `dv/block/dma/DMA_UVM_TESTPLAN.md`
- `dv/block/dma/sim/dma_block_uvm.f`
- `dv/block/dma/tb/.gitkeep`
- `dv/block/dma/tb/tb_ai_axi128_dma.sv`
- `dv/block/dma/tb/tb_ai_axi128_dma_uvm.sv`
- `dv/block/dma/tests/.gitkeep`
- `dv/block/dma/tests/dma_block_base_test.svh`
- `dv/block/dma/tests/dma_block_tests_pkg.sv`
- `dv/block/dma/tests/dma_functional_tests.svh`
- `dv/block/dma/tests/dma_load_ooo_smoke_test.svh`
- `dv/block/spad_arbiter/tb/.gitkeep`
- `dv/block/spad_arbiter/tb/tb_ai_spad_arbiter_rr.sv`
- `dv/block/spad_arbiter/tests/.gitkeep`
- `dv/subsystem/dma_spad/tb/.gitkeep`
- `dv/subsystem/dma_spad/tests/.gitkeep`
- `dv/subsystem/queue_completion/tb/.gitkeep`
- `dv/subsystem/queue_completion/tests/.gitkeep`
- `dv/subsystem/tensor_datapath/tb/.gitkeep`
- `dv/subsystem/tensor_datapath/tests/.gitkeep`
- `dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv`
- `dv/uvm/agent/ai_accel_uvm_types_pkg.sv`

## Constraints and flow

- `dv/spyglass/a8_constraints.sgdc`
- `fpga/xilinx_a7_100t/constraints/a7_100t_smoke.xdc`
- `dv/block/control/sim/Makefile`
- `dv/block/dma/sim/Makefile`
- `dv/spyglass/a8_rtl.f`
- `dv/subsystem/top_smoke/sim/Makefile`
- `dv/subsystem/top_smoke/sim/ai_accel.f`
- `fpga/xczu15eg/ai_accel_rtl.tcl`
- `fpga/xczu15eg/scripts/build_board.tcl`
- `fpga/xczu15eg/scripts/finalize_board_build.tcl`
- `fpga/xczu15eg/scripts/generate_baremetal.tcl`
- `fpga/xczu15eg/scripts/implement_ai_accel_ip.tcl`
- `fpga/xczu15eg/scripts/jtag_run_baremetal.tcl`
- `fpga/xczu15eg/scripts/jtag_validate.tcl`
- `fpga/xczu15eg/scripts/synth_ai_accel_ip.tcl`
- `fpga/xczu15eg/scripts/verify_ila.tcl`
- `fpga/xilinx_a7_100t/ai_accel_rtl.tcl`
- `fpga/xilinx_a7_100t/scripts/build_smoke_bitstream.tcl`
- `fpga/xilinx_a7_100t/scripts/program_smoke_bitstream.tcl`
- `fpga/xilinx_a7_100t/scripts/synth_ai_accel_ip.tcl`
- `fpga/xilinx_a7_100t/scripts/synth_smoke_top.tcl`
- `syn/convert_tsmc28_sram_lib.tcl`
- `syn/convert_tsmc28_stdcell_lib.tcl`
- `syn/dc_ai_accel_28nm.tcl`
- `syn/probe_tsmc28_libraries.tcl`

## Heuristic HDL tops

- `ai_axil_control_sva`, `ai_axi128_dma_sva`, `axi_memory_model`, `TS1N28HPCPL2SVTB4096X32M4MWBASO`, `ai_accel_sva`, `ai_accel_formal_axi_properties`, `axi_lite_bringup_master`, `fpga_ai_accel_smoke_top`, `ai_bank_local_controller`, `ai_bank_pe`, `ai_banked_cnm_core`, `ai_conv3x3_linebuffer_core`, `ai_integer_sqrt`, `ai_unsigned_divider`, `ai_int8_compute_core`, `ai_int8_datapath`, `ai_kv_cache_engine`, `ai_tensor_matrix_core`, `ai_tensor_matrix_datapath`, `ai_tile_pipeline`, `ai_tensor_sfu_core`, `contains`, `ai_tensor_sfu_math`, `ai_accel_regs`, `axi_lite_reg_if`, `ai_accel_opcode_decode`, `ai_desc_fetch`, `ai_descriptor_validator`, `axi_desc_fetch`, `owns` — verify against source ordering/filelists before compiling.

## Missing evidence to resolve

- Exact top/configuration, clock/reset assumptions, test selection, coverage/signoff criteria, and generated-source provenance are not inferred unless documented above.
