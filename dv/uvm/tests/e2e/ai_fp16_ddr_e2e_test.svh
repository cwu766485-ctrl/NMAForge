class ai_mixed_precision_ddr_e2e_test extends ai_base_test;
    `uvm_component_utils(ai_mixed_precision_ddr_e2e_test)

    ai_mixed_precision_vector_plan vector_plan;
    ai_mixed_precision_e2e_coverage e2e_coverage;
    int unsigned vector_seed;
    int unsigned order_override;
    int unsigned layout_override;
    int unsigned fp16_length_override;
    int unsigned bf16_length_override;
    int unsigned ar_gap_override;
    int unsigned aw_gap_override;
    bit axi_stalls_enabled;
    bit axi_transaction_jitter_enabled;

    function new(string name = "ai_mixed_precision_ddr_e2e_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        vector_seed = 20261014;
        void'($value$plusargs("MIXED_E2E_SEED=%d", vector_seed));
        axi_stalls_enabled = $test$plusargs("MIXED_E2E_AXI_STALLS=1");
        axi_transaction_jitter_enabled = $test$plusargs("MIXED_E2E_AXI_TXN_JITTER=1");
        if (axi_transaction_jitter_enabled && !axi_stalls_enabled)
            `uvm_fatal("MIXED_E2E_AXI_JITTER", "per-transaction jitter requires MIXED_E2E_AXI_STALLS=1")
        vector_plan = ai_mixed_precision_vector_plan::type_id::create("vector_plan");
        // Keep legacy seeded stimulus randomization exactly scoped to its
        // original fields unless this opt-in mode was explicitly requested.
        vector_plan.axi_read_gap.rand_mode(axi_stalls_enabled);
        vector_plan.axi_ready_gap.rand_mode(axi_stalls_enabled);
        vector_plan.axi_ar_gap.rand_mode(axi_stalls_enabled);
        vector_plan.axi_aw_gap.rand_mode(axi_stalls_enabled);
        if (!vector_plan.randomize_int8_stimulus(vector_seed))
            `uvm_fatal("MIXED_E2E_RAND", "failed to randomize exact operands and legal FP dot lengths")
        if ($value$plusargs("MIXED_E2E_ORDER=%d", order_override)) begin
            if (order_override > 5)
                `uvm_fatal("MIXED_E2E_ORDER", $sformatf("descriptor order must be 0..5, got %0d", order_override))
            vector_plan.descriptor_order = order_override;
        end
        if ($value$plusargs("MIXED_E2E_LAYOUT=%d", layout_override)) begin
            if (layout_override > 5)
                `uvm_fatal("MIXED_E2E_LAYOUT", $sformatf("SPAD layout must be 0..5, got %0d", layout_override))
            vector_plan.spad_layout = layout_override;
        end
        if ($value$plusargs("MIXED_E2E_FP16_K=%d", fp16_length_override)) begin
            if ((fp16_length_override < 1) || (fp16_length_override > 4))
                `uvm_fatal("MIXED_E2E_K", $sformatf("FP16 K must be 1..4, got %0d", fp16_length_override))
            vector_plan.fp16_length = fp16_length_override;
        end
        if ($value$plusargs("MIXED_E2E_BF16_K=%d", bf16_length_override)) begin
            if ((bf16_length_override < 1) || (bf16_length_override > 4))
                `uvm_fatal("MIXED_E2E_K", $sformatf("BF16 K must be 1..4, got %0d", bf16_length_override))
            vector_plan.bf16_length = bf16_length_override;
        end
        if ($value$plusargs("MIXED_E2E_AR_GAP=%d", ar_gap_override)) begin
            if (ar_gap_override > 3)
                `uvm_fatal("MIXED_E2E_AXI_GAP", $sformatf("AR address gap must be 0..3, got %0d", ar_gap_override))
            vector_plan.axi_ar_gap = ar_gap_override;
        end
        if ($value$plusargs("MIXED_E2E_AW_GAP=%d", aw_gap_override)) begin
            if (aw_gap_override > 3)
                `uvm_fatal("MIXED_E2E_AXI_GAP", $sformatf("AW address gap must be 0..3, got %0d", aw_gap_override))
            vector_plan.axi_aw_gap = aw_gap_override;
        end

        uvm_config_db#(bit)::set(this, "env.scoreboard", "check_mixed_ddr_path", 1'b1);
        uvm_config_db#(bit)::set(this, "env.scoreboard", "expect_dma_read_error", 1'b1);
        uvm_config_db#(bit)::set(this, "env.scoreboard", "allow_error_responses", 1'b1);
        uvm_config_db#(ai_mixed_precision_vector_plan)::set(this, "env.scoreboard", "mixed_vector_plan", vector_plan);
        super.build_phase(phase);
        e2e_coverage = ai_mixed_precision_e2e_coverage::type_id::create("e2e_coverage", this);
    endfunction

    task run_phase(uvm_phase phase);
        ai_fp16_ddr_e2e_seq seq;
        phase.raise_objection(this, "run INT8/BF16/FP16 queued DDR-to-DDR end-to-end checks");
        seq = ai_fp16_ddr_e2e_seq::type_id::create("fp16_ddr_e2e_seq");
        seq.vector_plan = vector_plan;
        seq.axi_stalls_enabled = axi_stalls_enabled;
        seq.axi_transaction_jitter_enabled = axi_transaction_jitter_enabled;
        seq.start(env.axil_agent.sequencer);
        if (!seq.coverage_sample_valid)
            `uvm_error("MIXED_E2E_COVERAGE", "sequence ended without reaching all top-level scenario samples")
        else if (!seq.active_compute_reset_checked)
            `uvm_error("MIXED_E2E_COVERAGE", "sequence did not verify reset during active compute")
        else if (!seq.active_dma_reset_checked)
            `uvm_error("MIXED_E2E_COVERAGE", "sequence did not verify coordinated reset with an outstanding DMA read")
        else if (!seq.independent_ddr_reset_recovery_checked)
            `uvm_error("MIXED_E2E_COVERAGE", "sequence did not verify DDR service/recovery across accelerator-only reset")
        else if (!seq.fp_watchdog_completion_checked)
            `uvm_error("MIXED_E2E_COVERAGE", "sequence did not verify the real FP watchdog-to-completion path")
        else if (!seq.fp_abort_completion_checked)
            `uvm_error("MIXED_E2E_COVERAGE", "sequence did not verify the real FP software-abort-to-completion path")
        else
            e2e_coverage.sample_run(
                vector_plan.descriptor_order,
                vector_plan.spad_layout,
                (vector_plan.spad_layout % 4),
                vector_plan.fp16_length,
                vector_plan.bf16_length,
                vector_plan.descriptor_order,
                1'b1,
                seq.active_compute_reset_checked,
                seq.active_dma_reset_checked,
                seq.independent_ddr_reset_recovery_checked,
                1'b1,
                1'b1,
                seq.fp_watchdog_completion_checked,
                seq.fp_abort_completion_checked,
                axi_stalls_enabled,
                vector_plan.axi_ar_gap,
                vector_plan.axi_aw_gap,
                vector_plan.axi_read_gap,
                vector_plan.axi_ready_gap
            );
        phase.drop_objection(this, "mixed-precision DDR-to-DDR sequence completed");
    endtask
endclass
