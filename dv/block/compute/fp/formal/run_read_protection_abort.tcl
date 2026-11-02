set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../../..]]
set RTL_DIR [file join $ROOT rtl compute fp]

set RTL_FILES [list \
    [file join $RTL_DIR ai_bf16_mul_fp32.v] \
    [file join $RTL_DIR ai_fp16_mul_fp32.v] \
    [file join $RTL_DIR ai_fp32_add.v] \
    [file join $RTL_DIR ai_fp32_accumulator.v] \
    [file join $RTL_DIR ai_mixed_precision_dot_fp32_core.v]]

set_app_var fml_mode_on true
read_verilog -rtl $RTL_FILES
read_sverilog -rtl [file join $FORMAL_DIR ai_fp_read_protection_abort_formal_top.sv]
elaborate -sva ai_fp_read_protection_abort_formal_top

# Reset the real production core. Abort, SPAD ready, and Protection are left
# unconstrained; no accepted-read or error assumption is added to obtain the
# structural exclusion.
create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
formal_setup_config -period 10 -initial 1 -apply true
check_fv_setup -verbose
check_fv -property {
    ai_fp_read_protection_abort_formal_top.ap_abort_blocks_read_accept
    ai_fp_read_protection_abort_formal_top.ap_abort_blocks_read_protection_failure}
report_fv -usage assert -verbose
check_fv -property {
    ai_fp_read_protection_abort_formal_top.cp_abort_protection_attempt_reachable
    ai_fp_read_protection_abort_formal_top.cp_read_protection_failure_reachable}
report_fv -usage cover -verbose
exit
