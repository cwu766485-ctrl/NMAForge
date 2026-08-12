interface ai_dma_axi_if(input logic clk, input logic resetn);
    logic [3:0] arid; logic arvalid; logic [63:0] araddr; logic [7:0] arlen;
    logic [2:0] arsize; logic [1:0] arburst; logic arready;
    logic [3:0] rid; logic [127:0] rdata; logic [1:0] rresp;
    logic rvalid; logic rlast; logic rready;
    logic [3:0] awid; logic awvalid; logic [63:0] awaddr; logic [7:0] awlen;
    logic [2:0] awsize; logic [1:0] awburst; logic awready;
    logic [127:0] wdata; logic [15:0] wstrb; logic wvalid; logic wlast; logic wready;
    logic [3:0] bid; logic [1:0] bresp; logic bvalid; logic bready;
endinterface
