`timescale 1ns/1ps
module tb_ai_spad_bank_parallel_arbiter;
    localparam integer BANKS=4, REQ=4, OB=3, TB=8, EB=4;
    reg clk=0, resetn=0, epoch_bump=0;
    always #5 clk=~clk;
    reg [REQ-1:0] req_valid=0, req_write=0;
    reg [REQ*32-1:0] req_addr=0, req_wdata=0;
    reg [REQ*4-1:0] req_wstrb=0;
    reg [REQ*OB-1:0] req_owner=0;
    reg [REQ*TB-1:0] req_tile=0;
    wire [REQ-1:0] req_ready, req_accept, req_denied, req_backpressure;
    wire [BANKS-1:0] bank_req_valid, bank_req_write;
    wire [BANKS-1:0] bank_ready;
    wire [BANKS*32-1:0] bank_req_addr, bank_req_wdata;
    wire [BANKS*4-1:0] bank_req_wstrb;
    wire [BANKS-1:0] bank_rsp_valid, bank_rsp_error;
    wire [BANKS*32-1:0] bank_rsp_rdata;
    wire [BANKS-1:0] rsp_valid, rsp_error;
    wire [BANKS*32-1:0] rsp_rdata;
    wire [BANKS*OB-1:0] rsp_owner_flat;
    wire [BANKS*2-1:0] rsp_bank_flat;
    wire [BANKS*TB-1:0] rsp_tile;
    wire [BANKS*EB-1:0] rsp_epoch;
    wire [BANKS-1:0] rsp_dropped;
    wire [EB-1:0] current_epoch;
    wire [BANKS-1:0] bank_busy;
    reg [BANKS-1:0] rv0=0, rv1=0, rv2=0;
    reg [BANKS-1:0] fe0=0, fe1=0, fe2=0, fault_inject=0;
    reg [BANKS*32-1:0] rd0=0, rd1=0, rd2=0;
    integer mem [0:BANKS-1][0:15];
    integer i,j, responses;

    assign bank_rsp_valid=rv2;
    assign bank_rsp_rdata=rd2;
    assign bank_rsp_error=fe2;
    assign bank_ready={BANKS{1'b1}};
    ai_spad_bank_parallel_arbiter dut (
      .clk(clk), .resetn(resetn), .epoch_bump(epoch_bump),
      .req_valid(req_valid), .req_write(req_write), .req_addr(req_addr),
      .req_wdata(req_wdata), .req_owner(req_owner), .req_tile(req_tile),
      .req_wstrb(req_wstrb),
      .req_ready(req_ready), .req_accept(req_accept), .req_denied(req_denied),
      .req_backpressure(req_backpressure), .bank_req_valid(bank_req_valid),
      .bank_req_write(bank_req_write), .bank_req_addr(bank_req_addr),
      .bank_req_wdata(bank_req_wdata), .bank_req_wstrb(bank_req_wstrb), .bank_rsp_valid(bank_rsp_valid),
      .bank_rsp_rdata(bank_rsp_rdata), .bank_rsp_error(bank_rsp_error),
      .bank_ready(bank_ready),
      .rsp_valid(rsp_valid), .rsp_rdata(rsp_rdata),
      .rsp_owner_flat(rsp_owner_flat), .rsp_error(rsp_error),
      .rsp_bank_flat(rsp_bank_flat), .rsp_tile(rsp_tile),
      .rsp_epoch(rsp_epoch), .rsp_dropped(rsp_dropped),
      .current_epoch(current_epoch), .bank_busy(bank_busy)
    );

    always @(posedge clk) begin
      rv0 <= bank_req_valid;
      rv1 <= rv0;
      rv2 <= rv1;
      fe0 <= bank_req_valid & {BANKS{fault_inject}};
      fe1 <= fe0;
      fe2 <= fe1;
      for (j=0;j<BANKS;j=j+1) begin
        if (bank_req_valid[j] && bank_req_write[j])
          mem[j][bank_req_addr[j*32 + 5 -: 2]] = bank_req_wdata[j*32 +: 32];
        if (bank_req_valid[j] && !bank_req_write[j])
          rd0[j*32 +: 32] <= mem[j][bank_req_addr[j*32 + 5 -: 2]];
      end
      rd1 <= rd0;
      rd2 <= rd1;
    end

    task clear_req;
      begin req_valid=0; req_write=0; req_addr=0; req_wdata=0; req_wstrb=0; req_owner=0; req_tile=0; end
    endtask
    task set_req;
      input integer s; input [31:0] a; input integer o; input integer t;
      begin req_valid[s]=1'b1; req_addr[s*32 +: 32]=a; req_wstrb[s*4 +: 4]=4'hf; req_owner[s*OB +: OB]=o; req_tile[s*TB +: TB]=t; end
    endtask
    task tick; begin @(posedge clk); #1; end endtask

    initial begin
      for (i=0;i<BANKS;i=i+1) for (j=0;j<16;j=j+1) mem[i][j]=32'h1000+i*32+j;
      repeat (2) tick; resetn=1; tick;

      clear_req; set_req(0,32'h0000_0000,1,8); set_req(1,32'h0000_0004,2,9); #1;
      if (req_ready !== 4'b0011 || bank_req_valid !== 4'b0011)
        $fatal(1,"BPF_TE two-bank admission failed ready=%b bank=%b",req_ready,bank_req_valid);
      tick; clear_req; repeat (2) tick;
      if (rsp_valid[0] !== 1'b1 || rsp_valid[1] !== 1'b1 ||
          rsp_owner_flat[0 +: OB] !== 3'd1 || rsp_owner_flat[OB +: OB] !== 3'd2)
        $fatal(1,"BPF_TE tagged responses failed valid=%b owner=%h",rsp_valid,rsp_owner_flat);
      $display("BPF_TE_TWO_BANK_PASS: simultaneous banks accepted and two-cycle owners preserved");

      clear_req; set_req(0,32'h0000_0000,3,10); set_req(1,32'h0000_0010,4,11); #1;
      if (req_accept !== 4'b0001 && req_accept !== 4'b0010)
        $fatal(1,"BPF_TE same-bank admitted count failed accept=%b",req_accept);
      if (^req_denied !== 1'b1 || ^req_backpressure !== 1'b1)
        $fatal(1,"BPF_TE same-bank denial not observable denied=%b bp=%b",req_denied,req_backpressure);
      tick; clear_req; repeat (2) tick;
      $display("BPF_TE_SAME_BANK_PASS: conflict serialized with explicit backpressure");

      clear_req; set_req(2,32'h0000_0004,5,12); #1; tick; clear_req;
      epoch_bump=1; tick; epoch_bump=0; repeat (3) tick;
      if (|rsp_valid) $fatal(1,"BPF_TE stale response escaped epoch flush");
      if (current_epoch !== 1) $fatal(1,"BPF_TE epoch did not advance");
      $display("BPF_TE_EPOCH_PASS: outstanding response flushed without stale delivery");

      // Fault is carried with the tagged response and cannot be confused with
      // a response from another bank.
      clear_req; fault_inject={BANKS{1'b1}}; set_req(3,32'h0000_000c,6,13); #1; tick;
      clear_req; repeat (2) tick;
      #1; $display("BPF_TE_FAULT_TRACE rv=%b fe=%b rsp=%b err=%b",bank_rsp_valid,fe2,rsp_valid,rsp_error);
      if (rsp_valid[3] !== 1'b1 || rsp_error[3] !== 1'b1 ||
          rsp_owner_flat[3*OB +: OB] !== 3'd6)
        $fatal(1,"BPF_TE fault response owner/error failed valid=%b error=%b owner=%h",rsp_valid,rsp_error,rsp_owner_flat);
      fault_inject=0;
      $display("BPF_TE_FAULT_PASS: bank error retained with owner and epoch tag");

      clear_req; set_req(0,32'h0,1,20); set_req(1,32'h10,2,21);
      responses=0;
      repeat (6) begin #1; if (|req_accept) responses=responses+1; tick; end
      clear_req; if (responses !== 6) $fatal(1,"BPF_TE fairness admission count=%0d",responses);
      $display("BPF_TE_FAIRNESS_PASS: six same-bank admissions completed with rotating grant");
      $display("BPF_TE_PASS: two-bank, conflict, ownership, epoch, and fairness checks passed");
      $finish;
    end
endmodule
