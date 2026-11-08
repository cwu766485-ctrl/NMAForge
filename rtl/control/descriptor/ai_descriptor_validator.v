module ai_descriptor_validator (
    input  wire [7:0]  op,
    input  wire [7:0]  version,
    input  wire [31:0] src0,
    input  wire [31:0] src1,
    input  wire [31:0] dst,
    input  wire [31:0] bias_base,
    input  wire [15:0] length,
    input  wire [15:0] m_size,
    input  wire [15:0] n_size,
    input  wire [15:0] k_words,
    input  wire        bias_enable,
    input  wire [7:0]  flags,
    input  wire [4:0]  scale_shift,
    input  wire [1:0]  activation,
    input  wire [31:0] aux0,
    input  wire [31:0] src0_stride,
    input  wire [31:0] src1_stride,
    input  wire [31:0] dst_stride,
    input  wire [15:0] batch_count,
    input  wire [15:0] head_count,
    input  wire        macro_child_fetch,

    output wire        op_valid,
    output wire        is_macro,
    output wire        is_tensor_matrix,
    output wire        is_tensor_sfu,
    output wire        version_valid,
    output wire        dimensions_valid,
    output wire        alignment_error,
    output wire        descriptor_invalid
);

    assign is_macro = (op >= 8'h40) && (op <= 8'h42);

    assign op_valid = ((op >= 8'h10) && (op <= 8'h17)) ||
                      (op == 8'h20) || (op == 8'h21) ||
                      ((op >= 8'h30) && (op <= 8'h39)) ||
                      ((op >= 8'h43) && (op <= 8'h44)) ||
                      is_macro || (op == 8'h50) || (op == 8'h51) ||
                      (op == 8'h52) || (op == 8'h53);

    assign is_tensor_matrix = (op == 8'h30) || (op == 8'h31) ||
                              (op == 8'h52) ||
                              (op == 8'h53);
    assign is_tensor_sfu = (op >= 8'h32) && (op <= 8'h39);
    wire is_bf16_dot = (op == 8'h50);
    wire is_fp16_dot = (op == 8'h51);
    wire is_fp_dot = is_bf16_dot || is_fp16_dot;
    wire [31:0] pack_tile_a_elements = {16'd0,m_size} * {16'd0,n_size};
    wire pack_tile_a_fields_valid =
        (op == 8'h36) && flags[4] &&
        (m_size != 0) && (n_size != 0) &&
        (m_size[1:0] == 0) && (n_size[1:0] == 0) &&
        (pack_tile_a_elements == {16'd0,length});

    assign version_valid = is_fp_dot ? (version == 8'd7) :
                           (version == 8'd7) ? 1'b1 :
                           is_macro ? (version == 8'd4) :
                           ((op == 8'h16 || op == 8'h17 ||
                             op == 8'h43 || op == 8'h44) ?
                            (version == 8'd5) :
                            (!(is_tensor_matrix || is_tensor_sfu) ||
                             (version == 8'd3)));

    assign dimensions_valid = (op == 8'h10 && length != 0) ||
                              ((op == 8'h11 || op == 8'h21) &&
                               m_size != 0 &&
                               (op == 8'h21 ? length != 0 : k_words != 0)) ||
                              ((op >= 8'h12 && op <= 8'h15) &&
                               m_size != 0 && n_size != 0 && k_words != 0) ||
                              (op == 8'h20 && length != 0) ||
                              (is_tensor_matrix && (op != 8'h52) &&
                               m_size != 0 &&
                               n_size != 0 && k_words != 0 &&
                               m_size[1:0] == 0 && n_size[1:0] == 0) ||
                              ((op == 8'h52) &&
                               (m_size >= 16'd1) && (m_size <= 16'd16) &&
                               (n_size >= 16'd1) && (n_size <= 16'd16) &&
                               (k_words != 16'd0)) ||
                              (is_tensor_sfu && length != 0) ||
                              ((op == 8'h16 || op == 8'h17) &&
                               m_size >= 16'd3 && n_size >= 16'd3) ||
                              ((op == 8'h43 || op == 8'h44) && length != 0) ||
                              (is_fp_dot && length != 0 &&
                               m_size == 16'd1 && n_size == 16'd1) ||
                              (op == 8'h40 && length == 16'd3) ||
                              ((op == 8'h41 || op == 8'h42) &&
                               length >= 16'd3 && length <= 16'd256);

    // For an ABI-v7 macro parent, src1 is the high word of the 64-bit child
    // list pointer {src1,src0}. Check alignment on the complete address via
    // src0's low bits; src1 is not an independently aligned data pointer.
    wire macro_v7_uses_64b_child_base = is_macro && (version == 8'd7);
    assign alignment_error = (|src0[1:0]) ||
                             ((|src1[1:0]) && !macro_v7_uses_64b_child_base) ||
                             (|dst[1:0]) ||
                             (bias_enable && (|bias_base[1:0])) ||
                             ((op == 8'h52) &&
                              ((|src0[3:0]) || (|src1[3:0])));

    wire fp_dot_fields_valid =
        (bias_base == 32'd0) && !bias_enable && (flags == 8'd0) &&
        (scale_shift == 5'd0) && (activation == 2'd0) &&
        (aux0 == 32'd0) && (src0_stride == 32'd0) &&
        (src1_stride == 32'd0) && (dst_stride == 32'd0) &&
        (batch_count == 16'd0) && (head_count == 16'd0);

    wire fused_matrix_fields_valid =
        (op != 8'h53) || ((version == 8'd7) && (aux0[31:8] == 0) &&
        (dst_stride == 0 || dst_stride[3:0] == 0) &&
        (dst[3:0] == 0) &&
        (!aux0[7] || ((aux0[6:5] == 0) && (m_size != 0) &&
                      (m_size[1:0] == 0) &&
                      (((n_size == 16'd4) && (m_size <= 16'd64)) ||
                       ((n_size == 16'd16) && (m_size <= 16'd512))) &&
                      (batch_count <= 16'd1) &&
                      (head_count <= 16'd1) && (dst_stride == 0) &&
                      (flags[7:1] == 0) && (flags[0] == bias_enable))) &&
        (!aux0[5] || ((m_size == 16) && (n_size == 16) &&
                      (batch_count <= 16'd1) && (dst_stride == 0))) &&
        (!aux0[6] || ((m_size == 16) && (k_words == 16'd4) &&
                      !flags[1] && (batch_count <= 16'd1) &&
                      (src0_stride == 0))));

    // Product GEMV descriptor field gate. Shape support is bounded by the
    // shared 16x16 Matrix array; unsupported strides, batching, and flags are
    // rejected before dispatch rather than silently ignored.
    // Opcode 0x52 consumes dense A rows padded to a 16-byte K stride, dense
    // B rows of 16 bytes, and a contiguous INT32 output. Keep these byte-span
    // calculations in the validator so an in-place destination cannot
    // overwrite operands that later row/K tiles still need to read.
    wire [31:0] gemv_a_bytes =
        ((({16'd0,k_words} + 32'd15) & 32'hffff_fff0) * {16'd0,m_size});
    wire [31:0] gemv_b_bytes = {16'd0,k_words} << 4;
    wire [31:0] gemv_dst_bytes =
        {16'd0,m_size} * {16'd0,n_size} * 32'd4;
    wire [31:0] gemv_bias_bytes = {16'd0,n_size} << 2;
    wire [32:0] gemv_a_end = {1'b0,src0} + {1'b0,gemv_a_bytes};
    wire [32:0] gemv_b_end = {1'b0,src1} + {1'b0,gemv_b_bytes};
    wire [32:0] gemv_dst_end = {1'b0,dst} + {1'b0,gemv_dst_bytes};
    wire [32:0] gemv_bias_end = {1'b0,bias_base} + {1'b0,gemv_bias_bytes};
    wire gemv_range_error =
        (gemv_a_end[32] && (|gemv_a_end[31:0])) ||
        (gemv_b_end[32] && (|gemv_b_end[31:0])) ||
        (gemv_dst_end[32] && (|gemv_dst_end[31:0])) ||
        (bias_enable && gemv_bias_end[32] && (|gemv_bias_end[31:0]));
    wire gemv_write_alias =
        (({1'b0,dst} < gemv_a_end) && ({1'b0,src0} < gemv_dst_end)) ||
        (({1'b0,dst} < gemv_b_end) && ({1'b0,src1} < gemv_dst_end)) ||
        (bias_enable && ({1'b0,dst} < gemv_bias_end) &&
         ({1'b0,bias_base} < gemv_dst_end));
    wire gemv_fields_valid =
        (op != 8'h52) ||
        ((version == 8'd7) && (flags[7:1] == 7'd0) &&
         (flags[0] == bias_enable) && (aux0 == 32'd0) &&
         (src0_stride == 32'd0) && (src1_stride == 32'd0) &&
         (dst_stride == 32'd0) && (batch_count <= 16'd1) &&
         (head_count == 16'd0) && !gemv_range_error && !gemv_write_alias);

    assign descriptor_invalid = !op_valid || !dimensions_valid ||
                                !version_valid ||
                                ((op == 8'h36) && flags[5] &&
                                 !pack_tile_a_fields_valid) ||
                                (macro_child_fetch && is_macro) ||
                                alignment_error ||
                                (is_macro && (|src0[5:0])) ||
                                (is_fp_dot && !fp_dot_fields_valid) ||
                                !fused_matrix_fields_valid ||
                                !gemv_fields_valid;

endmodule
