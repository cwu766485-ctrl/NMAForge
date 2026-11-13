`timescale 1ns/1ps

// Legacy Matrix-Line/CNM transaction adapter for the BPF-TE primitive.
// Exactly four bank slots are presented together. line_ready and cnm_ready
// are all-or-none: no partial line or partial four-lane CNM transaction is
// exposed to the caller.
module ai_bpf_te_atomic_adapter #(
    parameter integer BANKS=4, OWNER_BITS=3, TILE_BITS=8, EPOCH_BITS=4
) (
    input wire clk, input wire resetn, input wire epoch_bump,
    input wire line_valid, input wire line_write, input wire [31:0] line_addr,
    input wire [127:0] line_wdata, input wire [15:0] line_wstrb,
    input wire [OWNER_BITS-1:0] line_owner, input wire [TILE_BITS-1:0] line_tile,
    output wire line_ready, output wire line_rsp_valid,
    output wire [127:0] line_rsp_rdata, output wire [3:0] line_rsp_error,
    input wire [3:0] cnm_valid, input wire [31:0] cnm_addr0, input wire [31:0] cnm_addr1,
    input wire [31:0] cnm_addr2, input wire [31:0] cnm_addr3,
    input wire [OWNER_BITS-1:0] cnm_owner, input wire [TILE_BITS-1:0] cnm_tile,
    output wire [3:0] cnm_ready, output wire [3:0] cnm_rsp_valid,
    output wire [127:0] cnm_rsp_rdata, output wire [3:0] cnm_rsp_error,
    input wire matrix_valid, input wire [31:0] matrix_addr,
    input wire [OWNER_BITS-1:0] matrix_owner, input wire [TILE_BITS-1:0] matrix_tile,
    output wire matrix_ready, output wire matrix_rsp_valid,
    output wire [127:0] matrix_rsp_rdata, output wire [3:0] matrix_rsp_error,
    output wire [BANKS-1:0] bank_req_valid, output wire [BANKS-1:0] bank_req_write,
    output wire [BANKS*32-1:0] bank_req_addr, output wire [BANKS*32-1:0] bank_req_wdata,
    output wire [BANKS*4-1:0] bank_req_wstrb, input wire [BANKS-1:0] bank_ready,
    input wire [BANKS-1:0] bank_rsp_valid, input wire [BANKS*32-1:0] bank_rsp_rdata,
    input wire [BANKS-1:0] bank_rsp_error,
    output wire [BANKS-1:0] rsp_dropped
);
    wire [3:0] req_valid, req_write, req_ready, req_accept, req_denied, req_bp;
    wire [127:0] slot_addr, slot_wdata; wire [15:0] slot_wstrb;
    wire [11:0] slot_owner; wire [31:0] slot_tile;
    wire [BANKS-1:0] rsp_valid, rsp_error_int; wire [BANKS*32-1:0] rsp_data;
    wire [BANKS*OWNER_BITS-1:0] rsp_owner; wire [BANKS*2-1:0] rsp_bank;
    wire [BANKS*TILE_BITS-1:0] rsp_tile; wire [BANKS*EPOCH_BITS-1:0] rsp_epoch; wire [EPOCH_BITS-1:0] epoch_now;
    reg mode_line_r, mode_cnm_r, mode_matrix_r;
    wire line_rsp_valid_int;
    reg inflight_r;
    wire line_shape_ok = line_valid && (line_addr[3:0] == 0);
    wire cnm_shape_ok = (cnm_valid == 4'b1111) &&
                        (cnm_addr0[3:2] == 0) && (cnm_addr1[3:2] == 1) &&
                        (cnm_addr2[3:2] == 2) && (cnm_addr3[3:2] == 3);
    // Case equality keeps legacy instantiations (which predate the optional
    // Matrix banked-read port) inactive when the newly added input is left
    // unconnected. Connected RTL drives a two-state 0/1 signal.
    wire matrix_shape_ok = (matrix_valid === 1'b1) && (matrix_addr[3:0] == 0);
    wire bank_reservation_ok = &bank_ready;
    wire txn_slot_free = !inflight_r || (&rsp_valid);
    wire use_line = line_shape_ok && txn_slot_free && bank_reservation_ok;
    wire use_matrix = matrix_shape_ok && txn_slot_free && bank_reservation_ok && !use_line;
    wire use_cnm = cnm_shape_ok && txn_slot_free && bank_reservation_ok && !use_line && !use_matrix;
    assign req_valid = (use_line || use_matrix || use_cnm) ? 4'b1111 : 4'b0;
    assign req_write = use_line ? {4{line_write}} : 4'b0;
    assign slot_addr = use_line ? {line_addr+32'd12,line_addr+32'd8,line_addr+32'd4,line_addr} :
                       use_matrix ? {matrix_addr+32'd12,matrix_addr+32'd8,matrix_addr+32'd4,matrix_addr} :
                       {cnm_addr3,cnm_addr2,cnm_addr1,cnm_addr0};
    assign slot_wdata = line_wdata;
    assign slot_wstrb = line_wstrb;
    assign slot_owner = use_line ? {4{line_owner}} : use_matrix ? {4{matrix_owner}} : {4{cnm_owner}};
    assign slot_tile = use_line ? {4{line_tile}} : use_matrix ? {4{matrix_tile}} : {4{cnm_tile}};
    assign line_ready = use_line && (&req_ready);
    assign cnm_ready = use_cnm ? {4{&req_ready}} : 4'b0;
    assign matrix_ready = use_matrix && (&req_ready);
    assign line_rsp_valid = line_rsp_valid_int;
    assign line_rsp_rdata = rsp_data;
    assign line_rsp_error = rsp_error_int & {4{mode_line_r}};
    assign cnm_rsp_valid = rsp_valid & {4{mode_cnm_r}};
    assign cnm_rsp_rdata = rsp_data;
    assign cnm_rsp_error = rsp_error_int & {4{mode_cnm_r}};
    assign matrix_rsp_valid = (&rsp_valid) && mode_matrix_r;
    assign matrix_rsp_rdata = rsp_data;
    assign matrix_rsp_error = rsp_error_int & {4{mode_matrix_r}};

    assign line_rsp_valid_int = (&rsp_valid) && mode_line_r;
    ai_spad_bank_parallel_arbiter #(.BANKS(BANKS),.REQUESTERS(4),.OWNER_BITS(OWNER_BITS),.TILE_BITS(TILE_BITS),.EPOCH_BITS(EPOCH_BITS)) arb (
      .clk(clk),.resetn(resetn),.epoch_bump(epoch_bump),.req_valid(req_valid),.req_write(req_write),
      .req_addr(slot_addr),.req_wdata(slot_wdata),.req_wstrb(slot_wstrb),.req_owner(slot_owner),.req_tile(slot_tile),
      .req_ready(req_ready),.req_accept(req_accept),.req_denied(req_denied),.req_backpressure(req_bp),
      .bank_req_valid(bank_req_valid),.bank_req_write(bank_req_write),.bank_req_addr(bank_req_addr),
      .bank_req_wdata(bank_req_wdata),.bank_req_wstrb(bank_req_wstrb),.bank_rsp_valid(bank_rsp_valid),
      .bank_rsp_rdata(bank_rsp_rdata),.bank_rsp_error(bank_rsp_error),.bank_ready(bank_ready),
      .rsp_valid(rsp_valid),.rsp_rdata(rsp_data),.rsp_owner_flat(rsp_owner),.rsp_error(rsp_error_int),.rsp_bank_flat(rsp_bank),
      .rsp_tile(rsp_tile),.rsp_epoch(rsp_epoch),.rsp_dropped(rsp_dropped),.current_epoch(epoch_now),.bank_busy());

    always @(posedge clk or negedge resetn) begin
      if (!resetn) begin mode_line_r<=1'b0; mode_cnm_r<=1'b0; mode_matrix_r<=1'b0; inflight_r<=1'b0; end
      else begin
        if (&rsp_valid) begin mode_line_r<=1'b0; mode_cnm_r<=1'b0; mode_matrix_r<=1'b0; end
        if (line_ready && !line_write) begin mode_line_r<=1'b1; inflight_r<=1'b1; end
        if (matrix_ready) begin mode_matrix_r<=1'b1; inflight_r<=1'b1; end
        if (&cnm_ready) begin mode_cnm_r<=1'b1; inflight_r<=1'b1; end
        if (line_ready && line_write) inflight_r<=1'b0;
        if (&rsp_valid) inflight_r<=1'b0;
      end
    end
endmodule
