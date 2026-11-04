module ai_spad_arbiter_fairness_formal_top (
    input logic clk,
    input logic resetn,
    input logic core_valid,
    input logic core_line_valid,
    input logic banked_valid,
    input logic [3:0] cnm_valid,
    input logic dma_valid,
    input logic dma_line_valid
);
    wire core_ready;
    wire core_line_ready;
    wire banked_ready;
    wire [3:0] cnm_ready;
    wire dma_ready;
    wire dma_line_ready;
    wire [2:0] request_client;

    ai_spad_arbiter dut (
        .clk(clk), .resetn(resetn),
        // Control-plane priority is part of the contract. This proof scopes
        // the data-plane bound to the interval after control traffic drains.
        .desc_valid(1'b0), .desc_write(1'b0),
        .desc_addr(32'd0), .desc_wdata(32'd0), .desc_ready(),
        .cpl_valid(1'b0), .cpl_write(1'b0),
        .cpl_addr(32'd0), .cpl_wdata(32'd0), .cpl_ready(),
        .core_valid(core_valid), .core_write(1'b0),
        .core_addr(32'd0), .core_wdata(32'd0), .core_ready(core_ready),
        .core_line_valid(core_line_valid), .core_line_write(1'b1),
        .core_line_addr(32'd0), .core_line_wdata(128'd0),
        .core_line_wstrb(16'hffff), .core_line_ready(core_line_ready),
        .banked_valid(banked_valid), .banked_addr(32'd0),
        .banked_ready(banked_ready),
        .cnm_valid(cnm_valid),
        .cnm_addr0(32'd0), .cnm_addr1(32'd4),
        .cnm_addr2(32'd8), .cnm_addr3(32'd12), .cnm_ready(cnm_ready),
        .dma_valid(dma_valid), .dma_write(1'b0),
        .dma_addr(32'd0), .dma_wdata(32'd0), .dma_ready(dma_ready),
        .dma_line_valid(dma_line_valid), .dma_line_write(1'b1),
        .dma_line_addr(32'd0), .dma_line_wdata(128'd0),
        .dma_line_wstrb(16'hffff), .dma_line_ready(dma_line_ready),
        .spad_valid(), .spad_write(), .spad_addr(), .spad_wdata(),
        .spad_line_valid(), .spad_line_write(), .spad_line_addr(),
        .spad_line_wdata(), .spad_line_wstrb(),
        .spad_banked_valid(), .spad_banked_addr(),
        .spad_cnm_valid(), .spad_cnm_addr0(), .spad_cnm_addr1(),
        .spad_cnm_addr2(), .spad_cnm_addr3(),
        .spad_rdata(32'd0), .spad_error(1'b0),
        .spad_parity_error(1'b0), .spad_line_error(1'b0),
        .spad_line_parity_error(4'd0),
        .rsp_valid(), .rsp_client(), .rsp_is_line(),
        .request_client(request_client), .rsp_rdata(), .rsp_error(),
        .cnm_rsp_valid()
    );

    default clocking cb @(posedge clk); endclocking

    // Model legal ready/valid sources: a selected request remains asserted
    // until the arbiter accepts it. A real engine never presents its scalar
    // and Line forms simultaneously; likewise for DMA.
    assume property (disable iff (!resetn) !(core_valid && core_line_valid));
    assume property (disable iff (!resetn) !(dma_valid && dma_line_valid));
    assume property (disable iff (!resetn)
        (core_valid && !core_ready) |=> core_valid);
    assume property (disable iff (!resetn)
        (core_line_valid && !core_line_ready) |=> core_line_valid);
    assume property (disable iff (!resetn)
        (banked_valid && !banked_ready) |=> banked_valid);
    assume property (disable iff (!resetn)
        ((|cnm_valid) && !(|cnm_ready)) |=> $stable(cnm_valid));
    assume property (disable iff (!resetn)
        (dma_valid && !dma_ready) |=> dma_valid);
    assume property (disable iff (!resetn)
        (dma_line_valid && !dma_line_ready) |=> dma_line_valid);

    ap_core_class_progress_within_two: assert property (
        disable iff (!resetn)
        (core_valid || core_line_valid) |->
        ##[0:2] (core_ready || core_line_ready)
    );

    ap_dma_class_progress_within_two: assert property (
        disable iff (!resetn)
        (dma_valid || dma_line_valid) |->
        ##[0:2] (dma_ready || dma_line_ready)
    );

    ap_matrix_banked_progress_within_five: assert property (
        disable iff (!resetn)
        banked_valid |-> ##[0:5] banked_ready
    );

    ap_cnm_progress_within_five: assert property (
        disable iff (!resetn)
        (|cnm_valid) |-> ##[0:5] (|cnm_ready)
    );

    ap_data_plane_grant_is_exclusive: assert property (
        disable iff (!resetn)
        $onehot0({(core_ready || core_line_ready), banked_ready,
                  (|cnm_ready), (dma_ready || dma_line_ready)})
    );

    cp_core_scalar_grant: cover property (
        disable iff (!resetn) core_valid && core_ready
    );
    cp_core_line_grant: cover property (
        disable iff (!resetn) core_line_valid && core_line_ready
    );
    cp_matrix_grant_while_cnm_pending: cover property (
        disable iff (!resetn) banked_valid && (|cnm_valid) && banked_ready
    );
    cp_cnm_grant_while_matrix_pending: cover property (
        disable iff (!resetn) banked_valid && (|cnm_valid) && (|cnm_ready)
    );
    cp_dma_scalar_grant: cover property (
        disable iff (!resetn) dma_valid && dma_ready
    );
    cp_dma_line_grant: cover property (
        disable iff (!resetn) dma_line_valid && dma_line_ready
    );
endmodule
