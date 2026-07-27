# Read-only sanity probe for a TSMC28 standard-cell DB and SRAM DB cache.
foreach required_var {TSMC28_STDCELL_DB TSMC28_SRAM_DB_TT} {
    if {![info exists ::env($required_var)] || ![file exists $::env($required_var)]} {
        error "Set $required_var before running this probe"
    }
}
set_app_var target_library [list $::env(TSMC28_STDCELL_DB)]
set_app_var link_library [list "*" $::env(TSMC28_STDCELL_DB) $::env(TSMC28_SRAM_DB_TT)]
foreach_in_collection lib [get_libs *] {
    set lib_name [get_object_name $lib]
    set cells [get_lib_cells -quiet "${lib_name}/*"]
    puts "LIB=$lib_name CELLS=[sizeof_collection $cells]"
    set shown 0
    foreach_in_collection cell $cells {
        if {$shown >= 24} { break }
        puts "  CELL=[get_object_name $cell]"
        incr shown
    }
}
puts "SRAM_MACRO=[sizeof_collection [get_lib_cells -quiet */TS1N28HPCPL2SVTB4096X32M4MWBASO]]"
exit
