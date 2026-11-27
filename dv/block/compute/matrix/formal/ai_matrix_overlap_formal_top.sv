module ai_matrix_overlap_formal_top (
    input logic clk,
    input logic resetn,
    input logic start,
    input logic banked_ready,
    input logic banked_rsp_valid,
    input logic line_ready
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
        .ENABLE_A_TILE_CACHE(0),
        .ENABLE_NEXT_K_PREFETCH(0),
        .ENABLE_GEMV_B_TILE_CACHE(0),
        .ENABLE_GEMM_B_TILE_CACHE(0),
        .ENABLE_ELASTIC_TILE_FORWARDING(0)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .abort(1'b0),
        .op_mode(8'h30),
        .src0_base(32'h0000_1000),
        .src1_base(32'h0000_2000),
        .bias_base(32'h0000_0000),
        .dst_base(32'h0000_4000),
        .m_size(16'd32),
        .n_size(16'd32),
        .k_words(16'd1),
        .instance_count(32'd1),
        .src0_batch_stride(32'd0),
        .src1_batch_stride(32'd0),
        .dst_batch_stride(32'd0),
        .transpose_a(1'b0),
        .transpose_b(1'b0),
        .bias_enable(1'b0),
        .scale_shift(5'd0),
        .activation(2'd0), .accumulate(1'b0),
        .aux0(32'd0),
        .watchdog_limit(32'd0),
        .bank0_data(32'd0),
        .bank1_data(32'd0),
        .bank2_data(32'd0),
        .bank3_data(32'd0),
        .bank_parity_error(4'd0),
        .banked_read_valid(banked_read_valid),
        .banked_addr(banked_addr),
        .banked_ready(banked_ready),
        .banked_rsp_valid(banked_rsp_valid),
        .banked_protection_error(1'b0),
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
        .line_ready(line_ready),
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
    assume_start_only_when_idle: assume property (
        @(posedge clk) disable iff (!resetn) start |-> (dut.state_r == 4'd0));
    assume_banked_response_has_owner: assume property (
        @(posedge clk) disable iff (!resetn)
        banked_rsp_valid |-> (dut.read_outstanding_count != 0));

    ap_overlap_writer_has_legal_owner: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.matrix_overlap_wb_active_r |->
        (dut.matrix_overlap_enabled_r && line_valid && line_write &&
         (line_addr == dut.matrix_overlap_line_addr) &&
         (line_wdata == {dut.matrix_overlap_word3,dut.matrix_overlap_word2,
                         dut.matrix_overlap_word1,dut.matrix_overlap_word0}) &&
         (line_wstrb == 16'hffff)));

    ap_overlap_stalled_line_is_stable: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.matrix_overlap_wb_active_r && line_valid && !line_ready)
        |=> (dut.matrix_overlap_wb_active_r && line_valid &&
             $stable(line_addr) && $stable(line_wdata) &&
             $stable(line_wstrb)));

    ap_overlap_wait_preserves_accumulator: assert property (
        @(posedge clk) disable iff (!resetn)
        ((dut.state_r == 4'd10) && dut.matrix_overlap_capture_pending_r &&
         dut.matrix_overlap_wb_active_r) |-> !dut.array_clear_accumulators);

    ap_overlap_launch_claims_buffer: assert property (
        @(posedge clk) disable iff (!resetn)
        dut.matrix_overlap_launch |=> dut.matrix_overlap_wb_active_r);

    cp_overlap_mac_and_writeback: cover property (
        @(posedge clk) disable iff (!resetn)
        dut.matrix_overlap_wb_active_r && (dut.state_r == 4'd8));
    cp_overlap_second_tile_waits_for_owner: cover property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd10) && dut.matrix_overlap_capture_pending_r &&
        dut.matrix_overlap_wb_active_r);
    cp_overlap_stalled_buffered_line: cover property (
        @(posedge clk) disable iff (!resetn)
        dut.matrix_overlap_wb_active_r && line_valid && !line_ready);
endmodule
