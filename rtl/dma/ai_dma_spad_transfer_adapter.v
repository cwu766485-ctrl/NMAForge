// Combinational adapter between DMA burst state and scratchpad transactions.
// It neither stores state nor participates in AXI handshakes: ai_axi128_dma
// remains the sole owner of transfer lifecycle and response bookkeeping.
module ai_dma_spad_transfer_adapter (
    input  wire         read_active,
    input  wire         rd_drain_found,
    input  wire [15:0]  rd_word_index,
    input  wire [15:0]  rd_words,
    input  wire [31:0]  rd_spad_base,
    input  wire         rd_wide,
    input  wire [1:0]   rd_narrow_lane,
    input  wire [127:0] rd_data,

    input  wire         gather_need_index,
    input  wire         gather_wait_rsp,
    input  wire [31:0]  gather_index_base,
    input  wire [15:0]  gather_row_index,

    input  wire         write_gather_active,
    input  wire         wr_read_pending,
    input  wire [15:0]  wr_burst_words,
    input  wire [15:0]  wr_word_index,
    input  wire [31:0]  wr_spad_base,

    output wire [4:0]   rd_beat_index,
    output wire         rd_line_eligible,
    output wire         wr_line_eligible,

    output reg          spad_valid,
    output reg          spad_write,
    output reg  [31:0]  spad_addr,
    output reg  [31:0]  spad_wdata,
    output reg          spad_line_valid,
    output reg          spad_line_write,
    output reg  [31:0]  spad_line_addr,
    output reg  [127:0] spad_line_wdata,
    output reg  [15:0]  spad_line_wstrb
);

    wire [1:0]  rd_lane = rd_wide ? rd_word_index[1:0] : rd_narrow_lane;
    wire [15:0] rd_words_left = rd_words - rd_word_index;
    wire [31:0] rd_spad_addr = rd_spad_base + ({16'd0, rd_word_index} << 2);
    wire [15:0] wr_words_left = wr_burst_words - wr_word_index;
    wire [31:0] wr_spad_addr = wr_spad_base + ({16'd0, wr_word_index} << 2);

    assign rd_beat_index = rd_word_index[15:2];
    assign rd_line_eligible = rd_drain_found &&
                              rd_spad_addr[3:0] == 0 &&
                              rd_word_index[1:0] == 0 &&
                              rd_words_left >= 4;

    assign wr_line_eligible = write_gather_active &&
                              wr_spad_addr[3:0] == 0 &&
                              wr_word_index[1:0] == 0 &&
                              wr_words_left >= 4;

    always @* begin
        spad_valid      = 1'b0;
        spad_write      = 1'b0;
        spad_addr       = 32'd0;
        spad_wdata      = 32'd0;
        spad_line_valid = 1'b0;
        spad_line_write = 1'b0;
        spad_line_addr  = 32'd0;
        spad_line_wdata = 128'd0;
        spad_line_wstrb = 16'd0;

        if (read_active && rd_line_eligible) begin
            spad_line_valid = 1'b1;
            spad_line_write = 1'b1;
            spad_line_addr  = rd_spad_addr;
            spad_line_wdata = rd_data;
            spad_line_wstrb = 16'hffff;
        end else if (read_active && rd_drain_found) begin
            spad_valid = 1'b1;
            spad_write = 1'b1;
            spad_addr  = rd_spad_addr;
            case (rd_lane)
              2'd0: spad_wdata = rd_data[31:0];
              2'd1: spad_wdata = rd_data[63:32];
              2'd2: spad_wdata = rd_data[95:64];
              default: spad_wdata = rd_data[127:96];
            endcase
        end else if (read_active && gather_need_index && !gather_wait_rsp) begin
            spad_valid = 1'b1;
            spad_addr  = gather_index_base + ({16'd0, gather_row_index} << 2);
        end else if (write_gather_active && !wr_read_pending) begin
            if (wr_line_eligible) begin
                spad_line_valid = 1'b1;
                spad_line_addr  = wr_spad_addr;
            end else begin
                spad_valid = 1'b1;
                spad_addr  = wr_spad_addr;
            end
        end
    end

endmodule
