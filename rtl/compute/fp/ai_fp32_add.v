// Combinational IEEE-754 binary32 addition with gradual underflow and RNE.
// NaNs are canonicalized and no exception flags are generated.
module ai_fp32_add (
    input  wire [31:0] a_bits,
    input  wire [31:0] b_bits,
    output reg  [31:0] result_bits
);
    localparam [31:0] CANONICAL_QNAN = 32'h7fc00000;

    reg sign_a, sign_b;
    reg [7:0] exp_a_field, exp_b_field;
    reg [22:0] frac_a, frac_b;
    reg [23:0] sig_a, sig_b;
    reg [27:0] large_ext, small_ext, work_ext;
    reg [24:0] rounded_sig;
    reg [22:0] result_frac;
    reg [7:0] result_exp;
    reg result_sign;
    integer exp_a, exp_b, large_exp, small_exp, exp_work;
    integer shift_amount;
    integer i;
    reg a_nan, b_nan, a_inf, b_inf, a_zero, b_zero;

    function [27:0] shift_right_jam;
        input [27:0] value;
        input integer amount;
        integer k;
        reg jam;
        reg [27:0] shifted;
        begin
            jam = 1'b0;
            if (amount >= 28) begin
                jam = |value;
                shifted = 28'b0;
            end else if (amount <= 0) begin
                shifted = value;
            end else begin
                shifted = value >> amount;
                for (k = 0; k < 28; k = k + 1)
                    if (k < amount)
                        jam = jam | value[k];
            end
            shifted[0] = shifted[0] | jam;
            shift_right_jam = shifted;
        end
    endfunction

    always @* begin
        sign_a = a_bits[31];
        sign_b = b_bits[31];
        exp_a_field = a_bits[30:23];
        exp_b_field = b_bits[30:23];
        frac_a = a_bits[22:0];
        frac_b = b_bits[22:0];
        a_nan = (&exp_a_field) && (|frac_a);
        b_nan = (&exp_b_field) && (|frac_b);
        a_inf = (&exp_a_field) && !(|frac_a);
        b_inf = (&exp_b_field) && !(|frac_b);
        a_zero = !(|exp_a_field) && !(|frac_a);
        b_zero = !(|exp_b_field) && !(|frac_b);

        sig_a = {1'b0, frac_a};
        sig_b = {1'b0, frac_b};
        if (exp_a_field != 0) sig_a[23] = 1'b1;
        if (exp_b_field != 0) sig_b[23] = 1'b1;
        exp_a = (exp_a_field == 0) ? -126 : (exp_a_field - 127);
        exp_b = (exp_b_field == 0) ? -126 : (exp_b_field - 127);

        result_bits = 32'b0;
        result_sign = 1'b0;
        result_exp = 8'b0;
        result_frac = 23'b0;
        large_ext = 28'b0;
        small_ext = 28'b0;
        work_ext = 28'b0;
        rounded_sig = 25'b0;
        large_exp = 0;
        small_exp = 0;
        exp_work = 0;
        shift_amount = 0;

        if (a_nan || b_nan || (a_inf && b_inf && (sign_a != sign_b))) begin
            result_bits = CANONICAL_QNAN;
        end else if (a_inf) begin
            result_bits = {sign_a, 8'hff, 23'b0};
        end else if (b_inf) begin
            result_bits = {sign_b, 8'hff, 23'b0};
        end else if (a_zero && b_zero) begin
            // Under RNE, exact zero is negative only when both operands are -0.
            result_bits = {sign_a & sign_b, 31'b0};
        end else if (a_zero) begin
            result_bits = b_bits;
        end else if (b_zero) begin
            result_bits = a_bits;
        end else begin
            // Put the larger magnitude first; this also makes subtraction nonnegative.
            if ((exp_a > exp_b) || ((exp_a == exp_b) && (sig_a >= sig_b))) begin
                large_ext = {1'b0, sig_a, 3'b000};
                small_ext = {1'b0, sig_b, 3'b000};
                large_exp = exp_a;
                small_exp = exp_b;
                result_sign = sign_a;
            end else begin
                large_ext = {1'b0, sig_b, 3'b000};
                small_ext = {1'b0, sig_a, 3'b000};
                large_exp = exp_b;
                small_exp = exp_a;
                result_sign = sign_b;
            end

            shift_amount = large_exp - small_exp;
            small_ext = shift_right_jam(small_ext, shift_amount);
            exp_work = large_exp;

            if (sign_a == sign_b) begin
                work_ext = large_ext + small_ext;
                if (work_ext[27]) begin
                    work_ext = shift_right_jam(work_ext, 1);
                    exp_work = exp_work + 1;
                end
            end else begin
                work_ext = large_ext - small_ext;
                if (work_ext == 0) begin
                    result_bits = 32'b0; // exact nonzero cancellation is +0
                end else begin
                    for (i = 0; i < 27; i = i + 1) begin
                        if (!work_ext[26] && (work_ext != 0)) begin
                            work_ext = work_ext << 1;
                            exp_work = exp_work - 1;
                        end
                    end
                end
            end

            if (!((sign_a != sign_b) && (work_ext == 0))) begin
                // Shift into the subnormal exponent range before rounding.
                if (exp_work < -126) begin
                    work_ext = shift_right_jam(work_ext, -126 - exp_work);
                    exp_work = -126;
                end

                // Three low bits are guard, round, sticky. Ties go to even.
                rounded_sig = {1'b0, work_ext[26:3]};
                if (work_ext[2] && (work_ext[1] || work_ext[0] || work_ext[3]))
                    rounded_sig = rounded_sig + 1'b1;

                if (rounded_sig[23] && (exp_work == -126)) begin
                    // This covers a subnormal rounding up to the least normal.
                    result_exp = 8'd1;
                    result_frac = rounded_sig[22:0];
                    result_bits = {result_sign, result_exp, result_frac};
                end else if (rounded_sig[24]) begin
                    rounded_sig = {1'b0, 1'b1, 23'b0};
                    exp_work = exp_work + 1;
                    if (exp_work > 127)
                        result_bits = {result_sign, 8'hff, 23'b0};
                    else begin
                        result_exp = exp_work + 127;
                        result_bits = {result_sign, result_exp, rounded_sig[22:0]};
                    end
                end else if (exp_work > 127) begin
                    result_bits = {result_sign, 8'hff, 23'b0};
                end else if ((exp_work == -126) && !rounded_sig[23]) begin
                    result_bits = {result_sign, 8'b0, rounded_sig[22:0]};
                end else begin
                    result_exp = exp_work + 127;
                    result_bits = {result_sign, result_exp, rounded_sig[22:0]};
                end
            end
        end
    end
endmodule
