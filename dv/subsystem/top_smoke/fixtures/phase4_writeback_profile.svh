// Passive accepted Matrix payload log; no DUT control or state changes.
integer p4_line_fd=0,p4_line_clk=0;
initial begin : phase4_line_open
 string p;
 if($value$plusargs("PHASE1_PROFILE=%s",p))begin
  p4_line_fd=$fopen({p,"_lines.csv"},"w");
  if(!p4_line_fd)$fatal(1,"Phase4 line profile open failed");
  $fdisplay(p4_line_fd,"clock,address,data,wstrb");
 end
end
always @(posedge aclk)begin
 p4_line_clk=p4_line_clk+1;
 if(p4_line_fd && aresetn && transformer_top_timing_enable &&
    !transformer_top_final_captured && dut.matrix_line_valid && dut.arb_core_line_ready)
  $fdisplay(p4_line_fd,"%0d,%08h,%032h,%04h",p4_line_clk,dut.matrix_line_addr,
    dut.matrix_line_wdata,dut.matrix_line_wstrb);
end
