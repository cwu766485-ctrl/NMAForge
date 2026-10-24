`timescale 1ns / 1ps

// A4 sequential vector/SFU engine for Transformer primitives.
//
// Fixed-point contracts:
//   SOFTMAX input  : signed Q8.8 log2-domain scores in one 32-bit word each.
//   SOFTMAX output : unsigned Q0.15 probability in bits [15:0] of each word.
//   RMSNORM input  : signed integer/Q8.8 values; gamma is signed Q0.15.
//   RMSNORM output : same numeric scale as gamma-normalized input, int32.
//   GELU/SILU      : signed Q8.8 input/output using bounded piecewise models.
//   REQUANT        : arithmetic right shift and signed INT8 saturation.  The
//                    default output is sign-extended to one 32-bit word;
//                    descriptor flag[4] packs four INT8 outputs per word.
//
// Softmax is numerically stable (subtract max) and uses a piecewise-linear
// exp2 approximation.  Division and reciprocal-square-root are iterative so
// they do not create unbounded combinational timing paths.
module ai_tensor_sfu_core(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        abort,
    input  wire [7:0]  op_mode,
    input  wire [31:0] src0_base,
    input  wire [31:0] src1_base,
    input  wire [31:0] beta_base,
    input  wire        beta_enable,
    // Descriptor flag[4] turns REQUANT into a layout bridge: four saturated
    // INT8 results are packed into one word for a following matrix command.
    input  wire        pack_enable,
    input  wire [31:0] dst_base,
    input  wire [15:0] length,
    input  wire [4:0]  scale_shift,
    input  wire [31:0] epsilon,
    input  wire [31:0] watchdog_limit,

    output reg         spad_valid,
    output reg         spad_write,
    output reg  [31:0] spad_addr,
    output reg  [31:0] spad_wdata,
    input  wire        spad_ready,
    input  wire        spad_rsp_valid,
    input  wire [31:0] spad_rdata,
    input  wire        spad_parity_error,
    input  wire        spad_protection_error,

    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [3:0]  error_code,
    output reg  [31:0] result,
    output reg  [31:0] cycle_count,
    output reg  [31:0] element_count
);
    localparam [7:0] OP_SOFTMAX_Q15 = 8'h32;
    localparam [7:0] OP_RMSNORM_Q15 = 8'h33;
    localparam [7:0] OP_RESIDUAL_I32= 8'h34;
    localparam [7:0] OP_GELU_Q8_8   = 8'h35;
    localparam [7:0] OP_REQUANT_I8  = 8'h36;
    localparam [7:0] OP_SILU_Q8_8   = 8'h37;
    localparam [7:0] OP_LAYERNORM_Q15= 8'h38;
    // Decoder attention primitive. epsilon[15:0] carries the query token
    // index; score columns greater than that index are causally masked.
    localparam [7:0] OP_CAUSAL_SOFTMAX_Q15 = 8'h39;

    localparam [3:0] ERR_CONFIG     = 4'd1;
    localparam [3:0] ERR_OP         = 4'd2;
    localparam [3:0] ERR_ABORT      = 4'd3;
    localparam [3:0] ERR_WATCHDOG   = 4'd4;
    localparam [3:0] ERR_PARITY     = 4'd5;
    localparam [3:0] ERR_PROTECTION = 4'd6;
    localparam [3:0] ERR_NUMERIC    = 4'd11;

    // Each memory request state has an explicit response wait state.  The
    // divider and square-root start/wait pairs keep their iterative latency
    // outside the scratchpad request path.
    localparam [5:0] ST_IDLE               = 6'd0;
    localparam [5:0] ST_SM_MAX_REQ         = 6'd1;
    localparam [5:0] ST_SM_MAX_WAIT        = 6'd2;
    localparam [5:0] ST_SM_SUM_REQ         = 6'd3;
    localparam [5:0] ST_SM_SUM_WAIT        = 6'd4;
    localparam [5:0] ST_SM_OUT_REQ         = 6'd5;
    localparam [5:0] ST_SM_OUT_WAIT        = 6'd6;
    localparam [5:0] ST_SM_DIV_START       = 6'd7;
    localparam [5:0] ST_SM_DIV_WAIT        = 6'd8;
    localparam [5:0] ST_SM_WRITE           = 6'd9;
    localparam [5:0] ST_RMS_SUM_REQ        = 6'd10;
    localparam [5:0] ST_RMS_SUM_WAIT       = 6'd11;
    localparam [5:0] ST_RMS_MEAN_DIV_START = 6'd12;
    localparam [5:0] ST_RMS_MEAN_DIV_WAIT  = 6'd13;
    localparam [5:0] ST_RMS_SQRT_START     = 6'd14;
    localparam [5:0] ST_RMS_SQRT_WAIT      = 6'd15;
    localparam [5:0] ST_RMS_INV_START      = 6'd16;
    localparam [5:0] ST_RMS_INV_WAIT       = 6'd17;
    localparam [5:0] ST_RMS_X_REQ          = 6'd18;
    localparam [5:0] ST_RMS_X_WAIT         = 6'd19;
    localparam [5:0] ST_RMS_G_REQ          = 6'd20;
    localparam [5:0] ST_RMS_G_WAIT         = 6'd21;
    localparam [5:0] ST_RMS_WRITE          = 6'd22;
    localparam [5:0] ST_VEC_A_REQ          = 6'd23;
    localparam [5:0] ST_VEC_A_WAIT         = 6'd24;
    localparam [5:0] ST_VEC_B_REQ          = 6'd25;
    localparam [5:0] ST_VEC_B_WAIT         = 6'd26;
    localparam [5:0] ST_VEC_WRITE          = 6'd27;
    localparam [5:0] ST_DONE               = 6'd28;
    localparam [5:0] ST_ERROR              = 6'd29;
    localparam [5:0] ST_VEC_PREP           = 6'd30;
    localparam [5:0] ST_VEC_POST           = 6'd31;
    localparam [5:0] ST_LN_SUM_REQ         = 6'd32;
    localparam [5:0] ST_LN_SUM_WAIT        = 6'd33;
    localparam [5:0] ST_LN_MEAN_START      = 6'd34;
    localparam [5:0] ST_LN_MEAN_WAIT       = 6'd35;
    localparam [5:0] ST_LN_VAR_REQ         = 6'd36;
    localparam [5:0] ST_LN_VAR_WAIT        = 6'd37;
    localparam [5:0] ST_LN_VAR_ACC         = 6'd38;
    localparam [5:0] ST_LN_B_REQ           = 6'd39;
    localparam [5:0] ST_LN_B_WAIT          = 6'd40;

    reg [5:0] state_r;
    reg [7:0] op_r;
    reg [31:0] src0_r, src1_r, beta_base_r, dst_r, epsilon_r, watchdog_limit_r;
    reg [15:0] length_r, index_r;
    reg [4:0] scale_shift_r;
    reg signed [31:0] max_r, x_r, gamma_r, beta_r, mean_r;
    reg [31:0] exp_r, output_word_r;
    reg [63:0] sum_exp_r, sum_sq_r, mean_sq_r;
    reg signed [63:0] sum_x_r;
    reg signed [63:0] vector_product_r;
    reg [31:0] rms_root_r, inv_rms_r;
    reg rms_normalize_phase_r, beta_enable_r, pack_enable_r;
    reg [31:0] pack_word_r;

    reg div_start_r, sqrt_start_r;
    reg [63:0] div_dividend_r, div_divisor_r;
    wire div_busy, div_done, div_error;
    wire [63:0] div_quotient, div_remainder;
    wire sqrt_busy, sqrt_done;
    wire [31:0] sqrt_root;

    wire [31:0] src0_addr = src0_r + ({16'd0,index_r}<<2);
    wire [31:0] src1_addr = src1_r + ({16'd0,index_r}<<2);
    wire [31:0] beta_addr = beta_base_r + ({16'd0,index_r}<<2);
    wire packed_requant = (op_r == OP_REQUANT_I8) && pack_enable_r;
    wire [31:0] dst_addr = dst_r +
                           (packed_requant ?
                            ({18'd0,index_r[15:2]} << 2) :
                            ({16'd0,index_r} << 2));
    wire signed [31:0] spad_signed = spad_rdata;
    wire causal_masked = (op_r == OP_CAUSAL_SOFTMAX_Q15) &&
                         (index_r > epsilon_r[15:0]);
    wire valid_operation = (op_mode == OP_SOFTMAX_Q15) ||
                           (op_mode == OP_CAUSAL_SOFTMAX_Q15) ||
                           (op_mode == OP_RMSNORM_Q15) ||
                           (op_mode == OP_LAYERNORM_Q15) ||
                           (op_mode == OP_RESIDUAL_I32) ||
                           (op_mode == OP_GELU_Q8_8) ||
                           (op_mode == OP_REQUANT_I8) ||
                           (op_mode == OP_SILU_Q8_8);
    // Admission-time checks deliberately use live inputs; all execution-time
    // decisions below use the latched *_r command snapshot.
    wire input_alignment_error = (|src0_base[1:0]) || (|dst_base[1:0]) ||
                                 (((op_mode == OP_RESIDUAL_I32) ||
                                   (op_mode == OP_RMSNORM_Q15) ||
                                   (op_mode == OP_LAYERNORM_Q15)) &&
                                  (src1_base != 0) && (|src1_base[1:0])) ||
                                 ((op_mode == OP_LAYERNORM_Q15) && beta_enable &&
                                  (|beta_base[1:0]));
    wire last_element = (index_r == length_r - 1'b1);
    wire is_layernorm = (op_r == OP_LAYERNORM_Q15);
    wire is_normalization = (op_r == OP_RMSNORM_Q15) || is_layernorm;
    wire watchdog_expired = busy && (watchdog_limit_r != 0) &&
                              (cycle_count >= watchdog_limit_r);

    ai_unsigned_divider #(.WIDTH(64)) divider_u(
        .clk(clk), .resetn(resetn), .start(div_start_r),
        .dividend(div_dividend_r), .divisor(div_divisor_r),
        .busy(div_busy), .done(div_done), .error(div_error),
        .quotient(div_quotient), .remainder(div_remainder)
    );

    ai_integer_sqrt sqrt_u(
        .clk(clk), .resetn(resetn), .start(sqrt_start_r),
        .radicand(mean_sq_r+epsilon_r), .busy(sqrt_busy),
        .done(sqrt_done), .root(sqrt_root)
    );

    // All fixed-point arithmetic remains combinational.  The surrounding
    // FSM still samples these results at the original SPAD/divider boundaries.
    wire [31:0] softmax_exp_q15;
    wire [31:0] requant_spad;
    wire [31:0] residual_output;
    wire [31:0] gamma_scaled_output;
    wire [31:0] normalization_output;
    wire [31:0] gelu_output;
    wire [31:0] silu_output;
    wire [31:0] gelu_piecewise_output =
        (x_r <= -32'sd512) ? 32'd0 :
        (x_r >= 32'sd512) ? x_r : gelu_output;
    wire [31:0] silu_piecewise_output =
        (x_r <= -32'sd768) ? 32'd0 :
        (x_r >= 32'sd768) ? x_r : silu_output;

    ai_tensor_sfu_math math_u(
        .softmax_delta_q8_8(spad_signed - max_r),
        .requant_value(spad_signed), .requant_shift(scale_shift_r),
        .residual_x(x_r), .residual_y(gamma_r), .residual_shift(scale_shift_r),
        .gamma_x(x_r), .gamma(gamma_r), .norm_x(x_r),
        .norm_inv_rms(inv_rms_r), .norm_beta(beta_r),
        .norm_add_beta(is_layernorm), .gelu_product(vector_product_r),
        .silu_product(vector_product_r), .softmax_exp_q15(softmax_exp_q15),
        .requant_i8_value(requant_spad), .residual_value(residual_output),
        .gamma_scaled_value(gamma_scaled_output),
        .normalization_value(normalization_output),
        .gelu_q8_8_value(gelu_output), .silu_q8_8_value(silu_output)
    );

    always @(*) begin
        spad_valid=1'b0; spad_write=1'b0; spad_addr=0; spad_wdata=output_word_r;
        case (state_r)
            ST_SM_MAX_REQ,ST_SM_SUM_REQ,ST_SM_OUT_REQ,ST_RMS_SUM_REQ,
            ST_RMS_X_REQ,ST_VEC_A_REQ,ST_LN_SUM_REQ,ST_LN_VAR_REQ:
                begin spad_valid=1; spad_addr=src0_addr; end
            ST_RMS_G_REQ,ST_VEC_B_REQ: begin spad_valid=1; spad_addr=src1_addr; end
            ST_LN_B_REQ: begin spad_valid=1; spad_addr=beta_addr; end
            ST_SM_WRITE,ST_VEC_WRITE: begin
                spad_valid=1; spad_write=1; spad_addr=dst_addr; spad_wdata=output_word_r;
            end
            default: begin end
        endcase
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r<=ST_IDLE; op_r<=0; src0_r<=0; src1_r<=0; beta_base_r<=0; dst_r<=0;
            epsilon_r<=1; watchdog_limit_r<=0; length_r<=0; index_r<=0;
            scale_shift_r<=0; max_r<=32'sh8000_0000; x_r<=0; gamma_r<=0; beta_r<=0; mean_r<=0;
            exp_r<=0; output_word_r<=0; sum_exp_r<=0; sum_sq_r<=0;
            mean_sq_r<=0; vector_product_r<=0; rms_root_r<=0; inv_rms_r<=0;
            sum_x_r<=0; rms_normalize_phase_r<=0; beta_enable_r<=0;
            pack_enable_r<=0; pack_word_r<=0;
            div_start_r<=0; sqrt_start_r<=0; div_dividend_r<=0; div_divisor_r<=0;
            busy<=0; done<=0; error<=0; error_code<=0; result<=0;
            cycle_count<=0; element_count<=0;
        end else begin
            done<=0; div_start_r<=0; sqrt_start_r<=0;
            if (state_r==ST_IDLE && start) cycle_count<=0;
            else if (busy) cycle_count<=cycle_count+1'b1;

            if (state_r != ST_ERROR && busy && abort) begin error_code<=ERR_ABORT; state_r<=ST_ERROR; end
            else if (state_r != ST_ERROR && watchdog_expired) begin
                error_code<=ERR_WATCHDOG; state_r<=ST_ERROR;
            end else case (state_r)
                ST_IDLE: begin
                    busy<=0; error<=0; error_code<=0;
                    if (start) begin
                        op_r<=op_mode; src0_r<=src0_base; src1_r<=src1_base;
                        beta_base_r<=beta_base; beta_enable_r<=beta_enable;
                        pack_enable_r<=pack_enable; dst_r<=dst_base;
                        length_r<=length; scale_shift_r<=scale_shift;
                        // For causal Softmax this field is a zero-based query
                        // token index, so zero must remain a valid boundary.
                        // Other SFU operators retain the nonzero epsilon
                        // default used by their normalization arithmetic.
                        epsilon_r <= (op_mode == OP_CAUSAL_SOFTMAX_Q15) ? epsilon :
                                     (epsilon == 0 ? 32'd1 : epsilon);
                        watchdog_limit_r<=watchdog_limit; index_r<=0;
                        element_count<=0; busy<=1;
                        max_r<=32'sh8000_0000; sum_exp_r<=0; sum_sq_r<=0; sum_x_r<=0;
                        mean_r<=0; beta_r<=0; pack_word_r<=0;
                        rms_normalize_phase_r<=0;
                        if (length==0 || input_alignment_error) begin
                            error_code<=ERR_CONFIG; state_r<=ST_ERROR;
                        end else if (!valid_operation) begin
                            error_code<=ERR_OP; state_r<=ST_ERROR;
                        end else case (op_mode)
                            OP_SOFTMAX_Q15,OP_CAUSAL_SOFTMAX_Q15: state_r<=ST_SM_MAX_REQ;
                            OP_RMSNORM_Q15: state_r<=ST_RMS_SUM_REQ;
                            OP_LAYERNORM_Q15: state_r<=ST_LN_SUM_REQ;
                            OP_RESIDUAL_I32,OP_GELU_Q8_8,OP_REQUANT_I8,OP_SILU_Q8_8:
                                state_r<=ST_VEC_A_REQ;
                            default: begin error_code<=ERR_OP; state_r<=ST_ERROR; end
                        endcase
                    end
                end

                ST_SM_MAX_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_SM_MAX_WAIT;
                end
                ST_SM_MAX_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        if (!causal_masked && spad_signed>max_r) max_r<=spad_signed;
                        if (last_element) begin index_r<=0; sum_exp_r<=0; state_r<=ST_SM_SUM_REQ; end
                        else begin index_r<=index_r+1'b1; state_r<=ST_SM_MAX_REQ; end
                    end
                end
                ST_SM_SUM_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_SM_SUM_WAIT;
                end
                ST_SM_SUM_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        if (!causal_masked)
                            sum_exp_r <= sum_exp_r + softmax_exp_q15;
                        if (last_element) begin index_r<=0; state_r<=ST_SM_OUT_REQ; end
                        else begin index_r<=index_r+1'b1; state_r<=ST_SM_SUM_REQ; end
                    end
                end
                ST_SM_OUT_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_SM_OUT_WAIT;
                end
                ST_SM_OUT_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else if (causal_masked) begin output_word_r<=32'd0; state_r<=ST_SM_WRITE; end
                    else begin exp_r <= softmax_exp_q15; state_r <= ST_SM_DIV_START; end
                end
                ST_SM_DIV_START: begin
                    if (sum_exp_r==0) begin error_code<=ERR_NUMERIC; state_r<=ST_ERROR; end
                    else begin
                        div_dividend_r<={17'd0,exp_r,15'd0}; div_divisor_r<=sum_exp_r;
                        div_start_r<=1; state_r<=ST_SM_DIV_WAIT;
                    end
                end
                ST_SM_DIV_WAIT: if (div_done) begin
                    if (div_error) begin error_code<=ERR_NUMERIC; state_r<=ST_ERROR; end
                    else begin
                        output_word_r<=div_quotient>64'd32768 ? 32'd32768 : div_quotient[31:0];
                        state_r<=ST_SM_WRITE;
                    end
                end
                ST_SM_WRITE: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else begin
                        result<=output_word_r; element_count<=element_count+1'b1;
                        if (last_element) state_r<=ST_DONE;
                        else begin index_r<=index_r+1'b1; state_r<=ST_SM_OUT_REQ; end
                    end
                end

                ST_RMS_SUM_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_RMS_SUM_WAIT;
                end
                ST_RMS_SUM_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        x_r<=spad_signed;
                        state_r<=ST_RMS_WRITE;
                    end
                end
                ST_RMS_MEAN_DIV_START: begin
                    div_dividend_r<=sum_sq_r; div_divisor_r<={48'd0,length_r};
                    div_start_r<=1; state_r<=ST_RMS_MEAN_DIV_WAIT;
                end
                ST_RMS_MEAN_DIV_WAIT: if (div_done) begin
                    if (div_error) begin error_code<=ERR_NUMERIC; state_r<=ST_ERROR; end
                    else begin mean_sq_r<=div_quotient; state_r<=ST_RMS_SQRT_START; end
                end
                ST_RMS_SQRT_START: begin sqrt_start_r<=1; state_r<=ST_RMS_SQRT_WAIT; end
                ST_RMS_SQRT_WAIT: if (sqrt_done) begin
                    if (sqrt_root==0) begin error_code<=ERR_NUMERIC; state_r<=ST_ERROR; end
                    else begin rms_root_r<=sqrt_root; state_r<=ST_RMS_INV_START; end
                end
                ST_RMS_INV_START: begin
                    div_dividend_r<=64'h0000_0000_4000_0000;
                    div_divisor_r<={32'd0,rms_root_r}; div_start_r<=1; state_r<=ST_RMS_INV_WAIT;
                end
                ST_RMS_INV_WAIT: if (div_done) begin
                    if (div_error) begin error_code<=ERR_NUMERIC; state_r<=ST_ERROR; end
                    else begin
                        inv_rms_r<=div_quotient[31:0]; index_r<=0;
                        rms_normalize_phase_r<=1; state_r<=ST_RMS_X_REQ;
                    end
                end
                ST_RMS_X_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_RMS_X_WAIT;
                end
                ST_RMS_X_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        x_r<=is_layernorm ? spad_signed-mean_r : spad_signed;
                        if (src1_r==0) begin
                            gamma_r<=32'sd32768;
                            state_r<=(is_layernorm && beta_enable_r) ?
                                    ST_LN_B_REQ : ST_RMS_WRITE;
                        end
                        else state_r<=ST_RMS_G_REQ;
                    end
                end
                ST_RMS_G_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_RMS_G_WAIT;
                end
                ST_RMS_G_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        gamma_r<=spad_signed;
                        state_r<=(is_layernorm && beta_enable_r) ?
                                ST_LN_B_REQ : ST_RMS_WRITE;
                    end
                end
                ST_RMS_WRITE: begin
                    if (op_r==OP_RESIDUAL_I32) begin
                        output_word_r <= residual_output;
                        state_r<=ST_VEC_WRITE;
                    end else if (!rms_normalize_phase_r) begin
                        vector_product_r<=x_r*x_r;
                        state_r<=ST_VEC_POST;
                    end else begin
                        // Saturating the post-gamma intermediate to INT32 is
                        // both the A3 numeric contract and a clean pipeline
                        // cut before reciprocal scaling.
                        x_r <= gamma_scaled_output;
                        state_r<=ST_VEC_POST;
                    end
                end

                ST_VEC_A_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_VEC_A_WAIT;
                end
                ST_VEC_A_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        x_r<=spad_signed;
                        if (op_r==OP_RESIDUAL_I32) state_r<=ST_VEC_B_REQ;
                        else if (op_r==OP_REQUANT_I8) begin
                            if (!pack_enable_r) begin
                                output_word_r<=requant_spad;
                                state_r<=ST_VEC_WRITE;
                            end else begin
                                case (index_r[1:0])
                                  2'd0: begin
                                    pack_word_r[7:0]<=requant_spad[7:0];
                                    output_word_r<={24'd0,requant_spad[7:0]};
                                  end
                                  2'd1: begin
                                    pack_word_r[15:8]<=requant_spad[7:0];
                                    output_word_r<={16'd0,requant_spad[7:0],
                                                   pack_word_r[7:0]};
                                  end
                                  2'd2: begin
                                    pack_word_r[23:16]<=requant_spad[7:0];
                                    output_word_r<={8'd0,requant_spad[7:0],
                                                   pack_word_r[15:0]};
                                  end
                                  default: begin
                                    pack_word_r[31:24]<=requant_spad[7:0];
                                    output_word_r<={requant_spad[7:0],
                                                   pack_word_r[23:0]};
                                  end
                                endcase
                                if (index_r[1:0]==2'd3 ||
                                    last_element)
                                    state_r<=ST_VEC_WRITE;
                                else begin
                                    index_r<=index_r+1'b1;
                                    state_r<=ST_VEC_A_REQ;
                                end
                            end
                        end else begin
                            state_r<=ST_VEC_PREP;
                        end
                    end
                end
                ST_VEC_B_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_VEC_B_WAIT;
                end
                ST_VEC_B_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin gamma_r<=spad_signed; state_r<=ST_RMS_WRITE; end
                end
                ST_VEC_PREP: begin
                    vector_product_r <= (op_r==OP_GELU_Q8_8) ?
                        (x_r*(x_r+32'sd512)) :
                        (x_r*(x_r+32'sd768));
                    state_r<=ST_VEC_POST;
                end
                ST_VEC_POST: begin
                    if (is_normalization) begin
                        if (!rms_normalize_phase_r) begin
                            sum_sq_r<=sum_sq_r+vector_product_r;
                            if (last_element) begin
                                index_r<=0; state_r<=ST_RMS_MEAN_DIV_START;
                            end else begin
                                index_r<=index_r+1'b1;
                                state_r<=is_layernorm ?
                                        ST_LN_VAR_REQ : ST_RMS_SUM_REQ;
                            end
                        end else begin
                            output_word_r <= normalization_output;
                            state_r<=ST_VEC_WRITE;
                        end
                    end else begin
                        output_word_r <= (op_r == OP_GELU_Q8_8) ?
                                         gelu_piecewise_output :
                                         silu_piecewise_output;
                        state_r<=ST_VEC_WRITE;
                    end
                end
                ST_VEC_WRITE: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else begin
                        result<=output_word_r;
                        element_count<=element_count+
                            (packed_requant ?
                             ({30'd0,index_r[1:0]} + 32'd1) : 32'd1);
                        if (packed_requant)
                            pack_word_r<=0;
                        if (last_element) state_r<=ST_DONE;
                        else begin index_r<=index_r+1'b1;
                            state_r<=is_normalization ? ST_RMS_X_REQ : ST_VEC_A_REQ;
                        end
                    end
                end

                ST_LN_SUM_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_LN_SUM_WAIT;
                end
                ST_LN_SUM_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        sum_x_r<=sum_x_r+{{32{spad_signed[31]}},spad_signed};
                        if (last_element) begin index_r<=0; state_r<=ST_LN_MEAN_START; end
                        else begin index_r<=index_r+1'b1; state_r<=ST_LN_SUM_REQ; end
                    end
                end
                ST_LN_MEAN_START: begin
                    div_dividend_r<=sum_x_r[63] ? -sum_x_r : sum_x_r;
                    div_divisor_r<={48'd0,length_r}; div_start_r<=1;
                    state_r<=ST_LN_MEAN_WAIT;
                end
                ST_LN_MEAN_WAIT: if (div_done) begin
                    if (div_error || div_quotient>64'h0000_0000_8000_0000) begin
                        error_code<=ERR_NUMERIC; state_r<=ST_ERROR;
                    end else begin
                        mean_r<=sum_x_r[63] ? -$signed(div_quotient[31:0]) :
                                             $signed(div_quotient[31:0]);
                        sum_sq_r<=0; index_r<=0; state_r<=ST_LN_VAR_REQ;
                    end
                end
                ST_LN_VAR_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_LN_VAR_WAIT;
                end
                ST_LN_VAR_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin x_r<=spad_signed-mean_r; state_r<=ST_LN_VAR_ACC; end
                end
                ST_LN_VAR_ACC: begin
                    vector_product_r<=x_r*x_r;
                    state_r<=ST_VEC_POST;
                end
                ST_LN_B_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_LN_B_WAIT;
                end
                ST_LN_B_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin beta_r<=spad_signed; state_r<=ST_RMS_WRITE; end
                end

                ST_DONE: begin busy<=0; done<=1; error<=0; state_r<=ST_IDLE; end
                ST_ERROR: begin busy<=0; done<=1; error<=1; state_r<=ST_IDLE; end
                default: state_r<=ST_IDLE;
            endcase
        end
    end
endmodule
