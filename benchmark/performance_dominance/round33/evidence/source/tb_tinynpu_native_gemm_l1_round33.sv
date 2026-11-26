`timescale 1ns/1ps
`default_nettype none

module tb_tinynpu_native_gemm_l1_round33;
  import isa_pkg::*;

  localparam logic [15:0] SRC_A = 16'h0100;
  localparam logic [15:0] SRC_B = 16'h2000;
  localparam logic [15:0] DST_C = 16'h7000;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic cmd_valid = 1'b0;
  logic [15:0] cmd_src0 = SRC_A, cmd_src1 = SRC_B, cmd_dst = DST_C;
  logic [15:0] cmd_M = 0, cmd_N = 0, cmd_K = 0;
  logic [7:0] cmd_flags = 0;
  logic [15:0] cmd_imm = 0;
  logic cmd_dtype = 1'b0;

  logic sram_rd_en, sram_wr_en;
  logic [15:0] sram_rd_addr, sram_wr_addr;
  logic [7:0] sram_rd_data, sram_wr_data;
  logic tb_read_en = 1'b0;
  logic [15:0] tb_read_addr = 0;
  logic [7:0] tb_read_data;
  logic [11:0] mem_rd_addr;
  logic [1:0] mem_rd_bank, mem_wr_bank;
  logic mem_rd_pingpong, mem_wr_pingpong;
  logic [11:0] mem_wr_addr;
  logic [7:0] mem_rd_data;
  logic mem_rd_valid;
  logic tb_write_en = 1'b0;
  logic [15:0] tb_write_addr = 0;
  logic [7:0] tb_write_data = 0;

  logic acc_rd_en, acc_wr_en;
  logic [7:0] acc_rd_addr, acc_wr_addr;
  logic signed [31:0] acc_rd_data, acc_wr_data;
  logic sa_clear, sa_en, dtype_fp16, busy, done;
  logic signed [7:0] sa_a_col [16];
  logic signed [7:0] sa_b_row [16];
  logic signed [15:0] sa_a_col_fp16 [16];
  logic signed [15:0] sa_b_row_fp16 [16];
  logic signed [31:0] sa_acc [16][16];
  logic sa_acc_valid;
  logic signed [31:0] acc_mem [0:255];
  integer cycles;
  integer timeout_cycles;
  integer case_count = 0;
  integer sram_read_count = 0;
  integer sram_write_count = 0;
  integer row, col, kk, bank, word_addr, mismatches;
  integer signed a_value, b_value, golden;
  integer signed clamped;
  integer m, n, k_size;

  always #5 clk = ~clk;

  // TinyNPU's native controller talks to a byte SRAM. Map the byte address
  // onto its real four-bank byte-wide SRAM endpoint, with the native one-cycle
  // registered read response and independent write port.
  assign mem_rd_addr = (tb_read_en ? tb_read_addr : sram_rd_addr) >> 2;
  assign mem_rd_bank = (tb_read_en ? tb_read_addr : sram_rd_addr) & 16'h0003;
  assign mem_wr_bank = (tb_write_en ? tb_write_addr : sram_wr_addr) & 16'h0003;
  assign mem_wr_addr = (tb_write_en ? tb_write_addr : sram_wr_addr) >> 2;
  // The physical endpoint has two 16 KiB ping-pong planes. The harness maps
  // controller address bit 14 to that native ping-pong selector so the full
  // 32 KiB can be addressed without changing gemm_ctrl or the SRAM macro.
  assign mem_rd_pingpong = (tb_read_en ? tb_read_addr : sram_rd_addr) >> 14;
  assign mem_wr_pingpong = (tb_write_en ? tb_write_addr : sram_wr_addr) >> 14;
  assign tb_read_data = mem_rd_data;
  assign sram_rd_data = mem_rd_data;

  banked_sram #(
    .NUM_BANKS(4), .BANK_DEPTH(4096), .DATA_W(8), .PINGPONG(1),
    .ADDR_W(12), .BSEL_W(2)
  ) u_sram (
    .clk(clk), .rst_n(rst_n),
    .rd_en(tb_read_en || sram_rd_en), .rd_bank_sel(mem_rd_bank),
    .rd_addr(mem_rd_addr), .rd_pingpong_sel(mem_rd_pingpong),
    .rd_data(mem_rd_data), .rd_valid(mem_rd_valid),
    .wr_en(tb_write_en || sram_wr_en), .wr_bank_sel(mem_wr_bank),
    .wr_addr(mem_wr_addr), .wr_pingpong_sel(mem_wr_pingpong),
    .wr_data(tb_write_en ? tb_write_data : sram_wr_data)
  );

  integer acc_reset_i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_rd_data <= '0;
      for (acc_reset_i = 0; acc_reset_i < 256; acc_reset_i = acc_reset_i + 1)
        acc_mem[acc_reset_i] <= '0;
    end
    else begin
      if (acc_rd_en) acc_rd_data <= acc_mem[acc_rd_addr];
      if (acc_wr_en) acc_mem[acc_wr_addr] <= acc_wr_data;
    end
  end

  always @(posedge clk) begin
    if (rst_n && sram_rd_en) sram_read_count = sram_read_count + 1;
    if (rst_n && sram_wr_en) sram_write_count = sram_write_count + 1;
  end

  systolic_array #(.M(16), .N(16), .DATA_W(8), .ACC_W(32)) u_array (
    .clk(clk), .rst_n(rst_n), .clear_acc(sa_clear), .en(sa_en),
    .dtype_fp16(dtype_fp16), .a_col(sa_a_col), .b_row(sa_b_row),
    .a_col_fp16(sa_a_col_fp16), .b_row_fp16(sa_b_row_fp16),
    .acc_out(sa_acc), .acc_valid(sa_acc_valid)
  );

  gemm_ctrl #(.ARRAY_M(16), .ARRAY_N(16), .DATA_W(8), .ACC_W(32),
              .SRAM_ADDR_W(16)) u_ctrl (
    .clk(clk), .rst_n(rst_n), .cmd_valid(cmd_valid),
    .cmd_src0(cmd_src0), .cmd_src1(cmd_src1), .cmd_dst(cmd_dst),
    .cmd_M(cmd_M), .cmd_N(cmd_N), .cmd_K(cmd_K),
    .cmd_flags(cmd_flags), .cmd_imm(cmd_imm), .cmd_dtype(cmd_dtype),
    .sram_rd_en(sram_rd_en), .sram_rd_addr(sram_rd_addr),
    .sram_rd_data(sram_rd_data), .sram_wr_en(sram_wr_en),
    .sram_wr_addr(sram_wr_addr), .sram_wr_data(sram_wr_data),
    .acc_rd_en(acc_rd_en), .acc_rd_addr(acc_rd_addr),
    .acc_rd_data(acc_rd_data), .acc_wr_en(acc_wr_en),
    .acc_wr_addr(acc_wr_addr), .acc_wr_data(acc_wr_data),
    .sa_clear(sa_clear), .sa_en(sa_en), .sa_a_col(sa_a_col),
    .sa_b_row(sa_b_row), .sa_acc(sa_acc), .dtype_fp16(dtype_fp16),
    .sa_a_col_fp16(sa_a_col_fp16), .sa_b_row_fp16(sa_b_row_fp16),
    .busy(busy), .done(done)
  );

  task automatic write_byte(input integer address,
                            input logic [7:0] value);
    integer local_bank, local_word;
    begin
      local_bank = address & 3;
      local_word = (address >> 2) & 12'hfff;
      @(negedge clk);
      tb_write_en = 1'b1;
      tb_write_addr = address[15:0];
      tb_write_data = value;
      @(negedge clk);
      tb_write_en = 1'b0;
    end
  endtask

  task automatic read_byte(input integer address,
                           output logic [7:0] value);
    begin
      @(negedge clk);
      tb_read_addr = address[15:0];
      tb_read_en = 1'b1;
      @(negedge clk);
      value = tb_read_data;
      tb_read_en = 1'b0;
    end
  endtask

  task automatic run_case(input integer case_m, input integer case_n,
                          input integer case_k);
    integer r, c, q, local_cycles;
    logic [7:0] observed;
    begin
      m = case_m; n = case_n; k_size = case_k;
      for (r = 0; r < m; r = r + 1)
        for (q = 0; q < k_size; q = q + 1) begin
          a_value = ((r * 3 + q * 2 + 1) % 9) - 4;
          write_byte(SRC_A + r * k_size + q, a_value[7:0]);
        end
      for (q = 0; q < k_size; q = q + 1)
        for (c = 0; c < n; c = c + 1) begin
          b_value = ((q * 2 - c * 3 + 5) % 9) - 4;
          write_byte(SRC_B + q * n + c, b_value[7:0]);
        end

      cmd_src0 = SRC_A;
      cmd_src1 = SRC_B;
      cmd_dst = DST_C;
      cmd_M = m;
      cmd_N = n;
      cmd_K = k_size;
      cmd_flags = 8'd0; // native INT8 saturation, no requant scale
      cmd_imm = 16'd0;
      cmd_dtype = 1'b0;
      sram_read_count = 0;
      sram_write_count = 0;
      @(negedge clk);
      cmd_valid = 1'b1;
      @(negedge clk);
      cmd_valid = 1'b0;
      local_cycles = 0;
      while (!done && local_cycles < 200000) begin
        @(negedge clk);
        local_cycles = local_cycles + 1;
      end
      if (!done)
        $fatal(1, "Tiny native GEMM timeout shape=%0dx%0dx%0d state=%0d",
               m, n, k_size, u_ctrl.state);
      cycles = local_cycles;

      mismatches = 0;
      for (r = 0; r < m; r = r + 1)
        for (c = 0; c < n; c = c + 1) begin
          golden = 0;
          for (q = 0; q < k_size; q = q + 1) begin
            a_value = ((r * 3 + q * 2 + 1) % 9) - 4;
            b_value = ((q * 2 - c * 3 + 5) % 9) - 4;
            golden = golden + (a_value * b_value);
          end
          clamped = (golden > 127) ? 127 :
                    ((golden < -128) ? -128 : golden);
          read_byte(DST_C + r * n + c, observed);
          if ($signed(observed) !== clamped[7:0]) begin
            if (mismatches < 8)
              $display("Tiny mismatch shape=%0dx%0dx%0d row=%0d col=%0d got=%0d exp=%0d int32=%0d",
                       m, n, k_size, r, c, $signed(observed), clamped,
                       golden);
            mismatches = mismatches + 1;
          end
        end
      if (mismatches != 0)
        $fatal(1, "Tiny native GEMM Golden mismatch shape=%0dx%0dx%0d count=%0d",
               m, n, k_size, mismatches);
      case_count = case_count + 1;
      $display("TINYNPU_NATIVE_GEMM_L1_PASS shape_mnk=%0d,%0d,%0d cycles=%0d read_bytes=%0d expected_input_bytes=%0d write_bytes=%0d expected_output_bytes=%0d byte_sram_read_latency=1 write_bandwidth=1B/cycle controller=gemm_ctrl array=16x16 resources=256_MACs int8_output=saturating Golden=%0d/%0d",
               m, n, k_size, cycles, sram_read_count, m*k_size+k_size*n,
               sram_write_count, m*n, m * n, m * n);
    end
  endtask

  initial begin
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    run_case(16, 16, 16);
    run_case(16, 16, 32);
    run_case(32, 32, 64);
    run_case(64, 64, 64);
    run_case(1, 16, 64);
    run_case(1, 64, 64);
    run_case(1, 256, 64);
    run_case(1, 64, 256);
    $display("TINYNPU_NATIVE_MATRIX_L1_SUITE_PASS cases=%0d source_pinned=8216c22b762011aa20c05fc2768423fd12dda59d SRAM=4_banks_x_4KiB_x2_pingpong physical_capacity=32KiB address_map=addr_bit14_to_pingpong", case_count);
    $finish;
  end
endmodule

`default_nettype wire
