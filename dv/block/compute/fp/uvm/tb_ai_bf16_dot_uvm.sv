`timescale 1ns/1ps

module tb_ai_bf16_dot_uvm;
    import uvm_pkg::*;
    import ai_bf16_dot_uvm_pkg::*;

    logic clk;
    logic resetn_tb;
    logic reset_force;
    wire resetn = resetn_tb && !reset_force;
    ai_bf16_dot_if dot_if(clk, resetn, reset_force);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        resetn_tb = 1'b0;
        #40;
        resetn_tb = 1'b1;
    end

    ai_mixed_precision_dot_fp32_core dut (
        .clk(clk),
        .resetn(resetn),
        .start(dot_if.start),
        .format_fp16(dot_if.format_fp16),
        .abort(dot_if.abort),
        .src0_base(dot_if.src0_base),
        .src1_base(dot_if.src1_base),
        .dst_base(dot_if.dst_base),
        .length(dot_if.length),
        .watchdog_limit(dot_if.watchdog_limit),
        .spad_valid(dot_if.spad_valid),
        .spad_write(dot_if.spad_write),
        .spad_addr(dot_if.spad_addr),
        .spad_wdata(dot_if.spad_wdata),
        .spad_ready(dot_if.spad_ready),
        .spad_rsp_valid(dot_if.spad_rsp_valid),
        .spad_rdata(dot_if.spad_rdata),
        .spad_parity_error(dot_if.spad_parity_error),
        .spad_protection_error(dot_if.spad_protection_error),
        .busy(dot_if.busy),
        .done(dot_if.done),
        .error(dot_if.error),
        .error_code(dot_if.error_code),
        .result(dot_if.result),
        .cycle_count(dot_if.cycle_count),
        .element_count(dot_if.element_count)
    );

    initial begin
        uvm_config_db #(virtual ai_bf16_dot_if)::set(null, "*", "vif", dot_if);
        run_test();
    end

    initial begin
        #100000;
        $fatal(1, "BF16 dot UVM testbench global timeout");
    end
endmodule
