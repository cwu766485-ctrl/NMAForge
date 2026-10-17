// Local DMA protocol checks.  Interface-level AXI compliance is shared work;
// these properties focus on invariants owned by ai_axi128_dma.
module ai_axi128_dma_sva (
    input wire clk,
    input wire resetn,
    input wire [3:0] arid, input wire arvalid, input wire [63:0] araddr,
    input wire [7:0] arlen, input wire [2:0] arsize, input wire [1:0] arburst,
    input wire arready, input wire [3:0] rid, input wire rvalid,
    input wire rlast, input wire rready,
    input wire [3:0] awid, input wire awvalid, input wire [63:0] awaddr,
    input wire [7:0] awlen, input wire [2:0] awsize, input wire [1:0] awburst,
    input wire awready, input wire wvalid, input wire [127:0] wdata,
    input wire [15:0] wstrb, input wire wlast, input wire wready,
    input wire [3:0] bid, input wire [1:0] bresp, input wire bvalid,
    input wire bready
);
    function automatic bit stays_in_4k(input [63:0] addr, input [7:0] len,
                                       input [2:0] size);
        reg [63:0] bytes;
        begin
            bytes = ({56'd0, len} + 1) << size;
            stays_in_4k = ({52'd0, addr[11:0]} + bytes) <= 64'd4096;
        end
    endfunction

    property p_ar_payload_stable;
        @(posedge clk) disable iff (!resetn)
        arvalid && !arready |=> arvalid && $stable({arid, araddr, arlen, arsize, arburst});
    endproperty
    ap_dma_ar_payload_stable: assert property (p_ar_payload_stable)
        else $error("DMA AXI AR payload changed while stalled");

    property p_aw_payload_stable;
        @(posedge clk) disable iff (!resetn)
        awvalid && !awready |=> awvalid && $stable({awid, awaddr, awlen, awsize, awburst});
    endproperty
    ap_dma_aw_payload_stable: assert property (p_aw_payload_stable)
        else $error("DMA AXI AW payload changed while stalled");

    property p_w_payload_stable;
        @(posedge clk) disable iff (!resetn)
        wvalid && !wready |=> wvalid && $stable({wdata, wstrb, wlast});
    endproperty
    ap_dma_w_payload_stable: assert property (p_w_payload_stable)
        else $error("DMA AXI W payload changed while stalled");

    property p_dma_arid_range;
        @(posedge clk) disable iff (!resetn) arvalid |-> (arid >= 4'd1 && arid <= 4'd4);
    endproperty
    ap_dma_arid_range: assert property (p_dma_arid_range)
        else $error("DMA issued unsupported ARID");

    property p_dma_rid_range;
        @(posedge clk) disable iff (!resetn) rvalid |-> (rid >= 4'd1 && rid <= 4'd4);
    endproperty
    ap_dma_rid_range: assert property (p_dma_rid_range)
        else $error("DMA responder returned unsupported RID");

    property p_dma_awid_range;
        @(posedge clk) disable iff (!resetn) awvalid |-> (awid >= 4'd8 && awid <= 4'd11);
    endproperty
    ap_dma_awid_range: assert property (p_dma_awid_range)
        else $error("DMA issued unsupported AWID");

    property p_dma_bid_range;
        @(posedge clk) disable iff (!resetn) bvalid |-> (bid >= 4'd8 && bid <= 4'd11);
    endproperty
    ap_dma_bid_range: assert property (p_dma_bid_range)
        else $error("DMA responder returned unsupported BID");

    property p_ar_4k;
        @(posedge clk) disable iff (!resetn) arvalid && arready |-> stays_in_4k(araddr, arlen, arsize);
    endproperty
    ap_dma_ar_4k: assert property (p_ar_4k)
        else $error("DMA AR burst crosses a 4-KiB boundary");

    property p_aw_4k;
        @(posedge clk) disable iff (!resetn) awvalid && awready |-> stays_in_4k(awaddr, awlen, awsize);
    endproperty
    ap_dma_aw_4k: assert property (p_aw_4k)
        else $error("DMA AW burst crosses a 4-KiB boundary");

    property p_r_channel_known;
        @(posedge clk) disable iff (!resetn) rvalid |-> !$isunknown({rid, rlast, rready});
    endproperty
    ap_dma_r_channel_known: assert property (p_r_channel_known)
        else $error("DMA R channel contains X");

    property p_b_channel_known;
        @(posedge clk) disable iff (!resetn) bvalid |-> !$isunknown({bid, bresp, bready});
    endproperty
    ap_dma_b_channel_known: assert property (p_b_channel_known)
        else $error("DMA B channel contains X");
endmodule
