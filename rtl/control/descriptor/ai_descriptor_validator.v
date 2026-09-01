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
                      is_macro;

    assign is_tensor_matrix = (op == 8'h30) || (op == 8'h31);
    assign is_tensor_sfu = (op >= 8'h32) && (op <= 8'h39);

    assign version_valid = (version == 8'd7) ? 1'b1 :
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
                              (is_tensor_matrix && m_size != 0 &&
                               n_size != 0 && k_words != 0 &&
                               m_size[1:0] == 0 && n_size[1:0] == 0) ||
                              (is_tensor_sfu && length != 0) ||
                              ((op == 8'h16 || op == 8'h17) &&
                               m_size >= 16'd3 && n_size >= 16'd3) ||
                              ((op == 8'h43 || op == 8'h44) && length != 0) ||
                              (op == 8'h40 && length == 16'd3) ||
                              ((op == 8'h41 || op == 8'h42) &&
                               length >= 16'd3 && length <= 16'd256);

    assign alignment_error = (|src0[1:0]) || (|src1[1:0]) ||
                             (|dst[1:0]) ||
                             (bias_enable && (|bias_base[1:0]));

    assign descriptor_invalid = !op_valid || !dimensions_valid ||
                                !version_valid ||
                                (macro_child_fetch && is_macro) ||
                                alignment_error ||
                                (is_macro && (|src0[5:0]));

endmodule
