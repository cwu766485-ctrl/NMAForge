// Integration-boundary formal harness for the product's registered SPAD.
// Unlike the unconstrained-latency block harness, this model returns every
// accepted read exactly two sampled clocks later, matching the shared
// arbiter's response tag pipeline and the scratchpad's two-cycle read port.
module ai_fp_core_parity_2cycle_spad_formal_top (
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
    logic        spad_rsp_valid;
    logic        busy;
    logic        done;
    logic        error;
    logic [3:0]  error_code;
    logic [31:0] result;
    logic [31:0] cycle_count;
    logic [31:0] element_count;
    logic        read_fire_d1_r;
    logic        read_fire_d2_r;

    ai_mixed_precision_dot_fp32_core dut (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .format_fp16(format_fp16),
        .abort(abort),
        .src0_base(src0_base),
        .src1_base(src1_base),
        .dst_base(dst_base),
        .length(length),
        .watchdog_limit(watchdog_limit),
        .spad_valid(spad_valid),
        .spad_write(spad_write),
        .spad_addr(spad_addr),
        .spad_wdata(spad_wdata),
        .spad_ready(spad_ready),
        .spad_rsp_valid(spad_rsp_valid),
        .spad_rdata(spad_rdata),
        .spad_parity_error(spad_parity_error),
        .spad_protection_error(spad_protection_error),
        .busy(busy),
        .done(done),
        .error(error),
        .error_code(error_code),
        .result(result),
        .cycle_count(cycle_count),
        .element_count(element_count)
    );

    // A shift register models the exact response latency from an accepted
    // core read. Writes and requests stalled by the arbiter create no entry.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            read_fire_d1_r <= 1'b0;
            read_fire_d2_r <= 1'b0;
        end else begin
            read_fire_d1_r <= dut.read_fire;
            read_fire_d2_r <= read_fire_d1_r;
        end
    end
    always @* spad_rsp_valid = read_fire_d2_r;

    assume property (@(posedge clk) !resetn |=> resetn);
    assume property (@(posedge clk) resetn |=> resetn);
    assume property (@(posedge clk) disable iff (!resetn)
        start |-> ((length != 16'd0) &&
                   (src0_base[1:0] == 2'b00) &&
                   (src1_base[1:0] == 2'b00) &&
                   (dst_base[1:0] == 2'b00) &&
                   (watchdog_limit == 0)));
    assume property (@(posedge clk) !abort);
    // Isolate the parity path; response-side parity itself remains arbitrary.
    assume property (@(posedge clk) !spad_protection_error);

    ap_response_only_for_outstanding_read: assert property (
        @(posedge clk) disable iff (!resetn)
        spad_rsp_valid |-> (dut.outstanding_reads_r != 0));
    ap_final_pair_not_ready_on_parity_response: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.response_parity_failure && dut.last_element) |->
          !dut.pair_ready);
    ap_new_parity_blocks_last_compute: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.response_parity_failure && dut.last_element) |->
          !dut.compute_fire);
    ap_pending_parity_blocks_last_compute: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.pending_error_r == ERR_PARITY) && dut.last_element) |->
          !dut.compute_fire);
    ap_writeback_excludes_pending_parity: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == ST_WRITE) |->
          (dut.pending_error_r != ERR_PARITY));
    ap_parity_cutoff_is_valid: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.pending_error_r == ERR_PARITY) |->
          (dut.memory_error_cutoff_valid_r &&
           (dut.memory_error_cutoff_r < dut.length_r)));

    cp_final_pair_ready_on_parity_response: cover property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == ST_RUN) && dut.response_parity_failure &&
        dut.last_element && dut.pair_ready);
    cp_parity_response_at_two_outstanding: cover property (
        @(posedge clk) disable iff (!resetn)
        dut.response_parity_failure && (dut.outstanding_reads_r == 2));
    cp_parity_error_retires: cover property (
        @(posedge clk) disable iff (!resetn)
        done && error && (error_code == ERR_PARITY));
endmodule

// Bounded refinement wrapper for short-vector parity lifecycle questions.
// The child keeps the exact two-cycle response contract; this extra
// assumption restricts legal descriptors to the length-1..4 proof slice.
module ai_fp_core_parity_2cycle_spad_small_formal_top (
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
    input logic [31:0] spad_rdata,
    input logic        spad_parity_error,
    input logic        spad_protection_error
);
    ai_fp_core_parity_2cycle_spad_formal_top core (.*);

    assume property (@(posedge clk) disable iff (!resetn)
        start |-> (length <= 16'd4));
endmodule
