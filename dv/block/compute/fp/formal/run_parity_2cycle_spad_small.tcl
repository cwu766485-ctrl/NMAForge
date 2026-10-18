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
read_sverilog -rtl [file join $FORMAL_DIR ai_fp_core_parity_2cycle_spad_formal_top.sv]
elaborate -sva ai_fp_core_parity_2cycle_spad_small_formal_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true

if {[info exists ::env(PARITY_FORMAL_COVERS)]} {
    set CHECK_COVERS {}
    foreach COVER_NAME [split $::env(PARITY_FORMAL_COVERS) ","] {
        lappend CHECK_COVERS \
            "ai_fp_core_parity_2cycle_spad_small_formal_top.core.${COVER_NAME}"
    }
    check_fv -property $CHECK_COVERS
    report_fv -usage cover -verbose
} else {
    if {[info exists ::env(PARITY_FORMAL_PROPERTIES)]} {
        set CHECK_PROPERTIES {}
        foreach PROPERTY_NAME [split $::env(PARITY_FORMAL_PROPERTIES) ","] {
            lappend CHECK_PROPERTIES \
                "ai_fp_core_parity_2cycle_spad_small_formal_top.core.${PROPERTY_NAME}"
        }
    } else {
        set CHECK_PROPERTIES [list \
            ai_fp_core_parity_2cycle_spad_small_formal_top.core.ap_final_pair_not_ready_on_parity_response]
    }
    check_fv -property $CHECK_PROPERTIES
    report_fv -usage assert -verbose
}
exit
