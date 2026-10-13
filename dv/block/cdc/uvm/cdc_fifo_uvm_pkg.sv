`timescale 1ns/1ps
package cdc_fifo_uvm_pkg;
  import uvm_pkg::*; `include "uvm_macros.svh"
  parameter int W=32;
  class cdc_fifo_txn extends uvm_sequence_item;
    rand bit [W-1:0] data;
    `uvm_object_utils_begin(cdc_fifo_txn) `uvm_field_int(data,UVM_HEX) `uvm_object_utils_end
    function new(string n="cdc_fifo_txn"); super.new(n); endfunction
  endclass

  class cdc_fifo_scb extends uvm_component;
    `uvm_component_utils(cdc_fifo_scb)
    bit [W-1:0] expected[$]; int accepted_writes, accepted_reads, errors;
    function new(string n, uvm_component p); super.new(n,p); endfunction
    function void write_wr(cdc_fifo_txn t); expected.push_back(t.data); accepted_writes++; endfunction
    function void write_rd(cdc_fifo_txn t);
      accepted_reads++;
      if (!expected.size()) begin errors++; `uvm_error("SCB",$sformatf("unexpected read %08h",t.data)); end
      else if (expected.pop_front() !== t.data) begin errors++; `uvm_error("SCB",$sformatf("order/data mismatch got %08h",t.data)); end
    endfunction
    function void report_phase(uvm_phase phase);
      if (expected.size()!=0) `uvm_error("SCB",$sformatf("%0d accepted writes not read",expected.size()));
      `uvm_info("SCB",$sformatf("accepted writes=%0d reads=%0d errors=%0d",accepted_writes,accepted_reads,errors),UVM_LOW)
    endfunction
  endclass

  class cdc_fifo_env extends uvm_env;
    `uvm_component_utils(cdc_fifo_env)
    virtual cdc_fifo_if#(W) vif; cdc_fifo_scb scb;
    covergroup fifo_cg;
      option.per_instance=1;
      cp_full: coverpoint vif.wr_full {bins full={1};}
      cp_empty: coverpoint vif.rd_empty {bins empty={1};}
      cp_overflow: coverpoint vif.wr_overflow {bins seen={1};}
      cp_underflow: coverpoint vif.rd_underflow {bins seen={1};}
      cp_read_stall: coverpoint (vif.rd_valid && !vif.rd_ready) {bins stalled={1};}
      cp_reset: coverpoint {vif.wr_resetn,vif.rd_resetn} {bins wr_reset={2'b01}; bins rd_reset={2'b10}; bins both_up={2'b11};}
    endgroup
    function new(string n, uvm_component p); super.new(n,p); fifo_cg=new; endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); if(!uvm_config_db#(virtual cdc_fifo_if#(W))::get(this,"","vif",vif)) `uvm_fatal("NOVIF","missing vif");
      scb=cdc_fifo_scb::type_id::create("scb",this);
    endfunction
    task run_phase(uvm_phase phase);
      fork
        forever begin
          @(vif.wr_mon_cb);
          fifo_cg.sample();
          if (vif.wr_mon_cb.wr_resetn && vif.wr_mon_cb.wr_valid && vif.wr_mon_cb.wr_ready) begin
            cdc_fifo_txn t=new; t.data=vif.wr_mon_cb.wr_data; scb.write_wr(t);
          end
        end
        forever begin
          @(vif.rd_mon_cb);
          if (vif.rd_mon_cb.rd_resetn && vif.rd_mon_cb.rd_valid && vif.rd_mon_cb.rd_ready) begin
            cdc_fifo_txn t=new; t.data=vif.rd_mon_cb.rd_data; scb.write_rd(t);
          end
        end
      join_none
    endtask
    function void check_phase(uvm_phase phase);
      if(scb.errors!=0) `uvm_error("SCB",$sformatf("scoreboard errors=%0d",scb.errors));
    endfunction
  endclass

  class cdc_fifo_base_test extends uvm_test;
    `uvm_component_utils(cdc_fifo_base_test)
    cdc_fifo_env env; virtual cdc_fifo_if#(W) vif;
    function new(string n, uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); env=cdc_fifo_env::type_id::create("env",this); endfunction
    function void connect_phase(uvm_phase phase); vif=env.vif; endfunction
    task reset_both(); vif.wr_resetn=0; vif.rd_resetn=0; vif.wr_valid=0; vif.rd_ready=0; repeat(4) @(posedge vif.wr_clk); vif.wr_resetn=1; vif.rd_resetn=1; endtask
    task drain(int n=100); vif.rd_ready=1; repeat(n) @(posedge vif.rd_clk); repeat(10) @(posedge vif.rd_clk); endtask
    function void report_phase(uvm_phase phase); if(env.scb.expected.size()!=0) `uvm_error("TEST", "FIFO did not drain"); endfunction
  endclass

  class cdc_fifo_order_test extends cdc_fifo_base_test;
    `uvm_component_utils(cdc_fifo_order_test) function new(string n,uvm_component p);super.new(n,p);endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_both(); fork
      begin for(int i=0;i<80;i++) begin @(negedge vif.wr_clk); vif.wr_valid=($urandom_range(0,3)!=0); vif.wr_data=32'h1000+i; end vif.wr_valid=0; end
      begin repeat(6) @(posedge vif.rd_clk); for(int i=0;i<180;i++) begin @(negedge vif.rd_clk); vif.rd_ready=($urandom_range(0,4)!=0); end vif.rd_ready=1; end
    join drain(20); phase.drop_objection(this); endtask
  endclass

  class cdc_fifo_overflow_test extends cdc_fifo_base_test;
    `uvm_component_utils(cdc_fifo_overflow_test) function new(string n,uvm_component p);super.new(n,p);endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_both(); vif.wr_valid=1; vif.rd_ready=0; repeat(50) @(posedge vif.wr_clk); vif.wr_valid=0; if(!vif.wr_overflow) `uvm_error("OVF","sticky overflow not set"); vif.rd_ready=1; drain(300); phase.drop_objection(this); endtask
  endclass

  class cdc_fifo_underflow_test extends cdc_fifo_base_test;
    `uvm_component_utils(cdc_fifo_underflow_test) function new(string n,uvm_component p);super.new(n,p);endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_both(); vif.rd_ready=1; repeat(20) @(posedge vif.rd_clk); if(!vif.rd_underflow) `uvm_error("UDF","sticky underflow not set"); phase.drop_objection(this); endtask
  endclass

  class cdc_fifo_reset_test extends cdc_fifo_base_test;
    `uvm_component_utils(cdc_fifo_reset_test) function new(string n,uvm_component p);super.new(n,p);endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_both(); vif.wr_valid=0; vif.rd_ready=0; repeat(4) @(posedge vif.wr_clk); vif.wr_resetn=0; repeat(3) @(posedge vif.wr_clk); vif.wr_resetn=1; repeat(8) @(posedge vif.wr_clk); vif.rd_resetn=0; repeat(3) @(posedge vif.rd_clk); vif.rd_resetn=1; repeat(20) @(posedge vif.rd_clk); phase.drop_objection(this); endtask
  endclass

  class cdc_fifo_backpressure_test extends cdc_fifo_base_test;
    `uvm_component_utils(cdc_fifo_backpressure_test) function new(string n,uvm_component p);super.new(n,p);endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_both(); fork
      begin vif.wr_valid=1; for(int i=0;i<100;i++) begin @(negedge vif.wr_clk); vif.wr_data=i; end vif.wr_valid=0; end
      begin vif.rd_ready=0; repeat(100) @(posedge vif.rd_clk); vif.rd_ready=1; repeat(300) @(posedge vif.rd_clk); end
    join phase.drop_objection(this); endtask
  endclass
endpackage
