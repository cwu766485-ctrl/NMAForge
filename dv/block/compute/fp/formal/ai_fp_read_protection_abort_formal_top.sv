module ai_fp_read_protection_abort_formal_top (
    input logic clk,
    input logic resetn,
    input logic start,
    input logic abort,
    input logic spad_ready,
    input logic spad_rsp_valid,
    input logic spad_parity_error,
    input logic spad_protection_error
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

    ai_mixed_precision_dot_fp32_core dut (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .format_fp16(1'b0),
        .abort(abort),
        .src0_base(32'h0000_0100),
        .src1_base(32'h0000_0200),
        .dst_base(32'h0000_0300),
        .length(16'd1),
        .watchdog_limit(32'd0),
        .spad_valid(spad_valid),
        .spad_ready(spad_ready),
        .spad_write(spad_write),
        .spad_addr(spad_addr),
        .spad_wdata(spad_wdata),
        .spad_rsp_valid(spad_rsp_valid),
        .spad_rdata(32'd0),
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

    assume property (@(posedge clk) !resetn |=> resetn);
    assume property (@(posedge clk) resetn |=> resetn);

    ap_abort_blocks_read_accept: assert property (
        @(posedge clk) disable iff (!resetn)
        busy && (dut.state_r == 4'd1) && abort |-> !dut.read_fire);
    ap_abort_blocks_read_protection_failure: assert property (
        @(posedge clk) disable iff (!resetn)
        busy && (dut.state_r == 4'd1) && abort &&
        spad_ready && spad_protection_error |->
        !dut.read_protection_failure);
    cp_abort_protection_attempt_reachable: cover property (
        @(posedge clk) disable iff (!resetn)
        busy && (dut.state_r == 4'd1) && abort &&
        spad_ready && spad_protection_error);
    cp_read_protection_failure_reachable: cover property (
        @(posedge clk) disable iff (!resetn)
        busy && (dut.state_r == 4'd1) && !abort &&
        spad_ready && spad_protection_error && dut.read_fire &&
        dut.read_protection_failure);

    // A Parity response to an already accepted read masks the next request.
    // Thus a simultaneous Protection sideband can be present, but cannot be
    // qualified as a new accepted-read Protection failure on that edge.
    ap_parity_response_excludes_read_protection_failure: assert property (
        @(posedge clk) disable iff (!resetn)
        busy && (dut.state_r == 4'd1) && dut.response_parity_failure |->
        !dut.read_protection_failure);
    cp_parity_response_with_outstanding_read_reachable: cover property (
        @(posedge clk) disable iff (!resetn)
        busy && (dut.state_r == 4'd1) && (dut.outstanding_reads_r != 0) &&
        dut.response_parity_failure);
    cp_parity_response_and_protection_sideband_reachable: cover property (
        @(posedge clk) disable iff (!resetn)
        busy && (dut.state_r == 4'd1) && (dut.outstanding_reads_r != 0) &&
        dut.response_parity_failure && spad_protection_error);
endmodule
