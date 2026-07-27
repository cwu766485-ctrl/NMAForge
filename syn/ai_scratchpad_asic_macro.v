`timescale 1ns / 1ps

// ASIC-only scratchpad implementation for DC/PPA estimation.
//
// The FPGA RTL uses Xilinx XPM RAM.  Defining VCS for synthesis would instead
// expose a 512 KiB behavioural array, which DC could incorrectly turn into
// flops.  This wrapper keeps the real four-bank interface and represents each
// 32K x 32 common-clock TDP bank as one replaceable foundry SRAM macro.
//
// `cimforge_sram_32kx32_tdp` is deliberately a black box until a matching
// 40 nm SRAM .db/.lef/verilog view is supplied.  Replace only that adapter
// with the foundry macro wrapper; the accelerator-facing interface must stay
// unchanged.  Area, leakage and SRAM-internal timing are therefore excluded
// from the current standard-cell-only DC result and must not be quoted as
// full-chip SRAM PPA.

module ai_scratchpad #(
    parameter integer BANKS = 4,
    parameter integer WORDS_PER_BANK = 32768,
    parameter integer ROW_BITS = $clog2(WORDS_PER_BANK)
)(
    input wire clk, input wire resetn,
    input wire host_valid, input wire host_write,
    input wire [31:0] host_addr, input wire [31:0] host_wdata,
    input wire [3:0] host_wstrb,
    output reg [31:0] host_rdata, output reg host_error,
    output reg host_parity_error,
    input wire compute_valid, input wire compute_write,
    input wire [31:0] compute_addr, input wire [31:0] compute_wdata,
    output reg [31:0] compute_rdata, output reg compute_parity_error,
    input wire banked_read_valid, input wire [31:0] banked_addr,
    output reg [31:0] banked_data0, output reg [31:0] banked_data1,
    output reg [31:0] banked_data2, output reg [31:0] banked_data3,
    output reg [3:0] banked_parity_error
);
    localparam integer BANK_BITS = 2;
    wire [31:0] host_word_addr = host_addr[31:2];
    wire [31:0] compute_word_addr = compute_addr[31:2];
    wire [31:0] banked_word_addr = banked_addr[31:2];
    wire [1:0] host_bank = host_word_addr[1:0];
    wire [1:0] compute_bank = compute_word_addr[1:0];
    wire [ROW_BITS-1:0] host_row = host_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] compute_row = compute_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] banked_row = banked_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire host_align_error = |host_addr[1:0];
    wire compute_align_error = |compute_addr[1:0];
    wire banked_align_error = |banked_addr[3:0];
    wire host_range_error = (host_word_addr >= BANKS * WORDS_PER_BANK);
    wire compute_range_error = (compute_word_addr >= BANKS * WORDS_PER_BANK);
    wire banked_range_error = (banked_addr > (BANKS * WORDS_PER_BANK * 4) - 16);
    wire host_conflict = host_valid && (compute_valid || banked_read_valid);
    wire host_access_ok = host_valid && !host_align_error && !host_range_error && !host_conflict;
    wire compute_access_ok = compute_valid && !compute_align_error && !compute_range_error;
    wire banked_access_ok = banked_read_valid && !banked_align_error && !banked_range_error;
    wire portb_enable = banked_access_ok || compute_access_ok;
    wire [ROW_BITS-1:0] portb_row = banked_access_ok ? banked_row : compute_row;
    wire [3:0] host_we = (host_access_ok && host_write) ? host_wstrb : 4'b0;
    wire [3:0] compute_we = (compute_access_ok && compute_write) ? 4'hf : 4'b0;
    wire [31:0] x0a, x1a, x2a, x3a, x0b, x1b, x2b, x3b;
    reg [1:0] host_read_bank_d0, host_read_bank_d1;
    reg [1:0] compute_read_bank_d0, compute_read_bank_d1;

    (* keep_hierarchy = "yes", dont_touch = "yes" *) cimforge_sram_32kx32_tdp spad_macro0 (
        .clka(clk), .ena(host_access_ok && host_bank==2'd0), .wea(host_we), .addra(host_row), .dina(host_wdata), .douta(x0a),
        .clkb(clk), .enb(portb_enable), .web((compute_access_ok && compute_bank==2'd0) ? compute_we : 4'b0), .addrb(portb_row), .dinb(compute_wdata), .doutb(x0b));
    (* keep_hierarchy = "yes", dont_touch = "yes" *) cimforge_sram_32kx32_tdp spad_macro1 (
        .clka(clk), .ena(host_access_ok && host_bank==2'd1), .wea(host_we), .addra(host_row), .dina(host_wdata), .douta(x1a),
        .clkb(clk), .enb(portb_enable), .web((compute_access_ok && compute_bank==2'd1) ? compute_we : 4'b0), .addrb(portb_row), .dinb(compute_wdata), .doutb(x1b));
    (* keep_hierarchy = "yes", dont_touch = "yes" *) cimforge_sram_32kx32_tdp spad_macro2 (
        .clka(clk), .ena(host_access_ok && host_bank==2'd2), .wea(host_we), .addra(host_row), .dina(host_wdata), .douta(x2a),
        .clkb(clk), .enb(portb_enable), .web((compute_access_ok && compute_bank==2'd2) ? compute_we : 4'b0), .addrb(portb_row), .dinb(compute_wdata), .doutb(x2b));
    (* keep_hierarchy = "yes", dont_touch = "yes" *) cimforge_sram_32kx32_tdp spad_macro3 (
        .clka(clk), .ena(host_access_ok && host_bank==2'd3), .wea(host_we), .addra(host_row), .dina(host_wdata), .douta(x3a),
        .clkb(clk), .enb(portb_enable), .web((compute_access_ok && compute_bank==2'd3) ? compute_we : 4'b0), .addrb(portb_row), .dinb(compute_wdata), .doutb(x3b));

    always @(posedge clk) begin
        if (!resetn) begin
            host_read_bank_d0 <= 0; host_read_bank_d1 <= 0;
            compute_read_bank_d0 <= 0; compute_read_bank_d1 <= 0;
        end else begin
            if (host_access_ok && !host_write) host_read_bank_d0 <= host_bank;
            host_read_bank_d1 <= host_read_bank_d0;
            if (compute_access_ok && !compute_write) compute_read_bank_d0 <= compute_bank;
            compute_read_bank_d1 <= compute_read_bank_d0;
        end
    end

    always @(*) begin
        host_error = host_align_error || host_range_error || host_conflict;
        host_rdata = host_read_bank_d1==2'd0 ? x0a : host_read_bank_d1==2'd1 ? x1a : host_read_bank_d1==2'd2 ? x2a : x3a;
        compute_rdata = compute_read_bank_d1==2'd0 ? x0b : compute_read_bank_d1==2'd1 ? x1b : compute_read_bank_d1==2'd2 ? x2b : x3b;
        host_parity_error = 1'b0;
        compute_parity_error = 1'b0;
        banked_data0=x0b; banked_data1=x1b; banked_data2=x2b; banked_data3=x3b;
        banked_parity_error=4'b0;
    end
endmodule
