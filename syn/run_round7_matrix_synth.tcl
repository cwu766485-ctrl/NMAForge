# Bounded, standalone Matrix Array synthesis for NMAForge Round 7.
# Foundry libraries and generated outputs are supplied outside the repository.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set array_size [getenv NMAFORGE_R7_ARRAY_SIZE]
set period_ns [getenv NMAFORGE_R7_PERIOD_NS]
set run_dir [getenv NMAFORGE_R7_RUN_DIR]
set std_lib [getenv NMAFORGE_R7_STD_LIB]
set compile_mode [getenv NMAFORGE_R7_COMPILE_MODE]
set opcond [getenv NMAFORGE_R7_OPCOND]
set max_cores [getenv NMAFORGE_R7_MAX_CORES]
set synth_top [getenv NMAFORGE_R7_TOP]

foreach {name value} [list NMAFORGE_R7_ARRAY_SIZE $array_size \
                           NMAFORGE_R7_PERIOD_NS $period_ns \
                           NMAFORGE_R7_RUN_DIR $run_dir \
                           NMAFORGE_R7_STD_LIB $std_lib \
                           NMAFORGE_R7_COMPILE_MODE $compile_mode \
                           NMAFORGE_R7_OPCOND $opcond] {
    if {$value eq ""} { error "Missing environment variable $name" }
}
if {$max_cores eq ""} { set max_cores 2 }
if {$synth_top eq ""} { set synth_top ai_tensor_matrix_array }
if {$array_size ni {8 16}} { error "ARRAY_SIZE must be 8 or 16" }
if {$compile_mode ni {medium high}} { error "COMPILE_MODE must be medium or high" }
if {$synth_top ni {ai_tensor_matrix_array ai_tensor_matrix_core}} { error "Unsupported synthesis top $synth_top" }
if {$synth_top eq "ai_tensor_matrix_core" && $array_size != 16} { error "Matrix Core is only qualified for ARRAY_SIZE=16" }
if {![file exists $std_lib]} { error "Selected standard-cell database is missing" }
file mkdir $run_dir

set_app_var search_path [list $repo_root [file dirname $std_lib]]
set_app_var target_library [list $std_lib]
set_app_var link_library [list * $std_lib]
set_app_var alib_library_analysis_path [file join $run_dir alib]
set_host_options -max_cores $max_cores

puts "R7_SYNTH_BEGIN top=$synth_top array_size=$array_size period_ns=$period_ns mode=$compile_mode"
if {[catch {
    analyze -format sverilog [file join $repo_root rtl/compute/matrix/ai_tensor_matrix_array.sv]
    if {$synth_top eq "ai_tensor_matrix_core"} {
        analyze -format verilog [file join $repo_root rtl/compute/matrix/ai_tensor_matrix_core.v]
    }
} analyze_error]} {
    puts stderr "R7_SYNTH_ELABORATION_ERROR analyze: $analyze_error"
    exit 2
}
if {[catch {
    elaborate $synth_top -parameters "ARRAY_SIZE=$array_size"
    current_design ${synth_top}_ARRAY_SIZE$array_size
    link
    check_design -summary
} link_error]} {
    puts stderr "R7_SYNTH_LINK_ERROR: $link_error"
    exit 3
}
if {$opcond ne "" && [catch {set_operating_conditions -max $opcond} opcond_error]} {
    puts stderr "R7_SYNTH_LIBRARY_CONDITION_ERROR: $opcond_error"
    exit 4
}

if {[sizeof_collection [get_ports clk]] == 0} {
    error "Expected clock port clk was not found"
}
create_clock -name clk -period $period_ns [get_ports clk]
set_clock_uncertainty -setup 0.10 [get_clocks clk]
set_clock_uncertainty -hold 0.02 [get_clocks clk]
set_clock_transition 0.05 [get_clocks clk]
set_input_transition 0.05 [all_inputs]
set_input_delay -clock clk -max 0.25 [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -clock clk -min 0.05 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk -max 0.25 [all_outputs]
set_output_delay -clock clk -min 0.05 [all_outputs]
set_load 0.020 [all_outputs]
set_max_transition 0.20 [current_design]
set_max_fanout 16 [current_design]
set_dont_touch_network [get_ports clk]
set_switching_activity -static_probability 0.5 -toggle_rate 0.1 [all_inputs]

puts "R7_SYNTH_MAPPING_BEGIN mode=$compile_mode"
if {$compile_mode eq "medium"} {
    if {[catch {compile -map_effort medium} compile_error]} {
        puts stderr "R7_SYNTH_MAPPING_ERROR medium: $compile_error"
        exit 5
    }
} else {
    if {[catch {compile -map_effort high} compile_error]} {
        puts stderr "R7_SYNTH_MAPPING_ERROR high: $compile_error"
        exit 5
    }
}
puts "R7_SYNTH_MAPPING_DONE"

redirect -file [file join $run_dir check_design.rpt] { check_design }
redirect -file [file join $run_dir qor.rpt] { report_qor }
redirect -file [file join $run_dir area_hier.rpt] { report_area -hierarchy }
redirect -file [file join $run_dir reference.rpt] { report_reference }
if {[catch {
    redirect -file [file join $run_dir power_vectorless.rpt] { report_power -hierarchy }
} power_error]} {
    puts "R7_SYNTH_POWER_REPORT_UNAVAILABLE: $power_error"
}
if {[catch {
    write -format ddc -hierarchy -output [file join $run_dir ${synth_top}.ddc]
    write -format verilog -hierarchy -output [file join $run_dir ${synth_top}_mapped.v]
    write_sdc [file join $run_dir ai_tensor_matrix_array.sdc]
} write_error]} {
    puts stderr "R7_SYNTH_NETLIST_WRITE_ERROR: $write_error"
    exit 6
}
if {![file exists [file join $run_dir ${synth_top}_mapped.v]]} {
    puts stderr "R7_SYNTH_NETLIST_WRITE_ERROR: mapped netlist missing"
    exit 6
}
foreach period_variant {4.0 3.333333 2.500000 2.222222} {
    remove_clock [get_clocks clk]
    create_clock -name clk -period $period_variant [get_ports clk]
    set_clock_uncertainty -setup 0.10 [get_clocks clk]
    set_clock_uncertainty -hold 0.02 [get_clocks clk]
    set_clock_transition 0.05 [get_clocks clk]
    set_input_delay -clock clk -max 0.25 [remove_from_collection [all_inputs] [get_ports clk]]
    set_input_delay -clock clk -min 0.05 [remove_from_collection [all_inputs] [get_ports clk]]
    set_output_delay -clock clk -max 0.25 [all_outputs]
    set_output_delay -clock clk -min 0.05 [all_outputs]
    set period_tag [string map {. _} $period_variant]
    redirect -file [file join $run_dir timing_${period_tag}ns_max_20.rpt] {
        report_timing -delay_type max -max_paths 20 -input_pins -nets
    }
    redirect -file [file join $run_dir timing_${period_tag}ns_min_20.rpt] {
        report_timing -delay_type min -max_paths 20 -input_pins -nets
    }
    redirect -file [file join $run_dir qor_${period_tag}ns.rpt] { report_qor }
}
puts "R7_SYNTH_COMPLETE top=$synth_top array_size=$array_size period_ns=$period_ns run_dir=$run_dir"
exit
