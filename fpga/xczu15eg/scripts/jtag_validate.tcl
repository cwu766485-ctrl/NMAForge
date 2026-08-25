# Program the XCZU15EG board over JTAG and run a CPU-independent hardware
# smoke test through XSCT memory accesses. The test deliberately stops A53 #0
# and writes PS DDR through the debug access port, so no cache maintenance or
# prebuilt software platform is required.

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set REPO_ROOT [file normalize "$FPGA_DIR/../.."]
set BUILD_DIR "$FPGA_DIR/build/board"

set BIT_FILE "$BUILD_DIR/cimforge_board.runs/impl_1/cimforge_system_wrapper.bit"
set PSU_INIT "$BUILD_DIR/cimforge_board.gen/sources_1/bd/cimforge_system/ip/cimforge_system_ps8_0/psu_init.tcl"
set LOG_FILE "$BUILD_DIR/hw_validation.log"
if {[info exists ::env(CIMFORGE_BIT)]} {
    set BIT_FILE [file normalize $::env(CIMFORGE_BIT)]
}
if {[info exists ::env(CIMFORGE_PSU_INIT)]} {
    set PSU_INIT [file normalize $::env(CIMFORGE_PSU_INIT)]
}
if {[info exists ::env(CIMFORGE_HW_LOG)]} {
    set LOG_FILE [file normalize $::env(CIMFORGE_HW_LOG)]
}

foreach required [list $BIT_FILE $PSU_INIT] {
    if {![file exists $required]} {
        error "Required deployment file not found: $required"
    }
}
file mkdir [file dirname $LOG_FILE]
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

proc write32 {address value} {
    mwr $address [expr {$value & 0xffffffff}]
}

proc expect32 {address expected label} {
    set actual [read32 $address]
    if {$actual != $expected} {
        error [format "%s: address=0x%08x expected=0x%08x actual=0x%08x" \
            $label $address $expected $actual]
    }
    log_line [format "PASS %-24s address=0x%08x value=0x%08x" \
        $label $address $actual]
}

proc poll_bits {address mask expected label} {
    for {set poll 0} {$poll < 2000} {incr poll} {
        set actual [read32 $address]
        if {($actual & $mask) == $expected} {
            log_line [format "PASS %-24s polls=%d value=0x%08x" \
                $label $poll $actual]
            return $actual
        }
        after 1
    }
    error [format "%s timeout: address=0x%08x mask=0x%08x last=0x%08x" \
        $label $address $mask $actual]
}

proc dma_transfer {base external scratch words store label} {
    write32 [expr {$base + 0x0b4}] 0x00000006
    write32 [expr {$base + 0x0b8}] $external
    write32 [expr {$base + 0x0bc}] $scratch
    write32 [expr {$base + 0x0c0}] $words
    write32 [expr {$base + 0x108}] 0
    write32 [expr {$base + 0x0b0}] [expr {1 | ($store ? 2 : 0)}]
    set status [poll_bits [expr {$base + 0x0b4}] 0x00000002 0x00000002 $label]
    if {$status & 0x00000004} {
        set code [read32 [expr {$base + 0x0c4}]]
        error [format "%s failed: status=0x%08x error=0x%08x" $label $status $code]
    }
}

proc run_validation {} {
    global BIT_FILE PSU_INIT

    set base       0xa0000000
    set spad       [expr {$base + 0x00010000}]
    set ddr_a      0x01000000
    set ddr_b      0x01000100
    set ddr_desc   0x01001000
    set ddr_output 0x01002000

    log_line "CIMForge XCZU15EG JTAG deployment and validation"
    log_line "BIT=$BIT_FILE"
    log_line "PSU_INIT=$PSU_INIT"

    connect -url tcp:127.0.0.1:3121
    targets -set -nocase -filter {name =~ "APU*"}
    rst -system
    after 3000

    targets -set -nocase -filter {name =~ "PSU"}
    log_line "Programming PL bitstream..."
    fpga -file $BIT_FILE
    # Evaluate the generated initialization data in the global namespace.
    # Sourcing it in this procedure would make its data lists local while the
    # generated psu_init procedure resolves them as namespace variables.
    uplevel #0 [list source $PSU_INIT]
    psu_init
    psu_ps_pl_isolation_removal
    psu_ps_pl_reset_config
    psu_post_config

    # Keep the APU in reset for this CPU-independent test. The PSU/DAP target
    # can access PS DDR and the HPM AXI aperture without an FSBL or ELF.
    targets -set -nocase -filter {name =~ "PSU"}
    configparams force-mem-access 1

    expect32 [expr {$base + 0x044}] 0x10000002 "version"
    expect32 [expr {$base + 0x164}] 0x00080000 "scratchpad capacity"

    write32 $spad 0xa5a55a5a
    expect32 $spad 0xa5a55a5a "scratchpad low word"
    set spad_last [expr {$spad + 0x0007fffc}]
    write32 $spad_last 0x5aa5c33c
    expect32 $spad_last 0x5aa5c33c "scratchpad high word"

    write32 $ddr_a 0x04030201
    write32 $ddr_b 0x08070605
    dma_transfer $base $ddr_a 0x00000000 1 0 "DMA load A"
    dma_transfer $base $ddr_b 0x00000040 1 0 "DMA load B"
    expect32 [expr {$spad + 0x000}] 0x04030201 "DMA load A data"
    expect32 [expr {$spad + 0x040}] 0x08070605 "DMA load B data"

    set descriptor [list \
        0x12340010 0x00000000 0x00000040 0x00000000 \
        0x00000080 0x00010001 0x00000001 0x00000000 \
        0x00000000 0x00000000 0x00000000 0x00000000 \
        0x00000000 0x00000000 0x00000000 0x00000000]
    set index 0
    foreach word $descriptor {
        write32 [expr {$ddr_desc + 4 * $index}] $word
        incr index
    }

    write32 [expr {$base + 0x03c}] 1
    write32 [expr {$base + 0x040}] 1
    write32 [expr {$base + 0x080}] $ddr_desc
    write32 [expr {$base + 0x084}] 0
    write32 [expr {$base + 0x088}] 2
    write32 [expr {$base + 0x08c}] 0
    write32 [expr {$base + 0x0c8}] 1
    write32 [expr {$base + 0x0ac}] 1
    write32 [expr {$base + 0x090}] 0x00002000
    write32 [expr {$base + 0x094}] 0
    write32 [expr {$base + 0x098}] 2
    write32 [expr {$base + 0x09c}] 0
    write32 [expr {$base + 0x0cc}] 0
    write32 [expr {$base + 0x0a8}] 1000000
    write32 [expr {$base + 0x0a0}] 1

    set status [poll_bits [expr {$base + 0x004}] 0x00000002 0x00000002 \
        "external CMDQ completion"]
    if {$status & 0x00000004} {
        error [format "Command failed: status=0x%08x error=0x%08x" \
            $status [read32 [expr {$base + 0x030}]]]
    }
    expect32 [expr {$spad + 0x080}] 70 "VDOT result"
    expect32 [expr {$spad + 0x2000}] 0x00001234 "completion task"
    expect32 [expr {$spad + 0x2004}] 0x00000001 "completion status"
    expect32 [expr {$spad + 0x2008}] 70 "completion result"
    expect32 [expr {$spad + 0x200c}] 1 "completion elements"
    expect32 [expr {$base + 0x03c}] 1 "IRQ sticky status"

    write32 $ddr_output 0
    dma_transfer $base $ddr_output 0x00000080 1 1 "DMA store result"
    expect32 $ddr_output 70 "DDR stored result"

    set cycles [read32 [expr {$base + 0x034}]]
    set elements [read32 [expr {$base + 0x038}]]
    log_line [format "INFO command_cycles=%u elements=%u" $cycles $elements]
    log_line "CIMFORGE_HW_VALIDATION_PASS"

    configparams force-mem-access 0
    disconnect
}

set exit_code 0
if {[catch {run_validation} failure options]} {
    log_line "CIMFORGE_HW_VALIDATION_FAIL=$failure"
    log_line [dict get $options -errorinfo]
    catch {configparams force-mem-access 0}
    catch {disconnect}
    set exit_code 1
}
close $log_fd
if {$exit_code != 0} {
    error "CIMForge board validation failed; see $LOG_FILE"
}
exit
