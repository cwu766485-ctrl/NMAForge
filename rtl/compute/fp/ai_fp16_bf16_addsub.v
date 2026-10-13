// Combinational BF16/FP16 add/subtract with gradual underflow and RNE.
// Inputs and outputs are raw 16-bit encodings; NaNs are canonicalized.
module ai_fp16_bf16_addsub_core #(
    parameter integer EXP_BITS = 8,
    parameter integer FRAC_BITS = 7,
    parameter integer EXP_BIAS = 127,
    parameter [15:0] CANONICAL_QNAN = 16'h7fc0
) (
    input  wire [15:0] a_bits,
    input  wire [15:0] b_bits,
    input  wire        subtract,
    output reg  [15:0] result_bits
);
    localparam integer EMIN = 1 - EXP_BIAS;
    localparam integer EMAX = ((1 << EXP_BITS) - 2) - EXP_BIAS;

    reg sign_a, sign_b, sign_b_eff;
    reg [EXP_BITS-1:0] exp_a_field, exp_b_field;
    reg [FRAC_BITS-1:0] frac_a, frac_b;
    reg [14:0] sig_a, sig_b, large_ext, small_ext, work_ext;
    reg [FRAC_BITS+1:0] rounded_sig;
    reg [FRAC_BITS-1:0] result_frac;
    reg [EXP_BITS-1:0] result_exp;
    reg result_sign;
    integer exp_a, exp_b, exp_work;
    integer shift_amount;
    integer i;
    reg sticky;
    reg guard_bit, round_bit, sticky_bit;
    reg a_nan, b_nan, a_inf, b_inf, a_zero, b_zero;

    function [14:0] shift_right_jam;
        input [14:0] value;
        input integer amount;
        integer k;
        reg jam;
        reg [14:0] shifted;
        begin
            jam = 1'b0;
            if (amount >= 15) begin
                jam = |value;
                shifted = 15'b0;
            end else if (amount <= 0) begin
                shifted = value;
            end else begin
                shifted = value >> amount;
                for (k = 0; k < 15; k = k + 1)
                    if (k < amount)
                        jam = jam | value[k];
            end
            shifted[0] = shifted[0] | jam;
            shift_right_jam = shifted;
        end
    endfunction

    always @* begin
        sign_a = a_bits[15];
        sign_b = b_bits[15];
        exp_a_field = a_bits[FRAC_BITS +: EXP_BITS];
        exp_b_field = b_bits[FRAC_BITS +: EXP_BITS];
        frac_a = a_bits[FRAC_BITS-1:0];
        frac_b = b_bits[FRAC_BITS-1:0];
        a_nan = (&exp_a_field) && (|frac_a);
        b_nan = (&exp_b_field) && (|frac_b);
        a_inf = (&exp_a_field) && !(|frac_a);
        b_inf = (&exp_b_field) && !(|frac_b);
        a_zero = !(|exp_a_field) && !(|frac_a);
        b_zero = !(|exp_b_field) && !(|frac_b);
        sign_b_eff = sign_b ^ subtract;

        sig_a = {1'b0, frac_a, 3'b000};
        sig_b = {1'b0, frac_b, 3'b000};
        if (exp_a_field != 0) sig_a[FRAC_BITS+3] = 1'b1;
        if (exp_b_field != 0) sig_b[FRAC_BITS+3] = 1'b1;
        exp_a = (exp_a_field == 0) ? EMIN : (exp_a_field - EXP_BIAS);
        exp_b = (exp_b_field == 0) ? EMIN : (exp_b_field - EXP_BIAS);

        result_bits = 16'b0;
        result_sign = 1'b0;
        result_exp = {EXP_BITS{1'b0}};
        result_frac = {FRAC_BITS{1'b0}};
        large_ext = 15'b0;
        small_ext = 15'b0;
        work_ext = 15'b0;
        rounded_sig = {(FRAC_BITS+2){1'b0}};
        exp_work = EMIN;
        shift_amount = 0;
        sticky = 1'b0;
        guard_bit = 1'b0;
        round_bit = 1'b0;
        sticky_bit = 1'b0;

        if (a_nan || b_nan) begin
            result_bits = CANONICAL_QNAN;
        end else if (a_inf || b_inf) begin
            if (a_inf && b_inf && (sign_a != sign_b_eff))
                result_bits = CANONICAL_QNAN;
            else if (a_inf)
                result_bits = {sign_a, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
            else
                result_bits = {sign_b_eff, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
        end else if (a_zero && b_zero) begin
            // RNE retains -0 only when both effective operand signs are -.
            result_bits = {sign_a & sign_b_eff, {15{1'b0}}};
        end else begin
            // Order operands by magnitude before alignment/subtraction.
            if ((exp_a > exp_b) || ((exp_a == exp_b) && (sig_a >= sig_b))) begin
                large_ext = sig_a;
                small_ext = sig_b;
                exp_work = exp_a;
                result_sign = sign_a;
            end else begin
                large_ext = sig_b;
                small_ext = sig_a;
                exp_work = exp_b;
                result_sign = sign_b_eff;
            end

            shift_amount = (exp_a > exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);
            small_ext = shift_right_jam(small_ext, shift_amount);
            if (sign_a == sign_b_eff) begin
                work_ext = large_ext + small_ext;
                if (work_ext[FRAC_BITS+4]) begin
                    work_ext = shift_right_jam(work_ext, 1);
                    exp_work = exp_work + 1;
                end
            end else begin
                work_ext = large_ext - small_ext;
                if (work_ext == 0) begin
                    result_sign = 1'b0;
                end else begin
                    for (i = 0; i < FRAC_BITS+1; i = i + 1) begin
                        if (!work_ext[FRAC_BITS+3] && (exp_work > EMIN)) begin
                            work_ext = work_ext << 1;
                            exp_work = exp_work - 1;
                        end
                    end
                end
            end

            guard_bit = work_ext[2];
            round_bit = work_ext[1];
            sticky_bit = work_ext[0];
            sticky = round_bit | sticky_bit;
            rounded_sig = work_ext[FRAC_BITS+3:3];
            if (guard_bit && (sticky || rounded_sig[0]))
                rounded_sig = rounded_sig + 1'b1;

            if (work_ext == 0) begin
                result_bits = 16'b0;
            end else if (exp_work > EMAX) begin
                result_bits = {result_sign, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
            end else if (exp_work == EMIN && !rounded_sig[FRAC_BITS]) begin
                // At EMIN, a missing hidden bit denotes a rounded subnormal.
                result_frac = rounded_sig[FRAC_BITS-1:0];
                result_bits = {result_sign, {EXP_BITS{1'b0}}, result_frac};
            end else begin
                if (rounded_sig[FRAC_BITS+1]) begin
                    rounded_sig = rounded_sig >> 1;
                    exp_work = exp_work + 1;
                end
                if (exp_work > EMAX) begin
                    result_bits = {result_sign, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
                end else begin
                    result_exp = exp_work + EXP_BIAS;
                    result_frac = rounded_sig[FRAC_BITS-1:0];
                    result_bits = {result_sign, result_exp, result_frac};
                end
            end
        end
    end
endmodule

module ai_bf16_addsub (
    input  wire [15:0] a_bits,
    input  wire [15:0] b_bits,
    input  wire        subtract,
    output wire [15:0] result_bits
);
    ai_fp16_bf16_addsub_core #(
        .EXP_BITS(8), .FRAC_BITS(7), .EXP_BIAS(127), .CANONICAL_QNAN(16'h7fc0)
    ) u_core (.a_bits(a_bits), .b_bits(b_bits), .subtract(subtract), .result_bits(result_bits));
endmodule

module ai_fp16_addsub (
    input  wire [15:0] a_bits,
    input  wire [15:0] b_bits,
    input  wire        subtract,
    output wire [15:0] result_bits
);
    ai_fp16_bf16_addsub_core #(
        .EXP_BITS(5), .FRAC_BITS(10), .EXP_BIAS(15), .CANONICAL_QNAN(16'h7e00)
    ) u_core (.a_bits(a_bits), .b_bits(b_bits), .subtract(subtract), .result_bits(result_bits));
endmodule
