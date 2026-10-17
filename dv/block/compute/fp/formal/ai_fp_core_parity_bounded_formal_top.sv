module ai_fp_core_parity_bounded_formal_top #(
    parameter [15:0] MAX_LENGTH = 16'd4
) (
    input logic        clk,
    input logic        resetn,
    input logic        start,
    input logic        format_fp16,
    input logic        abort,
    input logic [31:0] src0_base,
    input logic [31:0] src1_base,
    input logic [31:0] dst_base,
    input logic [15:0] length,
    input logic [31:0] watchdog_limit,
    input logic        spad_ready,
    input logic        spad_rsp_valid,
    input logic [31:0] spad_rdata,
    input logic        spad_parity_error,
    input logic        spad_protection_error
);
    localparam [3:0] ERR_PARITY = 4'd5;
    localparam [3:0] ST_RUN = 4'd1;
    localparam [3:0] ST_WRITE = 4'd6;
    localparam [3:0] ST_ERROR = 4'd8;

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
    wire [16:0] words_needed = ({1'b0, dut.length_r} + 17'd1) >> 1;

    // The default proof wrapper bounds odd/even vectors to lengths 1..4.
    // The full-domain wrapper overrides MAX_LENGTH to 16'hffff, preserving
    // all 16-bit nonzero lengths with the same two-read/ordered-response DUT.
    assume property (@(posedge clk) !resetn |=> resetn);
    assume property (@(posedge clk) resetn |=> resetn);
    assume property (@(posedge clk) disable iff (!resetn)
        start |-> ((length >= 16'd1) && (length <= MAX_LENGTH) &&
                   (src0_base[1:0] == 2'b00) &&
                   (src1_base[1:0] == 2'b00) &&
                   (dst_base[1:0] == 2'b00) &&
                   (watchdog_limit == 0)));
    assume property (@(posedge clk) !abort);
    assume property (@(posedge clk) disable iff (!resetn)
        spad_rsp_valid |-> (dut.outstanding_reads_r != 0));

    ap_read_request_response_accounting: assert property (
        @(posedge clk) disable iff (!resetn)
        (accepted_read_count >= returned_read_count) &&
        ({16'd0, dut.outstanding_reads_r} ==
         (accepted_read_count - returned_read_count)));
    ap_request_index_not_past_end: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == ST_RUN) |->
          ({1'b0, dut.request_word_index_r} <= words_needed));
    ap_response_index_within_end: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.response_fire |->
          ({1'b0, dut.response_word_index_r} < words_needed));
    ap_accepted_read_count_within_task: assert property (
        @(posedge clk) disable iff (!resetn)
        accepted_read_count <= {words_needed, 1'b0});

    ap_parity_has_valid_cutoff: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.pending_error_r == ERR_PARITY) |->
          (dut.memory_error_cutoff_valid_r &&
           (dut.memory_error_cutoff_r < dut.length_r)));
    ap_parity_progress_stays_before_cutoff: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.pending_memory_error |->
          (dut.element_index_r <= dut.memory_error_cutoff_r));
    ap_parity_blocks_compute_at_cutoff: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.pending_error_r == ERR_PARITY) &&
         (dut.element_index_r >= dut.memory_error_cutoff_r)) |->
          !dut.compute_fire);
    ap_parity_drain_transitions_to_error: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == ST_RUN) &&
         (dut.pending_error_r == ERR_PARITY) &&
         (dut.outstanding_after == 0) &&
         (dut.element_index_r >= dut.memory_error_cutoff_r)) |=>
          (dut.state_r == ST_ERROR));
    ap_writeback_excludes_pending_parity: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == ST_WRITE) |->
          (dut.pending_error_r != ERR_PARITY));

    cp_parity_response_at_two_outstanding: cover property (
        @(posedge clk) disable iff (!resetn)
        dut.response_parity_failure && (dut.outstanding_reads_r == 2));
    cp_parity_error_retires: cover property (
        @(posedge clk) disable iff (!resetn)
        done && error && (error_code == ERR_PARITY));
endmodule

module ai_fp_core_parity_full_formal_top (
    input logic        clk,
    input logic        resetn,
    input logic        start,
    input logic        format_fp16,
    input logic        abort,
    input logic [31:0] src0_base,
    input logic [31:0] src1_base,
    input logic [31:0] dst_base,
    input logic [15:0] length,
    input logic [31:0] watchdog_limit,
    input logic        spad_ready,
    input logic        spad_rsp_valid,
    input logic [31:0] spad_rdata,
    input logic        spad_parity_error,
    input logic        spad_protection_error
);
    localparam [3:0] ERR_PARITY = 4'd5;
    localparam [3:0] ST_RUN = 4'd1;
    localparam [3:0] ST_WRITE = 4'd6;
    localparam [3:0] ST_ERROR = 4'd8;

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
    wire [16:0] words_needed = ({1'b0, dut.length_r} + 17'd1) >> 1;

    // Legal nonzero lengths span the complete 16-bit ABI field. Abort and
    // watchdog are disabled to isolate memory-parity lifecycle behavior.
    assume property (@(posedge clk) !resetn |=> resetn);
    assume property (@(posedge clk) resetn |=> resetn);
    assume property (@(posedge clk) disable iff (!resetn)
        start |-> ((length != 16'd0) &&
                   (src0_base[1:0] == 2'b00) &&
                   (src1_base[1:0] == 2'b00) &&
                   (dst_base[1:0] == 2'b00) &&
                   (watchdog_limit == 0)));
    assume property (@(posedge clk) !abort);
    assume property (@(posedge clk) disable iff (!resetn)
        spad_rsp_valid |-> (dut.outstanding_reads_r != 0));

    ap_read_request_response_accounting: assert property (
        @(posedge clk) disable iff (!resetn)
        (accepted_read_count >= returned_read_count) &&
        ({16'd0, dut.outstanding_reads_r} ==
         (accepted_read_count - returned_read_count)));
    ap_request_index_not_past_end: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == ST_RUN) |->
          ({1'b0, dut.request_word_index_r} <= words_needed));
    ap_response_index_within_end: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.response_fire |->
          ({1'b0, dut.response_word_index_r} < words_needed));
    ap_accepted_read_count_within_task: assert property (
        @(posedge clk) disable iff (!resetn)
        accepted_read_count <= {words_needed, 1'b0});
    ap_parity_has_valid_cutoff: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.pending_error_r == ERR_PARITY) |->
          (dut.memory_error_cutoff_valid_r &&
           (dut.memory_error_cutoff_r < dut.length_r)));
    ap_parity_progress_stays_before_cutoff: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.pending_memory_error |->
          (dut.element_index_r <= dut.memory_error_cutoff_r));
    ap_parity_blocks_compute_at_cutoff: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.pending_error_r == ERR_PARITY) &&
         (dut.element_index_r >= dut.memory_error_cutoff_r)) |->
          !dut.compute_fire);
    ap_parity_drain_transitions_to_error: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == ST_RUN) &&
         (dut.pending_error_r == ERR_PARITY) &&
         (dut.outstanding_after == 0) &&
         (dut.element_index_r >= dut.memory_error_cutoff_r)) |=>
          (dut.state_r == ST_ERROR));
    ap_writeback_excludes_pending_parity: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == ST_WRITE) |->
          (dut.pending_error_r != ERR_PARITY));

    cp_parity_response_at_two_outstanding: cover property (
        @(posedge clk) disable iff (!resetn)
        dut.response_parity_failure && (dut.outstanding_reads_r == 2));
    cp_parity_error_retires: cover property (
        @(posedge clk) disable iff (!resetn)
        done && error && (error_code == ERR_PARITY));
endmodule

// Assume-guarantee refinement for the response cursor. The two assumptions
// below are proved independently by the full-domain accounting and
// accepted-count targets under the identical reset/SPAD contract. Keeping
// this wrapper separate prevents those lemmas from weakening the canonical
// full-domain parity proof.
module ai_fp_core_parity_full_response_assume_top (
    input logic        clk,
    input logic        resetn,
    input logic        start,
    input logic        format_fp16,
    input logic        abort,
    input logic [31:0] src0_base,
    input logic [31:0] src1_base,
    input logic [31:0] dst_base,
    input logic [15:0] length,
    input logic [31:0] watchdog_limit,
    input logic        spad_ready,
    input logic        spad_rsp_valid,
    input logic [31:0] spad_rdata,
    input logic        spad_parity_error,
    input logic        spad_protection_error
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
    wire [16:0] words_needed = ({1'b0, dut.length_r} + 17'd1) >> 1;

    assume property (@(posedge clk) !resetn |=> resetn);
    assume property (@(posedge clk) resetn |=> resetn);
    assume property (@(posedge clk) disable iff (!resetn)
        start |-> ((length != 16'd0) &&
                   (src0_base[1:0] == 2'b00) &&
                   (src1_base[1:0] == 2'b00) &&
                   (dst_base[1:0] == 2'b00) &&
                   (watchdog_limit == 0)));
    assume property (@(posedge clk) !abort);
    assume property (@(posedge clk) disable iff (!resetn)
        spad_rsp_valid |-> (dut.outstanding_reads_r != 0));

    // These are assume-guarantee inputs, not unproved DUT assumptions:
    // parity-full-accounting and parity-full-accepted-count-bound prove each
    // assertion independently with the same legal-input contract above.
    assume property (@(posedge clk) disable iff (!resetn)
        (accepted_read_count >= returned_read_count) &&
        ({16'd0, dut.outstanding_reads_r} ==
         (accepted_read_count - returned_read_count)));
    assume property (@(posedge clk) disable iff (!resetn)
        accepted_read_count <= {words_needed, 1'b0});

    ap_response_index_within_end: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.response_fire |->
          ({1'b0, dut.response_word_index_r} < words_needed));
endmodule

// The response-index bound is proven separately by
// ai_fp_core_parity_full_response_assume_top. This wrapper uses that theorem
// to isolate the arithmetic/registration step from a parity response to the
// stored memory-error cutoff.
module ai_fp_core_parity_full_cutoff_assume_top (
    input logic        clk,
    input logic        resetn,
    input logic        start,
    input logic        format_fp16,
    input logic        abort,
    input logic [31:0] src0_base,
    input logic [31:0] src1_base,
    input logic [31:0] dst_base,
    input logic [15:0] length,
    input logic [31:0] watchdog_limit,
    input logic        spad_ready,
    input logic        spad_rsp_valid,
    input logic [31:0] spad_rdata,
    input logic        spad_parity_error,
    input logic        spad_protection_error
);
    localparam [3:0] ERR_PARITY = 4'd5;

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

    wire [16:0] words_needed = ({1'b0, dut.length_r} + 17'd1) >> 1;

    assume property (@(posedge clk) !resetn |=> resetn);
    assume property (@(posedge clk) resetn |=> resetn);
    assume property (@(posedge clk) disable iff (!resetn)
        start |-> ((length != 16'd0) &&
                   (src0_base[1:0] == 2'b00) &&
                   (src1_base[1:0] == 2'b00) &&
                   (dst_base[1:0] == 2'b00) &&
                   (watchdog_limit == 0)));
    assume property (@(posedge clk) !abort);
    assume property (@(posedge clk) disable iff (!resetn)
        spad_rsp_valid |-> (dut.outstanding_reads_r != 0));
    assume property (@(posedge clk) disable iff (!resetn)
        dut.response_fire |->
          ({1'b0, dut.response_word_index_r} < words_needed));

    ap_parity_cutoff_is_valid: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.pending_error_r == ERR_PARITY) |->
          (dut.memory_error_cutoff_valid_r &&
           (dut.memory_error_cutoff_r < dut.length_r)));
endmodule

// Refinement of parity lifecycle checks under independently proven boundary
// lemmas: response cursor in range and parity cutoff valid/in range. The
// canonical full-domain wrapper remains assumption-free with respect to both.
module ai_fp_core_parity_full_lifecycle_assume_top (
    input logic        clk,
    input logic        resetn,
    input logic        start,
    input logic        format_fp16,
    input logic        abort,
    input logic [31:0] src0_base,
    input logic [31:0] src1_base,
    input logic [31:0] dst_base,
    input logic [15:0] length,
    input logic [31:0] watchdog_limit,
    input logic        spad_ready,
    input logic        spad_rsp_valid,
    input logic [31:0] spad_rdata,
    input logic        spad_parity_error,
    input logic        spad_protection_error
);
    localparam [3:0] ERR_PARITY = 4'd5;
    localparam [3:0] ST_RUN = 4'd1;
    localparam [3:0] ST_WRITE = 4'd6;

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

    wire [16:0] words_needed = ({1'b0, dut.length_r} + 17'd1) >> 1;

    // Harness-only ghost tags record which packed SPAD word populated each
    // A/B pair slot. They do not constrain DUT behavior; they expose the
    // slot-to-element ownership relation as an inductive proof target.
    reg [15:0] pair_a_word_tag_r [0:1];
    reg [15:0] pair_b_word_tag_r [0:1];
    integer tag_slot;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (tag_slot = 0; tag_slot < 2; tag_slot = tag_slot + 1) begin
                pair_a_word_tag_r[tag_slot] <= 16'd0;
                pair_b_word_tag_r[tag_slot] <= 16'd0;
            end
        end else if ((dut.state_r == 4'd0) && start) begin
            for (tag_slot = 0; tag_slot < 2; tag_slot = tag_slot + 1) begin
                pair_a_word_tag_r[tag_slot] <= 16'd0;
                pair_b_word_tag_r[tag_slot] <= 16'd0;
            end
        end else if (dut.response_fire && !spad_parity_error) begin
            if (!dut.response_is_b_r)
                pair_a_word_tag_r[dut.response_slot] <=
                    dut.response_word_index_r;
            else
                pair_b_word_tag_r[dut.response_slot] <=
                    dut.response_word_index_r;
        end
    end

    assume property (@(posedge clk) !resetn |=> resetn);
    assume property (@(posedge clk) resetn |=> resetn);
    assume property (@(posedge clk) disable iff (!resetn)
        start |-> ((length != 16'd0) &&
                   (src0_base[1:0] == 2'b00) &&
                   (src1_base[1:0] == 2'b00) &&
                   (dst_base[1:0] == 2'b00) &&
                   (watchdog_limit == 0)));
    assume property (@(posedge clk) !abort);
    assume property (@(posedge clk) disable iff (!resetn)
        spad_rsp_valid |-> (dut.outstanding_reads_r != 0));
    assume property (@(posedge clk) disable iff (!resetn)
        dut.response_fire |->
          ({1'b0, dut.response_word_index_r} < words_needed));
    assume property (@(posedge clk) disable iff (!resetn)
        (dut.pending_error_r == ERR_PARITY) |->
          (dut.memory_error_cutoff_valid_r &&
           (dut.memory_error_cutoff_r < dut.length_r)));

    ap_compute_within_returned_pair_frontier: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.compute_fire) |->
        (dut.response_word_index_r > {1'b0, dut.element_index_r[15:1]}));
    ap_ready_pair_within_returned_frontier: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.pair_ready) |->
        (dut.response_word_index_r > {1'b0, dut.element_index_r[15:1]}));
    ap_pair0_ready_tags_match: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.pair_a_valid_r[0] && dut.pair_b_valid_r[0]) |->
        (pair_a_word_tag_r[0] == pair_b_word_tag_r[0]));
    ap_pair1_ready_tags_match: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.pair_a_valid_r[1] && dut.pair_b_valid_r[1]) |->
        (pair_a_word_tag_r[1] == pair_b_word_tag_r[1]));
    ap_ready_pair_tag_matches_current_element: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.pair_ready) |->
        ((pair_a_word_tag_r[dut.compute_slot] ==
          pair_b_word_tag_r[dut.compute_slot]) &&
         (pair_a_word_tag_r[dut.compute_slot] ==
          {1'b0, dut.element_index_r[15:1]})));
    ap_ready_slot0_tag_matches_element: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && !dut.compute_slot &&
         dut.pair_a_valid_r[0] && dut.pair_b_valid_r[0]) |->
        ((pair_a_word_tag_r[0] == pair_b_word_tag_r[0]) &&
         (pair_a_word_tag_r[0] ==
          {1'b0, dut.element_index_r[15:1]})));
    ap_ready_slot1_tag_matches_element: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.compute_slot &&
         dut.pair_a_valid_r[1] && dut.pair_b_valid_r[1]) |->
        ((pair_a_word_tag_r[1] == pair_b_word_tag_r[1]) &&
         (pair_a_word_tag_r[1] ==
          {1'b0, dut.element_index_r[15:1]})));
    ap_ready_pair_tag_precedes_response_cursor: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.pair_ready) |->
        (dut.response_word_index_r >
         pair_a_word_tag_r[dut.compute_slot]));
    ap_parity_progress_stays_before_cutoff: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.pending_error_r == ERR_PARITY) |->
          (dut.element_index_r <= dut.memory_error_cutoff_r));
    ap_writeback_excludes_pending_parity: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == ST_WRITE) |->
          (dut.pending_error_r != ERR_PARITY));
    // Split the global parity/writeback disposition at the final-element
    // boundary. These are transition-local lemmas: they do not assume that
    // parity is unreachable or that ST_WRITE itself is unreachable.
    ap_pending_parity_blocks_last_compute: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.pending_error_r == ERR_PARITY) && dut.last_element) |->
          !dut.compute_fire);
    ap_new_parity_blocks_last_compute: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.response_parity_failure && dut.last_element) |->
          !dut.compute_fire);
    ap_last_compute_does_not_set_parity: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.compute_fire && dut.last_element) |=>
          (dut.pending_error_r != ERR_PARITY));
    ap_last_compute_enters_write_without_parity: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd1) && dut.compute_fire && dut.last_element) |=>
          ((dut.state_r == ST_WRITE) &&
           (dut.pending_error_r != ERR_PARITY)));
    ap_last_compute_enters_write_state: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == ST_RUN) && dut.compute_fire && dut.last_element) |=>
          (dut.state_r == ST_WRITE));

    cp_parity_response_at_two_outstanding: cover property (
        @(posedge clk) disable iff (!resetn)
        dut.response_parity_failure && (dut.outstanding_reads_r == 2));
    cp_parity_error_retires: cover property (
        @(posedge clk) disable iff (!resetn)
        dut.done && dut.error && (dut.error_code == ERR_PARITY));
endmodule
