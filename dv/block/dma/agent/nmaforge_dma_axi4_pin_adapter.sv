// Project-owned pin map from the NMAForge DMA AXI4 master to protocol-vips.
// The VIP remains a standard active AXI4 slave; only absent optional sidebands
// are tied low at this integration boundary.
module nmaforge_dma_axi4_pin_adapter (
    tvip_axi_if.pin_adapter_slave vip,
    ai_dma_axi_if                 dma
);
    localparam int unsigned ADDR_WIDTH = $bits(dma.araddr);
    localparam int unsigned DATA_WIDTH = $bits(dma.rdata);
    localparam int unsigned ID_WIDTH   = $bits(dma.arid);

    initial begin
        if (ADDR_WIDTH > $bits(vip.araddr))
            $fatal(1, "NMAForge DMA address width exceeds AXI VIP width");
        if (DATA_WIDTH > $bits(vip.rdata))
            $fatal(1, "NMAForge DMA data width exceeds AXI VIP width");
        if (ID_WIDTH > $bits(vip.rid))
            $fatal(1, "NMAForge DMA ID width exceeds AXI VIP width");
    end

    always @* begin
        // AXI4 write address.
        vip.awvalid = dma.awvalid;
        vip.awid = '0;
        vip.awid[ID_WIDTH-1:0] = dma.awid;
        vip.awaddr = '0;
        vip.awaddr[ADDR_WIDTH-1:0] = dma.awaddr;
        vip.awlen = dma.awlen;
        vip.awsize = dma.awsize;
        vip.awburst = dma.awburst;
        vip.awcache = '0;
        vip.awprot = '0;
        vip.awqos = '0;
        dma.awready = vip.awready;

        // AXI4 write data and response.
        vip.wvalid = dma.wvalid;
        vip.wdata = '0;
        vip.wdata[DATA_WIDTH-1:0] = dma.wdata;
        vip.wstrb = '0;
        vip.wstrb[DATA_WIDTH/8-1:0] = dma.wstrb;
        vip.wlast = dma.wlast;
        dma.wready = vip.wready;
        dma.bid = vip.bid[ID_WIDTH-1:0];
        dma.bresp = vip.bresp;
        dma.bvalid = vip.bvalid;
        vip.bready = dma.bready;

        // AXI4 read address and response.
        vip.arvalid = dma.arvalid;
        vip.arid = '0;
        vip.arid[ID_WIDTH-1:0] = dma.arid;
        vip.araddr = '0;
        vip.araddr[ADDR_WIDTH-1:0] = dma.araddr;
        vip.arlen = dma.arlen;
        vip.arsize = dma.arsize;
        vip.arburst = dma.arburst;
        vip.arcache = '0;
        vip.arprot = '0;
        vip.arqos = '0;
        dma.arready = vip.arready;
        dma.rid = vip.rid[ID_WIDTH-1:0];
        dma.rdata = vip.rdata[DATA_WIDTH-1:0];
        dma.rresp = vip.rresp;
        dma.rvalid = vip.rvalid;
        dma.rlast = vip.rlast;
        vip.rready = dma.rready;
    end
endmodule
