//=============================================================================
// Copyright (c) 2017 by www.eecourse.com 
//=============================================================================
// Project  : ahb_soc
//
// File Name: ahb_slv_if.sv
//
// Author   : Name   :   
//            Email  :    
//            Dept   : 
//
// Version  : v1.0
//=============================================================================
// Description:
//
// Signal interface for agent ahb
//
//=============================================================================

`ifndef AHB_SLV_IF_SV
`define AHB_SLV_IF_SV

interface ahb_slv_if(input hclk); 
  logic         hresetn;
  logic	        hsel;
	logic	        hwrite;
  logic         hready;
  logic	[2:0] 	hsize;
  logic	[1:0] 	htrans;
  logic	[2:0] 	hburst;
  logic	[31:0]	hwdata;
  logic	[31:0]	haddr;	
  logic		      hready_resp;
  logic	[1:0] 	hresp;
  logic	[31:0]	hrdata;
  logic         irq;

  clocking drv_cb @(posedge hclk);
    output  hsel;
    output  hwrite;
    output  hready;
    output  hsize;
    output  htrans;
    output  hburst;
    output  haddr;
    output  hwdata;
    input   hready_resp;
    input   hresp;
    input   hrdata;
    input   irq;
  endclocking : drv_cb
  
  clocking mon_cb @(posedge hclk);
    input  hresetn;
    input  hready;
    input  hsel;
    input  hwrite;
    input  hsize;
    input  htrans;
    input  hburst;
    input  haddr;
    input  hwdata;
    input  hready_resp;
    input  hresp;
    input  hrdata;
    input  irq;
  endclocking : mon_cb
  
  modport driver (clocking drv_cb, output hresetn);
  modport monitor(clocking mon_cb);

  // You could add properties and assertions, for example
  // property name;
  // ...
  // endproperty : name
  // label: assert property(name);

endinterface : ahb_slv_if

`endif // AHB_SLV_IF_SV
