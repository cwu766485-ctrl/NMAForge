module ai_matrix_fsm_formal_top (
    input logic clk,
    input logic resetn,
    input logic start,
    input logic abort,
    input logic [7:0] op_mode,
    input logic [31:0] src0_base,
    input logic [31:0] src1_base,
    input logic [31:0] bias_base,
    input logic [31:0] dst_base,
    input logic [15:0] m_size,
    input logic [15:0] n_size,
    input logic [15:0] k_words,
    input logic [31:0] instance_count,
    input logic [31:0] src0_batch_stride,
    input logic [31:0] src1_batch_stride,
    input logic [31:0] dst_batch_stride,
    input logic transpose_a,
    input logic transpose_b,
    input logic bias_enable,
    input logic [4:0] scale_shift,
    input logic [1:0] activation,
    input logic [31:0] watchdog_limit,
    input logic [31:0] bank0_data,
    input logic [31:0] bank1_data,
    input logic [31:0] bank2_data,
    input logic [31:0] bank3_data,
    input logic [3:0] bank_parity_error,
    input logic banked_ready,
    input logic banked_rsp_valid,
    input logic banked_protection_error,
    input logic spad_ready,
    input logic spad_rsp_valid,
    input logic [31:0] spad_rdata,
    input logic spad_parity_error,
    input logic spad_protection_error,
    input logic line_ready,
    input logic line_protection_error
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
    ) dut (.*);

    // Legal registered-SPAD environment: a banked response can only return
    // while a previously accepted request is outstanding. Other inputs stay
    // unconstrained, including start/abort/fault timing.
    assume_reset_asserted_then_released: assume property (@(posedge clk)
        !resetn |=> resetn);
    assume_reset_stays_released: assume property (@(posedge clk)
        resetn |=> resetn);
    assume_bounded_legal_descriptor: assume property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd0 && start) |->
        (op_mode == 8'h30 && m_size == 16'd4 && n_size == 16'd4 &&
         k_words == 16'd3 && instance_count == 32'd1 &&
         src0_base == 32'h0000_0100 && src1_base == 32'h0000_0200 &&
         dst_base == 32'h0000_0400 && bias_enable == 1'b0));
    assume_banked_response_has_owner: assume property (
        @(posedge clk) disable iff (!resetn)
        banked_rsp_valid |-> (dut.read_outstanding_count != 0));

    // The default-profile misses are reviewed through reachable source states,
    // state invariants and one-step next-transition properties. Do not force
    // internal FSM encodings or inject an unowned response.
    ap_prefetch_wait_does_not_fall_back_to_a_req: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd14) |=> (dut.state_r != 4'd1));
    ap_idle_has_no_outstanding_reads: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd0) |-> (dut.read_outstanding_count == 0));
    ap_error_has_no_outstanding_reads: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd12) |-> (dut.read_outstanding_count == 0));
    ap_idle_does_not_enter_error_drain: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd0) |=> (dut.state_r != 4'd13));
    ap_error_does_not_reenter_error_drain: assert property (
        @(posedge clk) disable iff (!resetn)
        (dut.state_r == 4'd12) |=> (dut.state_r != 4'd13));

    cp_prefetch_wait_reachable: cover property (@(posedge clk)
        disable iff (!resetn) dut.state_r == 4'd14);
    cp_error_drain_reachable: cover property (@(posedge clk)
        disable iff (!resetn) dut.state_r == 4'd13);
endmodule
