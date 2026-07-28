`timescale 1ns / 1ps

// A4 sequential vector/SFU engine for Transformer primitives.
//
// Fixed-point contracts:
//   SOFTMAX input  : signed Q8.8 log2-domain scores in one 32-bit word each.
//   SOFTMAX output : unsigned Q0.15 probability in bits [15:0] of each word.
//   RMSNORM input  : signed integer/Q8.8 values; gamma is signed Q0.15.
//   RMSNORM output : same numeric scale as gamma-normalized input, int32.
//   GELU/SILU      : signed Q8.8 input/output using bounded piecewise models.
//   REQUANT        : arithmetic right shift and signed INT8 saturation, sign
//                    extended in a 32-bit scratchpad word.
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

    localparam [3:0] ERR_CONFIG=4'd1, ERR_OP=4'd2, ERR_ABORT=4'd3,
                     ERR_WATCHDOG=4'd4, ERR_PARITY=4'd5,
                     ERR_PROTECTION=4'd6, ERR_NUMERIC=4'd11;

    localparam [5:0] ST_IDLE=6'd0,
        ST_SM_MAX_REQ=6'd1, ST_SM_MAX_WAIT=6'd2,
        ST_SM_SUM_REQ=6'd3, ST_SM_SUM_WAIT=6'd4,
        ST_SM_OUT_REQ=6'd5, ST_SM_OUT_WAIT=6'd6,
        ST_SM_DIV_START=6'd7, ST_SM_DIV_WAIT=6'd8, ST_SM_WRITE=6'd9,
        ST_RMS_SUM_REQ=6'd10, ST_RMS_SUM_WAIT=6'd11,
        ST_RMS_MEAN_DIV_START=6'd12, ST_RMS_MEAN_DIV_WAIT=6'd13,
        ST_RMS_SQRT_START=6'd14, ST_RMS_SQRT_WAIT=6'd15,
        ST_RMS_INV_START=6'd16, ST_RMS_INV_WAIT=6'd17,
        ST_RMS_X_REQ=6'd18, ST_RMS_X_WAIT=6'd19,
        ST_RMS_G_REQ=6'd20, ST_RMS_G_WAIT=6'd21, ST_RMS_WRITE=6'd22,
        ST_VEC_A_REQ=6'd23, ST_VEC_A_WAIT=6'd24,
        ST_VEC_B_REQ=6'd25, ST_VEC_B_WAIT=6'd26, ST_VEC_WRITE=6'd27,
        ST_DONE=6'd28, ST_ERROR=6'd29,
        ST_VEC_PREP=6'd30, ST_VEC_POST=6'd31,
        ST_LN_SUM_REQ=6'd32, ST_LN_SUM_WAIT=6'd33,
        ST_LN_MEAN_START=6'd34, ST_LN_MEAN_WAIT=6'd35,
        ST_LN_VAR_REQ=6'd36, ST_LN_VAR_WAIT=6'd37,
        ST_LN_VAR_ACC=6'd38, ST_LN_B_REQ=6'd39,
        ST_LN_B_WAIT=6'd40;

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
    reg rms_normalize_phase_r, beta_enable_r;

    reg div_start_r, sqrt_start_r;
    reg [63:0] div_dividend_r, div_divisor_r;
    wire div_busy, div_done, div_error;
    wire [63:0] div_quotient, div_remainder;
    wire sqrt_busy, sqrt_done;
    wire [31:0] sqrt_root;

    wire [31:0] src0_addr = src0_r + ({16'd0,index_r}<<2);
    wire [31:0] src1_addr = src1_r + ({16'd0,index_r}<<2);
    wire [31:0] beta_addr = beta_base_r + ({16'd0,index_r}<<2);
    wire [31:0] dst_addr  = dst_r  + ({16'd0,index_r}<<2);
    wire signed [31:0] spad_signed = spad_rdata;
    wire causal_masked = (op_r == OP_CAUSAL_SOFTMAX_Q15) &&
                         (index_r > epsilon_r[15:0]);

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

    function [31:0] exp2_q15;
        input signed [31:0] delta_q8_8;
        reg [31:0] magnitude;
        reg [7:0] fraction;
        reg [7:0] integer_part;
        reg [31:0] base_value, next_value;
        begin
            if (delta_q8_8>=0)
                exp2_q15=32'd32768;
            else begin
                magnitude=-delta_q8_8;
                integer_part=magnitude[15:8];
                fraction=magnitude[7:0];
                if (integer_part>=8'd15)
                    exp2_q15=0;
                else begin
                    base_value=32'd32768>>integer_part;
                    next_value=base_value>>1;
                    exp2_q15=base_value-(((base_value-next_value)*fraction)>>8);
                end
            end
        end
    endfunction

    function [31:0] clamp_i32;
        input signed [63:0] value;
        begin
            if (value>64'sh0000_0000_7fff_ffff) clamp_i32=32'h7fff_ffff;
            else if (value<-64'sd2147483648) clamp_i32=32'h8000_0000;
            else clamp_i32=value[31:0];
        end
    endfunction

    function [31:0] gelu_piecewise_q8_8;
        input signed [31:0] value;
        reg signed [63:0] product_value;
        begin
            if (value<=-32'sd512) gelu_piecewise_q8_8=0;
            else if (value>=32'sd512) gelu_piecewise_q8_8=value;
            else begin
                product_value=value*(value+32'sd512);
                gelu_piecewise_q8_8=clamp_i32(product_value>>>10);
            end
        end
    endfunction

    function [31:0] silu_piecewise_q8_8;
        input signed [31:0] value;
        reg signed [63:0] product_value;
        begin
            if (value<=-32'sd768) silu_piecewise_q8_8=0;
            else if (value>=32'sd768) silu_piecewise_q8_8=value;
            else begin
                product_value=value*(value+32'sd768);
                silu_piecewise_q8_8=clamp_i32(product_value/64'sd1536);
            end
        end
    endfunction

    function [31:0] requant_i8;
        input signed [31:0] value;
        reg signed [31:0] shifted;
        begin
            shifted=value>>>scale_shift_r;
            if (shifted>127) requant_i8=32'h0000_007f;
            else if (shifted<-128) requant_i8=32'hffff_ff80;
            else requant_i8={{24{shifted[7]}},shifted[7:0]};
        end
    endfunction

    wire signed [63:0] residual_sum = $signed(x_r)+$signed(gamma_r);
    wire signed [63:0] residual_shifted = residual_sum>>>scale_shift_r;
    wire signed [63:0] rms_scaled = ($signed(x_r)*$signed(inv_rms_r))>>>30;
    wire signed [63:0] norm_with_beta = rms_scaled + $signed(beta_r);

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
            div_start_r<=0; sqrt_start_r<=0; div_dividend_r<=0; div_divisor_r<=0;
            busy<=0; done<=0; error<=0; error_code<=0; result<=0;
            cycle_count<=0; element_count<=0;
        end else begin
            done<=0; div_start_r<=0; sqrt_start_r<=0;
            if (busy) cycle_count<=cycle_count+1'b1;

            if (busy && abort) begin error_code<=ERR_ABORT; state_r<=ST_ERROR; end
            else if (busy && watchdog_limit_r!=0 && cycle_count>=watchdog_limit_r) begin
                error_code<=ERR_WATCHDOG; state_r<=ST_ERROR;
            end else case (state_r)
                ST_IDLE: begin
                    busy<=0; error<=0; error_code<=0;
                    if (start) begin
                        op_r<=op_mode; src0_r<=src0_base; src1_r<=src1_base;
                        beta_base_r<=beta_base; beta_enable_r<=beta_enable; dst_r<=dst_base;
                        length_r<=length; scale_shift_r<=scale_shift;
                        epsilon_r<=epsilon==0 ? 32'd1 : epsilon;
                        watchdog_limit_r<=watchdog_limit; index_r<=0;
                        cycle_count<=0; element_count<=0; busy<=1;
                        max_r<=32'sh8000_0000; sum_exp_r<=0; sum_sq_r<=0; sum_x_r<=0;
                        mean_r<=0; beta_r<=0;
                        rms_normalize_phase_r<=0;
                        if (length==0 || |src0_base[1:0] || |dst_base[1:0] ||
                            ((op_mode==OP_RESIDUAL_I32 || op_mode==OP_RMSNORM_Q15 ||
                              op_mode==OP_LAYERNORM_Q15) && src1_base!=0 && |src1_base[1:0]) ||
                            (op_mode==OP_LAYERNORM_Q15 && beta_enable && |beta_base[1:0])) begin
                            error_code<=ERR_CONFIG; state_r<=ST_ERROR;
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
                        if (index_r==length_r-1'b1) begin index_r<=0; sum_exp_r<=0; state_r<=ST_SM_SUM_REQ; end
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
                            sum_exp_r<=sum_exp_r+exp2_q15(spad_signed-max_r);
                        if (index_r==length_r-1'b1) begin index_r<=0; state_r<=ST_SM_OUT_REQ; end
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
                    else begin exp_r<=exp2_q15(spad_signed-max_r); state_r<=ST_SM_DIV_START; end
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
                        if (index_r==length_r-1'b1) state_r<=ST_DONE;
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
                        x_r<=(op_r==OP_LAYERNORM_Q15) ? spad_signed-mean_r : spad_signed;
                        if (src1_r==0) begin
                            gamma_r<=32'sd32768;
                            state_r<=(op_r==OP_LAYERNORM_Q15 && beta_enable_r) ?
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
                        state_r<=(op_r==OP_LAYERNORM_Q15 && beta_enable_r) ?
                                ST_LN_B_REQ : ST_RMS_WRITE;
                    end
                end
                ST_RMS_WRITE: begin
                    if (op_r==OP_RESIDUAL_I32) begin
                        output_word_r<=clamp_i32(residual_shifted);
                        state_r<=ST_VEC_WRITE;
                    end else if (!rms_normalize_phase_r) begin
                        vector_product_r<=$signed(x_r)*$signed(x_r);
                        state_r<=ST_VEC_POST;
                    end else begin
                        // Saturating the post-gamma intermediate to INT32 is
                        // both the A3 numeric contract and a clean pipeline
                        // cut before reciprocal scaling.
                        x_r<=clamp_i32(($signed(x_r)*$signed(gamma_r))>>>15);
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
                            output_word_r<=requant_i8(spad_signed);
                            state_r<=ST_VEC_WRITE;
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
                        ($signed(x_r)*($signed(x_r)+32'sd512)) :
                        ($signed(x_r)*($signed(x_r)+32'sd768));
                    state_r<=ST_VEC_POST;
                end
                ST_VEC_POST: begin
                    if (op_r==OP_RMSNORM_Q15 || op_r==OP_LAYERNORM_Q15) begin
                        if (!rms_normalize_phase_r) begin
                            sum_sq_r<=sum_sq_r+vector_product_r;
                            if (index_r==length_r-1'b1) begin
                                index_r<=0; state_r<=ST_RMS_MEAN_DIV_START;
                            end else begin
                                index_r<=index_r+1'b1;
                                state_r<=(op_r==OP_LAYERNORM_Q15) ?
                                        ST_LN_VAR_REQ : ST_RMS_SUM_REQ;
                            end
                        end else begin
                            output_word_r<=clamp_i32(op_r==OP_LAYERNORM_Q15 ?
                                                   norm_with_beta : rms_scaled);
                            state_r<=ST_VEC_WRITE;
                        end
                    end else begin
                        output_word_r <= (op_r==OP_GELU_Q8_8) ?
                            clamp_i32(vector_product_r>>>10) :
                            clamp_i32(vector_product_r/64'sd1536);
                        state_r<=ST_VEC_WRITE;
                    end
                end
                ST_VEC_WRITE: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else begin
                        result<=output_word_r; element_count<=element_count+1'b1;
                        if (index_r==length_r-1'b1) state_r<=ST_DONE;
                        else begin index_r<=index_r+1'b1;
                            state_r<=((op_r==OP_RMSNORM_Q15) ||
                                      (op_r==OP_LAYERNORM_Q15)) ? ST_RMS_X_REQ : ST_VEC_A_REQ;
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
                        if (index_r==length_r-1'b1) begin index_r<=0; state_r<=ST_LN_MEAN_START; end
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
                    vector_product_r<=$signed(x_r)*$signed(x_r);
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
