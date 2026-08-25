set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set REPO_ROOT [file normalize "$FPGA_DIR/../.."]

if {[info exists ::env(FPGA_PART)]} {
    set PART_NAME $::env(FPGA_PART)
} else {
    set PART_NAME "xc7a100tfgg484-2"
}

source "$FPGA_DIR/filelists/ai_accel_rtl.tcl"

set BUILD_DIR "$FPGA_DIR/build/smoke_synth"
set REPORT_DIR "$BUILD_DIR/reports"
file mkdir $REPORT_DIR

read_verilog {*}$AI_ACCEL_RTL_FILES
read_verilog {*}[list \
    "$FPGA_DIR/rtl/axi_lite_bringup_master.v" \
    "$FPGA_DIR/rtl/fpga_ai_accel_smoke_top.v" \
]
read_xdc "$FPGA_DIR/constraints/a7_100t_smoke.xdc"

synth_design -top fpga_ai_accel_smoke_top -part $PART_NAME
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

report_utilization -file "$REPORT_DIR/fpga_ai_accel_smoke_top_utilization.rpt"
report_timing_summary -file "$REPORT_DIR/fpga_ai_accel_smoke_top_timing.rpt"
report_drc -file "$REPORT_DIR/fpga_ai_accel_smoke_top_drc.rpt"
report_io -file "$REPORT_DIR/fpga_ai_accel_smoke_top_io.rpt"
write_checkpoint -force "$BUILD_DIR/fpga_ai_accel_smoke_top_synth.dcp"

puts "FPGA smoke top synthesis finished for part $PART_NAME"
puts "Reports: $REPORT_DIR"
