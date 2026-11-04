set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../..]]
set RTL [file join $ROOT rtl memory ai_spad_arbiter.v]
set TOP [file join $FORMAL_DIR ai_spad_arbiter_fairness_formal_top.sv]

set_app_var fml_mode_on true
read_verilog -rtl $RTL
read_sverilog -rtl $TOP
elaborate -sva ai_spad_arbiter_fairness_formal_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true

check_fv -property {
    ai_spad_arbiter_fairness_formal_top.ap_core_class_progress_within_two
    ai_spad_arbiter_fairness_formal_top.ap_dma_class_progress_within_two
    ai_spad_arbiter_fairness_formal_top.ap_matrix_banked_progress_within_five
    ai_spad_arbiter_fairness_formal_top.ap_cnm_progress_within_five
    ai_spad_arbiter_fairness_formal_top.ap_data_plane_grant_is_exclusive
}
report_fv -usage assert -verbose

check_fv -property {
    ai_spad_arbiter_fairness_formal_top.cp_core_scalar_grant
    ai_spad_arbiter_fairness_formal_top.cp_core_line_grant
    ai_spad_arbiter_fairness_formal_top.cp_matrix_grant_while_cnm_pending
    ai_spad_arbiter_fairness_formal_top.cp_cnm_grant_while_matrix_pending
    ai_spad_arbiter_fairness_formal_top.cp_dma_scalar_grant
    ai_spad_arbiter_fairness_formal_top.cp_dma_line_grant
}
report_fv -usage cover -verbose
exit
