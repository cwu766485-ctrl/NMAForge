`timescale 1ns/1ps
module tb_ai_ctrl_compute_cdc;
    reg ctrl_clk=0, compute_clk=0, ctrl_resetn=0, compute_resetn=0;
    reg ctrl_cmd_valid=0, compute_cmd_ready=0, compute_cpl_valid=0, ctrl_cpl_ready=0;
    reg [127:0] ctrl_cmd_data=0, compute_cpl_data=0;
    wire ctrl_cmd_ready, compute_cmd_valid, ctrl_cpl_valid, compute_cpl_ready;
    wire [127:0] compute_cmd_data, ctrl_cpl_data;
    integer cmd_sent=0, cmd_got=0, cpl_sent=0, cpl_got=0, errors=0;
    ai_ctrl_compute_cdc #(.DEPTH(4)) dut(.*);
    always #5 ctrl_clk=~ctrl_clk;
    always #3 compute_clk=~compute_clk;
    always @(posedge compute_clk) if (compute_cmd_valid && compute_cmd_ready) begin
        if (compute_cmd_data !== (128'hc000 + cmd_got)) errors=errors+1;
        cmd_got=cmd_got+1;
    end
    always @(posedge ctrl_clk) if (ctrl_cpl_valid && ctrl_cpl_ready) begin
        if (ctrl_cpl_data !== (128'hd000 + cpl_got)) errors=errors+1;
        cpl_got=cpl_got+1;
    end
    initial begin
        repeat(4) @(posedge ctrl_clk); ctrl_resetn=1; compute_resetn=1;
        compute_cmd_ready=1; ctrl_cpl_ready=1;
        fork
            begin : command_source
                while (cmd_sent < 12) begin
                    @(negedge ctrl_clk);
                    ctrl_cmd_valid = 1'b1;
                    ctrl_cmd_data  = 128'hc000 + cmd_sent;
                    @(posedge ctrl_clk);
                    if (ctrl_cmd_ready) cmd_sent = cmd_sent + 1;
                end
                @(negedge ctrl_clk); ctrl_cmd_valid = 1'b0;
            end
            begin : completion_source
                wait(cmd_got == 12);
                repeat(8) @(posedge compute_clk);
                while (cpl_sent < 12) begin
                    @(negedge compute_clk);
                    compute_cpl_valid = 1'b1;
                    compute_cpl_data  = 128'hd000 + cpl_sent;
                    @(posedge compute_clk);
                    if (compute_cpl_ready) cpl_sent = cpl_sent + 1;
                end
                @(negedge compute_clk); compute_cpl_valid = 1'b0;
            end
        join
        fork
            begin wait(cpl_got == 12); end
            begin repeat(1000) @(posedge ctrl_clk); $fatal(1,"CDC WRAPPER TIMEOUT cmd_sent=%0d cmd_got=%0d cpl_sent=%0d cpl_got=%0d",cmd_sent,cmd_got,cpl_sent,cpl_got); end
        join_any
        disable fork;
        repeat(4) @(posedge ctrl_clk);
        if (errors != 0) $fatal(1,"CDC WRAPPER FAIL errors=%0d",errors);
        $display("CDC WRAPPER PASS commands=%0d completions=%0d",cmd_got,cpl_got);
        $finish;
    end
endmodule
