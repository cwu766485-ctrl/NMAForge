`timescale 1ns / 1ps

// TSMC28 HPC+ ASIC scratchpad implementation.
//
// The installed macro set provides TS1N28HPCPL2SVTB4096X32M4MWBASO, a
// synchronous 4Kx32 *single-port* macro.  The accelerator scratchpad is
// 512 KiB = 4 logical banks x 32Kx32.  Each logical bank is therefore split
// into eight physical macros, for a total of 32 hard SRAM instances.
//
// This does not reduce the architectural port contract: ai_spad_arbiter is
// the unique scheduler admission point, so its scalar, banked, and line
// requests are mutually exclusive.  The host/debug port already rejects a
// request while any scheduler request is present.  Thus there is at most one
// access per logical bank per clock, which maps exactly to these 1RW macros.
//
// This file is synthesis-only.  VCS continues to use rtl/ai_scratchpad.v and
// its behavioural storage model; never add foundry macro models to the normal
// functional simulation source list.

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
    input wire line_valid, input wire line_write,
    input wire [31:0] line_addr, input wire [127:0] line_wdata,
    input wire [15:0] line_wstrb,
    output reg [127:0] line_rdata, output reg [3:0] line_parity_error,
    output reg line_error,
    input wire banked_read_valid, input wire [31:0] banked_addr,
    output reg [31:0] banked_data0, output reg [31:0] banked_data1,
    output reg [31:0] banked_data2, output reg [31:0] banked_data3,
    output reg [3:0] banked_parity_error
);
    localparam integer BANK_BITS = 2;
    localparam integer MACROS_PER_BANK = 8;
    localparam integer MACRO_ROW_BITS = 12;

    wire [31:0] host_word_addr = host_addr[31:2];
    wire [31:0] compute_word_addr = compute_addr[31:2];
    wire [31:0] line_word_addr = line_addr[31:2];
    wire [31:0] banked_word_addr = banked_addr[31:2];
    wire [1:0] host_bank = host_word_addr[1:0];
    wire [1:0] compute_bank = compute_word_addr[1:0];
    wire [ROW_BITS-1:0] host_row = host_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] compute_row = compute_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] line_row = line_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] banked_row = banked_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [2:0] host_slice = host_row[ROW_BITS-1:MACRO_ROW_BITS];
    wire [2:0] compute_slice = compute_row[ROW_BITS-1:MACRO_ROW_BITS];
    wire [2:0] line_slice = line_row[ROW_BITS-1:MACRO_ROW_BITS];
    wire [2:0] banked_slice = banked_row[ROW_BITS-1:MACRO_ROW_BITS];
    wire [MACRO_ROW_BITS-1:0] host_macro_addr = host_row[MACRO_ROW_BITS-1:0];
    wire [MACRO_ROW_BITS-1:0] compute_macro_addr = compute_row[MACRO_ROW_BITS-1:0];
    wire [MACRO_ROW_BITS-1:0] line_macro_addr = line_row[MACRO_ROW_BITS-1:0];
    wire [MACRO_ROW_BITS-1:0] banked_macro_addr = banked_row[MACRO_ROW_BITS-1:0];
    wire host_align_error = |host_addr[1:0];
    wire compute_align_error = |compute_addr[1:0];
    wire line_align_error = |line_addr[3:0];
    wire banked_align_error = |banked_addr[3:0];
    wire host_range_error = (host_word_addr >= BANKS * WORDS_PER_BANK);
    wire compute_range_error = (compute_word_addr >= BANKS * WORDS_PER_BANK);
    wire line_range_error = (line_addr > (BANKS * WORDS_PER_BANK * 4) - 16);
    wire banked_range_error = (banked_addr > (BANKS * WORDS_PER_BANK * 4) - 16);
    wire host_conflict = host_valid && (compute_valid || line_valid ||
                                        banked_read_valid);
    wire host_access_ok = host_valid && !host_align_error && !host_range_error && !host_conflict;
    wire compute_access_ok = compute_valid && !compute_align_error && !compute_range_error;
    wire line_access_ok = line_valid && !line_align_error && !line_range_error;
    wire banked_access_ok = banked_read_valid && !banked_align_error && !banked_range_error;
    wire [31:0] host_byte_mask = {{8{host_wstrb[3]}}, {8{host_wstrb[2]}},
                                  {8{host_wstrb[1]}}, {8{host_wstrb[0]}}};

    // The physical macro outputs are kept as an unpacked array so an address
    // slice can select the returning hard macro without flattening SRAM data
    // into standard-cell multiplexers inside the macro itself.
    wire [31:0] macro_q [0:31];
    reg [4:0] host_read_idx_d0, host_read_idx_d1;
    reg [4:0] compute_read_idx_d0, compute_read_idx_d1;
    reg [2:0] banked_slice_d0, banked_slice_d1;
    reg [2:0] line_slice_d0, line_slice_d1;

    genvar bank_i, slice_i;
    generate
        for (bank_i = 0; bank_i < BANKS; bank_i = bank_i + 1) begin: g_bank
            for (slice_i = 0; slice_i < MACROS_PER_BANK; slice_i = slice_i + 1) begin: g_slice
                localparam [1:0] BANK_ID = bank_i;
                localparam [2:0] SLICE_ID = slice_i;
                localparam integer MACRO_ID = bank_i * MACROS_PER_BANK + slice_i;
                wire host_select = host_access_ok && (host_bank == BANK_ID) && (host_slice == SLICE_ID);
                // spad_arbiter admits either scalar compute or banked read,
                // never both. Keep banked priority here as a defensive match
                // to rtl/ai_scratchpad.v's scheduler-port selection.
                wire banked_select = banked_access_ok && (banked_slice == SLICE_ID);
                wire line_select = line_access_ok && (line_slice == SLICE_ID);
                wire compute_select = compute_access_ok && !line_access_ok &&
                                      !banked_access_ok &&
                                      (compute_bank == BANK_ID) && (compute_slice == SLICE_ID);
                wire macro_enable = host_select || line_select || banked_select ||
                                    compute_select;
                wire macro_write = host_select ? host_write :
                                   (line_select ? line_write :
                                    (compute_select && compute_write));
                wire [3:0] line_bank_wstrb = line_wstrb[bank_i*4 +: 4];
                wire [31:0] line_byte_mask = {
                    {8{line_bank_wstrb[3]}}, {8{line_bank_wstrb[2]}},
                    {8{line_bank_wstrb[1]}}, {8{line_bank_wstrb[0]}}};
                wire [31:0] macro_wmask = host_select ? host_byte_mask :
                                         (line_select ? line_byte_mask :
                                          32'hffff_ffff);
                wire [31:0] macro_addr = host_select ? {{(32-MACRO_ROW_BITS){1'b0}}, host_macro_addr} :
                                        line_select ? {{(32-MACRO_ROW_BITS){1'b0}}, line_macro_addr} :
                                        banked_select ? {{(32-MACRO_ROW_BITS){1'b0}}, banked_macro_addr} :
                                                        {{(32-MACRO_ROW_BITS){1'b0}}, compute_macro_addr};
                wire [31:0] macro_wdata = host_select ? host_wdata :
                                          (line_select ?
                                           line_wdata[bank_i*32 +: 32] :
                                           compute_wdata);

                (* keep_hierarchy = "yes", dont_touch = "yes" *)
                TS1N28HPCPL2SVTB4096X32M4MWBASO spad_macro (
                    .SLP   (1'b0), .SD    (1'b0), .CLK   (clk),
                    .CEB   (~macro_enable), .WEB   (~macro_write),
                    .CEBM  (1'b1), .WEBM  (1'b1), .AWT   (1'b0),
                    .A     (macro_addr[MACRO_ROW_BITS-1:0]), .D (macro_wdata),
                    .BWEB  (~(macro_write ? macro_wmask : 32'hffff_ffff)),
                    .AM    ({MACRO_ROW_BITS{1'b0}}), .DM (32'd0),
                    .BWEBM (32'hffff_ffff), .BIST (1'b0), .Q (macro_q[MACRO_ID])
                );
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!resetn) begin
            host_read_idx_d0 <= 5'd0; host_read_idx_d1 <= 5'd0;
            compute_read_idx_d0 <= 5'd0; compute_read_idx_d1 <= 5'd0;
            banked_slice_d0 <= 3'd0; banked_slice_d1 <= 3'd0;
            line_slice_d0 <= 3'd0; line_slice_d1 <= 3'd0;
        end else begin
            if (host_access_ok && !host_write) host_read_idx_d0 <= {host_bank, host_slice};
            host_read_idx_d1 <= host_read_idx_d0;
            if (compute_access_ok && !compute_write) compute_read_idx_d0 <= {compute_bank, compute_slice};
            compute_read_idx_d1 <= compute_read_idx_d0;
            if (banked_access_ok) banked_slice_d0 <= banked_slice;
            banked_slice_d1 <= banked_slice_d0;
            if (line_access_ok && !line_write) line_slice_d0 <= line_slice;
            line_slice_d1 <= line_slice_d0;
        end
    end

    always @(*) begin
        host_error = host_align_error || host_range_error || host_conflict;
        line_error = line_valid && (line_align_error || line_range_error);
        host_rdata = macro_q[host_read_idx_d1];
        compute_rdata = macro_q[compute_read_idx_d1];
        banked_data0 = macro_q[{2'd0, banked_slice_d1}];
        banked_data1 = macro_q[{2'd1, banked_slice_d1}];
        banked_data2 = macro_q[{2'd2, banked_slice_d1}];
        banked_data3 = macro_q[{2'd3, banked_slice_d1}];
        line_rdata = {macro_q[{2'd3, line_slice_d1}],
                      macro_q[{2'd2, line_slice_d1}],
                      macro_q[{2'd1, line_slice_d1}],
                      macro_q[{2'd0, line_slice_d1}]};
        host_parity_error = 1'b0;
        compute_parity_error = 1'b0;
        banked_parity_error = 4'b0;
        line_parity_error = 4'b0;
    end
endmodule
