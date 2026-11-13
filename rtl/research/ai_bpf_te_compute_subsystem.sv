`timescale 1ns/1ps

// Isolated research integration of the product Matrix and CNM engines.
// The product top is intentionally untouched. Matrix banked reads, Matrix
// line writes, and CNM four-lane reads share the BPF-TE atomic adapter and the
// four-bank research SPAD, so this wrapper exercises real engine handshakes.
module ai_bpf_te_compute_subsystem (
    input wire clk, input wire resetn, input wire epoch_bump,
    input wire init_valid, input wire init_write, input wire [31:0] init_addr,
    input wire [31:0] init_wdata, input wire [3:0] init_wstrb,
    input wire matrix_start, input wire cnm_start, input wire abort,
    input wire [7:0] op_mode,
    input wire [31:0] matrix_src0, matrix_src1, matrix_dst,
    input wire [15:0] matrix_m, matrix_n, matrix_k,
    input wire [31:0] matrix_instance_count, matrix_src0_stride,
    input wire [31:0] matrix_src1_stride, matrix_dst_stride, matrix_aux0,
    input wire matrix_transpose_a, matrix_transpose_b, matrix_bias_enable,
    input wire [31:0] matrix_bias_base,
    input wire [4:0] matrix_shift, input wire [1:0] matrix_activation,
    input wire [31:0] cnm_src0, cnm_src1, cnm_dst,
    input wire [15:0] cnm_length, cnm_m,
    input wire [4:0] cnm_shift, input wire [1:0] cnm_activation,
    input wire [31:0] watchdog_limit,
    output wire matrix_busy, matrix_done, matrix_error,
    output wire [3:0] matrix_error_code, output wire [31:0] matrix_result,
    output wire [31:0] matrix_cycles,
    output wire cnm_busy, cnm_done, cnm_error,
    output wire [3:0] cnm_error_code, output wire [31:0] cnm_result,
    output wire [31:0] cnm_cycles,
    output wire [31:0] accepted_bank_ops, output wire [31:0] response_ops,
    output wire [31:0] denied_ops
);
    localparam integer BANKS = 4;
    wire [3:0] cnm_req_valid, cnm_req_ready, cnm_rsp_valid;
    wire [31:0] cnm_addr0, cnm_addr1, cnm_addr2, cnm_addr3;
    wire [127:0] cnm_rsp_data, matrix_rsp_data;
    wire [3:0] cnm_rsp_error, matrix_rsp_error;
    wire matrix_banked_valid, matrix_banked_ready, matrix_banked_rsp_valid;
    wire [31:0] matrix_banked_addr;
    wire matrix_line_valid, matrix_line_ready, matrix_line_rsp_valid;
    wire matrix_line_write;
    wire [31:0] matrix_line_addr;
    wire [127:0] matrix_line_wdata;
    wire [15:0] matrix_line_wstrb;
    wire cnm_spad_valid, cnm_spad_write;
    wire [31:0] cnm_spad_addr, cnm_spad_wdata;
    wire [3:0] bank_ready, bank_rsp_valid, bank_req_valid, bank_req_write;
    wire [127:0] matrix_banked_data;
    wire [BANKS*32-1:0] bank_req_addr, bank_req_wdata;
    wire [BANKS*4-1:0] bank_req_wstrb;
    wire [BANKS*32-1:0] bank_rsp_rdata;
    wire [3:0] bank_rsp_error;
    wire [3:0] bank_denied, bank_rsp_parity;
    wire [3:0] unused_host_rdata;

    ai_banked_cnm_core cnm_u(
      .clk(clk), .resetn(resetn), .start(cnm_start), .abort(abort),
      .op_mode(op_mode), .src0_base(cnm_src0), .src1_base(cnm_src1),
      .dst_base(cnm_dst), .length(cnm_length), .m_size(cnm_m),
      .scale_shift(cnm_shift), .activation(cnm_activation),
      .watchdog_limit(watchdog_limit), .cnm_req_valid(cnm_req_valid),
      .cnm_addr0(cnm_addr0), .cnm_addr1(cnm_addr1), .cnm_addr2(cnm_addr2),
      .cnm_addr3(cnm_addr3), .cnm_req_ready(cnm_req_ready),
      .cnm_rsp_valid(cnm_rsp_valid), .cnm_data0(cnm_rsp_data[31:0]),
      .cnm_data1(cnm_rsp_data[63:32]), .cnm_data2(cnm_rsp_data[95:64]),
      .cnm_data3(cnm_rsp_data[127:96]), .cnm_parity_error(cnm_rsp_error),
      .cnm_protection_error(|cnm_rsp_error), .spad_valid(cnm_spad_valid),
      .spad_write(cnm_spad_write), .spad_addr(cnm_spad_addr),
      .spad_wdata(cnm_spad_wdata), .spad_ready(1'b1),
      .spad_protection_error(1'b0), .busy(cnm_busy), .done(cnm_done),
      .error(cnm_error), .error_code(cnm_error_code), .result(cnm_result),
      .cycle_count(cnm_cycles), .element_count(), .local_accumulate_events(),
      .global_reduce_events(), .banked_read_issue_events(), .prefetch_events(),
      .pipeline_compute_events(), .response_wait_cycles());

    ai_tensor_matrix_core matrix_u(
      .clk(clk), .resetn(resetn), .start(matrix_start), .abort(abort),
      .op_mode(op_mode), .src0_base(matrix_src0), .src1_base(matrix_src1),
      .bias_base(matrix_bias_base), .dst_base(matrix_dst), .m_size(matrix_m),
      .n_size(matrix_n), .k_words(matrix_k), .instance_count(matrix_instance_count),
      .src0_batch_stride(matrix_src0_stride), .src1_batch_stride(matrix_src1_stride),
      .dst_batch_stride(matrix_dst_stride), .aux0(matrix_aux0),
      .transpose_a(matrix_transpose_a), .transpose_b(matrix_transpose_b),
      .bias_enable(matrix_bias_enable), .scale_shift(matrix_shift),
      .activation(matrix_activation), .watchdog_limit(watchdog_limit),
      .bank0_data(matrix_banked_data[31:0]), .bank1_data(matrix_banked_data[63:32]),
      .bank2_data(matrix_banked_data[95:64]), .bank3_data(matrix_banked_data[127:96]),
      .bank_parity_error(bank_rsp_parity), .banked_read_valid(matrix_banked_valid),
      .banked_addr(matrix_banked_addr), .banked_ready(matrix_banked_ready),
      .banked_rsp_valid(matrix_banked_rsp_valid), .banked_protection_error(|bank_rsp_error),
      .spad_valid(), .spad_write(), .spad_addr(), .spad_wdata(), .spad_ready(1'b1),
      .spad_rsp_valid(1'b0), .spad_rdata(32'd0), .spad_parity_error(1'b0),
      .spad_protection_error(1'b0), .line_valid(matrix_line_valid),
      .line_write(matrix_line_write), .line_addr(matrix_line_addr),
      .line_wdata(matrix_line_wdata), .line_wstrb(matrix_line_wstrb),
      .line_ready(matrix_line_ready), .line_protection_error(1'b0),
      .busy(matrix_busy), .done(matrix_done), .error(matrix_error),
      .error_code(matrix_error_code), .result(matrix_result),
      .cycle_count(matrix_cycles), .element_count(), .perf_mac_active(),
      .perf_banked_wait());

    ai_bpf_te_atomic_adapter atomic_u(
      .clk(clk), .resetn(resetn), .epoch_bump(epoch_bump),
      .line_valid(matrix_line_valid), .line_write(matrix_line_write),
      .line_addr(matrix_line_addr), .line_wdata(matrix_line_wdata),
      .line_wstrb(matrix_line_wstrb), .line_owner(3'd3), .line_tile(8'd0),
      .line_ready(matrix_line_ready), .line_rsp_valid(matrix_line_rsp_valid),
      .line_rsp_rdata(), .line_rsp_error(), .cnm_valid(cnm_req_valid),
      .cnm_addr0(cnm_addr0), .cnm_addr1(cnm_addr1), .cnm_addr2(cnm_addr2),
      .cnm_addr3(cnm_addr3), .cnm_owner(3'd5), .cnm_tile(8'd0),
      .cnm_ready(cnm_req_ready), .cnm_rsp_valid(cnm_rsp_valid),
      .cnm_rsp_rdata(cnm_rsp_data), .cnm_rsp_error(cnm_rsp_error),
      .matrix_valid(matrix_banked_valid), .matrix_addr(matrix_banked_addr),
      .matrix_owner(3'd3), .matrix_tile(8'd0), .matrix_ready(matrix_banked_ready),
      .matrix_rsp_valid(matrix_banked_rsp_valid), .matrix_rsp_rdata(matrix_rsp_data),
      .matrix_rsp_error(matrix_rsp_error), .bank_req_valid(bank_req_valid),
      .bank_req_write(bank_req_write), .bank_req_addr(bank_req_addr),
      .bank_req_wdata(bank_req_wdata), .bank_req_wstrb(bank_req_wstrb),
      .bank_ready(bank_ready), .bank_rsp_valid(bank_rsp_valid),
      .bank_rsp_rdata(bank_rsp_rdata), .bank_rsp_error(bank_rsp_error),
      .rsp_dropped());

    assign matrix_banked_data = matrix_rsp_data;
    ai_spad_bank_parallel_adapter spad_u(
      .clk(clk), .resetn(resetn), .host_valid(init_valid), .host_write(init_write),
      .host_addr(init_addr), .host_wdata(init_wdata), .host_wstrb(init_wstrb), .host_allow(init_valid),
      .host_ready(), .host_rsp_valid(), .host_rdata(), .host_error(),
      .host_parity_error(), .bank_req_valid(bank_req_valid),
      .bank_req_write(bank_req_write), .bank_req_addr(bank_req_addr),
      .bank_req_wdata(bank_req_wdata), .bank_req_wstrb(bank_req_wstrb),
      .bank_allow(4'b1111), .inject_parity_error(4'b0000), .bank_ready(bank_ready),
      .bank_denied(bank_denied), .bank_rsp_valid(bank_rsp_valid),
      .bank_rsp_rdata(bank_rsp_rdata), .bank_rsp_error(bank_rsp_error),
      .bank_rsp_parity_error(bank_rsp_parity));

    assign accepted_bank_ops = 32'd0;
    assign response_ops = 32'd0;
    assign denied_ops = {28'd0, |bank_denied};
endmodule
