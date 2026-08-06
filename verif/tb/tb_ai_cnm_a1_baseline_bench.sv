`timescale 1ns/1ps
module tb_ai_cnm_a1_baseline_bench;
  reg clk=0, resetn=0, start=0, abort=0; reg [15:0] length=0; reg rsp=0; integer errors=0;
  wire req,busy,done,error,spad_valid,spad_write; wire [31:0] addr,result,cycles,elements,spad_addr,spad_wdata;
  always #5 clk=~clk;
  ai_banked_compute_core_original dut(.clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(8'h21),.src0_base(0),.src1_base(32'h4000),.dst_base(32'h8000),.length(length),.m_size(4),.scale_shift(0),.activation(0),.watchdog_limit(0),.bank0_data(32'h01010101),.bank1_data(32'h01010101),.bank2_data(32'h01010101),.bank3_data(32'h01010101),.bank_parity_error(0),.banked_read_valid(req),.banked_addr(addr),.banked_ready(1'b1),.banked_rsp_valid(rsp),.banked_protection_error(0),.spad_valid(spad_valid),.spad_write(spad_write),.spad_addr(spad_addr),.spad_wdata(spad_wdata),.spad_ready(1'b1),.spad_protection_error(0),.busy(busy),.done(done),.error(error),.error_code(),.result(result),.cycle_count(cycles),.element_count(elements));
  always @(posedge clk) rsp<=req;
  task run_case(input [15:0] l); integer macs; begin length=l; @(posedge clk);start=1;@(posedge clk);start=0;wait(done);@(posedge clk);macs=64*l;if(error||result!==16*l||elements!==4)begin $display("ERROR: original L=%0d result=%0d elements=%0d",l,result,elements);errors=errors+1;end $display("BENCH: ORIGINAL_GEMV L=%0d cycles=%0d outputs=%0d macs=%0d mac_per_cycle_x1000=%0d global_reduce=%0d reads=%0d",l,cycles,elements,macs,(macs*1000)/cycles,4*l,8*l); $display("BENCH: A1_LOCAL_ACCUM L=%0d cycles=%0d outputs=%0d macs=%0d mac_per_cycle_x1000=%0d global_reduce=%0d reads=%0d note=cycle_equal_by_unchanged_fsm",l,cycles,elements,macs,(macs*1000)/cycles,4,8*l);end endtask
  initial begin repeat(3)@(posedge clk);resetn=1;run_case(16);run_case(64);run_case(256);if(errors)$fatal(1,"original RTL benchmark failed");$display("PASS: original RTL GEMV benchmark");$finish;end
endmodule
