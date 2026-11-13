`timescale 1ns/1ps
module tb_ai_bpf_te_atomic_adapter;
  reg clk=0, resetn=0, epoch_bump=0; always #5 clk=~clk;
  reg line_valid=0,line_write=0; reg [31:0] line_addr=0; reg [127:0] line_wdata=0; reg [15:0] line_wstrb=0; reg [2:0] line_owner=0; reg [7:0] line_tile=0;
  wire line_ready,line_rsp_valid; wire [127:0] line_rsp_rdata; wire [3:0] line_rsp_error;
  reg [3:0] cnm_valid=0; reg [31:0] cnm_addr0=0,cnm_addr1=0,cnm_addr2=0,cnm_addr3=0; reg [2:0] cnm_owner=0; reg [7:0] cnm_tile=0;
  wire [3:0] cnm_ready,cnm_rsp_valid,cnm_rsp_error; wire [127:0] cnm_rsp_rdata;
  reg matrix_valid=0; reg [31:0] matrix_addr=0; reg [2:0] matrix_owner=0; reg [7:0] matrix_tile=0;
  wire matrix_ready,matrix_rsp_valid; wire [127:0] matrix_rsp_rdata; wire [3:0] matrix_rsp_error;
  wire [3:0] bank_req_valid,bank_req_write,bank_ready,bank_rsp_valid,bank_rsp_error,bank_denied; wire [127:0] bank_req_addr,bank_req_wdata,bank_rsp_data; wire [15:0] bank_req_wstrb; wire [3:0] rsp_dropped;
  reg [3:0] bank_allow=4'hf, inject_parity_error=0;
  ai_bpf_te_atomic_adapter a(.clk(clk),.resetn(resetn),.epoch_bump(epoch_bump),.line_valid(line_valid),.line_write(line_write),.line_addr(line_addr),.line_wdata(line_wdata),.line_wstrb(line_wstrb),.line_owner(line_owner),.line_tile(line_tile),.line_ready(line_ready),.line_rsp_valid(line_rsp_valid),.line_rsp_rdata(line_rsp_rdata),.line_rsp_error(line_rsp_error),.cnm_valid(cnm_valid),.cnm_addr0(cnm_addr0),.cnm_addr1(cnm_addr1),.cnm_addr2(cnm_addr2),.cnm_addr3(cnm_addr3),.cnm_owner(cnm_owner),.cnm_tile(cnm_tile),.cnm_ready(cnm_ready),.cnm_rsp_valid(cnm_rsp_valid),.cnm_rsp_rdata(cnm_rsp_rdata),.cnm_rsp_error(cnm_rsp_error),.matrix_valid(matrix_valid),.matrix_addr(matrix_addr),.matrix_owner(matrix_owner),.matrix_tile(matrix_tile),.matrix_ready(matrix_ready),.matrix_rsp_valid(matrix_rsp_valid),.matrix_rsp_rdata(matrix_rsp_rdata),.matrix_rsp_error(matrix_rsp_error),.bank_req_valid(bank_req_valid),.bank_req_write(bank_req_write),.bank_req_addr(bank_req_addr),.bank_req_wdata(bank_req_wdata),.bank_req_wstrb(bank_req_wstrb),.bank_ready(bank_ready),.bank_rsp_valid(bank_rsp_valid),.bank_rsp_rdata(bank_rsp_data),.bank_rsp_error(bank_rsp_error),.rsp_dropped(rsp_dropped));
  ai_spad_bank_parallel_adapter s(.clk(clk),.resetn(resetn),.host_valid(1'b0),.host_write(1'b0),.host_addr(0),.host_wdata(0),.host_wstrb(4'b0),.host_allow(1'b1),.host_ready(),.host_rsp_valid(),.host_rdata(),.host_error(),.host_parity_error(),.bank_req_valid(bank_req_valid),.bank_req_write(bank_req_write),.bank_req_addr(bank_req_addr),.bank_req_wdata(bank_req_wdata),.bank_req_wstrb(bank_req_wstrb),.bank_allow(bank_allow),.inject_parity_error(inject_parity_error),.bank_ready(bank_ready),.bank_denied(bank_denied),.bank_rsp_valid(bank_rsp_valid),.bank_rsp_rdata(bank_rsp_data),.bank_rsp_error(bank_rsp_error),.bank_rsp_parity_error());
  task tick; begin @(posedge clk); #1; end endtask
  initial begin
    repeat(2) tick; resetn=1; tick;
    line_valid=1;line_write=1;line_addr=32'h20;line_wdata=128'h44444444333333332222222211111111;line_wstrb=16'hffff;line_owner=3;line_tile=8'h21;#1;if(!line_ready) $fatal(1,"line write not atomically ready");tick;line_valid=0;line_write=0;
    line_valid=1;line_addr=32'h20;#1;if(!line_ready) $fatal(1,"line read not atomically ready");tick;line_valid=0;repeat(2) tick;if(!line_rsp_valid || line_rsp_rdata!==128'h44444444333333332222222211111111 || |line_rsp_error) $fatal(1,"line response invalid valid=%b data=%h err=%b",line_rsp_valid,line_rsp_rdata,line_rsp_error);$display("BPF_TE_LINE_ATOMIC_PASS: four-bank line write/read Golden passed");
    // A denied atomic write must never reach even one bank.
    bank_allow=4'b0111; line_valid=1;line_write=1;line_addr=32'h20;line_wdata=128'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;line_wstrb=16'hffff;#1;if(line_ready || |bank_req_valid) $fatal(1,"partial bank reservation leaked write valid=%b req=%b",line_ready,bank_req_valid);tick;line_valid=0;line_write=0;bank_allow=4'hf;repeat(1) tick;
    line_valid=1;line_addr=32'h20;#1;tick;line_valid=0;repeat(2) tick;if(!line_rsp_valid || line_rsp_rdata!==128'h44444444333333332222222211111111) $fatal(1,"denied atomic write modified memory data=%h",line_rsp_rdata);$display("BPF_TE_ATOMIC_DENY_PASS: unavailable bank caused zero accepted writes");
    bank_allow=4'b0011; line_valid=1;line_write=1;line_addr=32'h20;#1;if(line_ready || |bank_req_valid) $fatal(1,"multiple unavailable banks leaked request");epoch_bump=1;tick;epoch_bump=0;line_valid=0;line_write=0;bank_allow=4'hf;repeat(1) tick;$display("BPF_TE_ATOMIC_EPOCH_PASS: epoch bump blocked atomic request");
    cnm_valid=4'hf;cnm_addr0=32'h20;cnm_addr1=32'h24;cnm_addr2=32'h28;cnm_addr3=32'h2c;cnm_owner=5;cnm_tile=8'h22;#1;if(cnm_ready!==4'hf) $fatal(1,"CNM full request not atomically ready");tick;cnm_valid=0;repeat(2) tick;if(cnm_rsp_valid!==4'hf || cnm_rsp_rdata!==128'h44444444333333332222222211111111 || |cnm_rsp_error) $fatal(1,"CNM response invalid valid=%b data=%h",cnm_rsp_valid,cnm_rsp_rdata);$display("BPF_TE_CNM_ATOMIC_PASS: full four-lane owner/Golden passed");
    cnm_valid=4'b0101;#1;if(|cnm_ready || |bank_req_valid) $fatal(1,"partial CNM was admitted");cnm_valid=0;
    line_valid=1;line_addr=32'h20;cnm_valid=4'hf;cnm_addr0=32'h20;cnm_addr1=32'h24;cnm_addr2=32'h28;cnm_addr3=32'h2c;#1;if(!line_ready || |cnm_ready) $fatal(1,"line/CNM priority not atomic");tick;line_valid=0;cnm_valid=0;repeat(2) tick;
    $display("BPF_TE_ATOMIC_PASS: Matrix-line/CNM all-or-none and partial rejection passed");$finish;
  end
endmodule
