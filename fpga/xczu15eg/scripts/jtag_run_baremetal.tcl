# Program the board, run the XSA-matched FSBL, download the NMAForge A53
# bring-up ELF, and independently check its exit status/register aftermath.

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set BUILD_DIR "$FPGA_DIR/build"
set BIT_FILE "$BUILD_DIR/board/cimforge_board.runs/impl_1/cimforge_system_wrapper.bit"
set XSA_FILE "$BUILD_DIR/board/cimforge_board.xsa"
set FSBL_FILE "$BUILD_DIR/baremetal/cimforge_fsbl.elf"
set APP_FILE "$BUILD_DIR/baremetal/cimforge_bringup.elf"
set LOG_FILE "$BUILD_DIR/board/baremetal_jtag.log"
set PSU_INIT "$BUILD_DIR/board/cimforge_board.gen/sources_1/bd/cimforge_system/ip/cimforge_system_ps8_0/psu_init.tcl"
set NM_TOOL ""

foreach {env_name variable_name} {
    NMAFORGE_BIT BIT_FILE
    NMAFORGE_XSA XSA_FILE
    NMAFORGE_FSBL FSBL_FILE
    NMAFORGE_APP APP_FILE
    NMAFORGE_JTAG_LOG LOG_FILE
    NMAFORGE_NM NM_TOOL
} {
    if {[info exists ::env($env_name)]} {
        set $variable_name [file normalize $::env($env_name)]
    }
}
foreach required [list $BIT_FILE $XSA_FILE $FSBL_FILE $APP_FILE $PSU_INIT $NM_TOOL] {
if {$NM_TOOL eq ""} {
    error "Set NMAFORGE_NM to the local aarch64-none-elf-nm executable"
}
    if {![file exists $required]} {
        error "Required deployment file not found: $required"
    }
}

set log_fd [open $LOG_FILE w]
proc log_line {message} {
    global log_fd
    puts $message
    puts $log_fd $message
    flush $log_fd
}
proc read32 {address} {
    return [expr {[mrd -value $address] & 0xffffffff}]
}
proc expect32 {address expected label} {
    set actual [read32 $address]
    if {$actual != $expected} {
        error [format "%s: expected=0x%08x actual=0x%08x" \
            $label $expected $actual]
    }
    log_line [format "PASS %-24s value=0x%08x" $label $actual]
}

proc run_baremetal {} {
    global BIT_FILE XSA_FILE FSBL_FILE APP_FILE PSU_INIT NM_TOOL
    log_line "CIMForge XCZU15EG FSBL and bare-metal deployment"
    connect -url tcp:127.0.0.1:3121

    targets -set -nocase -filter {name =~ "APU*"}
    rst -system
    after 3000

    # On ZynqMP both PS TAP and PSU may be reported at target level 0 after a
    # system reset. Select the unique PSU explicitly before configuring PL.
    targets -set -nocase -filter {name =~ "PSU"}
    fpga -file $BIT_FILE
    targets -set -nocase -filter {name =~ "APU*"}
    loadhw -hw $XSA_FILE -mem-ranges [list \
        {0x80000000 0xbfffffff} \
        {0x400000000 0x5ffffffff} \
        {0x1000000000 0x7fffffffff}] -regs
    configparams force-mem-access 1

    targets -set -nocase -filter {name =~ "*A53*#0"}
    rst -processor
    dow $FSBL_FILE
    set fsbl_bp [bpadd -addr &XFsbl_Exit]
    con -block -timeout 60
    bpremove $fsbl_bp
    log_line "PASS FSBL reached XFsbl_Exit"

    # The bitstream is programmed separately over JTAG, so this FSBL has no PL
    # partition to hand off and does not reliably remove PS/PL isolation.  Run
    # the XSA-matched post-configuration sequence before the A53 touches HPM0.
    uplevel #0 [list source $PSU_INIT]
    psu_ps_pl_isolation_removal
    psu_ps_pl_reset_config
    psu_post_config
    log_line "PASS PS/PL isolation removed and PL reset released"

    rst -processor
    dow $APP_FILE
    set exit_bp [bpadd -addr &_exit]
    configparams force-mem-access 0
    con -block -timeout 60
    bpremove $exit_bp
    # The standalone startup calls __libc_fini_array after main and therefore
    # does not preserve main's return value in r0 at the _exit breakpoint.
    # The application publishes and flushes an explicit DDR result instead.
    configparams force-mem-access 1
    set symbols [exec $NM_TOOL -g $APP_FILE]
    if {![regexp -line -nocase \
          {^([0-9a-f]+)\s+\S+\s+cimforge_validation_result$} \
          $symbols -> result_hex]} {
        error "Unable to locate cimforge_validation_result in application ELF"
    }
    scan $result_hex %x result_address
    set app_result [read32 $result_address]
    log_line [format "INFO application_return=%u" $app_result]
    if {$app_result != 0} {
        error "CIMForge bare-metal application returned $app_result"
    }

    # Post-run checks use DAP/PSU access; the A53 target's default memory map
    # rejects PL AXI apertures after force-mem-access is disabled for execution.
    targets -set -nocase -filter {name =~ "PSU"}
    expect32 0xa0000044 0x10000002 "version after ELF"
    expect32 0xa0000164 0x00080000 "capacity after ELF"
    expect32 0xa000003c 0x00000000 "IRQ cleared by ISR"
    log_line "CIMFORGE_BAREMETAL_PASS"
    configparams force-mem-access 0
    disconnect
}

set failed 0
if {[catch {run_baremetal} failure options]} {
    log_line "CIMFORGE_BAREMETAL_FAIL=$failure"
    log_line [dict get $options -errorinfo]
    catch {disconnect}
    set failed 1
}
close $log_fd
if {$failed} {
    error "CIMForge bare-metal deployment failed; see $LOG_FILE"
}
exit
