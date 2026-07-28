# CIMForge ASIC-oriented Design Compiler run using the available TSMC40
# standard-cell timing library. The scratchpad is represented by four
# replaceable 32Kx32 TDP macro black boxes in ai_scratchpad_asic_macro.v.
# This reports logic PPA and macro-boundary timing only until matching SRAM
# macro .db views are added to link_library.

set TOP ai_accel_top
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set RTL_DIR "$ROOT/rtl"
set SYN_DIR "$ROOT/syn"
set PERIOD [expr {[info exists ::env(CIMFORGE_DC_PERIOD_NS)] ? $::env(CIMFORGE_DC_PERIOD_NS) : 5.0}]
set RUN_DIR [expr {[info exists ::env(CIMFORGE_DC_RUN_DIR)] ? $::env(CIMFORGE_DC_RUN_DIR) : "$ROOT/syn/out/tsmc40_[string map {. _} $PERIOD]ns"}]

if {![info exists ::env(TSMC40_LIB_TC)] || ![file exists $::env(TSMC40_LIB_TC)]} {
    error "Set TSMC40_LIB_TC to the selected TSMC40 standard-cell .db before running DC"
}

file mkdir "$RUN_DIR/reports"
file mkdir "$RUN_DIR/netlist"
set_app_var search_path [list $SYN_DIR $RTL_DIR]
set_app_var target_library [list $::env(TSMC40_LIB_TC)]
set_app_var link_library [list "*" $::env(TSMC40_LIB_TC)]
# The foundry SRAM module is intentionally unresolved until its real macro
# view is available; preserve it as a black box rather than inferring flops.
set_app_var hdlin_unresolved_modules black_box

puts "CIMForge DC: TOP=$TOP PERIOD_NS=$PERIOD"
puts "CIMForge DC: STDCELL_DB=$::env(TSMC40_LIB_TC)"
puts "CIMForge DC: SRAM=4x32Kx32 blackbox macro boundary"

remove_design -all
analyze -format sverilog [list \
  $RTL_DIR/control/axi_lite_reg_if.v \
  $RTL_DIR/dma/axi_dma_master.v \
  $RTL_DIR/dma/ai_axi128_dma_ooo.v \
  $RTL_DIR/memory/ai_spad_protection.v \
  $RTL_DIR/memory/ai_spad_arbiter.v \
  $RTL_DIR/compute/ai_tile_pipeline.v \
  $RTL_DIR/control/ai_perf_monitor.v \
  $RTL_DIR/control/ai_command_processor.v \
  $RTL_DIR/compute/ai_bank_pe.v \
  $RTL_DIR/compute/ai_reduction_tree.v \
  $RTL_DIR/compute/ai_banked_compute_core.v \
  $RTL_DIR/compute/ai_unsigned_divider.v \
  $RTL_DIR/compute/ai_integer_sqrt.v \
  $RTL_DIR/compute/ai_tensor_matrix_core.v \
  $RTL_DIR/compute/ai_tensor_sfu_core.v \
  $RTL_DIR/compute/ai_conv3x3_linebuffer_core.v \
  $RTL_DIR/compute/ai_kv_cache_engine.v \
  $SYN_DIR/ai_scratchpad_asic_macro.v \
  $RTL_DIR/control/ai_desc_fetch.v \
  $RTL_DIR/control/axi_desc_fetch.v \
  $RTL_DIR/control/ai_completion_writer.v \
  $RTL_DIR/control/ai_accel_regs.v \
  $RTL_DIR/compute/ai_int8_compute_core.v \
  $RTL_DIR/top/ai_accel_top.v \
]
if {[catch {elaborate $TOP} elaboration_error]} {
    puts stderr "CIMForge DC elaboration failed: $elaboration_error"
    exit 2
}
current_design $TOP
if {[catch {link} link_error]} {
    puts stderr "CIMForge DC link failed: $link_error"
    exit 3
}
redirect -file "$RUN_DIR/reports/check_design.rpt" { check_design }

create_clock -name aclk -period $PERIOD [get_ports aclk]
set_clock_uncertainty 0.10 [get_clocks aclk]
set reset_ports [get_ports aresetn]
set data_inputs [remove_from_collection [all_inputs] [add_to_collection [get_ports aclk] $reset_ports]]
set_input_delay  0.20 -clock aclk $data_inputs
set_output_delay 0.20 -clock aclk [all_outputs]
set_false_path -from $reset_ports
set_fix_multiple_port_nets -all -buffer_constants
# This is a pre-layout approximation, but request min-delay repair so the
# report exposes a residual hold issue rather than silently leaving it open.
set_fix_hold [get_clocks aclk]
set_dont_touch [get_cells -hierarchical *spad_macro*]

compile_ultra
# `compile_ultra` is setup-driven by default.  A short incremental pass is
# needed to make the requested min-delay repair explicit in each DC point.
compile -incremental -only_hold_time

redirect -file "$RUN_DIR/reports/qor.rpt"       { report_qor }
redirect -file "$RUN_DIR/reports/area.rpt"      { report_area -hierarchy }
redirect -file "$RUN_DIR/reports/timing.rpt"    { report_timing -max_paths 20 }
redirect -file "$RUN_DIR/reports/hold_timing.rpt" { report_timing -delay min -max_paths 20 }
redirect -file "$RUN_DIR/reports/reference.rpt" { report_reference }
redirect -file "$RUN_DIR/reports/power.rpt"     { report_power }
write -format ddc -hierarchy -output "$RUN_DIR/netlist/$TOP.ddc"
write_file -format verilog -hierarchy -output "$RUN_DIR/netlist/${TOP}_syn.v"
puts "CIMForge DC completed: $RUN_DIR"
exit
