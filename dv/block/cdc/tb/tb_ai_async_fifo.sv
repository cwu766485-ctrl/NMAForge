`timescale 1ns/1ps
module tb_ai_async_fifo;
    localparam W=32; localparam D=4;
    reg wr_clk=0, rd_clk=0, wr_resetn=0, rd_resetn=0;
    reg wr_valid=0, rd_ready=0; reg [W-1:0] wr_data=0;
    wire wr_ready, wr_full, rd_valid, rd_empty; wire [W-1:0] rd_data;
    wire wr_overflow, rd_underflow;
    integer sent=0, received=0, errors=0, cycles=0;
    integer expected_count=0;
    ai_async_fifo #(.DATA_WIDTH(W),.DEPTH(D)) dut(.*);
    always #5 wr_clk=~wr_clk;
    always #7 rd_clk=~rd_clk;
    reg [W-1:0] sampled_data;
    always @(posedge rd_clk) begin
        if (rd_valid && rd_ready) begin
            sampled_data = rd_data;
            #1;
            if (sampled_data !== (received + 32'h1000)) begin
                $display("ERROR: expected %h got %h", received+32'h1000, sampled_data); errors=errors+1;
            end
            received=received+1;
        end
    end
    initial begin
        repeat(3) @(posedge wr_clk); wr_resetn=1; rd_resetn=1;
        rd_ready=0;
        fork
            begin repeat(4) @(posedge wr_clk); rd_ready=1; end
            begin
        while (sent < 12) begin
            @(negedge wr_clk);
            wr_valid=1; wr_data=sent+32'h1000;
            if (wr_ready) begin
                @(posedge wr_clk); #1; sent=sent+1; expected_count=expected_count+1;
            end else begin
                @(posedge wr_clk);
            end
        end
            end
        join
        wr_valid=0;
        repeat(8) @(posedge rd_clk);
        rd_ready=1;
        fork
            begin wait(received==expected_count); end
            begin repeat(500) @(posedge rd_clk); $fatal(1,"ASYNC FIFO TIMEOUT sent=%0d received=%0d full=%b empty=%b",sent,received,wr_full,rd_empty); end
        join_any
        disable fork;
        repeat(5) @(posedge rd_clk);
        if (errors != 0 || !rd_empty) $fatal(1,"ASYNC FIFO FAIL errors=%0d received=%0d empty=%b",errors,received,rd_empty);
        $display("ASYNC FIFO PASS sent=%0d received=%0d",sent,received);
        $finish;
    end
endmodule
