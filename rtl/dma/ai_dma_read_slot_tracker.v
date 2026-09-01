module ai_dma_read_slot_tracker #(
    parameter integer MAX_OUTSTANDING = 4,
    parameter [3:0] READ_ID_FIRST = 4'd1,
    parameter [3:0] READ_ID_LAST  = 4'd4
) (
    input  wire [3:0] rd_slot_valid,
    input  wire [3:0] rd_slot_complete,
    input  wire [3:0] m_axi_rid,
    output reg  [2:0] rd_count,
    output reg  [1:0] rd_free_slot,
    output reg        rd_free_found,
    output reg  [1:0] rd_drain_slot,
    output reg        rd_drain_found,
    output reg  [1:0] rd_rid_index,
    output reg        rid_is_dma
);

    integer i;

    always @* begin
        rd_count       = 3'd0;
        rd_free_slot   = 2'd0;
        rd_free_found  = 1'b0;
        rd_drain_slot  = 2'd0;
        rd_drain_found = 1'b0;

        for (i = 0; i < 4; i = i + 1) begin
            if (rd_slot_valid[i])
                rd_count = rd_count + 3'd1;

            if (!rd_slot_valid[i] && !rd_free_found &&
                (i < MAX_OUTSTANDING)) begin
                rd_free_found = 1'b1;
                rd_free_slot  = i[1:0];
            end

            if (rd_slot_complete[i] && !rd_drain_found) begin
                rd_drain_found = 1'b1;
                rd_drain_slot  = i[1:0];
            end
        end

        rid_is_dma  = (m_axi_rid >= READ_ID_FIRST) &&
                      (m_axi_rid <= READ_ID_LAST);
        rd_rid_index = m_axi_rid - READ_ID_FIRST;
    end

endmodule
