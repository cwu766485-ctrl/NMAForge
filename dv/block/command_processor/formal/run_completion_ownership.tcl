set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../..]]
set RTL_DIR [file join $ROOT rtl]
set RTL_FILES [list \
    [file join $RTL_DIR control queue ai_ring_pointer_next.v] \
    [file join $RTL_DIR control descriptor ai_descriptor_validator.v] \
    [file join $RTL_DIR compute pipeline ai_tile_pipeline.v] \
    [file join $RTL_DIR control queue ai_completion_writer.v] \
    [file join $RTL_DIR control queue ai_command_processor.v]]

set_app_var fml_mode_on true
read_verilog -rtl $RTL_FILES
read_sverilog -rtl [file join $FORMAL_DIR cp_completion_ownership_formal_top.sv]
elaborate -sva cp_completion_ownership_formal_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true

check_fv -property {
    cp_completion_ownership_formal_top.ap_completion_start_owned_by_cpl
    cp_completion_ownership_formal_top.ap_completion_done_owned_by_cpl
    cp_completion_ownership_formal_top.ap_decode_abort_pending_requires_live_abort
    cp_completion_ownership_formal_top.ap_decode_compute_busy_blocks_launch
    cp_completion_ownership_formal_top.ap_tile_activity_owned_by_tile_state
    cp_completion_ownership_formal_top.ap_active_available_completion_was_reserved}
report_fv -usage assert -verbose
check_fv -property {
    cp_completion_ownership_formal_top.cp_completion_done_owned_by_cpl
    cp_completion_ownership_formal_top.cp_completion_done_with_pending_command
    cp_completion_ownership_formal_top.cp_decode_compute_busy_release_launch}
report_fv -usage cover -verbose
exit
