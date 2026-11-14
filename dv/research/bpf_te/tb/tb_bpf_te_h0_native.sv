`timescale 1ns/1ps
module tb_bpf_te_h0_native;
  reg clk=0; always #5 clk=~clk; reg resetn=0;
  reg [3:0] cnm_valid=0; reg [31:0] ca0=0,ca1=4,ca2=8,ca3=12;
  wire [3:0] cnm_ready,cnm_rsp_valid; wire [31:0] d0,d1,d2,d3;
  wire [3:0] cnm_parity; wire cnm_prot;
  reg banked_valid=0; reg [31:0] banked_addr=0; wire banked_ready;
  wire [31:0] bank0,bank1,bank2,bank3; wire [3:0] bankpar;
  wire desc_ready,cpl_ready,core_ready,core_line_ready,dma_ready,dma_line_ready;
  wire [31:0] spad_rdata; wire spad_err,spad_pe,spad_line_err; wire [3:0] line_pe;
  wire [127:0] line_rdata; wire [31:0] req_client; wire [2:0] request_client,rsp_client;
  wire rsp_valid,rsp_error,rsp_is_line; wire [31:0] rsp_rdata; wire [3:0] unused;
  wire desc_rsp_valid,core_rsp_valid,banked_rsp_valid,dma_rsp_valid,dma_line_rsp_valid;
  wire desc_rsp_error,core_rsp_error,dma_rsp_error;
  wire compute_prot,banked_prot,cnm_prot_o,line_prot,cpl_prot;
  wire [31:0] desc_addr=0,cpl_addr=0,cpl_wdata=0,core_addr=0,core_wdata=0;
  wire [31:0] host_rdata,scheduler_rdata; wire host_error,host_pe,host_allow;
  wire [3:0] host_wstrb=0; wire [31:0] host_addr=0,host_wdata=0;
  ai_spad_arbiter arb(.clk(clk),.resetn(resetn),.desc_valid(0),.desc_write(0),.desc_addr(desc_addr),.desc_wdata(0),.desc_ready(desc_ready),
    .cpl_valid(0),.cpl_write(0),.cpl_addr(cpl_addr),.cpl_wdata(cpl_wdata),.cpl_ready(cpl_ready),
    .core_valid(0),.core_write(0),.core_addr(core_addr),.core_wdata(core_wdata),.core_ready(core_ready),
    .core_line_valid(0),.core_line_write(0),.core_line_addr(0),.core_line_wdata(0),.core_line_wstrb(0),.core_line_ready(core_line_ready),
    .banked_valid(banked_valid),.banked_addr(banked_addr),.banked_ready(banked_ready),.cnm_valid(cnm_valid),.cnm_addr0(ca0),.cnm_addr1(ca1),.cnm_addr2(ca2),.cnm_addr3(ca3),.cnm_ready(cnm_ready),
    .dma_valid(0),.dma_write(0),.dma_addr(0),.dma_wdata(0),.dma_ready(dma_ready),.dma_line_valid(0),.dma_line_write(0),.dma_line_addr(0),.dma_line_wdata(0),.dma_line_wstrb(0),.dma_line_ready(dma_line_ready),
    .spad_valid(),.spad_write(),.spad_addr(),.spad_wdata(),.spad_line_valid(),.spad_line_write(),.spad_line_addr(),.spad_line_wdata(),.spad_line_wstrb(),.spad_banked_valid(),.spad_banked_addr(),.spad_cnm_valid(),.spad_cnm_addr0(),.spad_cnm_addr1(),.spad_cnm_addr2(),.spad_cnm_addr3(),
    .spad_rdata(scheduler_rdata),.spad_error(0),.spad_parity_error(0),.spad_line_error(0),.spad_line_parity_error(0),.rsp_valid(rsp_valid),.rsp_client(rsp_client),.rsp_is_line(rsp_is_line),.cnm_rsp_valid(cnm_rsp_valid),.request_client(request_client),.rsp_rdata(rsp_rdata),.rsp_error(rsp_error));
  ai_scratchpad spad(.clk(clk),.resetn(resetn),.host_valid(0),.host_write(0),.host_addr(host_addr),.host_wdata(host_wdata),.host_wstrb(host_wstrb),.host_rdata(host_rdata),.host_error(host_error),.host_parity_error(host_pe),
    .compute_valid(0),.compute_write(0),.compute_addr(0),.compute_wdata(0),.compute_rdata(scheduler_rdata),.compute_parity_error(),.line_valid(0),.line_write(0),.line_addr(0),.line_wdata(0),.line_wstrb(0),.line_rdata(line_rdata),.line_parity_error(line_pe),.line_error(spad_line_err),
    .banked_read_valid(banked_valid),.banked_addr(banked_addr),.banked_data0(bank0),.banked_data1(bank1),.banked_data2(bank2),.banked_data3(bank3),.banked_parity_error(bankpar),.cnm_read_valid(cnm_valid),.cnm_addr0(ca0),.cnm_addr1(ca1),.cnm_addr2(ca2),.cnm_addr3(ca3),.cnm_data0(d0),.cnm_data1(d1),.cnm_data2(d2),.cnm_data3(d3),.cnm_parity_error(cnm_parity));
  integer t,cnm_accept,cnm_rsp,bank_accept,bank_rsp,cnm_cycles,bank_cycles;
  assign banked_rsp_valid = rsp_valid && (rsp_client == 3'd3);
  initial begin repeat(3) @(negedge clk); resetn=1;
    cnm_valid=4'hf; t=0; while (!(&cnm_ready) && t<20) begin @(negedge clk); t=t+1; end
    if (!(&cnm_ready)) $fatal(1,"H0 CNM never accepted"); cnm_accept=1; @(negedge clk); cnm_valid=0;
    cnm_cycles=0; repeat(5) begin @(negedge clk); cnm_cycles=cnm_cycles+1; if (|cnm_rsp_valid) cnm_rsp=cnm_rsp+1; end
    if (cnm_rsp==0) $fatal(1,"H0 CNM response absent"); $display("BPF_TE_H0_NATIVE_CNM_PASS accept=%0d response=%0d cycles=%0d",cnm_accept,cnm_rsp,cnm_cycles);
    banked_valid=1; banked_addr=32'h40; t=0; while (!banked_ready && t<20) begin @(negedge clk); t=t+1; end
    if (!banked_ready) $fatal(1,"H0 banked never accepted"); bank_accept=1; @(negedge clk); banked_valid=0;
    bank_cycles=0; repeat(5) begin @(negedge clk); bank_cycles=bank_cycles+1; if (banked_rsp_valid) bank_rsp=bank_rsp+1; end
    if (bank_rsp==0) $fatal(1,"H0 banked response absent"); $display("BPF_TE_H0_NATIVE_BANKED_PASS accept=%0d response=%0d cycles=%0d",bank_accept,bank_rsp,bank_cycles);
    $finish;
  end
  initial begin cnm_rsp=0; bank_rsp=0; end
endmodule
