// Independent integer Golden, transaction-order and fault-prefix scoreboards.
reg p4_check=0;
integer p4_seen=0,p4_lines=0,p4_done_pulses=0,p4_overlap=0,p4_both_full=0;
reg [127:0] p4_payload[0:63];
reg [31:0] p4_address[0:63];
integer p4_i,p4_w;
wire output_write_accept_for_p4 = line_valid && line_ready && !line_protection_error;
always @(posedge clk)if(resetn && p4_check)begin
 if(done)p4_done_pulses=p4_done_pulses+1;
 if(dut.fused_pingpong && dut.state_r==9)begin
  if(dut.fused_line_full_r==3)p4_both_full=p4_both_full+1;
  if(output_write_accept_for_p4 && !dut.fused_pack_done_r &&
     !dut.fused_line_full_r[dut.fused_pack_bank_r])p4_overlap=p4_overlap+1;
 end
 if(line_valid && line_ready && !line_protection_error)begin
  if(p4_seen>=p4_lines || line_addr!==p4_address[p4_seen] ||
     line_wdata!==p4_payload[p4_seen] || line_wstrb!==16'hffff)
   $fatal(1,"PHASE4 transaction ordinal=%0d addr=%08h expected=%08h payload=%032h expected=%032h",p4_seen,line_addr,p4_address[p4_seen],line_wdata,p4_payload[p4_seen]);
  p4_seen=p4_seen+1;
 end
 if(dut.fused_pingpong && dut.state_r==10 && dut.fused_line_full_r!=0)
  $fatal(1,"PHASE4 accumulator cleared before buffer drain");
end

task automatic p4_prepare(input integer m,n,rowmajor,shift,act);
 integer rr,cc,kk,i,j,idx,rg,cg,localrow,line;
 integer signed x;
 reg [127:0] packedline;
 begin
  p4_check=0;
  prepare_case(m,n,4,1,0,0,1,1,act,0,0);
  op_mode=8'h53;aux0=(rowmajor?128:0)|shift;
  for(i=0;i<256;i=i+1)output_mem[(DST_BASE>>2)+i]=32'hbad00000+((DST_BASE>>2)+i);
  p4_lines=0;p4_seen=0;p4_done_pulses=0;p4_overlap=0;p4_both_full=0;
  // Walk the existing line order, independently of DUT pack/commit pointers.
  for(rg=0;rg<m;rg=rg+16)for(cg=0;cg<n;cg=cg+16)begin
   for(line=0;line<((m-rg>=16)?16:4);line=line+1)begin
    packedline=0;
    for(i=0;i<16;i=i+1)begin
     if(rowmajor)begin rr=rg+line;cc=cg+i;end
     else begin rr=rg+(line/4)*4+i/4;cc=cg+(line%4)*4+i%4;end
     x=0;
     for(kk=0;kk<16;kk=kk+1)x=x+$signed(logical_a[0][rr][kk])*$signed(logical_b[0][kk][cc]);
     x=x+logical_bias[cc];x=x>>>1;
     if(act==1 && x<0)x=0;
     if(act==2)begin if(x<0)x=0;else if(x>6)x=6;end
     x=x>>>shift;if(x>127)x=127;else if(x< -128)x= -128;
     packedline[i*8+:8]=x[7:0];
    end
    p4_payload[p4_lines]=packedline;
    p4_address[p4_lines]=rowmajor ? DST_BASE+(rg+line)*16 :
      DST_BASE+((rg/4+line/4)*n*4)+cg*4+(line%4)*16;
    p4_lines=p4_lines+1;
   end
  end
  force_banked_ready=1;force_zero_bank_latency=1;
  force_line_ready=1;force_line_stall=0;watchdog_limit=0;
  inject_line_protection=0;p4_check=1;
 end
endtask

task automatic p4_start;
 begin @(negedge clk);start=1;@(negedge clk);start=0;end
endtask

task automatic p4_finish(input integer expected_error,prefix);
 integer timeout,i,j,word_index;reg [31:0] expword;
 begin
  timeout=0;while(!done && timeout<10000)begin @(negedge clk);timeout=timeout+1;end
  if(!done||error_code!=expected_error||error!=(expected_error!=0)||p4_seen!=prefix)
   $fatal(1,"PHASE4 completion error=%0d expected=%0d prefix=%0d expected=%0d state=%0d",error_code,expected_error,p4_seen,prefix,dut.state_r);
  // Verify committed prefix and untouched suffix independently of line counters.
  for(i=0;i<p4_lines;i=i+1)for(j=0;j<4;j=j+1)begin
   word_index=(p4_address[i]>>2)+j;
   expword=i<prefix ? p4_payload[i][j*32+:32] : (32'hbad00000+word_index);
   if(output_mem[word_index]!==expword)$fatal(1,"PHASE4 memory prefix/suffix mismatch line=%0d word=%0d",i,j);
  end
  repeat(4)@(negedge clk);
  if(p4_done_pulses!=1||p4_seen!=prefix||busy)$fatal(1,"PHASE4 exactly-once/quiet recovery failed pulses=%0d",p4_done_pulses);
  p4_check=0;inject_line_protection=0;force_line_stall=0;force_line_ready=0;
 end
endtask

task automatic run_phase4_writeback_campaign;
 integer i,mode,prefix,timeout,cycles,overlaps,full_seen,write_entry,j,wi;
 reg [31:0] ew;
 begin
  // Both layout variants; partial m20 falls back for its last tile. n32 checks
  // the original tile-major destination stride and independent commit address.
  for(mode=0;mode<2;mode=mode+1)begin
   p4_prepare(16,16,mode,2,0);p4_start();
   p4_finish(0,p4_lines);
   $display("PHASE4_WRITEBACK_GOLDEN_PASS rowmajor=%0d cycles=%0d overlap=%0d",mode,cycle_count,p4_overlap);
  end
  p4_prepare(16,32,0,1,1);p4_start();p4_finish(0,p4_lines);
  p4_prepare(20,16,1,3,2);p4_start();p4_finish(0,p4_lines);
  // Hold the head long enough to fill both banks, then verify stable release.
  p4_prepare(16,16,1,2,0);force_line_stall=1;p4_start();
  timeout=0;while(!line_valid&&timeout<5000)begin @(negedge clk);timeout=timeout+1;end
  repeat(15)@(negedge clk);
  if(dut.fused_pingpong && dut.fused_line_full_r!=3)$fatal(1,"PHASE4 failed to fill both output buffers");
  force_line_stall=0;p4_finish(0,16);
  if(dut.ENABLE_FUSED_PINGPONG_WRITEBACK && (p4_overlap==0||p4_both_full==0))$fatal(1,"PHASE4 overlap/full-bank stimulus missing");
  for(i=0;i<16;i=i+1)begin
   p4_prepare(16,16,1,2,0);inject_line_protection=1;line_protection_addr=p4_address[i];
   p4_start();p4_finish(ERR_PROTECTION,i);
  end
  // Abort, watchdog, simultaneous abort+watchdog+denied head; stop at each prefix.
  for(mode=0;mode<3;mode=mode+1)for(prefix=0;prefix<16;prefix=prefix+1)begin
   p4_prepare(16,16,1,2,0);
   if(mode!=0)watchdog_limit=32'hffffffff;
   p4_start();timeout=0;
   if(prefix==0)begin
    force_line_stall=1;
    while(!line_valid && timeout<5000)begin @(negedge clk);timeout=timeout+1;end
   end
   while(p4_seen<prefix&&timeout<5000)begin @(negedge clk);timeout=timeout+1;end
   force_line_stall=1;repeat(2)@(negedge clk);
   if(mode==0 || mode==2)abort=1;
   if(mode!=0)begin
    // Drive the original public watchdog register input before command launch
    // is impossible mid-command. Use a directed state-register probe here only
    // to exercise its existing priority at this exact buffered phase.
    force dut.watchdog_limit_r=1;
   end
   if(mode==2)begin inject_line_protection=1;line_protection_addr=line_addr;end
   @(negedge clk);abort=0;
   if(mode!=0)release dut.watchdog_limit_r;
   p4_finish(mode==1?ERR_WATCHDOG:ERR_ABORT,p4_seen);
  end
  // Public programmed watchdog deadline, held at an actual buffered head.
  p4_prepare(16,16,1,2,0);force_line_stall=1;p4_start();timeout=0;
  while(!line_valid && timeout<5000)begin @(negedge clk);timeout=timeout+1;end
  write_entry=cycle_count;force_line_stall=0;p4_finish(0,16);
  for(i=0;i<4;i=i+1)begin
   p4_prepare(16,16,1,2,0);watchdog_limit=write_entry+100+i;force_line_stall=1;
   p4_start();p4_finish(ERR_WATCHDOG,0);
  end
  // Reset at all sixteen accepted prefixes, inject old response and recover.
  for(prefix=0;prefix<16;prefix=prefix+1)begin
   p4_prepare(16,16,1,2,0);p4_start();timeout=0;
   if(prefix==0)begin
    force_line_stall=1;
    while(!line_valid && timeout<5000)begin @(negedge clk);timeout=timeout+1;end
   end
   while(p4_seen<prefix&&timeout<5000)begin @(negedge clk);timeout=timeout+1;end
   force_line_stall=1;repeat(2)@(negedge clk);
   full_seen=p4_seen;
   p4_check=0;resetn=0;repeat(2)@(negedge clk);resetn=1;
   repeat(4)@(negedge clk);
   if(done||busy||line_valid||dut.fused_line_full_r!=0)$fatal(1,"PHASE4 reset stale state");
   for(i=0;i<p4_lines;i=i+1)for(j=0;j<4;j=j+1)begin
    wi=(p4_address[i]>>2)+j;
    ew=i<full_seen?p4_payload[i][j*32+:32]:(32'hbad00000+wi);
    if(output_mem[wi]!==ew)$fatal(1,"PHASE4 reset committed prefix changed");
   end
   inject_orphan_bank_response=1;repeat(3)@(negedge clk);
   p4_prepare(16,16,1,2,0);p4_start();p4_finish(0,16);
  end
  // Random latency/backpressure, fixed independent integer Golden.
  for(i=0;i<20;i=i+1)begin
   p4_prepare(16,16,i%2,i%5,i%3);
   force_line_ready=0;force_banked_ready=0;force_zero_bank_latency=0;
   p4_start();p4_finish(0,16);
  end
  $display("PHASE4_WRITEBACK_RTL_PASS seed=%0d protection=16 abort_watchdog_priority=48 reset_recovery=16 public_watchdog=4 random=20 partial_tile=1 layouts=2 order_payload_wstrb=checked",initial_seed);
 end
endtask
