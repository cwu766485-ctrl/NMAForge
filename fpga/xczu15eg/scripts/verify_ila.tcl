# Attach the XSA-matched LTX to an already programmed XCZU15EG and verify that
# Vivado can discover the CIMForge debug core. This does not program flash or
# access the PS/DAP.

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set BUILD_DIR "$FPGA_DIR/build/board"
set LTX_FILE "$BUILD_DIR/cimforge_board.ltx"
set LOG_FILE "$BUILD_DIR/ila_validation.log"
if {[info exists ::env(CIMFORGE_LTX)]} {
    set LTX_FILE [file normalize $::env(CIMFORGE_LTX)]
}
if {[info exists ::env(CIMFORGE_ILA_LOG)]} {
    set LOG_FILE [file normalize $::env(CIMFORGE_ILA_LOG)]
}
if {![file exists $LTX_FILE]} {
    error "CIMForge LTX not found: $LTX_FILE"
}

set log_fd [open $LOG_FILE w]
proc log_line {message} {
    global log_fd
    puts $message
    puts $log_fd $message
    flush $log_fd
}

set failed 0
if {[catch {
    open_hw_manager
    connect_hw_server -allow_non_jtag
    open_hw_target
    set devices [get_hw_devices -quiet -filter {PART =~ "xczu15*"}]
    if {[llength $devices] != 1} {
        error "Expected one XCZU15 hardware device, found [llength $devices]"
    }
    set device [lindex $devices 0]
    set_property PROBES.FILE $LTX_FILE $device
    set_property FULL_PROBES.FILE $LTX_FILE $device
    refresh_hw_device $device
    set ilas [get_hw_ilas -quiet -of_objects $device]
    if {[llength $ilas] < 1} {
        error "No ILA discovered; program the matching bitstream and run PS/FSBL initialization so the PL0 debug-hub clock is active"
    }
    foreach ila $ilas {
        log_line "PASS ILA=[get_property NAME $ila]"
        set probes [get_hw_probes -quiet -of_objects $ila]
        log_line "INFO probes=[llength $probes]"
    }
    log_line "CIMFORGE_ILA_VALIDATION_PASS"
} failure options]} {
    log_line "CIMFORGE_ILA_VALIDATION_FAIL=$failure"
    log_line [dict get $options -errorinfo]
    set failed 1
}
catch {close_hw_target}
catch {disconnect_hw_server}
catch {close_hw_manager}
close $log_fd
if {$failed} {
    error "CIMForge ILA validation failed; see $LOG_FILE"
}
exit
