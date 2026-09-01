`timescale 1ns/1ps
`default_nettype none

// Combinational router for the accelerator's shared AXI master interface.
// Descriptor reads have exclusive priority while desc_busy is asserted.
// AXI write traffic is sourced only by the DMA client.
module ai_accel_axi_master_router #(
    parameter AXI_ADDR_WIDTH = 64
) (
    input  wire                      desc_busy,

    input  wire                      desc_arvalid,
    input  wire [3:0]                desc_arid,
    input  wire [AXI_ADDR_WIDTH-1:0] desc_araddr,
    input  wire [7:0]                desc_arlen,
    input  wire [2:0]                desc_arsize,
    input  wire [1:0]                desc_arburst,
    output wire                      desc_arready,
    input  wire                      desc_rready,

    input  wire                      dma_arvalid,
    input  wire [3:0]                dma_arid,
    input  wire [AXI_ADDR_WIDTH-1:0] dma_araddr,
    input  wire [7:0]                dma_arlen,
    input  wire [2:0]                dma_arsize,
    input  wire [1:0]                dma_arburst,
    output wire                      dma_arready,
    input  wire                      dma_rready,

    input  wire                      m_axi_arready,
    input  wire [3:0]                m_axi_rid,
    output wire                      m_axi_arvalid,
    output wire [3:0]                m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [7:0]                m_axi_arlen,
    output wire [2:0]                m_axi_arsize,
    output wire [1:0]                m_axi_arburst,
    output wire                      m_axi_rready,

    input  wire [3:0]                dma_awid,
    input  wire                      dma_awvalid,
    input  wire [AXI_ADDR_WIDTH-1:0] dma_awaddr,
    input  wire [7:0]                dma_awlen,
    input  wire [2:0]                dma_awsize,
    input  wire [1:0]                dma_awburst,
    input  wire                      dma_wvalid,
    input  wire [127:0]              dma_wdata,
    input  wire [15:0]               dma_wstrb,
    input  wire                      dma_wlast,
    input  wire                      dma_bready,
    output wire [3:0]                m_axi_awid,
    output wire                      m_axi_awvalid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [7:0]                m_axi_awlen,
    output wire [2:0]                m_axi_awsize,
    output wire [1:0]                m_axi_awburst,
    output wire                      m_axi_wvalid,
    output wire [127:0]              m_axi_wdata,
    output wire [15:0]               m_axi_wstrb,
    output wire                      m_axi_wlast,
    output wire                      m_axi_bready
);

    assign m_axi_arvalid = desc_busy ? desc_arvalid : dma_arvalid;
    assign m_axi_arid    = desc_busy ? desc_arid    : dma_arid;
    assign m_axi_araddr  = desc_busy ? desc_araddr  : dma_araddr;
    assign m_axi_arlen   = desc_busy ? desc_arlen   : dma_arlen;
    assign m_axi_arsize  = desc_busy ? desc_arsize  : dma_arsize;
    assign m_axi_arburst = desc_busy ? desc_arburst : dma_arburst;

    assign desc_arready = desc_busy ? m_axi_arready : 1'b0;
    assign dma_arready  = m_axi_arready && !desc_busy;
    assign m_axi_rready = (m_axi_rid == 4'd0) ? desc_rready : dma_rready;

    assign m_axi_awid    = dma_awid;
    assign m_axi_awvalid = dma_awvalid;
    assign m_axi_awaddr  = dma_awaddr;
    assign m_axi_awlen   = dma_awlen;
    assign m_axi_awsize  = dma_awsize;
    assign m_axi_awburst = dma_awburst;
    assign m_axi_wvalid  = dma_wvalid;
    assign m_axi_wdata   = dma_wdata;
    assign m_axi_wstrb   = dma_wstrb;
    assign m_axi_wlast   = dma_wlast;
    assign m_axi_bready  = dma_bready;

endmodule

`default_nettype wire
