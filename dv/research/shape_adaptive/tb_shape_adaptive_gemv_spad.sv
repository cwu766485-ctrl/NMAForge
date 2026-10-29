`timescale 1ns / 1ps

module tb_shape_adaptive_gemv_spad;
    localparam [1:0] MODE_GEMV = 2'd1;
    localparam [31:0] A_BASE = 32'h0000_0100;
    localparam [31:0] B_BASE = 32'h0000_2000;
    localparam [31:0] R_BASE = 32'h0000_4000;
    localparam [31:0] DMA_BASE = 32'h0000_5000;
    localparam [31:0] SENTINEL = 32'h5a5a_a5a5;

    reg clk = 0;
    reg resetn = 0;
    reg host_valid = 0, host_write = 0;
    reg [31:0] host_addr = 0, host_wdata = 0;
    reg [3:0] host_wstrb = 4'hf;
    wire [31:0] host_rdata;
    wire host_error;
    reg start = 0, abort = 0;
    reg [1:0] mode_request = MODE_GEMV;
    reg prefetch_enable = 1;
    reg [4:0] m_size = 0, n_size = 0;
    reg [7:0] k_size = 0;
    reg [31:0] a_base = A_BASE, b_base = B_BASE, result_base = R_BASE;
    reg contender_valid = 0, contender_write = 0;
    reg [31:0] contender_addr = DMA_BASE, contender_wdata = 0;
    wire contender_ready, contender_rsp_valid, contender_rsp_error;
    wire [31:0] contender_rsp_rdata;
    wire busy, done, error, selected_gemv;
    wire [4:0] selected_k_parallel;
    wire [31:0] elapsed_cycles, spad_read_bytes, spad_write_bytes;
    wire [31:0] arbiter_wait_cycles;

    integer seed = 1;
    integer failures = 0;
    integer passed_shapes = 0;
    integer dma_accepted = 0;
    integer dma_responses = 0;
    integer dma_pattern = 0;
    integer dma_active = 0;
    integer signed golden [0:15][0:15];
    integer signed av, bv;
    integer rr, cc, kk, wi, count, timeout_count, index;
    integer rows, cols, depth, run_seed, same_bank;
    integer expected_reads, expected_writes, prefix_words;
    integer baseline_cycles, adaptive_cycles, baseline_waits, adaptive_waits;
    integer dma_before, expected_static_gemv;
    reg [31:0] readback;

    always #5 clk = ~clk;

    ai_shape_adaptive_gemv_spad #(
        .MAX_M(16), .MAX_N(16), .MAX_K(128), .SPAD_WORDS_PER_BANK(4096)
    ) dut (
        .clk(clk), .resetn(resetn),
        .host_valid(host_valid), .host_write(host_write),
        .host_addr(host_addr), .host_wdata(host_wdata),
        .host_wstrb(host_wstrb), .host_rdata(host_rdata),
        .host_error(host_error), .start(start), .abort(abort),
        .mode_request(mode_request), .prefetch_enable(prefetch_enable),
        .m_size(m_size), .n_size(n_size), .k_size(k_size),
        .a_base(a_base), .b_base(b_base), .result_base(result_base),
        .contender_valid(contender_valid), .contender_write(contender_write),
        .contender_addr(contender_addr), .contender_wdata(contender_wdata),
        .contender_ready(contender_ready),
        .contender_rsp_valid(contender_rsp_valid),
        .contender_rsp_rdata(contender_rsp_rdata),
        .contender_rsp_error(contender_rsp_error),
        .busy(busy), .done(done), .error(error),
        .selected_gemv(selected_gemv),
        .selected_k_parallel(selected_k_parallel),
        .elapsed_cycles(elapsed_cycles), .spad_read_bytes(spad_read_bytes),
        .spad_write_bytes(spad_write_bytes),
        .arbiter_wait_cycles(arbiter_wait_cycles)
    );

    always @(posedge clk) begin
        if (resetn && dma_active && contender_valid && contender_ready)
            dma_accepted <= dma_accepted + 1;
        if (resetn && contender_rsp_valid)
            dma_responses <= dma_responses + 1;
    end

    always @(negedge clk) begin
        if (dma_active) begin
            contender_valid = 1;
            contender_write = 0;
            if (dma_pattern == 0)
                contender_addr = DMA_BASE + ((dma_accepted & 31) << 4); // bank 0
            else
                contender_addr = DMA_BASE + ((dma_accepted & 31) << 2); // rotate banks
        end else begin
            contender_valid = 0;
        end
    end

    function integer signed operand_a;
        input integer row;
        input integer depth_index;
        input integer local_seed;
        integer x;
        begin
            x = (local_seed*17 + row*13 + depth_index*7 + 5) % 29;
            operand_a = x - 14;
        end
    endfunction

    function integer signed operand_b;
        input integer depth_index;
        input integer col;
        input integer local_seed;
        integer x;
        begin
            x = (local_seed*11 + depth_index*19 + col*3 + 9) % 31;
            operand_b = x - 15;
        end
    endfunction

    function integer static_selects_gemv;
        input integer local_rows;
        input integer local_cols;
        input integer local_depth;
        integer fold, base_load, gemv_load, gemv_tiles;
        integer base_cost, gemv_cost, overlap;
        begin
            fold = 16 / local_rows;
            base_load = (local_rows + local_cols + 31) / 32;
            if (base_load < 1) base_load = 1;
            base_cost = base_load + local_depth +
                        (local_depth-1)*((base_load > 1) ? base_load-1 : 0);
            gemv_load = (fold*(local_rows+local_cols)+31) / 32;
            if (gemv_load < 1) gemv_load = 1;
            gemv_tiles = (local_depth + fold - 1) / fold;
            overlap = (gemv_load > 2) ? gemv_load-2 : 0;
            gemv_cost = gemv_load + 2*gemv_tiles +
                        (gemv_tiles-1)*overlap;
            static_selects_gemv = (local_rows < 16 &&
                                   local_depth >= 2*fold &&
                                   local_cols >= 8 && gemv_cost < base_cost);
        end
    endfunction

    task host_write_word;
        input [31:0] address;
        input [31:0] value;
        begin
            @(negedge clk);
            host_valid = 1;
            host_write = 1;
            host_addr = address;
            host_wdata = value;
            @(posedge clk);
            #1;
            if (host_error) begin
                $display("ERROR: host write rejected addr=%08x", address);
                failures = failures + 1;
            end
            @(negedge clk);
            host_valid = 0;
            host_write = 0;
        end
    endtask

    task host_read_word;
        input [31:0] address;
        output [31:0] value;
        begin
            @(negedge clk);
            host_valid = 1;
            host_write = 0;
            host_addr = address;
            @(negedge clk);
            host_valid = 0;
            repeat (2) @(negedge clk);
            value = host_rdata;
            if (host_error) begin
                $display("ERROR: host read rejected addr=%08x", address);
                failures = failures + 1;
            end
        end
    endtask

    task initialize_problem;
        input integer local_rows;
        input integer local_cols;
        input integer local_depth;
        input integer local_seed;
        integer byte_index, word_index, byte_lane, data_word;
        begin
            rows = local_rows;
            cols = local_cols;
            depth = local_depth;
            run_seed = local_seed;
            for (rr = 0; rr < 16; rr = rr + 1)
                for (cc = 0; cc < 16; cc = cc + 1)
                    golden[rr][cc] = 0;
            for (rr = 0; rr < rows; rr = rr + 1)
                for (kk = 0; kk < depth; kk = kk + 1)
                    for (cc = 0; cc < cols; cc = cc + 1)
                        golden[rr][cc] = golden[rr][cc] +
                                         operand_a(rr,kk,run_seed) *
                                         operand_b(kk,cc,run_seed);

            for (word_index = 0; word_index < ((rows*depth+3)/4); word_index = word_index + 1) begin
                data_word = 0;
                for (byte_lane = 0; byte_lane < 4; byte_lane = byte_lane + 1) begin
                    byte_index = word_index*4 + byte_lane;
                    if (byte_index < rows*depth) begin
                        rr = byte_index / depth;
                        kk = byte_index % depth;
                        data_word = data_word |
                            ((operand_a(rr,kk,run_seed) & 255) << (byte_lane*8));
                    end
                end
                host_write_word(A_BASE + word_index*4, data_word);
            end
            for (word_index = 0; word_index < ((depth*cols+3)/4); word_index = word_index + 1) begin
                data_word = 0;
                for (byte_lane = 0; byte_lane < 4; byte_lane = byte_lane + 1) begin
                    byte_index = word_index*4 + byte_lane;
                    if (byte_index < depth*cols) begin
                        kk = byte_index / cols;
                        cc = byte_index % cols;
                        data_word = data_word |
                            ((operand_b(kk,cc,run_seed) & 255) << (byte_lane*8));
                    end
                end
                host_write_word(B_BASE + word_index*4, data_word);
            end
            for (word_index = 0; word_index < rows*cols*2; word_index = word_index + 1)
                host_write_word(R_BASE + word_index*4, SENTINEL);
        end
    endtask

    task launch_until_done;
        input integer timeout_limit;
        begin
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            timeout_count = 0;
            while (!done && timeout_count < timeout_limit) begin
                @(posedge clk); #1;
                timeout_count = timeout_count + 1;
            end
            if (!done) begin
                $display("ERROR: timeout state=%0d busy=%0d", dut.state_r, busy);
                failures = failures + 1;
            end
            @(negedge clk);
        end
    endtask

    task check_image;
        input integer check_prefix_words;
        input integer expect_full_result;
        integer output_index, value_index, row_index, col_index;
        integer expected_word;
        reg [31:0] observed;
        begin
            for (output_index = 0; output_index < rows*cols*2; output_index = output_index + 1) begin
                host_read_word(R_BASE + output_index*4, observed);
                if (expect_full_result || output_index < check_prefix_words) begin
                    value_index = output_index / 2;
                    row_index = value_index / cols;
                    col_index = value_index % cols;
                    expected_word = (output_index & 1) ?
                        ((golden[row_index][col_index] < 0) ? -1 : 0) :
                        golden[row_index][col_index];
                    if (observed !== expected_word[31:0]) begin
                        $display("ERROR: memory image word=%0d got=%08x expected=%08x",
                                 output_index, observed, expected_word);
                        failures = failures + 1;
                    end
                end else if (observed !== SENTINEL) begin
                    $display("ERROR: abort/reset wrote beyond prefix word=%0d got=%08x",
                             output_index, observed);
                    failures = failures + 1;
                end
            end
        end
    endtask

    task run_shape;
        input integer local_rows;
        input integer local_cols;
        input integer local_depth;
        input integer local_seed;
        input integer local_dma_pattern;
        begin
            initialize_problem(local_rows,local_cols,local_depth,local_seed);
            m_size = local_rows;
            n_size = local_cols;
            k_size = local_depth;
            dma_pattern = local_dma_pattern;
            mode_request = 2'd0;
            dma_before = dma_accepted;
            dma_active = 1;
            launch_until_done(50000);
            dma_active = 0;
            contender_valid = 0;
            expected_reads = ((local_rows*local_depth+3)/4)*4 +
                             ((local_depth*local_cols+3)/4)*4;
            expected_writes = local_rows*local_cols*8;
            baseline_cycles = elapsed_cycles;
            baseline_waits = arbiter_wait_cycles;
            if (error || selected_gemv || spad_read_bytes !== expected_reads ||
                spad_write_bytes !== expected_writes || arbiter_wait_cycles == 0 ||
                elapsed_cycles <= local_rows*local_cols*local_depth/256) begin
                $display("ERROR: baseline metrics m=%0d n=%0d k=%0d error=%0d gemv=%0d reads=%0d/%0d writes=%0d/%0d wait=%0d elapsed=%0d",
                         local_rows,local_cols,local_depth,error,selected_gemv,
                         spad_read_bytes,expected_reads,spad_write_bytes,
                         expected_writes,arbiter_wait_cycles,elapsed_cycles);
                failures = failures + 1;
            end
            if (dma_accepted == dma_before || dma_responses == 0) begin
                $display("ERROR: contender did not make progress accepted=%0d responses=%0d",
                         dma_accepted,dma_responses);
                failures = failures + 1;
            end
            check_image(local_rows*local_cols*2,1);

            initialize_problem(local_rows,local_cols,local_depth,local_seed);
            mode_request = 2'd2;
            dma_before = dma_accepted;
            dma_active = 1;
            launch_until_done(50000);
            dma_active = 0;
            contender_valid = 0;
            adaptive_cycles = elapsed_cycles;
            adaptive_waits = arbiter_wait_cycles;
            expected_static_gemv = static_selects_gemv(local_rows,local_cols,local_depth);
            if (error || selected_gemv !== expected_static_gemv ||
                spad_read_bytes !== expected_reads ||
                spad_write_bytes !== expected_writes || arbiter_wait_cycles == 0 ||
                dma_accepted == dma_before) begin
                $display("ERROR: adaptive metrics m=%0d n=%0d k=%0d error=%0d gemv=%0d expected_gemv=%0d reads=%0d/%0d writes=%0d/%0d wait=%0d",
                         local_rows,local_cols,local_depth,error,selected_gemv,
                         expected_static_gemv,spad_read_bytes,expected_reads,
                         spad_write_bytes,expected_writes,arbiter_wait_cycles);
                failures = failures + 1;
            end
            check_image(local_rows*local_cols*2,1);
            $display("SPAD_COMPARE_PASS seed=%0d m=%0d n=%0d k=%0d macs=%0d baseline_cycles=%0d adaptive_cycles=%0d selected_gemv=%0d reads=%0d writes=%0d baseline_wait=%0d adaptive_wait=%0d dma_pattern=%0d",
                     local_seed,local_rows,local_cols,local_depth,
                     local_rows*local_cols*local_depth,baseline_cycles,
                     adaptive_cycles,selected_gemv,spad_read_bytes,
                     spad_write_bytes,baseline_waits,adaptive_waits,
                     local_dma_pattern);
            passed_shapes = passed_shapes + 1;
        end
    endtask

    task abort_during_read;
        begin
            initialize_problem(4,8,64,seed+101);
            m_size = 4; n_size = 8; k_size = 64;
            dma_active = 0;
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            wait(dut.state_r == 3'd2);
            @(negedge clk); abort = 1;
            @(negedge clk); abort = 0;
            wait(done === 1'b1);
            @(negedge clk);
            if (!error || busy || spad_write_bytes != 0) begin
                $display("ERROR: read abort disposition error=%0d busy=%0d writes=%0d",
                         error,busy,spad_write_bytes);
                failures = failures + 1;
            end
            check_image(0,0);
        end
    endtask

    task abort_during_compute;
        integer local_timeout;
        begin
            initialize_problem(1,8,64,seed+102);
            m_size = 1; n_size = 8; k_size = 64;
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            wait(dut.state_r == 3'd4);
            repeat (5) @(negedge clk);
            abort = 1;
            @(negedge clk); abort = 0;
            local_timeout = 0;
            while (!done && local_timeout < 1000) begin
                @(posedge clk); #1; local_timeout = local_timeout + 1;
            end
            @(negedge clk);
            if (!done || !error || busy || spad_write_bytes != 0) begin
                $display("ERROR: compute abort disposition done=%0d error=%0d busy=%0d writes=%0d",
                         done,error,busy,spad_write_bytes);
                failures = failures + 1;
            end
            rows=1; cols=8;
            check_image(0,0);
        end
    endtask

    task abort_during_writeback;
        integer local_timeout;
        begin
            initialize_problem(1,8,64,seed+103);
            m_size = 1; n_size = 8; k_size = 64;
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            wait(dut.state_r == 3'd5);
            repeat (7) @(negedge clk);
            abort = 1;
            @(negedge clk); abort = 0;
            local_timeout = 0;
            while (!done && local_timeout < 1000) begin
                @(posedge clk); #1; local_timeout = local_timeout + 1;
            end
            @(negedge clk);
            if (!error || busy || spad_write_bytes == 0 ||
                spad_write_bytes >= 1*8*8)
                begin
                    $display("ERROR: write abort disposition done=%0d error=%0d busy=%0d writes=%0d",
                             done,error,busy,spad_write_bytes);
                    failures = failures + 1;
                end
            rows=1; cols=8;
            prefix_words = spad_write_bytes / 4;
            check_image(prefix_words,0);
        end
    endtask

    task reset_during_read;
        begin
            initialize_problem(4,8,64,seed+104);
            m_size = 4; n_size = 8; k_size = 64;
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            wait(dut.state_r == 3'd2);
            @(negedge clk); resetn = 0;
            repeat (2) @(negedge clk);
            resetn = 1;
            repeat (6) @(negedge clk);
            if (busy || done || dut.state_r != 3'd0) begin
                $display("ERROR: reset failed to clear transaction state");
                failures = failures + 1;
            end
            rows=4; cols=8;
            check_image(0,0);
        end
    endtask

    initial begin
        if (!$value$plusargs("SEED=%d",seed)) seed = 20261030;
        repeat (4) @(negedge clk);
        resetn = 1;
        run_shape(1,8,64,seed,0);
        run_shape(4,8,64,seed+1,1);
        run_shape(8,8,64,seed+2,0);
        run_shape(16,8,64,seed+3,1);
        abort_during_read;
        abort_during_compute;
        abort_during_writeback;
        reset_during_read;
        if (failures == 0)
            $display("SHAPE_ADAPTIVE_SPAD_PASS seed=%0d shapes=%0d aborts=3 reset=1",
                     seed,passed_shapes);
        else
            $display("SHAPE_ADAPTIVE_SPAD_FAIL seed=%0d failures=%0d shapes=%0d",
                     seed,failures,passed_shapes);
        $finish;
    end
endmodule
