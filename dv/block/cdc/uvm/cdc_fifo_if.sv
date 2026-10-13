`timescale 1ns/1ps
interface cdc_fifo_if #(parameter int W=32) (input logic wr_clk, rd_clk);
  logic wr_resetn, rd_resetn, wr_valid, wr_ready, wr_full;
  logic [W-1:0] wr_data;
  logic rd_valid, rd_ready, rd_empty;
  logic [W-1:0] rd_data;
  logic wr_overflow, rd_underflow;

  // Monitor handshake signals in the preponed region.  Sampling bare signals
  // from an @posedge process races DUT sequential and combinational updates.
  clocking wr_mon_cb @(posedge wr_clk);
    input #1step wr_resetn, wr_valid, wr_ready, wr_data;
  endclocking
  clocking rd_mon_cb @(posedge rd_clk);
    input #1step rd_resetn, rd_valid, rd_ready, rd_data;
  endclocking
  // Ready/valid payload must not change while a consumer is stalled.
  property p_rd_data_stable;
    @(posedge rd_clk) disable iff (!rd_resetn)
      rd_valid && !rd_ready |=> rd_valid && $stable(rd_data);
  endproperty
  a_rd_data_stable: assert property (p_rd_data_stable)
    else $error("CDC FIFO rd_data changed while stalled");
endinterface
