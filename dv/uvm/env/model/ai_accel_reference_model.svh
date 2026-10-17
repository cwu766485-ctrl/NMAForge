class ai_accel_reference_model extends uvm_object;
    `uvm_object_utils(ai_accel_reference_model)
    function new(string name="ai_accel_reference_model"); super.new(name); endfunction
    function bit descriptor_is_structurally_valid(ai_descriptor d); return (d.version==8'd7)&&(d.opcode!=0)&&(d.dst[1:0]==0)&&(d.src0[1:0]==0); endfunction

    // Exact-integer oracle for the randomized top-level slice: each input is
    // an integer in [1, 7], so products and the FP32 sum are exact.
    function automatic bit [31:0] predict_small_integer_dot(
        input int unsigned a0,
        input int unsigned a1,
        input int unsigned a2,
        input int unsigned a3,
        input int unsigned b0,
        input int unsigned b1,
        input int unsigned b2,
        input int unsigned b3,
        input int unsigned length
    );
        int unsigned result;
        int unsigned exponent;
        int unsigned base;
        bit [31:0] encoded;

        result = a0 * b0;
        if (length > 1)
            result += a1 * b1;
        if (length > 2)
            result += a2 * b2;
        if (length > 3)
            result += a3 * b3;
        if (result == 0)
            return 32'b0;

        exponent = 0;
        base = 1;
        while ((base << 1) <= result) begin
            base = base << 1;
            exponent++;
        end

        encoded = '0;
        encoded[30:23] = 127 + exponent;
        encoded[22:0] = (result - base) << (23 - exponent);
        return encoded;
    endfunction

    // Signed INT8 four-lane dot product.  The packed return value is the
    // 32-bit two's-complement sum, independent of the FP reference path.
    function automatic bit [31:0] predict_int8_dot4(
        input bit signed [7:0] a0,
        input bit signed [7:0] a1,
        input bit signed [7:0] a2,
        input bit signed [7:0] a3,
        input bit signed [7:0] b0,
        input bit signed [7:0] b1,
        input bit signed [7:0] b2,
        input bit signed [7:0] b3
    );
        int signed result;

        result = $signed(a0) * $signed(b0);
        result += $signed(a1) * $signed(b1);
        result += $signed(a2) * $signed(b2);
        result += $signed(a3) * $signed(b3);
        return result[31:0];
    endfunction

    function ai_completion predict_rejected_completion(ai_descriptor d, bit [3:0] error_code);
        ai_completion c=ai_completion::type_id::create("rejected_completion"); c.task_id=d.task_id; c.status=4'hf; c.error_code=error_code; c.result='0; c.element_count='0; return c;
    endfunction
endclass
