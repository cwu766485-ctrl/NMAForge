# Generate an A53 standalone application skeleton and an FSBL directly from
# the board XSA. This HSI-only flow works with the Vitis embedded installer;
# it does not require the removed Classic Vitis IDE.

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set FPGA_DIR [file normalize "$SCRIPT_DIR/.."]
set REPO_ROOT [file normalize "$FPGA_DIR/../.."]
set XSA_FILE "$FPGA_DIR/build/board/cimforge_board.xsa"
set OUTPUT_DIR "$FPGA_DIR/build/baremetal"
if {[info exists ::env(CIMFORGE_XSA)]} {
    set XSA_FILE [file normalize $::env(CIMFORGE_XSA)]
}
if {[info exists ::env(CIMFORGE_SW_BUILD)]} {
    set OUTPUT_DIR [file normalize $::env(CIMFORGE_SW_BUILD)]
}
if {![file exists $XSA_FILE]} {
    error "CIMForge board XSA not found: $XSA_FILE"
}

file mkdir $OUTPUT_DIR
hsi::open_hw_design $XSA_FILE

hsi::create_sw_design cimforge_bringup_sw -proc psu_cortexa53_0 \
    -os standalone -app empty_application
hsi::generate_app -sw cimforge_bringup_sw -dir "$OUTPUT_DIR/bringup" \
    -app empty_application
hsi::close_sw_design cimforge_bringup_sw

hsi::create_sw_design cimforge_fsbl_sw -proc psu_cortexa53_0 \
    -os standalone -app zynqmp_fsbl
hsi::generate_app -sw cimforge_fsbl_sw -dir "$OUTPUT_DIR/fsbl" \
    -app zynqmp_fsbl -compile
hsi::close_sw_design cimforge_fsbl_sw

hsi::close_hw_design [hsi::current_hw_design]

set bringup_dir "$OUTPUT_DIR/bringup"
file copy -force "$REPO_ROOT/sw/baremetal/cimforge_bringup.c" $bringup_dir
file copy -force "$REPO_ROOT/sw/include/cimforge_regs.h" $bringup_dir

# Keep all application code and its static DMA/descriptor buffers below 4 GiB,
# while leaving low DDR clear for exception/null-pointer diagnostics.
set linker_file "$bringup_dir/lscript.ld"
set linker_fd [open $linker_file r]
set linker_text [read $linker_fd]
close $linker_fd
set old_region {psu_ddr_0_MEM_0 : ORIGIN = 0x0, LENGTH = 0x7FF00000}
set new_region {psu_ddr_0_MEM_0 : ORIGIN = 0x100000, LENGTH = 0x7FE00000}
if {[string first $old_region $linker_text] < 0} {
    error "Unexpected generated linker memory map: $linker_file"
}
set linker_text [string map [list $old_region $new_region] $linker_text]
set linker_fd [open $linker_file w]
puts -nonewline $linker_fd $linker_text
close $linker_fd

# Execute make inside XSCT so the Vitis tool environment supplies the correct
# Windows SHELL and cross-toolchain settings for nested BSP makefiles.
if {[catch {exec make -C $bringup_dir all 2>@1} make_output]} {
    puts $make_output
    error "CIMForge bring-up application build failed"
}
puts $make_output
file copy -force "$bringup_dir/executable.elf" "$OUTPUT_DIR/cimforge_bringup.elf"
file copy -force "$OUTPUT_DIR/fsbl/executable.elf" "$OUTPUT_DIR/cimforge_fsbl.elf"
exit
