// Descriptor opcode classification for the software/RTL ABI.
//
// These values are part of the descriptor ABI and must remain aligned with
// ai_command_processor: INT8 0x10..0x17, banked 0x20/0x21, tensor matrix
// 0x30/0x31, tensor SFU 0x32..0x39, macro 0x40..0x42, and CNN/KV 0x43/0x44.
// op_valid is the union of those mutually exclusive opcode classes.
module ai_accel_opcode_decode (
    input  wire [7:0] op,
    output wire       op_valid,
    output wire       is_int8,
    output wire       is_banked,
    output wire       is_tensor_matrix,
    output wire       is_tensor_sfu,
    output wire       is_cnn_kv,
    output wire       is_macro,
    output wire       is_bf16_dot,
    output wire       is_fp16_dot
);

    assign is_int8         = (op >= 8'h10) && (op <= 8'h17);
    assign is_banked       = (op == 8'h20) || (op == 8'h21);
    assign is_tensor_matrix = (op == 8'h30) || (op == 8'h31);
    assign is_tensor_sfu   = (op >= 8'h32) && (op <= 8'h39);
    assign is_cnn_kv       = (op == 8'h43) || (op == 8'h44);
    assign is_macro        = (op >= 8'h40) && (op <= 8'h42);
    assign is_bf16_dot     = (op == 8'h50);
    assign is_fp16_dot     = (op == 8'h51);

    assign op_valid = is_int8 || is_banked || is_tensor_matrix ||
                      is_tensor_sfu || is_cnn_kv || is_macro ||
                      is_bf16_dot || is_fp16_dot;

endmodule
