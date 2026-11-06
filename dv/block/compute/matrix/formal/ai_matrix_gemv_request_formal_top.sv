module ai_matrix_gemv_request_formal_top (
    input logic clk,
    input logic resetn,
    input logic start,
    input logic abort,
    input logic banked_ready,
    input logic banked_rsp_valid,
    input logic [31:0] bank0_data,
    input logic [31:0] bank1_data,
    input logic [31:0] bank2_data,
    input logic [31:0] bank3_data,
    input logic [3:0] bank_parity_error,
    input logic banked_protection_error
);
    logic banked_read_valid;
    logic [31:0] banked_addr;
    logic spad_valid;
    logic spad_write;
    logic [31:0] spad_addr;
    logic [31:0] spad_wdata;
    logic line_valid;
    logic line_write;
    logic [31:0] line_addr;
    logic [127:0] line_wdata;
    logic [15:0] line_wstrb;
    logic busy;
    logic done;
    logic error;
    logic [3:0] error_code;
    logic [31:0] result;
    logic [31:0] cycle_count;
    logic [31:0] element_count;
    logic perf_mac_active;
    logic perf_banked_wait;

    ai_tensor_matrix_core #(
        .ARRAY_SIZE(16),
        .MAX_OUTSTANDING_READS(4),
        .ENABLE_A_TILE_CACHE(1),
        .ENABLE_NEXT_K_PREFETCH(1)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .abort(abort),
        .op_mode(8'h52),
        .src0_base(32'h0000_0100),
        .src1_base(32'h0000_0200),
        .bias_base(32'h0000_0000),
        .dst_base(32'h0000_0400),
        .m_size(16'd1),
        .n_size(16'd1),
        .k_words(16'd1),
        .instance_count(32'd1),
        .src0_batch_stride(32'd0),
        .src1_batch_stride(32'd0),
        .dst_batch_stride(32'd0),
        .transpose_a(1'b0),
        .transpose_b(1'b0),
        .bias_enable(1'b0),
        .scale_shift(5'd0),
        .activation(2'd0),
        .aux0(32'd0),
        .watchdog_limit(32'd0),
        .bank0_data(bank0_data),
        .bank1_data(bank1_data),
        .bank2_data(bank2_data),
        .bank3_data(bank3_data),
        .bank_parity_error(bank_parity_error),
        .banked_read_valid(banked_read_valid),
        .banked_addr(banked_addr),
        .banked_ready(banked_ready),
        .banked_rsp_valid(banked_rsp_valid),
        .banked_protection_error(banked_protection_error),
        .spad_valid(spad_valid),
        .spad_write(spad_write),
        .spad_addr(spad_addr),
        .spad_wdata(spad_wdata),
        .spad_ready(1'b1),
        .spad_rsp_valid(1'b0),
        .spad_rdata(32'd0),
        .spad_parity_error(1'b0),
        .spad_protection_error(1'b0),
        .line_valid(line_valid),
        .line_write(line_write),
        .line_addr(line_addr),
        .line_wdata(line_wdata),
        .line_wstrb(line_wstrb),
        .line_ready(1'b1),
        .line_protection_error(1'b0),
        .busy(busy),
        .done(done),
        .error(error),
        .error_code(error_code),
        .result(result),
        .cycle_count(cycle_count),
        .element_count(element_count),
        .perf_mac_active(perf_mac_active),
        .perf_banked_wait(perf_banked_wait)
    );

    assume_reset_asserted_then_released: assume property (@(posedge clk)
        !resetn |=> resetn);
    assume_reset_stays_released: assume property (@(posedge clk)
        resetn |=> resetn);
    assume_response_has_an_accepted_owner: assume property (
        @(posedge clk) disable iff (!resetn)
        banked_rsp_valid |-> (dut.read_outstanding_count != 0));

    // A stalled 0x52 operand request remains valid with the same address until
    // accepted. Abort, a watchdog/error transition, or an already-owned fault
    // response can legally cancel the request and are explicit exceptions.
    ap_gemv_request_stable_until_accept: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.gemv_kfold_r && banked_read_valid && !banked_ready &&
         !abort && !dut.watchdog_expired &&
         !dut.banked_response_fault && !dut.banked_response_context_fault)
        |=> (abort || dut.watchdog_expired ||
             dut.state_r == 4'd13 ||
             (banked_read_valid && $stable(banked_addr))));

    cp_gemv_request_backpressure_release: cover property (
        @(posedge clk) disable iff (!resetn)
        (dut.gemv_kfold_r && banked_read_valid && !banked_ready) ##1
        (dut.gemv_kfold_r && banked_read_valid && !banked_ready) ##1
        (dut.gemv_kfold_r && banked_read_valid && banked_ready));
endmodule
