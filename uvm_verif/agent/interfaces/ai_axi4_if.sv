// Passive observation interface for the accelerator's 128-bit AXI4 master.
interface ai_axi4_if(input logic aclk, input logic aresetn);
    logic [3:0] arid; logic [63:0] araddr; logic [7:0] arlen; logic [2:0] arsize;
    logic [1:0] arburst; logic [3:0] arcache; logic [2:0] arprot; logic [3:0] arqos; logic arlock;
    logic arvalid; logic arready;
    logic [3:0] rid; logic [127:0] rdata; logic [1:0] rresp; logic rlast; logic rvalid; logic rready;
    logic [3:0] awid; logic [63:0] awaddr; logic [7:0] awlen; logic [2:0] awsize;
    logic [1:0] awburst; logic [3:0] awcache; logic [2:0] awprot; logic [3:0] awqos; logic awlock;
    logic awvalid; logic awready;
    logic [127:0] wdata; logic [15:0] wstrb; logic wlast; logic wvalid; logic wready;
    logic [3:0] bid; logic [1:0] bresp; logic bvalid; logic bready;
endinterface
