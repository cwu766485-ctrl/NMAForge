`timescale 1ns / 1ps

// AXI-Lite protocol boundary and control-window response selection.
// Register semantic ownership remains in ai_accel_regs / ai_command_processor;
// this module only adapts AW/W/B/AR/R to the internal request/response pair.
module ai_accel_control_fabric(
    input wire aclk, input wire aresetn,
    input wire [31:0] s_axi_awaddr, input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb, input wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0] s_axi_bresp, output wire s_axi_bvalid, input wire s_axi_bready,
    input wire [31:0] s_axi_araddr, input wire s_axi_arvalid, output wire s_axi_arready,
    output wire [31:0] s_axi_rdata, output wire [1:0] s_axi_rresp, output wire s_axi_rvalid, input wire s_axi_rready,
    output wire reg_req_valid, output wire reg_req_write, output wire [31:0] reg_req_addr,
    output wire [31:0] reg_req_wdata, output wire [3:0] reg_req_wstrb,
    input wire spad_window_selected, input wire [31:0] spad_rdata,
    input wire spad_error, input wire spad_parity_error, input wire spad_prot_allow,
    input wire [31:0] regs_rdata, input wire regs_error
);
    wire [31:0] reg_rsp_rdata = spad_window_selected ? spad_rdata : regs_rdata;
    wire reg_rsp_error = spad_window_selected ?
                         (spad_error || spad_parity_error || !spad_prot_allow) : regs_error;

    axi_lite_reg_if axi_lite_u(
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .reg_req_valid(reg_req_valid), .reg_req_write(reg_req_write), .reg_req_addr(reg_req_addr),
        .reg_req_wdata(reg_req_wdata), .reg_req_wstrb(reg_req_wstrb),
        .reg_rsp_rdata(reg_rsp_rdata), .reg_rsp_error(reg_rsp_error)
    );
endmodule
