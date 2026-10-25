module ai_spad_arbiter_decode_formal_top (
    input logic clk,
    input logic resetn,
    input logic [10:0] req_valid,
    input logic [5:0] req_write
);
    wire desc_ready;
    wire cpl_ready;
    wire core_ready;
    wire core_line_ready;
    wire banked_ready;
    wire [3:0] cnm_ready;
    wire dma_ready;
    wire dma_line_ready;
    wire [2:0] request_client;

    ai_spad_arbiter dut (
        .clk(clk), .resetn(resetn),
        .desc_valid(req_valid[0]), .desc_write(req_write[0]),
        .desc_addr(32'd0), .desc_wdata(32'd0), .desc_ready(desc_ready),
        .cpl_valid(req_valid[1]), .cpl_write(req_write[1]),
        .cpl_addr(32'd0), .cpl_wdata(32'd0), .cpl_ready(cpl_ready),
        .core_valid(req_valid[2]), .core_write(req_write[2]),
        .core_addr(32'd0), .core_wdata(32'd0), .core_ready(core_ready),
        .core_line_valid(req_valid[3]), .core_line_write(req_write[3]),
        .core_line_addr(32'd0), .core_line_wdata(128'd0),
        .core_line_wstrb(16'd0), .core_line_ready(core_line_ready),
        .banked_valid(req_valid[4]), .banked_addr(32'd0),
        .banked_ready(banked_ready),
        .cnm_valid(req_valid[8:5]),
        .cnm_addr0(32'd0), .cnm_addr1(32'd0),
        .cnm_addr2(32'd0), .cnm_addr3(32'd0), .cnm_ready(cnm_ready),
        .dma_valid(req_valid[9]), .dma_write(req_write[4]),
        .dma_addr(32'd0), .dma_wdata(32'd0), .dma_ready(dma_ready),
        .dma_line_valid(req_valid[10]), .dma_line_write(req_write[5]),
        .dma_line_addr(32'd0), .dma_line_wdata(128'd0),
        .dma_line_wstrb(16'd0), .dma_line_ready(dma_line_ready),
        .spad_valid(), .spad_write(), .spad_addr(), .spad_wdata(),
        .spad_line_valid(), .spad_line_write(), .spad_line_addr(),
        .spad_line_wdata(), .spad_line_wstrb(),
        .spad_banked_valid(), .spad_banked_addr(),
        .spad_cnm_valid(), .spad_cnm_addr0(), .spad_cnm_addr1(),
        .spad_cnm_addr2(), .spad_cnm_addr3(),
        .spad_rdata(32'd0), .spad_error(1'b0),
        .spad_parity_error(1'b0), .spad_line_error(1'b0),
        .spad_line_parity_error(4'd0),
        .rsp_valid(), .rsp_client(), .rsp_is_line(), .request_client(request_client),
        .rsp_rdata(), .rsp_error(), .cnm_rsp_valid()
    );

    default clocking cb @(posedge clk); endclocking

    ap_idle_decode_defaults_to_dma: assert property (
        disable iff (!resetn)
        !dut.accept_valid |-> dut.accept_client == 3'd4
    );

    ap_descriptor_selection_requires_accept: assert property (
        disable iff (!resetn)
        dut.accept_client == 3'd0 |-> dut.accept_valid
    );

    ap_completion_selection_requires_accept: assert property (
        disable iff (!resetn)
        dut.accept_client == 3'd1 |-> dut.accept_valid
    );

    ap_core_selection_requires_accept: assert property (
        disable iff (!resetn)
        dut.accept_client == 3'd2 |-> dut.accept_valid
    );

    ap_banked_selection_requires_response: assert property (
        disable iff (!resetn)
        (dut.accept_client == 3'd3 || dut.accept_client == 3'd5) |->
        (dut.accept_valid && dut.accept_response)
    );

    ap_delayed_banked_metadata_has_response: assert property (
        disable iff (!resetn)
        (dut.accept_client_d == 3'd3 || dut.accept_client_d == 3'd5) |->
        dut.accept_valid_d
    );

    ap_line_metadata_requires_accept: assert property (
        disable iff (!resetn)
        dut.accept_is_line |-> dut.accept_valid
    );

    ap_response_requires_accept: assert property (
        disable iff (!resetn)
        dut.accept_response |-> dut.accept_valid
    );

    cp_idle_decode: cover property (
        disable iff (!resetn)
        !dut.accept_valid && dut.accept_client == 3'd4
    );

    cp_descriptor_selection: cover property (
        disable iff (!resetn)
        dut.accept_valid && dut.accept_client == 3'd0
    );

    cp_completion_selection: cover property (
        disable iff (!resetn)
        dut.accept_valid && dut.accept_client == 3'd1
    );

    cp_banked_response_selection: cover property (
        disable iff (!resetn)
        dut.accept_valid && dut.accept_response && dut.accept_client == 3'd3
    );

    cp_cnm_response_selection: cover property (
        disable iff (!resetn)
        dut.accept_valid && dut.accept_response && dut.accept_client == 3'd5
    );
endmodule
