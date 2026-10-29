`timescale 1ns / 1ps

module tb_shape_adaptive_gemv;
    localparam integer MAX_M = 16;
    localparam integer MAX_N = 16;
    localparam integer MAX_K = 128;
    localparam integer A_WIDTH = MAX_M*MAX_K*8;
    localparam integer B_WIDTH = MAX_K*MAX_N*8;
    localparam integer R_WIDTH = MAX_M*MAX_N*64;

    localparam [1:0] MODE_BASELINE = 2'd0;
    localparam [1:0] MODE_GEMV = 2'd1;
    localparam [1:0] MODE_STATIC = 2'd2;

    reg clk = 0;
    reg resetn = 0;
    reg start = 0;
    reg abort = 0;
    reg [1:0] mode_request = MODE_BASELINE;
    reg prefetch_enable = 1;
    reg [4:0] m_size = 0;
    reg [4:0] n_size = 0;
    reg [7:0] k_size = 0;
    reg [A_WIDTH-1:0] a_operand = 0;
    reg [B_WIDTH-1:0] b_operand = 0;

    wire base_busy, base_done, base_error, base_selected_gemv;
    wire [4:0] base_k_parallel;
    wire [31:0] base_cycles, base_useful_macs;
    wire [R_WIDTH-1:0] base_results;
    wire gemv_busy, gemv_done, gemv_error, gemv_selected_gemv;
    wire [4:0] gemv_k_parallel;
    wire [31:0] gemv_cycles, gemv_useful_macs;
    wire [R_WIDTH-1:0] gemv_results;

    integer seed;
    integer failures = 0;
    integer case_count = 0;
    integer golden [0:MAX_M-1][0:MAX_N-1];
    integer m, n, k, i, j, value, expected_cycles, fold_k;
    integer expected_auto;
    integer base_load, gemv_load, base_tiles, gemv_tiles;
    integer base_cost, gemv_cost, overlap;

    always #5 clk = ~clk;

    ai_shape_adaptive_gemv #(
        .MAX_M(MAX_M), .MAX_N(MAX_N), .MAX_K(MAX_K), .MAC_COUNT(256)
    ) u_baseline (
        .clk(clk), .resetn(resetn), .start(start), .abort(abort),
        .mode_request(mode_request), .prefetch_enable(prefetch_enable),
        .m_size(m_size), .n_size(n_size), .k_size(k_size),
        .a_operand(a_operand), .b_operand(b_operand),
        .busy(base_busy), .done(base_done), .error(base_error),
        .selected_gemv(base_selected_gemv),
        .selected_k_parallel(base_k_parallel), .cycle_count(base_cycles),
        .useful_mac_count(base_useful_macs), .result_vector(base_results)
    );

    ai_shape_adaptive_gemv #(
        .MAX_M(MAX_M), .MAX_N(MAX_N), .MAX_K(MAX_K), .MAC_COUNT(256)
    ) u_adaptive (
        .clk(clk), .resetn(resetn), .start(start), .abort(abort),
        .mode_request(mode_request), .prefetch_enable(prefetch_enable),
        .m_size(m_size), .n_size(n_size), .k_size(k_size),
        .a_operand(a_operand), .b_operand(b_operand),
        .busy(gemv_busy), .done(gemv_done), .error(gemv_error),
        .selected_gemv(gemv_selected_gemv),
        .selected_k_parallel(gemv_k_parallel), .cycle_count(gemv_cycles),
        .useful_mac_count(gemv_useful_macs), .result_vector(gemv_results)
    );

    task build_operands;
        input integer rows;
        input integer cols;
        input integer depth;
        input integer run_seed;
        integer rr, cc, kk, mix;
        integer signed av, bv;
        begin
            a_operand = {A_WIDTH{1'b0}};
            b_operand = {B_WIDTH{1'b0}};
            for (rr = 0; rr < MAX_M; rr = rr + 1)
                for (cc = 0; cc < MAX_N; cc = cc + 1)
                    golden[rr][cc] = 0;
            for (rr = 0; rr < rows; rr = rr + 1) begin
                for (kk = 0; kk < depth; kk = kk + 1) begin
                    mix = (run_seed*17 + rr*13 + kk*7 + 5) % 29;
                    av = mix - 14;
                    a_operand[(rr*MAX_K+kk)*8 +: 8] = av[7:0];
                end
            end
            for (kk = 0; kk < depth; kk = kk + 1) begin
                for (cc = 0; cc < cols; cc = cc + 1) begin
                    mix = (run_seed*11 + kk*19 + cc*3 + 9) % 31;
                    bv = mix - 15;
                    b_operand[(kk*MAX_N+cc)*8 +: 8] = bv[7:0];
                end
            end
            for (rr = 0; rr < rows; rr = rr + 1) begin
                for (cc = 0; cc < cols; cc = cc + 1) begin
                    for (kk = 0; kk < depth; kk = kk + 1) begin
                        av = $signed(a_operand[(rr*MAX_K+kk)*8 +: 8]);
                        bv = $signed(b_operand[(kk*MAX_N+cc)*8 +: 8]);
                        golden[rr][cc] = golden[rr][cc] + av*bv;
                    end
                end
            end
        end
    endtask

    task check_results;
        input integer adaptive;
        input integer rows;
        input integer cols;
        integer rr, cc, observed;
        begin
            for (rr = 0; rr < MAX_M; rr = rr + 1) begin
                for (cc = 0; cc < MAX_N; cc = cc + 1) begin
                    if (adaptive)
                        observed = $signed(gemv_results[(rr*MAX_N+cc)*64 +: 64]);
                    else
                        observed = $signed(base_results[(rr*MAX_N+cc)*64 +: 64]);
                    if (rr < rows && cc < cols) begin
                        if (observed !== golden[rr][cc]) begin
                            $display("ERROR: result mode=%0d M=%0d N=%0d K=%0d row=%0d col=%0d got=%0d expected=%0d",
                                     adaptive, rows, cols, k_size, rr, cc,
                                     observed, golden[rr][cc]);
                            failures = failures + 1;
                        end
                    end else if (observed !== 0) begin
                        $display("ERROR: nonzero masked output mode=%0d M=%0d N=%0d row=%0d col=%0d got=%0d",
                                 adaptive, rows, cols, rr, cc, observed);
                        failures = failures + 1;
                    end
                end
            end
        end
    endtask

    task launch_and_check;
        input [1:0] requested_mode;
        input integer adaptive;
        input integer expected_gemv;
        input integer rows;
        input integer cols;
        input integer depth;
        integer got_cycles;
        integer got_macs;
        integer got_selected;
        integer got_fold;
        begin
            mode_request = requested_mode;
            @(negedge clk);
            start = 1;
            @(negedge clk);
            start = 0;
            if (adaptive) begin
                wait(gemv_done === 1'b1);
                @(negedge clk);
                got_cycles = gemv_cycles;
                got_macs = gemv_useful_macs;
                got_selected = gemv_selected_gemv;
                got_fold = gemv_k_parallel;
                if (gemv_error) begin
                    $display("ERROR: adaptive RTL reported error M=%0d N=%0d K=%0d",
                             rows, cols, depth);
                    failures = failures + 1;
                end
            end else begin
                wait(base_done === 1'b1);
                @(negedge clk);
                got_cycles = base_cycles;
                got_macs = base_useful_macs;
                got_selected = base_selected_gemv;
                got_fold = base_k_parallel;
                if (base_error) begin
                    $display("ERROR: baseline RTL reported error M=%0d N=%0d K=%0d",
                             rows, cols, depth);
                    failures = failures + 1;
                end
            end
            check_results(adaptive, rows, cols);
            if (adaptive && expected_gemv) begin
                fold_k = 16 / rows;
                expected_cycles = 2 * ((depth + fold_k - 1) / fold_k);
            end else begin
                expected_cycles = depth;
            end
            fold_k = 16 / rows;
            if (got_cycles !== expected_cycles || got_macs !== rows*cols*depth ||
                got_selected !== expected_gemv || got_fold !== ((rows == 0) ? 1 : (16/rows))) begin
                $display("ERROR: counters mode=%0d M=%0d N=%0d K=%0d cycles=%0d/%0d macs=%0d/%0d selected=%0d/%0d fold=%0d",
                         requested_mode, rows, cols, depth, got_cycles,
                         expected_cycles, got_macs, rows*cols*depth,
                         got_selected, expected_gemv, got_fold);
                failures = failures + 1;
            end
            if (requested_mode != MODE_STATIC)
                $display("CASE_PASS,seed=%0d,m=%0d,n=%0d,k=%0d,mode=%0d,gemv=%0d,cycles=%0d,macs=%0d,fold=%0d",
                         seed, rows, cols, depth, requested_mode,
                         got_selected, got_cycles, got_macs, got_fold);
            else
                $display("STATIC_PASS,seed=%0d,m=%0d,n=%0d,k=%0d,selected_gemv=%0d,cycles=%0d",
                         seed, rows, cols, depth, got_selected, got_cycles);
        end
    endtask

    task run_case;
        input integer rows;
        input integer cols;
        input integer depth;
        input integer run_seed;
        integer fold_local;
        begin
            m_size = rows;
            n_size = cols;
            k_size = depth;
            build_operands(rows, cols, depth, run_seed);
            fold_local = 16 / rows;
            launch_and_check(MODE_BASELINE, 0, 0, rows, cols, depth);
            launch_and_check(MODE_GEMV, 1, 1, rows, cols, depth);

            // Exercise the static shape-aware policy using the same operands.
            base_load = (rows + cols + 31) / 32;
            if (base_load < 1) base_load = 1;
            base_tiles = depth;
            base_cost = base_load + base_tiles +
                        (base_tiles - 1) * ((base_load > 1) ? (base_load - 1) : 0);
            gemv_load = (fold_local*(rows+cols) + 31) / 32;
            if (gemv_load < 1) gemv_load = 1;
            gemv_tiles = (depth + fold_local - 1) / fold_local;
            overlap = (gemv_load > 2) ? (gemv_load - 2) : 0;
            gemv_cost = gemv_load + 2*gemv_tiles + (gemv_tiles - 1)*overlap;
            expected_auto = 0;
            if (rows < 16 && depth >= 2*fold_local && cols >= 8 &&
                gemv_cost < base_cost)
                expected_auto = 1;
            launch_and_check(MODE_STATIC, 1, expected_auto, rows, cols, depth);
            case_count = case_count + 1;
        end
    endtask

    task check_abort_reset;
        begin
            m_size = 1;
            n_size = 16;
            k_size = 64;
            build_operands(1, 16, 64, seed+77);
            mode_request = MODE_BASELINE;
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            wait(base_busy === 1'b1);
            repeat (2) @(negedge clk);
            abort = 1;
            @(negedge clk); abort = 0;
            if (base_busy || !base_done || !base_error) begin
                $display("ERROR: abort disposition busy=%0d done=%0d error=%0d",
                         base_busy, base_done, base_error);
                failures = failures + 1;
            end
            resetn = 0;
            repeat (2) @(negedge clk);
            resetn = 1;
            repeat (2) @(negedge clk);
            if (base_busy || gemv_busy || base_error || gemv_error) begin
                $display("ERROR: reset did not clear v2 research state");
                failures = failures + 1;
            end
            $display("ABORT_RESET_PASS,seed=%0d", seed);
        end
    endtask

    task check_bad_config;
        begin
            m_size = 0;
            n_size = 16;
            k_size = 8;
            mode_request = MODE_BASELINE;
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            wait(base_done === 1'b1);
            @(negedge clk);
            if (base_busy || !base_error) begin
                $display("ERROR: zero-M descriptor was not rejected");
                failures = failures + 1;
            end
            $display("BAD_CONFIG_PASS,seed=%0d", seed);
        end
    endtask

    initial begin
        if (!$value$plusargs("SEED=%d", seed))
            seed = 20261025;
        repeat (3) @(negedge clk);
        resetn = 1;
        repeat (2) @(negedge clk);

        run_case(1, 8, 17, seed);
        run_case(1, 13, 64, seed+1);
        run_case(1, 16, 64, seed+2);
        run_case(4, 8, 17, seed+3);
        run_case(4, 13, 64, seed+4);
        run_case(4, 16, 64, seed+5);
        run_case(8, 8, 17, seed+6);
        run_case(8, 13, 64, seed+7);
        run_case(8, 16, 64, seed+8);
        run_case(16, 8, 17, seed+9);
        run_case(16, 13, 64, seed+10);
        run_case(16, 16, 64, seed+11);
        check_abort_reset();
        check_bad_config();

        if (failures != 0)
            $fatal(1, "SHAPE_ADAPTIVE_FAIL seed=%0d failures=%0d", seed, failures);
        $display("SHAPE_ADAPTIVE_PASS seed=%0d cases=%0d", seed, case_count);
        $finish;
    end
endmodule
