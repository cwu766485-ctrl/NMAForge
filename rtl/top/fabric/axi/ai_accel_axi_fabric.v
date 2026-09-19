`timescale 1ns / 1ps

// External AXI routing fabric. Descriptor fetch owns read ID 0; payload DMA
// owns IDs 1..4 and is the sole write-channel owner. DMA lifecycle and all
// response accounting deliberately remain in ai_axi128_dma.
module ai_accel_axi_fabric #(
    parameter integer AXI_ADDR_WIDTH = 64
)(
    input wire desc_busy, input wire desc_arvalid, input wire [3:0] desc_arid,
    input wire [AXI_ADDR_WIDTH-1:0] desc_araddr, input wire [7:0] desc_arlen,
    input wire [2:0] desc_arsize, input wire [1:0] desc_arburst,
    output wire desc_arready, input wire desc_rready,
    input wire dma_arvalid, input wire [3:0] dma_arid,
    input wire [AXI_ADDR_WIDTH-1:0] dma_araddr, input wire [7:0] dma_arlen,
    input wire [2:0] dma_arsize, input wire [1:0] dma_arburst,
    output wire dma_arready, input wire dma_rready,
    input wire m_axi_arready, input wire [3:0] m_axi_rid,
    output wire m_axi_arvalid, output wire [3:0] m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr, output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize, output wire [1:0] m_axi_arburst,
    output wire [3:0] m_axi_arcache, output wire [2:0] m_axi_arprot,
    output wire [3:0] m_axi_arqos, output wire m_axi_arlock, output wire m_axi_rready,
    input wire [3:0] dma_awid, input wire dma_awvalid,
    input wire [AXI_ADDR_WIDTH-1:0] dma_awaddr, input wire [7:0] dma_awlen,
    input wire [2:0] dma_awsize, input wire [1:0] dma_awburst,
    input wire dma_wvalid, input wire [127:0] dma_wdata, input wire [15:0] dma_wstrb,
    input wire dma_wlast, input wire dma_bready,
    output wire [3:0] m_axi_awid, output wire m_axi_awvalid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_awaddr, output wire [7:0] m_axi_awlen,
    output wire [2:0] m_axi_awsize, output wire [1:0] m_axi_awburst,
    output wire [3:0] m_axi_awcache, output wire [2:0] m_axi_awprot,
    output wire [3:0] m_axi_awqos, output wire m_axi_awlock,
    output wire m_axi_wvalid, output wire [127:0] m_axi_wdata,
    output wire [15:0] m_axi_wstrb, output wire m_axi_wlast, output wire m_axi_bready
);
    ai_accel_axi_master_router #(.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)) router_u(
        .desc_busy(desc_busy), .desc_arvalid(desc_arvalid), .desc_arid(desc_arid),
        .desc_araddr(desc_araddr), .desc_arlen(desc_arlen), .desc_arsize(desc_arsize),
        .desc_arburst(desc_arburst), .desc_arready(desc_arready), .desc_rready(desc_rready),
        .dma_arvalid(dma_arvalid), .dma_arid(dma_arid), .dma_araddr(dma_araddr),
        .dma_arlen(dma_arlen), .dma_arsize(dma_arsize), .dma_arburst(dma_arburst),
        .dma_arready(dma_arready), .dma_rready(dma_rready), .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid), .m_axi_arvalid(m_axi_arvalid), .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen), .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst), .m_axi_rready(m_axi_rready),
        .dma_awid(dma_awid), .dma_awvalid(dma_awvalid), .dma_awaddr(dma_awaddr),
        .dma_awlen(dma_awlen), .dma_awsize(dma_awsize), .dma_awburst(dma_awburst),
        .dma_wvalid(dma_wvalid), .dma_wdata(dma_wdata), .dma_wstrb(dma_wstrb),
        .dma_wlast(dma_wlast), .dma_bready(dma_bready),
        .m_axi_awid(m_axi_awid), .m_axi_awvalid(m_axi_awvalid), .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen), .m_axi_awsize(m_axi_awsize), .m_axi_awburst(m_axi_awburst),
        .m_axi_wvalid(m_axi_wvalid), .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast), .m_axi_bready(m_axi_bready)
    );
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;
    assign m_axi_awlock  = 1'b0;
endmodule
