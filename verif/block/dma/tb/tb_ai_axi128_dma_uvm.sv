`timescale 1ns / 1ps
module tb_ai_axi128_dma_uvm;
    import uvm_pkg::*;
    import dma_block_types_pkg::*;
    import dma_block_agent_pkg::*;
    import dma_block_env_pkg::*;
    import dma_block_tests_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    ai_dma_ctrl_if ctrl_if(clk);
    ai_dma_axi_if  axi_if(clk, ctrl_if.resetn);
    ai_dma_spad_if spad_if(clk, ctrl_if.resetn);

    ai_axi128_dma #(
        .MAX_OUTSTANDING(4),
        // Two beats per request makes the 32-word smoke issue four ARs.
        .MAX_BURST_BEATS(2)
    ) dut (
        .clk(clk), .resetn(ctrl_if.resetn), .start(ctrl_if.start), .abort(ctrl_if.abort),
        .store(ctrl_if.store), .ext_addr(ctrl_if.ext_addr), .spad_addr(ctrl_if.spad_addr),
        .length_words(ctrl_if.length_words), .row_words(ctrl_if.row_words),
        .row_count(ctrl_if.row_count), .ext_stride(ctrl_if.ext_stride),
        .spad_stride(ctrl_if.spad_stride), .gather_enable(ctrl_if.gather_enable),
        .gather_index_base(ctrl_if.gather_index_base), .read_outstanding(ctrl_if.read_outstanding),
        .busy(ctrl_if.busy), .done(ctrl_if.done), .error(ctrl_if.error),
        .error_code(ctrl_if.error_code),
        .spad_valid(spad_if.spad_valid), .spad_write(spad_if.spad_write),
        .spad_addr_o(spad_if.spad_addr), .spad_wdata(spad_if.spad_wdata),
        .spad_ready(spad_if.spad_ready), .spad_rsp_valid(spad_if.spad_rsp_valid),
        .spad_rdata(spad_if.spad_rdata), .spad_req_error(spad_if.spad_req_error),
        .spad_rsp_error(spad_if.spad_rsp_error), .spad_line_valid(spad_if.line_valid),
        .spad_line_write(spad_if.line_write), .spad_line_addr(spad_if.line_addr),
        .spad_line_wdata(spad_if.line_wdata), .spad_line_wstrb(spad_if.line_wstrb),
        .spad_line_ready(spad_if.line_ready), .spad_line_rsp_valid(spad_if.line_rsp_valid),
        .spad_line_rdata(spad_if.line_rdata), .spad_line_req_error(spad_if.line_req_error),
        .spad_line_rsp_error(spad_if.line_rsp_error), .spad_line_parity_error(spad_if.line_parity_error),
        .m_axi_arid(axi_if.arid), .m_axi_arvalid(axi_if.arvalid), .m_axi_araddr(axi_if.araddr),
        .m_axi_arlen(axi_if.arlen), .m_axi_arsize(axi_if.arsize), .m_axi_arburst(axi_if.arburst),
        .m_axi_arready(axi_if.arready), .m_axi_rid(axi_if.rid), .m_axi_rdata(axi_if.rdata),
        .m_axi_rresp(axi_if.rresp), .m_axi_rvalid(axi_if.rvalid), .m_axi_rlast(axi_if.rlast),
        .m_axi_rready(axi_if.rready), .m_axi_awid(axi_if.awid), .m_axi_awvalid(axi_if.awvalid),
        .m_axi_awaddr(axi_if.awaddr), .m_axi_awlen(axi_if.awlen), .m_axi_awsize(axi_if.awsize),
        .m_axi_awburst(axi_if.awburst), .m_axi_awready(axi_if.awready),
        .m_axi_wvalid(axi_if.wvalid), .m_axi_wdata(axi_if.wdata), .m_axi_wstrb(axi_if.wstrb),
        .m_axi_wlast(axi_if.wlast), .m_axi_wready(axi_if.wready), .m_axi_bid(axi_if.bid),
        .m_axi_bresp(axi_if.bresp), .m_axi_bvalid(axi_if.bvalid), .m_axi_bready(axi_if.bready),
        .rd_outstanding(ctrl_if.rd_outstanding), .rd_highwater(ctrl_if.rd_highwater),
        .r_beat_bytes(), .w_beat_bytes()
    );

    ai_axi128_dma_sva dma_sva (
        .clk(clk), .resetn(ctrl_if.resetn), .arid(axi_if.arid), .arvalid(axi_if.arvalid),
        .araddr(axi_if.araddr), .arlen(axi_if.arlen), .arsize(axi_if.arsize),
        .arburst(axi_if.arburst), .arready(axi_if.arready), .rid(axi_if.rid),
        .rvalid(axi_if.rvalid), .rlast(axi_if.rlast), .rready(axi_if.rready),
        .awid(axi_if.awid), .awvalid(axi_if.awvalid), .awaddr(axi_if.awaddr),
        .awlen(axi_if.awlen), .awsize(axi_if.awsize), .awburst(axi_if.awburst),
        .awready(axi_if.awready), .wvalid(axi_if.wvalid), .wdata(axi_if.wdata),
        .wstrb(axi_if.wstrb), .wlast(axi_if.wlast), .wready(axi_if.wready),
        .bid(axi_if.bid), .bresp(axi_if.bresp), .bvalid(axi_if.bvalid), .bready(axi_if.bready)
    );

    initial begin
        uvm_config_db#(virtual ai_dma_ctrl_if)::set(null, "*", "ctrl_vif", ctrl_if);
        uvm_config_db#(virtual ai_dma_axi_if)::set(null, "*", "axi_vif", axi_if);
        uvm_config_db#(virtual ai_dma_spad_if)::set(null, "*", "spad_vif", spad_if);
        run_test();
    end

    initial begin
        repeat (5) @(posedge clk);
        ctrl_if.resetn = 1'b1;
    end

    initial begin
        #100_000;
        $fatal(1, "DMA UVM timeout");
    end
endmodule
