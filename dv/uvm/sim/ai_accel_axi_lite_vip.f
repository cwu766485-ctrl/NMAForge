# Run from dv/uvm/sim. Protocol VIP dependencies compile before project UVM.
-f ${TUE_HOME}/compile.f
-f ${TVIP_COMMON_HOME}/compile.f
-f ${TVIP_AXI_HOME}/sim/compile.f
-f ai_accel_uvm.f
../tests/vip/nma_axi_lite_vip_test_pkg.sv
../tb/tb_nma_axi_lite_vip.sv
