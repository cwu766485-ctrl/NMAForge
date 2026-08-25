# Out-of-context post-route implementation for CIMForge ai_accel_top.
# This closes internal PL timing without pretending that the IP ports are
# board-level package pins.  Board timing/DRC is checked by build_board.tcl.
set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set BUILD_DIR "$FPGA_DIR/build/ai_accel_ip_synth"
set IMPL_DIR "$FPGA_DIR/build/ai_accel_ip_impl"
set REPORT_DIR "$IMPL_DIR/reports"

file mkdir $REPORT_DIR
open_checkpoint "$BUILD_DIR/ai_accel_top_synth.dcp"

opt_design
place_design
phys_opt_design
route_design
phys_opt_design -directive AggressiveExplore

report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -file "$REPORT_DIR/timing_summary_routed.rpt"
report_timing -delay_type max -max_paths 20 -nworst 4 \
    -file "$REPORT_DIR/setup_paths.rpt"
report_timing -delay_type min -max_paths 20 -nworst 4 \
    -file "$REPORT_DIR/hold_paths.rpt"
report_utilization -hierarchical -file "$REPORT_DIR/utilization_routed.rpt"
report_drc -file "$REPORT_DIR/drc_routed.rpt"
report_methodology -file "$REPORT_DIR/methodology_routed.rpt"
report_power -file "$REPORT_DIR/power_routed.rpt"
write_checkpoint -force "$IMPL_DIR/ai_accel_top_routed.dcp"

set timing_ok [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set hold_ok [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "CIMForge OOC routed timing: setup_slack=$timing_ok hold_slack=$hold_ok"
if {$timing_ok < 0.0 || $hold_ok < 0.0} {
    error "CIMForge OOC timing closure failed"
}
