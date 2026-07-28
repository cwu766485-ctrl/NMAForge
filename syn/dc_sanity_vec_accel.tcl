# DC sanity check for the AHB-Lite vector/SOM accelerator.
#
# This script intentionally stops before technology mapping. It checks whether
# Design Compiler can parse, elaborate, link and structurally check the RTL
# without requiring a foundry standard-cell .db library.

set TOP vec_accel_top
set RTL_DIR ../rtl
set SYN_DIR .

set_app_var search_path [list . $RTL_DIR]
set_app_var target_library [list]
set_app_var link_library [list "*"]
set_app_var synthetic_library [list standard.sldb]

remove_design -all

analyze -format verilog [list \
  $RTL_DIR/legacy/ahb_slave_if.v \
  $SYN_DIR/sram_core_blackbox.v \
  $RTL_DIR/legacy/vec_accel_regs.v \
  $RTL_DIR/legacy/vec_accel_core.v \
  $RTL_DIR/legacy/vec_accel_top.v \
]

elaborate $TOP
current_design $TOP
link

check_design
report_area
report_reference

quit
