`timescale 1ns/1ps
module tb_cdc_fifo_uvm;
  logic wr_clk=0, rd_clk=0; always #2.5 wr_clk=~wr_clk; always #3.5 rd_clk=~rd_clk;
  cdc_fifo_if#(32) vif(wr_clk,rd_clk);
  ai_async_fifo#(.DATA_WIDTH(32),.DEPTH(8)) dut(.wr_clk(wr_clk),.wr_resetn(vif.wr_resetn),.wr_valid(vif.wr_valid),.wr_ready(vif.wr_ready),.wr_data(vif.wr_data),.wr_full(vif.wr_full),.rd_clk(rd_clk),.rd_resetn(vif.rd_resetn),.rd_valid(vif.rd_valid),.rd_ready(vif.rd_ready),.rd_data(vif.rd_data),.rd_empty(vif.rd_empty),.wr_overflow(vif.wr_overflow),.rd_underflow(vif.rd_underflow));
  initial begin uvm_config_db#(virtual cdc_fifo_if#(32))::set(null,"*","vif",vif); run_test(); end
endmodule
