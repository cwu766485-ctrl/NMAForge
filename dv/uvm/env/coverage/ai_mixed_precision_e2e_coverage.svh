class ai_mixed_precision_e2e_coverage extends uvm_component;
    `uvm_component_utils(ai_mixed_precision_e2e_coverage)

    int unsigned sample_count;

    covergroup e2e_cg with function sample(
        int unsigned descriptor_order,
        int unsigned spad_layout,
        int unsigned spad_bank,
        int unsigned fp16_length,
        int unsigned bf16_length,
        int unsigned invalid_descriptor_case,
        bit dma_slverr_checked,
        bit active_compute_reset_checked,
        bit active_dma_reset_checked,
        bit independent_ddr_reset_recovery_checked,
        bit reset_recovery_checked,
        bit end_to_end_checked,
        bit fp_watchdog_completion_checked,
        bit fp_abort_completion_checked,
        bit axi_stalls_enabled,
        int unsigned axi_ar_gap,
        int unsigned axi_aw_gap,
        int unsigned axi_read_gap,
        int unsigned axi_ready_gap
    );
        option.per_instance = 1;
        option.goal = 100;

        cp_descriptor_order: coverpoint descriptor_order {
            bins permutations[] = {[0:5]};
            illegal_bins out_of_range = default;
        }
        cp_spad_layout: coverpoint spad_layout {
            bins layouts[] = {[0:5]};
            illegal_bins out_of_range = default;
        }
        cp_spad_bank: coverpoint spad_bank {
            bins banks[] = {[0:3]};
            illegal_bins out_of_range = default;
        }
        cp_invalid_descriptor: coverpoint invalid_descriptor_case {
            bins validator_cases[] = {[0:5]};
            illegal_bins out_of_range = default;
        }
        cp_fp16_length: coverpoint fp16_length {
            bins k1 = {1};
            bins k2 = {2};
            bins k3_odd_tail = {3};
            bins k4_two_words = {4};
            illegal_bins unsupported = default;
        }
        cp_bf16_length: coverpoint bf16_length {
            bins k1 = {1};
            bins k2 = {2};
            bins k3_odd_tail = {3};
            bins k4_two_words = {4};
            illegal_bins unsupported = default;
        }
        cp_dma_slverr: coverpoint dma_slverr_checked {
            bins expected_slverr = {1};
            illegal_bins missing_error_check = {0};
        }
        cp_reset_recovery: coverpoint reset_recovery_checked {
            bins command_recovered = {1};
            illegal_bins missing_recovery = {0};
        }
        cp_reset_inflight_compute: coverpoint active_compute_reset_checked {
            bins reset_while_compute_active = {1};
            illegal_bins missing_active_compute_reset = {0};
        }
        cp_reset_inflight_dma: coverpoint active_dma_reset_checked {
            bins reset_with_dma_read_outstanding = {1};
            illegal_bins missing_dma_outstanding_reset = {0};
        }
        cp_independent_ddr_reset: coverpoint independent_ddr_reset_recovery_checked {
            bins ddr_live_across_accelerator_reset = {1};
            illegal_bins missing_independent_ddr_reset = {0};
        }
        cp_end_to_end: coverpoint end_to_end_checked {
            bins full_path_checked = {1};
            illegal_bins incomplete_path = {0};
        }
        cp_fp_watchdog_completion: coverpoint fp_watchdog_completion_checked {
            bins real_engine_error_retired = {1};
            illegal_bins missing_watchdog_lifecycle = {0};
        }
        cp_fp_abort_completion: coverpoint fp_abort_completion_checked {
            bins real_engine_abort_retired = {1};
            illegal_bins missing_abort_lifecycle = {0};
        }
        cp_axi_read_gap: coverpoint axi_read_gap iff (axi_stalls_enabled) {
            bins gaps[] = {[0:3]};
            illegal_bins out_of_range = default;
        }
        cp_axi_ar_gap: coverpoint axi_ar_gap iff (axi_stalls_enabled) {
            bins gaps[] = {[0:3]};
            illegal_bins out_of_range = default;
        }
        cp_axi_aw_gap: coverpoint axi_aw_gap iff (axi_stalls_enabled) {
            bins gaps[] = {[0:3]};
            illegal_bins out_of_range = default;
        }
        cp_axi_ready_gap: coverpoint axi_ready_gap iff (axi_stalls_enabled) {
            bins gaps[] = {[0:3]};
            illegal_bins out_of_range = default;
        }
        fp16_x_bf16_length: cross cp_fp16_length, cp_bf16_length;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        e2e_cg = new();
        sample_count = 0;
    endfunction

    function void sample_run(
        int unsigned descriptor_order,
        int unsigned spad_layout,
        int unsigned spad_bank,
        int unsigned fp16_length,
        int unsigned bf16_length,
        int unsigned invalid_descriptor_case,
        bit dma_slverr_checked,
        bit active_compute_reset_checked,
        bit active_dma_reset_checked,
        bit independent_ddr_reset_recovery_checked,
        bit reset_recovery_checked,
        bit end_to_end_checked,
        bit fp_watchdog_completion_checked,
        bit fp_abort_completion_checked,
        bit axi_stalls_enabled,
        int unsigned axi_ar_gap,
        int unsigned axi_aw_gap,
        int unsigned axi_read_gap,
        int unsigned axi_ready_gap
    );
        e2e_cg.sample(descriptor_order, spad_layout, spad_bank,
                      fp16_length, bf16_length,
                      invalid_descriptor_case, dma_slverr_checked,
                      active_compute_reset_checked, active_dma_reset_checked,
                      independent_ddr_reset_recovery_checked,
                      reset_recovery_checked,
                      end_to_end_checked,
                      fp_watchdog_completion_checked,
                      fp_abort_completion_checked,
                      axi_stalls_enabled, axi_ar_gap, axi_aw_gap,
                      axi_read_gap, axi_ready_gap);
        sample_count++;
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("MIXED_E2E_COVERAGE",
                  $sformatf("samples=%0d per-run-group=%0.1f%% (aggregate bins are reported by URG)",
                            sample_count, e2e_cg.get_coverage()), UVM_LOW)
    endfunction
endclass
