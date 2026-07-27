//=============================================================================
// Copyright (c) 2017 by www.eecourse.com Ltd
//=============================================================================
// Project  : ahb_soc
//
// File Name: ahb_slv_driver_base.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// driver base class for ahb
//
//=============================================================================

`ifndef AHB_SLV_DRIVER_BASE_SV
`define AHB_SLV_DRIVER_BASE_SV

class ahb_slv_driver_base;

  string  name ;
  virtual ahb_slv_if.driver drv_if;
  ahb_slv_pkt pkt2send;

  reg        hsel;
  reg        hwrite;
  reg        hready;
  reg [2:0]  hsize;
  reg [1:0]  htrans;
  reg [2:0]  hburst;
  reg [31:0] haddr;
  reg [31:0] hwdata;
  reg [31:0] hrdata;
  reg [1:0]  hresp;
  reg        hready_resp;
  reg        irq;

  extern function new (string name="ahb_slv_driver_base", virtual ahb_slv_if.driver drv_if=null);
  
  extern virtual task send_ctrl_addr();

  extern virtual task process_data();

  extern virtual task drive_idle();

endclass: ahb_slv_driver_base

function ahb_slv_driver_base::new(string name="ahb_slv_driver_base", virtual ahb_slv_if.driver drv_if=null);
  this.name = name;
  this.drv_if = drv_if;
endfunction: new

task ahb_slv_driver_base::send_ctrl_addr();
  $display($time, "ns: [ahb_slv_driver_base] Sending control and address signals");
  drv_if.drv_cb.hsel    <= hsel;
  drv_if.drv_cb.hwrite  <= hwrite;
  drv_if.drv_cb.hready  <= hready;
  drv_if.drv_cb.hsize   <= hsize;
  drv_if.drv_cb.htrans  <= htrans;
  drv_if.drv_cb.hburst  <= hburst;
  drv_if.drv_cb.haddr   <= haddr;
  @drv_if.drv_cb;
endtask: send_ctrl_addr

task ahb_slv_driver_base::process_data();
  drv_if.drv_cb.hwdata  <= hwdata;
  do begin
    @drv_if.drv_cb;
  end while (drv_if.drv_cb.hready_resp !== 1'b1);
  hrdata = drv_if.drv_cb.hrdata;
  hresp = drv_if.drv_cb.hresp;
  hready_resp = drv_if.drv_cb.hready_resp;
  irq = drv_if.drv_cb.irq;
endtask: process_data

task ahb_slv_driver_base::drive_idle();
  drv_if.drv_cb.hsel   <= 1'b0;
  drv_if.drv_cb.hwrite <= 1'b0;
  drv_if.drv_cb.hready <= 1'b1;
  drv_if.drv_cb.hsize  <= 3'b010;
  drv_if.drv_cb.htrans <= 2'b00;
  drv_if.drv_cb.hburst <= 3'b000;
  drv_if.drv_cb.haddr  <= 32'd0;
  drv_if.drv_cb.hwdata <= 32'd0;
endtask: drive_idle

`endif  // AHB_SLV_DRIVER_BASE_SV
