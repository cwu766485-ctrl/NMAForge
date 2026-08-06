`timescale 1ns/1ps

// Directed A3 4x4 GEMM benchmark.  It deliberately uses the same 64*L INT8
// MAC count as the A2 4-row GEMV benchmark for a comparable MAC/cycle number.
module tb_ai_tensor_a3_gemm_bench;
  reg clk=0, resetn=0, start=0, abort=0;
  reg [15:0] k_words=0;
  wire banked_valid, banked_ready=1'b1;
  reg banked_rsp_valid=0;
  wire spad_valid,spad_write,line_valid,line_write,line_ready=1'b1;
  wire [31:0] banked_addr,spad_addr,spad_wdata,line_addr;
  wire [127:0] line_wdata;
  wire [15:0] line_wstrb;
  wire busy,done,error,mac_active,banked_wait;
  wire [31:0] result,cycles,elements;
  integer errors=0, mac_active_cycles=0, banked_wait_cycles=0;
  integer expected_result;
  always #5 clk=~clk;
  ai_tensor_matrix_core dut(
    .clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(8'h30),
    .src0_base(0),.src1_base(32'h4000),.bias_base(0),.dst_base(32'h8000),
    .m_size(16'd4),.n_size(16'd4),.k_words(k_words),.instance_count(32'd1),
    .src0_batch_stride(32'd0),.src1_batch_stride(32'd0),.dst_batch_stride(32'd0),
    .transpose_a(1'b0),.transpose_b(1'b0),.bias_enable(1'b0),.scale_shift(5'd0),.activation(2'd0),.watchdog_limit(32'd0),
    .bank0_data(32'h01010101),.bank1_data(32'h01010101),.bank2_data(32'h01010101),.bank3_data(32'h01010101),
    .bank_parity_error(4'd0),.banked_read_valid(banked_valid),.banked_addr(banked_addr),
    .banked_ready(banked_ready),.banked_rsp_valid(banked_rsp_valid),.banked_protection_error(1'b0),
    .spad_valid(spad_valid),.spad_write(spad_write),.spad_addr(spad_addr),.spad_wdata(spad_wdata),.spad_ready(1'b1),
    .spad_rsp_valid(1'b0),.spad_rdata(32'd0),.spad_parity_error(1'b0),.spad_protection_error(1'b0),
    .line_valid(line_valid),.line_write(line_write),.line_addr(line_addr),.line_wdata(line_wdata),.line_wstrb(line_wstrb),
    .line_ready(line_ready),.line_protection_error(1'b0),.busy(busy),.done(done),.error(error),.error_code(),
    .result(result),.cycle_count(cycles),.element_count(elements),.perf_mac_active(mac_active),.perf_banked_wait(banked_wait)
  );
  always @(posedge clk) begin
    banked_rsp_valid <= banked_valid;
    if (busy && mac_active) mac_active_cycles <= mac_active_cycles+1;
    if (busy && banked_wait) banked_wait_cycles <= banked_wait_cycles+1;
  end
  task run_case(input [15:0] l);
    begin
      k_words=l; expected_result=4*l;
      mac_active_cycles=0; banked_wait_cycles=0;
      @(posedge clk); start=1;
      @(posedge clk); start=0;
      wait(done); @(posedge clk);
      if(error || result!==expected_result || elements!==32'd16 ||
         mac_active_cycles!==4*l) begin
        $display("ERROR: A3 GEMM L=%0d result=%0d elem=%0d mac_active=%0d wait=%0d",
                 l,result,elements,mac_active_cycles,banked_wait_cycles);
        errors=errors+1;
      end
      // 4x4 outputs * 4 INT8 lanes * L K-groups = 64L MACs.
      $display("BENCH: A3_GEMM L=%0d cycles=%0d outputs=%0d macs=%0d mac_active=%0d mac_per_cycle_x1000=%0d banked_wait=%0d",
               l,cycles,elements,64*l,mac_active_cycles,(64*l*1000)/cycles,banked_wait_cycles);
    end
  endtask
  initial begin
    repeat(3) @(posedge clk); resetn=1;
    run_case(16); run_case(64); run_case(256);
    if(errors) $fatal(1,"A3 GEMM benchmark failed: %0d cases",errors);
    $display("PASS: A3 GEMM benchmark"); $finish;
  end
endmodule
