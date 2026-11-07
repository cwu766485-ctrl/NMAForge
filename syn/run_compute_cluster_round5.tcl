# Hierarchical, pre-layout DC run for the NMAForge Compute Cluster.
# The standard-cell database and all outputs are supplied outside the repo.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set std_lib [getenv NMAFORGE_STD_LIB]
set out_dir [getenv NMAFORGE_DC_OUT]
set period_ns [getenv NMAFORGE_DC_PERIOD_NS]
set top_name [getenv NMAFORGE_DC_TOP]
set clock_name [getenv NMAFORGE_DC_CLOCK]
set compile_mode [getenv NMAFORGE_DC_COMPILE_MODE]
set max_cores [getenv NMAFORGE_DC_MAX_CORES]
set opcond [getenv NMAFORGE_DC_OPCOND]

if {$std_lib eq "" || $out_dir eq "" || $period_ns eq ""} {
    error "Set NMAFORGE_STD_LIB, NMAFORGE_DC_OUT, and NMAFORGE_DC_PERIOD_NS"
}
if {$top_name eq ""} {
    set top_name ai_accel_compute_cluster
}
if {$clock_name eq ""} {
    if {$top_name eq "ai_tensor_matrix_core"} {
        set clock_name clk
    } else {
        set clock_name aclk
    }
}
if {$compile_mode eq ""} {
    set compile_mode ultra
}
if {$max_cores eq ""} {
    set max_cores 2
}
if {$opcond eq ""} {
    set opcond ssg0p72v125c
}
if {![file exists $std_lib]} {
    error "Standard-cell library does not exist: $std_lib"
}
file mkdir $out_dir

set_app_var search_path [list $repo_root [file dirname $std_lib]]
set_app_var target_library [list $std_lib]
set_app_var link_library [concat [list *] [list $std_lib]]
set_app_var alib_library_analysis_path $out_dir

set source_list [file join $repo_root dv subsystem top_smoke sim ai_accel.f]
set list_file [open $source_list r]
set rtl_files {}
while {[gets $list_file line] >= 0} {
    set line [string trim $line]
    if {[string match "../../../../rtl/*" $line] &&
        ([string match "*.v" $line] || [string match "*.sv" $line])} {
        lappend rtl_files [file normalize [file join [file dirname $source_list] $line]]
    }
}
close $list_file
if {[llength $rtl_files] == 0} {
    error "No RTL sources found in $source_list"
}

define_design_lib WORK -path [file join $out_dir WORK]
foreach rtl_file $rtl_files {
    analyze -format sverilog -work WORK $rtl_file
}
elaborate $top_name -work WORK
current_design $top_name
link
check_design -summary
set_operating_conditions -max $opcond

# All memory/arbiter response and request ports remain
# explicit top-level ports. No false paths, multicycle paths, or guessed SRAM
# timing are applied here.
if {[sizeof_collection [get_ports $clock_name]] == 0} {
    error "Clock port '$clock_name' does not exist on $top_name"
}
create_clock -name $clock_name -period $period_ns [get_ports $clock_name]
set_clock_uncertainty 0.10 [get_clocks $clock_name]
set_clock_transition 0.05 [get_clocks $clock_name]
set_input_transition 0.05 [all_inputs]
set_input_delay -clock $clock_name -max 0.25 \
    [remove_from_collection [all_inputs] [get_ports $clock_name]]
set_input_delay -clock $clock_name -min 0.05 \
    [remove_from_collection [all_inputs] [get_ports $clock_name]]
set_output_delay -clock $clock_name -max 0.25 [all_outputs]
set_output_delay -clock $clock_name -min 0.05 [all_outputs]
set_load 0.020 [all_outputs]
set_max_transition 0.20 [current_design]
set_max_fanout 16 [current_design]
set_dont_touch_network [get_ports $clock_name]
set_switching_activity -static_probability 0.5 -toggle_rate 0.1 [all_inputs]

# `check_design -summary` already ran after linking above. Pre-mapping QoR
# reports only zero cell area and can be disproportionately slow on the
# unflattened 16x16 Matrix Core, so emit QoR/check reports after mapping only.

# Preserve module boundaries to avoid flattening the large shared array into
# one unbounded mapping problem. DC still maps and times every child design.
set_host_options -max_cores $max_cores
if {$compile_mode eq "ultra"} {
    set compile_command {compile_ultra -no_autoungroup}
} elseif {$compile_mode eq "standard"} {
    set compile_command {compile -map_effort high}
} else {
    error "Unsupported NMAFORGE_DC_COMPILE_MODE: $compile_mode"
}
if {[catch {eval $compile_command} compile_result]} {
    error "$compile_command failed: $compile_result"
}

redirect -file [file join $out_dir qor.rpt] {report_qor}
redirect -file [file join $out_dir area_hier.rpt] {report_area -hierarchy}
redirect -file [file join $out_dir power_vectorless.rpt] {
    report_power -hierarchy
}
write -format verilog -hierarchy -output [file join $out_dir ${top_name}.v]
write_sdc [file join $out_dir ${top_name}.sdc]

# Evaluate the same mapped netlist at comparison clocks. The result is static
# timing on one mapping, not independent synthesis at each frequency.
foreach period_variant [list $period_ns 3.333333 2.222222] {
    remove_clock [get_clocks $clock_name]
    create_clock -name $clock_name -period $period_variant [get_ports $clock_name]
    set_clock_uncertainty 0.10 [get_clocks $clock_name]
    set_clock_transition 0.05 [get_clocks $clock_name]
    set_input_delay -clock $clock_name -max 0.25 \
        [remove_from_collection [all_inputs] [get_ports $clock_name]]
    set_input_delay -clock $clock_name -min 0.05 \
        [remove_from_collection [all_inputs] [get_ports $clock_name]]
    set_output_delay -clock $clock_name -max 0.25 [all_outputs]
    set_output_delay -clock $clock_name -min 0.05 [all_outputs]
    set period_tag [string map {. _} $period_variant]
    redirect -file [file join $out_dir timing_${period_tag}ns.rpt] {
        report_timing -delay_type max -max_paths 20 -input_pins -nets
    }
    redirect -file [file join $out_dir qor_${period_tag}ns.rpt] {report_qor}
}
exit
