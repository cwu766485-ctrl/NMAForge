// AXI4-Lite interface driven by the active UVM control-plane agent.
interface ai_axil_if(input logic aclk, input logic aresetn);
    logic [31:0] awaddr; logic awvalid; logic awready;
    logic [31:0] wdata;  logic [3:0] wstrb; logic wvalid; logic wready;
    logic [1:0]  bresp;  logic bvalid; logic bready;
    logic [31:0] araddr; logic arvalid; logic arready;
    logic [31:0] rdata;  logic [1:0] rresp; logic rvalid; logic rready;

    initial begin
        awaddr = '0; awvalid = 0; wdata = '0; wstrb = '0; wvalid = 0;
        bready = 0; araddr = '0; arvalid = 0; rready = 0;
    end
endinterface
