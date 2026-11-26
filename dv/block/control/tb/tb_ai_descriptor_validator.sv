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
    reg queued_dma_allowed;
    integer qdma_checks;

    wire op_valid, is_macro, is_tensor_matrix, is_tensor_sfu;
    wire version_valid, dimensions_valid, alignment_error, descriptor_invalid;
    wire dec_valid, dec_int8, dec_banked, dec_matrix, dec_sfu, dec_cnn_kv;
    wire dec_macro, dec_bf16, dec_fp16;

    integer legal_opcode_checks;
    integer invalid_rule_checks;
    integer boundary_accept_checks;
    integer boundary_reject_checks;
    integer i;
    reg [7:0] supported_ops [0:28];

    ai_descriptor_validator validator (
        .op(op), .version(version), .src0(src0), .src1(src1), .dst(dst),
        .bias_base(bias_base), .length(length), .m_size(m_size),
        .n_size(n_size), .k_words(k_words), .bias_enable(bias_enable),
        .flags(flags), .scale_shift(scale_shift), .activation(activation),
        .aux0(aux0), .src0_stride(src0_stride), .src1_stride(src1_stride),
        .dst_stride(dst_stride), .batch_count(batch_count),
        .head_count(head_count), .macro_child_fetch(macro_child_fetch),
        .queued_dma_allowed(queued_dma_allowed),
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
            queued_dma_allowed = 1'b1;
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
                8'h52: begin m_size = 16'd1; n_size = 16'd1; k_words = 16'd1; end
                8'h53: begin m_size = 16'd4; n_size = 16'd4; k_words = 16'd1; end
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
            expected_matrix = (opcode == 8'h30) || (opcode == 8'h31) ||
                              (opcode == 8'h52) || (opcode == 8'h53);
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


    task automatic set_qdma_defaults(input reg two_d);
        begin
            set_legal_defaults(8'h60);
            src0 = 32'h0000_1000; src1 = 32'd0; dst = 32'h0000_0100;
            length = 16'd64; m_size = two_d ? 16'd16 : 16'd0;
            n_size = 16'd0; k_words = length; flags = two_d ? 8'h01 : 8'h00;
            src0_stride = two_d ? 32'd256 : 32'd0;
            dst_stride = two_d ? 32'd128 : 32'd0;
            src1_stride = 32'd0; batch_count = 16'd0; head_count = 16'd0;
            // Descriptor fetch decodes flags[0] as bias_enable as well.
            aux0 = 32'd0; bias_enable = two_d; bias_base = 32'd0;
            scale_shift = 5'd0; activation = 2'd0;
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

    task automatic check_boundary_accept(input reg [255:0] label_text);
        begin
            #1;
            if (!dimensions_valid || descriptor_invalid)
                $fatal(1, "validator rejected documented dimension boundary: %0s op=0x%02h dims=%b invalid=%b",
                       label_text, op, dimensions_valid, descriptor_invalid);
            boundary_accept_checks = boundary_accept_checks + 1;
        end
    endtask

    task automatic check_boundary_reject(input reg [255:0] label_text);
        begin
            #1;
            if (dimensions_valid || !descriptor_invalid)
                $fatal(1, "validator accepted dimension outside current rule: %0s op=0x%02h dims=%b invalid=%b",
                       label_text, op, dimensions_valid, descriptor_invalid);
            boundary_reject_checks = boundary_reject_checks + 1;
        end
    endtask

    initial begin
        legal_opcode_checks = 0;
        invalid_rule_checks = 0;
        boundary_accept_checks = 0;
        boundary_reject_checks = 0;
        supported_ops[0]=8'h10; supported_ops[1]=8'h11; supported_ops[2]=8'h12;
        supported_ops[3]=8'h13; supported_ops[4]=8'h14; supported_ops[5]=8'h15;
        supported_ops[6]=8'h16; supported_ops[7]=8'h17; supported_ops[8]=8'h20;
        supported_ops[9]=8'h21; supported_ops[10]=8'h30; supported_ops[11]=8'h31;
        supported_ops[12]=8'h32; supported_ops[13]=8'h33; supported_ops[14]=8'h34;
        supported_ops[15]=8'h35; supported_ops[16]=8'h36; supported_ops[17]=8'h37;
        supported_ops[18]=8'h38; supported_ops[19]=8'h39; supported_ops[20]=8'h40;
        supported_ops[21]=8'h41; supported_ops[22]=8'h42; supported_ops[23]=8'h43;
        supported_ops[24]=8'h44; supported_ops[25]=8'h50; supported_ops[26]=8'h51;
        supported_ops[27]=8'h52; supported_ops[28]=8'h53;

        for (i=0; i<29; i=i+1) check_legal(supported_ops[i]);

        // Opcode 0x60 DMA_COPY (CAP2[8]) is dispatcher-only: it is not a
        // compute-cluster opcode, so the launch decoder keeps op_valid=0.
        qdma_checks = 0;
        set_qdma_defaults(1'b0); #1;
        if (descriptor_invalid || dec_valid !== 1'b0)
            $fatal(1, "legal 1D DMA_COPY rejected or decoded as compute op");
        qdma_checks = qdma_checks + 1;
        set_qdma_defaults(1'b1); src1 = 32'h0000_0003; #1;   // 64-bit ext high word
        if (descriptor_invalid) $fatal(1, "legal 2D DMA_COPY store rejected");
        qdma_checks = qdma_checks + 1;
        set_qdma_defaults(1'b0); queued_dma_allowed = 1'b0; check_invalid("DMA_COPY on serial processor");
        set_qdma_defaults(1'b0); length = 16'd0; check_invalid("DMA_COPY zero length");
        set_qdma_defaults(1'b0); src0 = 32'h0000_1002; check_invalid("DMA_COPY unaligned ext");
        set_qdma_defaults(1'b0); dst = 32'h0000_0102; check_invalid("DMA_COPY unaligned spad");
        set_qdma_defaults(1'b0); src0_stride = 32'd64; check_invalid("DMA_COPY 1D stride");
        set_qdma_defaults(1'b1); bias_base = 32'h100; check_invalid("DMA_COPY reserved bias base");
        set_qdma_defaults(1'b1); dst_stride = 32'd66; check_invalid("DMA_COPY 2D unaligned stride");
        set_qdma_defaults(1'b0); flags = 8'h02; check_invalid("DMA_COPY reserved flag");
        set_qdma_defaults(1'b0); aux0 = 32'd1; check_invalid("DMA_COPY reserved aux0");
        set_qdma_defaults(1'b0); version = 8'd3; check_invalid("DMA_COPY version");
        set_qdma_defaults(1'b0); dst = 32'hffff_fff0; check_invalid("DMA_COPY spad wrap");
        qdma_checks = qdma_checks + 11;

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
        set_legal_defaults(8'h43); version=8'd6; length=16'd16;
        flags=8'h02; src0_stride=32'd16; src1_stride=32'd256;
        aux0={16'd2,16'd15};
        check_boundary_accept("KV QK-compatible append ABI v6 token 15");
        set_legal_defaults(8'h43); version=8'd6; length=16'd16;
        flags=8'h02; src0_stride=32'd16; src1_stride=32'd256;
        aux0={16'd0,16'd16};
        check_invalid("KV QK-compatible append token outside capacity");
        set_legal_defaults(8'h43); version=8'd5; length=16'd16;
        flags=8'h02; src0_stride=32'd16; src1_stride=32'd256;
        check_invalid("KV QK-compatible append requires ABI v6");
        set_legal_defaults(8'h44); version=8'd6; length=16'd16;
        flags=8'h02; check_invalid("KV read rejects QK append mode");
        set_legal_defaults(8'h43); version=8'd6; length=16'd16;
        flags=8'h02; src0_stride=32'd16; src1_stride=32'd250;
        check_invalid("KV QK-compatible append invalid head span");
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

        // Product opcode 0x52 writes a contiguous INT32 result. Reject
        // destination overlap with any still-live input span, while allowing
        // exactly adjacent half-open ranges.
        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd4; k_words=16'd17;
        dst=32'h0000_0120;
        check_boundary_accept("0x52 A/output adjacent spans");
        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd4; k_words=16'd17;
        dst=32'h0000_0110;
        check_invalid("0x52 output overlaps padded A span");
        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd1; k_words=16'd17;
        dst=32'h0000_0200;
        check_invalid("0x52 output overlaps dense B span");
        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd4; k_words=16'd1;
        bias_enable=1'b1; flags=8'h01; bias_base=32'h0000_0300;
        check_invalid("0x52 output overlaps enabled bias span");
        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd1; k_words=16'd2;
        src1=32'hffff_fff0;
        check_invalid("0x52 B span address overflow");

        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd64; k_words=16'd64;
        src0=32'h0000_1000; src1=32'h0000_2000; dst=32'h0000_4000;
        check_boundary_accept("0x52 single-descriptor 1x64x64 dense B span");
        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd256; k_words=16'd64;
        src0=32'h0000_1000; src1=32'h0000_2000; dst=32'h0000_8000;
        check_boundary_accept("0x52 maximum N tile span 1x256x64");
        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd18; k_words=16'd64;
        check_boundary_reject("0x52 wide N requires complete 16-column tiles");
        set_legal_defaults(8'h52); m_size=16'd1; n_size=16'd272; k_words=16'd64;
        check_boundary_reject("0x52 N above shared-array mapping limit");

        // Opcode 0x53 tile capture/consume bits are additive ABI-v7 fields;
        // old Matrix opcodes remain untouched.
        set_legal_defaults(8'h53); version=8'd7; m_size=16'd16; n_size=16'd16;
        k_words=16'd4; aux0=32'h20; check_boundary_accept("0x53 tile capture");
        set_legal_defaults(8'h53); version=8'd7; m_size=16'd16; n_size=16'd16;
        k_words=16'd4; aux0=32'h40; check_boundary_accept("0x53 tile consume");
        set_legal_defaults(8'h53); version=8'd7; m_size=16'd16; n_size=16'd16;
        k_words=16'd4; aux0=32'h60; check_boundary_accept("0x53 ping-pong capture/consume");
        set_legal_defaults(8'h30); m_size=16'd4; n_size=16'd4;
        k_words=16'd1; aux0=32'd1;
        check_boundary_accept("legacy 0x30 aux0 behavior remains accepted");
        set_legal_defaults(8'h53); version=8'd3; check_invalid("0x53 requires ABI v7");
        set_legal_defaults(8'h53); m_size=16'd16; n_size=16'd16;
        k_words=16'd4; aux0=32'h100; check_invalid("0x53 reserved aux bit8");
        set_legal_defaults(8'h53); m_size=16'd8; n_size=16'd16;
        k_words=16'd4; aux0=32'h20; check_invalid("0x53 tile capture shape");
        set_legal_defaults(8'h53); m_size=16'd16; n_size=16'd16;
        k_words=16'd3; aux0=32'h40; check_invalid("0x53 tile consume K");
        set_legal_defaults(8'h53); m_size=16'd16; n_size=16'd16;
        k_words=16'd4; flags=8'h02; aux0=32'h40;
        check_invalid("0x53 transposed tile consume");
        set_legal_defaults(8'h53); m_size=16'd16; n_size=16'd16;
        k_words=16'd4; aux0=32'h40; src0_stride=32'd16;
        check_invalid("0x53 tile consume source stride");
        set_legal_defaults(8'h53); m_size=16'd16; n_size=16'd16;
        k_words=16'd4; aux0=32'h20; dst_stride=32'd16;
        check_invalid("0x53 capture requires dense output");
        set_legal_defaults(8'h53); m_size=16'd16; n_size=16'd16;
        k_words=16'd4; aux0=32'h20; batch_count=16'd2;
        check_invalid("0x53 capture rejects multiple batches");

        // Full DeiT repack uses a 4x4 Matrix-A tiled source. Its physical
        // source span is M*N*4 bytes, not the dense M*N-byte tensor size.
        set_legal_defaults(8'h3b); version=8'd7; m_size=16'd208;
        n_size=16'd192; length=16'd197; src0=32'h0000_2000;
        src1=32'd0; k_words=16'd0; dst=32'h0003_0000; dst_stride=32'd208;
        check_boundary_accept("0x3b full 208x192 physical Matrix-A span");
        set_legal_defaults(8'h3b); version=8'd7; m_size=16'd208;
        n_size=16'd192; length=16'd197; src0=32'h0000_2000;
        src1=32'd0; k_words=16'd0; dst=32'h0000_d000; dst_stride=32'd208;
        check_invalid("0x3b rejects alias inside sparse physical source span");
        set_legal_defaults(8'h3b); version=8'd7; m_size=16'd208;
        n_size=16'd192; length=16'd197; src0=32'h0000_2000;
        src1=32'd0; k_words=16'd0; dst=32'h0003_0000; dst_stride=32'd208;
        aux0=32'h10;
        check_boundary_accept("0x3b accepts compact packed Matrix-A source span");
        set_legal_defaults(8'h3b); version=8'd7; m_size=16'd208;
        n_size=16'd192; length=16'd197; src0=32'h0000_2000;
        src1=32'd0; k_words=16'd0; dst=32'h0000_d000; dst_stride=32'd208;
        aux0=32'h10;
        check_boundary_accept("0x3b compact source allows destination beyond compact span");
        set_legal_defaults(8'h3b); version=8'd7; m_size=16'd208;
        n_size=16'd192; length=16'd197; src0=32'h0000_2000;
        src1=32'd0; k_words=16'd0; dst=32'h0000_6000; dst_stride=32'd208;
        aux0=32'h10;
        check_invalid("0x3b compact source rejects destination alias");
        set_legal_defaults(8'h3b); version=8'd7; m_size=16'd208;
        n_size=16'd192; length=16'd197; src0=32'h0000_2000;
        src1=32'd0; k_words=16'd0; dst=32'h0003_0000; dst_stride=32'd208;
        aux0=32'h20;
        check_invalid("0x3b rejects reserved aux0 bit 5");

        // Characterize validator dimension edges. These are validator-only
        // checks: accepting a 16-bit maximum does not claim that the selected
        // engine, address range, or complete memory image supports that size.
        set_legal_defaults(8'h10); length=16'd1; check_boundary_accept("VDOT minimum length 1");
        set_legal_defaults(8'h10); length=16'hffff; check_boundary_accept("VDOT maximum encoded length");
        set_legal_defaults(8'h11); m_size=16'd1; k_words=16'd1; check_boundary_accept("Scalar GEMV minimum M/K");
        set_legal_defaults(8'h11); m_size=16'hffff; k_words=16'hffff; check_boundary_accept("Scalar GEMV maximum encoded M/K");
        set_legal_defaults(8'h11); m_size=16'd0; check_boundary_reject("Scalar GEMV M below minimum");
        set_legal_defaults(8'h11); k_words=16'd0; check_boundary_reject("Scalar GEMV K below minimum");

        for (i=8'h12; i<=8'h15; i=i+1) begin
            set_legal_defaults(i[7:0]); m_size=16'd1; n_size=16'd1; k_words=16'd1;
            check_boundary_accept("Scalar GEMM minimum M/N/K");
            set_legal_defaults(i[7:0]); m_size=16'hffff; n_size=16'hffff; k_words=16'hffff;
            check_boundary_accept("Scalar GEMM maximum encoded M/N/K");
        end
        set_legal_defaults(8'h12); m_size=16'd0; check_boundary_reject("Scalar GEMM M below minimum");
        set_legal_defaults(8'h12); n_size=16'd0; check_boundary_reject("Scalar GEMM N below minimum");
        set_legal_defaults(8'h12); k_words=16'd0; check_boundary_reject("Scalar GEMM K below minimum");

        set_legal_defaults(8'h20); length=16'd1; check_boundary_accept("CNM VDOT minimum length 1");
        set_legal_defaults(8'h20); length=16'hffff; check_boundary_accept("CNM VDOT maximum encoded length");
        set_legal_defaults(8'h21); m_size=16'd1; length=16'd1; check_boundary_accept("CNM GEMV minimum M/length");
        set_legal_defaults(8'h21); m_size=16'hffff; length=16'hffff; check_boundary_accept("CNM GEMV maximum encoded M/length");
        set_legal_defaults(8'h21); m_size=16'd0; check_boundary_reject("CNM GEMV M below minimum");
        set_legal_defaults(8'h21); length=16'd0; check_boundary_reject("CNM GEMV length below minimum");

        for (i=8'h30; i<=8'h31; i=i+1) begin
            set_legal_defaults(i[7:0]); m_size=16'd4; n_size=16'd4; k_words=16'd1;
            check_boundary_accept("Matrix minimum aligned M/N and K");
            set_legal_defaults(i[7:0]); m_size=16'd65532; n_size=16'd65532; k_words=16'hffff;
            check_boundary_accept("Matrix maximum encoded aligned M/N and K");
            set_legal_defaults(i[7:0]); m_size=16'd3; check_boundary_reject("Matrix M below aligned minimum");
            set_legal_defaults(i[7:0]); n_size=16'd3; check_boundary_reject("Matrix N below aligned minimum");
            set_legal_defaults(i[7:0]); k_words=16'd0; check_boundary_reject("Matrix K below minimum");
        end

        set_legal_defaults(8'h32); length=16'd1; check_boundary_accept("SFU minimum length 1");
        set_legal_defaults(8'h32); length=16'hffff; check_boundary_accept("SFU maximum encoded length");
        set_legal_defaults(8'h35); length=16'd0; check_boundary_reject("SFU length below minimum");

        set_legal_defaults(8'h16); m_size=16'd3; n_size=16'd3; check_boundary_accept("Conv minimum 3x3 window");
        set_legal_defaults(8'h17); m_size=16'hffff; n_size=16'hffff; check_boundary_accept("Depthwise Conv maximum encoded shape");
        set_legal_defaults(8'h16); m_size=16'd2; check_boundary_reject("Conv height below minimum");
        set_legal_defaults(8'h17); n_size=16'd2; check_boundary_reject("Depthwise Conv width below minimum");

        for (i=8'h43; i<=8'h44; i=i+1) begin
            set_legal_defaults(i[7:0]); length=16'd1; check_boundary_accept("KV minimum length 1");
            set_legal_defaults(i[7:0]); length=16'hffff; check_boundary_accept("KV maximum encoded length");
            set_legal_defaults(i[7:0]); length=16'd0; check_boundary_reject("KV length below minimum");
        end

        for (i=8'h50; i<=8'h51; i=i+1) begin
            set_legal_defaults(i[7:0]); length=16'd1; check_boundary_accept("FP dot minimum length 1");
            set_legal_defaults(i[7:0]); length=16'hffff; check_boundary_accept("FP dot maximum encoded length");
            set_legal_defaults(i[7:0]); m_size=16'd0; check_boundary_reject("FP dot M outside fixed one-element descriptor");
        end

        set_legal_defaults(8'h40); length=16'd3; check_boundary_accept("Macro exact child count");
        set_legal_defaults(8'h40); length=16'd4; check_boundary_reject("Macro count above exact child count");
        for (i=8'h41; i<=8'h42; i=i+1) begin
            set_legal_defaults(i[7:0]); length=16'd3; check_boundary_accept("Macro minimum child count");
            set_legal_defaults(i[7:0]); length=16'd256; check_boundary_accept("Macro maximum child count");
            set_legal_defaults(i[7:0]); length=16'd2; check_boundary_reject("Macro child count below minimum");
            set_legal_defaults(i[7:0]); length=16'd257; check_boundary_reject("Macro child count above maximum");
        end

        set_legal_defaults(8'h36); m_size=16'd16; n_size=16'd16; length=16'd256; flags=8'h30;
        check_boundary_accept("Matrix A tile-pack aligned 16x16 exact length");
        set_legal_defaults(8'h36); m_size=16'd16; n_size=16'd16; length=16'd255; flags=8'h30;
        #1;
        if (!descriptor_invalid)
            $fatal(1, "Matrix A tile-pack accepted a non-matching M*N length");
        boundary_reject_checks = boundary_reject_checks + 1;

        if (legal_opcode_checks != 30 || invalid_rule_checks != 51 ||
            boundary_accept_checks != 49 || boundary_reject_checks != 28)
            $fatal(1, "testpoint count mismatch legal=%0d invalid=%0d boundary_accept=%0d boundary_reject=%0d expected=30/51/49/28",
                   legal_opcode_checks, invalid_rule_checks, boundary_accept_checks, boundary_reject_checks);
        $display("DESCRIPTOR_VALIDATOR_PASS legal_opcodes=29 queued_dma=%0d tile_pack=1 invalid_rules=51 boundary_accept=49/49 boundary_reject=28/28 tile_forward_accept=3/3 repack_physical_span=1 repack_compact_span=1 legacy_aux_compat=1 opcode_classes_consistent=1 engine_limit_claim=0", qdma_checks);
        $finish;
    end
endmodule
