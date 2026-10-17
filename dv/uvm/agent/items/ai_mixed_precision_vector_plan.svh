class ai_mixed_precision_vector_plan extends uvm_object;
    `uvm_object_utils(ai_mixed_precision_vector_plan)

    int unsigned seed;
    rand int unsigned fp16_a0, fp16_a1, fp16_a2, fp16_a3;
    rand int unsigned fp16_b0, fp16_b1, fp16_b2, fp16_b3;
    rand int unsigned bf16_a0, bf16_a1, bf16_a2, bf16_a3;
    rand int unsigned bf16_b0, bf16_b1, bf16_b2, bf16_b3;
    rand int unsigned fp16_length, bf16_length;
    // Exhaustive seeded top-level regression can override this field to cover
    // all legal CMDQ orderings. Without an override it remains randomized.
    rand int unsigned descriptor_order;
    // Shift data words across scratchpad bank addresses without changing the
    // descriptor ABI or overlapping any operand/result allocation.
    rand int unsigned spad_layout;
    // Optional top-level AXI memory-model stall settings; randomized from the
    // same explicit object seed as the rest of this plan.
    rand int unsigned axi_read_gap;
    rand int unsigned axi_ready_gap;
    // Independent, seeded AR/AW address-channel READY latency.
    rand int unsigned axi_ar_gap;
    rand int unsigned axi_aw_gap;
    // Four signed INT8 lanes.  Lane zero occupies the least-significant byte
    // when packed by int8_a_word()/int8_b_word().
    rand bit signed [7:0] int8_a0, int8_a1, int8_a2, int8_a3;
    rand bit signed [7:0] int8_b0, int8_b1, int8_b2, int8_b3;

    constraint c_exact_positive_operands {
        fp16_a0 inside {[1:7]};
        fp16_a1 inside {[1:7]};
        fp16_a2 inside {[1:7]};
        fp16_a3 inside {[1:7]};
        fp16_b0 inside {[1:7]};
        fp16_b1 inside {[1:7]};
        fp16_b2 inside {[1:7]};
        fp16_b3 inside {[1:7]};
        bf16_a0 inside {[1:7]};
        bf16_a1 inside {[1:7]};
        bf16_a2 inside {[1:7]};
        bf16_a3 inside {[1:7]};
        bf16_b0 inside {[1:7]};
        bf16_b1 inside {[1:7]};
        bf16_b2 inside {[1:7]};
        bf16_b3 inside {[1:7]};
        fp16_length inside {[1:4]};
        bf16_length inside {[1:4]};
        descriptor_order inside {[0:5]};
        spad_layout inside {[0:5]};
        axi_read_gap inside {[0:3]};
        axi_ready_gap inside {[0:3]};
        axi_ar_gap inside {[0:3]};
        axi_aw_gap inside {[0:3]};
        int8_a0 inside {[-7:7]};
        int8_a1 inside {[-7:7]};
        int8_a2 inside {[-7:7]};
        int8_a3 inside {[-7:7]};
        int8_b0 inside {[-7:7]};
        int8_b1 inside {[-7:7]};
        int8_b2 inside {[-7:7]};
        int8_b3 inside {[-7:7]};
        // Keep every generated vector representative of signed arithmetic.
        // Across each vector, require at least one negative, zero, and positive
        // lane so a seeded stimulus exercises all three sign cases.
        (int8_a0 < 0) || (int8_a1 < 0) || (int8_a2 < 0) || (int8_a3 < 0);
        (int8_a0 == 0) || (int8_a1 == 0) || (int8_a2 == 0) || (int8_a3 == 0);
        (int8_a0 > 0) || (int8_a1 > 0) || (int8_a2 > 0) || (int8_a3 > 0);
        (int8_b0 < 0) || (int8_b1 < 0) || (int8_b2 < 0) || (int8_b3 < 0);
        (int8_b0 == 0) || (int8_b1 == 0) || (int8_b2 == 0) || (int8_b3 == 0);
        (int8_b0 > 0) || (int8_b1 > 0) || (int8_b2 > 0) || (int8_b3 > 0);
    }

    function new(string name = "ai_mixed_precision_vector_plan");
        super.new(name);
    endfunction

    // Seed the object RNG explicitly so the complete plan, including INT8
    // lanes, can be regenerated exactly by repeating the same seed.
    function bit randomize_int8_stimulus(input int unsigned stimulus_seed);
        seed = stimulus_seed;
        this.srandom(stimulus_seed);
        return this.randomize();
    endfunction

    // Operation IDs: 0=FP16, 1=BF16, 2=INT8. The six codes enumerate every
    // permutation exactly once and preserve the descriptor ABI.
    function int unsigned operation_at_slot(input int unsigned slot);
        if (slot > 2)
            return 3;
        case (descriptor_order)
            0: case (slot) 0: return 0; 1: return 1; default: return 2; endcase
            1: case (slot) 0: return 0; 1: return 2; default: return 1; endcase
            2: case (slot) 0: return 1; 1: return 0; default: return 2; endcase
            3: case (slot) 0: return 1; 1: return 2; default: return 0; endcase
            4: case (slot) 0: return 2; 1: return 0; default: return 1; endcase
            5: case (slot) 0: return 2; 1: return 1; default: return 0; endcase
            default: return 3;
        endcase
    endfunction

    // Small positive integers are exactly representable in FP16 and BF16.
    function automatic bit [15:0] encode_fp16_integer(input int unsigned value);
        int unsigned exponent;
        int unsigned base;
        bit [15:0] encoded;

        exponent = 0;
        base = 1;
        while ((base << 1) <= value) begin
            base = base << 1;
            exponent++;
        end

        encoded = '0;
        encoded[14:10] = 15 + exponent;
        encoded[9:0] = (value - base) << (10 - exponent);
        return encoded;
    endfunction

    function automatic bit [15:0] encode_bf16_integer(input int unsigned value);
        int unsigned exponent;
        int unsigned base;
        bit [15:0] encoded;

        exponent = 0;
        base = 1;
        while ((base << 1) <= value) begin
            base = base << 1;
            exponent++;
        end

        encoded = '0;
        encoded[14:7] = 127 + exponent;
        encoded[6:0] = (value - base) << (7 - exponent);
        return encoded;
    endfunction

    function bit [31:0] fp16_a_word(input int unsigned word_index);
        if (word_index == 0)
            return {encode_fp16_integer(fp16_a1), encode_fp16_integer(fp16_a0)};
        return {encode_fp16_integer(fp16_a3), encode_fp16_integer(fp16_a2)};
    endfunction

    function bit [31:0] fp16_b_word(input int unsigned word_index);
        if (word_index == 0)
            return {encode_fp16_integer(fp16_b1), encode_fp16_integer(fp16_b0)};
        return {encode_fp16_integer(fp16_b3), encode_fp16_integer(fp16_b2)};
    endfunction

    function bit [31:0] bf16_a_word(input int unsigned word_index);
        if (word_index == 0)
            return {encode_bf16_integer(bf16_a1), encode_bf16_integer(bf16_a0)};
        return {encode_bf16_integer(bf16_a3), encode_bf16_integer(bf16_a2)};
    endfunction

    function bit [31:0] bf16_b_word(input int unsigned word_index);
        if (word_index == 0)
            return {encode_bf16_integer(bf16_b1), encode_bf16_integer(bf16_b0)};
        return {encode_bf16_integer(bf16_b3), encode_bf16_integer(bf16_b2)};
    endfunction

    function bit [31:0] int8_a_word();
        return {int8_a3, int8_a2, int8_a1, int8_a0};
    endfunction

    function bit [31:0] int8_b_word();
        return {int8_b3, int8_b2, int8_b1, int8_b0};
    endfunction
endclass
