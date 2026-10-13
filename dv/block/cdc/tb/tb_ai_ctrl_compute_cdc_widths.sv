`timescale 1ns/1ps

// Directed dual-clock wrapper test: deliberately asymmetric payload widths,
// randomized valid/ready back-pressure, and ordered bidirectional checking.
module tb_ai_ctrl_compute_cdc_widths;
    localparam integer CMD_W = 1024;
    localparam integer CPL_W = 256;
    localparam integer N = 16;

    reg ctrl_clk = 1'b0, compute_clk = 1'b0;
    reg ctrl_resetn = 1'b0, compute_resetn = 1'b0;
    reg ctrl_cmd_valid = 1'b0, compute_cmd_ready = 1'b0;
    reg compute_cpl_valid = 1'b0, ctrl_cpl_ready = 1'b0;
    reg [CMD_W-1:0] ctrl_cmd_data = '0;
    reg [CPL_W-1:0] compute_cpl_data = '0;
    wire ctrl_cmd_ready, compute_cmd_valid, ctrl_cpl_valid, compute_cpl_ready;
    wire [CMD_W-1:0] compute_cmd_data;
    wire [CPL_W-1:0] ctrl_cpl_data;
    integer cmd_sent = 0, cmd_got = 0, cpl_sent = 0, cpl_got = 0;
    integer errors = 0;
    integer seed = 32'h51c0_2026;

    ai_ctrl_compute_cdc #(
        .CMD_DATA_WIDTH(CMD_W), .CPL_DATA_WIDTH(CPL_W), .DEPTH(8)
    ) dut (
        .ctrl_clk(ctrl_clk), .ctrl_resetn(ctrl_resetn),
        .ctrl_cmd_valid(ctrl_cmd_valid), .ctrl_cmd_ready(ctrl_cmd_ready),
        .ctrl_cmd_data(ctrl_cmd_data), .ctrl_cpl_valid(ctrl_cpl_valid),
        .ctrl_cpl_ready(ctrl_cpl_ready), .ctrl_cpl_data(ctrl_cpl_data),
        .compute_clk(compute_clk), .compute_resetn(compute_resetn),
        .compute_cmd_valid(compute_cmd_valid), .compute_cmd_ready(compute_cmd_ready),
        .compute_cmd_data(compute_cmd_data), .compute_cpl_valid(compute_cpl_valid),
        .compute_cpl_ready(compute_cpl_ready), .compute_cpl_data(compute_cpl_data)
    );

    always #5 ctrl_clk = ~ctrl_clk;
    always #7 compute_clk = ~compute_clk;

    function automatic [CMD_W-1:0] command_value(input integer index);
        command_value = {16{64'hc001_0000_0000_0000 + index}};
    endfunction
    function automatic [CPL_W-1:0] completion_value(input integer index);
        completion_value = {4{64'hd002_0000_0000_0000 + index}};
    endfunction

    always @(posedge compute_clk) begin
        if (compute_cmd_valid && compute_cmd_ready) begin
            if (compute_cmd_data !== command_value(cmd_got)) begin
                $display("ERROR command[%0d] data mismatch", cmd_got);
                errors = errors + 1;
            end
            cmd_got = cmd_got + 1;
        end
    end

    always @(posedge ctrl_clk) begin
        if (ctrl_cpl_valid && ctrl_cpl_ready) begin
            if (ctrl_cpl_data !== completion_value(cpl_got)) begin
                $display("ERROR completion[%0d] data mismatch", cpl_got);
                errors = errors + 1;
            end
            cpl_got = cpl_got + 1;
        end
    end

    initial begin : command_source
        wait (ctrl_resetn);
        while (cmd_sent < N) begin
            @(negedge ctrl_clk);
            ctrl_cmd_valid = (($urandom(seed) % 3) != 0);
            ctrl_cmd_data = command_value(cmd_sent);
            if (ctrl_cmd_valid) begin
                @(posedge ctrl_clk);
                if (ctrl_cmd_ready) cmd_sent = cmd_sent + 1;
            end
        end
        @(negedge ctrl_clk);
        ctrl_cmd_valid = 1'b0;
    end

    initial begin : completion_source
        wait (compute_resetn);
        while (cpl_sent < N) begin
            @(negedge compute_clk);
            compute_cpl_valid = (($urandom(seed) % 4) != 0);
            compute_cpl_data = completion_value(cpl_sent);
            if (compute_cpl_valid) begin
                @(posedge compute_clk);
                if (compute_cpl_ready) cpl_sent = cpl_sent + 1;
            end
        end
        @(negedge compute_clk);
        compute_cpl_valid = 1'b0;
    end

    initial begin : randomized_backpressure
        wait (ctrl_resetn && compute_resetn);
        forever begin
            @(negedge ctrl_clk);
            ctrl_cpl_ready = (($urandom(seed) % 5) != 0);
            @(negedge compute_clk);
            compute_cmd_ready = (($urandom(seed) % 4) != 0);
        end
    end

    initial begin : test_control
        repeat (4) @(posedge ctrl_clk);
        ctrl_resetn = 1'b1;
        compute_resetn = 1'b1;
        fork
            begin
                wait (cmd_got == N && cpl_got == N);
            end
            begin
                repeat (3000) @(posedge ctrl_clk);
                $fatal(1, "CDC WIDTH TIMEOUT sent=%0d/%0d got=%0d/%0d errors=%0d",
                       cmd_sent, cpl_sent, cmd_got, cpl_got, errors);
            end
        join_any
        disable fork;
        repeat (3) @(posedge ctrl_clk);
        if (cmd_sent != N || cpl_sent != N || cmd_got != N || cpl_got != N || errors != 0)
            $fatal(1, "CDC WIDTH FAIL sent=%0d/%0d got=%0d/%0d errors=%0d",
                   cmd_sent, cpl_sent, cmd_got, cpl_got, errors);
        $display("CDC WIDTH PASS CMD=%0d CPL=%0d commands=%0d completions=%0d",
                 CMD_W, CPL_W, cmd_got, cpl_got);
        $finish;
    end
endmodule
