`timescale 1ns/1ps

// Ordered scratchpad model: randomized ready back-pressure, any number of
// outstanding reads, in-order responses with 1..4 cycle latency (at most one
// response per cycle), optional parity/protection fault on the k-th read.
module sfu_equiv_spad #(parameter [31:0] LFSR_SEED = 32'h1ace_b00c) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        spad_valid,
    input  wire        spad_write,
    input  wire [31:0] spad_addr,
    input  wire [31:0] spad_wdata,
    output wire        spad_ready,
    output reg         spad_rsp_valid,
    output reg  [31:0] spad_rdata,
    output reg         spad_parity_error,
    output wire        spad_protection_error,
    input  wire [1:0]  inject_kind,      // 1 parity, 2 protection
    input  wire [31:0] inject_read,
    input  wire        stall_enable
);
    reg [31:0] memory [0:16383];
    reg [31:0] lfsr;
    reg [31:0] q_data [0:63];
    reg [31:0] q_time [0:63];
    reg        q_parity [0:63];
    reg [5:0]  q_head, q_tail;
    reg [31:0] now, last_time, read_index;
    assign spad_ready = !stall_enable || lfsr[0] || lfsr[3];
    wire accept_read = spad_valid && spad_ready && !spad_write;
    assign spad_protection_error = accept_read && inject_kind == 2'd2 &&
                                   read_index == inject_read;
    wire [31:0] latency = 32'd1 + (stall_enable ? {30'd0, lfsr[6:5]} : 32'd1);
    wire [31:0] due = (now + latency > last_time) ? now + latency : last_time + 32'd1;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            lfsr <= LFSR_SEED; q_head <= 0; q_tail <= 0; now <= 0; last_time <= 0;
            read_index <= 0; spad_rsp_valid <= 0; spad_rdata <= 0; spad_parity_error <= 0;
        end else begin
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            now <= now + 1;
            spad_rsp_valid <= 1'b0; spad_parity_error <= 1'b0;
            if (q_head != q_tail && q_time[q_head] <= now + 1) begin
                spad_rsp_valid <= 1'b1; spad_rdata <= q_data[q_head];
                spad_parity_error <= q_parity[q_head];
                q_head <= q_head + 1'b1;
            end
            if (spad_valid && spad_ready) begin
                if (spad_write) memory[spad_addr[15:2]] <= spad_wdata;
                else begin
                    q_data[q_tail] <= memory[spad_addr[15:2]];
                    q_parity[q_tail] <= (inject_kind == 2'd1) && (read_index == inject_read);
                    q_time[q_tail] <= due;
                    last_time <= due;
                    q_tail <= q_tail + 1'b1;
                    read_index <= read_index + 1;
                end
            end
        end
    end
endmodule

module tb_sfu_stream_equiv;
    reg clk = 0, resetn = 0, start = 0, abort = 0;
    always #5 clk = ~clk;
    reg [7:0]  op = 0;
    reg [31:0] src0 = 0, src1 = 0, beta = 0, dst = 0, eps = 1;
    reg        beta_en = 0, pack = 0, tile_a = 0;
    reg [15:0] len = 0, m_size = 0, n_size = 0;
    reg [4:0]  shift = 0;
    reg [1:0]  inj_kind = 0;
    reg [31:0] inj_read = 0;
    reg        stall_enable = 1;

    wire [1:0] sv, sw;
    wire [31:0] sa [0:1];
    wire [31:0] sd [0:1];
    wire [1:0] sr, rv, pe, pp;
    wire [31:0] rd [0:1];
    wire [1:0] busy, done, err;
    wire [3:0] code [0:1];
    wire [31:0] res [0:1];
    wire [31:0] cyc [0:1];
    wire [31:0] elems [0:1];

    genvar g;
    generate for (g = 0; g < 2; g = g + 1) begin : dut
        // g=0 legacy-only reference, g=1 fast path enabled.
        ai_tensor_sfu_core #(.FAST_PATH_ENABLE_P(g)) core (
            .clk(clk), .resetn(resetn), .start(start), .abort(abort), .op_mode(op),
            .src0_base(src0), .src1_base(src1), .beta_base(beta), .beta_enable(beta_en),
            .pack_enable(pack), .pack_tile_a(tile_a), .input_tile_a(1'b0),
            .src0_stride(32'd0), .dst_base(dst), .length(len), .m_size(m_size),
            .n_size(n_size), .scale_shift(shift), .epsilon(eps), .watchdog_limit(32'd0),
            .spad_valid(sv[g]), .spad_write(sw[g]), .spad_addr(sa[g]), .spad_wdata(sd[g]),
            .spad_ready(sr[g]), .spad_rsp_valid(rv[g]), .spad_rdata(rd[g]),
            .spad_parity_error(pe[g]), .spad_protection_error(pp[g]),
            .busy(busy[g]), .done(done[g]), .error(err[g]), .error_code(code[g]),
            .result(res[g]), .cycle_count(cyc[g]), .element_count(elems[g]));
        sfu_equiv_spad #(.LFSR_SEED(32'h1ace_b00c ^ (32'h9e37_79b9 * (g + 1)))) mem (
            .clk(clk), .resetn(resetn), .spad_valid(sv[g]), .spad_write(sw[g]),
            .spad_addr(sa[g]), .spad_wdata(sd[g]), .spad_ready(sr[g]),
            .spad_rsp_valid(rv[g]), .spad_rdata(rd[g]), .spad_parity_error(pe[g]),
            .spad_protection_error(pp[g]), .inject_kind(inj_kind), .inject_read(inj_read),
            .stall_enable(stall_enable));
    end endgenerate

    // valid/ready stability on the fast-path DUT: a stalled request must be
    // re-presented unchanged until accepted, except after the stream unit has
    // entered its error/abort drain (legacy FSM also withdraws on abort).
    reg        stall_d = 0;
    reg        stall_w_d = 0;
    reg [31:0] stall_a_d = 0, stall_wd_d = 0;
    integer    stability_checks = 0, stability_errors = 0;
    always @(posedge clk) begin
        if (resetn && stall_d && dut[1].core.stream_u.busy &&
            !dut[1].core.stream_u.error_pending_r && !abort) begin
            stability_checks = stability_checks + 1;
            if (!sv[1] || sw[1] !== stall_w_d || sa[1] !== stall_a_d ||
                (stall_w_d && sd[1] !== stall_wd_d)) begin
                stability_errors = stability_errors + 1;
                if (stability_errors < 5)
                    $display("EQUIV_STABILITY_FAIL t=%0t valid=%0d write=%0d/%0d addr=%08h/%08h",
                             $time, sv[1], sw[1], stall_w_d, sa[1], stall_a_d);
            end
        end
        stall_d <= sv[1] && !sr[1] && dut[1].core.stream_u.busy;
        stall_w_d <= sw[1]; stall_a_d <= sa[1]; stall_wd_d <= sd[1];
    end

    integer fd, rc, cases, c, i, w, t, mism, fails = 0, fault_cases = 0, fast_used = 0;
    integer ok_cases = 0, inj_at, fallback = 0;
    integer cyc_total [0:1];
    reg [31:0] h [0:14];
    reg [31:0] vx, vy, vb, poison;
    reg [1023:0] path;
    reg got_done [0:1];
    reg got_err [0:1];
    reg [3:0] got_code [0:1];
    reg [31:0] got_res [0:1];
    reg [31:0] got_elems [0:1];
    reg [31:0] got_cyc [0:1];

    initial begin
        if (!$value$plusargs("VECTORS=%s", path)) $fatal(1, "missing +VECTORS");
        if ($test$plusargs("NO_STALL")) stall_enable = 0;
        fd = $fopen(path, "r");
        rc = $fscanf(fd, "%d\n", cases);
        cyc_total[0] = 0; cyc_total[1] = 0;
        repeat (3) @(negedge clk);
        resetn = 1;
        for (c = 0; c < cases; c = c + 1) begin
            for (i = 0; i < 15; i = i + 1) rc = $fscanf(fd, "%h", h[i]);
            op = h[0]; len = h[1]; shift = h[2]; eps = h[3]; beta_en = h[4];
            pack = h[5]; tile_a = h[6]; m_size = h[7]; n_size = h[8];
            src0 = h[9] << 2; src1 = h[10] << 2; beta = h[11] << 2; dst = h[12] << 2;
            inj_kind = (h[13] == 1) ? 2'd1 : (h[13] == 2) ? 2'd2 : 2'd0;
            inj_at = h[14]; inj_read = h[14];
            // Identical pseudo-random background in both memories.
            poison = 32'h5eed_0000 ^ (c * 32'h0101_0101);
            for (w = 0; w < 16384; w = w + 1) begin
                dut[0].mem.memory[w] = poison ^ (w * 32'h9e37_79b9);
                dut[1].mem.memory[w] = poison ^ (w * 32'h9e37_79b9);
            end
            for (i = 0; i < len; i = i + 1) begin
                rc = $fscanf(fd, "%h %h %h\n", vx, vy, vb);
                dut[0].mem.memory[h[9] + i] = vx;  dut[1].mem.memory[h[9] + i] = vx;
                dut[0].mem.memory[32'h1400 + i] = vy; dut[1].mem.memory[32'h1400 + i] = vy;
                dut[0].mem.memory[h[11] + i] = vb; dut[1].mem.memory[h[11] + i] = vb;
            end
            got_done[0] = 0; got_done[1] = 0;
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            if (dut[1].core.last_stream_r) fast_used = fast_used + 1;
            else fallback = fallback + 1;
            t = 0;
            while (!(got_done[0] && got_done[1]) && t < 3000000) begin
                if (h[13] == 3 && t == 1) abort = 1; else abort = 0;
                @(posedge clk); #1;
                for (i = 0; i < 2; i = i + 1)
                    if (done[i] && !got_done[i]) begin
                        got_done[i] = 1; got_err[i] = err[i]; got_code[i] = code[i];
                        got_res[i] = res[i]; got_elems[i] = elems[i]; got_cyc[i] = cyc[i];
                    end
                @(negedge clk);
                t = t + 1;
            end
            abort = 0;
            if (!(got_done[0] && got_done[1])) $fatal(1, "EQUIV timeout case=%0d op=%02h len=%0d", c, op, len);
            // Let late responses of an errored command drain from the models.
            repeat (8) @(negedge clk);
            mism = 0;
            if (h[13] != 0) begin
                fault_cases = fault_cases + 1;
                if (got_err[0] !== got_err[1] || (got_err[0] && got_code[0] !== got_code[1])) mism = 1;
                if (busy !== 2'b00) mism = 1;
            end else begin
                if (got_err[0] !== got_err[1] || got_code[0] !== got_code[1] ||
                    (!got_err[0] && (got_res[0] !== got_res[1] || got_elems[0] !== got_elems[1])))
                    mism = 1;
                for (w = 0; w < 16384; w = w + 1)
                    if (dut[0].mem.memory[w] !== dut[1].mem.memory[w]) begin
                        if (mism < 4)
                            $display("EQUIV_MEM_DIFF case=%0d op=%02h len=%0d word=%04h legacy=%08h fast=%08h",
                                     c, op, len, w, dut[0].mem.memory[w], dut[1].mem.memory[w]);
                        mism = mism + 1;
                    end
                cyc_total[0] = cyc_total[0] + got_cyc[0];
                cyc_total[1] = cyc_total[1] + got_cyc[1];
            end
            if (mism) begin
                fails = fails + 1;
                $display("EQUIV_FAIL case=%0d op=%02h len=%0d pack=%0d tile_a=%0d beta=%0d src1=%0h dst=%0h inj=%0d err=%0d/%0d code=%0d/%0d res=%08h/%08h elems=%0d/%0d",
                         c, op, len, pack, tile_a, beta_en, src1, dst, h[13], got_err[0], got_err[1],
                         got_code[0], got_code[1], got_res[0], got_res[1], got_elems[0], got_elems[1]);
            end else ok_cases = ok_cases + 1;
        end
        if (stability_errors != 0)
            $fatal(1, "SFU_STREAM_EQUIV_FAIL valid_ready_stability_errors=%0d", stability_errors);
        if (fails != 0) $fatal(1, "SFU_STREAM_EQUIV_FAIL failures=%0d", fails);
        $display("SFU_STREAM_EQUIV_PASS cases=%0d fault_cases=%0d fast_path_cases=%0d legacy_fallback_cases=%0d legacy_cycles=%0d fast_cycles=%0d stall=%0d stability_checks=%0d",
                 cases, fault_cases, fast_used, fallback, cyc_total[0], cyc_total[1], stall_enable,
                 stability_checks);
        $finish;
    end
endmodule
