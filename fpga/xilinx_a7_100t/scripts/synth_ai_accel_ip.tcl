set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set REPO_ROOT [file normalize "$FPGA_DIR/../.."]

if {[info exists ::env(FPGA_PART)]} {
    set PART_NAME $::env(FPGA_PART)
} else {
    set PART_NAME "xc7a100tfgg484-2"
}

source "$FPGA_DIR/filelists/ai_accel_rtl.tcl"

set BUILD_DIR "$FPGA_DIR/build/ip_synth"
set REPORT_DIR "$BUILD_DIR/reports"
file mkdir $REPORT_DIR

read_verilog {*}$AI_ACCEL_RTL_FILES
synth_design -top ai_accel_top -part $PART_NAME -generic SPAD_WORDS_PER_BANK=4096

create_clock -name aclk -period 10.000 [get_ports aclk]

report_utilization -file "$REPORT_DIR/ai_accel_top_utilization.rpt"
report_timing_summary -file "$REPORT_DIR/ai_accel_top_timing.rpt"
report_drc -file "$REPORT_DIR/ai_accel_top_drc.rpt"
write_checkpoint -force "$BUILD_DIR/ai_accel_top_synth.dcp"

puts "AI accelerator IP synthesis finished for part $PART_NAME"
puts "Reports: $REPORT_DIR"
