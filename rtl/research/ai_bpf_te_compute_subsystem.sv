`timescale 1ns/1ps

// Isolated research integration of the product Matrix and CNM engines.
// The product top is intentionally untouched. Matrix banked reads, Matrix
// line writes, and CNM four-lane reads share the BPF-TE atomic adapter and the
// four-bank research SPAD, so this wrapper exercises real engine handshakes.
module ai_bpf_te_compute_subsystem (
    input wire clk, input wire resetn, input wire epoch_bump,
    input wire init_valid, input wire init_write, input wire [31:0] init_addr,
    input wire [31:0] init_wdata, input wire [3:0] init_wstrb,
    input wire probe_valid, input wire [31:0] probe_addr,
    input wire [3:0] bank_allow_cfg, input wire [3:0] inject_parity_error_cfg,
    input wire cnm_write_protection_error_cfg, input wire matrix_line_protection_error_cfg,
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
    output wire [31:0] denied_ops, output wire output_write_commit,
    output wire [31:0] output_write_addr, output wire [31:0] output_write_data,
    output wire matrix_line_commit, output wire [31:0] matrix_line_commit_addr,
    output wire [127:0] matrix_line_commit_data, output wire [15:0] matrix_line_commit_wstrb
    , output wire probe_rsp_valid, output wire [31:0] probe_rdata
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
    wire [3:0] bpf_rsp_dropped;
    wire cnm_spad_ready;
    wire host_valid_mux = init_valid || probe_valid;
    wire host_write_mux = init_valid && init_write && !probe_valid;
    wire [31:0] host_addr_mux = probe_valid ? probe_addr : init_addr;
    wire [31:0] host_wdata_mux = init_wdata;
    wire [3:0] host_wstrb_mux = init_wstrb;
    wire host_rsp_valid;
    wire [31:0] host_rdata;
    wire [3:0] write_bank_onehot;
    reg [31:0] accepted_bank_ops_r, response_ops_r, denied_ops_r;

    ai_banked_cnm_core cnm_u(
      .clk(clk), .resetn(resetn), .start(cnm_start), .abort(abort || epoch_bump || (|bpf_rsp_dropped)),
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
      .spad_wdata(cnm_spad_wdata), .spad_ready(cnm_spad_ready),
      .spad_protection_error(cnm_write_protection_error_cfg), .busy(cnm_busy), .done(cnm_done),
      .error(cnm_error), .error_code(cnm_error_code), .result(cnm_result),
      .cycle_count(cnm_cycles), .element_count(), .local_accumulate_events(),
      .global_reduce_events(), .banked_read_issue_events(), .prefetch_events(),
      .pipeline_compute_events(), .response_wait_cycles());

    ai_tensor_matrix_core matrix_u(
      .clk(clk), .resetn(resetn), .start(matrix_start), .abort(abort || epoch_bump || (|bpf_rsp_dropped)),
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
      .line_ready(matrix_line_ready), .line_protection_error(matrix_line_protection_error_cfg),
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
      .rsp_dropped(bpf_rsp_dropped));

    assign matrix_banked_data = matrix_rsp_data;
    // CNM writeback is a single-word Port-B operation. It is admitted only
    // when the atomic adapter has no bank transaction in this cycle; this
    // preserves the adapter's all-or-none read/line contract.
    assign write_bank_onehot = 4'b0001 << cnm_spad_addr[3:2];
    assign cnm_spad_ready = cnm_spad_valid && (bank_ready[cnm_spad_addr[3:2]]) &&
                            !(|bank_req_valid);
    wire [3:0] spad_req_valid_mux = bank_req_valid | (write_bank_onehot & {4{cnm_spad_valid && cnm_spad_ready}});
    wire [3:0] spad_req_write_mux = bank_req_write | (write_bank_onehot & {4{cnm_spad_valid && cnm_spad_ready}});
    reg [127:0] spad_req_addr_mux, spad_req_wdata_mux;
    reg [15:0] spad_req_wstrb_mux;
    always @(*) begin
      spad_req_addr_mux = bank_req_addr;
      spad_req_wdata_mux = bank_req_wdata;
      spad_req_wstrb_mux = bank_req_wstrb;
      if (cnm_spad_valid && cnm_spad_ready) begin
        spad_req_addr_mux[cnm_spad_addr[3:2]*32 +: 32] = cnm_spad_addr;
        spad_req_wdata_mux[cnm_spad_addr[3:2]*32 +: 32] = cnm_spad_wdata;
        spad_req_wstrb_mux[cnm_spad_addr[3:2]*4 +: 4] = 4'hf;
      end
    end

    ai_spad_bank_parallel_adapter spad_u(
      .clk(clk), .resetn(resetn), .host_valid(host_valid_mux), .host_write(host_write_mux),
      .host_addr(host_addr_mux), .host_wdata(host_wdata_mux), .host_wstrb(host_wstrb_mux), .host_allow(host_valid_mux),
      .host_ready(), .host_rsp_valid(host_rsp_valid), .host_rdata(host_rdata), .host_error(),
      .host_parity_error(), .bank_req_valid(spad_req_valid_mux),
      .bank_req_write(spad_req_write_mux), .bank_req_addr(spad_req_addr_mux),
      .bank_req_wdata(spad_req_wdata_mux), .bank_req_wstrb(spad_req_wstrb_mux),
      .bank_allow(bank_allow_cfg), .inject_parity_error(inject_parity_error_cfg), .bank_ready(bank_ready),
      .bank_denied(bank_denied), .bank_rsp_valid(bank_rsp_valid),
      .bank_rsp_rdata(bank_rsp_rdata), .bank_rsp_error(bank_rsp_error),
      .bank_rsp_parity_error(bank_rsp_parity));

    always @(posedge clk or negedge resetn) begin
      if (!resetn) begin
        accepted_bank_ops_r <= 0; response_ops_r <= 0; denied_ops_r <= 0;
      end else begin
        accepted_bank_ops_r <= accepted_bank_ops_r + spad_req_valid_mux[0] +
                              spad_req_valid_mux[1] + spad_req_valid_mux[2] + spad_req_valid_mux[3];
        response_ops_r <= response_ops_r + bank_rsp_valid[0] + bank_rsp_valid[1] +
                          bank_rsp_valid[2] + bank_rsp_valid[3];
        denied_ops_r <= denied_ops_r + bank_denied[0] + bank_denied[1] +
                        bank_denied[2] + bank_denied[3];
      end
    end
    assign accepted_bank_ops = accepted_bank_ops_r;
    assign response_ops = response_ops_r;
    assign denied_ops = denied_ops_r;
    assign output_write_commit = cnm_spad_valid && cnm_spad_ready;
    assign output_write_addr = cnm_spad_addr;
    assign output_write_data = cnm_spad_wdata;
    assign matrix_line_commit = matrix_line_valid && matrix_line_ready && matrix_line_write;
    assign matrix_line_commit_addr = matrix_line_addr;
    assign matrix_line_commit_data = matrix_line_wdata;
    assign matrix_line_commit_wstrb = matrix_line_wstrb;
    assign probe_rsp_valid = host_rsp_valid;
    assign probe_rdata = host_rdata;
    ai_bpf_te_compute_subsystem_sva sva_u(
      .clk(clk), .resetn(resetn), .epoch_bump(epoch_bump),
      .cnm_spad_valid(cnm_spad_valid), .cnm_spad_ready(cnm_spad_ready),
      .output_write_commit(output_write_commit), .matrix_line_commit(matrix_line_commit));
endmodule
