interface ai_dma_ctrl_if(input logic clk);
    logic         resetn;
    logic         start;
    logic         abort;
    logic         store;
    logic [63:0]  ext_addr;
    logic [31:0]  spad_addr;
    logic [15:0]  length_words;
    logic [15:0]  row_words;
    logic [15:0]  row_count;
    logic [31:0]  ext_stride;
    logic [31:0]  spad_stride;
    logic         gather_enable;
    logic [31:0]  gather_index_base;
    logic [2:0]   read_outstanding;

    logic         busy;
    logic         done;
    logic         error;
    logic [3:0]   error_code;
    logic [2:0]   rd_outstanding;
    logic [2:0]   rd_highwater;

    initial begin
        resetn = 0; start = 0; abort = 0; store = 0;
        ext_addr = '0; spad_addr = '0; length_words = '0;
        row_words = '0; row_count = '0; ext_stride = '0; spad_stride = '0;
        gather_enable = 0; gather_index_base = '0; read_outstanding = 3'd4;
    end
endinterface
