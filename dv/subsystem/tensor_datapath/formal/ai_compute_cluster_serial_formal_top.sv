module ai_compute_cluster_serial_formal_top (
    input logic clk,
    input logic resetn,
    input logic core_start,
    input logic [7:0] launch_op
);
    logic banked_op,tensor_matrix_op,tensor_sfu_op,kv_cache_op;
    logic conv_linebuffer_op,fp_op,scalar_op,op_valid,is_int8,is_macro;
    logic is_bf16_dot,is_fp16_dot;
    logic scalar_busy,fp_busy,banked_busy,matrix_busy,sfu_busy,conv_busy,kv_busy;
    logic core_busy,core_done,core_error;
    logic [3:0] core_error_code;
    logic [31:0] core_result,core_cycle_count,core_element_count;
    logic [3:0] cnm_read_valid;
    logic [31:0] cnm_read_addr0,cnm_read_addr1,cnm_read_addr2,cnm_read_addr3;
    logic banked_spad_valid,banked_spad_write,matrix_banked_read_valid;
    logic [31:0] banked_spad_addr,banked_spad_wdata,matrix_banked_read_addr;
    logic matrix_spad_valid,matrix_spad_write;
    logic [31:0] matrix_spad_addr,matrix_spad_wdata;
    logic matrix_line_valid,matrix_line_write;
    logic [31:0] matrix_line_addr;
    logic [127:0] matrix_line_wdata;
    logic [15:0] matrix_line_wstrb;
    logic sfu_spad_valid,sfu_spad_write;
    logic [31:0] sfu_spad_addr,sfu_spad_wdata;
    logic conv_spad_valid,conv_spad_write;
    logic [31:0] conv_spad_addr,conv_spad_wdata;
    logic kv_spad_valid,kv_spad_write;
    logic [31:0] kv_spad_addr,kv_spad_wdata;
    logic scalar_spad_valid,scalar_spad_write;
    logic [31:0] scalar_spad_addr,scalar_spad_wdata;
    logic fp_spad_valid,fp_spad_write;
    logic [31:0] fp_spad_addr,fp_spad_wdata;

    assign conv_linebuffer_op = (launch_op==8'h16)||(launch_op==8'h17);
    assign fp_op = (launch_op==8'h50)||(launch_op==8'h51);
    assign scalar_op = !(banked_op||tensor_matrix_op||tensor_sfu_op||
                         conv_linebuffer_op||kv_cache_op||fp_op);

    ai_accel_opcode_decode opcode_decode_u(
        .op(launch_op),.op_valid(op_valid),.is_int8(is_int8),
        .is_banked(banked_op),.is_tensor_matrix(tensor_matrix_op),
        .is_tensor_sfu(tensor_sfu_op),.is_cnn_kv(kv_cache_op),
        .is_macro(is_macro),.is_bf16_dot(is_bf16_dot),.is_fp16_dot(is_fp16_dot));

    // The command processor is the sole production source of core_start and
    // gates dispatch on scheduler_resources_idle. Its lifecycle is separately
    // checked by the CP formal harness; this harness checks all real engine
    // RTL under that integration contract.
    as_dispatch_waits_for_cluster_idle: assume property (
        @(posedge clk) disable iff (!resetn)
        core_busy |-> !core_start);

    ai_accel_compute_cluster cluster_u(
        .aclk(clk),.aresetn(resetn),.core_start(core_start),.core_abort(1'b0),
        .banked_op(banked_op),.tensor_matrix_op(tensor_matrix_op),
        .tensor_sfu_op(tensor_sfu_op),.conv_linebuffer_op(conv_linebuffer_op),
        .kv_cache_op(kv_cache_op),.launch_op(launch_op),
        .launch_src0(32'h0000_0100),.launch_src1(32'h0000_0200),
        .launch_dst(32'h0000_0400),.launch_length(16'd4),
        .launch_m(16'd4),.launch_n(16'd4),.launch_k(16'd1),
        .launch_shift(5'd0),.launch_activation(2'd0),
        .launch_bias_base(32'h0000_0300),.launch_bias_enable(1'b0),
        .launch_flags(8'd0),.launch_aux0(32'd1),
        .launch_src0_stride(32'd0),.launch_src1_stride(32'd0),
        .launch_dst_stride(32'd0),.launch_instance_count(32'd1),
        .watchdog_limit(32'd16),
        .arb_cnm_ready(4'hf),.cnm_rsp_valid(4'hf),
        .cnm_data0(32'd0),.cnm_data1(32'd0),.cnm_data2(32'd0),.cnm_data3(32'd0),
        .cnm_parity(4'd0),.cnm_protection_error(1'b0),
        .banked_data0(32'd0),.banked_data1(32'd0),
        .banked_data2(32'd0),.banked_data3(32'd0),.banked_parity(4'd0),
        .arb_banked_ready(1'b1),.banked_rsp_valid(1'b1),
        .banked_protection_error(1'b0),.arb_core_ready(1'b1),
        .core_rsp_valid(1'b1),.arb_rsp_rdata(32'd0),.core_rsp_error(1'b0),
        .core_spad_parity_error(1'b0),.compute_prot_error(1'b0),
        .arb_core_line_ready(1'b1),.line_prot_error(1'b0),
        .spad_line_raw_error(1'b0),
        .cnm_read_valid(cnm_read_valid),.cnm_read_addr0(cnm_read_addr0),
        .cnm_read_addr1(cnm_read_addr1),.cnm_read_addr2(cnm_read_addr2),
        .cnm_read_addr3(cnm_read_addr3),.banked_spad_valid(banked_spad_valid),
        .banked_spad_write(banked_spad_write),.banked_spad_addr(banked_spad_addr),
        .banked_spad_wdata(banked_spad_wdata),
        .matrix_banked_read_valid(matrix_banked_read_valid),
        .matrix_banked_read_addr(matrix_banked_read_addr),
        .matrix_spad_valid(matrix_spad_valid),.matrix_spad_write(matrix_spad_write),
        .matrix_spad_addr(matrix_spad_addr),.matrix_spad_wdata(matrix_spad_wdata),
        .matrix_line_valid(matrix_line_valid),.matrix_line_write(matrix_line_write),
        .matrix_line_addr(matrix_line_addr),.matrix_line_wdata(matrix_line_wdata),
        .matrix_line_wstrb(matrix_line_wstrb),.sfu_spad_valid(sfu_spad_valid),
        .sfu_spad_write(sfu_spad_write),.sfu_spad_addr(sfu_spad_addr),
        .sfu_spad_wdata(sfu_spad_wdata),.conv_spad_valid(conv_spad_valid),
        .conv_spad_write(conv_spad_write),.conv_spad_addr(conv_spad_addr),
        .conv_spad_wdata(conv_spad_wdata),.kv_spad_valid(kv_spad_valid),
        .kv_spad_write(kv_spad_write),.kv_spad_addr(kv_spad_addr),
        .kv_spad_wdata(kv_spad_wdata),.scalar_spad_valid(scalar_spad_valid),
        .scalar_spad_write(scalar_spad_write),.scalar_spad_addr(scalar_spad_addr),
        .scalar_spad_wdata(scalar_spad_wdata),.fp_spad_valid(fp_spad_valid),
        .fp_spad_write(fp_spad_write),.fp_spad_addr(fp_spad_addr),
        .fp_spad_wdata(fp_spad_wdata),.scalar_busy(scalar_busy),.fp_busy(fp_busy),
        .banked_busy(banked_busy),.matrix_busy(matrix_busy),.sfu_busy(sfu_busy),
        .conv_busy(conv_busy),.kv_busy(kv_busy),.core_busy(core_busy),
        .core_done(core_done),.core_error(core_error),.core_error_code(core_error_code),
        .core_result(core_result),.core_cycle_count(core_cycle_count),
        .core_element_count(core_element_count),.matrix_perf_mac_active(),
        .matrix_perf_banked_wait());

    ap_engine_busy_is_onehot0: assert property (
        @(posedge clk) disable iff (!resetn)
        $onehot0({scalar_busy,fp_busy,banked_busy,matrix_busy,
                  sfu_busy,conv_busy,kv_busy}));

    ap_core_busy_matches_engine_vector: assert property (
        @(posedge clk) disable iff (!resetn)
        core_busy == |{scalar_busy,fp_busy,banked_busy,matrix_busy,
                       sfu_busy,conv_busy,kv_busy});

    ap_opcode_classes_are_exclusive: assert property (
        @(posedge clk) disable iff (!resetn)
        $onehot0({scalar_op,fp_op,kv_cache_op,conv_linebuffer_op,
                  tensor_sfu_op,tensor_matrix_op,banked_op}));

    cp_scalar_dispatch: cover property (@(posedge clk) disable iff (!resetn)
        core_start && scalar_op ##1 scalar_busy);
    cp_fp_dispatch: cover property (@(posedge clk) disable iff (!resetn)
        core_start && fp_op ##1 fp_busy);
    cp_banked_dispatch: cover property (@(posedge clk) disable iff (!resetn)
        core_start && banked_op ##1 banked_busy);
    cp_matrix_dispatch: cover property (@(posedge clk) disable iff (!resetn)
        core_start && tensor_matrix_op ##1 matrix_busy);
    cp_sfu_dispatch: cover property (@(posedge clk) disable iff (!resetn)
        core_start && tensor_sfu_op ##1 sfu_busy);
    cp_conv_dispatch: cover property (@(posedge clk) disable iff (!resetn)
        core_start && conv_linebuffer_op ##1 conv_busy);
    cp_kv_dispatch: cover property (@(posedge clk) disable iff (!resetn)
        core_start && kv_cache_op ##1 kv_busy);
endmodule
