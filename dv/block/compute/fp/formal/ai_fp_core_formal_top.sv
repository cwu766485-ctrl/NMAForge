module ai_fp_core_formal_top (
    input  logic        clk,
    input  logic        resetn,
    input  logic        start,
    input  logic        format_fp16,
    input  logic        abort,
    input  logic [31:0] src0_base,
    input  logic [31:0] src1_base,
    input  logic [31:0] dst_base,
    input  logic [15:0] length,
    input  logic [31:0] watchdog_limit,
    input  logic        spad_ready,
    input  logic        spad_rsp_valid,
    input  logic [31:0] spad_rdata,
    input  logic        spad_parity_error,
    input  logic        spad_protection_error
);
    logic        spad_valid;
    logic        spad_write;
    logic [31:0] spad_addr;
    logic [31:0] spad_wdata;
    logic        busy;
    logic        done;
    logic        error;
    logic [3:0]  error_code;
    logic [31:0] result;
    logic [31:0] cycle_count;
    logic [31:0] element_count;

    ai_mixed_precision_dot_fp32_core dut (.*);

    wire [17:0] accepted_read_count =
        {1'b0, dut.request_word_index_r, 1'b0} + dut.request_is_b_r;
    wire [17:0] returned_read_count =
        {1'b0, dut.response_word_index_r, 1'b0} + dut.response_is_b_r;

    // Formal environment contract: one reset-active edge, then reset remains
    // released; the registered SPAD interface returns only accepted reads.
    assume property (@(posedge clk) !resetn |=> resetn);
    assume property (@(posedge clk) resetn |=> resetn);
    assume property (@(posedge clk) disable iff (!resetn)
        spad_rsp_valid |-> (dut.outstanding_reads_r != 2'b0));

    ap_read_enable_only_in_run: assert property (@(posedge clk)
        dut.read_request_enable |-> (dut.state_r == 4'd1));
    ap_write_protection_exclusive_to_write: assert property (@(posedge clk)
        !(dut.write_protection_failure && (dut.state_r == 4'd1)));
    ap_write_protection_only_in_write_state: assert property (@(posedge clk)
        dut.write_protection_failure |-> (dut.state_r == 4'd6));
    ap_write_state_has_valid_write_request: assert property (@(posedge clk)
        (dut.state_r == 4'd6) |-> (spad_valid && spad_write));
    ap_write_state_excludes_abort_error: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd6) |-> (dut.pending_error_r != 4'd3));
    ap_write_state_excludes_config_error: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd6) |-> (dut.pending_error_r != 4'd1));
    ap_write_state_excludes_watchdog_error: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd6) |-> (dut.pending_error_r != 4'd4));
    ap_write_state_excludes_parity_error: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd6) |-> (dut.pending_error_r != 4'd5));
    ap_cutoff_valid_tracks_memory_error: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.memory_error_cutoff_valid_r |->
          ((dut.pending_error_r == 4'd5) ||
           (dut.pending_error_r == 4'd6)));
    ap_outstanding_reads_bounded: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.outstanding_reads_r <= 2);
    ap_full_outstanding_blocks_unpaired_read: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.outstanding_reads_r == 2) && !dut.response_fire) |->
          !dut.read_fire);
    ap_zero_outstanding_has_no_response: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.outstanding_reads_r == 0) |-> !dut.response_fire);
    ap_failure_active_has_a_source: assert property (@(posedge clk)
        dut.failure_active |->
          ((dut.pending_error_r != 4'd0) || abort || dut.watchdog_expired ||
           dut.response_parity_failure || dut.read_protection_failure ||
           dut.write_protection_failure));

    // Supplemental lemmas for the parity-to-writeback reachability proof.
    // These describe the ordered, ID-less registered-SPAD request/response
    // accounting already assumed by the core and its environment contract.
    ap_read_request_response_accounting: assert property (
        @(posedge clk) disable iff (!resetn)
        (accepted_read_count >= returned_read_count) &&
        ({16'd0, dut.outstanding_reads_r} ==
         (accepted_read_count - returned_read_count)));
    ap_compute_within_returned_pair_frontier: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.compute_fire) |->
        (dut.response_word_index_r > {1'b0, dut.element_index_r[15:1]}));
    ap_new_memory_error_cutoff_precedes_length: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.first_memory_error_now) |->
        (dut.memory_error_cutoff_now < dut.length_r));
    ap_pending_memory_error_index_not_past_cutoff: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.pending_memory_error |->
        (dut.element_index_r <= dut.memory_error_cutoff_r));
    ap_pending_memory_error_blocks_last_compute: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.pending_memory_error && dut.last_element) |->
        !dut.compute_fire);
    ap_new_memory_error_blocks_last_compute: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.first_memory_error_now && dut.last_element) |->
        !dut.compute_fire);

    cp_waiting_for_operands: cover property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd1) && !dut.pair_ready && dut.compute_allowed &&
        !dut.immediate_cancel && !dut.write_protection_failure);
    cp_ready_pair_suppressed_after_error: cover property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd1) && dut.pair_ready && !dut.compute_allowed &&
        !dut.immediate_cancel && !dut.write_protection_failure);
    cp_write_pending_parity: cover property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd6) && (dut.pending_error_r == 4'd5));
endmodule
