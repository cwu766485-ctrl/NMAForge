`timescale 1ns/1ps

module tb_ai_descriptor_validator;
    reg [7:0] op;
    reg [7:0] version;
    reg [31:0] src0, src1, dst, bias_base;
    reg [15:0] length, m_size, n_size, k_words;
    reg bias_enable;
    reg [7:0] flags;
    reg [4:0] scale_shift;
    reg [1:0] activation;
    reg [31:0] aux0, src0_stride, src1_stride, dst_stride;
    reg [15:0] batch_count, head_count;
    reg macro_child_fetch;

    wire op_valid, is_macro, is_tensor_matrix, is_tensor_sfu;
    wire version_valid, dimensions_valid, alignment_error, descriptor_invalid;
    wire dec_valid, dec_int8, dec_banked, dec_matrix, dec_sfu, dec_cnn_kv;
    wire dec_macro, dec_bf16, dec_fp16;

    integer legal_opcode_checks;
    integer invalid_rule_checks;
    integer i;
    reg [7:0] supported_ops [0:26];

    ai_descriptor_validator validator (
        .op(op), .version(version), .src0(src0), .src1(src1), .dst(dst),
        .bias_base(bias_base), .length(length), .m_size(m_size),
        .n_size(n_size), .k_words(k_words), .bias_enable(bias_enable),
        .flags(flags), .scale_shift(scale_shift), .activation(activation),
        .aux0(aux0), .src0_stride(src0_stride), .src1_stride(src1_stride),
        .dst_stride(dst_stride), .batch_count(batch_count),
        .head_count(head_count), .macro_child_fetch(macro_child_fetch),
        .op_valid(op_valid), .is_macro(is_macro),
        .is_tensor_matrix(is_tensor_matrix), .is_tensor_sfu(is_tensor_sfu),
        .version_valid(version_valid), .dimensions_valid(dimensions_valid),
        .alignment_error(alignment_error), .descriptor_invalid(descriptor_invalid)
    );

    ai_accel_opcode_decode opcode_decode (
        .op(op), .op_valid(dec_valid), .is_int8(dec_int8),
        .is_banked(dec_banked), .is_tensor_matrix(dec_matrix),
        .is_tensor_sfu(dec_sfu), .is_cnn_kv(dec_cnn_kv),
        .is_macro(dec_macro), .is_bf16_dot(dec_bf16), .is_fp16_dot(dec_fp16)
    );

    task automatic set_legal_defaults(input reg [7:0] opcode);
        begin
            op = opcode;
            version = 8'd7;
            src0 = 32'h0000_0100;
            src1 = 32'h0000_0200;
            dst = 32'h0000_0300;
            bias_base = 32'd0;
            length = 16'd1;
            m_size = 16'd1;
            n_size = 16'd1;
            k_words = 16'd1;
            bias_enable = 1'b0;
            flags = 8'd0;
            scale_shift = 5'd0;
            activation = 2'd0;
            aux0 = 32'd0;
            src0_stride = 32'd0;
            src1_stride = 32'd0;
            dst_stride = 32'd0;
            batch_count = 16'd0;
            head_count = 16'd0;
            macro_child_fetch = 1'b0;
            case (opcode)
                8'h16, 8'h17, 8'h43, 8'h44: version = 8'd5;
                8'h40, 8'h41, 8'h42: begin version = 8'd4; length = 16'd3; src0 = 32'h0000_0140; end
                default: begin end
            endcase
            case (opcode)
                8'h11: begin m_size = 16'd1; k_words = 16'd1; end
                8'h12, 8'h13, 8'h14, 8'h15: begin
                    m_size = 16'd1; n_size = 16'd1; k_words = 16'd1;
                end
                8'h16, 8'h17: begin m_size = 16'd3; n_size = 16'd3; end
                8'h21: begin m_size = 16'd1; length = 16'd1; end
                8'h30, 8'h31: begin m_size = 16'd4; n_size = 16'd4; k_words = 16'd1; end
                8'h50, 8'h51: begin m_size = 16'd1; n_size = 16'd1; length = 16'd1; end
                default: begin end
            endcase
        end
    endtask

    task automatic check_legal(input reg [7:0] opcode);
        reg expected_int8, expected_banked, expected_matrix, expected_sfu;
        reg expected_cnn_kv, expected_macro, expected_bf16, expected_fp16;
        begin
            set_legal_defaults(opcode);
            #1;
            expected_int8 = (opcode >= 8'h10) && (opcode <= 8'h17);
            expected_banked = (opcode == 8'h20) || (opcode == 8'h21);
            expected_matrix = (opcode == 8'h30) || (opcode == 8'h31);
            expected_sfu = (opcode >= 8'h32) && (opcode <= 8'h39);
            expected_cnn_kv = (opcode == 8'h43) || (opcode == 8'h44);
            expected_macro = (opcode >= 8'h40) && (opcode <= 8'h42);
            expected_bf16 = (opcode == 8'h50);
            expected_fp16 = (opcode == 8'h51);
            if (!op_valid || !version_valid || !dimensions_valid || alignment_error || descriptor_invalid)
                $fatal(1, "legal opcode rejected: op=0x%02h op_valid=%b version=%b dims=%b align=%b invalid=%b", opcode, op_valid, version_valid, dimensions_valid, alignment_error, descriptor_invalid);
            if (dec_valid !== 1'b1 || dec_int8 !== expected_int8 || dec_banked !== expected_banked ||
                dec_matrix !== expected_matrix || dec_sfu !== expected_sfu || dec_cnn_kv !== expected_cnn_kv ||
                dec_macro !== expected_macro || dec_bf16 !== expected_bf16 || dec_fp16 !== expected_fp16 ||
                is_macro !== expected_macro || is_tensor_matrix !== expected_matrix || is_tensor_sfu !== expected_sfu)
                $fatal(1, "opcode decoder class mismatch: op=0x%02h", opcode);
            legal_opcode_checks = legal_opcode_checks + 1;
        end
    endtask

    task automatic check_invalid(input reg [255:0] label_text);
        begin
            #1;
            if (!descriptor_invalid)
                $fatal(1, "invalid descriptor accepted: %0s op=0x%02h", label_text, op);
            invalid_rule_checks = invalid_rule_checks + 1;
        end
    endtask

    initial begin
        legal_opcode_checks = 0;
        invalid_rule_checks = 0;
        supported_ops[0]=8'h10; supported_ops[1]=8'h11; supported_ops[2]=8'h12;
        supported_ops[3]=8'h13; supported_ops[4]=8'h14; supported_ops[5]=8'h15;
        supported_ops[6]=8'h16; supported_ops[7]=8'h17; supported_ops[8]=8'h20;
        supported_ops[9]=8'h21; supported_ops[10]=8'h30; supported_ops[11]=8'h31;
        supported_ops[12]=8'h32; supported_ops[13]=8'h33; supported_ops[14]=8'h34;
        supported_ops[15]=8'h35; supported_ops[16]=8'h36; supported_ops[17]=8'h37;
        supported_ops[18]=8'h38; supported_ops[19]=8'h39; supported_ops[20]=8'h40;
        supported_ops[21]=8'h41; supported_ops[22]=8'h42; supported_ops[23]=8'h43;
        supported_ops[24]=8'h44; supported_ops[25]=8'h50; supported_ops[26]=8'h51;

        for (i=0; i<27; i=i+1) check_legal(supported_ops[i]);

        // The descriptor-only Matrix A tile packing mode has an additional
        // exact M*N==length contract beyond the ordinary SFU length rule.
        set_legal_defaults(8'h36);
        version = 8'd7; m_size = 16'd4; n_size = 16'd4;
        length = 16'd16; flags = 8'h30;
        #1;
        if (descriptor_invalid) $fatal(1, "legal Matrix A tile-pack descriptor rejected");
        legal_opcode_checks = legal_opcode_checks + 1;

        set_legal_defaults(8'hff); check_invalid("unsupported opcode");
        set_legal_defaults(8'h10); length=16'd0; check_invalid("VDOT zero length");
        set_legal_defaults(8'h11); m_size=16'd0; check_invalid("GEMV zero M");
        set_legal_defaults(8'h12); n_size=16'd0; check_invalid("GEMM zero N");
        set_legal_defaults(8'h20); length=16'd0; check_invalid("CNM VDOT zero length");
        set_legal_defaults(8'h21); length=16'd0; check_invalid("CNM GEMV zero length");
        set_legal_defaults(8'h30); m_size=16'd2; check_invalid("Matrix M not multiple of four");
        set_legal_defaults(8'h35); length=16'd0; check_invalid("SFU zero length");
        set_legal_defaults(8'h16); m_size=16'd2; check_invalid("Conv H below minimum");
        set_legal_defaults(8'h43); length=16'd0; check_invalid("KV zero length");
        set_legal_defaults(8'h50); version=8'd6; check_invalid("FP ABI version");
        set_legal_defaults(8'h40); length=16'd2; check_invalid("macro minimum child count");

        set_legal_defaults(8'h36); version=8'd7; m_size=16'd4; n_size=16'd4;
        length=16'd15; flags=8'h30; check_invalid("Matrix A tile-pack element count");
        set_legal_defaults(8'h50); src0=src0+32'd2; check_invalid("FP source alignment");
        set_legal_defaults(8'h50); src1=src1+32'd2; check_invalid("FP second source alignment");
        set_legal_defaults(8'h50); dst=dst+32'd2; check_invalid("FP destination alignment");
        set_legal_defaults(8'h10); bias_enable=1'b1; bias_base=32'h0000_0102; check_invalid("bias alignment");
        set_legal_defaults(8'h40); src0=src0+32'd4; check_invalid("macro 64-byte child-list alignment");
        set_legal_defaults(8'h40); macro_child_fetch=1'b1; check_invalid("nested macro child");
        set_legal_defaults(8'h50); src0_stride=32'd4; check_invalid("FP stride unsupported");
        set_legal_defaults(8'h51); flags=8'h02; check_invalid("FP transpose flags unsupported");

        if (legal_opcode_checks != 28 || invalid_rule_checks != 21)
            $fatal(1, "testpoint count mismatch legal=%0d invalid=%0d expected=28/21", legal_opcode_checks, invalid_rule_checks);
        $display("DESCRIPTOR_VALIDATOR_PASS legal_opcodes=27 tile_pack=1 invalid_rules=21 opcode_classes_consistent=1");
        $finish;
    end
endmodule
