set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../..]]
set RTL [file join $ROOT rtl]
set RTL_FILES [list \
    [file join $RTL control queue ai_ring_pointer_next.v] \
    [file join $RTL control descriptor ai_descriptor_validator.v] \
    [file join $RTL control queue ai_parallel_compute_dispatcher.v]]

set_app_var fml_mode_on true
read_verilog -rtl $RTL_FILES
read_sverilog -rtl [file join $FORMAL_DIR ai_parallel_compute_dispatcher_formal_top.sv]
elaborate -sva ai_parallel_compute_dispatcher_formal_top

create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true

check_fv -property {
    ai_parallel_compute_dispatcher_formal_top.ap_launch_belongs_to_active_slot
    ai_parallel_compute_dispatcher_formal_top.ap_completion_payload_matches_retirement_head
    ai_parallel_compute_dispatcher_formal_top.ap_engine_done_requires_active_task
    ai_parallel_compute_dispatcher_formal_top.ap_abort_stops_later_launches
    ai_parallel_compute_dispatcher_formal_top.ap_abort_drains_bounded}
report_fv -usage assert -verbose

check_fv -property {
    ai_parallel_compute_dispatcher_formal_top.cp_pair_0_1
    ai_parallel_compute_dispatcher_formal_top.cp_pair_0_2
    ai_parallel_compute_dispatcher_formal_top.cp_pair_0_3
    ai_parallel_compute_dispatcher_formal_top.cp_pair_0_4
    ai_parallel_compute_dispatcher_formal_top.cp_pair_0_5
    ai_parallel_compute_dispatcher_formal_top.cp_pair_0_6
    ai_parallel_compute_dispatcher_formal_top.cp_pair_1_2
    ai_parallel_compute_dispatcher_formal_top.cp_pair_1_3
    ai_parallel_compute_dispatcher_formal_top.cp_pair_1_4
    ai_parallel_compute_dispatcher_formal_top.cp_pair_1_5
    ai_parallel_compute_dispatcher_formal_top.cp_pair_1_6
    ai_parallel_compute_dispatcher_formal_top.cp_pair_2_3
    ai_parallel_compute_dispatcher_formal_top.cp_pair_2_4
    ai_parallel_compute_dispatcher_formal_top.cp_pair_2_5
    ai_parallel_compute_dispatcher_formal_top.cp_pair_2_6
    ai_parallel_compute_dispatcher_formal_top.cp_pair_3_4
    ai_parallel_compute_dispatcher_formal_top.cp_pair_3_5
    ai_parallel_compute_dispatcher_formal_top.cp_pair_3_6
    ai_parallel_compute_dispatcher_formal_top.cp_pair_4_5
    ai_parallel_compute_dispatcher_formal_top.cp_pair_4_6
    ai_parallel_compute_dispatcher_formal_top.cp_pair_5_6
    ai_parallel_compute_dispatcher_formal_top.cp_all_seven_engines
    ai_parallel_compute_dispatcher_formal_top.cp_abort_with_active_engines}
report_fv -usage cover -verbose
exit
