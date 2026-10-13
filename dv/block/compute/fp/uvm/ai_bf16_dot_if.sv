`timescale 1ns/1ps

interface ai_bf16_dot_if(input logic clk, input logic resetn,
                          output logic reset_force);
    logic start;
    logic format_fp16;
    logic abort;
    logic [31:0] src0_base;
    logic [31:0] src1_base;
    logic [31:0] dst_base;
    logic [15:0] length;
    logic [31:0] watchdog_limit;

    logic spad_valid;
    logic spad_write;
    logic [31:0] spad_addr;
    logic [31:0] spad_wdata;
    logic spad_ready;
    logic spad_rsp_valid;
    logic [31:0] spad_rdata;
    logic spad_parity_error;
    logic spad_protection_error;

    logic busy;
    logic done;
    logic error;
    logic [3:0] error_code;
    logic [31:0] result;
    logic [31:0] cycle_count;
    logic [31:0] element_count;

    property p_spad_request_stable_while_stalled;
        @(posedge clk) disable iff (!resetn)
            (spad_valid && !spad_ready && !abort) |=>
                (abort ||
                 (spad_valid && $stable({spad_write,spad_addr,spad_wdata})));
    endproperty
    a_spad_request_stable_while_stalled:
        assert property (p_spad_request_stable_while_stalled)
        else $error("SPAD request changed under back-pressure");
endinterface
