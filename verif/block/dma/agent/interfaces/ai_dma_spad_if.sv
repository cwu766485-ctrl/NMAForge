interface ai_dma_spad_if(input logic clk, input logic resetn);
    logic spad_valid; logic spad_write; logic [31:0] spad_addr; logic [31:0] spad_wdata;
    logic spad_ready; logic spad_rsp_valid; logic [31:0] spad_rdata;
    logic spad_req_error; logic spad_rsp_error;
    logic line_valid; logic line_write; logic [31:0] line_addr;
    logic [127:0] line_wdata; logic [15:0] line_wstrb;
    logic line_ready; logic line_rsp_valid; logic [127:0] line_rdata;
    logic line_req_error; logic line_rsp_error; logic [3:0] line_parity_error;
endinterface
