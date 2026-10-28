set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../../..]]
set RTL_DIR [file join $ROOT rtl compute matrix]

set_app_var fml_mode_on true
read_verilog -rtl [list \
    [file join $RTL_DIR ai_tensor_matrix_datapath.v] \
    [file join $RTL_DIR ai_tensor_matrix_array.sv] \
    [file join $RTL_DIR ai_tensor_matrix_core.v]]
read_sverilog -rtl [file join $FORMAL_DIR ai_matrix_fsm_formal_top.sv]
elaborate -sva ai_matrix_fsm_formal_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
formal_setup_config -period 10 -initial 1 -apply true
check_fv_setup -verbose
check_fv -property {
    ai_matrix_fsm_formal_top.ap_prefetch_wait_does_not_fall_back_to_a_req
    ai_matrix_fsm_formal_top.ap_idle_has_no_outstanding_reads
    ai_matrix_fsm_formal_top.ap_error_has_no_outstanding_reads
    ai_matrix_fsm_formal_top.ap_idle_does_not_enter_error_drain
    ai_matrix_fsm_formal_top.ap_error_does_not_reenter_error_drain}
report_fv -usage assert -verbose
check_fv -property {ai_matrix_fsm_formal_top.cp_prefetch_wait_reachable}
report_fv -usage cover -verbose
check_fv -property {ai_matrix_fsm_formal_top.cp_error_drain_reachable}
report_fv -usage cover -verbose
exit
