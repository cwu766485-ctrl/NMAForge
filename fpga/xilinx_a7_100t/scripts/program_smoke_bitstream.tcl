set SCRIPT_DIR [file normalize [file dirname [info script]]]

if {![info exists ::env(FPGA_BITSTREAM)]} {
    error "FPGA_BITSTREAM is not set. Use run_vivado_synth.ps1 -Target program."
}

set BITSTREAM [file normalize $::env(FPGA_BITSTREAM)]
if {![file exists $BITSTREAM]} {
    error "Bitstream does not exist: $BITSTREAM"
}

if {[info exists ::env(VIVADO_HW_SERVER_URL)]} {
    set HW_SERVER_URL $::env(VIVADO_HW_SERVER_URL)
} else {
    set HW_SERVER_URL "localhost:3121"
}

open_hw_manager
connect_hw_server -url $HW_SERVER_URL
open_hw_target

set HW_DEVICES [get_hw_devices]
if {[llength $HW_DEVICES] == 0} {
    close_hw_manager
    error "No JTAG FPGA device found. Check board power, USB-JTAG cable, and HW_SERVER_URL."
}
if {[llength $HW_DEVICES] != 1} {
    set DEVICE_NAMES {}
    foreach DEVICE $HW_DEVICES {
        lappend DEVICE_NAMES [get_property PART $DEVICE]
    }
    close_hw_manager
    error "Expected one JTAG FPGA device; found [llength $HW_DEVICES]: $DEVICE_NAMES"
}

set HW_DEVICE [lindex $HW_DEVICES 0]
set_property PROGRAM.FILE $BITSTREAM $HW_DEVICE
program_hw_devices $HW_DEVICE
refresh_hw_device $HW_DEVICE

puts "Programmed [get_property PART $HW_DEVICE] with $BITSTREAM"
close_hw_manager
