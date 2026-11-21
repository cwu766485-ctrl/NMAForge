`timescale 1ns/1ps

module tb_axi_desc_fetch_repack;
    reg clk = 0;
    always #5 clk = ~clk;

    reg resetn = 0;
    reg start = 0;
    reg [63:0] desc_base = 64'h1000;
    wire [3:0] arid;
    wire arvalid;
    wire [63:0] araddr;
    wire [7:0] arlen;
    wire [2:0] arsize;
    wire [1:0] arburst;
    reg arready = 0;
    reg [3:0] rid = 0;
    reg [127:0] rdata = 0;
    reg [1:0] rresp = 0;
    reg rvalid = 0;
    reg rlast = 0;
    wire rready;
    wire busy, done, error;
    wire [7:0] desc_op;
    wire [15:0] desc_task_id, length, m_size, n_size, k_words;
    wire [31:0] src0, src1, dst, bias_base, aux0;
    wire [4:0] scale_shift;
    wire [1:0] activation;
    wire bias_enable;
    wire [7:0] flags;
    wire [31:0] src0_stride, src1_stride, dst_stride;
    wire [15:0] batch_count, head_count, wait_mask, signal_mask, clear_mask;
    wire [7:0] version;

    reg [31:0] words [0:15];
    integer beat;
    integer i;

    axi_desc_fetch #(.AXI_ADDR_WIDTH(64)) dut (
        .clk(clk), .resetn(resetn), .start(start), .desc_base(desc_base),
        .m_axi_arid(arid), .m_axi_arvalid(arvalid), .m_axi_araddr(araddr),
        .m_axi_arlen(arlen), .m_axi_arsize(arsize), .m_axi_arburst(arburst),
        .m_axi_arready(arready), .m_axi_rid(rid), .m_axi_rdata(rdata),
        .m_axi_rresp(rresp), .m_axi_rvalid(rvalid), .m_axi_rlast(rlast),
        .m_axi_rready(rready), .busy(busy), .done(done), .error(error),
        .desc_op(desc_op), .desc_task_id(desc_task_id),
        .desc_src0_base(src0), .desc_src1_base(src1), .desc_dst_base(dst),
        .desc_length(length), .desc_m_size(m_size), .desc_n_size(n_size),
        .desc_k_words(k_words), .desc_scale_shift(scale_shift),
        .desc_activation(activation), .desc_bias_base(bias_base),
        .desc_bias_enable(bias_enable), .desc_flags(flags), .desc_aux0(aux0),
        .desc_src0_stride(src0_stride), .desc_src1_stride(src1_stride),
        .desc_dst_stride(dst_stride), .desc_batch_count(batch_count),
        .desc_head_count(head_count), .desc_wait_mask(wait_mask),
        .desc_signal_mask(signal_mask), .desc_clear_mask(clear_mask),
        .desc_version(version)
    );

    task automatic run_descriptor(input [7:0] op, input [15:0] extent);
        begin
            for (i = 0; i < 16; i = i + 1) words[i] = 0;
            words[0] = {16'h29a0, 8'h00, op};
            words[1] = 32'h0000_1000;
            words[4] = 32'h0000_5000;
            words[5] = {16'd48, 16'd16};
            words[6] = {16'd0, extent};
            words[8] = 0;
            words[12] = 16;
            words[15] = 7;

            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            wait (arvalid);
            if (araddr !== desc_base || arlen !== 3 || arsize !== 4 || arid !== 0)
                $fatal(1, "descriptor AXI request contract mismatch");
            @(negedge clk); arready = 1;
            @(negedge clk); arready = 0;

            for (beat = 0; beat < 4; beat = beat + 1) begin
                @(negedge clk);
                rdata = {words[beat*4+3], words[beat*4+2],
                         words[beat*4+1], words[beat*4]};
                rvalid = 1;
                rlast = (beat == 3);
                @(negedge clk);
                rvalid = 0;
                rlast = 0;
            end
            wait (done);
            #1;
            if (error || desc_op !== op || length !== extent)
                $fatal(1, "descriptor fetch fields mismatch op=%02x err=%0d length=%0d",
                       desc_op, error, length);
            if (op == 8'h3b && k_words !== 0)
                $fatal(1, "0x3b must decode extent as length only, k_words=%0d", k_words);
            if (op == 8'h30 && k_words !== extent)
                $fatal(1, "legacy GEMM K decode changed: k_words=%0d expected=%0d",
                       k_words, extent);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        resetn = 1;
        run_descriptor(8'h3b, 16'd13);
        $display("AXI_DESC_REPACK_EXTENT_PASS opcode=0x3b length=%0d k_words=%0d",
                 length, k_words);
        run_descriptor(8'h30, 16'd4);
        $display("AXI_DESC_LEGACY_GEMM_EXTENT_PASS opcode=0x30 length=%0d k_words=%0d",
                 length, k_words);
        $display("AXI_DESC_FETCH_REPACK_TEST_PASS");
        $finish;
    end
endmodule
