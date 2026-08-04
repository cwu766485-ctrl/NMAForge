# Recover the export/report tail of build_board.tcl when Vivado's run dispatcher
# has completed impl_1 but the parent batch session failed to observe it.
# This script never launches synthesis, placement or routing.
set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set BUILD_DIR "$FPGA_DIR/build/board"
set REPORT_DIR "$BUILD_DIR/reports"
set PROJECT "$BUILD_DIR/cimforge_board.xpr"

if {![file exists $PROJECT]} {
    error "CIMForge board project not found: $PROJECT"
}
file mkdir $REPORT_DIR
open_project $PROJECT
open_run impl_1

report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -file "$REPORT_DIR/timing_routed.rpt"
report_utilization -hierarchical -file "$REPORT_DIR/utilization_routed.rpt"
report_drc -file "$REPORT_DIR/drc_routed.rpt"
report_methodology -file "$REPORT_DIR/methodology_routed.rpt"
report_power -file "$REPORT_DIR/power_routed.rpt"

file copy -force \
    "$BUILD_DIR/cimforge_board.runs/impl_1/cimforge_system_wrapper.bit" \
    "$BUILD_DIR/cimforge_board.bit"
write_hw_platform -fixed -include_bit -force "$BUILD_DIR/cimforge_board.xsa"
write_debug_probes -force "$BUILD_DIR/cimforge_board.ltx"

set setup_slack [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set hold_slack [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "CIMForge board routed timing: setup_slack=$setup_slack hold_slack=$hold_slack"
if {$setup_slack < 0.0 || $hold_slack < 0.0} {
    error "CIMForge board timing closure failed"
}
close_project
exit
