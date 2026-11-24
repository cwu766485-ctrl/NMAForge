set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../../..]]
set RTL_DIR [file join $ROOT rtl compute matrix]

set_app_var fml_mode_on true
read_verilog -rtl [list \
    [file join $RTL_DIR ai_tensor_matrix_datapath.v] \
    [file join $RTL_DIR ai_tensor_matrix_array.sv] \
    [file join $RTL_DIR ai_tensor_matrix_core.v]]
read_sverilog -rtl [file join $FORMAL_DIR ai_matrix_overlap_formal_top.sv]
elaborate -sva ai_matrix_overlap_formal_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
formal_setup_config -period 10 -initial 1 -apply true
check_fv_setup -verbose
check_fv -property {
    ai_matrix_overlap_formal_top.ap_overlap_writer_has_legal_owner
    ai_matrix_overlap_formal_top.ap_overlap_stalled_line_is_stable
    ai_matrix_overlap_formal_top.ap_overlap_wait_preserves_accumulator
    ai_matrix_overlap_formal_top.ap_overlap_launch_claims_buffer}
report_fv -usage assert -verbose
check_fv -property {
    ai_matrix_overlap_formal_top.cp_overlap_mac_and_writeback
    ai_matrix_overlap_formal_top.cp_overlap_second_tile_waits_for_owner
    ai_matrix_overlap_formal_top.cp_overlap_stalled_buffered_line}
report_fv -usage cover -verbose
exit
