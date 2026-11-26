`timescale 1ns/1ps

// TinyNPU operator benchmark wrapper around the pinned, unmodified
// sim/verilator/engine_tb_top.sv.  INT8 inputs are written through the TB SRAM
// ports before timing, the engine command is pulsed for one cycle, and cycles
// are counted from that command edge to done (the same start-to-done boundary
// as tb_nma_sfu_ops_perf.sv).  Outputs are dumped for check_tiny.py.
module tb_tiny_ops_perf;
  localparam int DEPTH = 4096;
  localparam int AW = 12;
  localparam logic [15:0] SRC = 16'd0, DST = 16'd1024, AUX = 16'd0;
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic s0_we = 0, s0_re = 0, s1_we = 0, s1_re = 0, scr_we = 0, scr_re = 0;
  logic [AW-1:0] s0_wa = 0, s0_ra = 0, s1_wa = 0, s1_ra = 0, scr_wa = 0, scr_ra = 0;
  logic [7:0] s0_wd = 0, s1_wd = 0;
  logic [15:0] scr_wd = 0;
  wire [7:0] s0_rd, s1_rd;
  wire [15:0] scr_rd;
  logic gelu_v = 0, sm_v = 0, ln_v = 0, vec_v = 0;
  logic [15:0] len = 0;
  wire gelu_b, gelu_d, sm_b, sm_d, ln_b, ln_d, vec_b, vec_d;
  wire signed [31:0] acc_d;
  wire acc_v;

  engine_tb_top #(.SRAM_DEPTH(DEPTH)) dut (
    .clk(clk), .rst_n(rst_n),
    .tb_sram0_wr_en(s0_we), .tb_sram0_wr_addr(s0_wa), .tb_sram0_wr_data(s0_wd),
    .tb_sram0_rd_en(s0_re), .tb_sram0_rd_addr(s0_ra), .tb_sram0_rd_data(s0_rd),
    .tb_sram1_wr_en(s1_we), .tb_sram1_wr_addr(s1_wa), .tb_sram1_wr_data(s1_wd),
    .tb_sram1_rd_en(s1_re), .tb_sram1_rd_addr(s1_ra), .tb_sram1_rd_data(s1_rd),
    .tb_scratch_wr_en(scr_we), .tb_scratch_wr_addr(scr_wa), .tb_scratch_wr_data(scr_wd),
    .tb_scratch_rd_en(scr_re), .tb_scratch_rd_addr(scr_ra), .tb_scratch_rd_data(scr_rd),
    .gelu_cmd_valid(gelu_v), .gelu_length(len), .gelu_src_base(SRC), .gelu_dst_base(DST),
    .gelu_busy(gelu_b), .gelu_done(gelu_d),
    .softmax_cmd_valid(sm_v), .softmax_length(len), .softmax_src_base(SRC),
    .softmax_dst_base(DST), .softmax_scale(16'd256), .softmax_causal_en(1'b0),
    .softmax_causal_limit(16'd0), .softmax_busy(sm_b), .softmax_done(sm_d),
    .layernorm_cmd_valid(ln_v), .layernorm_length(len), .layernorm_src_base(SRC),
    .layernorm_dst_base(DST), .layernorm_gamma_base(16'd2048), .layernorm_beta_base(AUX),
    .layernorm_busy(ln_b), .layernorm_done(ln_d),
    .vec_cmd_valid(vec_v), .vec_opcode(2'd0), .vec_length(len), .vec_src0_base(SRC),
    .vec_src1_base(AUX), .vec_dst_base(DST), .vec_scale(8'd1), .vec_shift(8'd0),
    .vec_busy(vec_b), .vec_done(vec_d),
    .sa_en(1'b0), .sa_clear_acc(1'b0), .sa_a_col_flat('0), .sa_b_row_flat('0),
    .sa_acc_rd_row('0), .sa_acc_rd_col('0), .sa_acc_rd_data(acc_d), .sa_acc_valid(acc_v));

  // engine_tb_top leaves the INT8/FP16 selector unconnected; Verilator
  // resolves it to zero.  Pin the same INT8 mode explicitly for VCS.
  initial begin
    force dut.u_softmax.cmd_dtype = 2'd0;
    force dut.u_layernorm.cmd_dtype = 2'd0;
  end

  integer fd, out, rc, cases, c, i, sel, n, cyc;
  logic [7:0] vx, vy;
  logic [1023:0] vec_path, out_path;
  logic done_sel;

  task automatic wr0(input int a, input logic [7:0] d);
    @(negedge clk); s0_we = 1; s0_wa = a[AW-1:0]; s0_wd = d;
    @(negedge clk); s0_we = 0;
  endtask
  task automatic wr1(input int a, input logic [7:0] d);
    @(negedge clk); s1_we = 1; s1_wa = a[AW-1:0]; s1_wd = d;
    @(negedge clk); s1_we = 0;
  endtask
  task automatic rd0(input int a, output logic [7:0] d);
    @(negedge clk); s0_re = 1; s0_ra = a[AW-1:0];
    @(negedge clk); s0_re = 0;
    @(posedge clk); #1 d = s0_rd;
  endtask

  initial begin
    logic [7:0] rv;
    if (!$value$plusargs("VECTORS=%s", vec_path)) $fatal(1, "missing +VECTORS");
    if (!$value$plusargs("OUT=%s", out_path)) $fatal(1, "missing +OUT");
    fd = $fopen(vec_path, "r");
    out = $fopen(out_path, "w");
    rc = $fscanf(fd, "%d\n", cases);
    repeat (5) @(negedge clk);
    rst_n = 1;
    repeat (2) @(negedge clk);
    for (c = 0; c < cases; c++) begin
      rc = $fscanf(fd, "%d %d\n", sel, n);
      for (i = 0; i < n; i++) begin
        rc = $fscanf(fd, "%h %h\n", vx, vy);
        wr0(SRC + i, vx);
        wr0(DST + i, 8'h5a);
        if (sel == 2 || sel == 3) wr1(AUX + i, vy);
      end
      len = n[15:0];
      @(negedge clk);
      case (sel)
        0: gelu_v = 1;
        1: sm_v = 1;
        2: ln_v = 1;
        default: vec_v = 1;
      endcase
      @(negedge clk);
      gelu_v = 0; sm_v = 0; ln_v = 0; vec_v = 0;
      cyc = 1;
      forever begin
        done_sel = (sel == 0) ? gelu_d : (sel == 1) ? sm_d : (sel == 2) ? ln_d : vec_d;
        if (done_sel || cyc > 2000000) break;
        @(negedge clk);
        cyc++;
      end
      if (!done_sel) $fatal(1, "TinyNPU engine timeout sel=%0d len=%0d", sel, n);
      $display("TINY_OP_PERF sel=%0d length=%0d cycles=%0d", sel, n, cyc);
      repeat (3) @(negedge clk);
      $fwrite(out, "%0d %0d %0d\n", sel, n, cyc);
      for (i = 0; i < n; i++) begin
        rd0(DST + i, rv);
        $fwrite(out, "%02h\n", rv);
      end
    end
    $fclose(out);
    $display("TINY_OP_PERF_DONE cases=%0d", cases);
    $finish;
  end
endmodule
