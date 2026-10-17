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
read_sverilog -rtl [file join $FORMAL_DIR ai_fp_core_formal_top.sv]
elaborate -sva ai_fp_core_formal_top

# Same assumptions as the canonical focused proof; no error-occurrence or
# input-data assumptions are added. Search specifically for parity pending at
# writeback so a reachable path yields a concrete trace.
create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true
check_fv -property {ai_fp_core_formal_top.cp_write_pending_parity}
report_fv -usage cover -verbose
exit
