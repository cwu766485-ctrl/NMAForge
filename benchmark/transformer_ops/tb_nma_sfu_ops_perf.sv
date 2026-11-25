`timescale 1ns/1ps

// Fixed-latency SFU operator benchmark.  The scratchpad model mirrors the
// production ai_spad_arbiter scalar core port with no competing client:
// ready is always high, writes commit on acceptance, and a read response is
// returned exactly two cycles after acceptance (arbiter accept register plus
// registered SRAM).  Every output word is compared to the independent Python
// reference.  Cycle counts run from start to done.
module tb_nma_sfu_ops_perf;
  reg clk = 0, resetn = 0, start = 0, abort = 0;
  reg [7:0] op_mode = 0;
  reg [31:0] src0_base = 32'h1000, src1_base = 32'h5000, beta_base = 32'h9000;
  reg [31:0] dst_base = 32'hd000;
  reg beta_enable = 0;
  reg [15:0] length = 0;
  reg [4:0] scale_shift = 0;
  reg [31:0] epsilon = 1;
  wire spad_valid, spad_write;
  wire [31:0] spad_addr, spad_wdata;
  wire spad_ready = 1'b1;
  reg rsp_v1 = 0, rsp_v2 = 0;
  reg [31:0] rsp_d1 = 0, rsp_d2 = 0;
  wire busy, done, error;
  wire [3:0] error_code;
  wire [31:0] result, cycle_count, element_count;

  reg [31:0] memory [0:16383];
  reg [31:0] expected [0:1023];
  integer reads = 0, writes = 0;
  integer fd, rc, cases, c, i, cyc, errors, total_errors = 0;
  integer op, len_i, shift_i, eps_i, beta_i;
  reg [31:0] vx, vy, vb, ve;
  reg [1023:0] vec_path;

  always #5 clk = ~clk;

  ai_tensor_sfu_core dut(
    .clk(clk), .resetn(resetn), .start(start), .abort(abort), .op_mode(op_mode),
    .src0_base(src0_base), .src1_base(src1_base), .beta_base(beta_base),
    .beta_enable(beta_enable), .pack_enable(1'b0), .pack_tile_a(1'b0),
    .input_tile_a(1'b0), .src0_stride(32'd0), .dst_base(dst_base),
    .length(length), .m_size(16'd0), .n_size(16'd0), .scale_shift(scale_shift),
    .epsilon(epsilon), .watchdog_limit(32'd0),
    .spad_valid(spad_valid), .spad_write(spad_write), .spad_addr(spad_addr),
    .spad_wdata(spad_wdata), .spad_ready(spad_ready), .spad_rsp_valid(rsp_v2),
    .spad_rdata(rsp_d2), .spad_parity_error(1'b0), .spad_protection_error(1'b0),
    .busy(busy), .done(done), .error(error), .error_code(error_code),
    .result(result), .cycle_count(cycle_count), .element_count(element_count));

  always @(posedge clk) begin
    rsp_v1 <= 1'b0;
    if (spad_valid && spad_ready) begin
      if (spad_write) begin
        memory[spad_addr[15:2]] <= spad_wdata;
        writes <= writes + 1;
      end else begin
        rsp_v1 <= 1'b1;
        rsp_d1 <= memory[spad_addr[15:2]];
        reads <= reads + 1;
      end
    end
    rsp_v2 <= rsp_v1;
    rsp_d2 <= rsp_d1;
  end

  initial begin
    if (!$value$plusargs("VECTORS=%s", vec_path)) $fatal(1, "missing +VECTORS");
    fd = $fopen(vec_path, "r");
    if (fd == 0) $fatal(1, "cannot open vectors");
    rc = $fscanf(fd, "%d\n", cases);
    repeat (4) @(negedge clk);
    resetn = 1;
    for (c = 0; c < cases; c = c + 1) begin
      rc = $fscanf(fd, "%h %d %d %d %d\n", op, len_i, shift_i, eps_i, beta_i);
      if (rc != 5) $fatal(1, "bad header case=%0d", c);
      for (i = 0; i < len_i; i = i + 1) begin
        rc = $fscanf(fd, "%h %h %h %h\n", vx, vy, vb, ve);
        if (rc != 4) $fatal(1, "bad data case=%0d i=%0d", c, i);
        memory[(src0_base >> 2) + i] = vx;
        memory[(src1_base >> 2) + i] = vy;
        memory[(beta_base >> 2) + i] = vb;
        memory[(dst_base >> 2) + i] = 32'hdead_0000 + i;
        expected[i] = ve;
      end
      op_mode = op[7:0]; length = len_i[15:0]; scale_shift = shift_i[4:0];
      epsilon = eps_i; beta_enable = beta_i[0];
      @(negedge clk);
      reads = 0; writes = 0;
      start = 1;
      @(negedge clk);
      start = 0;
      cyc = 1;
      while (!done && !error && cyc < 2000000) begin
        @(negedge clk);
        cyc = cyc + 1;
      end
      if (error) $fatal(1, "SFU error op=%02h len=%0d code=%0d", op, len_i, error_code);
      if (!done) $fatal(1, "SFU timeout op=%02h len=%0d", op, len_i);
      errors = 0;
      for (i = 0; i < len_i; i = i + 1)
        if (memory[(dst_base >> 2) + i] !== expected[i]) begin
          if (errors < 4)
            $display("NMA_OP_MISMATCH op=%02h len=%0d i=%0d exp=%08h got=%08h",
                     op, len_i, i, expected[i], memory[(dst_base >> 2) + i]);
          errors = errors + 1;
        end
      total_errors = total_errors + errors;
      $display("NMA_OP_PERF op=%02h length=%0d cycles=%0d core_cycle_count=%0d reads=%0d writes=%0d golden_words=%0d mismatches=%0d",
               op, len_i, cyc, cycle_count, reads, writes, len_i, errors);
      repeat (3) @(negedge clk);
    end
    if (total_errors != 0) $fatal(1, "NMA_OP_PERF_FAIL mismatches=%0d", total_errors);
    $display("NMA_OP_PERF_PASS cases=%0d", cases);
    $finish;
  end
endmodule
