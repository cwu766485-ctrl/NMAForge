// Combinational scratchpad response demultiplexer.
module ai_spad_response_demux (
    input  wire       arb_rsp_valid,
    input  wire       arb_rsp_error,
    input  wire       arb_rsp_is_line,
    input  wire [2:0] arb_rsp_client,

    output wire       desc_rsp_valid,
    output wire       core_rsp_valid,
    output wire       banked_rsp_valid,
    output wire       dma_rsp_valid,
    output wire       dma_line_rsp_valid,
    output wire       desc_rsp_error,
    output wire       core_rsp_error,
    output wire       dma_rsp_error
);

    assign desc_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd0);
    assign core_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd2) &&
                            !arb_rsp_is_line;
    assign banked_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd3);
    assign dma_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd4) &&
                           !arb_rsp_is_line;
    assign dma_line_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd4) &&
                                arb_rsp_is_line;
    assign desc_rsp_error = desc_rsp_valid && arb_rsp_error;
    assign core_rsp_error = core_rsp_valid && arb_rsp_error;
    assign dma_rsp_error = dma_rsp_valid && arb_rsp_error;

endmodule
