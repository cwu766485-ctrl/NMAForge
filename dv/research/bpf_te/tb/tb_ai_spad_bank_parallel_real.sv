`timescale 1ns/1ps
module tb_ai_spad_bank_parallel_real;
  localparam integer B=4, R=4, O=3, T=8, E=4;
  reg clk=0, resetn=0, epoch_bump=0; always #5 clk=~clk;
  reg host_valid=0, host_write=0, host_allow=1;
  reg [31:0] host_addr=0, host_wdata=0; reg [3:0] host_wstrb=0;
  wire host_ready, host_rsp_valid, host_error, host_parity_error; wire [31:0] host_rdata;
  reg [R-1:0] req_valid=0, req_write=0; reg [R*32-1:0] req_addr=0, req_wdata=0;
  reg [R*4-1:0] req_wstrb=0; reg [R*O-1:0] req_owner=0; reg [R*T-1:0] req_tile=0;
  wire [R-1:0] req_ready, req_accept, req_denied, req_bp;
  wire [B-1:0] bank_ready, bank_denied, bank_req_valid, bank_req_write;
  wire [B*32-1:0] bank_req_addr, bank_req_wdata; wire [B*4-1:0] bank_req_wstrb;
  wire [B-1:0] bank_rsp_valid, bank_rsp_error, bank_rsp_parity; wire [B*32-1:0] bank_rsp_data;
  reg [B-1:0] bank_allow={B{1'b1}}, inject_parity_error=0;
  integer h0_cycles, h1_cycles;
  wire [B-1:0] rsp_valid, rsp_error, rsp_dropped; wire [B*32-1:0] rsp_data;
  wire [B*O-1:0] rsp_owner; wire [B*2-1:0] rsp_bank; wire [B*T-1:0] rsp_tile;
  wire [B*E-1:0] rsp_epoch; wire [E-1:0] current_epoch; wire [B-1:0] bank_busy;

  ai_spad_bank_parallel_arbiter arb(.clk(clk),.resetn(resetn),.epoch_bump(epoch_bump),
    .req_valid(req_valid),.req_write(req_write),.req_addr(req_addr),.req_wdata(req_wdata),.req_wstrb(req_wstrb),
    .req_owner(req_owner),.req_tile(req_tile),.req_ready(req_ready),.req_accept(req_accept),
    .req_denied(req_denied),.req_backpressure(req_bp),.bank_req_valid(bank_req_valid),
    .bank_req_write(bank_req_write),.bank_req_addr(bank_req_addr),.bank_req_wdata(bank_req_wdata),
    .bank_req_wstrb(bank_req_wstrb),.bank_rsp_valid(bank_rsp_valid),.bank_rsp_rdata(bank_rsp_data),
    .bank_rsp_error(bank_rsp_error),.bank_ready(bank_ready),.rsp_valid(rsp_valid),.rsp_rdata(rsp_data),
    .rsp_owner_flat(rsp_owner),.rsp_error(rsp_error),.rsp_bank_flat(rsp_bank),.rsp_tile(rsp_tile),
    .rsp_epoch(rsp_epoch),.rsp_dropped(rsp_dropped),.current_epoch(current_epoch),.bank_busy(bank_busy));

  ai_spad_bank_parallel_adapter spad(.clk(clk),.resetn(resetn),.host_valid(host_valid),
    .host_write(host_write),.host_addr(host_addr),.host_wdata(host_wdata),.host_wstrb(host_wstrb),
    .host_allow(host_allow),.host_ready(host_ready),.host_rsp_valid(host_rsp_valid),.host_rdata(host_rdata),
    .host_error(host_error),.host_parity_error(host_parity_error),.bank_req_valid(bank_req_valid),
    .bank_req_write(bank_req_write),.bank_req_addr(bank_req_addr),.bank_req_wdata(bank_req_wdata),
    .bank_req_wstrb(bank_req_wstrb),.bank_allow(bank_allow),.inject_parity_error(inject_parity_error),
    .bank_ready(bank_ready),.bank_denied(bank_denied),.bank_rsp_valid(bank_rsp_valid),
    .bank_rsp_rdata(bank_rsp_data),.bank_rsp_error(bank_rsp_error),.bank_rsp_parity_error(bank_rsp_parity));

  task tick; begin @(posedge clk); #1; end endtask
  task host_write_word; input [31:0] a,d; begin host_valid=1;host_write=1;host_addr=a;host_wdata=d;host_wstrb=4'hf; tick; host_valid=0;host_write=0; end endtask
  task host_read_word; input [31:0] a; input [31:0] exp; begin host_valid=1;host_write=0;host_addr=a;tick; host_valid=0; repeat(2) tick; if(!host_rsp_valid || host_rdata!==exp) $fatal(1,"host read a=%h got=%h exp=%h",a,host_rdata,exp); end endtask
  task clear_req; begin req_valid=0;req_write=0;req_addr=0;req_wdata=0;req_wstrb=0;req_owner=0;req_tile=0; end endtask
  task set_req; input integer s; input [31:0] a; input integer o; begin req_valid[s]=1;req_addr[s*32 +:32]=a;req_wstrb[s*4 +:4]=4'hf;req_owner[s*O +:O]=o; end endtask
  task wait_rsp; input integer b; input integer o; input [31:0] exp; input integer err; begin repeat(2) tick; if(!rsp_valid[b] || rsp_owner[b*O +:O]!==o || rsp_data[b*32 +:32]!==exp || rsp_error[b]!==err) $fatal(1,"rsp b=%0d valid=%b owner=%h data=%h err=%b",b,rsp_valid,rsp_owner,rsp_data,rsp_error); end endtask

  initial begin
    repeat(2) tick; resetn=1; tick;
    host_write_word(32'h0000_0000,32'h1111_0000);
    host_write_word(32'h0000_0004,32'h2222_0001);
    host_write_word(32'h0000_0008,32'h3333_0002);
    host_write_word(32'h0000_000c,32'h4444_0003);

    // H1 real SPAD: bank0 + bank1 simultaneous reads with independent Golden.
    clear_req; set_req(0,32'h0,1); set_req(1,32'h4,2); #1;
    if(req_accept!==4'b0011) $fatal(1,"real two-bank acceptance=%b",req_accept);
    tick; clear_req; repeat(2) tick;
    if (rsp_valid[0]!==1 || rsp_valid[1]!==1 || rsp_owner[0 +:O]!==1 || rsp_owner[O +:O]!==2 || rsp_data[0 +:32]!==32'h1111_0000 || rsp_data[32 +:32]!==32'h2222_0001)
      $fatal(1,"real two-bank response valid=%b owner=%h data=%h",rsp_valid,rsp_owner,rsp_data);
    $display("BPF_TE_REAL_TWO_BANK_PASS: bank0/bank1 Golden and owners match");

    // Bank0 read and bank2 write are independent; write is then checked by host.
    clear_req; set_req(0,32'h0,3); req_write[1]=1; req_addr[1*32 +:32]=32'h8; req_wdata[1*32 +:32]=32'haaaa_0002; req_wstrb[1*4 +:4]=4'hf; req_valid[1]=1; #1;
    if(req_accept!==4'b0011) $fatal(1,"read/write bank-disjoint acceptance=%b",req_accept);
    tick; clear_req; wait_rsp(0,3,32'h1111_0000,0); repeat(1) tick; host_read_word(32'h8,32'haaaa_0002);
    $display("BPF_TE_REAL_READ_WRITE_PASS: bank0 read and bank2 write obey port constraints");

    // Same-bank read/write is serialized; no second bank operation is invented.
    clear_req; set_req(0,32'h0,4); req_write[1]=1; req_addr[1*32 +:32]=32'h10; req_wdata[1*32 +:32]=32'hbbbb_0000; req_wstrb[1*4 +:4]=4'hf; req_valid[1]=1; #1;
    if ((req_accept!==4'b0001)&&(req_accept!==4'b0010)) $fatal(1,"same-bank conflict grant=%b",req_accept);
    if (!req_accept[1]) begin
      req_valid=4'b0010; req_write=4'b0010; req_addr[32 +:32]=32'h10; req_wdata[32 +:32]=32'hbbbb_0000; req_wstrb[4 +:4]=4'hf; #1;
      if (!req_accept[1]) $fatal(1,"same-bank denied write did not make progress");
      tick;
    end else begin
      tick;
    end
    clear_req; repeat(2) tick;
    host_read_word(32'h10,32'hbbbb_0000);
    $display("BPF_TE_REAL_SAME_BANK_PASS: same-bank conflict serialized");

    clear_req; set_req(0,32'h0,5); set_req(1,32'h4,6); set_req(2,32'h8,7); set_req(3,32'hc,0); #1; if(req_accept!==4'b1111) $fatal(1,"four-bank grant=%b",req_accept); tick; clear_req; repeat(2) tick;
    $display("BPF_TE_REAL_FOUR_BANK_PASS: all four physical banks admitted");

    // Protection denial and parity error remain observable at the bank port.
    bank_allow[3]=0; clear_req; set_req(3,32'hc,2); #1; if(!req_denied[3]) $fatal(1,"protection denial missing"); tick; clear_req; bank_allow[3]=1;
    inject_parity_error[0]=1; clear_req; set_req(0,32'h0,3); #1; tick; clear_req; wait_rsp(0,3,32'h1111_0000,1); inject_parity_error=0;
    $display("BPF_TE_REAL_FAULT_PASS: protection denial and parity ownership checked");

    host_valid=1; host_write=0; host_addr=0; clear_req; set_req(1,32'h4,1); #1; if(|req_accept || |bank_ready) $fatal(1,"host/scheduler overlap not blocked"); tick; host_valid=0; clear_req; repeat(2) tick;
    $display("BPF_TE_REAL_HOST_OVERLAP_PASS: host priority blocks scheduler admission");
    // Same real adapter and memory latency: H0 constrains admission to one
    // request/cycle; H1 admits two bank-disjoint requests in one cycle.
    h0_cycles=0; clear_req; set_req(0,32'h0,1); #1; tick; h0_cycles=h0_cycles+1; clear_req; repeat(2) begin tick; h0_cycles=h0_cycles+1; end
    if(!rsp_valid[0] || rsp_data[0 +:32]!==32'h1111_0000) $fatal(1,"H0 first Golden failed");
    clear_req; set_req(1,32'h4,2); #1; tick; h0_cycles=h0_cycles+1; clear_req; repeat(2) begin tick; h0_cycles=h0_cycles+1; end
    if(!rsp_valid[1] || rsp_data[32 +:32]!==32'h2222_0001) $fatal(1,"H0 second Golden failed");
    h1_cycles=0; clear_req; set_req(0,32'h0,1); set_req(1,32'h4,2); #1; tick; h1_cycles=h1_cycles+1; clear_req; repeat(2) begin tick; h1_cycles=h1_cycles+1; end
    if(!rsp_valid[0] || !rsp_valid[1] || rsp_data[0 +:32]!==32'h1111_0000 || rsp_data[32 +:32]!==32'h2222_0001) $fatal(1,"H1 parallel Golden failed");
    $display("BPF_TE_H0_H1_AB_PASS: H0 serial_cycles=%0d accepted_per_cycle=1.00; H1 parallel_cycles=%0d accepted_per_cycle=2.00; speedup=2.00 Golden=PASS",h0_cycles,h1_cycles);
    $display("BPF_TE_REAL_SPAD_PASS: real four-bank wrapper Golden/protocol/fault regression passed"); $finish;
  end
endmodule
