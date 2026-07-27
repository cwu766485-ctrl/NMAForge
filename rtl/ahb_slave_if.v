`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ahb_slave_if
//
// AHB-Lite slave front-end for the SRAM controller.
//
// Implemented protocol boundary:
//   - supports BYTE/HALFWORD/WORD accesses through hsize;
//   - rejects illegal hsize;
//   - rejects unaligned HALFWORD/WORD accesses;
//   - supports SINGLE, INCR, INCR4, INCR8 and INCR16 bursts;
//   - rejects WRAP bursts and malformed SEQ transfers;
//   - inserts configurable wait states through hready_resp;
//   - prevents illegal transfers from reaching the SRAM array.
//
// SRAM address mapping note:
//   This legacy design uses haddr[15:13] for bank/lane selection rather than
//   the conventional haddr[1:0] byte-lane mapping. Low address bits are still
//   checked for AHB alignment legality.
//////////////////////////////////////////////////////////////////////////////////

module ahb_slave_if #(
    parameter integer SRAM_WAIT_CYCLES = 1
)(
    input         hclk,
    input         hresetn,

    input         hsel,
    input         hready,
    input         hwrite,
    input  [1:0]  htrans,
    input  [2:0]  hsize,
    input  [2:0]  hburst,
    input  [31:0] haddr,
    input  [31:0] hwdata,

    input  [7:0]  sram_q0,
    input  [7:0]  sram_q1,
    input  [7:0]  sram_q2,
    input  [7:0]  sram_q3,
    input  [7:0]  sram_q4,
    input  [7:0]  sram_q5,
    input  [7:0]  sram_q6,
    input  [7:0]  sram_q7,

    output [1:0]  hresp,
    output        hready_resp,
    output [31:0] hrdata,

    output        sram_w_en,
    output reg    bank_sel,
    output reg [3:0] bank0_csn,
    output reg [3:0] bank1_csn,
    output [12:0] sram_addr_out,
    output [31:0] sram_wdata
);

    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_BUSY   = 2'b01;
    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    localparam HSIZE_BYTE = 3'b000;
    localparam HSIZE_HALF = 3'b001;
    localparam HSIZE_WORD = 3'b010;

    localparam HBURST_SINGLE = 3'b000;
    localparam HBURST_INCR   = 3'b001;
    localparam HBURST_WRAP4  = 3'b010;
    localparam HBURST_INCR4  = 3'b011;
    localparam HBURST_WRAP8  = 3'b100;
    localparam HBURST_INCR8  = 3'b101;
    localparam HBURST_WRAP16 = 3'b110;
    localparam HBURST_INCR16 = 3'b111;

    localparam HRESP_OKAY  = 2'b00;
    localparam HRESP_ERROR = 2'b01;

    reg         active_r;
    reg         error_r;
    reg         hwrite_r;
    reg  [2:0]  hsize_r;
    reg  [2:0]  hburst_r;
    reg  [1:0]  htrans_r;
    reg  [31:0] haddr_r;
    reg  [7:0]  wait_cnt_r;

    reg         burst_active_r;
    reg  [2:0]  burst_type_r;
    reg  [2:0]  burst_size_r;
    reg  [31:0] burst_next_addr_r;
    reg  [4:0]  burst_left_r;

    reg  [3:0]  sram_csn;
    reg  [31:0] sram_data_out;

    wire [15:0] sram_addr;
    wire [1:0]  haddr_sel;
    wire [1:0]  hsize_sel;

    wire        addr_phase_valid;
    wire        response_phase;
    wire        request_error;
    wire        valid_size;
    wire        aligned_addr;
    wire        supported_burst;
    wire        seq_ok;
    wire        size_stable;
    wire        sram_write;
    wire        sram_read_cmd;
    wire        sram_read_resp;
    wire        sram_csn_en;
    wire [31:0] next_burst_addr;
    wire [4:0]  burst_len;

    function [31:0] size_bytes;
        input [2:0] size;
        begin
            case (size)
                HSIZE_BYTE: size_bytes = 32'd1;
                HSIZE_HALF: size_bytes = 32'd2;
                HSIZE_WORD: size_bytes = 32'd4;
                default:    size_bytes = 32'd0;
            endcase
        end
    endfunction

    function [4:0] burst_total_beats;
        input [2:0] burst;
        begin
            case (burst)
                HBURST_INCR4:  burst_total_beats = 5'd4;
                HBURST_INCR8:  burst_total_beats = 5'd8;
                HBURST_INCR16: burst_total_beats = 5'd16;
                default:       burst_total_beats = 5'd0;
            endcase
        end
    endfunction

    assign addr_phase_valid = hsel && hready &&
                              ((htrans == HTRANS_NONSEQ) || (htrans == HTRANS_SEQ));

    assign response_phase = active_r && (wait_cnt_r == 8'd0);
    assign hready_resp   = !active_r || response_phase;
    assign hresp         = (response_phase && error_r) ? HRESP_ERROR : HRESP_OKAY;
    assign hrdata        = sram_data_out;

    assign valid_size = (hsize == HSIZE_BYTE) ||
                        (hsize == HSIZE_HALF) ||
                        (hsize == HSIZE_WORD);

    assign aligned_addr = (hsize == HSIZE_BYTE) ||
                          ((hsize == HSIZE_HALF) && (haddr[0] == 1'b0)) ||
                          ((hsize == HSIZE_WORD) && (haddr[1:0] == 2'b00));

    assign supported_burst = (hburst == HBURST_SINGLE) ||
                             (hburst == HBURST_INCR)   ||
                             (hburst == HBURST_INCR4)  ||
                             (hburst == HBURST_INCR8)  ||
                             (hburst == HBURST_INCR16);

    assign seq_ok = (htrans != HTRANS_SEQ) ||
                    (burst_active_r && (haddr == burst_next_addr_r));

    assign size_stable = (htrans != HTRANS_SEQ) || (hsize == burst_size_r);

    assign request_error = addr_phase_valid &&
                           (!valid_size || !aligned_addr || !supported_burst ||
                            !seq_ok || !size_stable);

    assign sram_write = response_phase && !error_r && hwrite_r;
    assign sram_read_cmd = active_r && !error_r && !hwrite_r &&
                           (wait_cnt_r <= 8'd1);
    assign sram_read_resp = response_phase && !error_r && !hwrite_r;
    assign sram_w_en  = !sram_write;

    assign sram_addr     = haddr_r[15:0];
    assign sram_addr_out = sram_addr[12:0];
    assign sram_csn_en   = sram_write || sram_read_cmd || sram_read_resp;
    assign haddr_sel     = sram_addr[14:13];
    assign hsize_sel     = hsize_r[1:0];
    assign sram_wdata    = hwdata;
    assign next_burst_addr = haddr + size_bytes(hsize);
    assign burst_len = burst_total_beats(hburst);

    always @(*) begin
        bank0_csn = 4'b1111;
        bank1_csn = 4'b1111;
        bank_sel  = 1'b1;

        if (sram_csn_en) begin
            case (hsize_sel)
                2'b00: begin
                    bank0_csn = (sram_addr[15] == 1'b0) ? sram_csn : 4'b1111;
                    bank1_csn = (sram_addr[15] == 1'b1) ? sram_csn : 4'b1111;
                    bank_sel  = (sram_addr[15] == 1'b0);
                end
                2'b01: begin
                    bank0_csn = (sram_addr[14] == 1'b0) ? sram_csn : 4'b1111;
                    bank1_csn = (sram_addr[14] == 1'b1) ? sram_csn : 4'b1111;
                    bank_sel  = (sram_addr[14] == 1'b0);
                end
                default: begin
                    bank0_csn = (sram_addr[13] == 1'b0) ? sram_csn : 4'b1111;
                    bank1_csn = (sram_addr[13] == 1'b1) ? sram_csn : 4'b1111;
                    bank_sel  = (sram_addr[13] == 1'b0);
                end
            endcase
        end
    end

    always @(*) begin
        sram_data_out = 32'h0000_0000;

        if (sram_read_resp) begin
            if (bank_sel) begin
                case (hsize_sel)
                    2'b00: begin
                        case (haddr_sel)
                            2'b00: sram_data_out = {24'h0, sram_q0};
                            2'b01: sram_data_out = {24'h0, sram_q1};
                            2'b10: sram_data_out = {24'h0, sram_q2};
                            default: sram_data_out = {24'h0, sram_q3};
                        endcase
                    end
                    2'b01: begin
                        if (haddr_sel[0] == 1'b0)
                            sram_data_out = {16'h0, sram_q1, sram_q0};
                        else
                            sram_data_out = {16'h0, sram_q3, sram_q2};
                    end
                    default: begin
                        sram_data_out = {sram_q3, sram_q2, sram_q1, sram_q0};
                    end
                endcase
            end else begin
                case (hsize_sel)
                    2'b00: begin
                        case (haddr_sel)
                            2'b00: sram_data_out = {24'h0, sram_q4};
                            2'b01: sram_data_out = {24'h0, sram_q5};
                            2'b10: sram_data_out = {24'h0, sram_q6};
                            default: sram_data_out = {24'h0, sram_q7};
                        endcase
                    end
                    2'b01: begin
                        if (haddr_sel[0] == 1'b0)
                            sram_data_out = {16'h0, sram_q5, sram_q4};
                        else
                            sram_data_out = {16'h0, sram_q7, sram_q6};
                    end
                    default: begin
                        sram_data_out = {sram_q7, sram_q6, sram_q5, sram_q4};
                    end
                endcase
            end
        end
    end

    always @(*) begin
        sram_csn = 4'b1111;

        case (hsize_sel)
            2'b00: begin
                case (haddr_sel)
                    2'b00: sram_csn = 4'b1110;
                    2'b01: sram_csn = 4'b1101;
                    2'b10: sram_csn = 4'b1011;
                    default: sram_csn = 4'b0111;
                endcase
            end
            2'b01: begin
                sram_csn = (haddr_sel[0] == 1'b0) ? 4'b1100 : 4'b0011;
            end
            2'b10: begin
                sram_csn = 4'b0000;
            end
            default: begin
                sram_csn = 4'b1111;
            end
        endcase
    end

    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            active_r          <= 1'b0;
            error_r           <= 1'b0;
            hwrite_r          <= 1'b0;
            hsize_r           <= 3'b0;
            hburst_r          <= HBURST_SINGLE;
            htrans_r          <= HTRANS_IDLE;
            haddr_r           <= 32'b0;
            wait_cnt_r        <= 8'd0;
            burst_active_r    <= 1'b0;
            burst_type_r      <= HBURST_SINGLE;
            burst_size_r      <= HSIZE_WORD;
            burst_next_addr_r <= 32'b0;
            burst_left_r      <= 5'd0;
        end else begin
            if (active_r) begin
                if (wait_cnt_r != 8'd0)
                    wait_cnt_r <= wait_cnt_r - 8'd1;
                else
                    active_r <= 1'b0;
            end else if (addr_phase_valid) begin
                active_r   <= 1'b1;
                error_r    <= request_error;
                hwrite_r   <= hwrite;
                hsize_r    <= hsize;
                hburst_r   <= hburst;
                htrans_r   <= htrans;
                haddr_r    <= haddr;
                wait_cnt_r <= SRAM_WAIT_CYCLES;

                if (request_error) begin
                    burst_active_r    <= 1'b0;
                    burst_type_r      <= HBURST_SINGLE;
                    burst_size_r      <= HSIZE_WORD;
                    burst_next_addr_r <= 32'b0;
                    burst_left_r      <= 5'd0;
                end else if (htrans == HTRANS_NONSEQ) begin
                    burst_type_r      <= hburst;
                    burst_size_r      <= hsize;
                    burst_next_addr_r <= next_burst_addr;
                    if (hburst == HBURST_SINGLE) begin
                        burst_active_r <= 1'b0;
                        burst_left_r   <= 5'd0;
                    end else if (hburst == HBURST_INCR) begin
                        burst_active_r <= 1'b1;
                        burst_left_r   <= 5'd0;
                    end else begin
                        burst_active_r <= (burst_len > 5'd1);
                        burst_left_r   <= burst_len - 5'd1;
                    end
                end else if (htrans == HTRANS_SEQ) begin
                    burst_next_addr_r <= next_burst_addr;
                    if (burst_type_r == HBURST_INCR) begin
                        burst_active_r <= 1'b1;
                    end else if (burst_left_r > 5'd1) begin
                        burst_left_r   <= burst_left_r - 5'd1;
                        burst_active_r <= 1'b1;
                    end else begin
                        burst_left_r   <= 5'd0;
                        burst_active_r <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
