`timescale 1ns/1ps

// DMA load-bandwidth sweep: production ai_axi128_dma against the AXI
// performance memory model.  The SPAD line port is ready every cycle unless
// +SPAD_READY_PCT=<n> throttles it (scheduler-arbiter contention).  Every
// loaded word is checked against the external pattern.  Reports effective
// bytes/cycle from start to done; GB/s figures assume the 250 MHz target.
module tb_dma_bandwidth;
    reg clk = 0, resetn = 0;
    always #2 clk = ~clk;
    reg start = 0;
    reg [63:0] ext_addr = 0;
    reg [31:0] spad_addr = 0;
    reg [15:0] length_words = 0;
    reg [2:0]  outstanding = 4;
    reg [31:0] latency = 50, beat_interval = 1, max_out = 8;
    wire busy, done, error;
    wire [3:0] error_code;
    wire sv, sw, lv, lw;
    wire [31:0] sa, sd, la;
    wire [127:0] ld;
    wire [15:0] lstrb;
    reg  spad_ready_r = 1;
    wire [3:0] arid, rid, awid, bid;
    wire arvalid, arready, rvalid, rready, rlast, awvalid, awready, wvalid, wready, wlast, bvalid, bready;
    wire [63:0] araddr, awaddr;
    wire [7:0] arlen, awlen;
    wire [2:0] arsize, awsize;
    wire [1:0] arburst, awburst, rresp, bresp;
    wire [127:0] rdata, wdata;
    wire [15:0] wstrb;

    `ifndef DMA_BURST
    `define DMA_BURST 16
    `endif
    ai_axi128_dma #(.MAX_OUTSTANDING(4), .MAX_BURST_BEATS(`DMA_BURST), .AXI_ADDR_WIDTH(64)) dut (
        .clk(clk), .resetn(resetn), .start(start), .abort(1'b0), .store(1'b0),
        .ext_addr(ext_addr), .spad_addr(spad_addr), .length_words(length_words),
        .row_words(16'd0), .row_count(16'd0), .ext_stride(32'd0), .spad_stride(32'd0),
        .gather_enable(1'b0), .gather_index_base(32'd0), .read_outstanding(outstanding),
        .expand_i4(1'b0),
        .busy(busy), .done(done), .error(error), .error_code(error_code),
        .spad_valid(sv), .spad_write(sw), .spad_addr_o(sa), .spad_wdata(sd),
        .spad_ready(spad_ready_r), .spad_rsp_valid(1'b0), .spad_rdata(32'd0),
        .spad_req_error(1'b0), .spad_rsp_error(1'b0),
        .spad_line_valid(lv), .spad_line_write(lw), .spad_line_addr(la),
        .spad_line_wdata(ld), .spad_line_wstrb(lstrb), .spad_line_ready(spad_ready_r),
        .spad_line_rsp_valid(1'b0), .spad_line_rdata(128'd0), .spad_line_req_error(1'b0),
        .spad_line_rsp_error(1'b0), .spad_line_parity_error(4'd0),
        .m_axi_arid(arid), .m_axi_arvalid(arvalid), .m_axi_araddr(araddr), .m_axi_arlen(arlen),
        .m_axi_arsize(arsize), .m_axi_arburst(arburst), .m_axi_arready(arready),
        .m_axi_rid(rid), .m_axi_rdata(rdata), .m_axi_rresp(rresp), .m_axi_rvalid(rvalid),
        .m_axi_rlast(rlast), .m_axi_rready(rready),
        .m_axi_awid(awid), .m_axi_awvalid(awvalid), .m_axi_awaddr(awaddr), .m_axi_awlen(awlen),
        .m_axi_awsize(awsize), .m_axi_awburst(awburst), .m_axi_awready(awready),
        .m_axi_wvalid(wvalid), .m_axi_wdata(wdata), .m_axi_wstrb(wstrb), .m_axi_wlast(wlast),
        .m_axi_wready(wready), .m_axi_bid(bid), .m_axi_bresp(bresp), .m_axi_bvalid(bvalid),
        .m_axi_bready(bready), .r_beat_bytes(), .w_beat_bytes());

    axi_perf_memory_model #(.WORDS(1 << 18)) mem (
        .clk(clk), .resetn(resetn), .latency(latency), .beat_interval(beat_interval),
        .max_outstanding(max_out), .arid(arid), .arvalid(arvalid), .araddr(araddr),
        .arlen(arlen), .arsize(arsize), .arready(arready), .rid(rid), .rdata(rdata),
        .rresp(rresp), .rvalid(rvalid), .rlast(rlast), .rready(rready), .awid(awid),
        .awvalid(awvalid), .awaddr(awaddr), .awlen(awlen), .awready(awready),
        .wvalid(wvalid), .wdata(wdata), .wlast(wlast), .wready(wready), .bid(bid),
        .bresp(bresp), .bvalid(bvalid), .bready(bready));

    // SPAD sink with optional throttling and data check.
    reg [31:0] lfsr = 32'h1ace_b00c;
    integer ready_pct = 100;
    integer words_seen = 0, bad = 0, i;
    always @(posedge clk) begin
        lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
        spad_ready_r <= (ready_pct >= 100) ? 1'b1 : ((lfsr[15:0] % 100) < ready_pct);
        if (lv && lw && spad_ready_r) begin
            for (i = 0; i < 4; i = i + 1)
                if (lstrb[i*4]) begin
                    words_seen = words_seen + 1;
                    if (ld[i*32 +: 32] !== (32'hc0de_0000 ^ ((la - spad_addr) / 4 + i)))
                        bad = bad + 1;
                end
        end
        if (sv && sw && spad_ready_r) begin
            words_seen = words_seen + 1;
            if (sd !== (32'hc0de_0000 ^ ((sa - spad_addr) / 4))) bad = bad + 1;
        end
    end

    integer lens [0:5];
    integer outs [0:2];
    integer lats [0:2];
    integer li, oi, ti, cyc, w;
    real bpc;
    initial begin
        lens[0] = 64; lens[1] = 256; lens[2] = 1024; lens[3] = 4096; lens[4] = 16384; lens[5] = 65520;
        outs[0] = 1; outs[1] = 2; outs[2] = 4;
        lats[0] = 25; lats[1] = 50; lats[2] = 100;
        void'($value$plusargs("SPAD_READY_PCT=%d", ready_pct));
        void'($value$plusargs("BEAT_INTERVAL=%d", beat_interval));
        for (w = 0; w < (1 << 18); w = w + 1) mem.mem[w] = 32'hc0de_0000 ^ w;
        repeat (4) @(negedge clk); resetn = 1; repeat (4) @(negedge clk);
        for (ti = 0; ti < 3; ti = ti + 1)
            for (oi = 0; oi < 3; oi = oi + 1)
                for (li = 0; li < 6; li = li + 1) begin
                    latency = lats[ti]; outstanding = outs[oi]; length_words = lens[li];
                    ext_addr = 0; spad_addr = 32'h0;
                    words_seen = 0; bad = 0;
                    @(negedge clk); start = 1; @(negedge clk); start = 0;
                    cyc = 1;
                    while (!done && cyc < 4000000) begin @(negedge clk); cyc = cyc + 1; end
                    if (!done || error) $fatal(1, "DMA failed len=%0d err=%0d", lens[li], error_code);
                    repeat (2) @(negedge clk);
                    if (words_seen != lens[li] || bad != 0)
                        $fatal(1, "DMA data check len=%0d seen=%0d bad=%0d", lens[li], words_seen, bad);
                    bpc = (lens[li] * 4.0) / cyc;
                    $display("DMA_BW latency=%0d outstanding=%0d bytes=%0d cycles=%0d bytes_per_cycle=%0.3f gbps_at_250mhz=%0.3f pct_of_peak=%0.1f beat_interval=%0d spad_ready_pct=%0d burst_beats=%0d",
                             latency, outstanding, lens[li] * 4, cyc, bpc, bpc * 0.25, bpc / 16.0 * 100.0,
                             beat_interval, ready_pct, `DMA_BURST);
                    repeat (4) @(negedge clk);
                end
        $display("DMA_BW_SWEEP_PASS");
        $finish;
    end
endmodule
