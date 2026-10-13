# Post-synthesis SAIF power reporting for an existing DC DDC checkpoint.
# Required environment: TSMC28_STDCELL_DB, TSMC28_SRAM_DB_TT,
# CIMFORGE_DDC, CIMFORGE_SAIF, and CIMFORGE_PPA_REPORT_DIR.

foreach required_var {TSMC28_STDCELL_DB TSMC28_SRAM_DB_TT CIMFORGE_DDC CIMFORGE_SAIF CIMFORGE_PPA_REPORT_DIR} {
    if {![info exists ::env($required_var)] || $::env($required_var) eq ""} {
        error "Set $required_var before running report_saif_power.tcl"
    }
}
foreach required_file {TSMC28_STDCELL_DB TSMC28_SRAM_DB_TT CIMFORGE_DDC CIMFORGE_SAIF} {
    if {![file exists $::env($required_file)]} {
        error "$required_file does not exist: $::env($required_file)"
    }
}

set TOP [expr {[info exists ::env(CIMFORGE_TOP)] ? $::env(CIMFORGE_TOP) : "ai_accel_top"}]
set SAIF_INSTANCE [expr {[info exists ::env(CIMFORGE_SAIF_INSTANCE)] ? $::env(CIMFORGE_SAIF_INSTANCE) : $TOP}]
set REPORT_DIR $::env(CIMFORGE_PPA_REPORT_DIR)
file mkdir $REPORT_DIR

set_app_var target_library [list $::env(TSMC28_STDCELL_DB)]
set_app_var link_library [list "*" $::env(TSMC28_STDCELL_DB) $::env(TSMC28_SRAM_DB_TT)]
read_ddc $::env(CIMFORGE_DDC)
current_design $TOP
link

read_saif -input $::env(CIMFORGE_SAIF) -instance $SAIF_INSTANCE -auto_map_names
# Some DC installations expose report_power but not report_switching_activity.
# Keep that capability limitation explicit without discarding a successfully
# annotated SAIF or turning it into a false flow failure.
if {[catch {
    redirect -file "$REPORT_DIR/saif_activity.rpt" {
        report_switching_activity -list_not_annotated
    }
} activity_error]} {
    set activity_fh [open "$REPORT_DIR/saif_activity.rpt" w]
    puts $activity_fh "Unavailable in this DC installation: $activity_error"
    close $activity_fh
    puts "CIMForge SAIF activity detail unavailable: $activity_error"
}
redirect -file "$REPORT_DIR/power_saif.rpt" {
    report_power
}
puts "CIMForge SAIF power completed: ddc=$::env(CIMFORGE_DDC) saif=$::env(CIMFORGE_SAIF) instance=$SAIF_INSTANCE reports=$REPORT_DIR"
exit
