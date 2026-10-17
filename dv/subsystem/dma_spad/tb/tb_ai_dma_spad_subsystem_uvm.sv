`timescale 1ns / 1ps
module tb_ai_dma_spad_subsystem_uvm;
    import uvm_pkg::*;
    import dma_block_types_pkg::*;
    import dma_block_agent_pkg::*;
    import dma_block_env_pkg::*;
    import dma_block_tests_pkg::*;
    import dma_spad_subsystem_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    ai_dma_ctrl_if ctrl_if(clk);
    ai_dma_axi_if axi_if(clk, ctrl_if.resetn);
    ai_dma_spad_if spad_if(clk, ctrl_if.resetn);
    ai_dma_spad_system_if sys_if(clk, ctrl_if.resetn);

    wire [31:0] scheduler_rdata, host_rdata;
    wire scheduler_parity_error, host_error, host_parity_error;
    wire [127:0] line_rdata;
    wire [3:0] line_parity_error;
    wire line_raw_error;
    wire [31:0] banked_data0, banked_data1, banked_data2, banked_data3;
    wire [3:0] banked_parity, cnm_parity, cnm_rsp_valid;
    wire [31:0] cnm_data0, cnm_data1, cnm_data2, cnm_data3;
    wire host_prot_allow;
    wire dma_ready, dma_line_ready, dma_rsp_valid, dma_line_rsp_valid;
    wire dma_rsp_error, core_rsp_valid, core_rsp_error;
    wire [2:0] request_client, rsp_client;
    wire arb_rsp_valid, arb_rsp_error, arb_rsp_is_line;
    wire [31:0] arb_rsp_rdata;
    wire banked_rsp_valid, desc_rsp_valid, desc_rsp_error;
    wire compute_protection_error, banked_protection_error;
    wire cnm_protection_error, line_protection_error, cpl_protection_error;
    wire fp_spad_valid, fp_spad_write, fp_spad_ready;
    wire [31:0] fp_spad_addr, fp_spad_wdata, fp_result;
    wire fp_busy, fp_done, fp_error;
    wire [3:0] fp_error_code;
    wire [31:0] fp_cycle_count, fp_element_count;
    wire core_request_valid = sys_if.cnm_mode ? sys_if.cnm_spad_valid :
                              sys_if.fp_mode ? fp_spad_valid : sys_if.core_valid;
    wire core_request_write = sys_if.cnm_mode ? sys_if.cnm_spad_write :
                              sys_if.fp_mode ? fp_spad_write : sys_if.core_write;
    wire [31:0] core_request_addr = sys_if.cnm_mode ? sys_if.cnm_spad_addr :
                                    sys_if.fp_mode ? fp_spad_addr : sys_if.core_addr;
    wire [31:0] core_request_wdata = sys_if.cnm_mode ? sys_if.cnm_spad_wdata :
                                     sys_if.fp_mode ? fp_spad_wdata : sys_if.core_wdata;

    ai_mixed_precision_dot_fp32_core mixed_dot_core (
        .clk(clk), .resetn(ctrl_if.resetn),
        .start(sys_if.fp_start), .format_fp16(sys_if.fp_format_fp16),
        .abort(sys_if.fp_abort), .src0_base(sys_if.fp_src0_base),
        .src1_base(sys_if.fp_src1_base), .dst_base(sys_if.fp_dst_base),
        .length(sys_if.fp_length), .watchdog_limit(sys_if.fp_watchdog_limit),
        .spad_valid(fp_spad_valid), .spad_write(fp_spad_write),
        .spad_addr(fp_spad_addr), .spad_wdata(fp_spad_wdata),
        .spad_ready(fp_spad_ready), .spad_rsp_valid(core_rsp_valid),
        .spad_rdata(scheduler_rdata), .spad_parity_error(scheduler_parity_error),
        .spad_protection_error(compute_protection_error),
        .busy(fp_busy), .done(fp_done), .error(fp_error),
        .error_code(fp_error_code), .result(fp_result),
        .cycle_count(fp_cycle_count), .element_count(fp_element_count)
    );
    assign fp_spad_ready = sys_if.core_ready;

    ai_banked_cnm_core cnm_core (
        .clk(clk), .resetn(ctrl_if.resetn),
        .start(sys_if.cnm_start), .abort(sys_if.cnm_abort),
        .op_mode(sys_if.cnm_op_mode), .src0_base(sys_if.cnm_src0_base),
        .src1_base(sys_if.cnm_src1_base), .dst_base(sys_if.cnm_dst_base),
        .length(sys_if.cnm_length), .m_size(sys_if.cnm_m_size),
        .scale_shift(sys_if.cnm_scale_shift), .activation(sys_if.cnm_activation),
        .watchdog_limit(sys_if.cnm_watchdog_limit),
        .cnm_req_valid(sys_if.cnm_req_valid),
        .cnm_addr0(sys_if.cnm_addr0), .cnm_addr1(sys_if.cnm_addr1),
        .cnm_addr2(sys_if.cnm_addr2), .cnm_addr3(sys_if.cnm_addr3),
        .cnm_req_ready(sys_if.cnm_req_ready), .cnm_rsp_valid(sys_if.cnm_rsp_valid),
        .cnm_data0(sys_if.cnm_data0), .cnm_data1(sys_if.cnm_data1),
        .cnm_data2(sys_if.cnm_data2), .cnm_data3(sys_if.cnm_data3),
        .cnm_parity_error(sys_if.cnm_parity_error),
        .cnm_protection_error(sys_if.cnm_protection_error),
        .spad_valid(sys_if.cnm_spad_valid), .spad_write(sys_if.cnm_spad_write),
        .spad_addr(sys_if.cnm_spad_addr), .spad_wdata(sys_if.cnm_spad_wdata),
        .spad_ready(sys_if.core_ready),
        .spad_protection_error(sys_if.cnm_spad_protection_error),
        .busy(sys_if.cnm_busy), .done(sys_if.cnm_done), .error(sys_if.cnm_error),
        .error_code(sys_if.cnm_error_code), .result(sys_if.cnm_result),
        .cycle_count(sys_if.cnm_cycle_count), .element_count(sys_if.cnm_element_count),
        .local_accumulate_events(sys_if.cnm_local_accumulate_events),
        .global_reduce_events(sys_if.cnm_global_reduce_events),
        .banked_read_issue_events(sys_if.cnm_banked_read_issue_events),
        .prefetch_events(sys_if.cnm_prefetch_events),
        .pipeline_compute_events(sys_if.cnm_pipeline_compute_events),
        .response_wait_cycles(sys_if.cnm_response_wait_cycles)
    );

    ai_axi128_dma #(
        .MAX_OUTSTANDING(4),
        .MAX_BURST_BEATS(2)
    ) dma_dut (
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

    ai_accel_memory_fabric #(
        .WORDS_PER_BANK(256),
        .ROW_BITS(8),
        .SPAD_BYTES(32'd4096)
    ) memory_fabric_dut (
        .clk(clk), .resetn(ctrl_if.resetn),
        .region0_base(sys_if.region0_base), .region0_limit(sys_if.region0_limit),
        .region0_perm(sys_if.region0_perm),
        .region1_base(32'd0), .region1_limit(32'd0), .region1_perm(4'd0),
        .region2_base(32'd0), .region2_limit(32'd0), .region2_perm(4'd0),
        .region3_base(32'd0), .region3_limit(32'd0), .region3_perm(4'd0),
        .host_valid(sys_if.host_valid), .host_write(sys_if.host_write),
        .host_addr(sys_if.host_addr), .host_wdata(sys_if.host_wdata), .host_wstrb(sys_if.host_wstrb),
        .host_rdata(host_rdata), .host_error(host_error), .host_parity_error(host_parity_error),
        .host_prot_allow(host_prot_allow),
        .desc_valid(sys_if.desc_valid), .desc_addr(sys_if.desc_addr), .desc_ready(sys_if.desc_ready),
        .cpl_valid(sys_if.cpl_valid), .cpl_write(sys_if.cpl_write),
        .cpl_addr(sys_if.cpl_addr), .cpl_wdata(sys_if.cpl_wdata), .cpl_ready(sys_if.cpl_ready),
        .core_valid(core_request_valid), .core_write(core_request_write),
        .core_addr(core_request_addr), .core_wdata(core_request_wdata), .core_ready(sys_if.core_ready),
        .core_rsp_valid(core_rsp_valid), .core_rsp_error(core_rsp_error),
        .core_line_valid(1'b0), .core_line_write(1'b0), .core_line_addr(32'd0),
        .core_line_wdata(128'd0), .core_line_wstrb(16'd0), .core_line_ready(),
        .banked_valid(1'b0), .banked_addr(32'd0), .banked_ready(),
        .cnm_valid(sys_if.cnm_req_valid), .cnm_addr0(sys_if.cnm_addr0),
        .cnm_addr1(sys_if.cnm_addr1), .cnm_addr2(sys_if.cnm_addr2),
        .cnm_addr3(sys_if.cnm_addr3), .cnm_ready(sys_if.cnm_req_ready),
        .dma_valid(spad_if.spad_valid), .dma_write(spad_if.spad_write),
        .dma_addr(spad_if.spad_addr), .dma_wdata(spad_if.spad_wdata), .dma_ready(dma_ready),
        .dma_line_valid(spad_if.line_valid), .dma_line_write(spad_if.line_write),
        .dma_line_addr(spad_if.line_addr), .dma_line_wdata(spad_if.line_wdata),
        .dma_line_wstrb(spad_if.line_wstrb), .dma_line_ready(dma_line_ready),
        .cpl_base(32'd0), .cpl_index(32'd0),
        .scheduler_rdata(scheduler_rdata), .scheduler_parity_error(scheduler_parity_error),
        .line_rdata(line_rdata), .line_parity_error(line_parity_error), .line_raw_error(line_raw_error),
        .banked_data0(banked_data0), .banked_data1(banked_data1), .banked_data2(banked_data2), .banked_data3(banked_data3),
        .banked_parity(banked_parity), .cnm_data0(cnm_data0), .cnm_data1(cnm_data1),
        .cnm_data2(cnm_data2), .cnm_data3(cnm_data3), .cnm_parity(cnm_parity),
        .desc_rsp_valid(desc_rsp_valid), .desc_rsp_error(desc_rsp_error),
        .banked_rsp_valid(banked_rsp_valid),
        .dma_rsp_valid(dma_rsp_valid), .dma_line_rsp_valid(dma_line_rsp_valid),
        .dma_rsp_error(dma_rsp_error), .request_client(request_client), .rsp_client(rsp_client),
        .rsp_valid(arb_rsp_valid), .rsp_error(arb_rsp_error), .rsp_is_line(arb_rsp_is_line),
        .rsp_rdata(arb_rsp_rdata), .cnm_rsp_valid(cnm_rsp_valid),
        .compute_protection_error(compute_protection_error), .banked_protection_error(banked_protection_error),
        .cnm_protection_error(cnm_protection_error), .line_protection_error(line_protection_error),
        .cpl_protection_error(cpl_protection_error)
    );

    assign sys_if.host_rdata = host_rdata;
    assign sys_if.host_error = host_error;
    assign sys_if.fp_req_valid = sys_if.fp_mode && fp_spad_valid;
    assign sys_if.fp_req_write = sys_if.fp_mode && fp_spad_valid && fp_spad_write;
    assign sys_if.fp_req_addr = fp_spad_addr;
    assign sys_if.fp_req_ready = fp_spad_ready;
    assign sys_if.fp_rsp_valid = sys_if.fp_mode && core_rsp_valid;
    assign sys_if.fp_rsp_error = core_rsp_error;
    assign sys_if.fp_busy = fp_busy;
    assign sys_if.fp_done = fp_done;
    assign sys_if.fp_error = fp_error;
    assign sys_if.fp_error_code = fp_error_code;
    assign sys_if.fp_result = fp_result;
    assign sys_if.fp_cycle_count = fp_cycle_count;
    assign sys_if.fp_element_count = fp_element_count;
    assign sys_if.cnm_data0 = cnm_data0;
    assign sys_if.cnm_data1 = cnm_data1;
    assign sys_if.cnm_data2 = cnm_data2;
    assign sys_if.cnm_data3 = cnm_data3;
    assign sys_if.cnm_rsp_valid = cnm_rsp_valid;
    assign sys_if.cnm_parity_error = cnm_parity;
    assign sys_if.cnm_protection_error = cnm_protection_error;
    assign sys_if.cnm_spad_protection_error = compute_protection_error;
    assign sys_if.core_rdata = scheduler_rdata;
    assign sys_if.core_rsp_valid = core_rsp_valid;
    assign sys_if.core_rsp_error = core_rsp_error;
    assign sys_if.dma_valid = spad_if.spad_valid;
    assign sys_if.dma_write = spad_if.spad_write;
    assign sys_if.dma_ready = dma_ready;
    assign sys_if.dma_line_valid = spad_if.line_valid;
    assign sys_if.dma_line_ready = dma_line_ready;
    assign sys_if.request_client = request_client;
    assign sys_if.arb_rsp_valid = arb_rsp_valid;
    assign sys_if.arb_rsp_client = rsp_client;
    assign sys_if.arb_rsp_is_line = arb_rsp_is_line;
    assign sys_if.arb_rsp_rdata = arb_rsp_rdata;
    assign sys_if.arb_rsp_error = arb_rsp_error;
    assign sys_if.desc_rsp_valid = desc_rsp_valid;
    assign sys_if.desc_rsp_error = desc_rsp_error;

    assign spad_if.spad_ready = dma_ready;
    assign spad_if.spad_rsp_valid = dma_rsp_valid;
    assign spad_if.spad_rdata = scheduler_rdata;
    assign spad_if.spad_req_error = compute_protection_error;
    assign spad_if.spad_rsp_error = dma_rsp_error;
    assign spad_if.line_ready = dma_line_ready;
    assign spad_if.line_rsp_valid = dma_line_rsp_valid;
    assign spad_if.line_rdata = line_rdata;
    assign spad_if.line_req_error = line_protection_error && (request_client == 3'd4);
    assign spad_if.line_rsp_error = dma_line_rsp_valid && arb_rsp_error;
    assign spad_if.line_parity_error = line_parity_error;

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

    ai_dma_spad_subsystem_sva spad_sva (
        .clk(clk), .resetn(ctrl_if.resetn),
        .desc_valid(sys_if.desc_valid), .desc_ready(sys_if.desc_ready),
        .cpl_valid(sys_if.cpl_valid), .cpl_ready(sys_if.cpl_ready),
        .core_valid(core_request_valid), .core_ready(sys_if.core_ready),
        .cnm_valid(sys_if.cnm_req_valid), .cnm_ready(sys_if.cnm_req_ready),
        .cnm_addr0(sys_if.cnm_addr0), .cnm_addr1(sys_if.cnm_addr1),
        .cnm_addr2(sys_if.cnm_addr2), .cnm_addr3(sys_if.cnm_addr3),
        .cnm_rsp_valid(sys_if.cnm_rsp_valid),
        .cnm_protection_error(sys_if.cnm_protection_error),
        .dma_valid(sys_if.dma_valid), .dma_ready(sys_if.dma_ready),
        .dma_line_valid(sys_if.dma_line_valid), .dma_line_ready(sys_if.dma_line_ready),
        .request_client(sys_if.request_client), .rsp_valid(sys_if.arb_rsp_valid),
        .rsp_client(sys_if.arb_rsp_client), .rsp_is_line(sys_if.arb_rsp_is_line),
        .desc_rsp_valid(sys_if.desc_rsp_valid), .core_rsp_valid(sys_if.core_rsp_valid),
        .banked_rsp_valid(banked_rsp_valid), .dma_rsp_valid(dma_rsp_valid),
        .dma_line_rsp_valid(dma_line_rsp_valid)
    );

    initial begin
        uvm_config_db#(virtual ai_dma_ctrl_if)::set(null, "*", "ctrl_vif", ctrl_if);
        uvm_config_db#(virtual ai_dma_axi_if)::set(null, "*", "axi_vif", axi_if);
        uvm_config_db#(virtual ai_dma_spad_if)::set(null, "*", "spad_vif", spad_if);
        uvm_config_db#(virtual ai_dma_spad_system_if)::set(null, "*", "spad_system_vif", sys_if);
        run_test();
    end

    // The test requests reset through sys_if; this module synchronously
    // asserts/releases the shared reset at a falling edge and acknowledges
    // each phase. Virtual-interface inputs never drive ctrl_if.resetn.
    initial sys_if.subsystem_reset_ack = 1'b0;
    always @(negedge clk) begin
        if (sys_if.subsystem_reset_req && !sys_if.subsystem_reset_ack) begin
            ctrl_if.resetn <= 1'b0;
            sys_if.subsystem_reset_ack <= 1'b1;
        end else if (!sys_if.subsystem_reset_req && sys_if.subsystem_reset_ack) begin
            ctrl_if.resetn <= 1'b1;
            sys_if.subsystem_reset_ack <= 1'b0;
        end
    end

    initial begin
        repeat (5) @(posedge clk);
        ctrl_if.resetn = 1'b1;
    end

    initial begin
        #150_000;
        $fatal(1, "DMA-SPAD subsystem UVM timeout");
    end
endmodule
