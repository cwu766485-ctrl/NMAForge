module ai_dma_write_response_tracker #(
    parameter [3:0] WRITE_ID_FIRST = 4'd8,
    parameter [3:0] WRITE_ID_LAST  = 4'd11
) (
    input  wire [3:0] wr_pending_b,
    input  wire [3:0] m_axi_bid,
    output reg  [1:0] wr_bid_index,
    output reg        bid_is_dma,
    output reg  [1:0] wr_free_tag,
    output reg        wr_free_found
);

    always @* begin
        bid_is_dma = (m_axi_bid >= WRITE_ID_FIRST) &&
                     (m_axi_bid <= WRITE_ID_LAST);
        wr_bid_index = m_axi_bid - WRITE_ID_FIRST;

        wr_free_tag   = 2'd0;
        wr_free_found = 1'b0;
        if (!wr_pending_b[0]) begin
            wr_free_found = 1'b1;
            wr_free_tag   = 2'd0;
        end else if (!wr_pending_b[1]) begin
            wr_free_found = 1'b1;
            wr_free_tag   = 2'd1;
        end else if (!wr_pending_b[2]) begin
            wr_free_found = 1'b1;
            wr_free_tag   = 2'd2;
        end else if (!wr_pending_b[3]) begin
            wr_free_found = 1'b1;
            wr_free_tag   = 2'd3;
        end
    end

endmodule
