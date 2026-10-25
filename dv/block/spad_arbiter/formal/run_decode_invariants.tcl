set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../..]]
set RTL [file join $ROOT rtl memory ai_spad_arbiter.v]
set TOP [file join $FORMAL_DIR ai_spad_arbiter_decode_formal_top.sv]

set_app_var fml_mode_on true
read_verilog -rtl $RTL
read_sverilog -rtl $TOP
elaborate -sva ai_spad_arbiter_decode_formal_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true

check_fv -property {
    ai_spad_arbiter_decode_formal_top.ap_idle_decode_defaults_to_dma
    ai_spad_arbiter_decode_formal_top.ap_descriptor_selection_requires_accept
    ai_spad_arbiter_decode_formal_top.ap_completion_selection_requires_accept
    ai_spad_arbiter_decode_formal_top.ap_core_selection_requires_accept
    ai_spad_arbiter_decode_formal_top.ap_banked_selection_requires_response
    ai_spad_arbiter_decode_formal_top.ap_delayed_banked_metadata_has_response
    ai_spad_arbiter_decode_formal_top.ap_line_metadata_requires_accept
    ai_spad_arbiter_decode_formal_top.ap_response_requires_accept
}
report_fv -usage assert -verbose

check_fv -property {
    ai_spad_arbiter_decode_formal_top.cp_idle_decode
    ai_spad_arbiter_decode_formal_top.cp_descriptor_selection
    ai_spad_arbiter_decode_formal_top.cp_completion_selection
    ai_spad_arbiter_decode_formal_top.cp_banked_response_selection
    ai_spad_arbiter_decode_formal_top.cp_cnm_response_selection
}
report_fv -usage cover -verbose
exit
