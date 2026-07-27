//=============================================================================
// Project  : ahb_soc
//
// File Name: ahb_slv_pkt.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// data modeling for ahb slave packet 
//
//=============================================================================

`ifndef AHB_SLV_PKT_SV
`define AHB_SLV_PKT_SV

class ahb_slv_pkt ; 

  string name;

  rand bit         hsel;
  rand bit         hwrite;
  rand bit         hready;
  rand bit  [2:0]  hsize;
  rand bit  [1:0]  htrans;
  rand bit  [2:0]  hburst;
  rand bit  [31:0] haddr;
  rand bit  [31:0] hwdata;
       bit  [31:0] hrdata;
       bit  [1:0]  hresp;
       bit         hready_resp;
       bit         irq;
       bit         expect_error;
       bit         check_hrdata;
       bit         check_hrdata_nonzero;
       bit  [31:0] expected_hrdata;
       bit         check_irq;
       bit         expected_irq;
       bit  [2:0]  vec_op;
       bit  [15:0] vec_len;
       bit  [1:0]  data_width;
       bit         signed_mode;
       bit         saturate_en;
       bit         round_en;
       bit  [15:0] neuron_count;
       bit  [1:0]  som_winner_pos;
       string      purpose;

  constraint valid {
    hsel    inside {1};
    hwrite  inside {0,1};
    hready  inside {1};
    hsize   inside {3'b000, 3'b001, 3'b010};
    htrans  inside {2'b10};
    hburst  inside {3'b000, 3'b001, 3'b011, 3'b101, 3'b111};
    haddr   inside {[0:65535]};
    (hsize == 3'b001) -> (haddr[0] == 1'b0);
    (hsize == 3'b010) -> (haddr[1:0] == 2'b00);
  }

  extern function new(string name = "ahb_slv_pkt");
  extern function ahb_slv_pkt clone();
  extern virtual task display();
endclass : ahb_slv_pkt 

function ahb_slv_pkt::new(string name = "ahb_slv_pkt");
  this.name = name ;
endfunction : new

function ahb_slv_pkt ahb_slv_pkt::clone();
  clone = new({this.name, "_copy"});
  clone.hsel   = this.hsel;
  clone.hwrite = this.hwrite;
  clone.hready = this.hready;
  clone.hsize  = this.hsize;
  clone.htrans = this.htrans;
  clone.hburst = this.hburst;
  clone.haddr  = this.haddr;
  clone.hwdata = this.hwdata;
  clone.hrdata = this.hrdata;
  clone.hresp  = this.hresp;
  clone.hready_resp = this.hready_resp;
  clone.irq = this.irq;
  clone.expect_error = this.expect_error;
  clone.check_hrdata = this.check_hrdata;
  clone.check_hrdata_nonzero = this.check_hrdata_nonzero;
  clone.expected_hrdata = this.expected_hrdata;
  clone.check_irq = this.check_irq;
  clone.expected_irq = this.expected_irq;
  clone.vec_op = this.vec_op;
  clone.vec_len = this.vec_len;
  clone.data_width = this.data_width;
  clone.signed_mode = this.signed_mode;
  clone.saturate_en = this.saturate_en;
  clone.round_en = this.round_en;
  clone.neuron_count = this.neuron_count;
  clone.som_winner_pos = this.som_winner_pos;
  clone.purpose = this.purpose;
endfunction : clone

task ahb_slv_pkt::display();
  $display("[%s] purpose=%s hsel=%0h hwrite=%0h hready=%0h hsize=%0h htrans=%0h hburst=%0h haddr=%0h hwdata=%0h hrdata=%0h hresp=%0h irq=%0h expect_error=%0h check=%0h nonzero=%0h exp=%0h check_irq=%0h exp_irq=%0h op=%0d len=%0d dw=%0d signed=%0d sat=%0d round=%0d neurons=%0d winner_pos=%0d",
           name, purpose, hsel, hwrite, hready, hsize, htrans, hburst, haddr, hwdata, hrdata, hresp, irq, expect_error, check_hrdata, check_hrdata_nonzero, expected_hrdata, check_irq, expected_irq, vec_op, vec_len, data_width, signed_mode, saturate_en, round_en, neuron_count, som_winner_pos);
endtask: display

`endif // AHB_SLV_PKT_SV
