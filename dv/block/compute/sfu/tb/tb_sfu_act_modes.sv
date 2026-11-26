`timescale 1ns/1ps

// Round 35 SFU flag[7] modes (LUT activation, rounded REQUANT) against the
// independent Python Golden, with randomized ready back-pressure and 1..4
// cycle multi-outstanding read latency (sfu_equiv_spad).  Also checks guard
// words after the output and that the legacy-only core and plain packed GELU
// return ERR_CONFIG.
module tb_sfu_act_modes;
    reg clk = 0, resetn = 0, start = 0;
    always #5 clk = ~clk;
    reg [7:0] op = 0;
    reg [31:0] src0 = 0, src1 = 0, dst = 0;
    reg [15:0] len = 0, m_size = 0, n_size = 0;
    reg [4:0] shift = 0;
    reg pack = 0, tile_a = 0, flag7 = 0;
    reg [1:0] dut_sel = 0;

    wire [1:0] sv, sw, sr, rv, pe, pp, busy, done, err;
    wire [31:0] sa [0:1];
    wire [31:0] sd [0:1];
    wire [31:0] rd [0:1];
    wire [3:0] code [0:1];
    wire [31:0] res [0:1];
    wire [31:0] cyc [0:1];
    wire [31:0] elems [0:1];
    genvar g;
    generate for (g = 0; g < 2; g = g + 1) begin : dut
        // g=1: production fast path; g=0: legacy-only (must reject flag[7]).
        ai_tensor_sfu_core #(.FAST_PATH_ENABLE_P(g)) core (
            .clk(clk), .resetn(resetn), .start(start && dut_sel == g), .abort(1'b0),
            .op_mode(op), .src0_base(src0), .src1_base(src1), .beta_base(32'd0),
            .beta_enable(1'b0), .pack_enable(pack), .pack_tile_a(tile_a), .act_flag(flag7),
            .input_tile_a(1'b0), .src0_stride(32'd0), .dst_base(dst), .length(len),
            .m_size(m_size), .n_size(n_size), .scale_shift(shift), .epsilon(32'd1),
            .watchdog_limit(32'd0), .spad_valid(sv[g]), .spad_write(sw[g]), .spad_addr(sa[g]),
            .spad_wdata(sd[g]), .spad_ready(sr[g]), .spad_rsp_valid(rv[g]), .spad_rdata(rd[g]),
            .spad_parity_error(pe[g]), .spad_protection_error(pp[g]),
            .busy(busy[g]), .done(done[g]), .error(err[g]), .error_code(code[g]),
            .result(res[g]), .cycle_count(cyc[g]), .element_count(elems[g]));
        sfu_equiv_spad #(.LFSR_SEED(32'h5eed_1234 + g)) mem (
            .clk(clk), .resetn(resetn), .spad_valid(sv[g]), .spad_write(sw[g]),
            .spad_addr(sa[g]), .spad_wdata(sd[g]), .spad_ready(sr[g]), .spad_rsp_valid(rv[g]),
            .spad_rdata(rd[g]), .spad_parity_error(pe[g]), .spad_protection_error(pp[g]),
            .inject_kind(2'd0), .inject_read(32'd0), .stall_enable(1'b1));
    end endgenerate

    integer fd, rc, cases, c, i, outw, inplace, t, bad, fails = 0, words_checked = 0;
    integer lut_cases = 0, round_cases = 0, packed_cases = 0, tile_cases = 0;
    reg [31:0] h [0:8];
    reg [31:0] v, expected [0:16383];
    reg [1023:0] path;

    task automatic run(input integer sel, output reg e, output reg [3:0] ec);
        begin
            dut_sel = sel;
            @(negedge clk); start = 1; @(negedge clk); start = 0;
            t = 0;
            while (!done[sel] && t < 2000000) begin @(negedge clk); t = t + 1; end
            if (!done[sel]) $fatal(1, "ACT timeout case=%0d", c);
            e = err[sel]; ec = code[sel];
            repeat (8) @(negedge clk);
        end
    endtask

    reg e; reg [3:0] ec;
    initial begin
        if (!$value$plusargs("VECTORS=%s", path)) $fatal(1, "missing +VECTORS");
        fd = $fopen(path, "r");
        rc = $fscanf(fd, "%d\n", cases);
        repeat (3) @(negedge clk); resetn = 1;
        for (c = 0; c < cases; c = c + 1) begin
            for (i = 0; i < 9; i = i + 1) rc = $fscanf(fd, "%h", h[i]);
            op = h[0]; len = h[1]; shift = h[2]; pack = h[3]; tile_a = h[4];
            m_size = h[5]; n_size = h[6]; inplace = h[7]; outw = h[8]; flag7 = 1;
            src0 = 32'h1000; src1 = 32'h4000; dst = inplace ? src0 : 32'h8000;
            for (i = 0; i < 16384; i = i + 1) dut[1].mem.memory[i] = 32'h7ead_0000 ^ i;
            for (i = 0; i < len; i = i + 1) begin
                rc = $fscanf(fd, "%h\n", v); dut[1].mem.memory[(src0 >> 2) + i] = v;
            end
            for (i = 0; i < 64; i = i + 1) begin
                rc = $fscanf(fd, "%h\n", v); dut[1].mem.memory[(src1 >> 2) + i] = v;
            end
            for (i = 0; i < outw; i = i + 1) rc = $fscanf(fd, "%h\n", expected[i]);
            run(1, e, ec);
            bad = 0;
            if (e) begin
                $display("ACT_FAIL case=%0d op=%02h len=%0d error code=%0d", c, op, len, ec);
                bad = 1;
            end
            for (i = 0; i < outw; i = i + 1) begin
                if (dut[1].mem.memory[(dst >> 2) + i] !== expected[i]) begin
                    if (bad < 4)
                        $display("ACT_MISMATCH case=%0d op=%02h len=%0d pack=%0d tile=%0d word=%0d exp=%08h got=%08h",
                                 c, op, len, pack, tile_a, i, expected[i], dut[1].mem.memory[(dst >> 2) + i]);
                    bad = bad + 1;
                end
                words_checked = words_checked + 1;
            end
            // guard: the four words after the output region are untouched
            if (!inplace)
                for (i = outw; i < outw + 4; i = i + 1)
                    if (dut[1].mem.memory[(dst >> 2) + i] !== (32'h7ead_0000 ^ ((dst >> 2) + i))) begin
                        $display("ACT_GUARD_FAIL case=%0d word=%0d", c, i); bad = bad + 1;
                    end
            if (elems[1] !== len) begin
                $display("ACT_ELEMENTS_FAIL case=%0d exp=%0d got=%0d", c, len, elems[1]); bad = bad + 1;
            end
            if (bad) fails = fails + 1;
            if (op == 8'h35) lut_cases = lut_cases + 1; else round_cases = round_cases + 1;
            if (pack && !tile_a) packed_cases = packed_cases + 1;
            if (tile_a) tile_cases = tile_cases + 1;
            // Legacy-only core must reject the flag[7] mode.
            if (c % 7 == 0) begin
                run(0, e, ec);
                if (!e || ec !== 4'd1) begin
                    $display("ACT_LEGACY_REJECT_FAIL case=%0d err=%0d code=%0d", c, e, ec); fails = fails + 1;
                end
            end
        end
        // Plain GELU (flag[7]=0) with packing is a configuration error.
        op = 8'h35; flag7 = 0; pack = 1; tile_a = 0; len = 8; src0 = 32'h1000; dst = 32'h8000;
        run(1, e, ec);
        if (!e || ec !== 4'd1) begin $display("ACT_PACKED_GELU_REJECT_FAIL err=%0d code=%0d", e, ec); fails = fails + 1; end
        if (fails) $fatal(1, "SFU_ACT_MODES_FAIL failures=%0d", fails);
        $display("SFU_ACT_MODES_PASS cases=%0d lut=%0d round=%0d linear_packed=%0d tile_packed=%0d words=%0d legacy_reject=1 packed_gelu_reject=1",
                 cases, lut_cases, round_cases, packed_cases, tile_cases, words_checked);
        $finish;
    end
endmodule
