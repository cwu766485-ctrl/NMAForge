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

    always @* begin
        rd_count       = {2'd0, rd_slot_valid[0]} +
                         {2'd0, rd_slot_valid[1]} +
                         {2'd0, rd_slot_valid[2]} +
                         {2'd0, rd_slot_valid[3]};
        rd_free_slot   = 2'd0;
        rd_free_found  = 1'b0;
        rd_drain_slot  = 2'd0;
        rd_drain_found = 1'b0;

        if ((MAX_OUTSTANDING > 0) && !rd_slot_valid[0]) begin
            rd_free_found = 1'b1;
            rd_free_slot  = 2'd0;
        end else if ((MAX_OUTSTANDING > 1) && !rd_slot_valid[1]) begin
            rd_free_found = 1'b1;
            rd_free_slot  = 2'd1;
        end else if ((MAX_OUTSTANDING > 2) && !rd_slot_valid[2]) begin
            rd_free_found = 1'b1;
            rd_free_slot  = 2'd2;
        end else if ((MAX_OUTSTANDING > 3) && !rd_slot_valid[3]) begin
            rd_free_found = 1'b1;
            rd_free_slot  = 2'd3;
        end

        if (rd_slot_complete[0]) begin
            rd_drain_found = 1'b1;
            rd_drain_slot  = 2'd0;
        end else if (rd_slot_complete[1]) begin
            rd_drain_found = 1'b1;
            rd_drain_slot  = 2'd1;
        end else if (rd_slot_complete[2]) begin
            rd_drain_found = 1'b1;
            rd_drain_slot  = 2'd2;
        end else if (rd_slot_complete[3]) begin
            rd_drain_found = 1'b1;
            rd_drain_slot  = 2'd3;
        end

        rid_is_dma  = (m_axi_rid >= READ_ID_FIRST) &&
                      (m_axi_rid <= READ_ID_LAST);
        rd_rid_index = m_axi_rid - READ_ID_FIRST;
    end

endmodule
