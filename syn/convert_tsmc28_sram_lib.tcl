# Converts one foundry SRAM Liberty view into a local DC-readable .db cache.
# The generated .db is an environment-local PDK artifact and must not be
# committed.  Both environment variables are required to avoid hard-coding a
# user-specific PDK install path in the repository.
if {![info exists ::env(TSMC28_SRAM_LIB_TT)] || ![file exists $::env(TSMC28_SRAM_LIB_TT)]} {
    error "Set TSMC28_SRAM_LIB_TT to the input SRAM Liberty file"
}
if {![info exists ::env(TSMC28_SRAM_DB_TT)]} {
    error "Set TSMC28_SRAM_DB_TT to the generated local .db path"
}
file mkdir [file dirname $::env(TSMC28_SRAM_DB_TT)]
read_lib $::env(TSMC28_SRAM_LIB_TT)
set loaded_lib_collection [get_libs *]
if {[sizeof_collection $loaded_lib_collection] != 1} {
    error "Expected exactly one input SRAM library, got [sizeof_collection $loaded_lib_collection]"
}
set loaded_lib_name [get_object_name $loaded_lib_collection]
write_lib -format db -output $::env(TSMC28_SRAM_DB_TT) $loaded_lib_name
if {![file exists $::env(TSMC28_SRAM_DB_TT)]} {
    error "Liberty Compiler did not create $::env(TSMC28_SRAM_DB_TT)"
}
puts "CIMForge TSMC28 SRAM DB completed: $::env(TSMC28_SRAM_DB_TT)"
exit
