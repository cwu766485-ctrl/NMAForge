`timescale 1ns / 1ps

// ============================================================================
// ai_int8_compute_core
// ----------------------------------------------------------------------------
// INT8 计算核心。它不直接访问 DDR，只通过 spad_* 接口访问片上 scratchpad。
//
// 支持的计算：
//   OP_VDOT_INT8      : 两个向量点积，输出 1 个 int32 result。
//   OP_GEMV_INT8      : 矩阵向量乘，每一行输出 1 个 int32 result。
//   OP_GEMM_INT8_TILE : 小 tile 矩阵乘，输出 M*N 个 int32 result。
//
// 数据格式：
//   scratchpad 中每个 32-bit word 存 4 个 signed int8 lane。
//   每个计算周期读取 A/B 各 1 个 word，执行 dot4：
//       a0*b0 + a1*b1 + a2*b2 + a3*b3
//   多个 dot4 结果累加到 64-bit acc_r，最终经过 shift/activation/saturate 后写回
//   32-bit output word。
//
// 状态机主线：
//   IDLE -> READ_A -> READ_B -> CALC -> WRITE -> NEXT -> DONE
//   出错/abort/watchdog/parity 时进入 ERROR。
// ============================================================================
module ai_int8_compute_core(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        abort,
    input  wire [7:0]  op_mode,
    input  wire [31:0] src0_base,
    input  wire [31:0] src1_base,
    input  wire [31:0] dst_base,
    input  wire [15:0] length,
    input  wire [15:0] m_size,
    input  wire [15:0] n_size,
    input  wire [15:0] k_words,
    input  wire [4:0]  scale_shift,
    input  wire [1:0]  activation,
    input  wire [31:0] bias_base,
    input  wire        bias_enable,
    input  wire [31:0] watchdog_limit,
    input  wire        spad_ready,
    input  wire        spad_rsp_valid,
    input  wire        spad_parity_error,
    input  wire        spad_protection_error,
    input  wire [31:0] spad_rdata,
    output reg         spad_valid,
    output reg         spad_write,
    output reg  [31:0] spad_addr,
    output reg  [31:0] spad_wdata,
    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [3:0]  error_code,
    output reg  [31:0] result,
    output reg  [31:0] cycle_count,
    output reg  [31:0] element_count
);

    // op 编码要和 ai_accel_regs/descriptor 定义保持一致。
    // This core performs one packed INT8 dot4 per accumulator iteration.
    // Registered scratchpad timing is explicit in the READ_* / READ_*_WAIT
    // state pairs; do not collapse those pairs during refactoring.
    localparam [7:0] OP_VDOT_INT8      = 8'h10;
    localparam [7:0] OP_GEMV_INT8      = 8'h11;
    localparam [7:0] OP_GEMM_INT8_TILE = 8'h12;
    localparam [7:0] OP_CONV1X1_INT8   = 8'h13;
    localparam [7:0] OP_CONV3X3_INT8   = 8'h14;
    localparam [7:0] OP_DWCONV3X3_INT8 = 8'h15;

    localparam [3:0] ERR_NONE      = 4'd0;
    localparam [3:0] ERR_CONFIG    = 4'd1;
    localparam [3:0] ERR_OP        = 4'd2;
    localparam [3:0] ERR_ABORT     = 4'd3;
    localparam [3:0] ERR_WATCHDOG  = 4'd4;
    localparam [3:0] ERR_PARITY    = 4'd5;
    localparam [3:0] ERR_PROTECTION = 4'd6;

    localparam [3:0] ST_IDLE           = 4'd0;
    localparam [3:0] ST_READ_A         = 4'd1;
    localparam [3:0] ST_READ_B         = 4'd2;
    localparam [3:0] ST_CALC           = 4'd3;
    localparam [3:0] ST_WRITE          = 4'd4;
    localparam [3:0] ST_NEXT           = 4'd5;
    localparam [3:0] ST_DONE           = 4'd6;
    localparam [3:0] ST_ERROR          = 4'd7;
    localparam [3:0] ST_READ_A_WAIT    = 4'd8;
    localparam [3:0] ST_READ_B_WAIT    = 4'd9;
    localparam [3:0] ST_READ_BIAS      = 4'd10;
    localparam [3:0] ST_READ_BIAS_WAIT = 4'd11;

    localparam [1:0] ACT_RELU  = 2'd1;
    localparam [1:0] ACT_RELU6 = 2'd2;

    // 启动时把外部配置锁存到 *_r。这样任务执行期间即使软件改寄存器，
    // 当前任务也不会被中途影响，同时降低配置总线扇出。
    reg [3:0]  state_r;
    reg [7:0]  op_r;
    reg [31:0] src1_base_r;
    reg [15:0] length_r;
    reg [15:0] m_size_r;
    reg [15:0] n_size_r;
    reg [15:0] k_words_r;
    reg [4:0]  scale_shift_r;
    reg [1:0]  activation_r;
    reg [31:0] bias_base_r;
    reg        bias_enable_r;
    reg [31:0] watchdog_limit_r;
    // Incremental address generators.  Keeping the current output's A/B,
    // bias and destination bases in registers removes row/column/K
    // multipliers from the scratchpad request path.
    reg [31:0] a_output_base_r;
    reg [31:0] b_output_base_r;
    reg [31:0] output_addr_r;
    reg [31:0] bias_addr_r;
    reg [15:0] row_r;
    reg [15:0] col_r;
    reg [15:0] k_r;
    reg [31:0] a_word_r;
    reg [31:0] b_word_r;
    reg signed [63:0] acc_r;
    reg [31:0] output_word_r;
    reg [3:0]  start_error_code;
    reg        read_protection_error_r;

    wire [31:0] a_addr;
    wire [31:0] b_addr;
    wire [31:0] out_addr;
    wire [31:0] bias_addr;
    wire signed [63:0] acc_sum;
    wire [31:0] quantized_result;
    wire valid_op;
    wire valid_dims;
    wire input_alignment_error;
    wire use_length_as_k;
    wire last_k;
    wire last_output;
    wire matrix_mode;
    wire depthwise_mode;
    wire [31:0] k_byte_offset;
    wire [31:0] k_vector_bytes;
    wire read_response_error;
    wire watchdog_expired;

    // 地址生成：
    //   VDOT: A/B 都按 k 线性递增；
    //   GEMV: A 是输入向量，B 是第 row 行权重；
    //   GEMM: A 按 row 取，B 按 col 取，输出为 row/col 二维展开地址。
    assign use_length_as_k = (op_r == OP_VDOT_INT8);
    assign matrix_mode = (op_r == OP_GEMM_INT8_TILE) ||
                         (op_r == OP_CONV1X1_INT8) ||
                         (op_r == OP_CONV3X3_INT8) ||
                         (op_r == OP_DWCONV3X3_INT8);
    assign depthwise_mode = (op_r == OP_DWCONV3X3_INT8);
    // CONV3X3 consumes an im2col patch matrix.  DWCONV3X3 stores one packed
    // K-vector per {output-pixel, channel}.  The per-output bases advance in
    // ST_NEXT; only the current K word's byte offset is added here.
    assign k_byte_offset = {14'd0, k_r, 2'b00};
    assign k_vector_bytes = {14'd0, k_words_r, 2'b00};
    assign a_addr = a_output_base_r + k_byte_offset;
    assign b_addr = b_output_base_r + k_byte_offset;
    assign out_addr = output_addr_r;
    assign bias_addr = bias_addr_r;
    // packed INT8 dot4 datapath：每个 word 有 4 个 int8 lane。
    ai_int8_datapath int8_datapath_u(
        .a_word(a_word_r), .b_word(b_word_r), .accumulator(acc_r),
        .scale_shift(scale_shift_r), .activation(activation_r),
        .accumulator_sum(acc_sum),
        .quantized_result(quantized_result)
    );
    // 后处理：先算术右移做简化量化，再可选 ReLU，再饱和到 signed int32。
    assign valid_op = (op_mode == OP_VDOT_INT8) ||
                      (op_mode == OP_GEMV_INT8) ||
                      (op_mode == OP_GEMM_INT8_TILE) ||
                      (op_mode == OP_CONV1X1_INT8) ||
                      (op_mode == OP_CONV3X3_INT8) ||
                      (op_mode == OP_DWCONV3X3_INT8);
    assign valid_dims = ((op_mode == OP_VDOT_INT8) && (length != 16'd0)) ||
                        ((op_mode == OP_GEMV_INT8) && (m_size != 16'd0) && (k_words != 16'd0)) ||
                        (((op_mode == OP_GEMM_INT8_TILE) || (op_mode == OP_CONV1X1_INT8) ||
                          (op_mode == OP_CONV3X3_INT8) || (op_mode == OP_DWCONV3X3_INT8)) && (m_size != 16'd0) &&
                         (n_size != 16'd0) && (k_words != 16'd0));
    assign input_alignment_error = (src0_base[1:0] != 2'b00) ||
                                   (src1_base[1:0] != 2'b00) ||
                                   (dst_base[1:0] != 2'b00) ||
                                   (bias_enable && (bias_base[1:0] != 2'b00));
    assign last_k = use_length_as_k ? (k_r == (length_r - 16'd1)) :
                                     (k_r == (k_words_r - 16'd1));
    assign last_output = (op_r == OP_VDOT_INT8) ? 1'b1 :
                         ((op_r == OP_GEMV_INT8) ? (row_r == (m_size_r - 16'd1)) :
                          ((row_r == (m_size_r - 16'd1)) && (col_r == (n_size_r - 16'd1))));
    assign read_response_error = spad_parity_error || read_protection_error_r;
    assign watchdog_expired = busy && (watchdog_limit_r != 32'd0) &&
                              (cycle_count >= watchdog_limit_r);

    // 4-lane INT8 乘加函数。综合后对应 4 个 8x8 signed multiplier
    // 加一个小加法树。为了防止溢出，输出扩展到 signed 32-bit。
    // Packed little-endian INT8 dot product: byte lane i is multiplied only
    // by the corresponding byte lane i.  The 32-bit result prevents a
    // four-product overflow before it is accumulated into acc_r.
    /* function signed [31:0] dot4_i8;
        input [31:0] a;
        input [31:0] b;
        reg signed [7:0] a0;
        reg signed [7:0] a1;
        reg signed [7:0] a2;
        reg signed [7:0] a3;
        reg signed [7:0] b0;
        reg signed [7:0] b1;
        reg signed [7:0] b2;
        reg signed [7:0] b3;
        reg signed [31:0] p0;
        reg signed [31:0] p1;
        reg signed [31:0] p2;
        reg signed [31:0] p3;
        begin
            a0 = a[7:0];
            a1 = a[15:8];
            a2 = a[23:16];
            a3 = a[31:24];
            b0 = b[7:0];
            b1 = b[15:8];
            b2 = b[23:16];
            b3 = b[31:24];
            p0 = a0 * b0;
            p1 = a1 * b1;
            p2 = a2 * b2;
            p3 = a3 * b3;
            dot4_i8 = p0 + p1 + p2 + p3;
        end
    endfunction */

    // 启动前配置检查。非法 op、尺寸为 0、地址非 32-bit 对齐都会直接进入 ERROR，
    // 避免错误请求继续访问 scratchpad。
    // Validate a command before issuing any scratchpad transaction.
    always @(*) begin
        start_error_code = ERR_NONE;
        if (!valid_op)
            start_error_code = ERR_OP;
        else if (!valid_dims)
            start_error_code = ERR_CONFIG;
        else if (input_alignment_error)
            start_error_code = ERR_CONFIG;
    end

    // scratchpad 请求组合逻辑。
    // 综合后是一个由 state_r 控制的 mux：
    //   READ_A  -> 读 A 地址；
    //   READ_B  -> 读 B 地址；
    //   WRITE   -> 写输出地址；
    //   其他状态不访问 scratchpad。
    // The registered scratchpad interface is driven only for a request or a
    // write state; wait states deliberately issue no second transaction.
    always @(*) begin
        spad_valid = 1'b0;
        spad_write = 1'b0;
        spad_addr  = 32'd0;
        spad_wdata = 32'd0;

        case (state_r)
            ST_READ_BIAS: begin
                spad_valid = 1'b1;
                spad_addr  = bias_addr;
            end
            ST_READ_A: begin
                spad_valid = 1'b1;
                spad_addr  = a_addr;
            end
            ST_READ_B: begin
                spad_valid = 1'b1;
                spad_addr  = b_addr;
            end
            ST_WRITE: begin
                spad_valid = 1'b1;
                spad_write = 1'b1;
                spad_addr  = out_addr;
                spad_wdata = output_word_r;
            end
            default: begin
            end
        endcase
    end

    // 主状态机。
    // 每个输出元素都经历：读 A word -> 读 B word -> dot4+累加 -> 最后一个 k 后写结果。
    // VDOT 输出 1 个元素；GEMV 输出 M 个元素；GEMM_TILE 输出 M*N 个元素。
    // Per-output execution: optional bias, A read, B read, dot4/accumulate,
    // result write, then row/column advancement.  `done` remains a pulse.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r          <= ST_IDLE;
            op_r             <= OP_VDOT_INT8;
            src1_base_r      <= 32'd0;
            length_r         <= 16'd0;
            m_size_r         <= 16'd0;
            n_size_r         <= 16'd0;
            k_words_r        <= 16'd0;
            scale_shift_r    <= 5'd0;
            activation_r     <= 2'd0;
            bias_base_r      <= 32'd0;
            bias_enable_r    <= 1'b0;
            watchdog_limit_r <= 32'd0;
            a_output_base_r  <= 32'd0;
            b_output_base_r  <= 32'd0;
            output_addr_r    <= 32'd0;
            bias_addr_r      <= 32'd0;
            row_r            <= 16'd0;
            col_r            <= 16'd0;
            k_r              <= 16'd0;
            a_word_r         <= 32'd0;
            b_word_r         <= 32'd0;
            acc_r            <= 64'sd0;
            output_word_r    <= 32'd0;
            read_protection_error_r <= 1'b0;
            busy             <= 1'b0;
            done             <= 1'b0;
            error            <= 1'b0;
            error_code       <= ERR_NONE;
            result           <= 32'd0;
            cycle_count      <= 32'd0;
            element_count    <= 32'd0;
        end else begin
            done <= 1'b0;

            if (state_r==ST_IDLE && start)
                cycle_count <= 32'd0;
            else if (busy)
                cycle_count <= cycle_count + 32'd1;

            if (busy && abort) begin
                error_code <= ERR_ABORT;
                state_r    <= ST_ERROR;
            end else if (watchdog_expired) begin
                error_code <= ERR_WATCHDOG;
                state_r    <= ST_ERROR;
            end else begin
                case (state_r)
                    ST_IDLE: begin
                        // 空闲态等待 start。start 到来后锁存配置，并根据 start_error_code
                        // 决定进入计算流程还是直接报错。
                        busy  <= 1'b0;
                        error <= 1'b0;
                        if (start) begin
                            op_r             <= op_mode;
                            src1_base_r      <= src1_base;
                            length_r         <= length;
                            m_size_r         <= m_size;
                            n_size_r         <= n_size;
                            k_words_r        <= k_words;
                            scale_shift_r    <= scale_shift;
                            activation_r     <= activation;
                            bias_base_r      <= bias_base;
                            bias_enable_r    <= bias_enable;
                            watchdog_limit_r <= watchdog_limit;
                            a_output_base_r  <= src0_base;
                            b_output_base_r  <= src1_base;
                            output_addr_r    <= dst_base;
                            bias_addr_r      <= bias_base;
                            row_r            <= 16'd0;
                            col_r            <= 16'd0;
                            k_r              <= 16'd0;
                            acc_r            <= 64'sd0;
                            element_count    <= 32'd0;
                            error_code       <= start_error_code;
                            busy             <= 1'b1;
                            if (start_error_code != ERR_NONE)
                                state_r <= ST_ERROR;
                            else if (bias_enable)
                                state_r <= ST_READ_BIAS;
                            else
                                state_r <= ST_READ_A;
                        end
                    end
                    ST_READ_BIAS: if (spad_ready) begin
                        read_protection_error_r <= spad_protection_error;
                        state_r <= ST_READ_BIAS_WAIT;
                    end
                    ST_READ_BIAS_WAIT: if (spad_rsp_valid) begin
                        if (read_response_error) begin
                            error_code <= read_protection_error_r ? ERR_PROTECTION : ERR_PARITY;
                            state_r <= ST_ERROR;
                        end else begin
                            acc_r <= {{32{spad_rdata[31]}}, spad_rdata};
                            state_r <= ST_READ_A;
                        end
                    end
                    ST_READ_A: if (spad_ready) begin
                        read_protection_error_r <= spad_protection_error;
                        state_r <= ST_READ_A_WAIT;
                    end
                    ST_READ_A_WAIT: if (spad_rsp_valid) begin
                        a_word_r <= spad_rdata;
                        if (read_response_error) begin
                            error_code <= read_protection_error_r ? ERR_PROTECTION : ERR_PARITY;
                            state_r    <= ST_ERROR;
                        end else begin
                            state_r <= ST_READ_B;
                        end
                    end
                    ST_READ_B: if (spad_ready) begin
                        read_protection_error_r <= spad_protection_error;
                        state_r <= ST_READ_B_WAIT;
                    end
                    ST_READ_B_WAIT: if (spad_rsp_valid) begin
                        b_word_r <= spad_rdata;
                        if (read_response_error) begin
                            error_code <= read_protection_error_r ? ERR_PROTECTION : ERR_PARITY;
                            state_r    <= ST_ERROR;
                        end else begin
                            state_r <= ST_CALC;
                        end
                    end
                    ST_CALC: begin
                        // 计算一个 packed word 的 dot4，并加到 accumulator。
                        // 如果已经是最后一个 k，则做量化/激活/饱和并准备写回；
                        // 否则 k++，继续读取下一组 A/B word。
                        if (last_k) begin
                            output_word_r <= quantized_result;
                            result <= quantized_result;
                            state_r <= ST_WRITE;
                        end else begin
                            acc_r <= acc_sum;
                            k_r   <= k_r + 16'd1;
                            state_r <= ST_READ_A;
                        end
                    end
                    ST_WRITE: if (spad_ready) begin
                        // WRITE 状态组合逻辑会对 scratchpad 发写请求，这里只统计已写输出个数。
                        if (spad_protection_error) begin
                            error_code <= ERR_PROTECTION;
                            state_r <= ST_ERROR;
                        end else begin
                            element_count <= element_count + 32'd1;
                            state_r <= ST_NEXT;
                        end
                    end
                    ST_NEXT: begin
                        // 判断整个任务是否完成；否则推进 row/col，清 accumulator，
                        // 开始计算下一个输出元素。
                        if (last_output) begin
                            state_r <= ST_DONE;
                        end else begin
                            acc_r      <= 64'sd0;
                            k_r        <= 16'd0;
                            if (matrix_mode) begin
                                if (col_r == (n_size_r - 16'd1)) begin
                                    col_r <= 16'd0;
                                    row_r <= row_r + 16'd1;
                                    b_output_base_r <= src1_base_r;
                                    bias_addr_r <= bias_base_r;
                                    if (depthwise_mode)
                                        a_output_base_r <= a_output_base_r + k_vector_bytes;
                                    else
                                        a_output_base_r <= a_output_base_r + k_vector_bytes;
                                end else begin
                                    col_r <= col_r + 16'd1;
                                    b_output_base_r <= b_output_base_r + k_vector_bytes;
                                    bias_addr_r <= bias_addr_r + 32'd4;
                                    if (depthwise_mode)
                                        a_output_base_r <= a_output_base_r + k_vector_bytes;
                                end
                            end else begin
                                row_r <= row_r + 16'd1;
                                if (op_r == OP_GEMV_INT8) begin
                                    b_output_base_r <= b_output_base_r + k_vector_bytes;
                                    bias_addr_r <= bias_addr_r + 32'd4;
                                end
                            end
                            output_addr_r <= output_addr_r + 32'd4;
                            state_r <= bias_enable_r ? ST_READ_BIAS : ST_READ_A;
                        end
                    end
                    ST_DONE: begin
                        // done 只拉高 1 拍，由 ai_accel_regs 捕获成 sticky done/irq。
                        busy       <= 1'b0;
                        done       <= 1'b1;
                        error      <= 1'b0;
                        error_code <= ERR_NONE;
                        state_r    <= ST_IDLE;
                    end
                    ST_ERROR: begin
                        // 错误完成也会拉 done，让上层能够写 STATUS/error/completion。
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        error   <= 1'b1;
                        state_r <= ST_IDLE;
                    end
                    default: begin
                        state_r <= ST_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
