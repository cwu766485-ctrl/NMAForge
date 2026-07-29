`timescale 1ns / 1ps

module tb_ai_spad_arbiter_rr;
  reg clk=0, resetn=0;
  reg desc_valid=0, desc_write=0;
  reg [31:0] desc_addr=0, desc_wdata=0;
  wire desc_ready;
  reg cpl_valid=0, cpl_write=0;
  reg [31:0] cpl_addr=0, cpl_wdata=0;
  wire cpl_ready;
  reg core_valid=0, core_write=0;
  reg [31:0] core_addr=0, core_wdata=0;
  wire core_ready;
  reg core_line_valid=0, core_line_write=0;
  reg [31:0] core_line_addr=0;
  reg [127:0] core_line_wdata=0;
  reg [15:0] core_line_wstrb=0;
  wire core_line_ready;
  reg banked_valid=0;
  reg [31:0] banked_addr=0;
  wire banked_ready;
  reg dma_valid=0, dma_write=0;
  reg [31:0] dma_addr=0, dma_wdata=0;
  wire dma_ready;
  reg dma_line_valid=0, dma_line_write=0;
  reg [31:0] dma_line_addr=0;
  reg [127:0] dma_line_wdata=0;
  reg [15:0] dma_line_wstrb=0;
  wire dma_line_ready;
  wire spad_valid, spad_write;
  wire [31:0] spad_addr, spad_wdata;
  wire spad_line_valid, spad_line_write;
  wire [31:0] spad_line_addr;
  wire [127:0] spad_line_wdata;
  wire [15:0] spad_line_wstrb;
  wire spad_banked_valid;
  wire [31:0] spad_banked_addr;
  reg [31:0] spad_rdata=0;
  reg spad_error=0;
  reg spad_parity_error=0;
  reg spad_line_error=0;
  reg [3:0] spad_line_parity_error=0;
  wire rsp_valid;
  wire [2:0] rsp_client;
  wire rsp_is_line;
  wire [2:0] request_client;
  wire [31:0] rsp_rdata;
  wire rsp_error;
  integer i;

  always #5 clk=~clk;
  ai_spad_arbiter dut(.*);

  initial begin
    repeat(3) @(posedge clk);
    resetn=1;
    core_valid=1;
    banked_valid=1;
    dma_valid=1;
    for(i=0;i<6;i=i+1) begin
      @(negedge clk);
      case(i%3)
        0: if(!core_ready || banked_ready || dma_ready)
             $fatal(1,"RR expected core at step %0d",i);
        1: if(core_ready || !banked_ready || dma_ready)
             $fatal(1,"RR expected banked at step %0d",i);
        2: if(core_ready || banked_ready || !dma_ready)
             $fatal(1,"RR expected DMA at step %0d",i);
      endcase
      @(posedge clk);
    end
    desc_valid=1;
    @(negedge clk);
    if(!desc_ready || core_ready || banked_ready || dma_ready)
      $fatal(1,"descriptor did not retain control-plane priority");
    @(posedge clk);
    desc_valid=0;
    core_valid=0;
    banked_valid=0;
    dma_valid=0;
    core_line_valid=1;
    core_line_addr=32'h100;
    @(negedge clk);
    if(!core_line_ready || core_ready || dma_line_ready ||
       !spad_line_valid || request_client!=3'd2)
      $fatal(1,"core 128-bit line request was not admitted");
    @(posedge clk);
    core_line_valid=0;
    dma_line_valid=1;
    dma_line_addr=32'h200;
    @(negedge clk);
    if(!dma_line_ready || dma_ready || core_line_ready ||
       !spad_line_valid || request_client!=3'd4)
      $fatal(1,"DMA 128-bit line request was not admitted");
    $display("Scratchpad round-robin arbiter PASS");
    $finish;
  end
endmodule
