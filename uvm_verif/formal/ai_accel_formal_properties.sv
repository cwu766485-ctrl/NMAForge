// Bind this checker in a VC Formal harness after selecting the exact exposed
// top-level signals.  It is deliberately protocol-only and does not constrain
// DUT internals.
module ai_accel_formal_axi_properties (
    input logic clk, input logic resetn,
    input logic arvalid, input logic arready, input logic [63:0] araddr,
    input logic [7:0] arlen, input logic [2:0] arsize,
    input logic awvalid, input logic awready, input logic [63:0] awaddr,
    input logic [7:0] awlen, input logic [2:0] awsize
);
    default clocking cb @(posedge clk); endclocking
    default disable iff (!resetn);
    assert property (arvalid && !arready |=> arvalid && $stable({araddr, arlen, arsize}));
    assert property (awvalid && !awready |=> awvalid && $stable({awaddr, awlen, awsize}));
    // Address + total burst bytes may not cross one 4 KiB AXI boundary.
    assert property (arvalid && arready |-> ((araddr[11:0] + ((arlen + 1) << arsize)) <= 13'h1000));
    assert property (awvalid && awready |-> ((awaddr[11:0] + ((awlen + 1) << awsize)) <= 13'h1000));
endmodule
