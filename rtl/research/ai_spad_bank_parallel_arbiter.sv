`timescale 1ns/1ps

// BPF-TE research primitive. Four logical request slots feed four independently
// decoded bank ports. The bank memory must return bank_rsp_valid/data/error two
// cycles after a read request; this module owns only admission and tags.
module ai_spad_bank_parallel_arbiter #(
    parameter integer BANKS = 4,
    parameter integer REQUESTERS = 4,
    parameter integer OWNER_BITS = 3,
    parameter integer TILE_BITS = 8,
    parameter integer EPOCH_BITS = 4
) (
    input  wire                         clk,
    input  wire                         resetn,
    input  wire                         epoch_bump,
    input  wire [REQUESTERS-1:0]        req_valid,
    input  wire [REQUESTERS-1:0]        req_write,
    input  wire [REQUESTERS*32-1:0]     req_addr,
    input  wire [REQUESTERS*32-1:0]     req_wdata,
    input  wire [REQUESTERS*OWNER_BITS-1:0] req_owner,
    input  wire [REQUESTERS*TILE_BITS-1:0] req_tile,
    output wire [REQUESTERS-1:0]        req_ready,
    output wire [REQUESTERS-1:0]        req_accept,
    output wire [REQUESTERS-1:0]        req_denied,
    output wire [REQUESTERS-1:0]        req_backpressure,
    output wire [BANKS-1:0]             bank_req_valid,
    output wire [BANKS-1:0]             bank_req_write,
    output wire [BANKS*32-1:0]          bank_req_addr,
    output wire [BANKS*32-1:0]          bank_req_wdata,
    input  wire [BANKS-1:0]             bank_rsp_valid,
    input  wire [BANKS*32-1:0]          bank_rsp_rdata,
    input  wire [BANKS-1:0]             bank_rsp_error,
    output wire [BANKS-1:0]             rsp_valid,
    output wire [BANKS*32-1:0]          rsp_rdata,
    output wire [BANKS*OWNER_BITS-1:0]  rsp_owner_flat,
    output wire [BANKS-1:0]             rsp_error,
    output wire [BANKS*2-1:0]           rsp_bank_flat,
    output wire [BANKS*TILE_BITS-1:0]   rsp_tile,
    output wire [BANKS*EPOCH_BITS-1:0]  rsp_epoch,
    output wire [EPOCH_BITS-1:0]        current_epoch,
    output wire [BANKS-1:0]             bank_busy
);
    localparam integer BANK_BITS = (BANKS <= 2) ? 1 : $clog2(BANKS);
    reg [BANK_BITS-1:0] rr_ptr [0:BANKS-1];
    reg [REQUESTERS-1:0] grant;
    reg [BANKS-1:0] grant_bank;
    reg [31:0] grant_addr [0:BANKS-1];
    reg [31:0] grant_wdata [0:BANKS-1];
    reg grant_write [0:BANKS-1];
    reg [OWNER_BITS-1:0] grant_owner [0:BANKS-1];
    reg [TILE_BITS-1:0] grant_tile [0:BANKS-1];
    reg [REQUESTERS-1:0] ready_r;
    reg [BANKS-1:0] bank_req_valid_r, bank_req_write_r;
    reg [BANKS*32-1:0] bank_req_addr_r, bank_req_wdata_r;
    reg [EPOCH_BITS-1:0] epoch_r;
    reg [BANKS-1:0] tag_valid0, tag_valid1, tag_valid2;
    reg [OWNER_BITS-1:0] tag_owner0 [0:BANKS-1], tag_owner1 [0:BANKS-1], tag_owner2 [0:BANKS-1];
    reg [TILE_BITS-1:0] tag_tile0 [0:BANKS-1], tag_tile1 [0:BANKS-1], tag_tile2 [0:BANKS-1];
    reg [EPOCH_BITS-1:0] tag_epoch0 [0:BANKS-1], tag_epoch1 [0:BANKS-1], tag_epoch2 [0:BANKS-1];
    wire [BANKS*EPOCH_BITS-1:0] tag_epoch2_flat;
    integer b, s, off, idx, selected;

    assign req_ready = ready_r;
    assign req_accept = ready_r;
    assign req_denied = req_valid & ~ready_r;
    assign req_backpressure = req_denied;
    assign bank_req_valid = bank_req_valid_r;
    assign bank_req_write = bank_req_write_r;
    assign bank_req_addr = bank_req_addr_r;
    assign bank_req_wdata = bank_req_wdata_r;
    assign current_epoch = epoch_r;
    assign bank_busy = tag_valid0 | tag_valid1 | tag_valid2;

    genvar g;
    generate for (g=0; g<BANKS; g=g+1) begin : GEN_RSP
        assign tag_epoch2_flat[g*EPOCH_BITS +: EPOCH_BITS] = tag_epoch2[g];
        assign rsp_valid[g] = tag_valid2[g] && bank_rsp_valid[g] &&
                              (tag_epoch2[g] == epoch_r);
        assign rsp_rdata[g*32 +: 32] = bank_rsp_rdata[g*32 +: 32];
        assign rsp_owner_flat[g*OWNER_BITS +: OWNER_BITS] = tag_owner2[g];
        assign rsp_tile[g*TILE_BITS +: TILE_BITS] = tag_tile2[g];
        assign rsp_epoch[g*EPOCH_BITS +: EPOCH_BITS] = tag_epoch2[g];
        assign rsp_error[g] = rsp_valid[g] && bank_rsp_error[g];
        assign rsp_bank_flat[g*2 +: 2] = g[1:0];
    end endgenerate

    // Decode and arbitrate independently for each physical bank. A request
    // slot can win only one bank; different banks can win concurrently.
    always @(*) begin
        ready_r = {REQUESTERS{1'b0}};
        grant = {REQUESTERS{1'b0}};
        bank_req_valid_r = {BANKS{1'b0}};
        bank_req_write_r = {BANKS{1'b0}};
        bank_req_addr_r = {(BANKS*32){1'b0}};
        bank_req_wdata_r = {(BANKS*32){1'b0}};
        for (b=0; b<BANKS; b=b+1) begin
            selected = -1;
            for (off=0; off<REQUESTERS; off=off+1) begin
                idx = rr_ptr[b] + off;
                if (idx >= REQUESTERS) idx = idx - REQUESTERS;
                if (selected < 0 && req_valid[idx] &&
                    (req_addr[idx*32 + 3 -: 2] == b[1:0]))
                    selected = idx;
            end
            if (selected >= 0) begin
                grant[selected] = 1'b1;
                ready_r[selected] = 1'b1;
                bank_req_valid_r[b] = 1'b1;
                bank_req_write_r[b] = req_write[selected];
                bank_req_addr_r[b*32 +: 32] = req_addr[selected*32 +: 32];
                bank_req_wdata_r[b*32 +: 32] = req_wdata[selected*32 +: 32];
            end
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            epoch_r <= {EPOCH_BITS{1'b0}};
            for (b=0; b<BANKS; b=b+1) begin
                rr_ptr[b] <= {BANK_BITS{1'b0}};
                tag_valid0[b] <= 1'b0;
                tag_valid1[b] <= 1'b0;
                tag_valid2[b] <= 1'b0;
                tag_owner0[b] <= {OWNER_BITS{1'b0}};
                tag_owner1[b] <= {OWNER_BITS{1'b0}};
                tag_tile0[b] <= {TILE_BITS{1'b0}};
                tag_tile1[b] <= {TILE_BITS{1'b0}};
                tag_epoch0[b] <= {EPOCH_BITS{1'b0}};
                tag_epoch1[b] <= {EPOCH_BITS{1'b0}};
            end
        end else if (epoch_bump) begin
            epoch_r <= epoch_r + 1'b1;
            for (b=0; b<BANKS; b=b+1) begin
                tag_valid0[b] <= 1'b0;
                tag_valid1[b] <= 1'b0;
                tag_valid2[b] <= 1'b0;
            end
        end else begin
            for (b=0; b<BANKS; b=b+1) begin
                tag_valid1[b] <= tag_valid0[b];
                tag_owner1[b] <= tag_owner0[b];
                tag_tile1[b] <= tag_tile0[b];
                tag_epoch1[b] <= tag_epoch0[b];
                tag_valid2[b] <= tag_valid1[b];
                tag_owner2[b] <= tag_owner1[b];
                tag_tile2[b] <= tag_tile1[b];
                tag_epoch2[b] <= tag_epoch1[b];
                tag_valid0[b] <= bank_req_valid_r[b] && !bank_req_write_r[b];
                if (bank_req_valid_r[b]) begin
                    // Metadata comes from the selected request, preserving
                    // ownership even when the bank response is interleaved.
                    for (s=0; s<REQUESTERS; s=s+1) begin
                        if (grant[s] && (req_addr[s*32 + 3 -: 2] == b[1:0])) begin
                            tag_owner0[b] <= req_owner[s*OWNER_BITS +: OWNER_BITS];
                            tag_tile0[b] <= req_tile[s*TILE_BITS +: TILE_BITS];
                        end
                    end
                    tag_epoch0[b] <= epoch_r;
                    rr_ptr[b] <= (rr_ptr[b] == REQUESTERS-1) ?
                                  {BANK_BITS{1'b0}} : rr_ptr[b] + 1'b1;
                end
            end
        end
    end

endmodule
