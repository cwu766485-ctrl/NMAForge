# CIMForge TSMC28 HPC+ DC profile with real SRAM macro timing/area.
# Required environment: TSMC28_STDCELL_DB and TSMC28_SRAM_DB_TT.

set TOP ai_accel_top
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set RTL_DIR "$ROOT/rtl"
set SYN_DIR "$ROOT/syn"
set PERIOD [expr {[info exists ::env(CIMFORGE_DC_PERIOD_NS)] ? $::env(CIMFORGE_DC_PERIOD_NS) : 4.0}]
set RUN_DIR [expr {[info exists ::env(CIMFORGE_DC_RUN_DIR)] ? $::env(CIMFORGE_DC_RUN_DIR) : "$ROOT/syn/out/tsmc28_[string map {. _} $PERIOD]ns"}]
set SAIF_FILE [expr {[info exists ::env(CIMFORGE_SAIF)] ? $::env(CIMFORGE_SAIF) : ""}]
set SAIF_INSTANCE [expr {[info exists ::env(CIMFORGE_SAIF_INSTANCE)] ? $::env(CIMFORGE_SAIF_INSTANCE) : ""}]

foreach required_var {TSMC28_STDCELL_DB TSMC28_SRAM_DB_TT} {
    if {![info exists ::env($required_var)] || ![file exists $::env($required_var)]} {
        error "Set $required_var to a matching TSMC28 nominal-PVT library view before running DC"
    }
    set lib_tail [file tail $::env($required_var)]
    if {$lib_tail eq "your_library.db" || $lib_tail eq "gtech.db" || $lib_tail eq "dw_foundation.sldb"} {
        error "$required_var points to a generic/placeholder library ($lib_tail); provide the real TSMC28 .db"
    }
}
file mkdir "$RUN_DIR/reports"
file mkdir "$RUN_DIR/netlist"
set_app_var search_path [list $SYN_DIR $RTL_DIR]
set_app_var target_library [list $::env(TSMC28_STDCELL_DB)]
set_app_var link_library [list "*" $::env(TSMC28_STDCELL_DB) $::env(TSMC28_SRAM_DB_TT)]

# A readable .db can still be a broken/partial conversion.  Fail before
# compile if the target library cannot map the basic cells needed by DC.
set inv_cells [get_lib_cells -quiet */INVD1BWP7T40P140]
if {[sizeof_collection $inv_cells] == 0} {
    error "TSMC28_STDCELL_DB does not contain INVD1BWP7T40P140; use the complete TSMC28 RVT standard-cell .db"
}
set seq_cells [get_lib_cells -quiet */DFCNQD1BWP7T40P140]
if {[sizeof_collection $seq_cells] == 0} {
    error "TSMC28_STDCELL_DB does not contain DFCNQD1BWP7T40P140; use the complete TSMC28 RVT standard-cell .db"
}
set sram_cells [get_lib_cells -quiet */TS1N28HPCPL2SVTB4096X32M4MWBASO]
if {[sizeof_collection $sram_cells] == 0} {
    error "TSMC28_SRAM_DB_TT does not contain TS1N28HPCPL2SVTB4096X32M4MWBASO; use the matching SRAM macro .db"
}

puts "CIMForge DC TSMC28: TOP=$TOP PERIOD_NS=$PERIOD"
puts "CIMForge DC TSMC28: STDCELL_DB=$::env(TSMC28_STDCELL_DB)"
puts "CIMForge DC TSMC28: SRAM_DB=$::env(TSMC28_SRAM_DB_TT)"
puts "CIMForge DC TSMC28: SRAM=32x TS1N28HPCPL2SVTB4096X32M4MWBASO"

remove_design -all
analyze -format sverilog [list \
  $RTL_DIR/control/axi_lite_reg_if.v \
  $RTL_DIR/dma/ai_axi128_dma.v \
  $RTL_DIR/memory/ai_spad_protection.v \
  $RTL_DIR/memory/ai_spad_arbiter.v \
  $RTL_DIR/compute/ai_tile_pipeline.v \
  $RTL_DIR/control/ai_perf_monitor.v \
  $RTL_DIR/control/ai_command_processor.v \
  $RTL_DIR/compute/ai_bank_pe.v \
  $RTL_DIR/compute/ai_reduction_tree.v \
  $RTL_DIR/compute/ai_banked_compute_core.v \
  $RTL_DIR/compute/ai_bank_local_controller.v \
  $RTL_DIR/compute/ai_banked_cnm_core.v \
  $RTL_DIR/compute/ai_unsigned_divider.v \
  $RTL_DIR/compute/ai_integer_sqrt.v \
  $RTL_DIR/compute/ai_tensor_matrix_core.v \
  $RTL_DIR/compute/ai_tensor_sfu_core.v \
  $RTL_DIR/compute/ai_conv3x3_linebuffer_core.v \
  $RTL_DIR/compute/ai_kv_cache_engine.v \
  $SYN_DIR/ai_scratchpad_28nm_macro.v \
  $RTL_DIR/control/ai_desc_fetch.v \
  $RTL_DIR/control/axi_desc_fetch.v \
  $RTL_DIR/control/ai_completion_writer.v \
  $RTL_DIR/control/ai_accel_regs.v \
  $RTL_DIR/compute/ai_int8_compute_core.v \
  $RTL_DIR/top/ai_accel_top.v \
]
if {[catch {elaborate $TOP} elaboration_error]} {
    puts stderr "CIMForge TSMC28 DC elaboration failed: $elaboration_error"
    exit 2
}
current_design $TOP
if {[catch {link} link_error]} {
    puts stderr "CIMForge TSMC28 DC link failed: $link_error"
    exit 3
}
redirect -file "$RUN_DIR/reports/check_design.rpt" { check_design }

create_clock -name aclk -period $PERIOD [get_ports aclk]
# Keep the 100 ps setup guard band, but do not apply it wholesale to hold.
# Before CTS there is no extracted skew; retain a small 20 ps min-delay guard
# and defer final hold closure to post-layout OCV/RC STA.
set_clock_uncertainty -setup 0.10 [get_clocks aclk]
set_clock_uncertainty -hold  0.02 [get_clocks aclk]
set reset_ports [get_ports aresetn]
set data_inputs [remove_from_collection [all_inputs] [add_to_collection [get_ports aclk] $reset_ports]]
set_input_delay 0.20 -clock aclk $data_inputs
set_output_delay 0.20 -clock aclk [all_outputs]
set_false_path -from $reset_ports
set_fix_multiple_port_nets -all -buffer_constants
set_fix_hold [get_clocks aclk]
# The macro wrapper carries a synthesizer dont_touch attribute on each hard
# SRAM instance.  Do not use a broad hierarchical name match here: it can
# accidentally freeze surrounding glue logic and corrupt the PPA estimate.

compile_ultra
compile -incremental -only_hold_time

# Do not silently call a default-activity report a measured-power result.
# When a SAIF from `make ai_smoke_saif` is supplied, annotate it after
# synthesis and report its activity in the run log.  The instance path must
# name the synthesized design hierarchy (normally ai_accel_top); conversion
# tools may already have stripped the testbench wrapper.
if {$SAIF_FILE ne ""} {
    if {![file exists $SAIF_FILE]} {
        error "CIMFORGE_SAIF does not exist: $SAIF_FILE"
    }
    if {$SAIF_INSTANCE eq ""} {
        set SAIF_INSTANCE $TOP
    }
    # The VCS SAIF is captured below tb_ai_accel_smoke/dut, while synthesis
    # operates on ai_accel_top and may rename registers/nets.  Apply the SAIF
    # at the synthesized top and let DC map equivalent RTL/net names.
    read_saif -input $SAIF_FILE -instance $SAIF_INSTANCE -auto_map_names
    puts "CIMForge DC activity: measured SAIF=$SAIF_FILE instance=$SAIF_INSTANCE"
    redirect -file "$RUN_DIR/reports/saif_activity.rpt" {
        report_switching_activity -list_not_annotated
    }
} else {
    puts "CIMForge DC activity: no SAIF supplied; power.rpt uses tool default activity and is not a measured-power result"
}

redirect -file "$RUN_DIR/reports/qor.rpt" { report_qor }
redirect -file "$RUN_DIR/reports/area.rpt" { report_area -hierarchy }
redirect -file "$RUN_DIR/reports/timing.rpt" { report_timing -max_paths 20 }
redirect -file "$RUN_DIR/reports/hold_timing.rpt" { report_timing -delay min -max_paths 20 }
redirect -file "$RUN_DIR/reports/reference.rpt" { report_reference }
redirect -file "$RUN_DIR/reports/power.rpt" { report_power }
write -format ddc -hierarchy -output "$RUN_DIR/netlist/$TOP.ddc"
write_file -format verilog -hierarchy -output "$RUN_DIR/netlist/${TOP}_syn.v"
puts "CIMForge TSMC28 DC completed: $RUN_DIR"
exit
