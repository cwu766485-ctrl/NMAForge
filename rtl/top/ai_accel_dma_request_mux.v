module ai_accel_dma_request_mux (
    input  wire        tile_active,

    input  wire        dma_start,
    input  wire        dma_store,
    input  wire [63:0] dma_ext_addr,
    input  wire [31:0] dma_spad_addr,
    input  wire [15:0] dma_length_words,
    input  wire [15:0] dma_row_words,
    input  wire [15:0] dma_row_count,
    input  wire [31:0] dma_ext_stride,
    input  wire [31:0] dma_spad_stride,
    input  wire        dma_gather_enable,
    input  wire [31:0] dma_gather_index_base,
    input  wire [2:0]  dma_read_outstanding,

    input  wire        tile_dma_start,
    input  wire        tile_dma_store,
    input  wire [63:0] tile_dma_ext_addr,
    input  wire [31:0] tile_dma_spad_addr,
    input  wire [15:0] tile_dma_length_words,

    output wire        dma_start_mux,
    output wire        dma_store_mux,
    output wire [63:0] dma_ext_addr_mux,
    output wire [31:0] dma_spad_addr_mux,
    output wire [15:0] dma_length_words_mux,
    output wire [15:0] dma_row_words_mux,
    output wire [15:0] dma_row_count_mux,
    output wire [31:0] dma_ext_stride_mux,
    output wire [31:0] dma_spad_stride_mux,
    output wire        dma_gather_enable_mux,
    output wire [31:0] dma_gather_index_base_mux,
    output wire [2:0]  dma_read_outstanding_mux
);

    assign dma_start_mux = tile_active ? tile_dma_start : dma_start;
    assign dma_store_mux = tile_active ? tile_dma_store : dma_store;
    assign dma_ext_addr_mux = tile_active ? tile_dma_ext_addr : dma_ext_addr;
    assign dma_spad_addr_mux = tile_active ? tile_dma_spad_addr : dma_spad_addr;
    assign dma_length_words_mux = tile_active ? tile_dma_length_words : dma_length_words;
    assign dma_row_words_mux = tile_active ? 16'd0 : dma_row_words;
    assign dma_row_count_mux = tile_active ? 16'd0 : dma_row_count;
    assign dma_ext_stride_mux = tile_active ? 32'd0 : dma_ext_stride;
    assign dma_spad_stride_mux = tile_active ? 32'd0 : dma_spad_stride;
    assign dma_gather_enable_mux = tile_active ? 1'b0 : dma_gather_enable;
    assign dma_gather_index_base_mux = tile_active ? 32'd0 : dma_gather_index_base;
    assign dma_read_outstanding_mux = tile_active ? 3'd1 : dma_read_outstanding;

endmodule
