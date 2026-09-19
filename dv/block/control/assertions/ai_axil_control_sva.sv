module ai_axil_control_sva(
    input wire aclk, input wire aresetn,
    input wire [31:0] awaddr, input wire awvalid, input wire awready,
    input wire [31:0] wdata, input wire [3:0] wstrb, input wire wvalid, input wire wready,
    input wire [1:0] bresp, input wire bvalid, input wire bready,
    input wire [31:0] araddr, input wire arvalid, input wire arready,
    input wire [31:0] rdata, input wire [1:0] rresp, input wire rvalid, input wire rready,
    input wire reg_req_valid, input wire reg_req_write, input wire [31:0] reg_req_addr,
    input wire [31:0] reg_req_wdata, input wire core_abort, input wire irq
);
    // AXI valid payload must remain stable until its corresponding handshake.
    property p_aw_stable; @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> awvalid && $stable(awaddr); endproperty
    property p_w_stable; @(posedge aclk) disable iff (!aresetn)
        wvalid && !wready |=> wvalid && $stable(wdata) && $stable(wstrb); endproperty
    property p_b_stable; @(posedge aclk) disable iff (!aresetn)
        bvalid && !bready |=> bvalid && $stable(bresp); endproperty
    property p_ar_stable; @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> arvalid && $stable(araddr); endproperty
    property p_r_stable; @(posedge aclk) disable iff (!aresetn)
        rvalid && !rready |=> rvalid && $stable(rdata) && $stable(rresp); endproperty
    property p_abort_pulse; @(posedge aclk) disable iff (!aresetn)
        reg_req_valid && reg_req_write && reg_req_addr[8:0] == 9'h0a4 && reg_req_wdata[0] |=> core_abort; endproperty
    property p_irq_known; @(posedge aclk) disable iff (!aresetn) !$isunknown(irq); endproperty
    assert property (p_aw_stable);
    assert property (p_w_stable);
    assert property (p_b_stable);
    assert property (p_ar_stable);
    assert property (p_r_stable);
    assert property (p_abort_pulse);
    assert property (p_irq_known);
endmodule
