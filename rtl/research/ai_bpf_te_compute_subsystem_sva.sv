`timescale 1ns/1ps

// Research-top protocol checks. These checks are intentionally local to the
// isolated wrapper and do not alter the product ABI.
module ai_bpf_te_compute_subsystem_sva(
    input wire clk, input wire resetn, input wire epoch_bump,
    input wire cnm_spad_valid, input wire cnm_spad_ready,
    input wire output_write_commit, input wire matrix_line_commit
);
  property p_cnm_write_commit;
    @(posedge clk) disable iff (!resetn)
      (cnm_spad_valid && cnm_spad_ready) |-> output_write_commit;
  endproperty
  property p_epoch_blocks_writeback;
    @(posedge clk) disable iff (!resetn)
      epoch_bump |-> (!output_write_commit && !matrix_line_commit);
  endproperty
  ap_cnm_write_commit: assert property (p_cnm_write_commit);
  ap_epoch_blocks_writeback: assert property (p_epoch_blocks_writeback);
  cp_epoch_event: cover property (@(posedge clk) disable iff (!resetn) epoch_bump);
  cp_cnm_write: cover property (@(posedge clk) disable iff (!resetn)
                                  cnm_spad_valid && cnm_spad_ready);
endmodule
