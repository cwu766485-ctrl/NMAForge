//=============================================================================
// Copyright (c) 2017 by www.eecourse.com Ltd
//=============================================================================
// Project  : ahb_soc
//
// File Name: ahb_slv_driver.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// driver class for ahb
//
//=============================================================================

`ifndef AHB_SLV_DRIVER_SV
`define AHB_SLV_DRIVER_SV

class ahb_slv_driver extends ahb_slv_driver_base;

  string name;

  typedef mailbox #(ahb_slv_pkt) in_driver_mailbox;
  in_driver_mailbox in_drv_mbx = new;

  typedef mailbox #(ahb_slv_pkt) out_driver_mailbox;
  out_driver_mailbox exp_mbx;

  bit done;
  int packets_sent;

  extern function new (
    string name="ahb_slv_driver",
    in_driver_mailbox in_drv_mbx=null,
    virtual ahb_slv_if.driver drv_if=null,
    out_driver_mailbox exp_mbx=null
  );
  
  extern virtual task start();

endclass

function ahb_slv_driver::new(
  string name="ahb_slv_driver",
  in_driver_mailbox in_drv_mbx=null,
  virtual ahb_slv_if.driver drv_if=null,
  out_driver_mailbox exp_mbx=null
);
  super.new(name, drv_if);
  this.name = name;
  this.in_drv_mbx = in_drv_mbx;
  if (this.in_drv_mbx == null)
    this.in_drv_mbx = new();
  this.exp_mbx = exp_mbx;
endfunction: new

task ahb_slv_driver::start();
  ahb_slv_pkt pkt_done;
  $display($time,"ns:[ahb_slv_driver] AHB Slave Driver Started");
  done = 1'b0;
  packets_sent = 0;
  fork
    forever begin
      in_drv_mbx.get(pkt2send);
      packets_sent++;
      $display($time,"ns:[ahb_slv_driver] Sending a new ahb_slv_pkt Begin");
      this.hsel   = pkt2send.hsel;
      this.hwrite = pkt2send.hwrite;
      this.hready = pkt2send.hready;
      this.hsize  = pkt2send.hsize;
      this.htrans = pkt2send.htrans;
      this.hburst = pkt2send.hburst;
      this.haddr  = pkt2send.haddr;
      this.hwdata = pkt2send.hwdata;

      send_ctrl_addr();
      process_data();
      pkt_done = pkt2send.clone();
      if (exp_mbx != null)
        exp_mbx.put(pkt_done.clone());
      $display($time, "ns:[ahb_slv_driver] Sending in new packet END");
      $display($time, "ns:[ahb_slv_driver] Number of packets sent = %0d", packets_sent);
      if(in_drv_mbx.num()==0) begin
        drive_idle();
        done = 1'b1;
        $display($time, "ns:[ahb_slv_driver] Driver done, total packets sent = %0d", packets_sent);
        break;
      end
    end
  join_none
endtask: start
`endif  //AHB_SLV_DRIVER_SV
