//=============================================================================
// Project  : ahb_soc
//
// File Name: ahb_slv_fcoverage.sv
//
// Description:
//   Functional coverage collector for the class-based SV testbench. The driver
//   sends completed transactions to this class through a mailbox; this class
//   samples access direction, access size, transfer type and address alignment.
//=============================================================================

`ifndef AHB_SLV_FCOVERAGE_SV
`define AHB_SLV_FCOVERAGE_SV

class ahb_slv_fcoverage;
  string name;
  ahb_slv_pkt pkt_sent;

  typedef mailbox #(ahb_slv_pkt) in_mailbox;
  in_mailbox sb_mbx;

  covergroup ahb_slv_cg;
    option.per_instance = 1;

    cp_hwrite: coverpoint pkt_sent.hwrite {
      bins read  = {0};
      bins write = {1};
    }

    cp_hsize: coverpoint pkt_sent.hsize {
      bins byte_access     = {3'b000};
      bins halfword_access = {3'b001};
      bins word_access     = {3'b010};
      bins illegal_size    = {[3'b011:3'b111]};
    }

    cp_htrans: coverpoint pkt_sent.htrans {
      bins idle   = {2'b00};
      bins busy   = {2'b01};
      bins nonseq = {2'b10};
      bins seq    = {2'b11};
    }

    cp_addr_align: coverpoint pkt_sent.haddr[1:0] {
      bins byte0 = {2'b00};
      bins byte1 = {2'b01};
      bins byte2 = {2'b10};
      bins byte3 = {2'b11};
    }

    cp_addr_lane_sel: coverpoint pkt_sent.haddr[15:13] {
      bins lane_bank_sel[] = {[3'b000:3'b111]};
    }

    cp_hburst: coverpoint pkt_sent.hburst {
      bins single = {3'b000};
      bins incr   = {3'b001};
      bins incr4  = {3'b011};
      bins incr8  = {3'b101};
      bins incr16 = {3'b111};
      bins unsupported_wrap = {3'b010, 3'b100, 3'b110};
    }

    cp_hresp: coverpoint pkt_sent.hresp {
      bins okay  = {2'b00};
      bins error = {2'b01};
    }

    cp_region: coverpoint pkt_sent.haddr[16] {
      bins scratchpad_sram = {1'b0};
      bins register_space  = {1'b1};
    }

    cp_vec_op: coverpoint pkt_sent.vec_op {
      bins vadd   = {3'd0};
      bins vsub   = {3'd1};
      bins vmac   = {3'd2};
      bins l1dist = {3'd3};
      bins vmul   = {3'd4};
      bins som_recall = {3'd5};
      bins som_update = {3'd6};
      bins illegal = {3'd7};
    }

    cp_vec_len: coverpoint pkt_sent.vec_len {
      bins len0  = {16'd0};
      bins len1  = {16'd1};
      bins len2  = {16'd2};
      bins len3  = {16'd3};
      bins len4  = {16'd4};
      bins len8  = {16'd8};
      bins len16 = {16'd16};
    }

    cp_irq: coverpoint pkt_sent.irq {
      bins deasserted = {1'b0};
      bins asserted   = {1'b1};
    }

    cp_data_width: coverpoint pkt_sent.data_width {
      bins int32_word = {2'd0};
      bins int16x2    = {2'd1};
      bins int8x4     = {2'd2};
      bins illegal    = {2'd3};
    }

    cp_signed_mode: coverpoint pkt_sent.signed_mode {
      bins unsigned_mode = {1'b0};
      bins signed_mode   = {1'b1};
    }

    cp_saturate_en: coverpoint pkt_sent.saturate_en {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_round_en: coverpoint pkt_sent.round_en {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_neuron_count: coverpoint pkt_sent.neuron_count {
      bins none = {16'd0};
      bins one  = {16'd1};
      bins two  = {16'd2};
      bins three = {16'd3};
      bins small_many = {[16'd4:16'd16]};
    }

    cp_som_winner_pos: coverpoint pkt_sent.som_winner_pos {
      bins first  = {2'd0};
      bins middle = {2'd1};
      bins last   = {2'd2};
      bins unused  = {2'd3};
    }

    cp_check_hrdata: coverpoint pkt_sent.check_hrdata {
      bins unchecked = {0};
      bins checked   = {1};
    }

    cp_check_irq: coverpoint pkt_sent.check_irq {
      bins unchecked = {1'b0};
      bins checked   = {1'b1};
    }

    cp_expected_error: coverpoint pkt_sent.expect_error {
      bins legal_access   = {0};
      bins illegal_access = {1};
    }

    cross_hwrite_hsize: cross cp_hwrite, cp_hsize;
    cross_burst_resp: cross cp_hburst, cp_hresp {
      ignore_bins unsupported_wrap_okay =
        binsof(cp_hburst.unsupported_wrap) && binsof(cp_hresp.okay);
      ignore_bins incr8_error_not_target =
        binsof(cp_hburst.incr8) && binsof(cp_hresp.error);
      ignore_bins incr16_error_not_target =
        binsof(cp_hburst.incr16) && binsof(cp_hresp.error);
    }
    cross_region_resp: cross cp_region, cp_hresp;
    cross_op_check: cross cp_vec_op, cp_check_hrdata;
    cross_irq_check: cross cp_irq, cp_check_irq;
    cross_op_data_width: cross cp_vec_op, cp_data_width {
      ignore_bins non_som_illegal_width =
        binsof(cp_vec_op.vadd) && binsof(cp_data_width.illegal);
    }
    cross_som_neuron: cross cp_vec_op, cp_neuron_count {
      ignore_bins non_som_many_neurons =
        (binsof(cp_vec_op.vadd) || binsof(cp_vec_op.vsub) || binsof(cp_vec_op.vmac) ||
         binsof(cp_vec_op.l1dist) || binsof(cp_vec_op.vmul) || binsof(cp_vec_op.illegal)) &&
        (binsof(cp_neuron_count.two) || binsof(cp_neuron_count.three) ||
         binsof(cp_neuron_count.small_many));
    }
    cross_saturate_width: cross cp_saturate_en, cp_data_width {
      ignore_bins illegal_width_saturation =
        binsof(cp_saturate_en.enabled) && binsof(cp_data_width.illegal);
    }
    cross_round_op: cross cp_round_en, cp_vec_op {
      ignore_bins round_not_multiply =
        binsof(cp_round_en.enabled) &&
        (binsof(cp_vec_op.vadd) || binsof(cp_vec_op.vsub) ||
         binsof(cp_vec_op.l1dist) || binsof(cp_vec_op.som_recall) ||
         binsof(cp_vec_op.som_update) || binsof(cp_vec_op.illegal));
    }
  endgroup

  function new(string name="ahb_slv_fcoverage");
    this.name = name;
    pkt_sent = new("coverage_pkt");
    sb_mbx = new();
    ahb_slv_cg = new();
  endfunction

  extern virtual task start();
  extern function void report();
endclass : ahb_slv_fcoverage

task ahb_slv_fcoverage::start();
  $display($time, "ns:[ahb_slv_fcoverage] Functional coverage started");
  fork
    forever begin
      sb_mbx.get(pkt_sent);
      ahb_slv_cg.sample();
    end
  join_none
endtask : start

function void ahb_slv_fcoverage::report();
  $display("============================================================");
  $display("[ahb_slv_fcoverage] Functional coverage = %.2f%%", ahb_slv_cg.get_inst_coverage());
  $display("============================================================");
endfunction : report

`endif // AHB_SLV_FCOVERAGE_SV
