set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../..]]
set RTL [file join $ROOT rtl]
set RTL_FILES [list \
    [file join $RTL control descriptor ai_accel_opcode_decode.v] \
    [file join $RTL compute cnm ai_bank_pe.v] \
    [file join $RTL compute cnm ai_bank_local_controller.v] \
    [file join $RTL compute cnm ai_banked_cnm_core.v] \
    [file join $RTL compute common ai_unsigned_divider.v] \
    [file join $RTL compute common ai_integer_sqrt.v] \
    [file join $RTL compute matrix ai_tensor_matrix_datapath.v] \
    [file join $RTL compute matrix ai_tensor_matrix_core.v] \
    [file join $RTL compute sfu ai_tensor_sfu_math.v] \
    [file join $RTL compute sfu ai_tensor_sfu_core.v] \
    [file join $RTL compute cnn ai_conv3x3_linebuffer_core.v] \
    [file join $RTL compute kv ai_kv_cache_engine.v] \
    [file join $RTL compute int8 ai_int8_datapath.v] \
    [file join $RTL compute int8 ai_int8_compute_core.v] \
    [file join $RTL compute fp ai_bf16_mul_fp32.v] \
    [file join $RTL compute fp ai_fp16_mul_fp32.v] \
    [file join $RTL compute fp ai_fp32_add.v] \
    [file join $RTL compute fp ai_fp32_accumulator.v] \
    [file join $RTL compute fp ai_mixed_precision_dot_fp32_core.v] \
    [file join $RTL compute fp ai_fp16_bf16_addsub.v] \
    [file join $RTL top fabric compute ai_accel_compute_cluster.v]]

set_app_var fml_mode_on true
read_verilog -rtl $RTL_FILES
read_sverilog -rtl [file join $FORMAL_DIR ai_compute_cluster_serial_formal_top.sv]
elaborate -sva ai_compute_cluster_serial_formal_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true

check_fv -property {
    ai_compute_cluster_serial_formal_top.ap_engine_busy_is_onehot0
    ai_compute_cluster_serial_formal_top.ap_core_busy_matches_engine_vector
    ai_compute_cluster_serial_formal_top.ap_opcode_classes_are_exclusive}
report_fv -usage assert -verbose
check_fv -property {
    ai_compute_cluster_serial_formal_top.cp_scalar_dispatch
    ai_compute_cluster_serial_formal_top.cp_fp_dispatch
    ai_compute_cluster_serial_formal_top.cp_banked_dispatch
    ai_compute_cluster_serial_formal_top.cp_matrix_dispatch
    ai_compute_cluster_serial_formal_top.cp_sfu_dispatch
    ai_compute_cluster_serial_formal_top.cp_conv_dispatch
    ai_compute_cluster_serial_formal_top.cp_kv_dispatch}
report_fv -usage cover -verbose
exit
