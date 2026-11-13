`timescale 1ns/1ps
// Non-vacuous protocol assertions for the isolated BPF-TE primitive.
module ai_spad_bank_parallel_arbiter_sva #(
    parameter integer BANKS=4, REQUESTERS=4, EPOCH_BITS=4
) (
    input wire clk, input wire resetn,
    input wire [REQUESTERS-1:0] req_accept,
    input wire [REQUESTERS*32-1:0] req_addr,
    input wire [BANKS-1:0] bank_req_valid,
    input wire [BANKS-1:0] rsp_valid,
    input wire [BANKS-1:0] tag_valid2,
    input wire [BANKS*EPOCH_BITS-1:0] tag_epoch2,
    input wire [EPOCH_BITS-1:0] current_epoch
);
    genvar s, b;
    generate
        for (s=0; s<REQUESTERS; s=s+1) begin : ACCEPT_MAP
            assert property (@(posedge clk) disable iff (!resetn)
                req_accept[s] |-> bank_req_valid[req_addr[s*32 + 3 -: 2]]);
        end
        for (b=0; b<BANKS; b=b+1) begin : RESPONSE_TAG
            assert property (@(posedge clk) disable iff (!resetn)
                rsp_valid[b] |-> (tag_valid2[b] &&
                  (tag_epoch2[b*EPOCH_BITS +: EPOCH_BITS] == current_epoch)));
        end
    endgenerate
endmodule

bind ai_spad_bank_parallel_arbiter ai_spad_bank_parallel_arbiter_sva #(
    .BANKS(BANKS), .REQUESTERS(REQUESTERS), .EPOCH_BITS(EPOCH_BITS)
) bpf_te_sva (
    .clk(clk), .resetn(resetn), .req_accept(req_accept), .req_addr(req_addr),
    .bank_req_valid(bank_req_valid), .rsp_valid(rsp_valid),
    .tag_valid2(tag_valid2), .tag_epoch2(tag_epoch2_flat),
    .current_epoch(epoch_r)
);
