module ai_dma_spad_subsystem_sva (
    input logic clk,
    input logic resetn,
    input logic desc_valid,
    input logic desc_ready,
    input logic cpl_valid,
    input logic cpl_ready,
    input logic core_valid,
    input logic core_ready,
    input logic [3:0] cnm_valid,
    input logic [3:0] cnm_ready,
    input logic [31:0] cnm_addr0,
    input logic [31:0] cnm_addr1,
    input logic [31:0] cnm_addr2,
    input logic [31:0] cnm_addr3,
    input logic [3:0] cnm_rsp_valid,
    input logic cnm_protection_error,
    input logic dma_valid,
    input logic dma_ready,
    input logic dma_line_valid,
    input logic dma_line_ready,
    input logic [2:0] request_client,
    input logic rsp_valid,
    input logic [2:0] rsp_client,
    input logic rsp_is_line,
    input logic desc_rsp_valid,
    input logic core_rsp_valid,
    input logic banked_rsp_valid,
    input logic dma_rsp_valid,
    input logic dma_line_rsp_valid
);
    default clocking cb @(posedge clk); endclocking
    default disable iff (!resetn);

    ap_desc_priority: assert property (
        desc_valid |-> (desc_ready && !cpl_ready && !core_ready && !dma_ready && !dma_line_ready));
    ap_cpl_priority: assert property (
        (!desc_valid && cpl_valid) |-> (cpl_ready && !core_ready && !dma_ready && !dma_line_ready));
    ap_core_grant_owner: assert property (core_ready |-> core_valid && request_client == 3'd2);
    ap_cnm_grant_owner: assert property ((|cnm_ready) |-> (|cnm_valid) &&
                                         (cnm_ready == 4'hf) && request_client == 3'd5);
    ap_cnm_grant_exclusive: assert property ((|cnm_ready) |->
        !desc_ready && !cpl_ready && !core_ready && !dma_ready && !dma_line_ready);
    ap_cnm_request_stable_when_stalled: assert property (
        ((|cnm_valid) && !(|cnm_ready)) |=>
        (cnm_valid == $past(cnm_valid)) &&
        (cnm_addr0 == $past(cnm_addr0)) && (cnm_addr1 == $past(cnm_addr1)) &&
        (cnm_addr2 == $past(cnm_addr2)) && (cnm_addr3 == $past(cnm_addr3)));
    ap_dma_scalar_grant_owner: assert property (dma_ready |-> dma_valid && request_client == 3'd4);
    ap_dma_line_grant_owner: assert property (dma_line_ready |-> dma_line_valid && request_client == 3'd4);
    ap_single_scheduler_grant: assert property (
        $onehot0({desc_ready, cpl_ready, core_ready, dma_ready, dma_line_ready}));

    ap_desc_response_tag: assert property (
        desc_rsp_valid |-> rsp_valid && rsp_client == 3'd0 && !rsp_is_line);
    ap_core_response_tag: assert property (
        core_rsp_valid |-> rsp_valid && rsp_client == 3'd2 && !rsp_is_line);
    ap_banked_response_tag: assert property (
        banked_rsp_valid |-> rsp_valid && rsp_client == 3'd3);
    ap_cnm_response_tag: assert property (
        (|cnm_rsp_valid) |-> rsp_valid && rsp_client == 3'd5);
    ap_cnm_protection_error_response_tag: assert property (
        cnm_protection_error |-> (|cnm_rsp_valid) && rsp_valid && rsp_client == 3'd5);
    ap_dma_scalar_response_tag: assert property (
        dma_rsp_valid |-> rsp_valid && rsp_client == 3'd4 && !rsp_is_line);
    ap_dma_line_response_tag: assert property (
        dma_line_rsp_valid |-> rsp_valid && rsp_client == 3'd4 && rsp_is_line);
    ap_single_response_owner: assert property (
        $onehot0({desc_rsp_valid, core_rsp_valid, banked_rsp_valid,
                  (|cnm_rsp_valid), dma_rsp_valid, dma_line_rsp_valid}));
endmodule
