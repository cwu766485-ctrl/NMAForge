<!-- organize-chip-project:generated-file -->
# Repository map

Generated from a bounded scan; verify any heuristic before relying on it.

## Top-level layout

- `docs/`
- `dv/`
- `fpga/`
- `rtl/`
- `sw/`
- `syn/`
- `tools/`
- `.gitignore`
- `AGENTS.md`
- `NOTICE.md`
- `README.md`
- `README_ZH.md`

## HDL inventory

- `tb_ai_banked_cnm_a22` — `dv/block/compute/cnm/tb/tb_ai_banked_cnm_a22.sv`
- `tb_ai_cnm_a2_gemv_bench` — `dv/block/compute/cnm/tb/tb_ai_cnm_a2_gemv_bench.sv`
- `tb_ai_a6_datapaths` — `dv/block/compute/cnn_kv/tb/tb_ai_a6_datapaths.sv`
- `tb_ai_tensor_a3_gemm_bench` — `dv/block/compute/matrix/tb/tb_ai_tensor_a3_gemm_bench.sv`
- `ai_axil_control_sva` — `dv/block/control/assertions/ai_axil_control_sva.sv`
- `tb_ai_control_uvm` — `dv/block/control/tb/tb_ai_control_uvm.sv`
- `ai_axi128_dma_sva` — `dv/block/dma/assertions/ai_axi128_dma_sva.sv`
- `axi_memory_model` — `dv/block/dma/env/axi_memory_model.sv`
- `tb_ai_axi128_dma` — `dv/block/dma/tb/tb_ai_axi128_dma.sv`
- `tb_ai_axi128_dma_uvm` — `dv/block/dma/tb/tb_ai_axi128_dma_uvm.sv`
- `tb_ai_spad_arbiter_rr` — `dv/block/spad_arbiter/tb/tb_ai_spad_arbiter_rr.sv`
- `TS1N28HPCPL2SVTB4096X32M4MWBASO` — `dv/spyglass/tsmc28_sram_macro_stub.v`
- `ai_accel_sva` — `dv/subsystem/top_smoke/env/ai_accel_sva.sv`
- `tb_ai_accel_smoke` — `dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv`
- `ai_accel_formal_axi_properties` — `dv/uvm/formal/ai_accel_formal_properties.sv`
- `tb_ai_accel_uvm` — `dv/uvm/tb/tb_ai_accel_uvm.sv`
- `axi_lite_bringup_master` — `fpga/xilinx_a7_100t/rtl/axi_lite_bringup_master.v`
- `fpga_ai_accel_smoke_top` — `fpga/xilinx_a7_100t/rtl/fpga_ai_accel_smoke_top.v`
- `ai_bank_local_controller` — `rtl/compute/cnm/ai_bank_local_controller.v`
- `ai_bank_pe` — `rtl/compute/cnm/ai_bank_pe.v`
- `ai_banked_cnm_core` — `rtl/compute/cnm/ai_banked_cnm_core.v`
- `ai_conv3x3_linebuffer_core` — `rtl/compute/cnn/ai_conv3x3_linebuffer_core.v`
- `ai_integer_sqrt` — `rtl/compute/common/ai_integer_sqrt.v`
- `ai_unsigned_divider` — `rtl/compute/common/ai_unsigned_divider.v`
- `ai_int8_compute_core` — `rtl/compute/int8/ai_int8_compute_core.v`
- `ai_int8_datapath` — `rtl/compute/int8/ai_int8_datapath.v`
- `ai_kv_cache_engine` — `rtl/compute/kv/ai_kv_cache_engine.v`
- `ai_tensor_matrix_core` — `rtl/compute/matrix/ai_tensor_matrix_core.v`
- `ai_tensor_matrix_datapath` — `rtl/compute/matrix/ai_tensor_matrix_datapath.v`
- `ai_tile_pipeline` — `rtl/compute/pipeline/ai_tile_pipeline.v`
- `ai_tensor_sfu_core` — `rtl/compute/sfu/ai_tensor_sfu_core.v`
- `contains` — `rtl/compute/sfu/ai_tensor_sfu_math.v`
- `ai_tensor_sfu_math` — `rtl/compute/sfu/ai_tensor_sfu_math.v`
- `ai_accel_regs` — `rtl/control/axi_lite/ai_accel_regs.v`
- `axi_lite_reg_if` — `rtl/control/axi_lite/axi_lite_reg_if.v`
- `ai_accel_opcode_decode` — `rtl/control/descriptor/ai_accel_opcode_decode.v`
- `ai_desc_fetch` — `rtl/control/descriptor/ai_desc_fetch.v`
- `ai_descriptor_validator` — `rtl/control/descriptor/ai_descriptor_validator.v`
- `axi_desc_fetch` — `rtl/control/descriptor/axi_desc_fetch.v`
- `owns` — `rtl/control/queue/ai_command_processor.v`
- `ai_command_processor` — `rtl/control/queue/ai_command_processor.v`
- `remains` — `rtl/control/queue/ai_command_processor.v`
- `ai_completion_writer` — `rtl/control/queue/ai_completion_writer.v`
- `ai_perf_monitor` — `rtl/control/queue/ai_perf_monitor.v`
- `ai_ring_pointer_next` — `rtl/control/queue/ai_ring_pointer_next.v`
- `ai_axi128_dma` — `rtl/dma/ai_axi128_dma.v`
- `ai_dma_burst_planner` — `rtl/dma/ai_dma_burst_planner.v`
- `ai_dma_read_slot_tracker` — `rtl/dma/ai_dma_read_slot_tracker.v`
- `ai_dma_spad_transfer_adapter` — `rtl/dma/ai_dma_spad_transfer_adapter.v`
- `ai_dma_write_response_tracker` — `rtl/dma/ai_dma_write_response_tracker.v`
- `ai_scratchpad` — `rtl/memory/ai_scratchpad.v`
- `ai_spad_arbiter` — `rtl/memory/ai_spad_arbiter.v`
- `ai_spad_protection` — `rtl/memory/ai_spad_protection.v`
- `ai_accel_top` — `rtl/top/ai_accel_top.v`
- `ai_accel_axi_fabric` — `rtl/top/fabric/axi/ai_accel_axi_fabric.v`
- `ai_accel_axi_master_router` — `rtl/top/fabric/axi/ai_accel_axi_master_router.v`
- `ai_accel_dma_request_mux` — `rtl/top/fabric/axi/ai_accel_dma_request_mux.v`
- `ai_descriptor_source_mux` — `rtl/top/fabric/axi/ai_descriptor_source_mux.v`
- `ai_accel_compute_cluster` — `rtl/top/fabric/compute/ai_accel_compute_cluster.v`
- `only` — `rtl/top/fabric/control/ai_accel_control_fabric.v`
- `ai_accel_control_fabric` — `rtl/top/fabric/control/ai_accel_control_fabric.v`
- `ai_accel_memory_fabric` — `rtl/top/fabric/memory/ai_accel_memory_fabric.v`
- `ai_accel_spad_subsystem` — `rtl/top/fabric/memory/ai_accel_spad_subsystem.v`
- `ai_spad_response_demux` — `rtl/top/fabric/memory/ai_spad_response_demux.v`
- `ai_scratchpad` — `syn/ai_scratchpad_28nm_macro.v`

## Role index

### RTL / HDL source

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

### agent instructions

- `AGENTS.md`

### build / EDA flow input

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

### constraints / power intent

- `dv/spyglass/a8_constraints.sgdc`
- `fpga/xilinx_a7_100t/constraints/a7_100t_smoke.xdc`

### design / verification documentation

- `docs/PUBLIC_RELEASE.md`
- `docs/README_ZH.md`
- `docs/RTL_GUIDE.md`
- `docs/project_update_log.md`
- `docs/wsl_linux_instruction.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/CNM_BANK_LOCAL_PE_RESEARCH_ZH.md`
- `docs/architecture/CNM_EVALUATION.md`
- `docs/architecture/CNM_EVALUATION_ZH.md`
- `docs/architecture/Literature_Review.md`
- `docs/architecture/PROJECT_EXPERIENCE_ZH.md`
- `docs/exec-plans/active/execution-frontier.md`
- `docs/spec/NAMING_COMPATIBILITY.md`
- `docs/spec/SPEC.md`
- `docs/spec/SPEC_ZH.md`
- `docs/verification/STATIC_ANALYSIS_REPORT.md`
- `docs/verification/TSMC28_SYNTHESIS_REPORT.md`
- `docs/verification/VPLAN.md`
- `docs/verification/XCZU15EG_BRINGUP.md`

### project artifact

- `.gitignore`
- `NOTICE.md`
- `README_ZH.md`
- `docs/exec-plans/active/physical-migration-map.json`
- `dv/VERIFICATION_MATRIX.md`
- `dv/block/command_processor/.gitkeep`
- `dv/block/command_processor/assertions/.gitkeep`
- `dv/block/command_processor/ref/.gitkeep`
- `dv/block/command_processor/sim/.gitkeep`
- `dv/block/compute/cnm/.gitkeep`
- `dv/block/compute/cnn_kv/.gitkeep`
- `dv/block/compute/matrix/.gitkeep`
- `dv/block/compute/sfu/.gitkeep`
- `dv/block/control/.gitkeep`
- `dv/block/control/assertions/.gitkeep`
- `dv/block/control/ref/.gitkeep`
- `dv/block/control/sim/.gitkeep`
- `dv/block/control/sim/cm.log`
- `dv/block/control/sim/control_block_regress.log`
- `dv/block/control/sim/control_block_urg.log`
- `dv/block/control/sim/control_random_debug.log`
- `dv/block/control/sim/control_random_fixed.log`
- `dv/block/control/sim/tr_db.log`
- `dv/block/dma/.gitkeep`
- `dv/block/dma/agent/.gitkeep`

### project guidance / source of truth

- `README.md`
- `docs/README.md`
- `dv/block/README.md`
- `dv/block/compute/cnm/README.md`
- `dv/block/compute/cnn_kv/README.md`
- `dv/block/compute/matrix/README.md`
- `dv/block/compute/sfu/README.md`
- `dv/block/control/README.md`
- `dv/block/dma/README.md`
- `dv/spyglass/README.md`
- `dv/subsystem/README.md`
- `dv/subsystem/tensor_datapath/README.md`
- `dv/subsystem/top_smoke/README.md`
- `dv/uvm/README.md`
- `dv/uvm/formal/README.md`
- `fpga/xczu15eg/README.md`
- `fpga/xilinx_a7_100t/README.md`
- `rtl/README.md`
- `sw/README.md`
- `sw/workloads/transformer_micro/README.md`
- `syn/README.md`

### tool / automation script

- `dv/block/compute/cnm/ref/ai_a2_reference.py`
- `dv/block/compute/matrix/ref/ai_a3_reference.py`
- `dv/spyglass/run_spyglass_a8.sh`
- `dv/subsystem/top_smoke/sim/run_ai_smoke_linux.sh`
- `sw/tools/cimforge_mapper.py`
- `syn/run_ai_accel_28nm_dc.sh`

### verification source

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
