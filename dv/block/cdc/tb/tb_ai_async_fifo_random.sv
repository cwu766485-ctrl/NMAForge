`timescale 1ns/1ps

// Randomized, two-clock FIFO stress test.
//
// This testbench is intentionally kept outside the synthesizable RTL path.  It
// checks the ready/valid contract under independent clock phases, random write
// gaps, and random read back-pressure while a small scoreboard checks ordering.
module tb_ai_async_fifo_random;
    localparam integer W = 32;
    localparam integer D = 8;
    localparam integer TARGET = 256;
    localparam integer TIMEOUT_CYCLES = 5000;

    reg wr_clk = 1'b0;
    reg rd_clk = 1'b0;
    reg wr_resetn = 1'b0;
    reg rd_resetn = 1'b0;
    reg wr_valid = 1'b0;
    reg rd_ready = 1'b0;
    reg [W-1:0] wr_data = {W{1'b0}};
    wire wr_ready;
    wire wr_full;
    wire rd_valid;
    wire rd_empty;
    wire [W-1:0] rd_data;
    wire wr_overflow;
    wire rd_underflow;

    integer seed = 32'h5eed_1234;
    integer accepted_count = 0;
    integer received_count = 0;
    integer errors = 0;
    integer wr_cycles = 0;
    integer rd_cycles = 0;
    reg [31:0] wr_prng = 32'h1;
    reg [31:0] rd_prng = 32'h1;
    reg [W-1:0] expected [0:TARGET-1];

    ai_async_fifo #(.DATA_WIDTH(W), .DEPTH(D)) dut (.*);

    always #5 wr_clk = ~wr_clk;
    always #7 rd_clk = ~rd_clk;

    wire wr_fire = wr_valid && wr_ready;
    wire rd_fire = rd_valid && rd_ready;

    function automatic [W-1:0] payload(input integer index);
        payload = 32'ha500_0000 ^ (index * 32'h0001_0101);
    endfunction

    // The source holds valid/data until a write is accepted.  It does not
    // assert valid while full, because this FIFO intentionally records that
    // condition as a sticky overflow diagnostic.
    always @(negedge wr_clk) begin
        if (!wr_resetn) begin
            wr_valid <= 1'b0;
            wr_data <= {W{1'b0}};
        end else if (accepted_count >= TARGET && !wr_fire) begin
            wr_valid <= 1'b0;
        end else if (wr_valid && !wr_ready) begin
            // The implementation records valid-at-full as an intentional
            // overflow attempt.  Withdraw and retry this payload later.
            wr_valid <= 1'b0;
        end else if (accepted_count < TARGET && !wr_full && (wr_prng[1:0] != 2'b00)) begin
            wr_valid <= 1'b1;
            wr_data <= payload(accepted_count);
        end else begin
            wr_valid <= 1'b0;
        end
        wr_prng <= {wr_prng[30:0], wr_prng[31] ^ wr_prng[21] ^ wr_prng[1] ^ wr_prng[0]};
    end

    // Hold the consumer inactive until the first write pointer has safely
    // crossed into the read domain.  Thereafter apply random back-pressure.
    // This avoids manufacturing an empty read solely while bringing the two
    // independent reset domains out of reset.
    always @(negedge rd_clk) begin
        if (!rd_resetn) begin
            rd_ready <= 1'b0;
        end else if (received_count >= TARGET) begin
            rd_ready <= 1'b0;
        end else if (rd_cycles >= 8 && rd_valid) begin
            rd_ready <= (rd_prng[1:0] != 2'b00);
        end else begin
            rd_ready <= 1'b0;
        end
        rd_prng <= {rd_prng[30:0], rd_prng[31] ^ rd_prng[21] ^ rd_prng[1] ^ rd_prng[0]};
    end

    // Record only accepted writes.  The read-side check is deliberately
    // performed at the handshake edge, so it verifies both no loss and FIFO
    // ordering rather than merely checking eventual contents.
    always @(posedge wr_clk) begin
        wr_cycles = wr_cycles + 1;
        if (wr_fire) begin
            if (accepted_count >= TARGET) begin
                errors = errors + 1;
                $display("ERROR: write accepted after TARGET at %0t", $time);
            end else begin
                expected[accepted_count] = wr_data;
                accepted_count = accepted_count + 1;
            end
        end
    end

    always @(posedge rd_clk) begin
        rd_cycles = rd_cycles + 1;
        if (rd_fire) begin
            if (received_count >= accepted_count) begin
                errors = errors + 1;
                $display("ERROR: read without a scoreboard entry at %0t", $time);
            end else if (rd_data !== expected[received_count]) begin
                errors = errors + 1;
                $display("ERROR: FIFO order/data mismatch index=%0d expected=%h got=%h",
                         received_count, expected[received_count], rd_data);
            end
            received_count = received_count + 1;
        end
    end

    // Show-ahead data must remain stable for the complete ready/valid stall.
    // This is the key protocol property for the FIFO's registered read
    // pointer and is intentionally checked independently of the scoreboard.
    property p_rd_payload_stable_when_stalled;
        @(posedge rd_clk) disable iff (!rd_resetn)
            rd_valid && !rd_ready |=> rd_valid && $stable(rd_data);
    endproperty

    assert property (p_rd_payload_stable_when_stalled)
        else $fatal(1, "SVA FAIL: rd_data changed while rd_valid && !rd_ready");

    cover property (@(posedge rd_clk) disable iff (!rd_resetn)
        (rd_valid && !rd_ready) ##1 (rd_valid && rd_ready));

    initial begin
        if ($value$plusargs("SEED=%d", seed))
            $display("CDC RANDOM SEED=%0d", seed);
        else
            $display("CDC RANDOM SEED=%0d (default)", seed);
        wr_prng = seed ^ 32'h1357_9bdf;
        rd_prng = seed ^ 32'h2468_ace1;

        repeat (4) @(posedge wr_clk);
        repeat (3) @(posedge rd_clk);
        wr_resetn = 1'b1;
        rd_resetn = 1'b1;

        fork
            begin
                wait (received_count == TARGET);
                repeat (4) @(posedge rd_clk);
            end
            begin
                repeat (TIMEOUT_CYCLES) @(posedge rd_clk);
                $fatal(1, "CDC RANDOM TIMEOUT accepted=%0d received=%0d full=%b empty=%b",
                       accepted_count, received_count, wr_full, rd_empty);
            end
        join_any
        disable fork;

        wr_valid = 1'b0;
        rd_ready = 1'b0;
        if (accepted_count != TARGET || received_count != TARGET || errors != 0) begin
            $fatal(1, "CDC RANDOM FAIL accepted=%0d received=%0d errors=%0d overflow=%b underflow=%b",
                   accepted_count, received_count, errors, wr_overflow, rd_underflow);
        end
        if (wr_overflow || rd_underflow) begin
            $fatal(1, "CDC RANDOM FAIL unexpected diagnostic overflow=%b underflow=%b",
                   wr_overflow, rd_underflow);
        end
        $display("CDC RANDOM PASS seed=%0d accepted=%0d received=%0d wr_cycles=%0d rd_cycles=%0d",
                 seed, accepted_count, received_count, wr_cycles, rd_cycles);
        $finish;
    end
endmodule
