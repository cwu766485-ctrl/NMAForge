# Converts the selected foundry TSMC28 RVT standard-cell Liberty view into a
# local DC-readable .db cache.  Generated PDK cache files are environment
# local and must not be committed.
if {![info exists ::env(TSMC28_STDCELL_LIB_TT)] || ![file exists $::env(TSMC28_STDCELL_LIB_TT)]} {
    error "Set TSMC28_STDCELL_LIB_TT to the input TSMC28 RVT standard-cell Liberty file"
}
if {![info exists ::env(TSMC28_STDCELL_DB)]} {
    error "Set TSMC28_STDCELL_DB to the generated local .db path"
}
file mkdir [file dirname $::env(TSMC28_STDCELL_DB)]
read_lib $::env(TSMC28_STDCELL_LIB_TT)
set loaded_lib_collection [get_libs *]
if {[sizeof_collection $loaded_lib_collection] != 1} {
    error "Expected exactly one input standard-cell library, got [sizeof_collection $loaded_lib_collection]"
}
set loaded_lib_name [get_object_name $loaded_lib_collection]
write_lib -format db -output $::env(TSMC28_STDCELL_DB) $loaded_lib_name
if {![file exists $::env(TSMC28_STDCELL_DB)]} {
    error "Liberty Compiler did not create $::env(TSMC28_STDCELL_DB)"
}
puts "CIMForge TSMC28 standard-cell DB completed: $::env(TSMC28_STDCELL_DB)"
exit
