`timescale 1ns / 1ps

// ============================================================================
// ai_accel_memory_fabric
// ----------------------------------------------------------------------------
// Structural home for the banked scratchpad fabric.  ai_spad_arbiter remains
// the only owner of the scheduler port; this wrapper only groups arbitration,
// response tagging/demultiplexing, SRAM storage, and protection checks.
// Registered scratchpad read timing is deliberately preserved.
// ============================================================================
module ai_accel_memory_fabric #(
    parameter integer WORDS_PER_BANK = 32768,
    parameter integer ROW_BITS = $clog2(WORDS_PER_BANK),
    parameter [31:0] SPAD_BYTES = 32'd524288
)(
    input wire clk, input wire resetn,
    input wire [31:0] region0_base, input wire [31:0] region0_limit, input wire [3:0] region0_perm,
    input wire [31:0] region1_base, input wire [31:0] region1_limit, input wire [3:0] region1_perm,
    input wire [31:0] region2_base, input wire [31:0] region2_limit, input wire [3:0] region2_perm,
    input wire [31:0] region3_base, input wire [31:0] region3_limit, input wire [3:0] region3_perm,
    input wire host_valid, input wire host_write, input wire [31:0] host_addr,
    input wire [31:0] host_wdata, input wire [3:0] host_wstrb,
    output wire [31:0] host_rdata, output wire host_error, output wire host_parity_error,
    output wire host_prot_allow,
    input wire desc_valid, input wire [31:0] desc_addr, output wire desc_ready,
    input wire cpl_valid, input wire cpl_write, input wire [31:0] cpl_addr,
    input wire [31:0] cpl_wdata, output wire cpl_ready,
    input wire core_valid, input wire core_write, input wire [31:0] core_addr,
    input wire [31:0] core_wdata, output wire core_ready,
    input wire core_line_valid, input wire core_line_write, input wire [31:0] core_line_addr,
    input wire [127:0] core_line_wdata, input wire [15:0] core_line_wstrb,
    output wire core_line_ready,
    input wire banked_valid, input wire [31:0] banked_addr, output wire banked_ready,
    input wire [3:0] cnm_valid, input wire [31:0] cnm_addr0, input wire [31:0] cnm_addr1,
    input wire [31:0] cnm_addr2, input wire [31:0] cnm_addr3, output wire [3:0] cnm_ready,
    input wire dma_valid, input wire dma_write, input wire [31:0] dma_addr,
    input wire [31:0] dma_wdata, output wire dma_ready,
    input wire dma_line_valid, input wire dma_line_write, input wire [31:0] dma_line_addr,
    input wire [127:0] dma_line_wdata, input wire [15:0] dma_line_wstrb,
    output wire dma_line_ready,
    input wire [31:0] cpl_base, input wire [31:0] cpl_index,
    output wire [31:0] scheduler_rdata, output wire scheduler_parity_error,
    output wire [127:0] line_rdata, output wire [3:0] line_parity_error, output wire line_raw_error,
    output wire [31:0] banked_data0, output wire [31:0] banked_data1,
    output wire [31:0] banked_data2, output wire [31:0] banked_data3,
    output wire [3:0] banked_parity, output wire [31:0] cnm_data0,
    output wire [31:0] cnm_data1, output wire [31:0] cnm_data2,
    output wire [31:0] cnm_data3, output wire [3:0] cnm_parity,
    output wire desc_rsp_valid, output wire core_rsp_valid,
    output wire banked_rsp_valid, output wire dma_rsp_valid,
    output wire dma_line_rsp_valid, output wire desc_rsp_error,
    output wire core_rsp_error, output wire dma_rsp_error,
    output wire [2:0] request_client, output wire [2:0] rsp_client,
    output wire rsp_valid, output wire rsp_error, output wire rsp_is_line,
    output wire [31:0] rsp_rdata,
    output wire [3:0] cnm_rsp_valid,
    output wire compute_protection_error, output wire banked_protection_error,
    output wire cnm_protection_error, output wire line_protection_error,
    output wire cpl_protection_error
);
    wire spad_valid;
    wire spad_write;
    wire [31:0] spad_addr;
    wire [31:0] spad_wdata;
    wire spad_line_valid;
    wire spad_line_write;
    wire [31:0] spad_line_addr;
    wire [127:0] spad_line_wdata;
    wire [15:0] spad_line_wstrb;
    wire arb_banked_valid;
    wire [31:0] arb_banked_addr;
    wire [3:0] arb_cnm_valid;
    wire [31:0] arb_cnm_addr0, arb_cnm_addr1, arb_cnm_addr2, arb_cnm_addr3;
    wire compute_prot_allow, line_prot_allow, banked_prot_allow, cpl_prot_allow;
    wire core_spad_error;
    wire spad_line_error;
    wire cnm_protection_error_request;
    reg cnm_protection_error_req_d;
    reg cnm_protection_error_rsp_r;

    ai_spad_arbiter spad_arbiter_u(
        .clk(clk), .resetn(resetn),
        .desc_valid(desc_valid), .desc_write(1'b0), .desc_addr(desc_addr), .desc_wdata(32'd0), .desc_ready(desc_ready),
        .cpl_valid(cpl_valid), .cpl_write(cpl_write), .cpl_addr(cpl_addr), .cpl_wdata(cpl_wdata), .cpl_ready(cpl_ready),
        .core_valid(core_valid), .core_write(core_write), .core_addr(core_addr), .core_wdata(core_wdata), .core_ready(core_ready),
        .core_line_valid(core_line_valid), .core_line_write(core_line_write), .core_line_addr(core_line_addr), .core_line_wdata(core_line_wdata), .core_line_wstrb(core_line_wstrb), .core_line_ready(core_line_ready),
        .banked_valid(banked_valid), .banked_addr(banked_addr), .banked_ready(banked_ready),
        .cnm_valid(cnm_valid), .cnm_addr0(cnm_addr0), .cnm_addr1(cnm_addr1), .cnm_addr2(cnm_addr2), .cnm_addr3(cnm_addr3), .cnm_ready(cnm_ready),
        .dma_valid(dma_valid), .dma_write(dma_write), .dma_addr(dma_addr), .dma_wdata(dma_wdata), .dma_ready(dma_ready),
        .dma_line_valid(dma_line_valid), .dma_line_write(dma_line_write), .dma_line_addr(dma_line_addr), .dma_line_wdata(dma_line_wdata), .dma_line_wstrb(dma_line_wstrb), .dma_line_ready(dma_line_ready),
        .spad_valid(spad_valid), .spad_write(spad_write), .spad_addr(spad_addr), .spad_wdata(spad_wdata),
        .spad_line_valid(spad_line_valid), .spad_line_write(spad_line_write), .spad_line_addr(spad_line_addr), .spad_line_wdata(spad_line_wdata), .spad_line_wstrb(spad_line_wstrb),
        .spad_banked_valid(arb_banked_valid), .spad_banked_addr(arb_banked_addr),
        .spad_cnm_valid(arb_cnm_valid), .spad_cnm_addr0(arb_cnm_addr0), .spad_cnm_addr1(arb_cnm_addr1), .spad_cnm_addr2(arb_cnm_addr2), .spad_cnm_addr3(arb_cnm_addr3),
        .spad_rdata(scheduler_rdata), .spad_error(core_spad_error), .spad_parity_error(scheduler_parity_error),
        .spad_line_error(spad_line_error), .spad_line_parity_error(line_parity_error),
        .rsp_valid(rsp_valid), .rsp_client(rsp_client), .rsp_is_line(rsp_is_line), .request_client(request_client),
        .rsp_rdata(rsp_rdata), .rsp_error(rsp_error), .cnm_rsp_valid(cnm_rsp_valid)
    );

    ai_spad_response_demux response_demux_u(
        .arb_rsp_valid(rsp_valid), .arb_rsp_error(rsp_error), .arb_rsp_is_line(rsp_is_line), .arb_rsp_client(rsp_client),
        .desc_rsp_valid(desc_rsp_valid), .core_rsp_valid(core_rsp_valid), .banked_rsp_valid(banked_rsp_valid),
        .dma_rsp_valid(dma_rsp_valid), .dma_line_rsp_valid(dma_line_rsp_valid),
        .desc_rsp_error(desc_rsp_error), .core_rsp_error(core_rsp_error), .dma_rsp_error(dma_rsp_error)
    );

    assign compute_protection_error = spad_valid &&
                                      (!compute_prot_allow || (spad_addr > SPAD_BYTES - 32'd4));
    // Preserve the exact error inputs that the original top supplied to the
    // scheduler.  They are sampled with the admitted request for the tagged
    // response two cycles later.
    assign core_spad_error = compute_protection_error;
    assign banked_protection_error = arb_banked_valid &&
                                     (!banked_prot_allow || (arb_banked_addr > SPAD_BYTES - 32'd16));
    // CNM protection is a response-side indication.  Tag the request only
    // when the arbiter accepts it, then delay the error alongside the
    // scratchpad's registered data and cnm_rsp_valid pipeline.
    assign cnm_protection_error_request =
        (arb_cnm_valid[0] && (arb_cnm_addr0 > SPAD_BYTES - 32'd4)) ||
        (arb_cnm_valid[1] && (arb_cnm_addr1 > SPAD_BYTES - 32'd4)) ||
        (arb_cnm_valid[2] && (arb_cnm_addr2 > SPAD_BYTES - 32'd4)) ||
        (arb_cnm_valid[3] && (arb_cnm_addr3 > SPAD_BYTES - 32'd4));
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cnm_protection_error_req_d <= 1'b0;
            cnm_protection_error_rsp_r <= 1'b0;
        end else begin
            cnm_protection_error_req_d <= (|cnm_ready) && cnm_protection_error_request;
            cnm_protection_error_rsp_r <= cnm_protection_error_req_d;
        end
    end
    assign cnm_protection_error = cnm_protection_error_rsp_r;
    assign line_protection_error = spad_line_valid &&
                                   (!line_prot_allow || (spad_line_addr > SPAD_BYTES - 32'd16));
    assign spad_line_error = line_raw_error || line_protection_error;
    assign cpl_protection_error = !cpl_prot_allow ||
                                  ((cpl_base + (cpl_index << 4)) > SPAD_BYTES - 32'd16);

    ai_accel_spad_subsystem #(
        .BANKS(4), .WORDS_PER_BANK(WORDS_PER_BANK), .ROW_BITS(ROW_BITS), .SPAD_BYTES(SPAD_BYTES)
    ) spad_subsystem_u(
        .clk(clk), .resetn(resetn),
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .host_valid(host_valid), .host_write(host_write), .host_addr(host_addr), .host_wdata(host_wdata), .host_wstrb(host_wstrb),
        .compute_valid(spad_valid), .compute_write(spad_write), .compute_addr(spad_addr), .compute_wdata(spad_wdata),
        .compute_req_execute((request_client == 3'd2) || (request_client == 3'd3)),
        .line_valid(spad_line_valid), .line_write(spad_line_write), .line_addr(spad_line_addr), .line_wdata(spad_line_wdata), .line_wstrb(spad_line_wstrb), .line_req_execute(request_client == 3'd2),
        .banked_valid(arb_banked_valid), .banked_addr(arb_banked_addr),
        .cnm_valid(arb_cnm_valid), .cnm_addr0(arb_cnm_addr0), .cnm_addr1(arb_cnm_addr1), .cnm_addr2(arb_cnm_addr2), .cnm_addr3(arb_cnm_addr3),
        .cpl_base(cpl_base), .cpl_index(cpl_index),
        .host_rdata(host_rdata), .host_error(host_error), .host_parity_error(host_parity_error),
        .compute_rdata(scheduler_rdata), .compute_parity_error(scheduler_parity_error),
        .line_rdata(line_rdata), .line_parity_error(line_parity_error), .line_raw_error(line_raw_error),
        .banked_data0(banked_data0), .banked_data1(banked_data1), .banked_data2(banked_data2), .banked_data3(banked_data3), .banked_parity_error(banked_parity),
        .cnm_data0(cnm_data0), .cnm_data1(cnm_data1), .cnm_data2(cnm_data2), .cnm_data3(cnm_data3), .cnm_parity_error(cnm_parity),
        .host_prot_allow(host_prot_allow), .compute_prot_allow(compute_prot_allow), .line_prot_allow(line_prot_allow), .banked_prot_allow(banked_prot_allow), .cpl_prot_allow(cpl_prot_allow)
    );
endmodule
