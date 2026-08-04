# CIMForge XCZU15EG PS/PL integration and bitstream flow.
#
# The board has a custom ZynqMP PS DDR/MIO layout.  Rather than guessing that
# configuration, this script clones the configured PS cell from the vendor
# mem_test project under docs/hardware/xczu15eg, then enables only the PL
# interfaces needed by CIMForge.
set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set REPO_ROOT [file normalize "$FPGA_DIR/../.."]
set PART_NAME "xczu15eg-ffvb1156-2-i"
set BUILD_DIR "$FPGA_DIR/build/board"
set REPORT_DIR "$BUILD_DIR/reports"
set VENDOR_XPR "$REPO_ROOT/docs/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.xpr"
if {[info exists ::env(CIMFORGE_VENDOR_XPR)]} {
    set VENDOR_XPR [file normalize $::env(CIMFORGE_VENDOR_XPR)]
}
if {![file exists $VENDOR_XPR]} {
    error "Vendor PS reference project not found: $VENDOR_XPR"
}

# Capture every configured PS property from the board-vendor reference.
open_project $VENDOR_XPR -quiet
set vendor_bd [get_files -quiet */design_1.bd]
if {[llength $vendor_bd] == 0} {
    error "No design_1.bd found in vendor project: $VENDOR_XPR"
}
open_bd_design [lindex $vendor_bd 0] -quiet
set vendor_ps [get_bd_cells -quiet -filter {VLNV =~ "xilinx.com:ip:zynq_ultra_ps_e:*"}]
if {[llength $vendor_ps] != 1} {
    error "Expected one ZynqMP PS cell in vendor design"
}
set ps_config [list]
foreach prop [list_property $vendor_ps] {
    if {[string match "CONFIG.*" $prop]} {
        # Derived frequency/interrupt-count fields and Component_Name are
        # read-only in Vivado 2024.1.  Their values are recomputed after the
        # writable board configuration is applied.
        if {[string match "CONFIG.Component_Name" $prop] ||
            [string match "CONFIG.PSU__M_AXI_GP*__FREQMHZ" $prop] ||
            [string match "CONFIG.PSU__S_AXI_GP*__FREQMHZ" $prop] ||
            [string match "CONFIG.PSU__NUM_F2P*__INTR__INPUTS" $prop] ||
            [string match "CONFIG.PSU__TSU__BUFG_PORT_LOOPBACK" $prop]} {
            continue
        }
        set value [get_property $prop $vendor_ps]
        if {$value ne ""} {
            lappend ps_config $prop $value
        }
    }
}
close_project

file mkdir $BUILD_DIR
file mkdir $REPORT_DIR
create_project -force cimforge_board $BUILD_DIR -part $PART_NAME
set_property target_language Verilog [current_project]
source "$FPGA_DIR/filelists/ai_accel_rtl.tcl"
add_files -norecurse $AI_ACCEL_RTL_FILES
update_compile_order -fileset sources_1

create_bd_design cimforge_system
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:* ps8]
set_property -dict $ps_config $ps
# PL0 is the single 100 MHz clock domain. GP0 is M_AXI_HPM0_FPD; GP2 is
# S_AXI_HP0_FPD on ZynqMP. IRQ0 feeds pl_ps_irq0.
set_property -dict [list \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__USE__IRQ0 {1}] $ps

set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst_pl]
# Match the board vendor's proven PS->PL control topology. AXI Interconnect
# performs the HPM0 AXI4-to-accelerator AXI4-Lite/data-width conversion with
# explicit per-interface clock/reset pins, which are also easier to inspect
# during first-silicon bring-up than SmartConnect's internal clock mapper.
set ctrl_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:* ctrl_ic]
set data_smc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:* data_smc]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $ctrl_ic
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1} CONFIG.NUM_CLKS {1}] $data_smc
set irq_concat [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:* irq_concat]
set_property CONFIG.NUM_PORTS {1} $irq_concat
set ila [create_bd_cell -type ip -vlnv xilinx.com:ip:ila:* ila_accel]
set_property -dict [list CONFIG.C_NUM_OF_PROBES {9} CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_EN_STRG_QUAL {1} CONFIG.C_ADV_TRIGGER {true}] $ila
set ctrl_ila [create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:* system_ila_ctrl]
set_property -dict [list CONFIG.C_NUM_MONITOR_SLOTS {2} CONFIG.C_DATA_DEPTH {4096}] $ctrl_ila

# ai_accel_top carries explicit X_INTERFACE metadata, so Vivado exposes S_AXI
# and M_AXI as module-reference interfaces.
set accel [create_bd_cell -type module -reference ai_accel_top accel_0]

connect_bd_intf_net [get_bd_intf_pins ps8/M_AXI_HPM0_FPD] [get_bd_intf_pins ctrl_ic/S00_AXI]
connect_bd_intf_net -intf_net ctrl_axi_lite \
    [get_bd_intf_pins ctrl_ic/M00_AXI] [get_bd_intf_pins accel_0/S_AXI]
connect_bd_intf_net -intf_net ctrl_axi_lite \
    [get_bd_intf_pins accel_0/S_AXI] [get_bd_intf_pins system_ila_ctrl/SLOT_0_AXI]
connect_bd_intf_net -intf_net data_axi \
    [get_bd_intf_pins accel_0/M_AXI] [get_bd_intf_pins data_smc/S00_AXI]
connect_bd_intf_net -intf_net data_axi \
    [get_bd_intf_pins accel_0/M_AXI] [get_bd_intf_pins system_ila_ctrl/SLOT_1_AXI]
connect_bd_intf_net [get_bd_intf_pins data_smc/M00_AXI] [get_bd_intf_pins ps8/S_AXI_HP0_FPD]

connect_bd_net [get_bd_pins ps8/pl_clk0] \
    [get_bd_pins ps8/maxihpm0_fpd_aclk] \
    [get_bd_pins ps8/saxihp0_fpd_aclk] \
    [get_bd_pins rst_pl/slowest_sync_clk] \
    [get_bd_pins ctrl_ic/ACLK] \
    [get_bd_pins ctrl_ic/S00_ACLK] \
    [get_bd_pins ctrl_ic/M00_ACLK] \
    [get_bd_pins data_smc/aclk] \
    [get_bd_pins accel_0/aclk] \
    [get_bd_pins system_ila_ctrl/clk]
connect_bd_net [get_bd_pins ps8/pl_resetn0] [get_bd_pins rst_pl/ext_reset_in]
connect_bd_net [get_bd_pins rst_pl/peripheral_aresetn] \
    [get_bd_pins ctrl_ic/ARESETN] \
    [get_bd_pins ctrl_ic/S00_ARESETN] \
    [get_bd_pins ctrl_ic/M00_ARESETN] \
    [get_bd_pins data_smc/aresetn] \
    [get_bd_pins accel_0/aresetn] \
    [get_bd_pins system_ila_ctrl/resetn]
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins irq_concat/In0]
connect_bd_net [get_bd_pins irq_concat/dout] [get_bd_pins ps8/pl_ps_irq0]
# Native ILA probes must not attach to any member of a module-reference AXI
# interface.  Even an accelerator-driven output such as S_AXI/BVALID is
# detached from the interface net when it is also connected as a scalar pin.
# Complete AXI response-side monitoring is therefore owned by System ILA.
# Internal scheduler state remains visible through register/perf readback.
connect_bd_net [get_bd_pins ps8/pl_clk0] [get_bd_pins ila_accel/clk]
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins ila_accel/probe0]
# Keep the native ILA strictly on non-interface health/status signals.  The
# duplicated IRQ probes preserve its configured widths without touching AXI;
# both complete AXI interfaces are monitored by the two System ILA slots.
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins ila_accel/probe1]
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins ila_accel/probe2]
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins ila_accel/probe3]
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins ila_accel/probe4]
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins ila_accel/probe5]
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins ila_accel/probe6]
connect_bd_net [get_bd_pins accel_0/irq] [get_bd_pins ila_accel/probe7]
connect_bd_net [get_bd_pins rst_pl/peripheral_aresetn] [get_bd_pins ila_accel/probe8]

assign_bd_address
# Reserve a 1 MiB power-of-two aperture: the register page starts at offset 0,
# and the default 512 KiB scratchpad occupies 0x10000..0x8ffff.
set ps_data [get_bd_addr_spaces ps8/Data]
set accel_ctrl_segs [get_bd_addr_segs -of_objects $ps_data -filter {NAME =~ "*accel_0*"}]
if {[llength $accel_ctrl_segs] != 1} {
    error "Expected one PS-visible accelerator control segment, got: $accel_ctrl_segs"
}
assign_bd_address -force -target_address_space $ps_data \
    -offset 0xA0000000 -range 1M [lindex $accel_ctrl_segs 0]

validate_bd_design
save_bd_design
set wrapper_files [make_wrapper -files [get_files cimforge_system.bd] -top]
add_files -norecurse $wrapper_files
set_property top cimforge_system_wrapper [current_fileset]
update_compile_order -fileset sources_1

if {[info exists ::env(CIMFORGE_VALIDATE_ONLY)] &&
    $::env(CIMFORGE_VALIDATE_ONLY) ne "0"} {
    puts "CIMForge board block design validation completed."
    exit
}

generate_target all [get_files cimforge_system.bd]
launch_runs synth_1 -jobs 8
wait_on_run synth_1
open_run synth_1
report_utilization -hierarchical -file "$REPORT_DIR/utilization_synth.rpt"
report_timing_summary -file "$REPORT_DIR/timing_synth.rpt"
report_drc -file "$REPORT_DIR/drc_synth.rpt"
close_design

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
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
