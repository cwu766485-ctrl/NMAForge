# Standalone XCZU15EG synthesis/implementation timing gate for ai_accel_top.
# Run from the repository root with Vivado 2024.1:
#   vivado -mode batch -source fpga/xczu15eg/scripts/synth_ai_accel_ip.tcl

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set REPO_ROOT [file normalize [file join $SCRIPT_DIR .. .. ..]]
set FPGA_PART [expr {[info exists ::env(FPGA_PART)] ?
                     $::env(FPGA_PART) : "xczu15eg-ffvb1156-2-i"}]
set CLOCK_PERIOD_NS [expr {[info exists ::env(CIMFORGE_FPGA_PERIOD_NS)] ?
                           $::env(CIMFORGE_FPGA_PERIOD_NS) : 10.0}]
set BUILD_DIR [expr {[info exists ::env(CIMFORGE_FPGA_BUILD_DIR)] ?
                     [file normalize $::env(CIMFORGE_FPGA_BUILD_DIR)] :
                     "$REPO_ROOT/fpga/xczu15eg/build/ai_accel_ip"}]
set REPORT_DIR "$BUILD_DIR/reports"

file mkdir $REPORT_DIR
create_project -in_memory -part $FPGA_PART
source "$REPO_ROOT/fpga/xczu15eg/ai_accel_rtl.tcl"

foreach rtl_file $AI_ACCEL_RTL_FILES {
    if {![file exists $rtl_file]} {
        error "Missing RTL source: $rtl_file"
    }
    read_verilog -sv $rtl_file
}

synth_design -top ai_accel_top -part $FPGA_PART -mode out_of_context \
             -flatten_hierarchy rebuilt
create_clock -name aclk -period $CLOCK_PERIOD_NS [get_ports aclk]
set_false_path -from [get_ports aresetn]

report_utilization -file "$REPORT_DIR/utilization_synth.rpt"
report_timing_summary -delay_type max -max_paths 20 \
                      -file "$REPORT_DIR/timing_synth.rpt"
write_checkpoint -force "$BUILD_DIR/ai_accel_top_synth.dcp"

opt_design
place_design
phys_opt_design
route_design

report_utilization -file "$REPORT_DIR/utilization_routed.rpt"
report_timing_summary -delay_type min_max -max_paths 20 \
                      -report_unconstrained \
                      -file "$REPORT_DIR/timing_routed.rpt"
report_power -file "$REPORT_DIR/power_routed.rpt"
report_drc -file "$REPORT_DIR/drc_routed.rpt"
write_checkpoint -force "$BUILD_DIR/ai_accel_top_routed.dcp"

set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
set setup_wns [expr {[llength $setup_paths] ? [get_property SLACK $setup_paths] : 0.0}]
set hold_wns [expr {[llength $hold_paths] ? [get_property SLACK $hold_paths] : 0.0}]
puts "CIMForge XCZU15EG completed: PART=$FPGA_PART PERIOD_NS=$CLOCK_PERIOD_NS"
puts "CIMForge XCZU15EG timing: SETUP_WNS_NS=$setup_wns HOLD_WNS_NS=$hold_wns"
puts "CIMForge XCZU15EG reports: $REPORT_DIR"
if {$setup_wns < 0.0 || $hold_wns < 0.0} {
    error "XCZU15EG timing did not close"
}
exit
