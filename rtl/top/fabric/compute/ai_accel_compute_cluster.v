// Structural wrapper for the accelerator compute engines.
module ai_accel_compute_cluster (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire        core_start,
    input  wire        core_abort,
    input  wire        banked_op,
    input  wire        tensor_matrix_op,
    input  wire        tensor_sfu_op,
    input  wire        conv_linebuffer_op,
    input  wire        kv_cache_op,

    input  wire [7:0]  launch_op,
    input  wire [31:0] launch_src0,
    input  wire [31:0] launch_src1,
    input  wire [31:0] launch_dst,
    input  wire [15:0] launch_length,
    input  wire [15:0] launch_m,
    input  wire [15:0] launch_n,
    input  wire [15:0] launch_k,
    input  wire [4:0]  launch_shift,
    input  wire [1:0]  launch_activation,
    input  wire [31:0] launch_bias_base,
    input  wire        launch_bias_enable,
    input  wire [7:0]  launch_flags,
    input  wire [31:0] launch_aux0,
    input  wire [31:0] launch_src0_stride,
    input  wire [31:0] launch_src1_stride,
    input  wire [31:0] launch_dst_stride,
    input  wire [31:0] launch_instance_count,
    input  wire [31:0] watchdog_limit,

    input  wire [3:0]  arb_cnm_ready,
    // ai_spad_arbiter returns one registered response-valid bit per bank.
    // Preserve this vector through the wrapper; bank-local controllers each
    // consume their corresponding lane.
    input  wire [3:0]  cnm_rsp_valid,
    input  wire [31:0] cnm_data0,
    input  wire [31:0] cnm_data1,
    input  wire [31:0] cnm_data2,
    input  wire [31:0] cnm_data3,
    input  wire [3:0]  cnm_parity,
    input  wire        cnm_protection_error,

    input  wire [31:0] banked_data0,
    input  wire [31:0] banked_data1,
    input  wire [31:0] banked_data2,
    input  wire [31:0] banked_data3,
    input  wire [3:0]  banked_parity,
    input  wire        arb_banked_ready,
    input  wire        banked_rsp_valid,
    input  wire        banked_protection_error,

    input  wire        arb_core_ready,
    input  wire        core_rsp_valid,
    input  wire [31:0] arb_rsp_rdata,
    input  wire        core_rsp_error,
    input  wire [6:0]  engine_core_ready,
    input  wire [6:0]  engine_core_rsp_valid,
    input  wire [223:0] engine_core_rsp_rdata,
    input  wire [6:0]  engine_core_rsp_error,
    input  wire [6:0]  engine_core_protection_error,
    input  wire        core_spad_parity_error,
    input  wire        compute_prot_error,
    input  wire        arb_core_line_ready,
    input  wire        line_prot_error,
    input  wire        spad_line_raw_error,

    output wire [3:0]  cnm_read_valid,
    output wire [31:0] cnm_read_addr0,
    output wire [31:0] cnm_read_addr1,
    output wire [31:0] cnm_read_addr2,
    output wire [31:0] cnm_read_addr3,

    output wire        banked_spad_valid,
    output wire        banked_spad_write,
    output wire [31:0] banked_spad_addr,
    output wire [31:0] banked_spad_wdata,

    output wire        matrix_banked_read_valid,
    output wire [31:0] matrix_banked_read_addr,
    output wire        matrix_spad_valid,
    output wire        matrix_spad_write,
    output wire [31:0] matrix_spad_addr,
    output wire [31:0] matrix_spad_wdata,
    output wire        matrix_line_valid,
    output wire        matrix_line_write,
    output wire [31:0] matrix_line_addr,
    output wire [127:0] matrix_line_wdata,
    output wire [15:0] matrix_line_wstrb,

    output wire        sfu_spad_valid,
    output wire        sfu_spad_write,
    output wire [31:0] sfu_spad_addr,
    output wire [31:0] sfu_spad_wdata,

    output wire        conv_spad_valid,
    output wire        conv_spad_write,
    output wire [31:0] conv_spad_addr,
    output wire [31:0] conv_spad_wdata,

    output wire        kv_spad_valid,
    output wire        kv_spad_write,
    output wire [31:0] kv_spad_addr,
    output wire [31:0] kv_spad_wdata,

    output wire        scalar_spad_valid,
    output wire        scalar_spad_write,
    output wire [31:0] scalar_spad_addr,
    output wire [31:0] scalar_spad_wdata,

    output wire        fp_spad_valid,
    output wire        fp_spad_write,
    output wire [31:0] fp_spad_addr,
    output wire [31:0] fp_spad_wdata,

    output wire        scalar_busy,
    output wire        fp_busy,
    output wire        banked_busy,
    output wire        matrix_busy,
    output wire        sfu_busy,
    output wire        conv_busy,
    output wire        kv_busy,

    output wire        core_busy,
    output wire        core_done,
    output wire        core_error,
    output wire [3:0]  core_error_code,
    output wire [31:0] core_result,
    output wire [31:0] core_cycle_count,
    output wire [31:0] core_element_count,
    output wire [6:0]  engine_busy,
    output wire [6:0]  engine_done,
    output wire [6:0]  engine_error,
    output wire [27:0] engine_error_code,
    output wire [223:0] engine_result,
    output wire [223:0] engine_cycle_count,
    output wire [223:0] engine_element_count,
    output wire        matrix_perf_mac_active,
    output wire        matrix_perf_banked_wait
);

    wire        scalar_done, scalar_error;
    wire [3:0]  scalar_error_code;
    wire [31:0] scalar_result, scalar_cycle_count, scalar_element_count;
    wire        fp_done, fp_error;
    wire [3:0]  fp_error_code;
    wire [31:0] fp_result, fp_cycle_count, fp_element_count;
    wire        banked_done, banked_error;
    wire [3:0]  banked_error_code;
    wire [31:0] banked_result, banked_cycle_count, banked_element_count;
    wire        matrix_done, matrix_error;
    wire [3:0]  matrix_error_code;
    wire [31:0] matrix_result, matrix_cycle_count, matrix_element_count;
    wire        sfu_done, sfu_error;
    wire [3:0]  sfu_error_code;
    wire [31:0] sfu_result, sfu_cycle_count, sfu_element_count;
    wire        conv_done, conv_error;
    wire [3:0]  conv_error_code;
    wire [31:0] conv_result, conv_cycle_count, conv_element_count;
    wire        kv_done, kv_error;
    wire [3:0]  kv_error_code;
    wire [31:0] kv_result, kv_cycle_count, kv_element_count;

    assign core_busy = scalar_busy || fp_busy || banked_busy || matrix_busy || sfu_busy || conv_busy || kv_busy;
    assign core_done = scalar_done || fp_done || banked_done || matrix_done || sfu_done || conv_done || kv_done;
    assign core_error = fp_done ? fp_error : conv_done ? conv_error : kv_done ? kv_error : matrix_done ? matrix_error :
                        sfu_done ? sfu_error :
                        banked_done ? banked_error : scalar_error;
    assign core_error_code = fp_done ? fp_error_code : conv_done ? conv_error_code : kv_done ? kv_error_code : matrix_done ? matrix_error_code :
                             sfu_done ? sfu_error_code :
                             banked_done ? banked_error_code : scalar_error_code;
    assign core_result = fp_done ? fp_result : conv_done ? conv_result : kv_done ? kv_result : matrix_done ? matrix_result :
                         sfu_done ? sfu_result :
                         banked_done ? banked_result : scalar_result;
    assign core_cycle_count = fp_done ? fp_cycle_count : conv_done ? conv_cycle_count : kv_done ? kv_cycle_count : matrix_done ? matrix_cycle_count :
                              sfu_done ? sfu_cycle_count :
                              banked_done ? banked_cycle_count : scalar_cycle_count;
    assign core_element_count = fp_done ? fp_element_count : conv_done ? conv_element_count : kv_done ? kv_element_count : matrix_done ? matrix_element_count :
                                sfu_done ? sfu_element_count :
                                banked_done ? banked_element_count : scalar_element_count;

    // Packed status vectors form the per-engine completion interface used by
    // the parallel command dispatcher. Bit 0 is scalar INT8; bit 6 is KV.
    assign engine_busy = {kv_busy, conv_busy, sfu_busy, matrix_busy,
                          banked_busy, fp_busy, scalar_busy};
    assign engine_done = {kv_done, conv_done, sfu_done, matrix_done,
                          banked_done, fp_done, scalar_done};
    assign engine_error = {kv_error, conv_error, sfu_error, matrix_error,
                           banked_error, fp_error, scalar_error};
    assign engine_error_code = {kv_error_code, conv_error_code, sfu_error_code,
                                matrix_error_code, banked_error_code,
                                fp_error_code, scalar_error_code};
    assign engine_result = {kv_result, conv_result, sfu_result, matrix_result,
                            banked_result, fp_result, scalar_result};
    assign engine_cycle_count = {kv_cycle_count, conv_cycle_count,
                                 sfu_cycle_count, matrix_cycle_count,
                                 banked_cycle_count, fp_cycle_count,
                                 scalar_cycle_count};
    assign engine_element_count = {kv_element_count, conv_element_count,
                                   sfu_element_count, matrix_element_count,
                                   banked_element_count, fp_element_count,
                                   scalar_element_count};

    ai_banked_cnm_core banked_core_u(
        .clk(aclk), .resetn(aresetn), .start(core_start && banked_op), .abort(core_abort), .op_mode(launch_op),
        .src0_base(launch_src0), .src1_base(launch_src1), .dst_base(launch_dst),
        .length(launch_length), .m_size(launch_m), .scale_shift(launch_shift), .activation(launch_activation),
        .watchdog_limit(watchdog_limit),
        .cnm_req_valid(cnm_read_valid), .cnm_addr0(cnm_read_addr0), .cnm_addr1(cnm_read_addr1),
        .cnm_addr2(cnm_read_addr2), .cnm_addr3(cnm_read_addr3), .cnm_req_ready(arb_cnm_ready),
        .cnm_rsp_valid(cnm_rsp_valid), .cnm_data0(cnm_data0), .cnm_data1(cnm_data1),
        .cnm_data2(cnm_data2), .cnm_data3(cnm_data3), .cnm_parity_error(cnm_parity),
        .cnm_protection_error(cnm_protection_error),
        .spad_valid(banked_spad_valid), .spad_write(banked_spad_write), .spad_addr(banked_spad_addr), .spad_wdata(banked_spad_wdata),
        .spad_ready(engine_core_ready[2]),
        .spad_protection_error(engine_core_protection_error[2]),
        .busy(banked_busy), .done(banked_done), .error(banked_error), .error_code(banked_error_code),
        .result(banked_result), .cycle_count(banked_cycle_count), .element_count(banked_element_count),
        // Optional CNM benchmark counters are not part of the top-level ABI.
        .local_accumulate_events(), .global_reduce_events(),
        .banked_read_issue_events(), .prefetch_events(),
        .pipeline_compute_events(), .response_wait_cycles()
    );

    ai_tensor_matrix_core tensor_matrix_u(
        .clk(aclk), .resetn(aresetn),
        .start(core_start && tensor_matrix_op), .abort(core_abort), .op_mode(launch_op),
        .src0_base(launch_src0), .src1_base(launch_src1),
        .bias_base(launch_bias_base), .dst_base(launch_dst),
        .m_size(launch_m), .n_size(launch_n), .k_words(launch_k),
        .instance_count(launch_instance_count),
        .src0_batch_stride(launch_src0_stride), .src1_batch_stride(launch_src1_stride),
        .dst_batch_stride(launch_dst_stride),
        .transpose_a(launch_flags[1]), .transpose_b(launch_flags[2]),
        .bias_enable(launch_bias_enable), .scale_shift(launch_shift),
        .activation(launch_activation), .watchdog_limit(watchdog_limit),
        .bank0_data(banked_data0), .bank1_data(banked_data1),
        .bank2_data(banked_data2), .bank3_data(banked_data3),
        .bank_parity_error(banked_parity),
        .banked_read_valid(matrix_banked_read_valid), .banked_addr(matrix_banked_read_addr),
        .banked_ready(arb_banked_ready), .banked_rsp_valid(banked_rsp_valid),
        .banked_protection_error(banked_protection_error),
        .spad_valid(matrix_spad_valid), .spad_write(matrix_spad_write),
        .spad_addr(matrix_spad_addr), .spad_wdata(matrix_spad_wdata),
        .spad_ready(engine_core_ready[3]), .spad_rsp_valid(engine_core_rsp_valid[3]),
        .spad_rdata(engine_core_rsp_rdata[3*32 +: 32]),
        .spad_parity_error(engine_core_rsp_error[3]),
        .spad_protection_error(engine_core_protection_error[3]),
        .line_valid(matrix_line_valid), .line_write(matrix_line_write),
        .line_addr(matrix_line_addr), .line_wdata(matrix_line_wdata),
        .line_wstrb(matrix_line_wstrb), .line_ready(arb_core_line_ready),
        .line_protection_error(line_prot_error || spad_line_raw_error),
        .busy(matrix_busy), .done(matrix_done), .error(matrix_error),
        .error_code(matrix_error_code), .result(matrix_result),
        .cycle_count(matrix_cycle_count), .element_count(matrix_element_count),
        .perf_mac_active(matrix_perf_mac_active),
        .perf_banked_wait(matrix_perf_banked_wait)
    );

    ai_tensor_sfu_core tensor_sfu_u(
        .clk(aclk), .resetn(aresetn),
        .start(core_start && tensor_sfu_op), .abort(core_abort), .op_mode(launch_op),
        .src0_base(launch_src0), .src1_base(launch_src1),
        .beta_base(launch_bias_base), .beta_enable(launch_bias_enable),
        .pack_enable(launch_flags[4]), .dst_base(launch_dst),
        .length(launch_length), .scale_shift(launch_shift),
        .epsilon(launch_aux0), .watchdog_limit(watchdog_limit),
        .spad_valid(sfu_spad_valid), .spad_write(sfu_spad_write),
        .spad_addr(sfu_spad_addr), .spad_wdata(sfu_spad_wdata),
        .spad_ready(engine_core_ready[4]), .spad_rsp_valid(engine_core_rsp_valid[4]),
        .spad_rdata(engine_core_rsp_rdata[4*32 +: 32]),
        .spad_parity_error(engine_core_rsp_error[4]),
        .spad_protection_error(engine_core_protection_error[4]),
        .busy(sfu_busy), .done(sfu_done), .error(sfu_error),
        .error_code(sfu_error_code), .result(sfu_result),
        .cycle_count(sfu_cycle_count), .element_count(sfu_element_count)
    );

    ai_conv3x3_linebuffer_core conv_linebuffer_u(
        .clk(aclk), .resetn(aresetn), .start(core_start && conv_linebuffer_op),
        .abort(core_abort), .op_mode(launch_op), .src0_base(launch_src0),
        .src1_base(launch_src1), .dst_base(launch_dst), .height(launch_m),
        .width(launch_n), .watchdog_limit(watchdog_limit),
        .spad_valid(conv_spad_valid), .spad_write(conv_spad_write),
        .spad_addr(conv_spad_addr), .spad_wdata(conv_spad_wdata),
        .spad_ready(engine_core_ready[5]), .spad_rsp_valid(engine_core_rsp_valid[5]),
        .spad_rdata(engine_core_rsp_rdata[5*32 +: 32]),
        .spad_error(engine_core_rsp_error[5] || engine_core_protection_error[5]),
        .busy(conv_busy), .done(conv_done), .error(conv_error), .error_code(conv_error_code),
        .result(conv_result), .cycle_count(conv_cycle_count), .element_count(conv_element_count)
    );

    ai_kv_cache_engine kv_cache_u(
        .clk(aclk), .resetn(aresetn), .start(core_start && kv_cache_op),
        .abort(core_abort), .op_mode(launch_op), .src0_base(launch_src0),
        .dst_base(launch_dst), .length(launch_length),
        .src0_stride(launch_src0_stride), .src1_stride(launch_src1_stride),
        .aux0(launch_aux0), .watchdog_limit(watchdog_limit),
        .spad_valid(kv_spad_valid), .spad_write(kv_spad_write),
        .spad_addr(kv_spad_addr), .spad_wdata(kv_spad_wdata),
        .spad_ready(engine_core_ready[6]), .spad_rsp_valid(engine_core_rsp_valid[6]),
        .spad_rdata(engine_core_rsp_rdata[6*32 +: 32]),
        .spad_error(engine_core_rsp_error[6] || engine_core_protection_error[6]),
        .busy(kv_busy), .done(kv_done), .error(kv_error), .error_code(kv_error_code),
        .result(kv_result), .cycle_count(kv_cycle_count), .element_count(kv_element_count)
    );

    // First mixed-precision product engine.  It shares the scheduler-side
    // 32-bit core SPAD port and never bypasses ai_spad_arbiter.
    ai_mixed_precision_dot_fp32_core mixed_precision_dot_core_u(
        .clk(aclk), .resetn(aresetn),
        .start(core_start && ((launch_op == 8'h50) ||
                              (launch_op == 8'h51))),
        .format_fp16(launch_op == 8'h51), .abort(core_abort),
        .src0_base(launch_src0), .src1_base(launch_src1), .dst_base(launch_dst),
        .length(launch_length), .watchdog_limit(watchdog_limit),
        .spad_valid(fp_spad_valid), .spad_write(fp_spad_write),
        .spad_addr(fp_spad_addr), .spad_wdata(fp_spad_wdata),
        .spad_ready(engine_core_ready[1]), .spad_rsp_valid(engine_core_rsp_valid[1]),
        .spad_rdata(engine_core_rsp_rdata[1*32 +: 32]),
        .spad_parity_error(engine_core_rsp_error[1]),
        .spad_protection_error(engine_core_protection_error[1]),
        .busy(fp_busy), .done(fp_done), .error(fp_error),
        .error_code(fp_error_code), .result(fp_result),
        .cycle_count(fp_cycle_count), .element_count(fp_element_count)
    );

    ai_int8_compute_core core_u(
        .clk                (aclk),
        .resetn             (aresetn),
        .start              (core_start && !banked_op && !tensor_matrix_op && !tensor_sfu_op && !conv_linebuffer_op && !kv_cache_op && (launch_op != 8'h50) && (launch_op != 8'h51)),
        .abort              (core_abort),
        .op_mode            (launch_op),
        .src0_base          (launch_src0),
        .src1_base          (launch_src1),
        .dst_base           (launch_dst),
        .length             (launch_length),
        .m_size             (launch_m),
        .n_size             (launch_n),
        .k_words            (launch_k),
        .scale_shift        (launch_shift),
        .activation         (launch_activation),
        .bias_base          (launch_bias_base),
        .bias_enable        (launch_bias_enable),
        .watchdog_limit     (watchdog_limit),
        .spad_ready         (engine_core_ready[0]),
        .spad_rsp_valid     (engine_core_rsp_valid[0]),
        .spad_parity_error  (engine_core_rsp_error[0]),
        .spad_protection_error(engine_core_protection_error[0]),
        .spad_rdata         (engine_core_rsp_rdata[0*32 +: 32]),
        .spad_valid         (scalar_spad_valid),
        .spad_write         (scalar_spad_write),
        .spad_addr          (scalar_spad_addr),
        .spad_wdata         (scalar_spad_wdata),
        .busy               (scalar_busy),
        .done               (scalar_done),
        .error              (scalar_error),
        .error_code         (scalar_error_code),
        .result             (scalar_result),
        .cycle_count        (scalar_cycle_count),
        .element_count      (scalar_element_count)
    );

endmodule
