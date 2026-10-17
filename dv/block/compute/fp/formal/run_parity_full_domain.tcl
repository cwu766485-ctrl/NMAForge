set FORMAL_DIR [file dirname [file normalize [info script]]]
set ROOT [file normalize [file join $FORMAL_DIR ../../../../..]]
set RTL_DIR [file join $ROOT rtl compute fp]
set RTL_FILES [list \
    [file join $RTL_DIR ai_bf16_mul_fp32.v] \
    [file join $RTL_DIR ai_fp16_mul_fp32.v] \
    [file join $RTL_DIR ai_fp32_add.v] \
    [file join $RTL_DIR ai_fp32_accumulator.v] \
    [file join $RTL_DIR ai_mixed_precision_dot_fp32_core.v]]

set_app_var fml_mode_on true
read_verilog -rtl $RTL_FILES
read_sverilog -rtl [file join $FORMAL_DIR ai_fp_core_parity_bounded_formal_top.sv]
elaborate -sva ai_fp_core_parity_full_formal_top

# Prove the registered memory-error invariants and writeback exclusion across
# every nonzero 16-bit length. Abort and watchdog are disabled to isolate the
# parity lifecycle; response-valid is still constrained only by outstanding
# reads, and SPAD request backpressure remains unconstrained.
create_clock clk -period 10
create_reset resetn -sense low
sim_config -default_input 0
sim_run 2
sim_save_reset
check_fv_setup -verbose
formal_setup_config -period 10 -initial 1 -apply true

check_fv -property {
    ai_fp_core_parity_full_formal_top.ap_read_request_response_accounting
    ai_fp_core_parity_full_formal_top.ap_parity_has_valid_cutoff
    ai_fp_core_parity_full_formal_top.ap_parity_progress_stays_before_cutoff
    ai_fp_core_parity_full_formal_top.ap_parity_blocks_compute_at_cutoff
    ai_fp_core_parity_full_formal_top.ap_parity_drain_transitions_to_error
    ai_fp_core_parity_full_formal_top.ap_writeback_excludes_pending_parity}
report_fv -usage assert -verbose

check_fv -property {
    ai_fp_core_parity_full_formal_top.cp_parity_response_at_two_outstanding
    ai_fp_core_parity_full_formal_top.cp_parity_error_retires}
report_fv -usage cover -verbose
exit
