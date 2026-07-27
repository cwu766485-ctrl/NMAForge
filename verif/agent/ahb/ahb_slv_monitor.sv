//=============================================================================
// Project  : ahb_soc
//
// File Name: ahb_slv_monitor.sv
//
// Description:
//   Passive AHB monitor. It does not drive any signal. It only samples the
//   real bus transaction from the interface and sends the observed result to
//   scoreboard/coverage users through a mailbox.
//=============================================================================

`ifndef AHB_SLV_MONITOR_SV
`define AHB_SLV_MONITOR_SV

class ahb_slv_monitor;

  string name;
  virtual ahb_slv_if.monitor mon_if;

  typedef mailbox #(ahb_slv_pkt) out_monitor_mailbox;
  out_monitor_mailbox mon_mbx;

  extern function new(
    string name="ahb_slv_monitor",
    virtual ahb_slv_if.monitor mon_if=null,
    out_monitor_mailbox mon_mbx=null
  );

  extern virtual task start();
  extern virtual task collect_one(ref ahb_slv_pkt pkt);

endclass : ahb_slv_monitor

function ahb_slv_monitor::new(
  string name="ahb_slv_monitor",
  virtual ahb_slv_if.monitor mon_if=null,
  out_monitor_mailbox mon_mbx=null
);
  this.name = name;
  this.mon_if = mon_if;
  this.mon_mbx = mon_mbx;
  if (this.mon_mbx == null)
    this.mon_mbx = new();
endfunction : new

task ahb_slv_monitor::collect_one(ref ahb_slv_pkt pkt);
  pkt = new($sformatf("%s_actual", name));

  pkt.hsel   = mon_if.mon_cb.hsel;
  pkt.hwrite = mon_if.mon_cb.hwrite;
  pkt.hready = mon_if.mon_cb.hready;
  pkt.hsize  = mon_if.mon_cb.hsize;
  pkt.htrans = mon_if.mon_cb.htrans;
  pkt.hburst = mon_if.mon_cb.hburst;
  pkt.haddr  = mon_if.mon_cb.haddr;
  pkt.hwdata = 32'd0;

  do begin
    @mon_if.mon_cb;
  end while (mon_if.mon_cb.hready_resp !== 1'b1);

  pkt.hrdata      = mon_if.mon_cb.hrdata;
  pkt.hresp       = mon_if.mon_cb.hresp;
  pkt.hready_resp = mon_if.mon_cb.hready_resp;
  pkt.irq         = mon_if.mon_cb.irq;
  pkt.hwdata      = mon_if.mon_cb.hwdata;
endtask : collect_one

task ahb_slv_monitor::start();
  ahb_slv_pkt actual_pkt;
  int packets_seen = 0;
  $display($time, "ns:[ahb_slv_monitor] Passive monitor started");

  fork
    forever begin
      @mon_if.mon_cb;

      if (mon_if.mon_cb.hresetn !== 1'b1)
        continue;

      if (mon_if.mon_cb.hsel && mon_if.mon_cb.hready) begin
        collect_one(actual_pkt);
        packets_seen++;
        $display($time, "ns:[ahb_slv_monitor] Observed transaction %0d", packets_seen);
        mon_mbx.put(actual_pkt);
      end
    end
  join_none
endtask : start

`endif // AHB_SLV_MONITOR_SV
