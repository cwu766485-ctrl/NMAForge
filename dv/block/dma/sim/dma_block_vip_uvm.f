+incdir+../agent
+incdir+../agent/interfaces
+incdir+../env
+incdir+../tests
+incdir+${TVIP_AXI_HOME}/env
+incdir+${TVIP_AXI_HOME}/agent/common
+incdir+${TVIP_AXI_HOME}/agent/master
+incdir+${TVIP_AXI_HOME}/agent/slave
+incdir+${TVIP_AXI_HOME}/tb
+incdir+${TVIP_AXI_HOME}/env/protocol_checker

-f ${TUE_HOME}/compile.f
-f ${TVIP_COMMON_HOME}/compile.f
-f ${TVIP_AXI_HOME}/sim/compile.f

../agent/interfaces/ai_dma_ctrl_if.sv
../agent/interfaces/ai_dma_axi_if.sv
../agent/interfaces/ai_dma_spad_if.sv
../../../../rtl/dma/ai_dma_burst_planner.v
../../../../rtl/dma/ai_dma_read_slot_tracker.v
../../../../rtl/dma/ai_dma_write_response_tracker.v
../../../../rtl/dma/ai_dma_spad_transfer_adapter.v
../../../../rtl/dma/ai_axi128_dma.v
../agent/dma_block_types_pkg.sv
../agent/dma_block_agent_pkg.sv
../env/dma_block_env_pkg.sv
../tests/dma_block_tests_pkg.sv
../assertions/ai_axi128_dma_sva.sv
../agent/nmaforge_dma_axi4_pin_adapter.sv
../tb/tb_ai_axi128_dma_vip_uvm.sv
