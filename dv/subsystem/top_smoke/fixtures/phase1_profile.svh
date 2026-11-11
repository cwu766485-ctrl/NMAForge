// Passive Phase 1 audit: no forcing, no DUT parameter or state changes.
integer p1_fd=0,p1_mem_fd=0,p1_clk=0,p1_window=-1,p1_ms,p1_ss,p1_bucket;
reg p1_active=0;reg [7:0] p1_req,p1_acc,p1_wr;
reg [31:0] p1_addr[0:7];integer p1_i,p1_bytes,p1_owner;
initial begin : phase1_open
 string p;
 if($value$plusargs("PHASE1_PROFILE=%s",p))begin
  p1_fd=$fopen({p,"_cycles.csv"},"w");p1_mem_fd=$fopen({p,"_memory.csv"},"w");
  if(!p1_fd || !p1_mem_fd)$fatal(1,"Phase1 profile open failed");
  $fdisplay(p1_fd,"window,clock,bucket,matrix_state,sfu_state,sfu_opcode,matrix_busy,sfu_busy,prefetch_overlap,prefetch_active,outstanding,request_mask,accept_mask,desc,cpl");
  $fdisplay(p1_mem_fd,"window,clock,kind,client,write,address,bytes,bank_mask,error");
 end
end
always @(posedge aclk)begin
 p1_clk=p1_clk+1;
 if(p1_fd && aresetn)begin
  if(transformer_top_timing_enable && !transformer_top_final_captured)begin
   if(!p1_active)begin p1_window=p1_window+1;p1_active=1;end
  end else p1_active=0;
  p1_req={|dut.cnm_read_valid,dut.dma_spad_line_valid,dut.dma_spad_valid,dut.banked_read_valid,dut.matrix_line_valid,dut.core_spad_valid,dut.cpl_spad_valid,dut.desc_spad_valid};
  p1_acc=p1_req & {(|dut.cnm_read_valid && |dut.arb_cnm_ready),dut.arb_dma_line_ready,dut.arb_dma_ready,dut.arb_banked_ready,dut.arb_core_line_ready,dut.arb_core_ready,dut.arb_cpl_ready,dut.arb_desc_ready};
  p1_wr={1'b0,dut.dma_spad_line_write,dut.dma_spad_write,1'b0,dut.matrix_line_write,dut.core_spad_write,dut.cpl_spad_write,1'b0};
  p1_addr[0]=dut.desc_spad_addr;p1_addr[1]=dut.cpl_spad_addr;p1_addr[2]=dut.core_spad_addr;p1_addr[3]=dut.matrix_line_addr;p1_addr[4]=dut.banked_read_addr;p1_addr[5]=dut.dma_spad_addr_o;p1_addr[6]=dut.dma_spad_line_addr;p1_addr[7]=dut.cnm_read_addr0;
  for(p1_i=0;p1_i<8;p1_i=p1_i+1)if(p1_acc[p1_i])begin
   p1_bytes=(p1_i==3 || p1_i==4 || p1_i==6 || p1_i==7)?16:4;
   p1_owner=(p1_i==3)?2:(p1_i==4)?3:(p1_i==5 || p1_i==6)?4:(p1_i==7)?5:p1_i;
   $fdisplay(p1_mem_fd,"%0d,%0d,A,%0d,%0d,%08h,%0d,%0d,0",p1_active?p1_window:-1,p1_clk,p1_owner,p1_wr[p1_i],p1_addr[p1_i],p1_bytes,p1_bytes==16?15:(1 << p1_addr[p1_i][3:2]));
  end
  if(dut.arb_rsp_valid)$fdisplay(p1_mem_fd,"%0d,%0d,R,%0d,0,00000000,0,0,%0d",p1_active?p1_window:-1,p1_clk,dut.arb_rsp_client,(dut.arb_rsp_client==3) ? (|dut.banked_parity) : (dut.arb_rsp_client==5) ? (|dut.cnm_parity) : dut.arb_rsp_error);
  if(p1_active)begin
   p1_ms=dut.compute_cluster_u.tensor_matrix_u.state_r;p1_ss=dut.compute_cluster_u.tensor_sfu_u.state_r;
   if(dut.matrix_busy)case(p1_ms)
    1,3,5:p1_bucket=1;
    2,4,6,14:p1_bucket=2;
    7,10:p1_bucket=0;
    8:p1_bucket=3;
    9:p1_bucket=4;
    default:p1_bucket=5;
   endcase
   else if(dut.engine_busy[4])case(p1_ss)
    1,3,5,10,18,20,23,25,32,36,39:p1_bucket=6;
    2,4,6,11,19,21,24,26,33,37,40:p1_bucket=7;
    8,13,15,17,35:p1_bucket=9;
    9,27:p1_bucket=10;
    28,29:p1_bucket=11;
    default:p1_bucket=8;
   endcase
   else if(|dut.engine_busy)p1_bucket=12;
   else if(dut.cpl_spad_valid)p1_bucket=13;
   else if(dut.desc_spad_valid)p1_bucket=14;
   else p1_bucket=15;
   $fdisplay(p1_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",p1_window,p1_clk,p1_bucket,p1_ms,p1_ss,dut.compute_cluster_u.tensor_sfu_u.op_r,dut.matrix_busy,dut.engine_busy[4],dut.matrix_busy && p1_ms==8 && dut.compute_cluster_u.tensor_matrix_u.prefetch_active,dut.compute_cluster_u.tensor_matrix_u.prefetch_active,dut.compute_cluster_u.tensor_matrix_u.read_outstanding_count,p1_req,p1_acc,dut.desc_spad_valid,dut.cpl_spad_valid);
  end
 end
end
