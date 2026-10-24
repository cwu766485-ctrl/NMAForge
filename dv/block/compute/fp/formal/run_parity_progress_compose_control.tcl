set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../../..]]
set RTL_DIR [file join $ROOT rtl compute fp]

set_app_var fml_mode_on true
read_verilog -rtl [list \
    [file join $FORMAL_DIR ai_fp_datapath_control_stubs.v] \
    [file join $RTL_DIR ai_mixed_precision_dot_fp32_core.v]]
read_sverilog -rtl \
    [file join $FORMAL_DIR ai_fp_core_parity_bounded_formal_top.sv]
elaborate -sva ai_fp_core_parity_progress_compose_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true

check_fv -property \
    ai_fp_core_parity_progress_compose_top.ap_parity_progress_stays_before_cutoff
report_fv -usage assert -verbose
exit
