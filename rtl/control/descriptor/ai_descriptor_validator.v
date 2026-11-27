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
    // 1 only for the parallel CMDQ dispatcher, which owns the queued DMA
    // engine. The serial command processor rejects opcode 0x60.
    input  wire        queued_dma_allowed,

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
                      ((op >= 8'h30) && (op <= 8'h3b)) ||
                      ((op >= 8'h43) && (op <= 8'h44)) ||
                      is_macro || (op == 8'h50) || (op == 8'h51) ||
                      (op == 8'h52) || (op == 8'h53) || (op == 8'h60);

    assign is_tensor_matrix = (op == 8'h30) || (op == 8'h31) ||
                              (op == 8'h52) ||
                              (op == 8'h53);
    assign is_tensor_sfu = (op >= 8'h32) && (op <= 8'h3b);
    wire is_bf16_dot = (op == 8'h50);
    wire is_fp16_dot = (op == 8'h51);
    wire is_fp_dot = is_bf16_dot || is_fp16_dot;
    wire is_queued_dma = (op == 8'h60);
    wire [31:0] pack_tile_a_elements = {16'd0,m_size} * {16'd0,n_size};
    // Round 35: GELU flag[7] selects the LUT activation, which may pack like
    // REQUANT; packing on plain GELU is rejected.
    wire pack_tile_a_fields_valid =
        ((op == 8'h36) || ((op == 8'h35) && flags[7])) && flags[4] &&
        (m_size != 0) && (n_size != 0) &&
        (m_size[1:0] == 0) && (n_size[1:0] == 0) &&
        (pack_tile_a_elements == {16'd0,length});
    // Optional ABI-v7.4 LayerNorm bridge for the official DeiT-Tiny
    // 208x192 Matrix-A packed embedding. In this mode src0_stride is the
    // zero-based logical token row (not a byte stride); only valid rows
    // 0..196 may be selected. Other LayerNorm descriptors keep the legacy
    // contiguous INT32 input contract.
    wire ln_tile_a_fields_valid =
        (op == 8'h38) && (version == 8'd7) && (flags[7] == 1'b0) &&
        (flags[5:1] == 5'd0) && (flags[0] == bias_enable) && bias_enable &&
        (length == 16'd192) && (m_size == 16'd208) &&
        (n_size == 16'd192) && (src0_stride < 32'd197) &&
        (src1 != 32'd0) && (bias_base != 32'd0) &&
        (aux0 == 32'd1) && (scale_shift == 5'd0) &&
        (activation == 2'd0) && (src1_stride == 32'd0) &&
        (dst_stride == 32'd0) && (batch_count == 16'd1) &&
        (head_count == 16'd1);

    assign version_valid = (version == 8'd7) ||
                           (is_macro && (version == 8'd4)) ||
                           ((op == 8'h43) &&
                            (((version == 8'd5) && (flags != 8'h02)) ||
                             ((version == 8'd6) && (flags == 8'h02)))) ||
                           (((op == 8'h16) || (op == 8'h17) ||
                             (op == 8'h44)) && (version == 8'd5)) ||
                           ((is_tensor_matrix || is_tensor_sfu) &&
                            (version == 8'd3)) ||
                           !(is_fp_dot || is_macro || is_tensor_matrix ||
                             is_tensor_sfu || (op == 8'h16) ||
                             (op == 8'h17) || (op == 8'h43) ||
                             (op == 8'h44));

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
                               (n_size >= 16'd1) && (n_size <= 16'd256) &&
                               ((n_size <= 16'd16) ||
                                (n_size[3:0] == 4'd0)) &&
                               (k_words != 16'd0)) ||
                              ((is_tensor_sfu && op != 8'h3a && op != 8'h3b) && length != 0) ||
                              (op == 8'h3a && length != 0 &&
                               length[1:0] == 2'b00 && flags[4]) ||
                              (op == 8'h3b && length != 0 &&
                               m_size >= 16 && m_size <= 256 &&
                               n_size >= 48 && n_size <= 384) ||
                              ((op == 8'h16 || op == 8'h17) &&
                               m_size >= 16'd3 && n_size >= 16'd3) ||
                              ((op == 8'h43 || op == 8'h44) && length != 0) ||
                              (is_fp_dot && length != 0 &&
                               m_size == 16'd1 && n_size == 16'd1) ||
                              (is_queued_dma && length != 0) ||
                              (op == 8'h40 && length == 16'd3) ||
                              ((op == 8'h41 || op == 8'h42) &&
                               length >= 16'd3 && length <= 16'd256);

    // For an ABI-v7 macro parent, src1 is the high word of the 64-bit child
    // list pointer {src1,src0}. Check alignment on the complete address via
    // src0's low bits; src1 is not an independently aligned data pointer.
    wire macro_v7_uses_64b_child_base = is_macro && (version == 8'd7);
    // Queued DMA also carries a 64-bit external address in {src1,src0}.
    assign alignment_error = (|src0[1:0]) ||
                             ((|src1[1:0]) && !macro_v7_uses_64b_child_base &&
                              !is_queued_dma) ||
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

    wire [31:0] kv_flag02_capacity =
        (length != 0) ? (src1_stride / length) : 32'd0;
    wire kv_flag02_fields_valid =
        (op == 8'h43) && (version == 8'd6) &&
        (length >= 16'd4) && (length <= 16'd16) &&
        (length[1:0] == 2'b00) && (src0_stride == 32'd16) &&
        (src1_stride != 0) && ((src1_stride % length) == 0) &&
        (kv_flag02_capacity >= 4) && (kv_flag02_capacity <= 16) &&
        ((kv_flag02_capacity & 32'd3) == 0) &&
        ({16'd0,aux0[15:0]} < kv_flag02_capacity) &&
        (dst_stride == 0);
    wire kv_fields_valid =
        !((op == 8'h43) || (op == 8'h44)) ||
        ((op == 8'h43) ?
         ((flags == 8'd0) ||
          (flags == 8'h01) ||
          ((flags == 8'h02) && kv_flag02_fields_valid)) :
         (flags == 8'd0));

    wire [15:0] repack_head_dim = n_size / 16'd3;
    // Legacy 0x3b sources use the sparse INT32 Matrix-A word footprint
    // (1 KiB per 16x16 tile). 0x53 packed INT8 writeback instead stores each
    // Matrix-A tile compactly (256 bytes per 16x16 tile); aux0[4] selects
    // that physical source layout. Use the selected physical span for range
    // and alias checks so compact sources are not over/under-described.
    wire [31:0] repack_src_elements =
        {16'd0,m_size} * {16'd0,n_size};
    wire [31:0] repack_src_bytes = aux0[4] ? repack_src_elements :
        (repack_src_elements << 2);
    wire [31:0] repack_dst_bytes =
        (aux0[1:0] == 2'd2) ?
        (({16'd0,repack_head_dim} / 16) *
         ((({16'd0,m_size} * 16) + 4095) & 32'hffff_f000)) :
        ({16'd0,m_size} * {16'd0,repack_head_dim});
    wire [32:0] repack_src_end = {1'b0,src0} + {1'b0,repack_src_bytes};
    wire [32:0] repack_dst_end = {1'b0,dst} + {1'b0,repack_dst_bytes};
    wire repack_range_error =
        repack_src_end[32] || repack_dst_end[32];
    wire repack_alias_error =
        ({1'b0,dst} < repack_src_end) && ({1'b0,src0} < repack_dst_end);
    wire repack_fields_valid =
        (op != 8'h3b) ||
        ((version == 8'd7) && (flags == 0) && (bias_base == 0) &&
         !bias_enable && (scale_shift == 0) && (activation == 0) &&
         (aux0[31:5] == 0) && (aux0[1:0] <= 2) && (aux0[3:2] <= 2) &&
         (length != 0) && (length <= m_size) &&
         (m_size >= 16) && (m_size <= 256) && (m_size[3:0] == 0) &&
         (n_size >= 48) && (n_size <= 384) && (n_size % 16'd48 == 0) &&
         (k_words == 0) && (src1 == 0) && (src0_stride == 0) &&
         (src1_stride == 0) && (dst_stride == {16'd0,m_size}) &&
         (batch_count == 0) && (head_count == 0) &&
         !repack_range_error && !repack_alias_error);

    // Product GEMV descriptor field gate. Shape support is bounded by the
    // shared 16x16 Matrix array; unsupported strides, batching, and flags are
    // rejected before dispatch rather than silently ignored.
    // Opcode 0x52 consumes dense A rows padded to a 16-byte K stride, dense
    // B rows padded to a 16-byte N stride, and a contiguous INT32 output. Keep these byte-span
    // calculations in the validator so an in-place destination cannot
    // overwrite operands that later row/K tiles still need to read.
    wire [31:0] gemv_a_bytes =
        ((({16'd0,k_words} + 32'd15) & 32'hffff_fff0) * {16'd0,m_size});
    wire [31:0] gemv_b_row_stride =
        ({16'd0,n_size} + 32'd15) & 32'hffff_fff0;
    wire [31:0] gemv_b_bytes = {16'd0,k_words} * gemv_b_row_stride;
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

    // Opcode 0x60 DMA_COPY (CAP2[8]): {src1,src0} external address, dst SPAD
    // address, length words per row, m_size rows (0 = 1D), src0_stride and
    // dst_stride row strides (2D only), flags[0] store. Word 6 also decodes
    // as k_words (it mirrors length) and flags[0] also decodes as
    // bias_enable. Every other field is reserved and must be zero. 2D strides must be word aligned and a 2D
    // store may not use the gather path (the payload DMA has none).
    wire [31:0] qdma_words = (m_size == 16'd0) ? {16'd0,length} :
                             ({16'd0,length} * {16'd0,m_size});
    // flags[1] (CAP2[10]) expands INT4 super-blocks on load: 1D only,
    // 256-byte source, 16-byte SPAD, length a multiple of 64 source words;
    // the SPAD span is length/64 super-blocks of 480 bytes.
    wire qdma_expand = flags[1];
    wire qdma_expand_ok = !qdma_expand ||
        (!flags[0] && (m_size == 16'd0) && (src0[7:0] == 8'd0) &&
         (length[5:0] == 6'd0) && (dst[3:0] == 4'd0));
    wire [32:0] qdma_spad_last =
        {1'b0,dst} +
        (qdma_expand ? ({23'd0,length[15:6]} * 33'd480) :
         (m_size == 16'd0) ? ({1'b0,qdma_words} << 2) :
         ({17'd0,m_size - 16'd1} * {1'b0,dst_stride}) +
         ({17'd0,length} << 2));
    wire qdma_fields_valid =
        !is_queued_dma ||
        ((version == 8'd7) && (flags[7:2] == 6'd0) && qdma_expand_ok &&
         (bias_enable == flags[0]) &&
         (bias_base == 32'd0) && (n_size == 16'd0) &&
         (scale_shift == 5'd0) && (activation == 2'd0) && (aux0 == 32'd0) &&
         (src1_stride == 32'd0) && (batch_count == 16'd0) &&
         (head_count == 16'd0) &&
         ((m_size == 16'd0) ? ((src0_stride == 32'd0) && (dst_stride == 32'd0)) :
          ((src0_stride[1:0] == 2'd0) && (dst_stride[1:0] == 2'd0))) &&
         !qdma_spad_last[32] && queued_dma_allowed);

    // Round 38 GEMM accumulate epilogue: flags[7] on 0x30/0x31 makes the
    // matrix core read-add-write the destination (16-byte aligned rows).
    // flags[7] stays reserved on the other matrix opcodes.
    wire gemm_acc_fields_valid =
        !(flags[7] && ((op == 8'h52) || (op == 8'h53))) &&
        !(flags[7] && ((op == 8'h30) || (op == 8'h31)) &&
          ((|dst[3:0]) || ((batch_count > 16'd1) && (|dst_stride[3:0]))));

    assign descriptor_invalid = !op_valid || !dimensions_valid ||
                                !version_valid ||
                                (flags[6] && !ln_tile_a_fields_valid) ||
                                (((op == 8'h36) || (op == 8'h35)) && flags[5] &&
                                 !pack_tile_a_fields_valid) ||
                                ((op == 8'h35) && flags[4] && !flags[7]) ||
                                ((op == 8'h3a) &&
                                 (flags[7:5] != 0 || flags[4] != 1'b1)) ||
                                (macro_child_fetch && is_macro) ||
                                alignment_error ||
                                (is_macro && (|src0[5:0])) ||
                                (is_fp_dot && !fp_dot_fields_valid) ||
                                !fused_matrix_fields_valid ||
                                !repack_fields_valid ||
                                !kv_fields_valid ||
                                !gemv_fields_valid ||
                                !qdma_fields_valid ||
                                !gemm_acc_fields_valid;

endmodule
