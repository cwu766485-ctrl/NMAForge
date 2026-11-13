`timescale 1ns/1ps

// Research-only 128 KiB four-bank Port-B adapter. It mirrors the product
// behavioral SRAM's bank geometry, byte-write and parity semantics while
// exposing one physical Port-B operation per bank. It is intentionally not
// connected to the product top: a real ASIC integration still needs four
// compatible SRAM Port-B macros.
module ai_spad_bank_parallel_adapter #(
    parameter integer BANKS=4,
    parameter integer WORDS_PER_BANK=8192
) (
    input wire clk, input wire resetn,
    input wire host_valid, input wire host_write,
    input wire [31:0] host_addr, input wire [31:0] host_wdata,
    input wire [3:0] host_wstrb, input wire host_allow,
    output wire host_ready, output wire host_rsp_valid,
    output wire [31:0] host_rdata, output wire host_error,
    output wire host_parity_error,
    input wire [BANKS-1:0] bank_req_valid,
    input wire [BANKS-1:0] bank_req_write,
    input wire [BANKS*32-1:0] bank_req_addr,
    input wire [BANKS*32-1:0] bank_req_wdata,
    input wire [BANKS*4-1:0] bank_req_wstrb,
    input wire [BANKS-1:0] bank_allow,
    input wire [BANKS-1:0] inject_parity_error,
    output wire [BANKS-1:0] bank_ready,
    output wire [BANKS-1:0] bank_denied,
    output wire [BANKS-1:0] bank_rsp_valid,
    output wire [BANKS*32-1:0] bank_rsp_rdata,
    output wire [BANKS-1:0] bank_rsp_error,
    output wire [BANKS-1:0] bank_rsp_parity_error
);
    localparam integer ROW_BITS = $clog2(WORDS_PER_BANK);
    localparam integer TOTAL_BYTES = BANKS*WORDS_PER_BANK*4;
    reg [31:0] mem [0:BANKS-1][0:WORDS_PER_BANK-1];
    reg parity [0:BANKS-1][0:WORDS_PER_BANK-1];
    reg [BANKS-1:0] read_v0, read_v1, read_v2;
    reg [BANKS*32-1:0] read_d0, read_d1, read_d2;
    reg [BANKS-1:0] read_e0, read_e1, read_e2;
    reg host_v0, host_v1, host_v2, host_e0, host_e1, host_e2;
    reg [31:0] host_d0, host_d1, host_d2;
    integer b, r;

    function [31:0] merge_wstrb;
        input [31:0] old_data, new_data; input [3:0] wstrb;
        begin
            merge_wstrb=old_data;
            if (wstrb[0]) merge_wstrb[7:0]=new_data[7:0];
            if (wstrb[1]) merge_wstrb[15:8]=new_data[15:8];
            if (wstrb[2]) merge_wstrb[23:16]=new_data[23:16];
            if (wstrb[3]) merge_wstrb[31:24]=new_data[31:24];
        end
    endfunction

    wire host_addr_ok = (host_addr[1:0] == 0) && (host_addr < TOTAL_BYTES);
    assign host_ready = host_valid && host_allow && host_addr_ok;
    assign host_rsp_valid = host_v2;
    assign host_rdata = host_d2;
    assign host_parity_error = host_e2;
    assign host_error = host_v2 && host_e2;

    genvar g;
    generate for (g=0; g<BANKS; g=g+1) begin : BANK_STATUS
        wire [31:0] bank_addr = bank_req_addr[g*32 +: 32];
        wire addr_ok = (bank_addr[1:0] == 0) && (bank_addr < TOTAL_BYTES);
        assign bank_ready[g] = !host_valid && bank_allow[g] && addr_ok;
        assign bank_denied[g] = bank_req_valid[g] && !bank_ready[g];
        assign bank_rsp_valid[g] = read_v2[g];
        assign bank_rsp_rdata[g*32 +: 32] = read_d2[g*32 +: 32];
        assign bank_rsp_parity_error[g] = read_e2[g] || inject_parity_error[g];
        assign bank_rsp_error[g] = read_v2[g] && (read_e2[g] || inject_parity_error[g]);
    end endgenerate

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            read_v0 <= 0; read_v1 <= 0; read_v2 <= 0;
            read_d0 <= 0; read_d1 <= 0; read_d2 <= 0;
            read_e0 <= 0; read_e1 <= 0; read_e2 <= 0;
            host_v0 <= 0; host_v1 <= 0; host_v2 <= 0;
            host_d0 <= 0; host_d1 <= 0; host_d2 <= 0;
            host_e0 <= 0; host_e1 <= 0; host_e2 <= 0;
        end else begin
            read_v1 <= read_v0; read_v2 <= read_v1;
            read_d1 <= read_d0; read_d2 <= read_d1;
            read_e1 <= read_e0; read_e2 <= read_e1;
            host_v1 <= host_v0; host_v2 <= host_v1;
            host_d1 <= host_d0; host_d2 <= host_d1;
            host_e1 <= host_e0; host_e2 <= host_e1;
            read_v0 <= 0; read_e0 <= 0;
            host_v0 <= 0; host_e0 <= 0;

            if (host_ready) begin
                host_d0 <= mem[host_addr[3:2]][host_addr[16:4]];
                host_e0 <= (^mem[host_addr[3:2]][host_addr[16:4]]) ^
                           parity[host_addr[3:2]][host_addr[16:4]];
                host_v0 <= !host_write;
                if (host_write) begin
                    mem[host_addr[3:2]][host_addr[16:4]] <=
                      merge_wstrb(mem[host_addr[3:2]][host_addr[16:4]],host_wdata,host_wstrb);
                    parity[host_addr[3:2]][host_addr[16:4]] <=
                      ^merge_wstrb(mem[host_addr[3:2]][host_addr[16:4]],host_wdata,host_wstrb);
                end
            end
            for (b=0; b<BANKS; b=b+1) begin
                if (bank_req_valid[b] && bank_ready[b]) begin
                    if (bank_req_write[b]) begin
                        mem[b][bank_req_addr[b*32 + 16 -: ROW_BITS]] <=
                          merge_wstrb(mem[b][bank_req_addr[b*32 + 16 -: ROW_BITS]],
                                      bank_req_wdata[b*32 +: 32], bank_req_wstrb[b*4 +: 4]);
                        parity[b][bank_req_addr[b*32 + 16 -: ROW_BITS]] <=
                          ^merge_wstrb(mem[b][bank_req_addr[b*32 + 16 -: ROW_BITS]],
                                       bank_req_wdata[b*32 +: 32], bank_req_wstrb[b*4 +: 4]);
                    end else begin
                        read_v0[b] <= 1'b1;
                        read_d0[b*32 +: 32] <= mem[b][bank_req_addr[b*32 + 16 -: ROW_BITS]];
                        read_e0[b] <= (^mem[b][bank_req_addr[b*32 + 16 -: ROW_BITS]]) ^
                                      parity[b][bank_req_addr[b*32 + 16 -: ROW_BITS]];
                    end
                end
            end
        end
    end
endmodule
